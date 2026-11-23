# Legal and third-party notice

## This project

The code in this repository is MIT licensed (see `LICENSE`).

## The `seguiemj.ttf` font

**We do not redistribute the font.** `Segoe UI Emoji` is owned by Microsoft.
The font's `name` table contains:

> "Microsoft supplied font. You may use this font to create, display and print
> content as permitted by the license terms [...] Any other use is prohibited."

The `fsType` field is `8` (embeddable for viewing/printing), which **does not**
grant permission to redistribute the file. The official page confirms this:
<https://learn.microsoft.com/typography/font-list/segoe-ui-emoji>.

This project downloads the font from public third-party mirrors, or accepts a
local file through `-Source` / `setup.exe --source`. **You are responsible for
obtaining the file and for complying with Microsoft's terms.** If that is not
acceptable to you, do not use this project.

The release executable `Win10EmojiRefresh-Setup.exe` embeds only the project's
own scripts (`Win11Emoji.ps1` and `FixPending.ps1`). It does **not** contain
`seguiemj.ttf` or any other Microsoft binary.

### Free alternative

If you need a fully redistributable solution, use a freely licensed emoji font,
for example:

- [Microsoft Fluent Emoji](https://github.com/microsoft/fluentui-emoji) (MIT) —
  visually close to the Windows 11 designs, provided as SVG/PNG.
- [Noto Color Emoji](https://github.com/googlefonts/noto-emoji) (OFL).

To use one of those, convert it to TTF with the family name `Segoe UI Emoji`
and pass the file with `-Source`. The installer validates the family, version
and the presence of the `COLR` table before installing.

## Default mirrors

- `skeyuui/windows-seguiemj-emoji-tracker`
- `Gitbreast/win11_emoji_for_win10`

They are download sources only; use `-Url` or `-Source` to choose another one.
Always verify the SHA256 with `-ExpectedSha256` in sensitive environments.
