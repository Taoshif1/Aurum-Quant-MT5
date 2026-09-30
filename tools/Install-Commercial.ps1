param(
  [Parameter(Mandatory=$true)][string]$TerminalData
)
$ErrorActionPreference='Stop'
$root=(Resolve-Path $PSScriptRoot).Path
$mql=Join-Path $TerminalData 'MQL5'
if(!(Test-Path -LiteralPath $mql -PathType Container)){throw 'Select the MT5 data folder from File > Open Data Folder.'}

$stamp=Get-Date -Format 'yyyyMMdd-HHmmss-fff'
$backup=Join-Path $TerminalData ('AurumQuantBackup\'+$stamp)
$items=@(
  @{Source='Experts\AurumQuantEA.ex5';Target='Experts\AurumQuantEA.ex5'},
  @{Source='Scripts\AurumQuantValidation.ex5';Target='Scripts\AurumQuantValidation.ex5'},
  @{Source='Scripts\AurumQuantBrokerProbe.ex5';Target='Scripts\AurumQuantBrokerProbe.ex5'}
)
foreach($item in $items){
  $source=Join-Path $root $item.Source
  if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw "Package file missing: $($item.Source)"}
  $target=Join-Path $mql $item.Target
  if(Test-Path -LiteralPath $target -PathType Leaf){
    $saved=Join-Path $backup $item.Target
    New-Item -ItemType Directory -Path (Split-Path $saved -Parent) -Force | Out-Null
    Copy-Item -LiteralPath $target -Destination $saved -Force
  }
  New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
  Copy-Item -LiteralPath $source -Destination $target -Force
}

$presetSource=Join-Path $root 'Presets'
$presetTarget=Join-Path $mql 'Presets\AurumQuant'
if(!(Test-Path -LiteralPath $presetSource -PathType Container)){throw 'Package Presets folder missing.'}
if(Test-Path -LiteralPath $presetTarget -PathType Container){
  $saved=Join-Path $backup 'Presets\AurumQuant'
  New-Item -ItemType Directory -Path $saved -Force | Out-Null
  Copy-Item -Path (Join-Path $presetTarget '*') -Destination $saved -Recurse -Force
}
New-Item -ItemType Directory -Path $presetTarget -Force | Out-Null
Copy-Item -Path (Join-Path $presetSource '*') -Destination $presetTarget -Force

Write-Output 'PASS: Aurum Quant commercial candidate installed.'
Write-Output "Existing files, if any, were backed up under: $backup"
Write-Output 'Start with an OBSERVE preset. Do not enable submission until your broker/demo validation is complete.'
