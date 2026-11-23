# Technical reference

For normal installation and quick answers, see the [README](../README.md).
This page holds the low-level details that used to make the README long.

## Why `System` mode is the default

The first version of this project used only a per-user registry override
(`HKCU\...\Fonts`). That works for apps that request the font family by name
(Edge/Chromium), **but it does not affect the `Win + .` emoji panel**.

A memory dump of `TextInputHost.exe` proved the reason:

```text
C:\WINDOWS\FONTS\SEGUIEMJ.TTF
... Segoe UI Emoji Regular Version 1.29 ...
```

The panel loads the font by its absolute system path and ignores the `HKCU`
registration. Therefore **`System` mode is the default** — it is the only mode
that changes what the panel renders.

## Modes

### `System` (default, recommended)

- Requires administrator rights (`install.cmd` triggers UAC by itself).
- Replaces `C:\Windows\Fonts\seguiemj.ttf`.
- Backs the original up to `%LOCALAPPDATA%\Win11EmojiBackport\backups\system`
  (the legacy folder ID is kept so existing backups remain reachable).
- If the file is locked, the swap is queued through
  `PendingFileRenameOperations` and applied on the next boot.
- `-RebootNow` restarts automatically 20 seconds after a queued swap. The
  release setup does **not** use this; it asks for confirmation instead.
- Affects all users and the emoji panel.
- Cumulative updates or `sfc /scannow` may restore the old font.

### `User` (limited, no admin)

- Installs into `%LOCALAPPDATA%\Microsoft\Windows\Fonts\` and registers in
  `HKCU`.
- **Does not change the `Win + .` panel** — only apps that resolve the family by
  name.
- Useful only when you have no administrator rights and accept that limitation.

## Install from source (manual)

Run these from the repository root:

```bat
:: Read-only diagnostics
diagnose.cmd

:: Install to the system (UAC prompt appears) — this is what changes Win + .
install.cmd

:: Install from a local file
install.cmd -Source C:\Downloads\seguiemj.ttf

:: Simulate without changing anything
install.cmd -DryRun

:: Normalize the boot queue, e.g. after running install.cmd twice
fix-pending.cmd

:: Verify
verify.cmd

:: Restore the original Windows 10 font
uninstall.cmd
```

All `.cmd` wrappers pause at the end — press any key to close the window.

Direct PowerShell usage:

```powershell
powershell -ExecutionPolicy Bypass -File src\Win11Emoji.ps1 -Mode System -Source C:\Downloads\seguiemj.ttf
powershell -ExecutionPolicy Bypass -File src\Win11Emoji.ps1 -Mode User -DryRun
```

| Option | Effect |
|---|---|
| `-Mode System\|User` | Selects the mode (default: `System`) |
| `-Source <file>` | Uses a local font instead of downloading |
| `-Url <url>` | Overrides the mirror list |
| `-ExpectedSha256 <hash>` | Verifies the downloaded font hash |
| `-Force` | Reinstalls even if the installed version is equal/newer |
| `-RebootNow` | If the swap was queued, reboots in 20 seconds |
| `-NoRestart` | Does not restart `TextInputHost.exe` |
| `-Json` | JSON output for `-Diagnose` |
| `-DryRun` | Changes nothing |

After installation, **close and reopen running apps**. If the swap was queued,
reboot first.

## What the installer validates

The embedded TTF reader (no external dependencies) checks:

- SFNT/OTTO signature;
- `name` family equals `Segoe UI Emoji`;
- numeric version ≥ 1.30 (Windows 10 ships 1.29);
- presence of the `COLR` table (color emoji);
- glyph count and highest codepoint in `cmap`;
- SHA256 (optionally compared with `-ExpectedSha256`);
- a quick Windows Defender scan when available.

The v1.60 font used during testing has 62,354 glyphs, covers up to U+1FAF8 and
passes all these checks.

## Repository layout

```text
win10emojirefresh/
├─ src/Win11Emoji.ps1      # installer / diagnostics (PowerShell 5.1)
├─ src/FixPending.ps1      # normalizes PendingFileRenameOperations
├─ src/Setup/Program.cs    # source of the single-file setup.exe
├─ src/Setup/build.ps1     # rebuilds the setup.exe with the Windows C# compiler
├─ install.cmd             # self-elevates to System by default
├─ fix-pending.cmd         # normalizes a duplicated boot queue
├─ uninstall.cmd
├─ verify.cmd
├─ diagnose.cmd
├─ release/
│  └─ Win10EmojiRefresh-Setup.exe  # built locally; upload to GitHub Releases (not committed)
├─ docs/FAQ.md             # troubleshooting
├─ docs/INVESTIGATION.md   # local research notes
├─ docs/TECHNICAL.md       # this file
├─ tests/SmokeTests.ps1
├─ LICENSE                 # MIT (code)
└─ NOTICE.md               # third-party font notice
```

## Tests and rebuild

```powershell
powershell -ExecutionPolicy Bypass -File tests\SmokeTests.ps1
```

Covers syntax parsing, JSON diagnostics, font reading/validation, dry-run and
the embedded resources in the release setup. The real System-mode
install/rollback requires elevation and is not executed automatically.

To rebuild the release executable from source:

```powershell
powershell -ExecutionPolicy Bypass -File src\Setup\build.ps1
```

The `.exe` is generated from [Program.cs](../src/Setup/Program.cs) and embeds
[Win11Emoji.ps1](../src/Win11Emoji.ps1) and
[FixPending.ps1](../src/FixPending.ps1). It does **not** embed the font.

## Compatibility

- Windows 10 19041+ (tested on 19045.3803 / 22H2).
- PowerShell 5.1 (included with Windows 10).
- The emoji panel comes from `MicrosoftWindows.Client.CBS_*`
  (`TextInputHost.exe` / `InputApp.dll`). This project does not replace those
  binaries — it replaces the font they load from disk.

## Limitations

- Final appearance depends on the font version you obtain; the project cannot
  guarantee that a public mirror stays online.
- Apps with their own emoji assets (Discord, Slack, WhatsApp, some games) are
  not affected — they do not use the Windows font.
- Windows Update or `sfc /scannow` may restore 1.29; run the setup again.
- This backport changes **rendering**, not the Windows 10 emoji-panel search
  index. Search terms for newer emoji (for example `trans`) are compiled into
  Windows 10 input components / language data, not into the font. The panel can
  render the trans flag after the install, but `Win + .` may still not find it
  by that name.

## More

- [FAQ — troubleshooting](FAQ.md)
- [Local investigation](INVESTIGATION.md)
- [Legal and third-party notice](../NOTICE.md)
