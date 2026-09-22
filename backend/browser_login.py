#!/usr/bin/env python3
"""
Nutsty - Native Google / YouTube Music Login Assistant
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

try:
    from . import platform_compat as pc
except (ImportError, ValueError):
    import platform_compat as pc

PROFILE_NAME = os.getenv("NUTSTY_PROFILE", "").strip().lower()
PROFILE_SUFFIX = f"_{PROFILE_NAME}" if PROFILE_NAME else ""

CDP_PORT = 19222 if not PROFILE_NAME else (19222 + (abs(hash(PROFILE_NAME)) % 100) + 1)
PROFILE_DIR = os.path.join(pc.get_config_dir(), f"browser_auth{PROFILE_SUFFIX}")

LOGIN_URL = (
    "https://accounts.google.com/ServiceLogin?"
    "ltmpl=music&service=youtube&uilel=3&passive=true&"
    "continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Faction_handle_signin%3Dtrue%26app%3Ddesktop%26hl%3Den%26next%3Dhttps%253A%252F%252Fmusic.youtube.com%252F%26feature%3D__FEATURE__&hl=en"
)

def find_system_browser():
    # 1. On Windows: Check standard paths for Edge, Chrome, Brave
    if sys.platform == "win32" or os.name == "nt":
        win_candidates = []
        p_files_x86 = os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")
        p_files = os.environ.get("ProgramFiles", r"C:\Program Files")
        local_appdata = os.environ.get("LOCALAPPDATA", "")

        # Microsoft Edge (Pre-installed on every Windows 10/11)
        win_candidates.extend([
            os.path.join(p_files_x86, "Microsoft", "Edge", "Application", "msedge.exe"),
            os.path.join(p_files, "Microsoft", "Edge", "Application", "msedge.exe"),
            shutil.which("msedge") or "",
        ])
        # Google Chrome
        win_candidates.extend([
            os.path.join(p_files, "Google", "Chrome", "Application", "chrome.exe"),
            os.path.join(p_files_x86, "Google", "Chrome", "Application", "chrome.exe"),
            os.path.join(local_appdata, "Google", "Chrome", "Application", "chrome.exe") if local_appdata else "",
            shutil.which("chrome") or "",
        ])
        # Brave
        win_candidates.extend([
            os.path.join(p_files, "BraveSoftware", "Brave-Browser", "Application", "brave.exe"),
            os.path.join(local_appdata, "BraveSoftware", "Brave-Browser", "Application", "brave.exe") if local_appdata else "",
            shutil.which("brave") or "",
        ])
        for p in win_candidates:
            if p and os.path.exists(p) and os.path.isfile(p):
                return p

    # 2. On Linux: Check typical desktop Chromium paths
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
        "msedge",
        "vivaldi"
    ]
    for c in candidates:
        bin_path = shutil.which(c)
        if bin_path and os.path.isfile(bin_path):
            return bin_path
        if os.path.isfile(c):
            return c
    return None

def kill_browser_proc(proc):
    if not proc:
        return
    try:
        if sys.platform == "win32" or os.name == "nt":
            subprocess.run(["taskkill", "/F", "/T", "/PID", str(proc.pid)], capture_output=True, timeout=3)
        else:
            os.killpg(os.getpgid(proc.pid), 15)
    except Exception:
        try:
            proc.kill()
        except Exception:
            pass

async def capture_cookies_via_cdp(ws_url, cdp_port, proc, max_timeout=300):
    import websockets

    start_time = time.time()
    google_signed_in_time = None
    msg_id = 1

    try:
        async with websockets.connect(ws_url, ping_interval=None) as ws:
            while time.time() - start_time < max_timeout:
                if proc.poll() is not None:
                    return {"success": False, "error": "Login window was closed by user."}

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
                        
                        yt_cookies = {}
                        google_cookies = {}
                        has_login_info = False
                        has_sapisid = False
                        
                        for c in cookies:
                            name = c.get("name", "")
                            val = c.get("value", "")
                            domain = c.get("domain", "")
                            if not name or not val:
                                continue

                            if name == "LOGIN_INFO":
                                has_login_info = True

                            if name in ("SAPISID", "__Secure-3PAPISID"):
                                has_sapisid = True

                            if "youtube" in domain:
                                yt_cookies[name] = val
                            elif "google" in domain:
                                google_cookies[name] = val
                        
                        # Note when Google Accounts credentials have been accepted
                        if has_sapisid and not google_signed_in_time:
                            google_signed_in_time = time.time()

                        # If user authenticated with Google but hasn't reached music.youtube.com after 5s
                        if google_signed_in_time and not has_login_info and (time.time() - google_signed_in_time > 5.0):
                            try:
                                with urllib.request.urlopen(f"http://127.0.0.1:{cdp_port}/json/list", timeout=1.0) as r:
                                    pages = json.loads(r.read().decode("utf-8"))
                                for p in pages:
                                    p_url = p.get("url", "")
                                    if p.get("type") == "page" and "music.youtube.com" not in p_url:
                                        p_ws = p.get("webSocketDebuggerUrl")
                                        if p_ws:
                                            async with websockets.connect(p_ws, ping_interval=None) as page_ws:
                                                await page_ws.send(json.dumps({
                                                    "id": 999,
                                                    "method": "Page.navigate",
                                                    "params": {"url": "https://music.youtube.com/"}
                                                }))
                                                break
                            except Exception as ne:
                                sys.stderr.write(f"[Page nav helper]: {ne}\n")

                        # Crucial condition: must have both YouTube session (LOGIN_INFO) and auth (SAPISID)
                        if has_login_info and has_sapisid:
                            # Merge cookies: YouTube cookies take priority
                            merged = dict(google_cookies)
                            merged.update(yt_cookies)

                            # Defensive: ensure __Secure-3PAPISID exists if SAPISID does
                            if "SAPISID" in merged and "__Secure-3PAPISID" not in merged:
                                merged["__Secure-3PAPISID"] = merged["SAPISID"]
                            elif "__Secure-3PAPISID" in merged and "SAPISID" not in merged:
                                merged["SAPISID"] = merged["__Secure-3PAPISID"]

                            full_cookie_str = "; ".join(f"{k}={v}" for k, v in merged.items())

                            # Verify auth using ytmusic_helper
                            res = ytmusic_helper.save_auth(full_cookie_str)
                            if res.get("success"):
                                await asyncio.sleep(0.8)
                                return res
                            else:
                                sys.stderr.write(f"[Auth verification pending]: {res.get('error')}\n")

                except asyncio.TimeoutError:
                    pass
                except Exception as e:
                    sys.stderr.write(f"[CDP loop error]: {e}\n")

                await asyncio.sleep(1.0)
    except websockets.exceptions.ConnectionClosed:
        return {"success": False, "error": "Login window was closed."}
    except Exception as e:
        return {"success": False, "error": str(e)}

    return {"success": False, "error": "Login timed out after 5 minutes."}

def start_login():
    browser_bin = find_system_browser()
    if not browser_bin:
        err = {"success": False, "error": "No Chromium-based browser (Brave, Chrome, Chromium) found."}
        print(json.dumps(err, ensure_ascii=False))
        return err

    os.makedirs(PROFILE_DIR, exist_ok=True)

    # Clean stale Chromium singleton locks if no browser is running
    for lock_name in ("SingletonLock", "SingletonSocket", "SingletonCookie"):
        lock_path = os.path.join(PROFILE_DIR, lock_name)
        if os.path.islink(lock_path) or os.path.exists(lock_path):
            try:
                os.remove(lock_path)
            except Exception:
                pass

    cmd = [
        browser_bin,
        f"--app={LOGIN_URL}",
        f"--remote-debugging-port={CDP_PORT}",
        f"--user-data-dir={PROFILE_DIR}",
        "--no-first-run",
        "--no-default-browser-check",
        "--window-size=680,780"
    ]

    kwargs = {}
    if sys.platform == "win32" or os.name == "nt":
        kwargs["creationflags"] = subprocess.CREATE_NEW_PROCESS_GROUP
    else:
        kwargs["preexec_fn"] = os.setsid

    proc = subprocess.Popen(
        cmd,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        **kwargs
    )

    ws_url = None
    for _ in range(40):
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
        kill_browser_proc(proc)
        err = {"success": False, "error": "Failed to establish DevTools connection with browser window."}
        print(json.dumps(err, ensure_ascii=False))
        return err

    result = {"success": False, "error": "Unknown error"}
    try:
        result = asyncio.run(capture_cookies_via_cdp(ws_url, CDP_PORT, proc))
    except Exception as e:
        result = {"success": False, "error": str(e)}
    finally:
        # Gracefully terminate browser window
        kill_browser_proc(proc)

    print(json.dumps(result, ensure_ascii=False))
    return result

def main():
    start_login()

if __name__ == "__main__":
    main()
