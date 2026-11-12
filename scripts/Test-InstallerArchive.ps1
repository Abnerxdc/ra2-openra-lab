[CmdletBinding()]
param([Parameter(Mandatory)][string]$InstallerPath, [Parameter(Mandatory)][string]$PayloadDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$payload = (Resolve-Path -LiteralPath $PayloadDirectory).Path
$destination = Join-Path $root ('local/installer-audit/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $destination
# 7z parses the installer as an archive. It never invokes its PE entry point.
& 7z t $installer *> (Join-Path $destination 'archive-test.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Installer archive integrity check failed.' }
& 7z x $installer ("-o$destination/extracted") -y *> (Join-Path $destination 'archive-extract.local.log')
if ($LASTEXITCODE -ne 0) { throw 'Installer static extraction failed.' }
$count = 0
Get-ChildItem -LiteralPath $payload -Recurse -File | ForEach-Object {
    $relative = [IO.Path]::GetRelativePath($payload, $_.FullName)
    $extracted = Join-Path $destination (Join-Path 'extracted' $relative)
    if (!(Test-Path -LiteralPath $extracted -PathType Leaf)) { throw "Installer omitted payload file: $relative" }
    if ((Get-FileHash -LiteralPath $_.FullName).Hash -ne (Get-FileHash -LiteralPath $extracted).Hash) {
        throw "Installer file bytes differ: $relative"
    }
    $count++
}
@{ PayloadFilesCompared=$count; InstallerSHA256=(Get-FileHash -LiteralPath $installer).Hash;
    Scope='Static archive CRC/extraction and file hashes only; not installation or uninstall execution' } |
    ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports/installer-archive-audit.local.json') -Encoding utf8
Write-Output "Installer static audit passed: $count payload files match. Installer was not executed."
