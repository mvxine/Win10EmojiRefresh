<#!
.SYNOPSIS
    Normalizes or removes seguiemj entries from PendingFileRenameOperations.

.DESCRIPTION
    Without parameters: keeps ONE correct swap for the next boot, using
    C:\Windows\Fonts\seguiemj.stage and the most recent installation state.

    With -ClearOnly: only removes seguiemj entries from the queue. Used by the
    setup before a fresh install, to cancel stale swaps.

    If there are no seguiemj entries, nothing is changed and the script exits
    successfully.
#>
[CmdletBinding()]
param(
    [switch]$ClearOnly
)

$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$keyPath = 'SYSTEM\CurrentControlSet\Control\Session Manager'
$valueName = 'PendingFileRenameOperations'
$target = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf'
$stage  = Join-Path $env:SystemRoot 'Fonts\seguiemj.stage'
# Legacy state folder is intentional: it keeps existing backups reachable.
$stateDir = Join-Path $env:LOCALAPPDATA 'Win11EmojiBackport\backups\system'

$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($keyPath, $true)
if (-not $key) { throw 'Could not open Session Manager (administrator rights required).' }
try {
    $current = @($key.GetValue($valueName, $null))
    $pending = @($current | Where-Object { $_ -and ($_ -match 'seguiemj') })

    if ($pending.Count -eq 0) {
        Write-Host 'PendingFileRenameOperations: no seguiemj entries; nothing to fix.' -ForegroundColor Green
        return
    }

    $kept = @($current | Where-Object { $_ -and ($_ -notmatch 'seguiemj') })

    if ($ClearOnly) {
        $key.SetValue($valueName, [string[]]$kept,
            [Microsoft.Win32.RegistryValueKind]::MultiString)
        Write-Host "PendingFileRenameOperations cleared: $($pending.Count) seguiemj entries removed." -ForegroundColor Green
        return
    }

    if (-not (Test-Path -LiteralPath $stage -PathType Leaf)) {
        throw "Staged file not found: $stage"
    }
    $hash = (Get-FileHash -LiteralPath $stage -Algorithm SHA256).Hash
    if ($hash -ine 'F07CBD7886F4A1A5255A1BDF4CA5EA29DB3BE3357414003A92BEC5D1C3165578') {
        Write-Warning "Stage hash is $hash (v1.60 was expected). Continuing anyway."
    }

    $stateFile = Get-ChildItem -LiteralPath $stateDir -Filter 'state-*.json' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $stateFile) { throw "No installation state found in $stateDir" }
    $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
    $retired = $state.RetiredPath
    if (-not $retired) { throw 'The state does not contain RetiredPath.' }
    if (Test-Path -LiteralPath $retired) {
        $retired = Join-Path $stateFile.DirectoryName "seguiemj-retired-fix-$(Get-Date -Format 'yyyyMMdd-HHmmss').ttf"
    }

    $ops = @(
        "\??\$target", "\??\$retired",
        "\??\$stage",  "\??\$target"
    )
    $final = @($kept) + $ops

    $key.SetValue($valueName, [string[]]$final,
        [Microsoft.Win32.RegistryValueKind]::MultiString)

    "PendingFileRenameOperations normalized: $($current.Count) -> $($final.Count) entries"
    " 1) $target"
    "    -> $retired"
    " 2) $stage"
    "    -> $target"
    ''
    Write-Host 'RESTART THE COMPUTER NOW.' -ForegroundColor Yellow
    Write-Host 'Then run verify.cmd.' -ForegroundColor Yellow
} finally {
    $key.Close()
}
