# Linux

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r linux/requirements.txt
python linux/app.py
```

Use an X11 session for Alt + Print Screen capture. Clipboard images are collected automatically. Check the images to paste, or export all as separate PNGs.

The layout follows the Windows app. Linux uses Qt controls, so fonts and window decorations can differ. Wayland global capture, tray integration and capture notifications are not implemented yet.
