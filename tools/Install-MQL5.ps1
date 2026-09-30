param(
  [Parameter(Mandatory=$true)][string]$TerminalData
)
$ErrorActionPreference='Stop'
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mql=Join-Path $TerminalData 'MQL5'
if(!(Test-Path -LiteralPath $mql -PathType Container)){throw 'Select the MT5 data folder from File > Open Data Folder.'}
$backup=Join-Path $repo ('.build\backup-'+(Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
$items=@(
 @{Source='Experts\AurumQuantEA.mq5';Target='Experts\AurumQuantEA.mq5'},
 @{Source='Include\AurumQuant';Target='Include\AurumQuant'},
 @{Source='Tests\AurumQuantValidation.mq5';Target='Scripts\AurumQuantValidation.mq5'},
 @{Source='Tests\AurumQuantBrokerProbe.mq5';Target='Scripts\AurumQuantBrokerProbe.mq5'},
 @{Source='Presets';Target='Presets\AurumQuant'}
)
foreach($item in $items){
 $source=Join-Path $repo $item.Source
 $target=Join-Path $mql $item.Target
 if(Test-Path -LiteralPath $target){
  $saved=Join-Path $backup $item.Target
  New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $target -Destination $saved -Recurse -Force
 }
 New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
 if(Test-Path -LiteralPath $source -PathType Container){
  New-Item -ItemType Directory -Path $target -Force | Out-Null
  Copy-Item -Path (Join-Path $source '*') -Destination $target -Recurse -Force
 }else{Copy-Item -LiteralPath $source -Destination $target -Force}
}
Write-Output "Source installed. Existing files backed up under $backup."
Write-Output 'Compile the installed EA, validation script, and broker probe in MetaEditor. Load an OBSERVE preset before attaching.'
