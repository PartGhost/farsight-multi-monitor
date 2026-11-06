param(
	[Parameter(Mandatory)]
	[string]$AddOns
)

$ErrorActionPreference = 'Stop'

$addon = 'FarsightMultiMonitor'
$target = Join-Path $AddOns $addon
$dist = Join-Path $PSScriptRoot 'dist'
$csc = Join-Path ([Runtime.InteropServices.RuntimeEnvironment]::GetRuntimeDirectory()) 'csc.exe'

New-Item -ItemType Directory -Force $target, $dist | Out-Null
Copy-Item (Join-Path $PSScriptRoot "$addon\*") $target

& $csc /nologo /target:winexe /platform:x64 /optimize+ /r:System.Windows.Forms.dll /r:System.Drawing.dll "/out:$(Join-Path $dist 'Farsight.exe')" (Join-Path $PSScriptRoot 'launcher\Farsight.cs')
if ($LASTEXITCODE -ne 0) {
	throw 'Launcher build failed'
}
