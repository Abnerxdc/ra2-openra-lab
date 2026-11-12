[CmdletBinding()]
param([Parameter(Mandatory)][string]$PayloadDirectory, [Parameter(Mandatory)][string]$DotnetPath)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$payload = (Resolve-Path -LiteralPath $PayloadDirectory).Path
$engine = Join-Path $payload 'engine'
$runtime = Join-Path $payload 'runtime/dotnet.exe'
$forbidden = Get-ChildItem -LiteralPath $payload -File -Recurse | Where-Object {
    $_.Extension -in @('.mix','.pdb','.log','.user') -or $_.Name -match '^(OpenRA\.Test|nunit|NUnit|testhost|Microsoft\.TestPlatform)'
}
if ($forbidden) { throw 'Disallowed development or original resource files in payload.' }
Get-ChildItem -LiteralPath $payload -Recurse -File -Filter '*.zip' | ForEach-Object {
    $zip = [IO.Compression.ZipFile]::OpenRead($_.FullName)
    try {
        if ($zip.Entries | Where-Object { $_.FullName -match '\.(mix|exe|dll|pdb)$' }) { throw 'Binary or MIX entries embedded in a source ZIP.' }
    } finally { $zip.Dispose() }
}
$needles = @($root, [Environment]::GetFolderPath('UserProfile'))
Get-ChildItem -LiteralPath $payload -File -Recurse | Where-Object { $_.Extension -in @('.exe','.dll','.json','.cs','.txt','.yaml') } | ForEach-Object {
    $bytes = [IO.File]::ReadAllBytes($_.FullName)
    $utf8 = [Text.Encoding]::UTF8.GetString($bytes)
    $utf16 = [Text.Encoding]::Unicode.GetString($bytes)
    foreach ($needle in $needles) {
        if ($utf8.Contains($needle) -or $utf16.Contains($needle)) { throw 'Development path embedded in payload; rebuild with path mapping and without debug records.' }
    }
}
foreach ($name in @('OpenRA.Mods.Common','OpenRA.Mods.Cnc','OpenRA.Mods.RA2','OpenRA.Platforms.Default')) {
    foreach ($suffix in @('.dll','.deps.json')) {
        if (!(Test-Path -LiteralPath (Join-Path $engine ($name + $suffix)))) { throw "Missing runtime dependency: $name$suffix" }
    }
}
& $runtime --list-runtimes *> (Join-Path $root 'reports/package-runtime.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Bundled runtime cannot execute.' }
$runtimes = Get-Content -LiteralPath (Join-Path $root 'reports/package-runtime.local.log') -Raw
if ($runtimes -notmatch 'Microsoft.NETCore.App 6.0.36') { throw 'Unexpected bundled runtime.' }
$sdks = & $runtime --list-sdks
if ($LASTEXITCODE -ne 0 -or $sdks) { throw 'Runtime payload unexpectedly contains an SDK.' }
$checkRoot = Join-Path $root ('local/package-check/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $checkRoot
Copy-Item -LiteralPath (Join-Path $engine 'mods/ra2') -Destination $checkRoot -Recurse
$mod = Join-Path $checkRoot 'ra2'
$manifestPath = Join-Path $mod 'mod.yaml'
$relative = [IO.Path]::GetRelativePath($engine, (Join-Path $root 'local/support/Content/ra2')).Replace('\','/')
$manifest = (Get-Content -LiteralPath $manifestPath -Raw).Replace('~^SupportDir|Content/ra2', "~^EngineDir|$relative")
Set-Content -LiteralPath $manifestPath -Value $manifest -Encoding utf8
$env:ENGINE_DIR = $engine
$env:MOD_SEARCH_PATHS = "$checkRoot,$engine/mods"
$env:TREAT_WARNINGS_AS_ERRORS = 'true'
foreach ($command in @('check-yaml','check-missing-sprites')) {
    & $runtime (Join-Path $engine 'OpenRA.Utility.dll') $mod "--$command" *> (Join-Path $root "reports/package-$command.local.log")
    if ($LASTEXITCODE -ne 0) { throw "Packaged engine $command failed." }
}
& (Join-Path $PSScriptRoot 'Test-GameResourcePayloads.ps1') -EngineDirectory $engine -DotnetPath $DotnetPath -RuntimeDotnetPath $runtime
if ($LASTEXITCODE -ne 0) { throw 'Packaged payload audit failed.' }
Write-Output 'Packaged runtime, YAML, sprites, models and declared audio checks passed. No game, installer or device initialization.'
