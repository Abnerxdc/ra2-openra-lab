[CmdletBinding()]
param([Parameter(Mandatory)][string]$ModDirectory, [Parameter(Mandatory)][string]$DotnetPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mod = (Resolve-Path -LiteralPath $ModDirectory).Path
$dotnet = (Resolve-Path -LiteralPath $DotnetPath).Path
$engine = Join-Path $mod 'engine'
if (!(Test-Path -LiteralPath (Join-Path $engine 'bin/OpenRA.Utility.dll'))) { throw 'Build the pinned upstream first.' }
# Each run gets a fresh ignored stage. Never edit or delete upstream or a previous stage.
$stage = Join-Path $root ('local/stormline-stage/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $stage
Copy-Item -LiteralPath (Join-Path $mod 'mods/ra2') -Destination $stage -Recurse
$stagedMod = Join-Path $stage 'ra2'
Copy-Item -LiteralPath (Join-Path $root 'stormline/prototype') -Destination (Join-Path $stagedMod 'stormline') -Recurse
$manifestPath = Join-Path $stagedMod 'mod.yaml'
$manifest = Get-Content -LiteralPath $manifestPath -Raw
$manifest = $manifest.Replace('Title: Red Alert 2', 'Title: Stormline Prototype (RA2 overlay)')
foreach ($section in @(@('Rules','rules'), @('Sequences','sequences'), @('Weapons','weapons'))) {
    $pattern = '(?m)^' + $section[0] + ':\r?$'
    if (!([regex]::IsMatch($manifest, $pattern))) { throw 'Unexpected pinned manifest structure.' }
    $manifest = [regex]::Replace($manifest, $pattern, ($section[0] + ":`n`tra2|stormline/" + $section[1] + '.yaml'))
}
$manifest = [regex]::Replace($manifest, '(?m)^\tra2\|uibits\r?$', "`tra2|uibits`n`tra2|stormline/art")
# Only mount the project-local copy of proprietary content; do not reference platform files.
$content = [IO.Path]::GetRelativePath($engine, (Join-Path $root 'local/support/Content/ra2')).Replace('\','/')
# A drive-letter colon is parsed as a YAML key/value delimiter by MiniYaml.
$manifest = $manifest.Replace('~^SupportDir|Content/ra2', "~^EngineDir|$content")
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding utf8
$env:DOTNET_ROOT = Split-Path -Parent $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root 'local/dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:NUGET_PACKAGES = Join-Path $root 'local/nuget'
$env:ENGINE_DIR = $engine
$env:MOD_SEARCH_PATHS = "$stage,$mod/mods,$engine/mods"
$env:TREAT_WARNINGS_AS_ERRORS = 'true'
$null = New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force
$log = Join-Path $root 'reports/stormline-check-yaml.local.log'
# Entry reviewed: Utility dispatches CheckYaml directly; no client, renderer or sound initialization.
& $dotnet (Join-Path $engine 'bin/OpenRA.Utility.dll') $stagedMod --check-yaml *> $log
if ($LASTEXITCODE -ne 0) { throw 'Prototype YAML validation failed; see local log.' }
$checker = Join-Path $root 'local/stormline-sprite-check'
$null = New-Item -ItemType Directory -Path $checker -Force
$engineBin = [System.Security.SecurityElement]::Escape((Join-Path $engine 'bin'))
$checkerSource = [System.Security.SecurityElement]::Escape((Join-Path $PSScriptRoot 'CheckPrototypeSprites.cs'))
@"
<Project Sdk="Microsoft.NET.Sdk">
 <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup>
 <ItemGroup>
  <Compile Include="$checkerSource" />
  <Reference Include="OpenRA.Game"><HintPath>$engineBin/OpenRA.Game.dll</HintPath></Reference>
  <Reference Include="OpenRA.Mods.Common"><HintPath>$engineBin/OpenRA.Mods.Common.dll</HintPath></Reference>
 </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $checker 'Checker.csproj') -Encoding utf8
& $dotnet build (Join-Path $checker 'Checker.csproj') -c Release --nologo *> (Join-Path $root 'reports/stormline-sprite-build.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Sprite checker build failed; see local report.' }
$art = Join-Path $stagedMod 'stormline/art'
& $dotnet (Join-Path $checker 'bin/Release/net6.0/Checker.dll') (Join-Path $art 'dc_prism.png') (Join-Path $art 'cu_anvil.png') *> (Join-Path $root 'reports/stormline-sprites.local.json')
if ($LASTEXITCODE -ne 0) { throw 'Sprite decoding failed; see local report.' }
@{ Stage=$stagedMod; Scope='YAML and CPU PNG decoding only; not rendering, audio or complete-match validation' } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports/stormline-stage.local.json') -Encoding utf8
Write-Output 'Stormline prototype YAML and CPU PNG decoding validation completed. Stage and detailed logs stay local.'
