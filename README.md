# Cumulative Screenshots

A small, portable Windows app to collect screenshots, review them, and paste the checked ones as separate PNG files.

## Use

1. [Download CumulativeScreenshots.exe](https://github.com/javiadaame/cumulative-screenshots/raw/refs/heads/main/bin/CumulativeScreenshots.exe) and open it. No installer or console window.
2. Press **Alt + Print Screen** to capture the active window. Each capture gets a visible confirmation and is checked automatically.
3. Click a screenshot to preview it. Use its **checkbox** to include or exclude it.
4. Press **Ctrl + V** in your destination app. The checked screenshots are already on the clipboard as individual files.

**Export all screenshots** saves every screenshot as a separate PNG using a modern Save As dialog. The first uses your chosen filename; the rest add `-002`, `-003`, etc.

## Notes

- Windows 10/11 with Windows PowerShell 5.1 and .NET Framework 4.x. No Python, Rust, or Go required. Opening the app does not take a screenshot.
- The mouse cursor is added for matching active-window captures when it is inside the captured area. Other images copied to the clipboard are also collected while the app is open.
- Pasting multiple files depends on the destination app. HTML with separate images is also offered; use PNG export if your app does not support either format.
- Copying text or other content takes priority until you capture again or change a checkbox. Closing the app stops collection and replaces its clipboard group with the last single screenshot, if the group is still current.
- Everything stays local. Clipboard PNGs remain in `%TEMP%\CumulativeScreenshots-*` until temporary files are cleaned. Export screenshots you want to keep before closing. The collection is limited to 100 million pixels.

## Build

From Windows PowerShell, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```

The build embeds `src/App.ps1` inside `bin/CumulativeScreenshots.exe`. A small C# launcher hosts the Windows PowerShell engine in-process, so no `powershell.exe` console opens when you run the app.
