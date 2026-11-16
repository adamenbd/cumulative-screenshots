"""Portable checks of Mac capture logic with native services replaced by fakes.

Run with QT_QPA_PLATFORM=offscreen python mac/verify.py.
These checks do not establish macOS compatibility.
"""
import sys
import tempfile
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch
from PySide6.QtWidgets import QApplication
from PySide6.QtGui import QImage
from PySide6.QtCore import Qt
from main import MacWindow, MacHotkey, frontmost_window_id

app = QApplication([])
board = SimpleNamespace(changeCount=lambda: 0)
workspace = SimpleNamespace(frontmostApplication=lambda: SimpleNamespace(processIdentifier=lambda: 42))
quartz = SimpleNamespace(
    kCGWindowListOptionOnScreenOnly=1, kCGWindowListExcludeDesktopElements=2,
    kCGNullWindowID=0, kCGWindowBounds='bounds', kCGWindowOwnerPID='pid',
    kCGWindowLayer='layer', kCGWindowAlpha='alpha', kCGWindowNumber='id',
    CGPreflightScreenCaptureAccess=lambda: True,
    CGRequestScreenCaptureAccess=lambda: None,
    CGWindowListCopyWindowInfo=lambda *_: [
        {'pid': 12, 'id': 1, 'layer': 0, 'bounds': {'Width': 600, 'Height': 400}},
        {'pid': 42, 'id': 2, 'layer': 3, 'bounds': {'Width': 600, 'Height': 400}},
        {'pid': 42, 'id': 3, 'layer': 0, 'bounds': {'Width': 600, 'Height': 400}}])
assert frontmost_window_id(quartz, workspace) == 3
appkit = SimpleNamespace(NSPasteboard=SimpleNamespace(generalPasteboard=lambda: board),
    NSWorkspace=SimpleNamespace(sharedWorkspace=lambda: workspace))
with patch.dict(sys.modules, {'Quartz': quartz, 'AppKit': appkit}), patch.object(MacHotkey, 'start'):
    window = MacWindow()
    window.show()
    app.processEvents()
    calls = []
    def capture_file(args, **kwargs):
        calls.append(args)
        image = QImage(600, 400, QImage.Format_RGB32)
        image.fill(Qt.white)
        assert image.save(args[-1], 'PNG')
        return SimpleNamespace(returncode=0)
    with patch('main.subprocess.run', side_effect=capture_file):
        window.capture()
        assert len(window.shots) == 1
        assert calls[0][-2] == '3'
        assert len(app.clipboard().mimeData().urls()) == 1
        assert 'Command+V' in window.status.text()
        window.list.item(0).setCheckState(Qt.Unchecked)
        assert app.clipboard().mimeData() is None or not app.clipboard().mimeData().hasUrls()
        window.list.item(0).setCheckState(Qt.Checked)
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'shot.png'
            window.export_to(str(path))
            assert QImage(str(path)).size() == window.shots[0].size()
        quartz.CGPreflightScreenCaptureAccess = lambda: False
        window.capture()
        assert len(window.shots) == 1
        assert 'Screen Recording' in window.status.text()
        assert len(calls) == 1
    window.close()
print('PASS: active-app window filtering, capture command, clipboard selection, export, permission denial (native services mocked).')
