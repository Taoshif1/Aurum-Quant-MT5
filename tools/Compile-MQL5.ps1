param(
  [string]$MetaEditor = 'C:\Program Files\MetaTrader 5\MetaEditor64.exe',
  [Parameter(Mandatory=$true)][string]$TerminalData
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$stage=Join-Path $repo '.build\MQL5'
if(!(Test-Path -LiteralPath $MetaEditor -PathType Leaf)){throw "MetaEditor not found: $MetaEditor"}
$standard=Join-Path $TerminalData 'MQL5\Include'
if(!(Test-Path -LiteralPath (Join-Path $standard 'Trade\Trade.mqh'))){throw 'Official MQL5 standard library missing from the selected terminal.'}
New-Item -ItemType Directory -Path (Join-Path $stage 'Include\AurumQuant') -Force | Out-Null
Copy-Item -Path (Join-Path $standard '*') -Destination (Join-Path $stage 'Include') -Recurse -Force
Copy-Item -Path (Join-Path $repo 'Include\AurumQuant\*') -Destination (Join-Path $stage 'Include\AurumQuant') -Recurse -Force
$targets=@('Experts\AurumQuantEA.mq5','Tests\AurumQuantValidation.mq5','Tests\AurumQuantBrokerProbe.mq5')
foreach($relative in $targets){
 $source=Join-Path $repo $relative
 $log=Join-Path $repo ('.build\'+[IO.Path]::GetFileNameWithoutExtension($source)+'.log')
 $binary=[IO.Path]::ChangeExtension($source,'.ex5')
 # Never accept a stale success log or an old binary.
 if(Test-Path -LiteralPath $log){Remove-Item -LiteralPath $log -Force}
 if(Test-Path -LiteralPath $binary){Remove-Item -LiteralPath $binary -Force}
 $arguments=@('/compile:"'+$source+'"','/inc:"'+$stage+'"','/log:"'+$log+'"')
 $process=Start-Process -FilePath $MetaEditor -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
 if(!(Test-Path -LiteralPath $log)){throw "Compiler did not produce a log for $relative"}
 $output=Get-Content -LiteralPath $log -Raw
 Write-Output $output
 if($output -notmatch 'Result: 0 errors, 0 warnings' -or !(Test-Path -LiteralPath $binary)){
  throw "MQL5 compilation failed for $relative (MetaEditor exit $($process.ExitCode))"
 }
}
