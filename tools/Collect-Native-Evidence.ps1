param(
  [Parameter(Mandatory=$true)][string]$TerminalData,
  [Parameter(Mandatory=$true)][string]$ValidationJournal,
  [string]$BrokerProbe = '',
  [string]$TesterReport = '',
  [string]$TesterJournal = '',
  [string]$OutputRoot = ''
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if($OutputRoot -eq ''){$OutputRoot=Join-Path $repo 'evidence'}
if(!(Test-Path -LiteralPath $TerminalData -PathType Container)){throw "Terminal data folder not found: $TerminalData"}
if(!(Test-Path -LiteralPath $ValidationJournal -PathType Leaf)){throw "Validation journal not found: $ValidationJournal"}

$compileLogs=@(
  (Join-Path $repo '.build\AurumQuantEA.log'),
  (Join-Path $repo '.build\AurumQuantValidation.log'),
  (Join-Path $repo '.build\AurumQuantBrokerProbe.log')
)
foreach($log in $compileLogs){
  if(!(Test-Path -LiteralPath $log -PathType Leaf)){throw "Required compile log missing: $log"}
  $text=Get-Content -LiteralPath $log -Raw
  if($text -notmatch 'Result: 0 errors, 0 warnings'){throw "Compile log is not clean: $log"}
}

$validation=Get-Content -LiteralPath $ValidationJournal -Raw
if($validation -notmatch 'AURUM\|SELF_TEST\|RESULT\|passed=78\|failed=0'){
  throw 'Validation journal does not contain passed=78|failed=0.'
}

if($BrokerProbe -eq ''){
  $probeDir=Join-Path $TerminalData 'MQL5\Files\AurumQuant'
  $latest=Get-ChildItem -LiteralPath $probeDir -Filter 'BrokerProbe-*.csv' -File -ErrorAction Stop |
    Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
  if($null -eq $latest){throw "No BrokerProbe CSV found under $probeDir"}
  $BrokerProbe=$latest.FullName
}
if(!(Test-Path -LiteralPath $BrokerProbe -PathType Leaf)){throw "Broker probe not found: $BrokerProbe"}
$probeRows=Import-Csv -LiteralPath $BrokerProbe
if($probeRows.Count -lt 1){throw 'Broker probe contains no symbol rows.'}
$bad=@($probeRows | Where-Object { $_.status -ne 'OK' })
if($bad.Count -gt 0){throw "Broker probe contains $($bad.Count) non-OK row(s)."}

$optional=@()
if($TesterReport -ne ''){
  if(!(Test-Path -LiteralPath $TesterReport -PathType Leaf)){throw "Tester report not found: $TesterReport"}
  $optional += $TesterReport
}
if($TesterJournal -ne ''){
  if(!(Test-Path -LiteralPath $TesterJournal -PathType Leaf)){throw "Tester journal not found: $TesterJournal"}
  $optional += $TesterJournal
}

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$out=Join-Path $OutputRoot ('native-'+$stamp)
New-Item -ItemType Directory -Path $out -Force | Out-Null

$inputs=@($compileLogs)+@($ValidationJournal,$BrokerProbe)+$optional
$items=@()
$index=0
foreach($source in $inputs){
  $index++
  $leaf=[IO.Path]::GetFileName($source)
  $dest=Join-Path $out ('{0:D2}-{1}' -f $index,$leaf)
  Copy-Item -LiteralPath $source -Destination $dest -Force
  $hash=(Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
  $items += [ordered]@{
    source=$source
    file=[IO.Path]::GetFileName($dest)
    bytes=(Get-Item -LiteralPath $dest).Length
    sha256=$hash
  }
}

$manifest=[ordered]@{
  schema_version=1
  product='Aurum Quant MT5'
  evidence_kind='native-validation-evidence'
  captured_utc=(Get-Date).ToUniversalTime().ToString('o')
  source_commit=(git -C $repo rev-parse HEAD 2>$null)
  terminal_data=$TerminalData
  required_native_self_test='passed=78|failed=0'
  compile_result='0 errors, 0 warnings'
  broker_probe_symbols=@($probeRows | ForEach-Object { $_.symbol })
  tester_report_included=($TesterReport -ne '')
  tester_journal_included=($TesterJournal -ne '')
  files=$items
}
$manifestPath=Join-Path $out 'evidence-manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
Write-Output "PASS: native evidence collected at $out"
Write-Output "PASS: $($probeRows.Count) broker symbol row(s), 3 clean compiler logs, native self-test 78/0"
