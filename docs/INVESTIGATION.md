# Local investigation (Windows 10 Pro 22H2)

This document records what was found **inside the system itself** before any
implementation, as requested.

## 1. System identification

```
ProductName          : Windows 10 Pro
DisplayVersion       : 22H2
CurrentBuild         : 19045
UBR                  : 3803
WindowsBuildLabEx    : 19041.1.amd64fre.vb_release.191206-1406
OsArchitecture       : 64-bit
```

## 2. Installed emoji font

```
C:\Windows\Fonts\seguiemj.ttf        2,072,388 bytes  2019-12-07
```

Registry:

```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts
  "Segoe UI Emoji (TrueType)" = "seguiemj.ttf"
```

An identical second copy exists in WinSxS:

```
C:\Windows\WinSxS\amd64_microsoft-windows-font-truetype-segoeui_31bf3856ad364e35_10.0.19041.3636_none_45539a7cc791229e\seguiemj.ttf
```

Tables: `cmap, COLR, CPAL, cvt , DSIG, fpgm, gasp, GDEF, glyf, GPOS, GSUB,
head, hhea, hmtx, kern, loca, maxp, meta, name, OS/2, post, prep`.

Read values:

| Field | Value |
|---|---|
| `name` family | Segoe UI Emoji |
| `name` version | Version 1.29 |
| `head.fontRevision` | 0x00014A3D |
| `OS/2.fsType` | 8 |
| glyphs | 12,189 |
| highest codepoint (`cmap` fmt 12) | U+1FA95 |

Text embedded in the `name` table:

> Microsoft supplied font. You may use this font to create, display and print
> content as permitted by the license terms [...] Any other use is prohibited.

Legal conclusion: **do not redistribute** `seguiemj.ttf` in this repo (see
`NOTICE.md`).

## 3. Font fallback chains

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontLink\SystemLink` was
inspected for `Segoe UI`, `Tahoma`, etc. The chains end in
`SEGUISYM.TTF,Segoe UI Symbol`; **there is no `seguiemj`/emoji entry**.

`HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\FontMapperFamilyFallback`
also has no emoji entry.

That explains why editing those keys is not the solution: Windows treats the
`Segoe UI Emoji` family specially.

## 4. Emoji/input panel

Package:

```
C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy\
  TextInputHost.exe   123.26505.0.0
  InputApp.dll        123.26505.0.0
```

Font assets inside the package (`Assets\Fonts`): `AXPMDL2.ttf`,
`CloudAnimation.ttf`, `ECMDL2.ttf`, `ESIPMDL2.ttf`, `GetSMDL.ttf`,
`HandwritingMixedInput.ttf` — **no emoji font of its own**.

Relevant strings:

- `InputApp.dll`: `Emoji`, `Emoji_Kaomoji`, `Emoji_Sticker`, `Emoji_Symbol`,
  `ChatWithoutEmoji`.
- `EmojiDS.dll` (10.0.19041.3636): `GenerateSuggestionList`, `GetCandidates`,
  `LoadTrie`, `SetContextProperty`.
- `AdvancedEmojiDS.dll` (10.0.19041.3636): `DiverseEmojiSkinToneModifier`,
  `EmojiInputHistory.dat`, `EMOJITRANSLATION`.

Conclusion: the panel has rich suggestion data but **renders the system font**;
it does not need to be replaced.

## 5. Decisive experiment: per-user override

Candidate font obtained from a public mirror:

```
skeyuui/windows-seguiemj-emoji-tracker  →  seguiemj.ttf
12,450,664 bytes — Version 1.60 — 62,354 glyphs — up to U+1FAF8
```

Procedure:

1. Create `%LOCALAPPDATA%\Microsoft\Windows\Fonts\seguiemj_win11.ttf`.
2. Register in `HKCU\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts`:
   `"Segoe UI Emoji (TrueType)" = <path>`.
3. Notify Windows with `WM_FONTCHANGE` (`SendMessageTimeout(HWND_BROADCAST,
   0x001A, ...)`).
4. Capture a test HTML page with headless Edge (`--screenshot`), before/after.

Result:

| Capture | Size | SHA256 (prefix) |
|---|---|---|
| before | 24,840 B | `C33B53709573...` |
| after | 19,358 B | `80E721ED7DAF...` |
| after removing the registration | 24,840 B | `C33B53709573...` (identical) |

The test HTML contained old and new emojis (`🥲 🥹 🫠 🫨 🪿 🫩 🫮 🫯`) plus
ZWJ sequences and flags. The hash change and exact return to the original
initially suggested that the per-user font had priority and was reversible
without a reboot.

## 6. Why not just copy over `C:\Windows\Fonts`

The file is protected (TrustedInstaller) and usually locked, requiring
elevation, ACL changes and often `PendingFileRenameOperations` + reboot.
In addition, cumulative updates or `sfc /scannow` can revert it. That is why
`User` mode used to be the default; `System` mode is now the correct path for
the original request.

## 7. External references consulted

- <https://learn.microsoft.com/typography/font-list/segoe-ui-emoji>
- <https://github.com/microsoft/fluentui-emoji> (MIT; SVG/PNG, no ready TTF)
- <https://github.com/googlefonts/noto-emoji> (OFL)
- <https://github.com/dirtTW/Segoe-UI-Emoji-Updater> (reference for the
  replacement/backup technique)
- <https://github.com/skeyuui/windows-seguiemj-emoji-tracker> (font mirror)
- <https://github.com/Gitbreast/win11_emoji_for_win10> (alternative mirror)

## 8. Decisive correction: the `Win + .` panel ignores the per-user override

After the report that the panel still showed Windows 10 emojis, a memory dump of
`TextInputHost.exe` (PID 41892, 451 MB) was searched for `seguiemj`:

```
UTF-16 @ 1892584:  ... C:\WINDOWS\FONTS\SEGUIEMJ.TTF ...
ASCII @ 75489938:  ... Segoe UI EmojiRegularVersion 1.29SegoeUIEmoji ...
```

Conclusion: the `TextInputHost` **loads the font from the absolute system path**
and keeps the v1.29 data in memory. The `HKCU\...\Fonts` registration influences
apps that request the family by name (confirmed in Edge), but **not** the emoji
panel and not necessarily every text field.

This reverses the original recommendation:

- `User` → useful but limited; **does not fix `Win + .`**.
- `System` → replaces the file the panel actually opens; now the default and the
  correct answer to the original request.

The dump also explains why the headless Edge test was misleading: it validated
DirectWrite family resolution, not the fixed-path load performed by the input
component.

## 9. Limitations of the investigation

- Windows 11 is not installed on this machine; the Windows 11 font version was
  confirmed through public mirrors and documentation, not by reading a local
  Windows 11 installation.
- The current session is not elevated (`net session` fails; medium integrity
  token), so the `System` mode was implemented using standard techniques but
  **could not be executed here**.
- `Get-WindowsPackage -Online` also requires elevation; the
  `MicrosoftWindows.Client.CBS` version was read from files on disk.

## 10. Emoji search terms are not in the font

After the System-mode install, the panel renders Windows 11 emoji correctly,
but searching `trans` in `Win + .` still does not find the trans flag. This is
expected: the TTF contains glyphs and cmap entries, not human-readable search
tags.

Local inspection found the search machinery in Windows 10 components:

```
C:\Windows\System32\EmojiDS.dll
  EmojiDS::LoadTrie
  EmojiDS::GetCandidates
  EmojiDS::GenerateSuggestionList

C:\Windows\System32\AdvancedEmojiDS.dll
  EMOJITRANSLATION
  EmojiInputHistory.dat
  DiverseEmojiSkinToneModifier

C:\Windows\SystemApps\MicrosoftWindows.Client.CBS_*\InputApp.dll
  Search / Searchable / SupportsSearch
```

There is also an emoji fluency/language model at:

```
C:\Windows\Globalization\ELS\SpellDictionaries\Fluency\<locale>\emoji_bg_c.lm2
```

No `trans`, `nonbinary`, `rainbow`, `pride` or the trans-flag byte sequence was
found in the inspected DLLs, and `emoji_bg_c.lm2` is a compiled/huffman-like
binary model rather than editable text. Updating the keyword set would require
patching Microsoft binaries or replacing the language model with a Windows 11
version. Both would mean redistributing modified/proprietary Microsoft files or
importing protected OS components, which this project deliberately avoids.

Conclusion: this backport fixes **rendering** (`seguiemj.ttf`); the Windows 10
search index remains Windows 10-era. A future optional experiment could import
the Windows 11 panel components from a user-supplied Windows 11 installation,
but that is not part of the safe release setup.
