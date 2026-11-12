[CmdletBinding()]
param([Parameter(Mandatory)][string]$ModDirectory, [Parameter(Mandatory)][string]$DotnetPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mod = (Resolve-Path -LiteralPath $ModDirectory).Path
$dotnet = (Resolve-Path -LiteralPath $DotnetPath).Path
$env:DOTNET_ROOT = Split-Path -Parent $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root 'local/dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:DOTNET_ADD_GLOBAL_TOOLS_TO_PATH = 'false'
$env:NUGET_PACKAGES = Join-Path $root 'local/nuget'
$null = New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force
foreach ($entry in @(@('engine','engine/OpenRA.sln'), @('mod','OpenRA.Mods.RA2.sln'))) {
    & $dotnet build (Join-Path $mod $entry[1]) -c Release --nologo -p:TargetPlatform=win-x64 *> (Join-Path $root "reports/build-$($entry[0]).local.log")
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $($entry[0]); see local log." }
}
$env:ENGINE_DIR = Join-Path $mod 'engine'
$env:MOD_SEARCH_PATHS = "$mod/mods,$mod/engine/mods"
& $dotnet (Join-Path $mod 'engine/bin/OpenRA.Utility.dll') ra2 --check-yaml *> (Join-Path $root 'reports/check-yaml.local.log')
if ($LASTEXITCODE -ne 0) { throw 'YAML validation failed; see local log.' }
