# macOS

Requires Python 3.10+ and macOS 13+. Download the repository, then run:

```sh
bash mac/Start.command
```

1. Allow **Screen Recording** and **Accessibility** in System Settings → Privacy & Security for the app or terminal running it. Allow Input Monitoring if macOS requests it.
2. Reopen the app and press **Command + Shift + F8** to capture the active window. Hold Fn too if F8 controls media.
3. Check the screenshots to include and press **Command + V** in an app that accepts files, such as Finder.

**Export all screenshots** saves every capture as a separate PNG. Clipboard images are also collected while the app is open.

Uses the same interface as the Linux port. macOS window decorations and fonts can differ. Tray integration and capture notifications are not implemented. Native capture, permissions and pasting still need verification on a Mac. This is a source version, not a signed `.app`.
