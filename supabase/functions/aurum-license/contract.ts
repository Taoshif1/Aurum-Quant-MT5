export type ActivationRequest = {
  licenseKey: string
  accountFingerprint: string
  version: string
}

export type LicenseDecision =
  | 'VALID'
  | 'INVALID'
  | 'REVOKED'
  | 'EXPIRED'
  | 'ACTIVATION_LIMIT'
  | 'RATE_LIMITED'

const keyPattern = /^[A-Za-z0-9_-]{8,128}$/
const fingerprintPattern = /^[0-9a-f]{64}$/
const versionPattern = /^[0-9A-Za-z._-]{1,32}$/

export function parseActivationForm(body: string):
  | { ok: true; value: ActivationRequest }
  | { ok: false; error: string } {
  if (body.length === 0 || body.length > 512) return { ok: false, error: 'invalid body size' }
  const form = new URLSearchParams(body)
  const licenseKey = form.get('license_key') ?? ''
  const accountFingerprint = form.get('account_fingerprint') ?? ''
  const version = form.get('version') ?? ''

  if (!keyPattern.test(licenseKey)) return { ok: false, error: 'invalid license key format' }
  if (!fingerprintPattern.test(accountFingerprint)) return { ok: false, error: 'invalid account fingerprint' }
  if (!versionPattern.test(version)) return { ok: false, error: 'invalid version' }
  return { ok: true, value: { licenseKey, accountFingerprint, version } }
}

export function responseForDecision(decision: LicenseDecision, expiresUnix: number): Response {
  const expires = Number.isSafeInteger(expiresUnix) && expiresUnix >= 0 ? expiresUnix : 0
  if (decision === 'VALID') {
    return new Response(`AURUM_LICENSE|status=VALID|expires=${expires}`, {
      status: 200,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
    })
  }
  if (decision === 'EXPIRED') {
    return new Response('AURUM_LICENSE|status=EXPIRED', {
      status: 410,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
    })
  }
  if (decision === 'RATE_LIMITED') {
    return new Response('AURUM_LICENSE|status=RATE_LIMITED', {
      status: 429,
      headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store', 'Retry-After': '600' },
    })
  }
  const status = decision === 'REVOKED' ? 'REVOKED' : 'INVALID'
  return new Response(`AURUM_LICENSE|status=${status}`, {
    status: 403,
    headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' },
  })
}
