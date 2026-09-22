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

# Safe logging for Windows PyInstaller GUI mode (where sys.stdout/stderr are None)
class SafeLogWriter:
    def __init__(self, log_path=None):
        self.log_file = None
        if log_path:
            try:
                os.makedirs(os.path.dirname(log_path), exist_ok=True)
                self.log_file = open(log_path, "a", encoding="utf-8", errors="replace")
            except Exception:
                pass

    def write(self, s):
        if self.log_file:
            try:
                self.log_file.write(str(s))
                self.log_file.flush()
            except Exception:
                pass

    def flush(self):
        if self.log_file:
            try:
                self.log_file.flush()
            except Exception:
                pass

log_dir = os.path.join(os.environ.get("TEMP", os.path.expanduser("~")), "nutsty")
log_file_path = os.path.join(log_dir, "launcher.log")
if sys.stdout is None:
    sys.stdout = SafeLogWriter(log_file_path)
if sys.stderr is None:
    sys.stderr = SafeLogWriter(log_file_path)

# Resolve App and Resource Root across source runs and PyInstaller onedir bundles
def resolve_app_root():
    if getattr(sys, "frozen", False):
        meipass = getattr(sys, "_MEIPASS", None)
        if meipass and os.path.exists(os.path.join(meipass, "shell.qml")):
            return meipass
        exe_dir = os.path.dirname(sys.executable)
        internal_dir = os.path.join(exe_dir, "_internal")
        if os.path.exists(os.path.join(internal_dir, "shell.qml")):
            return internal_dir
        if os.path.exists(os.path.join(exe_dir, "shell.qml")):
            return exe_dir
        return meipass or exe_dir
    return os.path.dirname(os.path.abspath(__file__))

APP_ROOT = resolve_app_root()
sys.path.insert(0, os.path.join(APP_ROOT, "backend"))

import platform_compat as pc

# Backend CLI Dispatcher: Prevents re-launching GUI when invoked as backend worker
def check_cli_dispatch():
    """
    If Nutsty.exe is invoked with backend script arguments (e.g. from QML Process
    or external scripts), dispatch to that script in headless mode and exit.
    This prevents fork bombs and infinite window popup loops.
    """
    args = sys.argv[1:]
    if not args:
        return
    clean_args = [a for a in args if not a.startswith("-")]
    if not clean_args:
        return

    target_script = clean_args[0]
    script_name = os.path.basename(target_script)

    backend_map = {
        "player_daemon.py": "player_daemon",
        "auth_server.py": "auth_server",
        "download_manager.py": "download_manager",
        "library.py": "library",
        "palette_extractor.py": "palette_extractor",
        "lyrics_helper.py": "lyrics_helper",
        "playlist_manager.py": "playlist_manager",
        "ytmusic_helper.py": "ytmusic_helper",
        "social_notes.py": "social_notes",
    }

    if script_name in backend_map:
        mod_name = backend_map[script_name]
        idx = args.index(target_script)
        sys.argv = [target_script] + args[idx + 1:]
        try:
            import importlib
            mod = importlib.import_module(mod_name)
            if hasattr(mod, "main"):
                mod.main()
            sys.exit(0)
        except SystemExit:
            raise
        except Exception as e:
            sys.stderr.write(f"Error running {script_name}: {e}\n")
            sys.exit(1)

# Run CLI dispatch check immediately
check_cli_dispatch()

# Detect Qt bindings (PySide6 or PyQt6)
try:
    from PySide6.QtCore import QObject, Signal, Property, Slot, QUrl, QTimer, QThread
    from PySide6.QtGui import QGuiApplication, QIcon
    from PySide6.QtQml import QQmlApplicationEngine, qmlRegisterType, QmlAttached
    from PySide6.QtQuick import QQuickWindow
    IS_PYSIDE = True
except ImportError:
    try:
        from PyQt6.QtCore import QObject, pyqtSignal as Signal, pyqtProperty as Property, pyqtSlot as Slot, QUrl, QTimer, QThread
        from PyQt6.QtGui import QGuiApplication, QIcon
        from PyQt6.QtQml import QQmlApplicationEngine, qmlRegisterType
        from PyQt6.QtQuick import QQuickWindow
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
        elif key == "NUTSTY_APP_DIR":
            return APP_ROOT
        return os.environ.get(key, "")

    @Slot(str, result=str)
    def readFile(self, path: str) -> str:
        if not path or not os.path.exists(path):
            return ""
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as f:
                return f.read()
        except Exception:
            return ""

    @Slot(str, result=str)
    def checkFileMtime(self, path: str) -> str:
        if not path or not os.path.exists(path):
            return ""
        try:
            return str(os.path.getmtime(path))
        except Exception:
            return ""

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

# Quickshell Compatibility Classes
class WlrLayershellAttached(QObject):
    def __init__(self, parent=None):
        super().__init__(parent)
        self._layer = 0
        self._namespace = ""
    @Property(int)
    def layer(self): return self._layer
    @layer.setter
    def layer(self, v): self._layer = v
    @Property(str)
    def namespace(self): return self._namespace
    @namespace.setter
    def namespace(self, v): self._namespace = v

def register_qml_types():
    if IS_PYSIDE:
        @QmlAttached(WlrLayershellAttached)
        class WlrLayershell(QObject):
            @staticmethod
            def qmlAttachedProperties(*args, **kwargs):
                parent = args[-1] if (args and isinstance(args[-1], QObject)) else None
                return WlrLayershellAttached(parent)
        qmlRegisterType(WlrLayershell, "Quickshell.Wayland", 1, 0, "WlrLayershell")
    else:
        class WlrLayershell(QObject):
            qmlAttachedProperties = WlrLayershellAttached
        qmlRegisterType(WlrLayershell, "Quickshell.Wayland", 1, 0, "WlrLayershell", attachedProperties=WlrLayershellAttached)

def start_daemons():
    """Start resident backend daemons (auth_server HTTP daemon)."""
    def _auth_runner():
        try:
            import auth_server
            if hasattr(auth_server, "run_server"):
                auth_server.run_server()
            elif hasattr(auth_server, "main"):
                auth_server.main()
        except Exception as e:
            sys.stderr.write(f"auth_server daemon thread error: {e}\n")

    t = threading.Thread(target=_auth_runner, daemon=True)
    t.start()

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

    register_qml_types()
    start_daemons()

    engine = QQmlApplicationEngine()
    engine.warnings.connect(lambda warns: [sys.stderr.write(f"QML Warning: {w.toString()}\n") for w in warns])

    compat_path = os.path.join(APP_ROOT, "compat")
    engine.addImportPath(compat_path)
    engine.addImportPath(APP_ROOT)
    engine.addImportPath(os.path.join(APP_ROOT, "components"))

    if getattr(sys, "frozen", False):
        pyside_qml = os.path.join(APP_ROOT, "PySide6", "qml")
        if os.path.exists(pyside_qml):
            engine.addImportPath(pyside_qml)
        exe_dir = os.path.dirname(sys.executable)
        alt_pyside_qml = os.path.join(exe_dir, "_internal", "PySide6", "qml")
        if os.path.exists(alt_pyside_qml):
            engine.addImportPath(alt_pyside_qml)

    bridge = NutstyBridge()
    engine.rootContext().setContextProperty("__NutstyBridge", bridge)

    shell_qml = os.path.join(APP_ROOT, "shell.qml")
    engine.load(QUrl.fromLocalFile(shell_qml))

    if not engine.rootObjects():
        err_details = [
            f"Target QML: {shell_qml}",
            f"File Exists: {os.path.exists(shell_qml)}",
            f"APP_ROOT: {APP_ROOT}",
            f"Executable: {sys.executable}",
            f"sys._MEIPASS: {getattr(sys, '_MEIPASS', 'N/A')}",
            f"Log File: {log_file_path}",
        ]
        msg = "Fatal: Failed to load QML root object.\n\n" + "\n".join(err_details)
        sys.stderr.write(msg + "\n")
        try:
            if sys.platform == "win32":
                import ctypes
                ctypes.windll.user32.MessageBoxW(0, msg, "Nutsty Error", 0x10)
        except Exception:
            pass
        sys.exit(1)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()

