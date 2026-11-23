# Builds the single release executable from source.
# Requires only the .NET Framework C# compiler included with Windows 10.
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$source = Join-Path $PSScriptRoot 'Program.cs'
$installer = Join-Path $root 'src\Win11Emoji.ps1'
$fixPending = Join-Path $root 'src\FixPending.ps1'
$outDir = Join-Path $root 'release'
$output = Join-Path $outDir 'Win10EmojiRefresh-Setup.exe'

foreach ($p in @($source, $installer, $fixPending)) {
    if (-not (Test-Path -LiteralPath $p)) { throw "Missing source file: $p" }
}

$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319'
if (-not (Test-Path -LiteralPath (Join-Path $framework 'csc.exe'))) {
    $framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319'
}
$csc = Join-Path $framework 'csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw "C# compiler not found: $csc" }

New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$cscArgs = @(
    '/nologo'
    '/target:exe'
    '/platform:anycpu'
    '/optimize+'
    '/debug-'
    "/out:$output"
    "/resource:$installer,Win11Emoji.ps1"
    "/resource:$fixPending,FixPending.ps1"
    '/r:System.dll'
    '/r:System.Core.dll'
    $source
)
& $csc @cscArgs
if ($LASTEXITCODE -ne 0) { throw "csc failed with exit code $LASTEXITCODE" }

$asm = [Reflection.Assembly]::LoadFrom($output)
$resources = @($asm.GetManifestResourceNames())
if ($resources -notcontains 'Win11Emoji.ps1') { throw 'Embedded resource Win11Emoji.ps1 is missing.' }
if ($resources -notcontains 'FixPending.ps1') { throw 'Embedded resource FixPending.ps1 is missing.' }

$sha = (Get-FileHash -LiteralPath $output -Algorithm SHA256).Hash
Write-Host "Built: $output"
Write-Host "SHA256: $sha"
Write-Host "Embedded resources: $($resources -join ', ')"
