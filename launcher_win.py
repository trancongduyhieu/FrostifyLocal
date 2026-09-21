#!/usr/bin/env python3
"""
Nutsty Cross-Platform Launcher (Windows & Desktop Qt Quick)
Launches Nutsty with PySide6 / PyQt6, injects compatibility bridges for Quickshell APIs,
starts background services, and displays the main window.
"""
import os
import sys
import json
import time
import subprocess
import threading
from pathlib import Path

# Add backend to path
APP_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(APP_ROOT, "backend"))

import platform_compat as pc

# Detect Qt bindings (PySide6 or PyQt6)
try:
    from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QTimer, QThread
    from PySide6.QtGui import QGuiApplication, QIcon
    from PySide6.QtQml import QQmlApplicationEngine
    IS_PYSIDE = True
except ImportError:
    try:
        from PyQt6.QtCore import QObject, pyqtSignal as Signal, pyqtProperty as Property, pyqtSlot as Slot, QUrl, QTimer, QThread
        from PyQt6.QtGui import QGuiApplication, QIcon
        from PyQt6.QtQml import QQmlApplicationEngine
        IS_PYSIDE = False
    except ImportError:
        sys.stderr.write("Fatal: Neither PySide6 nor PyQt6 is installed.\n")
        sys.stderr.write("Please run: pip install PySide6\n")
        sys.exit(1)

class NutstyBridge(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)

    @Slot(str, result=str)
    def getEnv(self, key: str) -> str:
        if key == "HOME":
            return os.path.expanduser("~")
        return os.environ.get(key, "")

    @Slot(list)
    def execDetached(self, args: list):
        if not args:
            return
        cmd = list(args)
        if cmd[0] == "python3" or cmd[0] == "python":
            cmd[0] = sys.executable
        try:
            subprocess.Popen(cmd, **pc.get_daemon_popen_kwargs())
        except Exception as e:
            sys.stderr.write(f"execDetached failed: {e}\n")

    @Slot(list, "QJSValue")
    def runProcess(self, args: list, callback):
        """Run process asynchronously and invoke JS callback(stdout, stderr, exitCode)."""
        if not args:
            return
        cmd = list(args)
        if cmd[0] == "python3" or cmd[0] == "python":
            cmd[0] = sys.executable

        def _worker():
            try:
                res = subprocess.run(cmd, capture_output=True, text=True, timeout=60, **pc.get_daemon_popen_kwargs())
                out = res.stdout or ""
                err = res.stderr or ""
                code = res.returncode
            except Exception as e:
                out = ""
                err = str(e)
                code = 1
            
            QTimer.singleShot(0, lambda: callback.call([out, err, code]))

        threading.Thread(target=_worker, daemon=True).start()

    @Slot(str, result=str)
    def checkFileMtime(self, path: str) -> str:
        if not path or not os.path.exists(path):
            return ""
        try:
            return str(os.path.getmtime(path))
        except Exception:
            return ""

def start_daemons():
    """Start resident backend daemons (auth_server and player_daemon prewarm)."""
    auth_script = os.path.join(APP_ROOT, "backend", "auth_server.py")
    if os.path.exists(auth_script):
        subprocess.Popen([sys.executable, "-u", auth_script], **pc.get_daemon_popen_kwargs())

def main():
    os.environ["QT_QUICK_CONTROLS_STYLE"] = "Basic"
    
    app = QGuiApplication(sys.argv)
    app.setApplicationName("Nutsty")
    app.setOrganizationName("Nutsty")

    icon_path = os.path.join(APP_ROOT, "assets", "icons", "nutsty.png")
    if not os.path.exists(icon_path):
        icon_path = os.path.join(APP_ROOT, "assets", "icons", "application-x-executable.svg")
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))

    start_daemons()

    engine = QQmlApplicationEngine()
    
    compat_path = os.path.join(APP_ROOT, "compat")
    engine.addImportPath(compat_path)
    engine.addImportPath(APP_ROOT)

    bridge = NutstyBridge()
    engine.rootContext().setContextProperty("__NutstyBridge", bridge)

    shell_qml = os.path.join(APP_ROOT, "shell.qml")
    engine.load(QUrl.fromLocalFile(shell_qml))

    if not engine.rootObjects():
        sys.stderr.write("Fatal: Failed to load QML root object.\n")
        sys.exit(1)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
