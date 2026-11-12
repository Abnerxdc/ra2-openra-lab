[CmdletBinding()]
param([Parameter(Mandatory)][string]$SourceDirectory)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $SourceDirectory).Path
$destination = Join-Path $root 'local/support/Content/ra2'
$null = New-Item -ItemType Directory -Path $destination -Force
$results = foreach ($name in @('ra2.mix', 'language.mix', 'theme.mix')) {
    $inputFile = Join-Path $source $name
    if (!(Test-Path -LiteralPath $inputFile -PathType Leaf)) {
        if ($name -ne 'theme.mix') { throw "Required base package missing: $name" }
        continue
    }
    $outputFile = Join-Path $destination $name
    $before = (Get-FileHash -LiteralPath $inputFile -Algorithm SHA256).Hash
    if (Test-Path -LiteralPath $outputFile) {
        if ((Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash -ne $before) {
            throw "Existing staged package differs; refusing overwrite: $name"
        }
    } else {
        # CreateNew prevents overwriting an existing file, including a concurrent copy.
        $inputStream = [IO.File]::OpenRead($inputFile)
        try {
            $outputStream = [IO.File]::Open($outputFile, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
            try { $inputStream.CopyTo($outputStream) } finally { $outputStream.Dispose() }
        } finally { $inputStream.Dispose() }
    }
    $after = (Get-FileHash -LiteralPath $outputFile -Algorithm SHA256).Hash
    if ($before -ne $after) { throw "Staged package hash mismatch: $name" }
    [pscustomobject]@{ Name=$name; SHA256=$after; CopyVerified=$true }
}
$null = New-Item -ItemType Directory -Path (Join-Path $root 'reports') -Force
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root 'reports/staged-content.local.json') -Encoding utf8
Write-Output 'Local base content staged and copy hashes verified. No game or installer was launched.'
