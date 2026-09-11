#!/usr/bin/env python3
"""
Nutsty System Tray Indicator (StatusNotifierItem)
Enables background minimization, tray icon interaction, and quick controls.
"""
import os
import sys
import subprocess
import signal

try:
    import gi
    gi.require_version('AppIndicator3', '0.1')
    gi.require_version('Gtk', '3.0')
    from gi.repository import AppIndicator3, Gtk, GLib
except Exception as e:
    print(f"Tray indicator error: {e}", file=sys.stderr)
    sys.exit(1)

APP_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICON_PATH = os.path.join(APP_DIR, "assets", "nutsty-symbolic.svg")
DAEMON_SCRIPT = os.path.join(APP_DIR, "backend", "player_daemon.py")
SHELL_QML = os.path.join(APP_DIR, "shell.qml")

def show_nutsty_window(*args):
    """Reopen or bring Nutsty window to front via Quickshell IPC"""
    subprocess.Popen([
        "/usr/bin/quickshell", "ipc", "-p", SHELL_QML, "call", "nutsty", "openWindow"
    ])

def toggle_playback(*args):
    """Toggle music playback"""
    subprocess.Popen(["python3", DAEMON_SCRIPT, "toggle"])

def next_track(*args):
    """Skip to next track"""
    subprocess.Popen(["python3", DAEMON_SCRIPT, "next"])

def prev_track(*args):
    """Skip to previous track"""
    subprocess.Popen(["python3", DAEMON_SCRIPT, "prev"])

def quit_nutsty(*args):
    """Completely terminate Nutsty and its daemons"""
    subprocess.run(["/usr/bin/quickshell", "kill", "-p", SHELL_QML], stderr=subprocess.DEVNULL)
    subprocess.run(["python3", DAEMON_SCRIPT, "stop"], stderr=subprocess.DEVNULL)
    Gtk.main_quit()
    sys.exit(0)

def build_menu():
    menu = Gtk.Menu()

    # Open App
    open_item = Gtk.MenuItem(label="Mở Nutsty")
    open_item.connect("activate", show_nutsty_window)
    menu.append(open_item)

    menu.append(Gtk.SeparatorMenuItem())

    # Play/Pause
    play_item = Gtk.MenuItem(label="Phát / Tạm dừng")
    play_item.connect("activate", toggle_playback)
    menu.append(play_item)

    # Next
    next_item = Gtk.MenuItem(label="Bài tiếp theo")
    next_item.connect("activate", next_track)
    menu.append(next_item)

    # Previous
    prev_item = Gtk.MenuItem(label="Bài trước đó")
    prev_item.connect("activate", prev_track)
    menu.append(prev_item)

    menu.append(Gtk.SeparatorMenuItem())

    # Exit
    quit_item = Gtk.MenuItem(label="Thoát Nutsty")
    quit_item.connect("activate", quit_nutsty)
    menu.append(quit_item)

    menu.show_all()
    return menu, open_item

def main():
    signal.signal(signal.SIGINT, lambda *args: Gtk.main_quit())
    signal.signal(signal.SIGTERM, lambda *args: Gtk.main_quit())

    icon_name = ICON_PATH if os.path.exists(ICON_PATH) else "multimedia-audio-player"
    indicator = AppIndicator3.Indicator.new(
        "nutsty-tray",
        icon_name,
        AppIndicator3.IndicatorCategory.APPLICATION_STATUS
    )
    indicator.set_title("Nutsty")
    indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)

    menu, open_item = build_menu()
    indicator.set_menu(menu)
    indicator.set_secondary_activate_target(open_item)

    Gtk.main()

if __name__ == "__main__":
    main()
