[CmdletBinding()]
param([Parameter(Mandatory)][string]$EngineDirectory, [Parameter(Mandatory)][string]$DotnetPath, [string]$RuntimeDotnetPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$engine = (Resolve-Path -LiteralPath $EngineDirectory).Path
$dotnet = (Resolve-Path -LiteralPath $DotnetPath).Path
$env:DOTNET_ROOT = Split-Path -Parent $dotnet
$env:DOTNET_CLI_HOME = Join-Path $root 'local/dotnet-home'
$env:NUGET_PACKAGES = Join-Path $root 'local/nuget'
$work = Join-Path $root ('local/game-resource-check/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work -Force
$engineXml = [Security.SecurityElement]::Escape($engine)
$sourceXml = [Security.SecurityElement]::Escape((Join-Path $PSScriptRoot 'CheckGameResourcePayloads.cs'))
@"
<Project Sdk="Microsoft.NET.Sdk">
 <PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net6.0</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup>
 <ItemGroup>
  <Compile Include="$sourceXml" />
  <Reference Include="OpenRA.Game"><HintPath>$engineXml/OpenRA.Game.dll</HintPath></Reference>
 </ItemGroup>
</Project>
"@ | Set-Content -LiteralPath (Join-Path $work 'ResourceCheck.csproj') -Encoding utf8
& $dotnet build (Join-Path $work 'ResourceCheck.csproj') -c Release --nologo *> (Join-Path $root 'reports/resource-payload-build.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Resource payload checker build failed.' }
$output = Join-Path $work 'bin/Release/net6.0'
Get-ChildItem -LiteralPath $engine -File | Where-Object { $_.Extension -eq '.dll' -or $_.Name -like '*.deps.json' } | Copy-Item -Destination $output
# Reviewed CPU entry: only ModData, rules, VXL/HVA, PCM streams and font headers; no World or device creation.
$runtime = if ($RuntimeDotnetPath) { (Resolve-Path -LiteralPath $RuntimeDotnetPath).Path } else { $dotnet }
& $runtime (Join-Path $work 'bin/Release/net6.0/ResourceCheck.dll') $engine (Join-Path $root 'local/support') *> (Join-Path $root 'reports/resource-payloads.local.json')
if ($LASTEXITCODE -ne 0) { throw 'Resource payload checks reported failures; see local report.' }
Write-Output 'Resource payload decoding checks passed; detailed local report records exact scope.'
