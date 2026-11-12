[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$git = Get-Command git -ErrorAction SilentlyContinue
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
$gh = Get-Command gh -ErrorAction SilentlyContinue
$sdks = @()
if ($dotnet) {
    $sdks = @(& $dotnet.Source --list-sdks)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to enumerate .NET SDKs.' }
}
[pscustomobject]@{
    GitAvailable = [bool]$git
    GitHubCliAvailable = [bool]$gh
    DotNetAvailable = [bool]$dotnet
    DotNetSdks = $sdks
    HasSdk = ($sdks.Count -gt 0)
    Note = 'Inventory only; no game process launched. SDK compatibility requires upstream inspection.'
} | ConvertTo-Json -Depth 4
