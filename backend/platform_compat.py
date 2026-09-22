#!/usr/bin/env python3
"""
Nutsty Platform Compatibility Layer
Handles cross-platform paths, process lifecycle, IPC socket targets, and binary resolution
between Linux (Wayland / Niri) and Windows (PySide6 / Win32).
"""
import os
import sys
import platform
import tempfile
import socket
import shutil
import subprocess
from pathlib import Path

IS_WINDOWS = platform.system() == "Windows"
IS_LINUX = platform.system() == "Linux"
IS_MACOS = platform.system() == "Darwin"

APP_ROOT = os.getenv("NUTSTY_APP_DIR") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

_bin_dir = os.path.join(APP_ROOT, "bin")
if os.path.exists(_bin_dir) and _bin_dir not in os.environ.get("PATH", ""):
    os.environ["PATH"] = _bin_dir + os.pathsep + os.environ.get("PATH", "")

def get_config_dir() -> str:
    """Return platform-appropriate configuration directory."""
    if IS_WINDOWS:
        appdata = os.getenv("APPDATA")
        if appdata:
            base = os.path.join(appdata, "Nutsty")
        else:
            base = os.path.expanduser("~/.config/nutsty")
    else:
        # Standard Noctalia/Nutsty directory on Linux
        base = os.path.expanduser("~/.config/noctalia")
    os.makedirs(base, exist_ok=True)
    return base

def get_cache_dir() -> str:
    """Return platform-appropriate cache directory."""
    if IS_WINDOWS:
        local_appdata = os.getenv("LOCALAPPDATA")
        if local_appdata:
            base = os.path.join(local_appdata, "Nutsty", "cache")
        else:
            base = os.path.expanduser("~/.cache/nutsty")
    else:
        base = os.path.expanduser("~/.cache/nutsty")
    os.makedirs(base, exist_ok=True)
    return base

def get_temp_dir() -> str:
    """Return platform-appropriate temp directory."""
    if IS_WINDOWS:
        base = os.path.join(tempfile.gettempdir(), "nutsty")
        os.makedirs(base, exist_ok=True)
        return base
    return "/tmp"

def get_music_dir() -> str:
    """Return user's Music directory across platforms."""
    if IS_WINDOWS:
        userprofile = os.getenv("USERPROFILE")
        if userprofile:
            m = os.path.join(userprofile, "Music")
            if os.path.exists(m):
                return m
    return os.path.expanduser("~/Music")

if IS_WINDOWS:
    import ctypes

    kernel32 = ctypes.windll.kernel32
    GENERIC_READ = 0x80000000
    GENERIC_WRITE = 0x40000000
    OPEN_EXISTING = 3
    INVALID_HANDLE_VALUE = -1

    class WindowsNamedPipeClient:
        def __init__(self, pipe_name: str, timeout: float = 2.0):
            self.pipe_name = pipe_name
            timeout_ms = int(timeout * 1000)
            kernel32.WaitNamedPipeW(pipe_name, max(100, timeout_ms))
            self.handle = kernel32.CreateFileW(
                pipe_name,
                GENERIC_READ | GENERIC_WRITE,
                0,
                None,
                OPEN_EXISTING,
                0,
                None
            )
            if self.handle == INVALID_HANDLE_VALUE:
                err = ctypes.GetLastError()
                raise OSError(f"Failed to open named pipe {pipe_name}, win32 error: {err}")

        def sendall(self, data: bytes):
            bytes_written = ctypes.c_ulong()
            res = kernel32.WriteFile(self.handle, data, len(data), ctypes.byref(bytes_written), None)
            if not res:
                err = ctypes.GetLastError()
                raise OSError(f"WriteFile to named pipe failed, error: {err}")

        def recv(self, bufsize: int = 4096) -> bytes:
            buf = ctypes.create_string_buffer(bufsize)
            bytes_read = ctypes.c_ulong()
            res = kernel32.ReadFile(self.handle, buf, bufsize, ctypes.byref(bytes_read), None)
            if not res:
                err = ctypes.GetLastError()
                if err == 109:  # ERROR_BROKEN_PIPE
                    return b""
                raise OSError(f"ReadFile from named pipe failed, error: {err}")
            return buf.raw[:bytes_read.value]

        def close(self):
            if self.handle != INVALID_HANDLE_VALUE:
                kernel32.CloseHandle(self.handle)
                self.handle = INVALID_HANDLE_VALUE
else:
    class WindowsNamedPipeClient:
        pass

def get_mpv_ipc_target(profile_suffix: str = ""):
    r"""
    Return (ipc_type, address) for MPV IPC communication.
    On Linux: ('unix', '/tmp/nutsty_mpv<suffix>.sock')
    On Windows: ('pipe', r'\\.\pipe\nutsty_mpv<suffix>')
    """
    if IS_WINDOWS:
        pipe_path = rf"\\.\pipe\nutsty_mpv{profile_suffix}"
        return ("pipe", pipe_path)
    else:
        sock_path = f"/tmp/nutsty_mpv{profile_suffix}.sock"
        return ("unix", sock_path)

def get_mpv_ipc_arg(ipc_type: str, address) -> str:
    """Return the --input-ipc-server argument for MPV CLI."""
    return f"--input-ipc-server={address}"

def connect_mpv_socket(ipc_type: str, address, timeout: float = 2.0):
    """Open and return a connected socket or pipe client to MPV IPC server."""
    if ipc_type == "pipe":
        return WindowsNamedPipeClient(address, timeout=timeout)
    elif ipc_type == "tcp":
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(address)
        return s
    else:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(timeout)
        s.connect(address)
        return s

def is_process_running(name_or_title: str) -> bool:
    """Check if process with title or image name is currently active."""
    if IS_WINDOWS:
        try:
            CREATE_NO_WINDOW = 0x08000000
            exe_name = name_or_title if name_or_title.endswith(".exe") else f"{name_or_title}.exe"
            cmd = ["tasklist", "/fi", f"imagename eq {exe_name}"]
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=2, creationflags=CREATE_NO_WINDOW)
            return exe_name.lower() in res.stdout.lower()
        except Exception:
            return False
    else:
        try:
            res = subprocess.run(["pgrep", "-f", f"title={name_or_title}"], capture_output=True, text=True, timeout=2)
            return res.returncode == 0 and bool(res.stdout.strip())
        except Exception:
            return False

def kill_process(name_or_title: str):
    """Force terminate process cleanly across platforms."""
    if IS_WINDOWS:
        try:
            CREATE_NO_WINDOW = 0x08000000
            exe_name = name_or_title if name_or_title.endswith(".exe") else f"{name_or_title}.exe"
            subprocess.run(["taskkill", "/f", "/im", exe_name], capture_output=True, timeout=3, creationflags=CREATE_NO_WINDOW)
        except Exception:
            pass
    else:
        try:
            subprocess.run(["pkill", "-9", "-f", f"title={name_or_title}"], capture_output=True, timeout=3)
        except Exception:
            pass

def get_binary_path(name: str) -> str:
    """Resolve executable path, checking local bin/ directory before system PATH."""
    bin_ext = ".exe" if IS_WINDOWS else ""
    local_bin = os.path.join(APP_ROOT, "bin", f"{name}{bin_ext}")
    if os.path.exists(local_bin) and os.path.isfile(local_bin):
        return local_bin
    
    found = shutil.which(name if not IS_WINDOWS else f"{name}{bin_ext}")
    if found:
        # On Windows, never use .com console wrapper if .exe exists
        if IS_WINDOWS and found.lower().endswith(".com"):
            exe_alt = found[:-4] + ".exe"
            if os.path.exists(exe_alt):
                return exe_alt
        return found
    return name

def get_daemon_popen_kwargs() -> dict:
    """Return platform-safe subprocess flags for detached background execution."""
    kwargs = {}
    if IS_WINDOWS:
        CREATE_NO_WINDOW = 0x08000000
        kwargs["creationflags"] = CREATE_NO_WINDOW
    else:
        kwargs["start_new_session"] = True
    return kwargs
