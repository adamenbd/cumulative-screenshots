"""Cumulative Screenshots for Linux (X11)."""
import sys, tempfile, threading
from pathlib import Path
from datetime import datetime
from PySide6.QtCore import Qt, QTimer, QMimeData, QUrl, Signal, QObject
from PySide6.QtGui import QPixmap, QImage, QFont
from PySide6.QtWidgets import (QApplication, QWidget, QPushButton, QListWidget,
    QListWidgetItem, QLabel, QHBoxLayout, QVBoxLayout, QFileDialog, QMessageBox)

class Hotkey(QObject):
    capture = Signal()
    def start(self):
        def listen():
            try:
                from Xlib import X, XK, display
                d = display.Display()
                root = d.screen().root
                key = d.keysym_to_keycode(XK.string_to_keysym('Print'))
                for extra in (0, X.LockMask, X.Mod2Mask, X.LockMask | X.Mod2Mask):
                    root.grab_key(key, X.Mod1Mask | extra, False, X.GrabModeAsync, X.GrabModeAsync)
                d.sync()
                while True:
                    if d.next_event().type == X.KeyPress:
                        self.capture.emit()
            except Exception as error:
                print('Global shortcut unavailable:', error, file=sys.stderr)
        threading.Thread(target=listen, daemon=True).start()

class Window(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle('Cumulative Screenshots')
        self.resize(960, 700)
        self.setMinimumSize(760, 500)
        self.setFont(QFont('Segoe UI', 10))
        self.shots = []
        self.owned = None
        self.folder = Path(tempfile.mkdtemp(prefix='CumulativeScreenshots-'))
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)
        bar = QWidget()
        bar.setFixedHeight(88)
        buttons = QHBoxLayout(bar)
        buttons.setContentsMargins(10, 10, 10, 46)
        for title, action in [('Delete previewed screenshot', self.delete), ('Clear list', self.clear), ('Export all screenshots', self.export)]:
            button = QPushButton(title)
            button.setMinimumHeight(32)
            button.clicked.connect(action)
            buttons.addWidget(button)
        buttons.addStretch()
        outer.addWidget(bar)
        body = QHBoxLayout()
        body.setSpacing(0)
        self.list = QListWidget()
        self.list.setFixedWidth(210)
        self.list.currentRowChanged.connect(self.preview)
        self.list.itemChanged.connect(self.sync)
        body.addWidget(self.list)
        self.image = QLabel()
        self.image.setAlignment(Qt.AlignCenter)
        self.image.setStyleSheet('background: rgb(35,39,46)')
        body.addWidget(self.image, 1)
        outer.addLayout(body, 1)
        self.status = QLabel('0 screenshots. Check the ones to paste, then press Ctrl+V in your destination app.')
        self.status.setFixedHeight(55)
        self.status.setContentsMargins(10, 0, 10, 0)
        outer.addWidget(self.status)
        self.clip = QApplication.clipboard()
        self.clip.dataChanged.connect(self.collect)
        self.hotkey = Hotkey()
        self.hotkey.capture.connect(self.capture)
        if QApplication.platformName() == 'xcb':
            self.hotkey.start()
        else:
            self.status.setText('Global capture needs X11. Clipboard image collection is available.')

    def capture(self):
        try:
            from Xlib import display
            d = display.Display()
            root = d.screen().root
            prop = root.get_full_property(d.intern_atom('_NET_ACTIVE_WINDOW'), 0)
            wid = int(prop.value[0]) if prop is not None else d.get_input_focus().focus.id
            shot = QApplication.primaryScreen().grabWindow(wid)
            d.close()
            if not shot.isNull():
                self.add(shot.toImage())
        except Exception as error:
            self.status.setText('Capture unavailable: ' + str(error))

    def collect(self):
        data = self.clip.mimeData()
        if data and data.hasImage():
            image = self.clip.image()
            if not image.isNull():
                self.add(image)

    def add(self, image):
        if sum(s.width() * s.height() for s in self.shots) + image.width() * image.height() > 100000000:
            self.status.setText('Memory limit reached. Export and delete screenshots to continue.')
            return
        self.shots.append(image.copy())
        self.list.blockSignals(True)
        item = QListWidgetItem(f'{len(self.shots)}. {datetime.now():%H:%M:%S}  ({image.width()} x {image.height()})')
        item.setFlags(item.flags() | Qt.ItemIsUserCheckable)
        item.setCheckState(Qt.Checked)
        self.list.addItem(item)
        self.list.blockSignals(False)
        self.list.setCurrentRow(len(self.shots)-1)
        self.sync()

    def preview(self, row):
        if 0 <= row < len(self.shots):
            self.image.setPixmap(QPixmap.fromImage(self.shots[row]).scaled(self.image.size(), Qt.KeepAspectRatio, Qt.SmoothTransformation))
        else:
            self.image.clear()

    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.preview(self.list.currentRow())

    def sync(self, *_):
        chosen = [s for i, s in enumerate(self.shots) if self.list.item(i).checkState() == Qt.Checked]
        data = QMimeData()
        urls = []
        for i, image in enumerate(chosen):
            path = self.folder / f'{datetime.now():%H%M%S%f}-{i:03}.png'
            image.save(str(path), 'PNG')
            urls.append(QUrl.fromLocalFile(str(path)))
        data.setUrls(urls)
        data.setData('x-special/gnome-copied-files', ('copy\n' + '\n'.join(u.toString() for u in urls)).encode())
        data.setHtml(''.join(f'<p><img src="{u.toString()}"></p>' for u in urls))
        self.clip.blockSignals(True)
        if chosen:
            self.clip.setMimeData(data)
            self.owned = data
        elif self.clip.mimeData() is self.owned:
            self.clip.clear()
        self.clip.blockSignals(False)
        self.status.setText(f'{len(chosen)} of {len(self.shots)} screenshots ready for Ctrl+V as separate PNG files.' if chosen else 'No screenshots checked for pasting.')

    def delete(self):
        row = self.list.currentRow()
        if row >= 0:
            self.list.blockSignals(True)
            self.shots.pop(row)
            self.list.takeItem(row)
            self.list.blockSignals(False)
            self.preview(self.list.currentRow())
            self.sync()

    def clear(self):
        if self.shots and QMessageBox.question(self, 'Clear list', 'Remove all screenshots from the list?') == QMessageBox.Yes:
            self.list.blockSignals(True)
            self.shots.clear()
            self.list.clear()
            self.list.blockSignals(False)
            self.image.clear()
            self.sync()

    def export_to(self, filename):
        path = Path(filename)
        paths = [path if i == 0 else path.with_name(f'{path.stem}-{i+1:03}.png') for i in range(len(self.shots))]
        if any(p.exists() for p in paths) and QMessageBox.question(self, 'Save PNG files', 'Overwrite existing files?') != QMessageBox.Yes:
            return
        for image, target in zip(self.shots, paths):
            if not image.save(str(target), 'PNG'):
                raise OSError(f'Unable to save {target}')
        self.status.setText(f'Saved {len(paths)} screenshots to {path.parent}')

    def export(self):
        if not self.shots:
            return
        filename, _ = QFileDialog.getSaveFileName(self, 'Save PNG screenshots', 'screenshot.png', 'PNG image (*.png)')
        if filename:
            try:
                self.export_to(filename if filename.lower().endswith('.png') else filename + '.png')
            except OSError as error:
                QMessageBox.warning(self, 'Unable to save', str(error))

    def closeEvent(self, event):
        if self.clip.mimeData() is self.owned:
            self.clip.blockSignals(True)
            if self.shots:
                self.clip.setImage(self.shots[-1])
            else:
                self.clip.clear()
            self.clip.blockSignals(False)
        super().closeEvent(event)

if __name__ == '__main__':
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    window = Window()
    window.show()
    sys.exit(app.exec())
