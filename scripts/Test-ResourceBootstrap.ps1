[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$work = Join-Path $root ('local/bootstrap-test/' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work -Force
$exe = Join-Path $work 'ResourceStoreTests.exe'
$csc = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $csc /nologo /codepage:65001 /target:exe /main:ResourceStoreTests /platform:x64 /optimize+ /reference:System.Windows.Forms.dll /reference:System.Drawing.dll ("/out:$exe") (Join-Path $root 'packaging/windows/Bootstrap.cs') (Join-Path $PSScriptRoot 'ResourceStoreTests.cs')
if ($LASTEXITCODE -ne 0) { throw 'Bootstrap test compilation failed.' }
# Reviewed console entry; exercises only ResourceStore with synthetic data, never game resources or UI.
& $exe $work
if ($LASTEXITCODE -ne 0) { throw 'Resource-store tests failed.' }
