<#!
.SYNOPSIS
    Win10 Emoji Refresh - brings the native Windows 11 emoji font to Windows 10.

.DESCRIPTION
    Does not redistribute Microsoft binaries. The module inspects, downloads
    (from configurable sources) and registers an updated "Segoe UI Emoji" font.

    Modes:
      User   - per-user install (no administrator). Limited; does not change Win + .
      System - replaces C:\Windows\Fonts\seguiemj.ttf (requires administrator).

    Commands:
      -Diagnose  reports system and font state (changes nothing).
      -Verify    confirms that the installation is active and intact.
      -Uninstall removes the installation and restores the previous state.
      -DryRun    shows what would be done, without changes.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File src\Win11Emoji.ps1 -Diagnose

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File src\Win11Emoji.ps1 -Mode User -DryRun

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File src\Win11Emoji.ps1 -Mode User -Source C:\Downloads\seguiemj.ttf
#>
[CmdletBinding(DefaultParameterSetName = 'Install')]
param(
    [ValidateSet('User', 'System')]
    [string]$Mode = 'System',

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Uninstall,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Verify,

    [Parameter(ParameterSetName = 'Install')]
    [switch]$Diagnose,

    [switch]$DryRun,
    [switch]$Force,
    [switch]$NoRestart,
    [switch]$RebootNow,

    [string]$Source,
    [string]$Url,
    [string]$ExpectedSha256,
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------
$Script:Product      = 'Win10EmojiRefresh'
$Script:DisplayName  = 'Win10 Emoji Refresh'
# Legacy ID kept as the state folder so existing backups remain reachable.
$Script:StateId      = 'Win11EmojiBackport'
$Script:FontFamily   = 'Segoe UI Emoji'
$Script:RegValueName = 'Segoe UI Emoji (TrueType)'
$Script:FontsKey     = 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$Script:MachineFontsKey = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
$Script:MinVersion   = [version]'1.30'
$Script:BaselineVersion = [version]'1.29'
$Script:StateRoot    = Join-Path $env:LOCALAPPDATA $Script:StateId
$Script:UserFontDir  = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Fonts'
$Script:MachineFontPath = Join-Path $env:SystemRoot 'Fonts\seguiemj.ttf'
$Script:Sources = @(
    'https://raw.githubusercontent.com/skeyuui/windows-seguiemj-emoji-tracker/main/seguiemj.ttf',
    'https://raw.githubusercontent.com/Gitbreast/win11_emoji_for_win10/main/newest/seguiemj.ttf'
)

function Write-Info([string]$Message) {
    if ($Json) { Write-Dim $Message } else { Write-Host $Message -ForegroundColor Cyan }
}
function Write-Good([string]$Message) { Write-Host $Message -ForegroundColor Green }
function Write-Warn2([string]$Message) { Write-Host $Message -ForegroundColor Yellow }
function Write-Bad([string]$Message) { Write-Host $Message -ForegroundColor Red }
function Write-Dim([string]$Message) { Write-Host $Message -ForegroundColor DarkGray }

# ---------------------------------------------------------------------------
# TTF reader (no external dependencies)
# ---------------------------------------------------------------------------
if (-not ('Win11EmojiFontInspector' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Text.RegularExpressions;
using System.Security.Cryptography;

public sealed class Win11EmojiFontFacts {
    public string Path;
    public long Size;
    public string Family = "";
    public string VersionText = "";
    public Version Version;
    public int Glyphs;
    public long MaxCodePoint;
    public bool HasColorGlyphs;
    public string Sha256 = "";
    public string Error = "";
}

public static class Win11EmojiFontInspector {
    private static ushort U16(byte[] b, long o) {
        if (o < 0 || o + 2 > b.Length) return 0;
        return (ushort)(((int)b[o] << 8) | b[o + 1]);
    }
    private static uint U32(byte[] b, long o) {
        if (o < 0 || o + 4 > b.Length) return 0;
        return ((uint)b[o] << 24) | ((uint)b[o + 1] << 16) | ((uint)b[o + 2] << 8) | b[o + 3];
    }

    public static Win11EmojiFontFacts Read(string path) {
        var r = new Win11EmojiFontFacts();
        r.Path = path;
        try {
            byte[] b = File.ReadAllBytes(path);
            r.Size = b.Length;
            if (b.Length < 12) { r.Error = "File is too short to be a TTF font."; return r; }

            string sig = Encoding.ASCII.GetString(b, 0, 4);
            bool sfnt = (b[0] == 0 && b[1] == 1 && b[2] == 0 && b[3] == 0);
            if (!sfnt && sig != "OTTO" && sig != "true") {
                r.Error = "Unknown font signature: " + sig;
                return r;
            }

            int numTables = U16(b, 4);
            long nameOff = -1, maxpOff = -1, cmapOff = -1, headOff = -1;
            bool hasColr = false;
            for (int i = 0; i < numTables; i++) {
                long x = 12L + i * 16L;
                if (x + 16 > b.Length) break;
                string tag = Encoding.ASCII.GetString(b, (int)x, 4);
                long off = U32(b, x + 8);
                if (tag == "name") nameOff = off;
                else if (tag == "maxp") maxpOff = off;
                else if (tag == "cmap") cmapOff = off;
                else if (tag == "head") headOff = off;
                else if (tag == "COLR") hasColr = true;
            }
            r.HasColorGlyphs = hasColr;

            if (nameOff >= 0 && nameOff + 6 <= b.Length) {
                ushort count = U16(b, nameOff + 2);
                ushort stringBase = U16(b, nameOff + 4);
                string family = null, version = null;
                for (int i = 0; i < count; i++) {
                    long x = nameOff + 6L + i * 12L;
                    if (x + 12 > b.Length) break;
                    ushort platform = U16(b, x);
                    ushort encoding = U16(b, x + 2);
                    ushort language = U16(b, x + 4);
                    ushort nameId = U16(b, x + 6);
                    ushort len = U16(b, x + 8);
                    ushort off = U16(b, x + 10);
                    if (nameId != 1 && nameId != 5) continue;
                    long p = nameOff + stringBase + off;
                    if (p + len > b.Length) continue;
                    string text = (platform == 3 || platform == 0)
                        ? Encoding.BigEndianUnicode.GetString(b, (int)p, len)
                        : Encoding.ASCII.GetString(b, (int)p, len);
                    int quality = (platform == 3 && encoding == 1 && language == 1033) ? 3
                                : (platform == 1) ? 2 : 1;
                    if (nameId == 1 && (family == null || quality == 3)) family = text;
                    if (nameId == 5 && (version == null || quality == 3)) version = text;
                }
                r.Family = family ?? "";
                r.VersionText = version ?? "";
                var m = Regex.Match(r.VersionText, @"([0-9]+(?:\.[0-9]+)+)");
                if (m.Success) Version.TryParse(m.Groups[1].Value, out r.Version);
            }

            if (maxpOff >= 0 && maxpOff + 6 <= b.Length) r.Glyphs = U16(b, maxpOff + 4);

            if (cmapOff >= 0 && cmapOff + 4 <= b.Length) {
                ushort nsub = U16(b, cmapOff + 2);
                long best = -1; int bestScore = -1;
                for (int i = 0; i < nsub; i++) {
                    long x = cmapOff + 4L + i * 8L;
                    if (x + 8 > b.Length) break;
                    ushort plat = U16(b, x), enc = U16(b, x + 2);
                    long sub = cmapOff + U32(b, x + 4);
                    int score = (plat == 3 && enc == 10) ? 4 : (plat == 0) ? 3 : (plat == 3) ? 2 : 1;
                    if (score > bestScore) { bestScore = score; best = sub; }
                }
                if (best >= 0 && best + 2 <= b.Length) {
                    ushort fmt = U16(b, best);
                    if (fmt == 12 && best + 16 <= b.Length) {
                        uint groups = U32(b, best + 12);
                        for (uint i = 0; i < groups; i++) {
                            long g = best + 16L + (long)i * 12L;
                            if (g + 8 > b.Length) break;
                            uint end = U32(b, g + 4);
                            if (end > r.MaxCodePoint && end < 0x110000) r.MaxCodePoint = end;
                        }
                    } else if (fmt == 4 && best + 14 <= b.Length) {
                        ushort segX2 = U16(b, best + 6);
                        int seg = segX2 / 2;
                        long ends = best + 14;
                        for (int i = 0; i < seg; i++) {
                            ushort e = U16(b, ends + i * 2);
                            if (e != 0xffff && e > r.MaxCodePoint) r.MaxCodePoint = e;
                        }
                    }
                }
            }

            using (var sha = SHA256.Create()) {
                var hash = sha.ComputeHash(b);
                var sb = new StringBuilder(hash.Length * 2);
                foreach (var x in hash) sb.Append(x.ToString("x2"));
                r.Sha256 = sb.ToString();
            }
        } catch (Exception ex) {
            r.Error = ex.Message;
        }
        return r;
    }
}
'@
}

function Get-FontInfo {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    return [Win11EmojiFontInspector]::Read($Path)
}

function Assert-Candidate {
    param([Parameter(Mandatory)]$Info)
    if ($Info.Error) { throw "Invalid font: $($Info.Error)" }
    if ($Info.Family -ne $Script:FontFamily) {
        throw "The supplied font family is '$($Info.Family)', not '$($Script:FontFamily)'."
    }
    if (-not $Info.Version) { throw "Could not read the font version." }
    if (-not $Info.HasColorGlyphs) { throw "The font has no COLR table (color emoji)." }
    if ($Info.Version -lt $Script:MinVersion) {
        throw "Version $($Info.Version) is too old; expected >= $($Script:MinVersion)."
    }
}

# ---------------------------------------------------------------------------
# System utilities
# ---------------------------------------------------------------------------
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-OsInfo {
    $cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
    [pscustomobject]@{
        ProductName = $cv.ProductName
        DisplayVersion = $cv.DisplayVersion
        CurrentBuild = $cv.CurrentBuild
        Ubr = $cv.UBR
        Architecture = $env:PROCESSOR_ARCHITECTURE
        IsWindows10 = (([int]$cv.CurrentBuild) -ge 19041)
    }
}

function Send-FontChange {
    if (-not ('Win11EmojiFontNotify' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Win11EmojiFontNotify {
    [DllImport("user32.dll", CharSet=CharSet.Auto, SetLastError=true)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam,
        string lParam, uint flags, uint timeout, out UIntPtr result);
}
'@
    }
    $result = [UIntPtr]::Zero
    [void][Win11EmojiFontNotify]::SendMessageTimeout([IntPtr]0xffff, 0x001A,
        [UIntPtr]::Zero, $null, 2, 2000, [ref]$result)
}

function Restart-TextInputHost {
    if ($NoRestart) { return }
    $procs = Get-Process -Name TextInputHost -ErrorAction SilentlyContinue
    foreach ($p in $procs) {
        try { Stop-Process -Id $p.Id -Force -ErrorAction Stop; Write-Dim "TextInputHost restarted (PID $($p.Id))." }
        catch { Write-Dim "Could not restart TextInputHost: $($_.Exception.Message)" }
    }
}

function New-StateDir([string]$Child) {
    $p = Join-Path $Script:StateRoot $Child
    if (-not (Test-Path -LiteralPath $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
    return $p
}

function Write-JsonState {
    param([string]$Directory, [object]$State)
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $path = Join-Path $Directory "state-$stamp.json"
    $State | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $path -Encoding UTF8
    return $path
}

function Get-LatestState {
    param([string]$Directory, [string]$Filter = 'state-*.json')
    if (-not (Test-Path -LiteralPath $Directory)) { return $null }
    return Get-ChildItem -LiteralPath $Directory -Filter $Filter -File |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
}

# ---------------------------------------------------------------------------
# User mode - per-user install (no administrator)
# ---------------------------------------------------------------------------
function Get-UserRegistration {
    $key = Get-Item -LiteralPath $Script:FontsKey -ErrorAction SilentlyContinue
    if (-not $key) { return $null }
    $value = $key.GetValue($Script:RegValueName, $null,
        [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    if ($null -eq $value) { return $null }
    return [string]$value
}

function Install-UserFont {
    param([Parameter(Mandatory)]$Candidate)

    $previous = Get-UserRegistration
    $targetDir = $Script:UserFontDir
    $shortHash = $Candidate.Sha256.Substring(0, 10)
    $fileName = "seguiemj-win11-v$($Candidate.Version)-$shortHash.ttf"
    $target = Join-Path $targetDir $fileName

    Write-Info "User mode (per-user, no administrator)"
    Write-Dim "  Registry : $($Script:FontsKey)\$($Script:RegValueName)"
    Write-Dim "  File     : $target"

    if ($DryRun) {
        Write-Good "  DRY RUN: nothing was changed."
        return
    }

    $backupDir = New-StateDir 'backups\user'
    $state = @{
        Mode = 'User'
        Timestamp = (Get-Date).ToString('o')
        PreviousRegistration = $previous
        PreviousRegistrationExists = ($null -ne $previous)
        InstalledFile = $target
        InstalledVersion = $Candidate.VersionText
        InstalledSha256 = $Candidate.Sha256
        SourcePath = $Candidate.Path
    }
    if ($previous -and (Test-Path -LiteralPath $previous)) {
        $saved = Join-Path $backupDir "previous-$(Get-Date -Format 'yyyyMMdd-HHmmss').ttf"
        Copy-Item -LiteralPath $previous -Destination $saved -Force
        $state.PreviousFileBackup = $saved
    }

    if (-not (Test-Path -LiteralPath $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $Candidate.Path -Destination $target -Force
    Set-ItemProperty -LiteralPath $Script:FontsKey -Name $Script:RegValueName -Value $target -Type String

    $statePath = Write-JsonState -Directory $backupDir -State $state
    Send-FontChange
    Restart-TextInputHost

    Write-Good "  Installed: Segoe UI Emoji $($Candidate.Version) for the current user."
    Write-Dim "  Backup   : $statePath"
    Write-Warn2 "  Close and reopen applications so they load the new font."
}

function Uninstall-UserFont {
    $stateFile = Get-LatestState -Directory (Join-Path $Script:StateRoot 'backups\user')
    $previous = Get-UserRegistration
    $currentTarget = $previous

    if ($stateFile) {
        $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
        $currentTarget = $state.InstalledFile
    }

    Write-Info "Uninstalling User mode"
    if ($DryRun) { Write-Good "  DRY RUN: nothing was changed."; return }

    if ($currentTarget -and (Test-Path -LiteralPath $currentTarget)) {
        Remove-Item -LiteralPath $currentTarget -Force -ErrorAction SilentlyContinue
        Write-Dim "  Removed : $currentTarget"
    }

    if ($stateFile) {
        $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
        if ($state.PreviousRegistrationExists -and $state.PreviousRegistration) {
            Set-ItemProperty -LiteralPath $Script:FontsKey -Name $Script:RegValueName `
                -Value $state.PreviousRegistration -Type String
            Write-Good "  Registry restored to: $($state.PreviousRegistration)"
        } else {
            Remove-ItemProperty -LiteralPath $Script:FontsKey -Name $Script:RegValueName -ErrorAction SilentlyContinue
            Write-Good "  Per-user font registration removed."
        }
        if ($state.PSObject.Properties['PreviousFileBackup'] -and
            $state.PreviousFileBackup -and (Test-Path -LiteralPath $state.PreviousFileBackup)) {
            Copy-Item -LiteralPath $state.PreviousFileBackup -Destination $state.PreviousRegistration -Force
        }
        Rename-Item -LiteralPath $stateFile.FullName -NewName ($stateFile.Name + '.used') -Force
    } else {
        Remove-ItemProperty -LiteralPath $Script:FontsKey -Name $Script:RegValueName -ErrorAction SilentlyContinue
        Write-Good "  Per-user font registration removed."
    }

    Send-FontChange
    Restart-TextInputHost
    Write-Warn2 "  Restart applications to return to the previous font."
}

# ---------------------------------------------------------------------------
# System mode - replacing the protected font
# ---------------------------------------------------------------------------
$Script:SidSystem = '*S-1-5-18'
$Script:SidAdmins = '*S-1-5-32-544'
$Script:SidUsers = '*S-1-5-32-545'
$Script:SidTrustedInstaller = '*S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464'
$Script:SidAllApps = '*S-1-15-2-1'
$Script:SidRestrictedApps = '*S-1-15-2-2'

function Restore-NormalAcl([string]$Path) {
    & icacls $Path /setowner 'NT SERVICE\TrustedInstaller' 2>$null | Out-Null
    & icacls $Path /grant:r "$($Script:SidSystem):(RX)" "$($Script:SidAdmins):(RX)" `
        "$($Script:SidUsers):(RX)" "$($Script:SidTrustedInstaller):(F)" `
        "$($Script:SidAllApps):(RX)" "$($Script:SidRestrictedApps):(RX)" 2>$null | Out-Null
}

function Grant-SystemFull([string]$Path) {
    & takeown /f $Path /a 2>$null | Out-Null
    & icacls $Path /grant "$($Script:SidSystem):(F)" 2>$null | Out-Null
}

function Queue-BootSwap {
    param(
        [Parameter(Mandatory)][string]$OldPath,
        [Parameter(Mandatory)][string]$BackupPath,
        [Parameter(Mandatory)][string]$StagePath,
        [Parameter(Mandatory)][string]$NewPath
    )
    # PendingFileRenameOperations = pairs (source, destination).
    # 1) old font -> backup   2) staged candidate -> font path
    $ops = @(
        "\??\$OldPath", "\??\$BackupPath",
        "\??\$StagePath", "\??\$NewPath"
    )
    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
        'SYSTEM\CurrentControlSet\Control\Session Manager', $true)
    if (-not $key) { throw 'Could not open Session Manager to queue the swap.' }
    try {
        $existing = $key.GetValue('PendingFileRenameOperations', $null)
        $all = if ($existing) { @($existing) + $ops } else { $ops }
        $key.SetValue('PendingFileRenameOperations', [string[]]$all,
            [Microsoft.Win32.RegistryValueKind]::MultiString)
    } finally { $key.Close() }
}

function Swap-MachineFont {
    param(
        [Parameter(Mandatory)][string]$Candidate,
        [Parameter(Mandatory)][string]$BackupCopy,   # clean copy, for later undo
        [Parameter(Mandatory)][string]$RetiredPath,  # destination of the Move of the current font (must not exist)
        [string]$Label = 'Swap'
    )

    $stage = Join-Path $env:SystemRoot 'Fonts\seguiemj.stage'
    if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Force -ErrorAction SilentlyContinue }
    Copy-Item -LiteralPath $Candidate -Destination $stage -Force

    $moved = $false
    $aside = $false
    try {
        [IO.File]::Move($Script:MachineFontPath, $RetiredPath)
        $aside = $true
        [IO.File]::Move($stage, $Script:MachineFontPath)
        $moved = $true
    } catch {
        Write-Warn2 "  File is in use; queuing the swap for the next boot."
        if ($aside) { try { [IO.File]::Move($RetiredPath, $Script:MachineFontPath) } catch { } }
    }

    if ($moved) {
        Restore-NormalAcl $Script:MachineFontPath
        Write-Good "  $Label completed without a restart."
    } else {
        Grant-SystemFull $Script:MachineFontPath
        Grant-SystemFull $stage
        Restore-NormalAcl $stage
        Queue-BootSwap -OldPath $Script:MachineFontPath -BackupPath $RetiredPath `
            -StagePath $stage -NewPath $Script:MachineFontPath
        Write-Warn2 "  Swap queued. Restart the computer to apply it."
    }

    try { Stop-Service FontCache -Force -ErrorAction SilentlyContinue } catch { }

    if (-not $moved -and $RebootNow) {
        Write-Warn2 '  Restarting in 20 seconds (close unsaved work)...'
        shutdown.exe /r /t 20 /c 'Applying the Segoe UI Emoji font'
    }
}

function Install-SystemFont {
    param([Parameter(Mandatory)]$Candidate)
    $current = Get-FontInfo $Script:MachineFontPath
    Write-Info "System mode (replaces the system font - changes the Win + . panel)"
    Write-Dim "  Current : $($current.VersionText)"
    Write-Dim "  New     : $($Candidate.VersionText)"

    if ($DryRun) {
        Write-Good "  DRY RUN: nothing was changed."
        Write-Dim "  Would replace: $($Script:MachineFontPath)"
        Write-Dim "  Backup at    : $(Join-Path $Script:StateRoot 'backups\system')"
        return
    }

    if (-not (Test-IsAdmin)) {
        throw 'System mode requires administrator rights. Use -Mode User for a limited override, or run elevated.'
    }

    $backupDir = New-StateDir 'backups\system'
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupCopy = Join-Path $backupDir "seguiemj-v$($current.Version)-$stamp.ttf"
    $retired = Join-Path $backupDir "seguiemj-retired-v$($current.Version)-$stamp.ttf"
    Copy-Item -LiteralPath $Script:MachineFontPath -Destination $backupCopy -Force

    $state = @{
        Mode = 'System'
        Timestamp = (Get-Date).ToString('o')
        BackupPath = $backupCopy
        RetiredPath = $retired
        PreviousVersion = $current.VersionText
        InstalledVersion = $Candidate.VersionText
        InstalledSha256 = $Candidate.Sha256
    }
    $statePath = Write-JsonState -Directory $backupDir -State $state

    Swap-MachineFont -Candidate $Candidate.Path -BackupCopy $backupCopy `
        -RetiredPath $retired -Label 'Replacement'
    Write-Dim "  Backup   : $statePath"
    Write-Warn2 "  Note: cumulative updates or sfc /scannow may restore the old font."
}

function Uninstall-SystemFont {
    $stateFile = Get-LatestState -Directory (Join-Path $Script:StateRoot 'backups\system')
    if (-not $stateFile) { throw 'No System-mode backup was found.' }
    $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $state.BackupPath)) { throw 'The backup file no longer exists.' }

    Write-Info "Restoring system font: $($state.PreviousVersion)"
    if ($DryRun) { Write-Good "  DRY RUN: nothing was changed."; return }

    if (-not (Test-IsAdmin)) { throw 'System mode requires administrator rights.' }

    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $rollbackCopy = Join-Path $stateFile.DirectoryName "seguiemj-pre-rollback-$stamp.ttf"
    $retired = Join-Path $stateFile.DirectoryName "seguiemj-retired-rollback-$stamp.ttf"
    Copy-Item -LiteralPath $Script:MachineFontPath -Destination $rollbackCopy -Force

    Swap-MachineFont -Candidate $state.BackupPath -BackupCopy $rollbackCopy `
        -RetiredPath $retired -Label 'Restore'
    Rename-Item -LiteralPath $stateFile.FullName -NewName ($stateFile.Name + '.used') -Force
}

# ---------------------------------------------------------------------------
# Download / validation
# ---------------------------------------------------------------------------
function Get-Candidate {
    Write-Warn2 'Legal notice: Segoe UI Emoji is proprietary to Microsoft. This project does not redistribute it; obtain it at your own risk (see NOTICE.md).'
    $work = Join-Path $Script:StateRoot 'downloads'
    if (-not (Test-Path -LiteralPath $work)) { New-Item -ItemType Directory -Path $work -Force | Out-Null }

    if ($Source) {
        $resolved = (Resolve-Path -LiteralPath $Source).Path
        $dest = $resolved
    } else {
        $dest = Join-Path $work 'seguiemj.ttf'
        $urls = if ($Url) { @($Url) } else { $Script:Sources }
        $ok = $false
        foreach ($u in $urls) {
            try {
                Write-Dim "  Downloading: $u"
                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                Invoke-WebRequest -Uri $u -OutFile $dest -UseBasicParsing -TimeoutSec 300
                $ok = $true
                break
            } catch { Write-Warn2 "    failed: $($_.Exception.Message)" }
        }
        if (-not $ok) {
            throw 'Could not download the font. Use -Source with a local file.'
        }
    }

    $info = Get-FontInfo -Path $dest
    Assert-Candidate $info

    if ($ExpectedSha256) {
        if ($info.Sha256 -ine $ExpectedSha256) {
            throw "SHA256 mismatch. Expected: $ExpectedSha256 / Got: $($info.Sha256)"
        }
        Write-Good '  SHA256 verified.'
    }

    $mp = Join-Path $env:ProgramFiles 'Windows Defender\MpCmdRun.exe'
    if (Test-Path $mp) {
        Write-Dim '  Checking with Windows Defender...'
        $scan = (& $mp -Scan -ScanType 3 -File $dest 2>&1 | Out-String)
        if ($scan -match 'found\s+(\d+)\s+threat' -and [int]$matches[1] -gt 0) {
            throw 'Windows Defender found a threat in the downloaded font. Aborting.'
        }
    }

    return $info
}

# ---------------------------------------------------------------------------
# Diagnose / Verify
# ---------------------------------------------------------------------------
function Get-PanelInfo {
    $base = Join-Path $env:SystemRoot 'SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy'
    $items = @('TextInputHost.exe', 'InputApp.dll')
    $result = @{}
    foreach ($name in $items) {
        $p = Join-Path $base $name
        if (Test-Path -LiteralPath $p) {
            $f = Get-Item -LiteralPath $p
            $result[$name] = $f.VersionInfo.FileVersion
        } else { $result[$name] = $null }
    }
    return $result
}

function Invoke-Diagnose {
    $os = Get-OsInfo
    $machine = Get-FontInfo $Script:MachineFontPath
    $userPath = Get-UserRegistration
    $user = if ($userPath) { Get-FontInfo $userPath } else { $null }
    $panel = Get-PanelInfo

    $machineOut = $null
    if ($machine -and -not $machine.Error) {
        $machineOut = @{
            path = $machine.Path; version = $machine.VersionText; family = $machine.Family
            glyphs = $machine.Glyphs; maxCodePoint = ('U+{0:X}' -f $machine.MaxCodePoint)
            color = $machine.HasColorGlyphs; sha256 = $machine.Sha256
        }
    }
    $userOut = $null
    if ($user -and -not $user.Error) {
        $userOut = @{
            path = $user.Path; version = $user.VersionText; family = $user.Family
            glyphs = $user.Glyphs; maxCodePoint = ('U+{0:X}' -f $user.MaxCodePoint)
            color = $user.HasColorGlyphs; sha256 = $user.Sha256
        }
    }
    $out = [ordered]@{
        product = $Script:Product
        os = $os
        admin = (Test-IsAdmin)
        machineFont = $machineOut
        userRegistration = $userPath
        userFont = $userOut
        emojiPanel = $panel
        # Confirmed by a TextInputHost memory dump: the Win + . panel loads
        # C:\WINDOWS\FONTS\SEGUIEMJ.TTF by fixed path, not from the HKCU registry.
        panelFontSource = $Script:MachineFontPath
        panelFollowsUserOverride = $false
        stateRoot = $Script:StateRoot
    }

    if ($Json) {
        Write-Host ($out | ConvertTo-Json -Depth 8)
        return
    }

    Write-Info "$($Script:DisplayName) - diagnostics"
    Write-Host "  System       : $($os.ProductName) $($os.DisplayVersion) (build $($os.CurrentBuild).$($os.Ubr))"
    Write-Host "  Administrator: $(Test-IsAdmin)"
    if ($machine) {
        Write-Host "  System font  : $($machine.VersionText)  glyphs=$($machine.Glyphs)  max=U+$('{0:X}' -f $machine.MaxCodePoint)"
    }
    if ($userPath) {
        if ($user -and -not $user.Error) {
            Write-Good "  User font    : $($user.VersionText)  $userPath"
        } else {
            Write-Warn2 "  User registry points to an invalid file: $userPath"
        }
    } else {
        Write-Dim '  User font    : not registered'
    }
    Write-Host "  InputApp panel: $($panel['InputApp.dll']) / TextInputHost: $($panel['TextInputHost.exe'])"
    Write-Warn2 "  Win + . panel ALWAYS uses: $($Script:MachineFontPath)"
    if ($userPath -and $machine -and $machine.Version -lt $Script:MinVersion) {
        Write-Warn2 '  A per-user override does NOT change the Win + . panel. Use -Mode System (admin).'
    }
    Write-Dim "  State: $($Script:StateRoot)"
}

function Invoke-Verify {
    $ok = $true
    if ($Mode -eq 'User') {
        $p = Get-UserRegistration
        if (-not $p) { Write-Bad 'FAIL: no per-user font registered.'; return $false }
        $info = Get-FontInfo $p
        if (-not $info -or $info.Error) { Write-Bad "FAIL: invalid file at $p"; return $false }
        if ($info.Family -ne $Script:FontFamily) { Write-Bad "FAIL: family '$($info.Family)'."; return $false }
        Write-Good "OK: Segoe UI Emoji $($info.VersionText) active for the current user."
        Write-Dim "  $p"
        $stateFile = Get-LatestState -Directory (Join-Path $Script:StateRoot 'backups\user')
        if ($stateFile) {
            $state = Get-Content -LiteralPath $stateFile.FullName -Raw | ConvertFrom-Json
            if ($state.InstalledSha256 -and $state.InstalledSha256 -ne $info.Sha256) {
                Write-Bad 'FAIL: the installed file was changed (SHA256 differs from backup).'
                $ok = $false
            }
        }
    } else {
        $info = Get-FontInfo $Script:MachineFontPath
        if (-not $info -or $info.Error) { Write-Bad 'FAIL: invalid system font.'; return $false }
        Write-Good "OK: system font is Segoe UI Emoji $($info.VersionText)."
        Write-Good '  This is the font used by the Win + . panel and by apps without a per-user override.'
        if ($info.Version -lt $Script:MinVersion) {
            Write-Bad "FAIL: the system font is still old (< $($Script:MinVersion)); the Win + . panel will keep using Windows 10 emoji."
            $ok = $false
        }
    }
    return $ok
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
function Invoke-Main {
    if ($Json) {
        if ($Diagnose) { Invoke-Diagnose; return 0 }
        Write-Bad 'ERROR: -Json is only supported with -Diagnose.'
        return 2
    }

    Write-Host ''
    Write-Info "$($Script:DisplayName) - Windows 11 emojis on Windows 10"
    Write-Dim '========================================================='
    Write-Host ''

    if ($Diagnose) { Invoke-Diagnose; return 0 }
    if ($Verify) { if (Invoke-Verify) { return 0 } else { return 2 } }

    if ($Uninstall) {
        if ($Mode -eq 'User') { Uninstall-UserFont } else { Uninstall-SystemFont }
        return 0
    }

    $candidate = Get-Candidate
    Write-Host ''
    Write-Host "  Family   : $($candidate.Family)"
    Write-Host "  Version  : $($candidate.VersionText)"
    Write-Host "  Glyphs   : $($candidate.Glyphs)   max=U+$('{0:X}' -f $candidate.MaxCodePoint)"
    Write-Host "  SHA256   : $($candidate.Sha256)"
    Write-Host "  Size     : $([Math]::Round($candidate.Size / 1MB, 2)) MB"
    Write-Host ''

    $current = if ($Mode -eq 'System') { Get-FontInfo $Script:MachineFontPath } else {
        $p = Get-UserRegistration
        if ($p) { Get-FontInfo $p } else { Get-FontInfo $Script:MachineFontPath }
    }
    if ($current -and $candidate.Version -le $current.Version -and -not $Force) {
        Write-Warn2 "The installed font ($($current.VersionText)) is already the same or newer. Use -Force to reinstall."
        return 0
    }

    if ($Mode -eq 'User') { Install-UserFont -Candidate $candidate }
    else { Install-SystemFont -Candidate $candidate }
    return 0
}

try {
    $code = Invoke-Main
} catch {
    Write-Bad "ERROR: $($_.Exception.Message)"
    Write-Dim $_.ScriptStackTrace
    $code = 1
}
exit $code
