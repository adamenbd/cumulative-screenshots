"""Exercise the Linux UI on an X11 display and save real window captures."""
from pathlib import Path
import time
from PySide6.QtWidgets import QApplication, QWidget, QVBoxLayout, QLabel, QTextEdit
from PySide6.QtCore import Qt
from PySide6.QtTest import QTest
from Xlib import display, X, XK
from Xlib.ext import xtest
from app import Window

out = Path('/tmp/artifacts/cumulative-screenshots')
out.mkdir(parents=True, exist_ok=True)
app = QApplication([])
app.setStyle('Fusion')
w = Window()
w.move(160, 80)
w.show()
QTest.qWait(200)
w.grab().save(str(out / '01-empty.png'))
d = display.Display()
demo = QWidget()
demo.resize(640, 400)
demo.move(20, 20)
layout = QVBoxLayout(demo)
heading = QLabel('Example notes')
heading.setStyleSheet('font-size: 24px; font-weight: bold; padding: 12px')
layout.addWidget(heading)
editor = QTextEdit()
editor.setPlainText('Project notes\n\n1. Capture a window with Alt + Print Screen.\n2. Review the screenshots in the list.\n3. Paste the checked files or export all.\n\nThis is a real Linux window used for the capture test.')
layout.addWidget(editor)
demo.show()
QTest.qWait(200)
win = d.create_resource_object('window', int(demo.winId()))
win.set_input_focus(X.RevertToParent, X.CurrentTime)
d.sync()
QTest.qWait(200)
for name in ('Alt_L', 'Print'):
    xtest.fake_input(d, X.KeyPress, d.keysym_to_keycode(XK.string_to_keysym(name)))
for name in ('Print', 'Alt_L'):
    xtest.fake_input(d, X.KeyRelease, d.keysym_to_keycode(XK.string_to_keysym(name)))
d.sync()

for _ in range(30):
    app.processEvents()
    time.sleep(0.03)

assert len(w.shots) == 1, 'Global shortcut failed'
assert w.shots[0].size() == demo.size()
heading.setText('Export checklist')
editor.setPlainText('Screenshots to share\n\n[✓] Notes window\n[✓] Export checklist\n[✓] Clipboard example\n\nEach screenshot is exported as its own PNG file.')
QTest.qWait(100)
w.capture()
heading.setText('Clipboard example')
editor.setPlainText('Clipboard image collection\n\nImages copied from another application are added to the list automatically.\n\nUncheck any screenshot to exclude it from the files ready to paste.')
QTest.qWait(100)
app.clipboard().setImage(app.primaryScreen().grabWindow(int(demo.winId())).toImage())
QTest.qWait(100)
assert len(w.shots) == 3
w.list.item(1).setCheckState(Qt.Unchecked)
assert len(app.clipboard().mimeData().urls()) == 2
assert app.clipboard().mimeData().hasHtml()
w.export_to(str(out / 'example.png'))
assert all((out / n).exists() for n in ['example.png','example-002.png','example-003.png'])
demo.hide()
w.list.setCurrentRow(0)
w.sync()
QTest.qWait(100)
w.grab().save(str(out / '02-collected.png'))
w.list.setCurrentRow(2)
QTest.qWait(100)
w.grab().save(str(out / '03-preview.png'))
w.delete()
assert len(w.shots) == 2
print('PASS: X11 global hotkey, active-window capture, clipboard image collection, checkbox filtering, PNG file clipboard, HTML clipboard, PNG export, preview, deletion')
d.close()
w.close()
