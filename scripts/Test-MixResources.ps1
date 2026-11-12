[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModDirectory,
    [Parameter(Mandatory)][string]$DotnetPath,
    [Parameter(Mandatory)][string[]]$ResourceFiles
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mod = (Resolve-Path -LiteralPath $ModDirectory).Path
$dotnet = (Resolve-Path -LiteralPath $DotnetPath).Path
$inputs = @($ResourceFiles | ForEach-Object { (Resolve-Path -LiteralPath $_).Path })
$env:DOTNET_ROOT = Split-Path -Parent $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root 'local/dotnet-home'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$env:NUGET_PACKAGES = Join-Path $root 'local/nuget'
$work = Join-Path $root 'local/mix-validator'
$null = New-Item -ItemType Directory -Path $work -Force
$null = New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force
# XML escape user-supplied paths; no shell-generated command lines.
$engineBin = [System.Security.SecurityElement]::Escape((Join-Path $mod 'engine/bin'))
$source = [System.Security.SecurityElement]::Escape((Join-Path $PSScriptRoot 'MixStructureCheck.cs'))
@"
<Project Sdk="Microsoft.NET.Sdk">
 <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup>
 <ItemGroup>
  <Compile Include="$source" />
  <Reference Include="OpenRA.Game"><HintPath>$engineBin/OpenRA.Game.dll</HintPath></Reference>
  <Reference Include="OpenRA.Mods.Cnc"><HintPath>$engineBin/OpenRA.Mods.Cnc.dll</HintPath></Reference>
 </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $work 'Validator.csproj') -Encoding utf8
& $dotnet build (Join-Path $work 'Validator.csproj') -c Release --nologo *> (Join-Path $root 'reports/build-mix-validator.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Validator build failed; see local report.' }
& $dotnet (Join-Path $work 'bin/Release/net6.0/Validator.dll') @inputs > (Join-Path $root 'reports/mix-validation.local.json')
if ($LASTEXITCODE -ne 0) { throw 'MIX validation failed; see local report.' }
Write-Output 'MIX index and known nested package checks completed; detailed report stays local.'
