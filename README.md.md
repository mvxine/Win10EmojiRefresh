# Win10 Emoji Refresh

[![Downloads](https://img.shields.io/github/downloads/mvxine/win10emojirefresh/Win10EmojiRefresh-Setup.exe/total?style=for-the-badge&label=Downloads)](../../releases/latest)
[![License](https://img.shields.io/github/license/mvxine/win10emojirefresh?style=for-the-badge)](LICENSE)
[![Latest Release](https://img.shields.io/github/v/release/mvxine/win10emojirefresh?style=for-the-badge)](../../releases/latest)

Get **Windows 11 emoji on Windows 10** — including the `Win + .` emoji panel.

It replaces only the `Segoe UI Emoji` font, keeps a backup of your current one, and can undo the change.

The setup does **not** include the Microsoft font. It automatically downloads the required `Segoe UI Emoji` font from public mirrors during installation. No manual download is needed. You can also provide your own font file using the `--source` option.

---

## ⚠️ Warning

**Double-click the setup normally. Do not right-click it → "Run as administrator".** The setup asks for UAC by itself.

Running it twice before rebooting can duplicate the boot-time font swap.

---

## Installation

1. Download `Win10EmojiRefresh-Setup.exe` from the [Releases](../../releases/latest) page.
2. Double-click it.
3. Answer `Y` to continue, then accept the Windows UAC prompt.
4. If it asks to restart, type `Y` when you're ready to save and close your work. Type `N` to restart later.
5. After restarting (if needed), press `Win + .` and enjoy the new emoji!

Already have the font file? Pass it to the setup:

```cmd
Win10EmojiRefresh-Setup.exe --source C:\Downloads\seguiemj.ttf
```

To see the available options:

```cmd
Win10EmojiRefresh-Setup.exe --help
```

---

## Did it work?

If you downloaded the source too, run `verify.cmd`. A healthy install says:

```text
OK: system font is Segoe UI Emoji Version 1.60.
```

If it says `Version 1.29`, reboot and check again. If you already rebooted, see the FAQ below.

---

## Uninstall

Run `uninstall.cmd` from the source folder and accept the UAC prompt. It restores the font that was active before the install. A reboot may be required.

---

## FAQ

**Do I need administrator rights?**

Yes, for the emoji panel. The setup requests UAC automatically — you do not need to do anything special. There is a limited no-admin mode, but it does **not** change `Win + .`; see the [technical details](docs/TECHNICAL.md).

**The first window closed immediately. Did it fail?**

Probably not. When UAC is needed, the first window exits and a **new** elevated window opens. Continue in that new window. If you declined UAC, nothing was changed — run the setup again and accept the prompt.

**It said the swap was queued, and nothing changed yet. Now what?**

Reboot the PC. Windows applies the font during startup because the old file is in use. After the reboot, check `Win + .` again.

If you ran the installer more than once before rebooting, run `fix-pending.cmd` once (from the source folder) **before** rebooting. It cleans up the duplicated queue entry.

**Does it restart my PC automatically?**

Only if the font swap was queued **and** you answer `Y` to the restart question. Answering `N` leaves the machine running; restart whenever convenient.

**I only downloaded the `.exe`. Where is `verify.cmd`?**

`verify.cmd` is in the source repository and is optional. If you only have the setup, just reboot if asked and try `Win + .` — new emoji rendering is the real test.

**Why can't I search for "trans (🏳️‍⚧️)" or other new emoji tags in `Win + .`?**

Because the font draws emoji but does **not** store their names. The search words live in Windows 10's input components and language data, which this project does not replace. The trans flag will **render** correctly after the install, but searching `trans` may still return nothing. Searching `smile` still works.

**Will it work in Discord, Slack, WhatsApp or games?**

Usually no. Those apps ship their own emoji artwork and do not use the Windows font. This project only affects apps that use the system font, including the `Win + .` panel and most browsers.

**Can Windows Update undo it?**

Yes. A cumulative update or `sfc /scannow` may restore the old font. Just run the setup or `install.cmd` again.

**Is the Microsoft font bundled in the download?**

No. The `.exe` contains only the project's own code and scripts. The font is downloaded automatically from public mirrors during installation. You are responsible for obtaining the font if you choose to supply your own file; see [NOTICE.md](NOTICE.md).

More troubleshooting lives in the [full FAQ](docs/FAQ.md). The research behind the search limitation is in [INVESTIGATION.md](docs/INVESTIGATION.md).

---

## For Developers

The readable source, build script, options and internals are in [TECHNICAL.md](docs/TECHNICAL.md).

The code is MIT licensed; the Microsoft font is not redistributed.

---

**Owner:** [@mvxine](https://github.com/mvxine)