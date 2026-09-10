#!/usr/bin/env python3
"""
Frostify Local - Native Google / YouTube Music Login Assistant
Launches an isolated browser app window for official Google login
and automatically captures auth cookies via Chrome DevTools Protocol (CDP).
Zero extension required, zero manual copy-pasting.
"""
import os
import sys
import json
import time
import shutil
import asyncio
import subprocess
import urllib.request
import urllib.error

BACKEND_DIR = os.path.dirname(os.path.abspath(__file__))
if BACKEND_DIR not in sys.path:
    sys.path.insert(0, BACKEND_DIR)

import ytmusic_helper

CDP_PORT = 19222
PROFILE_DIR = os.path.expanduser("~/.config/frostify/browser_auth")

LOGIN_URL = (
    "https://accounts.google.com/ServiceLogin?"
    "ltmpl=music&service=youtube&uilel=3&passive=true&"
    "continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Den%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F%26feature%3D__FEATURE__&hl=en"
)

def find_system_browser():
    candidates = [
        "brave",
        "brave-browser",
        "/usr/bin/brave",
        "google-chrome",
        "google-chrome-stable",
        "/usr/bin/google-chrome",
        "chromium",
        "chromium-browser",
        "/usr/bin/chromium",
        "microsoft-edge",
        "vivaldi"
    ]
    for c in candidates:
        bin_path = shutil.which(c)
        if bin_path and os.path.isfile(bin_path):
            return bin_path
    return None

async def capture_cookies_via_cdp(ws_url, max_timeout=300):
    import websockets

    start_time = time.time()
    msg_id = 1

    async with websockets.connect(ws_url, ping_interval=None) as ws:
        while time.time() - start_time < max_timeout:
            msg_id += 1
            cmd = {
                "id": msg_id,
                "method": "Storage.getCookies"
            }
            await ws.send(json.dumps(cmd))
            
            try:
                resp_text = await asyncio.wait_for(ws.recv(), timeout=2.0)
                data = json.loads(resp_text)
                if data.get("id") == msg_id:
                    cookies = data.get("result", {}).get("cookies", [])
                    sapisid = None
                    cookie_parts = []
                    
                    for c in cookies:
                        name = c.get("name", "")
                        val = c.get("value", "")
                        domain = c.get("domain", "")
                        if "youtube" in domain or "google" in domain:
                            cookie_parts.append(f"{name}={val}")
                            if name == "SAPISID" and val:
                                sapisid = val
                    
                    if sapisid and len(cookie_parts) >= 3:
                        full_cookie_str = "; ".join(cookie_parts)
                        res = ytmusic_helper.save_auth(full_cookie_str)
                        return res
            except asyncio.TimeoutError:
                pass
            except Exception as e:
                sys.stderr.write(f"[CDP recv error]: {e}\n")

            await asyncio.sleep(1.0)

    return {"success": False, "error": "Login timed out after 5 minutes."}

def start_login():
    browser_bin = find_system_browser()
    if not browser_bin:
        err = {"success": False, "error": "No Chromium-based browser (Brave, Chrome, Chromium) found."}
        print(json.dumps(err, ensure_ascii=False))
        return err

    os.makedirs(PROFILE_DIR, exist_ok=True)

    cmd = [
        browser_bin,
        f"--app={LOGIN_URL}",
        f"--remote-debugging-port={CDP_PORT}",
        f"--user-data-dir={PROFILE_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=680,780"
    ]

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        preexec_fn=os.setsid
    )

    ws_url = None
    for _ in range(30):
        time.sleep(0.5)
        if proc.poll() is not None:
            # User closed window before CDP connection
            err = {"success": False, "error": "Login window was closed."}
            print(json.dumps(err, ensure_ascii=False))
            return err

        try:
            with urllib.request.urlopen(f"http://127.0.0.1:{CDP_PORT}/json/version", timeout=1.0) as r:
                ver_info = json.loads(r.read().decode("utf-8"))
                ws_url = ver_info.get("webSocketDebuggerUrl")
                if ws_url:
                    break
        except Exception:
            continue

    if not ws_url:
        try:
            os.killpg(os.getpgid(proc.pid), 15)
        except Exception:
            pass
        err = {"success": False, "error": "Failed to establish DevTools connection with browser window."}
        print(json.dumps(err, ensure_ascii=False))
        return err

    result = {"success": False, "error": "Unknown error"}
    try:
        result = asyncio.run(capture_cookies_via_cdp(ws_url))
    except Exception as e:
        result = {"success": False, "error": str(e)}
    finally:
        # Gracefully terminate browser window
        try:
            os.killpg(os.getpgid(proc.pid), 15)
        except Exception:
            pass

    print(json.dumps(result, ensure_ascii=False))
    return result

if __name__ == "__main__":
    start_login()
