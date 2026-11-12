[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceDirectory
)
$ErrorActionPreference = 'Stop'
$resourceRoot = (Resolve-Path -LiteralPath $ResourceDirectory).Path
if (-not (Test-Path -LiteralPath $resourceRoot -PathType Container)) {
    throw 'ResourceDirectory must be a directory.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$reportDirectory = Join-Path $projectRoot 'reports'
$null = New-Item -ItemType Directory -Path $reportDirectory -Force
$entries = @()
foreach ($name in @('ra2.mix', 'language.mix', 'ra2md.mix', 'langmd.mix', 'theme.mix')) {
    $path = Join-Path $resourceRoot $name
    $exists = Test-Path -LiteralPath $path -PathType Leaf
    $size = $null
    $hash = $null
    if ($exists) {
        $size = (Get-Item -LiteralPath $path).Length
        $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    }
    $entries += [pscustomobject]@{
        Name = $name
        RequiredForInitialInventory = ($name -in @('ra2.mix', 'language.mix'))
        Exists = $exists
        SizeBytes = $size
        SHA256 = $hash
    }
}
$missing = @($entries | Where-Object { $_.RequiredForInitialInventory -and (-not $_.Exists -or $_.SizeBytes -eq 0) })
$report = [pscustomobject]@{
    GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
    SourceDirectory = $resourceRoot
    BasicFilesPresent = ($missing.Count -eq 0)
    Scope = 'File presence, size and SHA-256 only. Not an authenticity, archive integrity or compatibility check.'
    Files = $entries
}
$outputPath = Join-Path $reportDirectory 'resource-inventory.local.json'
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $outputPath -Encoding utf8
$entries | Format-Table Name, Exists, SizeBytes, RequiredForInitialInventory
Write-Output "Local report: $outputPath"
if ($missing.Count -gt 0) { throw 'Required base resource files are missing or empty.' }

