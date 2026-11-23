# FAQ / Troubleshooting

All commands below are run from the project folder.

---

## What does `Win10EmojiRefresh-Setup.exe` do?

It is a single executable for the GitHub release. Double-click it normally; do
not right-click → "Run as administrator". It asks for confirmation, requests UAC
by itself, and then:

1. runs the embedded `FixPending.ps1 -ClearOnly` to remove stale `seguiemj`
   entries from `PendingFileRenameOperations`;
2. runs the embedded `Win11Emoji.ps1 -Mode System` to install the font;
3. asks `[Y/N]` before rebooting **only** if the swap was queued.

It does not contain the Microsoft font. Use
`Win10EmojiRefresh-Setup.exe --source C:\Downloads\seguiemj.ttf` if you already
have the font file.

The source and the build script are in `src/Setup/`, so the executable can be
rebuilt and audited.

---

## I ran the setup and the first window closed immediately

That is expected when UAC is required. The original window exits after launching
the elevated copy; a **new** console window appears for the real installation.
Do not run the setup a second time. If UAC was declined, nothing was changed —
run it again and accept the prompt.

---

## Does the setup reboot automatically?

No. If the font file was locked and Windows queued the swap for the next boot,
the setup asks:

```
Do you want to restart the computer NOW? [Y/N]:
```

`Y` restarts in 10 seconds. `N` or Enter leaves the machine running; reboot
manually when convenient and then run `verify.cmd`. If no swap was queued, the
setup does not ask and reports that no reboot is needed.

---

## Why does `Win + .` not find new emoji by name?

This is a **separate limitation** from rendering. The backport replaces only
`seguiemj.ttf`. The emoji panel's search terms/index live in Windows 10 input
components and language data — notably `EmojiDS.dll` /
`AdvancedEmojiDS.dll` and the fluency model
`C:\Windows\Globalization\ELS\SpellDictionaries\Fluency\<locale>\emoji_bg_c.lm2`.
Those files still contain the Windows 10-era keyword set.

Result: after the install, newer emoji **render** correctly (you can paste them
from a web page and see the Windows 11 artwork), but typing `trans` in the
`Win + .` search box may still return nothing. Searching `smile` should still
work. If even old terms return nothing, install the latest Windows 10
cumulative update instead — some 2025 updates broke emoji search generally.

There is no safe fix in this project: patching Microsoft DLLs or replacing the
language model would mean redistributing modified Microsoft binaries. This
repository does not do that. Practical workaround: copy the emoji from a site
such as Emojipedia, or keep a small text snippet of the emojis you use often.

---

## I ran `install.cmd` and "nothing happened"

This almost always means the install only **queued** the swap and you have not
rebooted yet. The console printed something like:

```
File is in use; queuing the swap for the next boot.
Swap queued. Restart the computer to apply it.
```

That is expected: `C:\Windows\Fonts\seguiemj.ttf` is locked by running apps, so
Windows applies the rename during startup.

Do this:

1. **If you ran `install.cmd` more than once before rebooting**, run
   `fix-pending.cmd` first (accept UAC). It removes duplicate entries and fixes
   the path format.
2. Reboot the PC.
3. Run `verify.cmd`.

> [!WARNING]
> **Never "fix" this by right-clicking `install.cmd` → Run as administrator and
> running it again.** See the question below.

---

## I ran `install.cmd` and `verify.cmd` still shows 1.29

Check in this order:

1. Did `install.cmd` say **"Swap queued"**? → reboot is required.
2. Did you run `install.cmd` twice? → run `fix-pending.cmd`, then reboot.
3. Did you decline the UAC prompt? → the system font was never touched. Run
   `install.cmd` again and accept the prompt.
4. Did a Windows Update or `sfc /scannow` run after the reboot? → run
   `install.cmd -Force`.

Run `diagnose.cmd` to see the current state. If it reports
`Administrator: False`, that is fine for diagnostics — only the install needs
elevation.

---

## Should I right-click `install.cmd` and choose "Run as administrator"?

**No.** `install.cmd` already detects missing privileges and requests UAC on
its own.

Doing it manually causes two problems:

- It is easy to launch it twice (once normally, once elevated), which appends
  two sets of `PendingFileRenameOperations`. At boot those pairs can cancel each
  other out and leave `seguiemj.ttf` missing.
- The elevated process opens a second window, so it looks as if the first run
  "did nothing".

If you already did this, run **`fix-pending.cmd`** before rebooting. It keeps
only one valid swap:

```
C:\Windows\Fonts\seguiemj.ttf  ->  ...\seguiemj-retired-v1.29-....ttf
C:\Windows\Fonts\seguiemj.stage ->  C:\Windows\Fonts\seguiemj.ttf
```

---

## The `.cmd` window closes before I can read it

This was fixed in the current version: every wrapper captures the exit code,
uses the Windows `pause` command and waits. On a Portuguese Windows system the
localized `pause` text may still read `Pressione qualquer tecla para
continuar...`; the script messages themselves are in English.

If it still closes, start it from an already open Command Prompt:

```bat
cmd /k "D:\mod menu\win10emojirefresh\verify.cmd"
```

`cmd /k` keeps the window open after the script exits.

---

## I used `-Mode User` but `Win + .` still shows Windows 10 emojis

Expected. The emoji panel (`TextInputHost.exe`) loads the font by the fixed path
`C:\Windows\Fonts\seguiemj.ttf` and ignores the per-user `HKCU` registration.
The `User` mode only affects applications that ask for the `Segoe UI Emoji`
family by name (for example Chromium-based browsers).

Use the default `System` mode for the panel.

---

## What exactly does `fix-pending.cmd` do?

It requires administrator rights and:

1. reads `HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\
   PendingFileRenameOperations`;
2. removes every entry containing `seguiemj`;
3. writes exactly one correct pair of rename operations using the staged v1.60
   font at `C:\Windows\Fonts\seguiemj.stage`;
4. asks you to reboot.

It does **not** download anything and does **not** change the font immediately.
The change happens at the next boot.

---

## `verify.cmd` exits with code 1

That is not a crash. Exit code 1 means "the system font is still older than
1.30". The console says:

```
FAIL: the system font is still old (< 1.30)...
```

Follow ["I ran install.cmd and verify still shows 1.29"](#i-ran-installcmd-and-verify-still-shows-129).

Exit code 0 means the v1.60 font is active.

---

## Windows Update restored the old font

Cumulative updates and `sfc /scannow` can replace `seguiemj.ttf` with the
Windows 10 version. Re-apply with:

```bat
install.cmd -Force
```

Your original backup is kept under
`%LOCALAPPDATA%\Win11EmojiBackport\backups\system` (legacy folder ID, kept for
compatibility with backups from earlier versions).

---

## Discord / WhatsApp / Slack still show different emojis

Those applications ship their own emoji assets and do not use the Windows font.
This project cannot change them. The Windows emoji panel, Notepad and apps that
use `Segoe UI Emoji` from the OS will change.

---

## How do I undo everything?

```bat
uninstall.cmd
```

It self-elevates, restores the newest backup and marks the state file as used.
Reopen running applications afterwards. If the restore was queued, reboot.

---

## Am I redistributing a Microsoft font?

No. The repository contains only code, documentation and tests. The font is
downloaded from third-party mirrors at install time, or supplied by you via
`-Source`. See `NOTICE.md`.
