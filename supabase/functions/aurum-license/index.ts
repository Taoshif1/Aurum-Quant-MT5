import { createClient } from 'npm:@supabase/supabase-js@2.95.0'
import { parseActivationForm, responseForDecision, type LicenseDecision } from './contract.ts'

function adminClient() {
  const url = Deno.env.get('SUPABASE_URL') ?? ''
  let key = ''
  const modern = Deno.env.get('SUPABASE_SECRET_KEYS')
  if (modern) {
    try {
      const parsed = JSON.parse(modern) as Record<string, string>
      key = parsed.default ?? ''
    } catch {
      key = ''
    }
  }
  if (!key) key = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
  if (!url || !key) throw new Error('Supabase server credentials unavailable')
  return createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false, detectSessionInUrl: false },
  })
}

async function sha256Hex(value: string): Promise<string> {
  const bytes = new TextEncoder().encode(value)
  const digest = await crypto.subtle.digest('SHA-256', bytes)
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('')
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', {
      status: 405,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Allow': 'POST' },
    })
  }

  const contentType = req.headers.get('content-type')?.toLowerCase() ?? ''
  if (!contentType.startsWith('application/x-www-form-urlencoded')) {
    return new Response('unsupported media type', { status: 415 })
  }

  const parsed = parseActivationForm(await req.text())
  if (!parsed.ok) return new Response(parsed.error, { status: 400 })

  try {
    const keyHash = await sha256Hex(parsed.value.licenseKey)
    const supabase = adminClient()
    const { data, error } = await supabase.rpc('aurum_validate_license', {
      p_key_hash: keyHash,
      p_account_fingerprint: parsed.value.accountFingerprint,
      p_version: parsed.value.version,
    })
    if (error) {
      console.error('AURUM_LICENSE_DB_ERROR', error.code ?? 'unknown')
      return new Response('license service unavailable', {
        status: 503,
        headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
      })
    }

    const row = Array.isArray(data) ? data[0] : data
    const decision = String(row?.decision ?? 'INVALID') as LicenseDecision
    const expiresUnix = Number(row?.expires_unix ?? 0)
    return responseForDecision(decision, expiresUnix)
  } catch (error) {
    console.error('AURUM_LICENSE_SERVICE_ERROR', error instanceof Error ? error.message : 'unknown')
    return new Response('license service unavailable', {
      status: 503,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
    })
  }
})
