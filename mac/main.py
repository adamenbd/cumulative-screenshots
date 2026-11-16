"""macOS launcher for the shared Cumulative Screenshots interface."""
import sys
import subprocess
import tempfile
from pathlib import Path

# Package the same interface used by the Linux port, rather than a second copy.
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'linux'))
from app import Window as SharedWindow
from PySide6.QtCore import QObject, Signal, QTimer
from PySide6.QtGui import QImage
from PySide6.QtWidgets import QApplication


class MacHotkey(QObject):
    capture = Signal()
    error = Signal(str)

    def start(self):
        from pynput.keyboard import GlobalHotKeys
        self.listener = GlobalHotKeys({'<cmd>+<shift>+<f8>': self.capture.emit})
        self.listener.start()

    def stop(self):
        if hasattr(self, 'listener'):
            self.listener.stop()


def frontmost_window_id(quartz, workspace):
    """Return the frontmost visible standard window belonging to the active app."""
    pid = workspace.frontmostApplication().processIdentifier()
    options = quartz.kCGWindowListOptionOnScreenOnly | quartz.kCGWindowListExcludeDesktopElements
    for window in quartz.CGWindowListCopyWindowInfo(options, quartz.kCGNullWindowID) or []:
        bounds = window.get(quartz.kCGWindowBounds, {})
        if (window.get(quartz.kCGWindowOwnerPID) == pid
                and window.get(quartz.kCGWindowLayer) == 0
                and window.get(quartz.kCGWindowAlpha, 1) > 0
                and bounds.get('Width', 0) > 1
                and bounds.get('Height', 0) > 1):
            return int(window[quartz.kCGWindowNumber])
    raise RuntimeError('No visible window in the active application.')


class MacWindow(SharedWindow):
    def __init__(self):
        super().__init__()
        from AppKit import NSPasteboard
        self.pasteboard = NSPasteboard.generalPasteboard()
        self.last_change = self.pasteboard.changeCount()
        self.status.setText('0 screenshots. Capture with Command+Shift+F8. Paste checked files with Command+V.')
        self.hotkey = MacHotkey(self)
        self.hotkey.capture.connect(self.capture)
        try:
            self.hotkey.start()
        except Exception as error:
            self.status.setText(f'Shortcut unavailable: {error}. Enable Accessibility and reopen the app.')
        # Qt on macOS may only notice external clipboard changes on activation.
        self.poll = QTimer(self)
        self.poll.setInterval(250)
        self.poll.timeout.connect(self.poll_clipboard)
        self.poll.start()

    def poll_clipboard(self):
        current = self.pasteboard.changeCount()
        if current != self.last_change:
            self.last_change = current
            self.collect()

    def collect(self):
        super().collect()
        if hasattr(self, 'pasteboard'):
            self.last_change = self.pasteboard.changeCount()

    def sync(self, *_):
        super().sync()
        self.status.setText(self.status.text().replace('Ctrl+V', 'Command+V'))
        if hasattr(self, 'pasteboard'):
            self.last_change = self.pasteboard.changeCount()

    def capture(self):
        try:
            import Quartz
            from AppKit import NSWorkspace
            if hasattr(Quartz, 'CGPreflightScreenCaptureAccess') and not Quartz.CGPreflightScreenCaptureAccess():
                Quartz.CGRequestScreenCaptureAccess()
                self.status.setText('Allow Screen Recording in System Settings, then reopen the app.')
                return
            window_id = frontmost_window_id(Quartz, NSWorkspace.sharedWorkspace())
            with tempfile.TemporaryDirectory(prefix='CumulativeCapture-') as folder:
                target = Path(folder) / 'capture.png'
                result = subprocess.run(
                    ['/usr/sbin/screencapture', '-x', '-o', '-C', '-l', str(window_id), str(target)],
                    capture_output=True, text=True, timeout=15, check=False)
                image = QImage(str(target))
                if result.returncode or image.isNull():
                    raise RuntimeError('Unable to capture. Check Screen Recording permission.')
                self.add(image)
        except Exception as error:
            self.status.setText(f'Capture unavailable: {error}')

    def closeEvent(self, event):
        self.poll.stop()
        self.hotkey.stop()
        super().closeEvent(event)


def main():
    if sys.platform != 'darwin':
        raise SystemExit('This launcher requires macOS. Use linux/app.py on Linux.')
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    window = MacWindow()
    window.show()
    return app.exec()


if __name__ == '__main__':
    sys.exit(main())
