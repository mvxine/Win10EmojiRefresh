**Win10 Emoji Refresh**  
[![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAxElEQVR4nO1W0Q6AIAiE/v+bpaeaYyYc6NLVvbRm484DL1lEKAIRIWaG1zQ4IgAhsHCMJkc31BXQKmbtvF73iOkKQIvV8LbpFqAJ9Dvac2Z2iQ4N4UiYQ2gJ9G7g6TsupQw7UpHjefTCBCEmwueEaPAMhBzQBVDC+tkit2pOOQWXEx5H0gIy/ScK/Atq0os4k5ihHOilHJyYyyfhTIjIJg48idQ5EME6DrwlZB0HthaQcRG+FbeQuaZ/ewb2ScJfQBSe9p77EZ7a26s/yQAAAABJRU5ErkJggg==)](../../releases/latest "../../releases/latest")  
   
 [![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAxElEQVR4nO1W0Q6AIAiE/v+bpaeaYyYc6NLVvbRm484DL1lEKAIRIWaG1zQ4IgAhsHCMJkc31BXQKmbtvF73iOkKQIvV8LbpFqAJ9Dvac2Z2iQ4N4UiYQ2gJ9G7g6TsupQw7UpHjefTCBCEmwueEaPAMhBzQBVDC+tkit2pOOQWXEx5H0gIy/ScK/Atq0os4k5ihHOilHJyYyyfhTIjIJg48idQ5EME6DrwlZB0HthaQcRG+FbeQuaZ/ewb2ScJfQBSe9p77EZ7a26s/yQAAAABJRU5ErkJggg==)  
   
 ](LICENSE "LICENSE")[![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAxElEQVR4nO1W0Q6AIAiE/v+bpaeaYyYc6NLVvbRm484DL1lEKAIRIWaG1zQ4IgAhsHCMJkc31BXQKmbtvF73iOkKQIvV8LbpFqAJ9Dvac2Z2iQ4N4UiYQ2gJ9G7g6TsupQw7UpHjefTCBCEmwueEaPAMhBzQBVDC+tkit2pOOQWXEx5H0gIy/ScK/Atq0os4k5ihHOilHJyYyyfhTIjIJg48idQ5EME6DrwlZB0HthaQcRG+FbeQuaZ/ewb2ScJfQBSe9p77EZ7a26s/yQAAAABJRU5ErkJggg==)](#anchor-1 "#anchor-1")  
[![](data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACAAAAAgCAYAAABzenr0AAAABmJLR0QA/wD/AP+gvaeTAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAxElEQVR4nO1W0Q6AIAiE/v+bpaeaYyYc6NLVvbRm484DL1lEKAIRIWaG1zQ4IgAhsHCMJkc31BXQKmbtvF73iOkKQIvV8LbpFqAJ9Dvac2Z2iQ4N4UiYQ2gJ9G7g6TsupQw7UpHjefTCBCEmwueEaPAMhBzQBVDC+tkit2pOOQWXEx5H0gIy/ScK/Atq0os4k5ihHOilHJyYyyfhTIjIJg48idQ5EME6DrwlZB0HthaQcRG+FbeQuaZ/ewb2ScJfQBSe9p77EZ7a26s/yQAAAABJRU5ErkJggg==)](../../releases/latest "../../releases/latest")  
Get **Windows 11 emoji** on **Windows 10** — including the `Win + .` emoji  
   
 panel. It replaces only the `Segoe UI Emoji` font, keeps a backup of your  
   
 current one, and can undo the change.  
The setup does **not** contain the Microsoft font. It downloads the font from  
   
 public mirrors when it runs, or you can supply your own file.  
*\[!WARNING\]*  
   
 *Double-click the setup normally.* ***Do not*** *right-click it → "Run as*  
   
 *administrator". The setup asks for UAC by itself. Running it twice before*  
   
 *rebooting can duplicate the boot-time font swap.*  
**Install**  
1. Download `Win10EmojiRefresh-Setup.exe` from the **Releases** page.  
2. Double-click it.  
3. Answer `Y` to continue, then accept the Windows UAC prompt.  
4. If it asks to restart, type `Y` only when you are ready to save and close  
   
 your work. `N` lets you restart later.  
5. After the restart (if one was needed), open `Win + .` and enjoy the new emoji.  
Already have the font file? Pass it to the setup:  
```  
Win10EmojiRefresh-Setup.exe --source C:\Downloads\seguiemj.ttf  
   
```  
To see the available options:  
```  
Win10EmojiRefresh-Setup.exe --help  
   
```  
**Did it work?**  
If you downloaded the source too, run `verify.cmd`. A healthy install says:  
```  
OK: system font is Segoe UI Emoji Version 1.60.  
   
```  
If it says `Version 1.29`, reboot and check again. If you already rebooted, see  
   
 the FAQ below.  
**Uninstall**  
Run `uninstall.cmd` from the source folder and accept the UAC prompt. It restores  
   
 the font that was active before the install. A reboot may be required.  
**FAQ**  
**Do I need administrator rights?**  
Yes, for the emoji panel. The setup requests UAC automatically — you do not need  
   
 to do anything special. There is a limited no-admin mode, but it does **not**  
   
 change `Win + .`; see the [technical details.](#anchor-2 "#anchor-2")  
**The first window closed immediately. Did it fail?**  
Probably not. When UAC is needed, the first window exits and a **new** elevated  
   
 window opens. Continue in that new window. If you declined UAC, nothing was  
   
 changed — run the setup again and accept the prompt.  
**It said the swap was queued, and nothing changed yet. Now what?**  
Reboot the PC. Windows applies the font during startup because the old file is  
   
 in use. After the reboot, check `Win + .` again.  
If you ran the installer more than once before rebooting, run  
   
 `fix-pending.cmd` once (from the source folder) **before** rebooting. It cleans  
   
 up the duplicated queue entry.  
**Does it restart my PC automatically?**  
Only if the font swap was queued **and** you answer `Y` to the restart question.  
   
 Answering `N` leaves the machine running; restart whenever convenient.  
**I only downloaded the** `.exe`**. Where is** `verify.cmd`**?**  
`verify.cmd` is in the source repository and is optional. If you only have the  
   
 setup, just reboot if asked and try `Win + .` — new emoji rendering is the real  
   
 test.  
## **Why can't I search for "trans (🏳️‍⚧️)" or other new emoji tags in** `Win + .`**?**  
Because the font draws emoji but does **not** store their names. The search  
   
 words live in Windows 10's input components and language data, which this  
   
 project does not replace. The trans flag will **render** correctly after the  
   
 install, but searching `trans` may still return nothing. Searching `smile`  
   
 still works.  
**Will it work in Discord, Slack, WhatsApp or games?**  
Usually no. Those apps ship their own emoji artwork and do not use the Windows  
   
 font. This project only affects apps that use the system font, including the  
   
 `Win + .` panel and most browsers.  
**Can Windows Update undo it?**  
Yes. A cumulative update or `sfc /scannow` may restore the old font. Just run  
   
 the setup or `install.cmd` again.  
**Is the Microsoft font bundled in the download?**  
No. The `.exe` contains only the project's own code and scripts. You are  
   
 responsible for obtaining the font; see [NOTICE.md.](NOTICE.md "NOTICE.md")  
More troubleshooting lives in the [full FAQ. The research behind  
   
 the search limitation is in](docs/FAQ.md "docs/FAQ.md") [INVESTIGATION.md.](docs/INVESTIGATION.md "docs/INVESTIGATION.md")  
**For developers**  
The readable source, build script, options and internals are in  
   
 [docs/TECHNICAL.md. The code is MIT licensed; the Microsoft  
   
 font is not redistributed.](docs/TECHNICAL.md "docs/TECHNICAL.md")  
