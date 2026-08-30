param(
  [string]$MetaEditor = 'C:\Program Files\MetaTrader 5\MetaEditor64.exe',
  [string]$TerminalData = 'C:\Users\taosh\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075'
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stage=Join-Path $repo '.build\MQL5'
New-Item -ItemType Directory -Path (Join-Path $stage 'Include') -Force | Out-Null
Copy-Item -Path (Join-Path $TerminalData 'MQL5\Include\*') -Destination (Join-Path $stage 'Include') -Recurse -Force
Copy-Item -Path (Join-Path $repo 'Include\AurumQuant\*') -Destination (Join-Path $stage 'Include\AurumQuant') -Recurse -Force
$targets=@('Experts\AurumQuantEA.mq5','Tests\AurumQuantValidation.mq5')
foreach($relative in $targets){
  $source=Join-Path $repo $relative
  $log=Join-Path $repo ('.build\'+[IO.Path]::GetFileNameWithoutExtension($source)+'.log')
  $arguments=@('/compile:"'+$source+'"','/inc:"'+$stage+'"','/log:"'+$log+'"')
  $process=Start-Process -FilePath $MetaEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
  $output=Get-Content -LiteralPath $log -Raw
  Write-Output $output
  if($output -notmatch 'Result: 0 errors, 0 warnings'){throw "MQL5 compilation failed for $relative (MetaEditor exit $($process.ExitCode))"}
}
