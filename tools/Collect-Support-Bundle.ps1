param(
  [Parameter(Mandatory=$true)][string]$TerminalData,
  [string]$BrokerProbe = '',
  [string]$AurumLog = '',
  [string]$Preset = '',
  [string]$OutputRoot = ''
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if($OutputRoot -eq ''){$OutputRoot=Join-Path $repo 'support'}
if(!(Test-Path -LiteralPath $TerminalData -PathType Container)){throw "Terminal data folder not found."}

function Get-Sha256([string]$Path){
  return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Redact-Line([string]$Line){
  $value=$Line
  $value=[regex]::Replace($value,'(?i)(account[_ ]?login|login)\s*[=:]\s*\d+','$1=[redacted]')
  $value=[regex]::Replace($value,'(?i)(password|secret|token|license(?:key)?|api[_-]?key|credential)\s*[=:]\s*[^|\s,;]+','$1=[redacted]')
  $value=[regex]::Replace($value,'(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b','[redacted-email]')
  return $value
}

if($BrokerProbe -eq ''){
  $probeDir=Join-Path $TerminalData 'MQL5\Files\AurumQuant'
  $latest=Get-ChildItem -LiteralPath $probeDir -Filter 'BrokerProbe-*.csv' -File -ErrorAction Stop |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  if($null -eq $latest){throw "No BrokerProbe CSV found under the terminal data folder."}
  $BrokerProbe=$latest.FullName
}
if(!(Test-Path -LiteralPath $BrokerProbe -PathType Leaf)){throw "Broker probe not found."}
$probeRows=@(Import-Csv -LiteralPath $BrokerProbe)
if($probeRows.Count -lt 1){throw 'Broker probe contains no rows.'}

if($AurumLog -eq ''){
  $logDir=Join-Path $TerminalData 'MQL5\Logs'
  if(Test-Path -LiteralPath $logDir -PathType Container){
    $latestLog=Get-ChildItem -LiteralPath $logDir -Filter '*.log' -File |
      Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if($null -ne $latestLog){$AurumLog=$latestLog.FullName}
  }
}
if($AurumLog -ne '' -and !(Test-Path -LiteralPath $AurumLog -PathType Leaf)){throw "Aurum log not found."}
if($Preset -ne '' -and !(Test-Path -LiteralPath $Preset -PathType Leaf)){throw "Preset not found."}

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$out=Join-Path $OutputRoot ('support-'+$stamp)
New-Item -ItemType Directory -Path $out -Force | Out-Null

$sanitizedProbe=Join-Path $out 'broker-probe-sanitized.csv'
$probeRows |
  Select-Object captured_gmt,terminal_build,account_server,broker_company,account_currency,
    account_trade_mode,account_margin_mode,leverage,symbol,status,error,digits,point,bid,ask,
    tick_size,tick_value,tick_value_profit,tick_value_loss,contract_size,volume_min,volume_max,
    volume_step,stops_level,freeze_level,symbol_trade_mode,swap_long,swap_short |
  Export-Csv -LiteralPath $sanitizedProbe -NoTypeInformation -Encoding UTF8

$includedLog=$false
if($AurumLog -ne ''){
  $lines=Get-Content -LiteralPath $AurumLog -ErrorAction Stop |
    Where-Object { $_ -match 'AURUM\|' } |
    Select-Object -Last 1000 |
    ForEach-Object { Redact-Line $_ }
  if($lines.Count -gt 0){
    $lines | Set-Content -LiteralPath (Join-Path $out 'aurum-log-sanitized.txt') -Encoding UTF8
    $includedLog=$true
  }
}

$includedPreset=$false
if($Preset -ne ''){
  $safe=@()
  foreach($line in Get-Content -LiteralPath $Preset){
    if($line -match '^\s*([^=]+)=(.*)$'){
      $key=$Matches[1].Trim()
      if($key -match '(?i)(password|secret|token|license|api.?key|credential)'){
        $safe += ($key+'=[redacted]')
      } else {
        $safe += (Redact-Line $line)
      }
    } else {
      $safe += (Redact-Line $line)
    }
  }
  $safe | Set-Content -LiteralPath (Join-Path $out 'preset-sanitized.set') -Encoding UTF8
  $includedPreset=$true
}

$items=@()
foreach($file in Get-ChildItem -LiteralPath $out -File){
  $items += [ordered]@{
    file=$file.Name
    bytes=$file.Length
    sha256=(Get-Sha256 $file.FullName)
  }
}
$commit=(git -C $repo rev-parse HEAD 2>$null)
$manifest=[ordered]@{
  schema_version=1
  product='Aurum Quant MT5'
  bundle_kind='customer-support-diagnostics'
  captured_utc=(Get-Date).ToUniversalTime().ToString('o')
  source_commit=$commit
  sanitized=$true
  raw_account_login_included=$false
  raw_terminal_path_included=$false
  aurum_log_included=$includedLog
  preset_included=$includedPreset
  files=$items
}
$manifestPath=Join-Path $out 'support-manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

$zip=$out+'.zip'
if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
Compress-Archive -Path (Join-Path $out '*') -DestinationPath $zip -CompressionLevel Optimal
Write-Output "PASS: privacy-safe support bundle created: $zip"
Write-Output 'Review the sanitized bundle before sharing it with support.'
