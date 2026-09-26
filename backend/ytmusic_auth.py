#!/usr/bin/env python3
"""
Nutsty YouTube Music Authentication & Session Manager
Handles Google Account cookies, SAPISID hashing, and authenticated ytmusicapi client.
"""
import sys
import os
import json
import time
import shutil
import re
import hashlib
import urllib.request

try:
    from . import platform_compat as pc
except (ImportError, ValueError):
    import platform_compat as pc

pc.configure_windows_ssl()
# Monkey-patch gettext.translation to prevent FileNotFoundError: [Errno 2] No translation file found for domain: 'base'
import gettext
if not getattr(gettext, "_nutsty_patched", False):
    _orig_translation = gettext.translation
    def _safe_translation(domain, localedir=None, languages=None, class_=None, fallback=False, codeset=None):
        try:
            return _orig_translation(domain, localedir=localedir, languages=languages, class_=class_, fallback=fallback)
        except (FileNotFoundError, OSError):
            return gettext.NullTranslations()
    gettext.translation = _safe_translation
    gettext._nutsty_patched = True

# Monkey-patch ytmusicapi sapisid_from_cookie to be 100% immune to SimpleCookie syntax/token errors
def safe_sapisid_from_cookie(raw_cookie: str) -> str:
    match = re.search(r'(?:^|;\s*)(?:__Secure-3PAPISID|SAPISID)=([^;]+)', raw_cookie)
    if match:
        return match.group(1).strip('"').strip()
    try:
        from http.cookies import SimpleCookie
        cookie = SimpleCookie()
        cookie.load(raw_cookie.replace('"', ''))
        if "__Secure-3PAPISID" in cookie:
            return cookie["__Secure-3PAPISID"].value
        if "SAPISID" in cookie:
            return cookie["SAPISID"].value
    except Exception:
        pass
    raise KeyError("__Secure-3PAPISID")

try:
    import ytmusicapi.auth.browser
    ytmusicapi.auth.browser.sapisid_from_cookie = safe_sapisid_from_cookie
except Exception:
    pass

try:
    import ytmusicapi.ytmusic
    ytmusicapi.ytmusic.sapisid_from_cookie = safe_sapisid_from_cookie
except Exception:
    pass

def create_resilient_session():
    import requests
    session = requests.Session()
    ca_path = os.environ.get("REQUESTS_CA_BUNDLE") or os.environ.get("SSL_CERT_FILE")
    if ca_path and os.path.exists(ca_path):
        session.verify = ca_path
    else:
        try:
            import certifi
            cpath = certifi.where()
            if os.path.exists(cpath):
                session.verify = cpath
            else:
                session.verify = False
        except Exception:
            session.verify = False
    return session

def sanitize_cookie_for_ytmusic(raw_cookie: str) -> str:
    """Sanitize and prioritize Google/YouTube authentication cookies."""
    if not raw_cookie:
        return ""
    pairs = {}
    for item in raw_cookie.split(';'):
        item = item.strip()
        if '=' in item:
            k, v = item.split('=', 1)
            k = k.strip()
            v = v.strip().strip('"')
            if k and v:
                pairs[k] = v

    sapisid = pairs.get('SAPISID') or pairs.get('__Secure-3PAPISID') or pairs.get('__Secure-1PAPISID')
    if sapisid:
        pairs['__Secure-3PAPISID'] = sapisid
        pairs['SAPISID'] = sapisid

    priority_keys = [
        '__Secure-3PAPISID', 'SAPISID', '__Secure-3PSID', 'SID', 'HSID', 'SSID', 'APISID',
        'LOGIN_INFO', '__Secure-1PAPISID', '__Secure-1PSID', '__Secure-3PSIDTS', '__Secure-1PSIDTS',
        'PREF', 'SOCS', 'YSC', 'VISITOR_INFO1_LIVE', 'VISITOR_PRIVACY_METADATA'
    ]

    ordered = []
    for pk in priority_keys:
        if pk in pairs:
            ordered.append(f'{pk}={pairs[pk]}')
            del pairs[pk]

    for k, v in pairs.items():
        if re.match(r'^[a-zA-Z0-9_.-]+$', k):
            ordered.append(f'{k}={v}')

    return '; '.join(ordered)

def fetch_google_profile_from_cookies(cookie_str: str) -> dict:
    """
    Directly query Google / YouTube endpoints using session cookies to extract
    verified account name and email address.
    """
    info = {"name": "", "email": "", "thumb": ""}
    if not cookie_str:
        return info
    try:
        import requests
        headers = {
            "Cookie": cookie_str,
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
            "Accept-Language": "en-US,en;q=0.9"
        }

        # 1. Query YouTube Account Switcher endpoint
        try:
            r = requests.post(
                "https://www.youtube.com/get_account_switcher_endpoint",
                headers=headers,
                json={"context": {"client": {"clientName": "WEB", "clientVersion": "2.20240101.00.00"}}},
                timeout=4.0
            )
            if r.status_code == 200:
                raw_text = r.text
                emails = re.findall(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', raw_text)
                valid_emails = [e for e in emails if not e.endswith("@google.com") and not e.endswith("@youtube.com")]
                if valid_emails:
                    info["email"] = valid_emails[0]

                def find_key(obj, k):
                    if isinstance(obj, dict):
                        if k in obj: return obj[k]
                        for v in obj.values():
                            res = find_key(v, k)
                            if res: return res
                    elif isinstance(obj, list):
                        for item in obj:
                            res = find_key(item, k)
                            if res: return res
                    return None

                try:
                    data = r.json()
                    acc_name = find_key(data, "accountName")
                    if isinstance(acc_name, dict):
                        runs = acc_name.get("runs", [])
                        if runs: info["name"] = runs[0].get("text", "").strip()
                    elif isinstance(acc_name, str):
                        info["name"] = acc_name.strip()
                except Exception:
                    pass
        except Exception:
            pass

        # 2. Query Google MyAccount dashboard fallback
        if not info["name"] or not info["email"]:
            try:
                r = requests.get("https://myaccount.google.com/", headers=headers, timeout=4.0, allow_redirects=True)
                if r.status_code == 200:
                    html = r.text
                    if not info["email"]:
                        em_match = re.search(r'data-email=["\']([^"\']+@[^"\']+)["\']', html)
                        if em_match:
                            info["email"] = em_match.group(1).strip()
                        else:
                            emails = re.findall(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', html)
                            valid_emails = [e for e in emails if not e.endswith("@google.com") and not e.endswith("@youtube.com")]
                            if valid_emails:
                                info["email"] = valid_emails[0]

                    if not info["name"]:
                        name_match = re.search(r'data-name=["\']([^"\']+)["\']', html)
                        if name_match:
                            info["name"] = name_match.group(1).strip()
                        else:
                            wel_match = re.search(r'(?:Welcome|Chào mừng|Hi),\s*([^<.,!]+)', html, re.IGNORECASE)
                            if wel_match:
                                cand = wel_match.group(1).strip()
                                if len(cand) < 40 and not cand.startswith("<"):
                                    info["name"] = cand
            except Exception:
                pass
    except Exception as e:
        sys.stderr.write(f"[fetch_google_profile_from_cookies error]: {e}\n")
    return info

PROFILE_NAME = os.getenv("NUTSTY_PROFILE", "").strip().lower()
PROFILE_SUFFIX = f"_{PROFILE_NAME}" if PROFILE_NAME else ""

AUTH_FILE = os.path.join(pc.get_config_dir(), f"ytmusic_auth{PROFILE_SUFFIX}.json")
AUTH_CHANGED_FILE = os.path.join(pc.get_temp_dir(), f"nutsty_auth_changed{PROFILE_SUFFIX}")
STREAM_CACHE_FILE = os.path.join(pc.get_cache_dir(), "stream_cache.json")
HOME_CACHE_FILE = os.path.join(pc.get_cache_dir(), f"home_feed{PROFILE_SUFFIX}.json")
ONLINE_TRACKS_FILE = os.path.join(pc.get_cache_dir(), f"online_tracks{PROFILE_SUFFIX}.json")
MOOD_CACHE_DIR = os.path.join(pc.get_cache_dir(), "moods")
MOOD_CATS_FILE = os.path.join(pc.get_cache_dir(), "mood_categories.json")
SQUARE_COVERS_CACHE_FILE = os.path.join(pc.get_cache_dir(), "square_covers.json")

def load_json(filepath, default=None):
    if os.path.exists(filepath):
        try:
            with open(filepath, "r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return default if default is not None else {}
    return default if default is not None else {}

def save_json(filepath, data):
    try:
        os.makedirs(os.path.dirname(filepath), exist_ok=True)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
    except Exception:
        pass


def get_ytmusic_client(session=None):
    from ytmusicapi import YTMusic
    if session is None:
        session = create_resilient_session()
    if os.path.exists(AUTH_FILE):
        try:
            return YTMusic(AUTH_FILE, requests_session=session)
        except Exception as e:
            sys.stderr.write(f"[ytmusic auth load error]: {e}\n")
    return YTMusic(requests_session=session)

def extract_account_details_from_client(yt, headers=None):
    """
    Safely extract account information (name, email, avatar photo, channel handle)
    from YouTube Music InnerTube API without throwing KeyError if accountPhoto is missing
    (e.g. accounts using default initial letter avatar like 'H' or without custom brand photo).
    """
    info = {"name": "", "email": "", "thumb": "", "handle": ""}

    # Method 1: Query InnerTube account/account_menu
    try:
        endpoint = "account/account_menu"
        resp = yt._send_request(endpoint, {})
        if isinstance(resp, dict):
            def find_node(obj, target_key):
                if isinstance(obj, dict):
                    if target_key in obj:
                        return obj[target_key]
                    for v in obj.values():
                        res = find_node(v, target_key)
                        if res: return res
                elif isinstance(obj, list):
                    for item in obj:
                        res = find_node(item, target_key)
                        if res: return res
                return None

            header = find_node(resp, "activeAccountHeaderRenderer")
            if header and isinstance(header, dict):
                # Extract Account Name
                name_obj = header.get("accountName") or header.get("name")
                if isinstance(name_obj, dict):
                    runs = name_obj.get("runs", [])
                    if runs and isinstance(runs, list) and len(runs) > 0:
                        info["name"] = runs[0].get("text", "").strip()
                    elif "simpleText" in name_obj:
                        info["name"] = name_obj.get("simpleText", "").strip()
                elif isinstance(name_obj, str):
                    info["name"] = name_obj.strip()

                # Extract Email & Channel Handle
                for field in ["email", "channelHandle", "byline"]:
                    f_obj = header.get(field)
                    if isinstance(f_obj, dict):
                        runs = f_obj.get("runs", [])
                        if runs and isinstance(runs, list) and len(runs) > 0:
                            txt = runs[0].get("text", "").strip()
                            if "@" in txt and "." in txt:
                                if not info["email"]: info["email"] = txt
                            elif not info["handle"]:
                                info["handle"] = txt
                        elif "simpleText" in f_obj:
                            txt = f_obj.get("simpleText", "").strip()
                            if "@" in txt and "." in txt:
                                if not info["email"]: info["email"] = txt
                            elif not info["handle"]:
                                info["handle"] = txt

                # Extract Avatar Photo safely (no KeyError if missing)
                for photo_key in ["accountPhoto", "avatar", "thumbnail", "thumbnails"]:
                    p_obj = header.get(photo_key)
                    if isinstance(p_obj, dict):
                        thumbs = p_obj.get("thumbnails", [])
                        if thumbs and isinstance(thumbs, list) and len(thumbs) > 0:
                            info["thumb"] = thumbs[-1].get("url", "")
                            break

            # If email was not explicitly in header, search the entire menu response for email address
            if not info["email"]:
                try:
                    raw_str = json.dumps(resp)
                    emails = re.findall(r'[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+', raw_str)
                    valid_emails = [e for e in emails if not e.endswith("@youtube.com") and not e.endswith("@google.com")]
                    if valid_emails:
                        info["email"] = valid_emails[0]
                except Exception:
                    pass
    except Exception as e:
        sys.stderr.write(f"[extract_account_details account_menu error]: {e}\n")

    # Method 2: Standard ytmusicapi get_account_info fallback
    if not info["name"] or info["name"] == "Google User":
        try:
            std_user = yt.get_account_info()
            if isinstance(std_user, dict):
                if std_user.get("accountName"):
                    info["name"] = std_user.get("accountName")
                if std_user.get("channelHandle") and not info["handle"]:
                    info["handle"] = std_user.get("channelHandle")
                if std_user.get("accountPhotoUrl") and not info["thumb"]:
                    info["thumb"] = std_user.get("accountPhotoUrl")
        except Exception:
            pass

    return info

def get_auth_status():
    if not os.path.exists(AUTH_FILE):
        return {"logged_in": False, "name": "", "thumb": "", "email": ""}
    user_cache_file = os.path.join(os.path.dirname(AUTH_FILE), f"nutsty_user_cache{PROFILE_SUFFIX}.json")
    
    cached_info = {}
    if os.path.exists(user_cache_file):
        try:
            with open(user_cache_file, "r", encoding="utf-8") as ucf:
                cached_info = json.load(ucf)
        except Exception:
            pass

    try:
        from ytmusicapi import YTMusic
        yt = YTMusic(AUTH_FILE)
        user = extract_account_details_from_client(yt)
        
        name = user.get("name") or ""
        thumb = user.get("thumb") or ""
        handle = user.get("handle") or ""
        email = user.get("email") or handle or ""

        # Merge with cached info if user lacked name/email in InnerTube response
        if (not name or name == "Google User") and cached_info.get("name") and cached_info.get("name") != "Google User":
            name = cached_info.get("name")
        if not email and cached_info.get("email") and "@" in cached_info.get("email") and not cached_info.get("email").startswith("googleuser@"):
            email = cached_info.get("email")
        if not thumb and cached_info.get("avatar"):
            thumb = cached_info.get("avatar")

        # Direct profile extraction from cookies if still missing
        if not name or name == "Google User" or not email:
            try:
                with open(AUTH_FILE, "r", encoding="utf-8") as f:
                    auth_data = json.load(f)
                cookie_str = auth_data.get("cookie", "")
                if cookie_str:
                    dp = fetch_google_profile_from_cookies(cookie_str)
                    if dp.get("name") and (not name or name == "Google User"):
                        name = dp["name"]
                    if dp.get("email") and not email:
                        email = dp["email"]
                    if dp.get("thumb") and not thumb:
                        thumb = dp["thumb"]
            except Exception:
                pass

        if not name:
            name = "Google User"
        if not email and name and name != "Google User":
            safe_name = re.sub(r'[^a-zA-Z0-9]', '', name).lower()
            email = f"{safe_name or (PROFILE_NAME or 'user')}@gmail.com"

        # Update local user cache with verified account details
        try:
            with open(user_cache_file, "w", encoding="utf-8") as ucf:
                json.dump({
                    "email": (email or "").strip().lower(),
                    "name": name,
                    "avatar": thumb,
                    "handle": handle
                }, ucf, indent=2, ensure_ascii=False)
        except Exception:
            pass

        return {"logged_in": True, "name": name, "thumb": thumb, "email": email}
    except Exception as e:
        # Fallback 1: Return cached profile if available
        if cached_info and cached_info.get("name") and cached_info.get("name") != "Google User":
            return {
                "logged_in": True,
                "name": cached_info.get("name"),
                "thumb": cached_info.get("avatar") or "",
                "email": cached_info.get("email") or ""
            }

        # Fallback 2: Direct profile lookup from AUTH_FILE cookies
        try:
            with open(AUTH_FILE, "r", encoding="utf-8") as f:
                auth_data = json.load(f)
            cookie_data = auth_data.get("cookie", "")
            if "login_info" in cookie_data.lower() or "sapisid" in cookie_data.lower():
                dp = fetch_google_profile_from_cookies(cookie_data)
                fb_name = dp.get("name") or (cached_info.get("name") if cached_info else "") or "Google User"
                fb_email = dp.get("email") or (cached_info.get("email") if cached_info else "") or ""
                fb_thumb = dp.get("thumb") or (cached_info.get("avatar") if cached_info else "") or ""
                return {"logged_in": True, "name": fb_name, "thumb": fb_thumb, "email": fb_email}
        except Exception:
            pass

        return {"logged_in": False, "name": "", "thumb": "", "email": "", "error": str(e)}

def save_auth(raw_text, profile_hint=None):
    if isinstance(raw_text, dict):
        raw_text = "; ".join(f"{k}={v}" for k, v in raw_text.items())
    raw_text = str(raw_text).strip()
    if not raw_text:
        return {"success": False, "error": "Empty input"}

    try:
        import ytmusicapi
        from ytmusicapi.auth.browser import initialize_headers
        if sys.platform == "win32":
            headers["user-agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36"
        else:
            headers["user-agent"] = "Mozilla/5.0 (X11; Linux x86_64; rv:130.0) Gecko/20100101 Firefox/130.0"

        # Authuser detection
        target_authuser = "0"
        authuser_match = re.search(r'(?:x-goog-)?authuser[=:\s]+(["\']?)(\d+)\1', raw_text, re.IGNORECASE)
        if authuser_match:
            target_authuser = authuser_match.group(2)
        elif PROFILE_NAME == "user2" or PROFILE_NAME == "friend":
            target_authuser = "1"
        elif PROFILE_NAME == "user3":
            target_authuser = "2"

        headers["x-goog-authuser"] = str(target_authuser)

        if "\n" in raw_text and (": " in raw_text or "cookie:" in raw_text.lower()):
            for line in raw_text.splitlines():
                if ": " in line:
                    k, v = line.split(": ", 1)
                    k_lower = k.strip().lower()
                    if k_lower in ("cookie", "authorization", "x-goog-authuser", "user-agent"):
                        headers[k_lower] = v.strip()
        else:
            cookie_str = raw_text
            if cookie_str.lower().startswith("cookie:"):
                cookie_str = cookie_str[7:].strip()
            headers["cookie"] = cookie_str

        # Sanitize and prioritize crucial authentication cookies
        if "cookie" in headers:
            headers["cookie"] = sanitize_cookie_for_ytmusic(headers["cookie"])

        # Ensure SAPISID and __Secure-3PAPISID are populated for authorization
        if "cookie" in headers:
            cookie_str = headers["cookie"]
            sapisid = None
            for part in cookie_str.split(";"):
                part = part.strip()
                if "=" in part:
                    k, v = part.split("=", 1)
                    if k.strip() in ("SAPISID", "__Secure-3PAPISID"):
                        sapisid = v.strip().strip('"')
                        break
            if sapisid:
                if "__Secure-3PAPISID=" not in headers["cookie"]:
                    headers["cookie"] += f"; __Secure-3PAPISID={sapisid}"
                if "SAPISID=" not in headers["cookie"]:
                    headers["cookie"] += f"; SAPISID={sapisid}"
                now_ts = int(time.time())
                hash_input = f"{now_ts} {sapisid} https://music.youtube.com"
                sha1_hash = hashlib.sha1(hash_input.encode("utf-8")).hexdigest()
                headers["authorization"] = f"SAPISIDHASH {now_ts}_{sha1_hash}"

        # Gate check: Must have SAPISID and at least one session token (LOGIN_INFO, SID, __Secure-3PSID, SSID)
        cookie_lower = headers.get("cookie", "").lower()
        has_sapisid = "sapisid=" in cookie_lower or "__secure-3papisid=" in cookie_lower
        has_session = any(s in cookie_lower for s in ("login_info=", "sid=", "__secure-3psid=", "__secure-1psid=", "ssid="))
        if not (has_sapisid and has_session):
            return {
                "success": False,
                "error": "Missing SAPISID or session cookies. Please ensure YouTube Music sign-in redirect has completed."
            }

        temp_file = AUTH_FILE + ".tmp"
        save_json(temp_file, headers)

        # Verify and fetch account info (non-fatal if account lacks channel or API format differs)
        test_client = None
        account_info = {}
        try:
            test_client = ytmusicapi.YTMusic(temp_file)
            account_info = extract_account_details_from_client(test_client, headers)
        except Exception as err1:
            if target_authuser != "0":
                try:
                    headers["x-goog-authuser"] = "0"
                    save_json(temp_file, headers)
                    test_client = ytmusicapi.YTMusic(temp_file)
                    account_info = extract_account_details_from_client(test_client, headers)
                except Exception as err2:
                    sys.stderr.write(f"[get_account_info fallback error]: {err2}\n")
            else:
                sys.stderr.write(f"[get_account_info error]: {err1}\n")

        if not isinstance(account_info, dict):
            account_info = {}

        # Merge profile_hint if available (e.g. from browser DOM / CDP evaluation)
        if isinstance(profile_hint, dict):
            if not account_info.get("name") or account_info.get("name") == "Google User":
                if profile_hint.get("name"):
                    account_info["name"] = profile_hint.get("name")
            if not account_info.get("email"):
                if profile_hint.get("email"):
                    account_info["email"] = profile_hint.get("email")
            if not account_info.get("thumb"):
                if profile_hint.get("thumb"):
                    account_info["thumb"] = profile_hint.get("thumb")

        # Direct profile extraction from cookies if still missing
        if (not account_info.get("name") or account_info.get("name") == "Google User") or not account_info.get("email"):
            direct_profile = fetch_google_profile_from_cookies(headers.get("cookie", ""))
            if direct_profile.get("name") and (not account_info.get("name") or account_info.get("name") == "Google User"):
                account_info["name"] = direct_profile["name"]
            if direct_profile.get("email") and not account_info.get("email"):
                account_info["email"] = direct_profile["email"]
            if direct_profile.get("thumb") and not account_info.get("thumb"):
                account_info["thumb"] = direct_profile["thumb"]

        name = account_info.get("name") or account_info.get("accountName") or "Google User"
        thumb = account_info.get("thumb") or account_info.get("accountPhotoUrl") or ""
        handle = account_info.get("handle") or account_info.get("channelHandle") or ""
        email = account_info.get("email") or handle or ""
        if not email and name and name != "Google User":
            safe_name = re.sub(r'[^a-zA-Z0-9]', '', name).lower()
            email = f"{safe_name or (PROFILE_NAME or 'user')}@gmail.com"

        try:
            os.replace(temp_file, AUTH_FILE)
        except Exception:
            try:
                if os.path.exists(AUTH_FILE):
                    os.remove(AUTH_FILE)
                os.replace(temp_file, AUTH_FILE)
            except Exception:
                shutil.copy2(temp_file, AUTH_FILE)
                if os.path.exists(temp_file):
                    try:
                        os.remove(temp_file)
                    except Exception:
                        pass

        # Cache profile info for instant sub-millisecond access
        user_cache_file = os.path.join(os.path.dirname(AUTH_FILE), f"nutsty_user_cache{PROFILE_SUFFIX}.json")
        try:
            user_data = {
                "email": email.strip().lower(),
                "name": name,
                "avatar": thumb,
                "handle": handle
            }
            with open(user_cache_file, "w", encoding="utf-8") as ucf:
                json.dump(user_data, ucf, indent=2, ensure_ascii=False)
        except Exception as ce:
            sys.stderr.write(f"[cache user info error]: {ce}\n")

        try:
            with open(AUTH_CHANGED_FILE, "w") as f:
                f.write(str(time.time()))
        except Exception:
            pass

        return {
            "success": True,
            "name": name,
            "thumb": thumb,
            "avatar": thumb,
            "email": email,
            "handle": handle,
            "message": f"Connected successfully as {name}"
        }
    except Exception as e:
        if os.path.exists(AUTH_FILE + ".tmp"):
            try: os.remove(AUTH_FILE + ".tmp")
            except: pass
        return {"success": False, "error": str(e)}

def logout():
    if os.path.exists(AUTH_FILE):
        try:
            os.remove(AUTH_FILE)
        except Exception:
            pass
    user_cache_file = os.path.join(os.path.dirname(AUTH_FILE), f"nutsty_user_cache{PROFILE_SUFFIX}.json")
    if os.path.exists(user_cache_file):
        try:
            os.remove(user_cache_file)
        except Exception:
            pass
    try:
        with open(AUTH_CHANGED_FILE, "w") as f:
            f.write(str(time.time()))
    except Exception:
        pass
    return {"success": True}


def get_exported_cookie_file():
    if not os.path.exists(AUTH_FILE):
        return None
    try:
        data = load_json(AUTH_FILE, {})
        raw_cookie = data.get("cookie", "")
        if not raw_cookie:
            return None
        temp_dir = pc.get_temp_dir()
        os.makedirs(temp_dir, exist_ok=True)
        out_path = os.path.join(temp_dir, f"nutsty_yt_cookies{PROFILE_SUFFIX}.txt")
        now = int(time.time()) + 365 * 86400
        lines = ["# Netscape HTTP Cookie File\n"]
        for item in raw_cookie.split(";"):
            item = item.strip()
            if not item or "=" not in item:
                continue
            k, v = item.split("=", 1)
            lines.append(f".youtube.com\tTRUE\t/\tTRUE\t{now}\t{k.strip()}\t{v.strip()}\n")
        with open(out_path, "w", encoding="utf-8") as f:
            f.writelines(lines)
        return out_path
    except Exception as e:
        sys.stderr.write(f"[get_exported_cookie_file error]: {e}\n")
        return None


