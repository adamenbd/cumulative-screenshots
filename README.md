# Cumulative Screenshots

A portable Windows app to collect screenshots and paste them as separate PNG files.

## Use

1. [Download CumulativeScreenshots.exe](https://github.com/adamenbd/cumulative-screenshots/raw/refs/heads/main/bin/CumulativeScreenshots.exe) and open it.
2. Press **Alt + Print Screen** to capture the active window.
3. Click a screenshot to preview it. Uncheck any you don't want to include.
4. Press **Ctrl + V** in an app that supports pasting files.

Use **Export all screenshots** to save all captures as PNG files.

Requires Windows 10/11, Windows PowerShell 5.1 and .NET Framework 4.x. No installation needed.

## Build

Run from Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\build.ps1
```
