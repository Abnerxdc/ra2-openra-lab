[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ModDirectory,
    [Parameter(Mandatory)][string]$DotnetPath,
    [Parameter(Mandatory)][string]$MakeNsisPath
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$mod = (Resolve-Path -LiteralPath $ModDirectory).Path
$dotnet = (Resolve-Path -LiteralPath $DotnetPath).Path
$nsis = (Resolve-Path -LiteralPath $MakeNsisPath).Path
$sdk = Split-Path -Parent $dotnet
$engine = Join-Path $mod 'engine'
$env:DOTNET_ROOT = $sdk
$env:DOTNET_CLI_HOME = Join-Path $root 'local/dotnet-home'
$env:NUGET_PACKAGES = Join-Path $root 'local/nuget'
$env:DOTNET_CLI_TELEMETRY_OPTOUT = '1'
$null = New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force
$build = Join-Path $root ('local/windows-package/' + [guid]::NewGuid().ToString('N'))
$payload = Join-Path $build 'payload'
$null = New-Item -ItemType Directory -Path (Join-Path $payload 'engine') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $payload 'runtime') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $payload 'licenses') -Force
$null = New-Item -ItemType Directory -Path (Join-Path $payload 'sources') -Force
$releaseFlags = @('-c','Release','--nologo','-t:Rebuild','-p:TargetPlatform=win-x64','-p:DebugType=None','-p:DebugSymbols=false',"-p:PathMap=$root=/_/project")
foreach ($entry in @(@('engine','engine/OpenRA.sln'), @('mod','OpenRA.Mods.RA2.sln'))) {
    & $dotnet build (Join-Path $mod $entry[1]) @releaseFlags *> (Join-Path $root "reports/package-$($entry[0])-build.local.log")
    if ($LASTEXITCODE -ne 0) { throw "Release package build failed: $($entry[0])" }
}
& $dotnet build (Join-Path $engine 'OpenRA.WindowsLauncher/OpenRA.WindowsLauncher.csproj') @releaseFlags -p:LauncherName=RA2Engine -p:ModID=ra2 -p:DisplayName=RA2Lab *> (Join-Path $root 'reports/package-launcher-build.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Windows launcher build failed.' }
# Release runtime dependency assemblies only; no tests, PDBs, logs or development executables.
$excluded = '^(OpenRA\.Test|OpenRA\.Mods\.D2k|Microsoft\.TestPlatform|Microsoft\.VisualStudio|testhost|testcentric|nunit|NUnit|NuGet\.Frameworks)'
Get-ChildItem -LiteralPath (Join-Path $engine 'bin') -File | Where-Object {
    $_.Name -notmatch $excluded -and
    ($_.Extension -eq '.dll' -or $_.Name -match '\.dll\.config$' -or $_.Name -like '*.deps.json' -or $_.Name -match '^(RA2Engine|OpenRA\.Utility)\.(exe|runtimeconfig\.json)$')
} | Copy-Item -Destination (Join-Path $payload 'engine')
foreach ($name in @('glsl','VERSION','global mix database.dat')) {
    Copy-Item -LiteralPath (Join-Path $engine $name) -Destination (Join-Path $payload 'engine') -Recurse
}
$mods = Join-Path $payload 'engine/mods'
$null = New-Item -ItemType Directory -Path $mods
foreach ($name in @('common','modcontent')) { Copy-Item -LiteralPath (Join-Path $engine "mods/$name") -Destination $mods -Recurse }
Copy-Item -LiteralPath (Join-Path $mod 'mods/ra2') -Destination $mods -Recurse
Copy-Item -LiteralPath (Join-Path $root 'patches/ra2') -Destination (Join-Path $mods 'ra2/lab-compat') -Recurse
$manifestPath = Join-Path $mods 'ra2/mod.yaml'
$manifest = (Get-Content -LiteralPath $manifestPath -Raw).Replace('{DEV_VERSION}', 'ra2lab-preview-0.1')
$manifest = $manifest.Replace('ra2|audio/voices.yaml', "ra2|audio/voices.yaml`n`tra2|lab-compat/voices.yaml")
$manifest = $manifest.Replace('ra2|weapons/zaps.yaml', "ra2|weapons/zaps.yaml`n`tra2|lab-compat/weapons.yaml")
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding utf8
# Bundle only the runtime from the official local SDK, never the SDK itself.
Copy-Item -LiteralPath $dotnet -Destination (Join-Path $payload 'runtime/dotnet.exe')
Copy-Item -LiteralPath (Join-Path $sdk 'host') -Destination (Join-Path $payload 'runtime/host') -Recurse
$null = New-Item -ItemType Directory -Path (Join-Path $payload 'runtime/shared')
Copy-Item -LiteralPath (Join-Path $sdk 'shared/Microsoft.NETCore.App') -Destination (Join-Path $payload 'runtime/shared/Microsoft.NETCore.App') -Recurse
Copy-Item -LiteralPath (Join-Path $sdk 'LICENSE.txt') -Destination (Join-Path $payload 'licenses/Dotnet-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $sdk 'ThirdPartyNotices.txt') -Destination (Join-Path $payload 'licenses/Dotnet-ThirdPartyNotices.txt')
Copy-Item -LiteralPath (Join-Path $engine 'COPYING') -Destination (Join-Path $payload 'licenses/OpenRA-COPYING')
Copy-Item -LiteralPath (Join-Path $engine 'AUTHORS') -Destination (Join-Path $payload 'licenses/OpenRA-AUTHORS')
Copy-Item -LiteralPath (Join-Path $mod 'LICENSE') -Destination (Join-Path $payload 'licenses/RA2-LICENSE')
Copy-Item -LiteralPath (Join-Path $mod 'mods/ra2/CREDITS') -Destination (Join-Path $payload 'licenses/RA2-CREDITS')
Copy-Item -LiteralPath (Join-Path (Split-Path -Parent $nsis) 'COPYING') -Destination (Join-Path $payload 'licenses/NSIS-COPYING')
Copy-Item -LiteralPath (Join-Path $root 'local/engine-source.zip') -Destination (Join-Path $payload 'sources/OpenRA-release-20231010.zip')
Copy-Item -LiteralPath (Join-Path $root 'local/ra2-source.zip') -Destination (Join-Path $payload 'sources/RA2-61e24e3.zip')
Copy-Item -LiteralPath (Join-Path $root 'packaging/windows/Bootstrap.cs') -Destination (Join-Path $payload 'sources/Bootstrap.cs')
Copy-Item -LiteralPath (Join-Path $root 'packaging/windows/installer.nsi') -Destination (Join-Path $payload 'sources/installer.nsi')
Copy-Item -LiteralPath (Join-Path $root 'packaging/windows/USER-GUIDE.txt') -Destination $payload
# Keep available license/notice metadata for dependency packages; no package binaries here.
$notices = Join-Path $payload 'licenses/dependencies'
$null = New-Item -ItemType Directory -Path $notices
$noticeIndex = [Collections.Generic.List[string]]::new()
Get-ChildItem -LiteralPath (Join-Path $root 'local/nuget') -Directory | Where-Object { $_.Name -notmatch 'test|nunit|codecoverage|nuget\.commandline|stylecop' } | ForEach-Object {
    $package = $_
    Get-ChildItem -LiteralPath $package.FullName -File -Recurse | Where-Object { $_.Name -match '^(LICENSE|COPYING|NOTICE|THIRD.PARTY)' -or $_.Extension -eq '.nuspec' } | ForEach-Object {
        $relative = [IO.Path]::GetRelativePath($package.FullName, $_.FullName)
        # Flatten long NuGet names for the NSIS compiler's Windows path limit.
        $leaf = 'notice-{0:D4}{1}' -f $noticeIndex.Count, $(if ($_.Extension -eq '.nuspec') { '.nuspec' } else { '.txt' })
        $noticeIndex.Add("$leaf`t$($package.Name)/$relative")
        $target = Join-Path $notices $leaf
        Copy-Item -LiteralPath $_.FullName -Destination $target
    }
}
$noticeIndex | Set-Content -LiteralPath (Join-Path $notices 'index.txt') -Encoding utf8
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $csc /nologo /codepage:65001 /target:winexe /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ("/out:" + (Join-Path $payload 'RA2Lab.exe')) (Join-Path $root 'packaging/windows/Bootstrap.cs') *> (Join-Path $root 'reports/package-bootstrap-build.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Resource bootstrap compilation failed.' }
# The installer payload is always proprietary-MIX-free.
if (Get-ChildItem -LiteralPath $payload -Recurse -File -Filter '*.mix') { throw 'Refusing to package original MIX resources.' }
if (Get-ChildItem -LiteralPath $payload -Recurse -File | Where-Object { $_.Extension -in @('.pdb','.log','.user','.env') }) { throw 'Development files detected in payload.' }
& (Join-Path $PSScriptRoot 'Test-WindowsPayload.ps1') -PayloadDirectory $payload -DotnetPath $dotnet
$owned = Join-Path $build 'owned-files.nsh'
$lines = @()
Get-ChildItem -LiteralPath $payload -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($payload, $_.FullName)
    if ($relative.Contains('$') -or $relative.Contains('"')) { throw 'Unsafe NSIS filename.' }
    $lines += 'Delete "$INSTDIR\' + $relative + '"'
}
Get-ChildItem -LiteralPath $payload -Recurse -Directory | Sort-Object { $_.FullName.Length } -Descending | ForEach-Object {
    $lines += 'RMDir "$INSTDIR\' + [IO.Path]::GetRelativePath($payload, $_.FullName) + '"'
}
$lines | Set-Content -LiteralPath $owned -Encoding utf8BOM
$output = Join-Path $build 'RA2Lab-0.1.0-preview-win-x64-setup.exe'
& $nsis /V3 ("/DPAYLOAD_DIR=$payload") ("/DOUTPUT_FILE=$output") ("/DOWNED_FILES=$owned") (Join-Path $root 'packaging/windows/installer.nsi') *> (Join-Path $root 'reports/package-nsis-build.local.log')
if ($LASTEXITCODE -ne 0) { throw 'NSIS package compilation failed.' }
(Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash | Set-Content -LiteralPath ($output + '.sha256') -Encoding ascii
@{ Payload=$payload; Installer=$output; Scope='Preview build; installer and game not executed; acceptance pending' } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports/windows-package.local.json') -Encoding utf8
Write-Output 'Windows preview installer compiled. Local report records artifact location and SHA-256; runtime acceptance pending.'
