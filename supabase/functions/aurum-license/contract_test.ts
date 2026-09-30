import { parseActivationForm, responseForDecision } from './contract.ts'

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) throw new Error(message)
}

Deno.test('accepts the MT5 activation contract', () => {
  const parsed = parseActivationForm(
    'license_key=AQ-abcdef_123456&account_fingerprint=' + 'a'.repeat(64) + '&version=1.250',
  )
  assert(parsed.ok, 'valid activation form rejected')
  if (parsed.ok) {
    assert(parsed.value.licenseKey === 'AQ-abcdef_123456', 'license key changed')
    assert(parsed.value.version === '1.250', 'version changed')
  }
})

Deno.test('rejects raw or malformed identity values', () => {
  assert(!parseActivationForm('license_key=x&account_fingerprint=123&version=1.250').ok, 'bad form accepted')
  assert(!parseActivationForm(
    'license_key=AQ-abcdef_123456&account_fingerprint=' + 'a'.repeat(64) + '&version=<script>',
  ).ok, 'bad version accepted')
})

Deno.test('renders MT5-compatible license responses', async () => {
  const valid = responseForDecision('VALID', 1893456000)
  assert(valid.status === 200, 'VALID status code')
  assert((await valid.text()) === 'AURUM_LICENSE|status=VALID|expires=1893456000', 'VALID body')
  assert(responseForDecision('EXPIRED', 0).status === 410, 'EXPIRED status code')
  assert(responseForDecision('REVOKED', 0).status === 403, 'REVOKED status code')
  assert(responseForDecision('ACTIVATION_LIMIT', 0).status === 403, 'activation limit status code')
  assert(responseForDecision('RATE_LIMITED', 0).status === 429, 'rate limit status code')
})
