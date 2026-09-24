#!/usr/bin/env python3
"""
Nutsty Social, Friends, 24h Notes, and Co-Listening HTTP Route Handlers
Extracted from auth_server.py for clean modularity and CodeGraph AST function indexing.
"""
import os
import json
import time
from datetime import datetime

try:
    from .cloud_relay_client import (
        GLOBAL_RELAY_CLIENT,
        _cloud_notes_cache,
        get_nutsty_config_dir,
        resolve_profile_suffix,
        ensure_cloud_identity,
        save_cloud_identity,
        load_notes_vault,
        save_notes_vault,
        load_events_vault,
        save_events_vault,
        get_user_all_identifiers,
    )
except (ImportError, ValueError):
    from cloud_relay_client import (
        GLOBAL_RELAY_CLIENT,
        _cloud_notes_cache,
        get_nutsty_config_dir,
        resolve_profile_suffix,
        ensure_cloud_identity,
        save_cloud_identity,
        load_notes_vault,
        save_notes_vault,
        load_events_vault,
        save_events_vault,
        get_user_all_identifiers,
    )


def handle_get_notes(handler, query):
    profile = query.get("profile", [""])[0].strip()
    user_email = query.get("user_email", [""])[0].strip()
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    if GLOBAL_RELAY_CLIENT.is_external():
        res = GLOBAL_RELAY_CLIENT.get_notes(caller_ident["user_id"], caller_ident["secret_key"])
        if res and res.get("unauthorized"):
            caller_ident = ensure_cloud_identity(suffix, force_recreate=True)
            res = GLOBAL_RELAY_CLIENT.get_notes(caller_ident["user_id"], caller_ident["secret_key"])
        if res and res.get("success"):
            notes_arr = res.get("notes") or []
            seen_ids = set()
            seen_tags = set()
            for n_item in notes_arr:
                if isinstance(n_item, dict):
                    if n_item.get("tag"):
                        n_item["user_email"] = n_item["tag"]
                        seen_tags.add(str(n_item["tag"]).strip().lower())
                    if n_item.get("user_id"):
                        seen_ids.add(str(n_item["user_id"]).strip().lower())
                    if not n_item.get("user_name") and n_item.get("username"):
                        n_item["user_name"] = n_item["username"]
                    n_item["is_friend"] = True

            # Ensure all accepted friends from get_friends() are present in notes_arr
            try:
                fr_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
                for f in (fr_res.get("friends") or []):
                    f_id = str(f.get("id") or "").strip().lower()
                    f_tag = str(f.get("tag") or "").strip().lower()
                    if (f_id and f_id in seen_ids) or (f_tag and f_tag in seen_tags):
                        for n_item in notes_arr:
                            if (f_id and str(n_item.get("user_id") or "").strip().lower() == f_id) or \
                               (f_tag and str(n_item.get("tag") or "").strip().lower() == f_tag):
                                if not n_item.get("avatar_url") and f.get("avatar_url"):
                                    n_item["avatar_url"] = f.get("avatar_url")
                                if not n_item.get("user_name") and f.get("username"):
                                    n_item["user_name"] = f.get("username")
                                if not n_item.get("now_playing") and f.get("now_playing") and f.get("is_online"):
                                    n_item["now_playing"] = f.get("now_playing")
                    else:
                        notes_arr.append({
                            "user_id": f.get("id", ""),
                            "user_email": f.get("tag", ""),
                            "user_name": f.get("username", ""),
                            "avatar_url": f.get("avatar_url", ""),
                            "tag": f.get("tag", ""),
                            "note_text": "",
                            "track": None,
                            "created_at": 0,
                            "is_friend": True,
                            "is_online": bool(f.get("is_online", False)),
                            "last_active_at": f.get("last_active_at", 0),
                            "now_playing": f.get("now_playing", "") if f.get("is_online") else ""
                        })
                        if f_id:
                            seen_ids.add(f_id)
                        if f_tag:
                            seen_tags.add(f_tag)
            except Exception:
                pass

            my_n = res.get("my_note")
            if isinstance(my_n, dict) and my_n.get("tag"):
                my_n["user_email"] = my_n["tag"]
            _cloud_notes_cache["ts"] = time.time()
            _cloud_notes_cache["data"] = notes_arr
            _cloud_notes_cache["my_note"] = my_n
            res["notes"] = notes_arr
            res["count"] = len(notes_arr)
            handler._send_json(res, 200)
            return

    relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
    cloud_friends = relay_res.get("friends", [])

    vault = load_notes_vault()
    now = time.time()
    valid_notes = []
    my_note = None
    cleaned_vault = {}

    caller_tag = (caller_ident.get("tag") or "").strip().lower()
    caller_uid = (caller_ident.get("user_id") or "").strip().lower()
    caller_uname = (caller_ident.get("username") or "").strip().lower()
    caller_email = user_email.strip().lower() if user_email else ""

    for k, item in vault.items():
        if item.get("_expires_ts", 0) > now:
            cleaned_vault[k] = item
            iem = item.get("user_email", "").strip().lower()
            itag = (item.get("tag") or "").strip().lower()
            iuid = (item.get("user_id") or "").strip().lower()
            iname = (item.get("user_name") or "").strip().lower()

            is_me = False
            if caller_tag and (itag == caller_tag or iem == caller_tag):
                is_me = True
            elif caller_uid and (iuid == caller_uid or iem == caller_uid):
                is_me = True
            elif caller_email and (iem == caller_email or itag == caller_email):
                is_me = True
            elif caller_uname and (iname == caller_uname or iem == caller_uname):
                is_me = True

            if is_me:
                if my_note is None or item.get("last_active_ts", 0) >= my_note.get("last_active_ts", 0):
                    my_note = item.copy()

    if len(cleaned_vault) != len(vault):
        save_notes_vault(cleaned_vault)

    ONLINE_TIMEOUT_SEC = 25.0
    for f in cloud_friends:
        f_tag = (f.get("tag") or "").strip().lower()
        f_id = (f.get("id") or "").strip().lower()
        f_name = (f.get("username") or "").strip().lower()

        matched_note = (
            cleaned_vault.get(f"note:{f_tag}") or
            cleaned_vault.get(f"note:{f_id}") or
            cleaned_vault.get(f"note:{f_name}")
        )
        if not matched_note:
            for k, item in cleaned_vault.items():
                iem = item.get("user_email", "").strip().lower()
                itag = (item.get("tag") or "").strip().lower()
                iuid = (item.get("user_id") or "").strip().lower()
                iname = (item.get("user_name") or "").strip().lower()
                if (f_tag and (itag == f_tag or iem == f_tag)) or \
                   (f_id and (iuid == f_id or iem == f_id)) or \
                   (f_name and (iname == f_name or iem == f_name)):
                    matched_note = item.copy()
                    break

        if matched_note:
            fn = matched_note.copy()
            fn["avatar_url"] = f.get("avatar_url") or fn.get("avatar_url", "")
            fn["user_name"] = f.get("username") or fn.get("user_name", "")
            fn["tag"] = f.get("tag") or fn.get("tag", "")

            last_active = fn.get("last_active_ts") or 0
            if not last_active and f.get("last_active_at"):
                last_active = f.get("last_active_at") / 1000.0 if f.get("last_active_at") > 1e11 else f.get("last_active_at")
            is_online = (now - last_active) < ONLINE_TIMEOUT_SEC if last_active else False
            fn["is_online"] = is_online
            fn["last_active_ts"] = last_active
            fn["now_playing"] = (f.get("now_playing") or fn.get("now_playing", "")) if is_online else ""
            valid_notes.append(fn)
        else:
            last_active = f.get("last_active_at", 0)
            if last_active > 1e11:
                last_active = last_active / 1000.0
            is_online = (now - last_active) < ONLINE_TIMEOUT_SEC if last_active else False
            valid_notes.append({
                "user_id": f.get("id", ""),
                "user_email": f.get("tag", ""),
                "user_name": f.get("username", ""),
                "avatar_url": f.get("avatar_url", ""),
                "tag": f.get("tag", ""),
                "note_text": "",
                "track": None,
                "created_at": 0,
                "is_friend": True,
                "is_online": is_online,
                "last_active_ts": last_active,
                "now_playing": f.get("now_playing", "") if is_online else ""
            })

    data = {"count": len(valid_notes), "notes": valid_notes, "my_note": my_note}
    handler._send_json(data, 200)


def handle_get_friends(handler, query):
    profile = query.get("profile", [""])[0].strip()
    user_email = query.get("user_email", [""])[0].strip()
    preferred_name = query.get("name", [""])[0].strip()
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None)

    relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
    if relay_res and relay_res.get("unauthorized"):
        caller_ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None, force_recreate=True)
        relay_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
    friends_data = []
    notes_vault = load_notes_vault()

    for f in (relay_res or {}).get("friends", []):
        f_tag = f["tag"]
        note_item = notes_vault.get(f"note:{f_tag}") or notes_vault.get(f"note:{f['id']}") or notes_vault.get(f"note:{f['username'].lower()}")
        friends_data.append({
            "id": f["id"],
            "user_id": f["id"],
            "email": f["tag"],
            "name": f["username"],
            "avatar": f.get("avatar_url", ""),
            "nutsty_tag": f["tag"],
            "tag": f["tag"],
            "discriminator": f["discriminator"],
            "now_playing": f.get("now_playing", ""),
            "note": note_item
        })

    incoming = []
    for r in (relay_res or {}).get("incoming_requests", []):
        incoming.append({
            "id": f"req_{r['id']}",
            "from_id": r["id"],
            "from_email": r["tag"],
            "from_name": r["username"],
            "from_avatar": r.get("avatar_url", ""),
            "from_tag": r["tag"],
            "created_at": r.get("requested_at", 0),
            "status": "pending"
        })

    data = {
        "friends": friends_data,
        "incoming_requests": incoming,
        "outgoing_requests": [],
        "unread_count": len(incoming)
    }
    handler._send_json(data, 200)


def handle_get_user_me(handler, query):
    profile = query.get("profile", [""])[0].strip()
    user_email = query.get("user_email", [""])[0].strip()
    preferred_name = query.get("name", [""])[0].strip()
    suffix = resolve_profile_suffix(profile, user_email)
    ident = ensure_cloud_identity(suffix, fallback_name=preferred_name or None)
    cur_uname = (ident.get("username") or "").strip()
    if cur_uname and cur_uname not in ("User", "Nutsty User", "Khách", "Guest"):
        display_name = cur_uname
        display_tag = ident.get("tag") or f"{display_name}#{ident.get('discriminator', '0001')}"
    else:
        display_name = preferred_name if (preferred_name and preferred_name not in ("User", "Nutsty User", "Shiraori", "Khách", "Guest")) else (cur_uname or "Nutsty User")
        display_tag = f"{display_name}#{ident.get('discriminator', '0001')}"
    handler._send_json({
        "success": True,
        "profile": {
            "id": ident["user_id"],
            "user_id": ident["user_id"],
            "name": display_name,
            "username": display_name,
            "discriminator": ident["discriminator"],
            "pin_code": ident["discriminator"],
            "tag": display_tag,
            "nutsty_tag": display_tag,
            "avatar": ident.get("avatar_url", ""),
            "avatar_url": ident.get("avatar_url", "")
        }
    }, 200)


def handle_search_users(handler, query):
    raw_q = query.get("q", [""])[0].strip()
    profile = query.get("profile", [""])[0].strip()
    user_email = query.get("user_email", [""])[0].strip()
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    res = GLOBAL_RELAY_CLIENT.search(raw_q, caller_user_id=caller_ident.get("user_id"))
    raw_results = res.get("results", [])

    # Deduplicate multiple stale IDs that have the EXACT SAME username (e.g. Shiraori#4444, #3333, #1168 -> keep newest Shiraori#4444)
    # Never merge across avatar_url alone so two devices sharing a Google account with different names (e.g. Shiraori vs nick) stay distinct!
    deduped_map = {}
    ordered_keys = []
    q_clean = raw_q.strip().lower()
    exact_disc_query = q_clean.split("#")[-1].strip() if "#" in q_clean else (q_clean if q_clean.isdigit() else "")
    caller_uid = (caller_ident.get("user_id") or "").strip()

    for r in raw_results:
        if caller_uid and r.get("id") == caller_uid:
            continue
        uname_key = (r.get("username") or "").strip().lower()
        r_disc = str(r.get("discriminator") or "").strip()
        if exact_disc_query and r_disc == exact_disc_query.zfill(4):
            person_key = f"disc:{r.get('id', '')}"
        elif uname_key and uname_key not in ("user", "nutsty user", "khách", "guest"):
            person_key = f"u:{uname_key}"
        else:
            person_key = f"id:{r.get('id', '')}"

        item_obj = {
            "id": r["id"],
            "user_id": r["id"],
            "email": r["tag"],
            "name": r["username"],
            "nutsty_tag": r["tag"],
            "tag": r["tag"],
            "pin_code": r["discriminator"],
            "discriminator": r["discriminator"],
            "avatar": r.get("avatar_url", "") or "",
            "avatar_url": r.get("avatar_url", "") or "",
            "now_playing": r.get("now_playing", ""),
            "last_active_at": r.get("last_active_at", 0) or 0,
            "is_self": False,
            "is_friend": r.get("is_friend", False),
            "has_outgoing_request": r.get("has_outgoing_request", False),
            "has_incoming_request": r.get("has_incoming_request", False)
        }

        if person_key not in deduped_map:
            deduped_map[person_key] = item_obj
            ordered_keys.append(person_key)
        else:
            existing = deduped_map[person_key]
            cand_tag_low = (r.get("tag") or "").strip().lower()
            if (q_clean and cand_tag_low == q_clean) or \
               (item_obj["last_active_at"] > existing["last_active_at"]) or \
               (item_obj["is_friend"] and not existing["is_friend"]):
                if existing["is_friend"]:
                    item_obj["is_friend"] = True
                deduped_map[person_key] = item_obj
            else:
                if item_obj["is_friend"]:
                    existing["is_friend"] = True

    results = [deduped_map[k] for k in ordered_keys]
    handler._send_json({"results": results}, 200)


def handle_get_note_events(handler, query):
    profile = query.get("profile", [""])[0].strip()
    user_email = query.get("user_email", [""])[0].strip()
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    relay_evts = GLOBAL_RELAY_CLIENT.get_events(caller_ident["user_id"], caller_ident["secret_key"])
    events = []
    for revt in relay_evts.get("events", []):
        raw_pl = revt.get("payload")
        if isinstance(raw_pl, str):
            try:
                raw_pl = json.loads(raw_pl)
            except Exception:
                raw_pl = {}
        elif not isinstance(raw_pl, dict):
            raw_pl = {}

        inner_data = raw_pl.get("data") if "data" in raw_pl else raw_pl
        events.append({
            "id": revt.get("id", ""),
            "event": revt.get("event_type", ""),
            "from_id": raw_pl.get("from_id") or revt.get("from_user_id", ""),
            "from_email": (raw_pl.get("from_tag") or raw_pl.get("tag") or revt.get("from_user_id", "")).strip(),
            "from_name": (raw_pl.get("from_name") or raw_pl.get("username") or "User").strip(),
            "from_avatar": (raw_pl.get("from_avatar") or raw_pl.get("avatar_url") or "").strip(),
            "timestamp": revt.get("created_at", time.time() * 1000) / 1000.0,
            "data": inner_data
        })

    user_aliases = set(get_user_all_identifiers(user_email))
    if caller_ident.get("tag"):
        user_aliases.add(caller_ident["tag"].strip().lower())
    if caller_ident.get("user_id"):
        user_aliases.add(caller_ident["user_id"].strip().lower())
    local_evts = load_events_vault()
    my_local = [e for e in local_evts if e.get("to_email", "").strip().lower() in user_aliases]
    rem_local = [e for e in local_evts if e.get("to_email", "").strip().lower() not in user_aliases]
    if my_local:
        save_events_vault(rem_local)
        events.extend(my_local)

    handler._send_json({"count": len(events), "events": events}, 200)


def handle_post_update_profile(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "")
    suffix = resolve_profile_suffix(profile, user_email)
    ident = ensure_cloud_identity(suffix)

    new_username = req_data.get("new_username")
    new_discriminator = req_data.get("new_discriminator")
    avatar_url = req_data.get("avatar_url")

    res = GLOBAL_RELAY_CLIENT.update_profile(
        user_id=ident["user_id"],
        secret_key=ident["secret_key"],
        new_username=new_username,
        new_discriminator=new_discriminator,
        avatar_url=avatar_url
    )

    if res.get("success") and res.get("user"):
        u = res["user"]
        ident["username"] = u["username"]
        ident["discriminator"] = u["discriminator"]
        ident["tag"] = u["tag"]
        ident["custom_username"] = True
        if "avatar_url" in u:
            ident["avatar_url"] = u["avatar_url"]
        save_cloud_identity(ident, suffix)

        d = get_nutsty_config_dir()
        uc_path = os.path.join(d, f"nutsty_user_cache{suffix}.json")
        if os.path.exists(uc_path):
            try:
                with open(uc_path, "r", encoding="utf-8") as f:
                    uc_data = json.load(f)
                uc_data["name"] = u["username"]
                with open(uc_path, "w", encoding="utf-8") as f:
                    json.dump(uc_data, f, indent=2, ensure_ascii=False)
            except Exception:
                pass

        handler._send_json({"success": True, "user": u, "profile": ident}, 200)
    else:
        handler._send_json(res, 409 if res.get("suggested_discriminator") else 400)


def handle_post_regenerate_pin(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "")
    suffix = resolve_profile_suffix(profile, user_email)
    ident = ensure_cloud_identity(suffix)

    new_disc = GLOBAL_RELAY_CLIENT.local_engine.find_available_discriminator(ident["username"])
    res = GLOBAL_RELAY_CLIENT.update_profile(
        user_id=ident["user_id"],
        secret_key=ident["secret_key"],
        new_username=ident["username"],
        new_discriminator=new_disc
    )
    if res.get("success") and res.get("user"):
        u = res["user"]
        ident["discriminator"] = u["discriminator"]
        ident["tag"] = u["tag"]
        save_cloud_identity(ident, suffix)
        handler._send_json({"success": True, "pin_code": u["discriminator"], "nutsty_tag": u["tag"], "tag": u["tag"]}, 200)
    else:
        handler._send_json({"success": False, "error": "Failed to generate new tag"}, 500)


def handle_post_user_offline(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "")
    suffix = resolve_profile_suffix(profile, user_email)
    ident = ensure_cloud_identity(suffix)

    email = user_email.lower() if user_email else ident.get("tag", "").lower()
    try:
        GLOBAL_RELAY_CLIENT.set_offline(ident["user_id"], ident["secret_key"])
    except Exception as e:
        print(f"[auth_server offline error] {e}")

    vault = load_notes_vault()
    key = f"note:{email}" if email else f"note:{ident['user_id']}"
    if key in vault:
        vault[key]["last_active_ts"] = 0
        vault[key]["now_playing"] = ""
        save_notes_vault(vault)

    handler._send_json({"success": True, "message": "User is offline"}, 200)


def handle_post_publish_note(handler, req_data):
    profile = req_data.get("profile", "").strip().lower()
    email = req_data.get("user_email", "").strip().lower()
    note_text = req_data.get("note_text", "").strip()
    track = req_data.get("track")
    if isinstance(track, dict) and not track.get("title") and not track.get("name") and not track.get("id"):
        track = None

    suffix = resolve_profile_suffix(profile, email)
    caller_ident = ensure_cloud_identity(suffix)

    cloud_tag = caller_ident.get("tag") or req_data.get("user_tag") or email
    user_name = caller_ident.get("username") or req_data.get("user_name", "Anonymous")
    avatar_url = caller_ident.get("avatar_url") or req_data.get("avatar_url", "")
    user_id = caller_ident.get("user_id", "")

    if not email and cloud_tag:
        email = cloud_tag.lower()

    if not email or (not note_text and not track):
        handler._send_json({"success": False, "error": "Missing required fields (either text or track required)"}, 400)
        return

    if GLOBAL_RELAY_CLIENT.is_external():
        cloud_res = GLOBAL_RELAY_CLIENT.publish_note(
            caller_ident["user_id"],
            caller_ident["secret_key"],
            note_text,
            track,
            req_data.get("now_playing")
        )
        if cloud_res and cloud_res.get("success"):
            handler._send_json(cloud_res, 200)
        else:
            handler._send_json(cloud_res or {"success": False, "error": "Cloud relay failed"}, 400)
        return

    ttl = 86400
    now = time.time()
    record = {
        "user_email": email,
        "tag": cloud_tag,
        "user_id": user_id,
        "user_name": user_name,
        "avatar_url": avatar_url,
        "note_text": note_text[:80],
        "track": track,
        "now_playing": req_data.get("now_playing"),
        "created_at": datetime.fromtimestamp(now).isoformat(),
        "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
        "_expires_ts": now + ttl,
        "last_active_ts": now
    }
    vault = load_notes_vault()
    if email:
        vault[f"note:{email}"] = record
    if cloud_tag:
        vault[f"note:{cloud_tag.lower()}"] = record
    if user_id:
        vault[f"note:{user_id}"] = record
    if user_name:
        vault[f"note:{user_name.lower()}"] = record

    save_notes_vault(vault)
    handler._send_json({"success": True, "note": record}, 200)


def handle_post_delete_note(handler, req_data):
    profile = req_data.get("profile", "").strip().lower()
    email = req_data.get("user_email", "").strip().lower()
    suffix = resolve_profile_suffix(profile, email)
    caller_ident = ensure_cloud_identity(suffix)

    if GLOBAL_RELAY_CLIENT.is_external():
        cloud_res = GLOBAL_RELAY_CLIENT.delete_note(caller_ident["user_id"], caller_ident["secret_key"])
        if cloud_res and cloud_res.get("success"):
            handler._send_json(cloud_res, 200)
        else:
            handler._send_json(cloud_res or {"success": False, "error": "Cloud relay failed"}, 400)
        return

    vault = load_notes_vault()
    if email:
        vault.pop(f"note:{email}", None)
    if caller_ident.get("tag"):
        vault.pop(f"note:{caller_ident['tag'].lower()}", None)
    if caller_ident.get("user_id"):
        vault.pop(f"note:{caller_ident['user_id']}", None)
    if caller_ident.get("username"):
        vault.pop(f"note:{caller_ident['username'].lower()}", None)
    save_notes_vault(vault)
    handler._send_json({"success": True}, 200)


def handle_post_note_event(handler, req_data):
    ev_type = req_data.get("event", "leave")
    from_email = req_data.get("from_email", "").strip()
    from_name = req_data.get("from_name", "").strip()
    from_avatar = req_data.get("from_avatar", "").strip()
    to_email = req_data.get("to_email", "").strip()
    profile = req_data.get("profile", "").strip().lower()
    suffix = resolve_profile_suffix(profile, from_email)
    caller_ident = ensure_cloud_identity(suffix)

    to_user_id = req_data.get("to_user_id", "").strip()
    if not to_email and not to_user_id:
        handler._send_json({"success": False, "error": "Missing to_email or to_user_id"}, 400)
        return

    if GLOBAL_RELAY_CLIENT.is_external():
        resolved_uid = to_user_id if to_user_id.startswith("usr_") else None
        resolved_tag = to_email if "#" in to_email else None
        target_lower = (to_email or to_user_id or "").lower()

        # Fast 0ms lookup from in-memory _cloud_notes_cache first
        if not resolved_uid and target_lower:
            for fn in (_cloud_notes_cache.get("data") or []):
                fn_uid = (fn.get("user_id") or "").strip()
                fn_tag = (fn.get("tag") or "").strip()
                fn_email = (fn.get("user_email") or "").strip()
                fn_name = (fn.get("user_name") or "").strip()
                if target_lower in (fn_uid.lower(), fn_tag.lower(), fn_email.lower(), fn_name.lower()):
                    if fn_uid:
                        resolved_uid = fn_uid
                    if fn_tag:
                        resolved_tag = fn_tag
                    break

        # Fallback to friends API if not in cache
        if not resolved_uid and target_lower:
            try:
                f_res = GLOBAL_RELAY_CLIENT.get_friends(caller_ident["user_id"], caller_ident["secret_key"])
                for fr in (f_res or {}).get("friends", []):
                    fr_tag = (fr.get("tag") or "").strip()
                    fr_name = (fr.get("username") or "").strip()
                    fr_id = (fr.get("id") or "").strip()
                    if fr_id.lower() == target_lower or fr_tag.lower() == target_lower or fr_name.lower() == target_lower:
                        resolved_uid = fr_id
                        resolved_tag = fr_tag
                        break
            except Exception:
                pass

        cloud_res = GLOBAL_RELAY_CLIENT.send_note_event(
            caller_ident["user_id"],
            caller_ident["secret_key"],
            to_tag=resolved_tag,
            to_user_id=resolved_uid or (to_email if not resolved_tag else None),
            event=ev_type,
            data=req_data.get("data")
        )
        if cloud_res and cloud_res.get("success"):
            handler._send_json(cloud_res, 200)
            return

    events = load_events_vault()
    ev = {
        "id": f"ev_{int(time.time()*1000)}",
        "event": ev_type,
        "from_email": from_email,
        "from_name": from_name,
        "from_avatar": from_avatar,
        "to_email": to_email,
        "data": req_data.get("data"),
        "timestamp": time.time(),
        "created_at": datetime.now().isoformat()
    }
    events.append(ev)
    save_events_vault(events)
    handler._send_json({"success": True, "event": ev}, 200)


def handle_post_now_playing(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "").strip()
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    email = user_email.lower() if user_email else caller_ident.get("tag", "").lower()
    now_playing = req_data.get("now_playing")
    track_meta = req_data.get("track")
    np_payload = None

    if isinstance(now_playing, dict):
        np_payload = now_playing
    elif isinstance(track_meta, dict):
        np_payload = {
            "title": track_meta.get("title", ""),
            "artist": track_meta.get("artist", ""),
            "cover": track_meta.get("cover", track_meta.get("image", "")),
            "videoId": track_meta.get("videoId", track_meta.get("id", "")),
            "accent_color": track_meta.get("accent_color", "")
        }
    elif isinstance(now_playing, str) and now_playing.strip().startswith("{"):
        try:
            np_payload = json.loads(now_playing)
        except Exception:
            pass

    if np_payload is None and req_data.get("title"):
        np_payload = {
            "title": req_data.get("title", ""),
            "artist": req_data.get("artist", ""),
            "cover": req_data.get("image", req_data.get("cover", "")),
            "videoId": req_data.get("videoId", req_data.get("id", "")),
            "accent_color": req_data.get("accent_color", "")
        }

    presence_val = np_payload if np_payload else (now_playing if now_playing is not None else "")
    np_text = ""
    if isinstance(np_payload, dict):
        np_text = f"{np_payload.get('title', '')} - {np_payload.get('artist', '')}".strip(" -")
    elif isinstance(now_playing, str):
        np_text = now_playing

    try:
        GLOBAL_RELAY_CLIENT.update_presence(caller_ident["user_id"], caller_ident["secret_key"], presence_val)
    except Exception as pe:
        print(f"[auth_server presence error] {pe}")

    vault = load_notes_vault()
    key = f"note:{email}" if email else f"note:{caller_ident['user_id']}"
    now = time.time()
    store_np = np_payload if np_payload else np_text
    if key in vault:
        vault[key]["now_playing"] = store_np
        vault[key]["last_active_ts"] = now
        if np_payload and not vault[key].get("track"):
            vault[key]["track"] = np_payload
        record = vault[key]
    else:
        ttl = 86400
        record = {
            "user_email": email or caller_ident.get("tag", ""),
            "user_name": req_data.get("user_name") or caller_ident.get("username", "User"),
            "avatar_url": req_data.get("avatar_url") or caller_ident.get("avatar_url", ""),
            "note_text": "",
            "track": np_payload,
            "now_playing": store_np,
            "created_at": datetime.fromtimestamp(now).isoformat(),
            "expires_at": datetime.fromtimestamp(now + ttl).isoformat(),
            "_expires_ts": now + ttl,
            "last_active_ts": now
        }
        vault[key] = record
    save_notes_vault(vault)
    handler._send_json({"success": True, "note": record}, 200)


def handle_post_friend_request(handler, req_data):
    profile = req_data.get("profile", "")
    from_email = req_data.get("from_email", "")
    suffix = resolve_profile_suffix(profile, from_email)
    caller_ident = ensure_cloud_identity(suffix)

    target_user_id = (req_data.get("target_user_id") or req_data.get("target_id") or "").strip()
    to_email = (req_data.get("to_email") or req_data.get("target_email") or "").strip()

    if not target_user_id and to_email:
        search_res = GLOBAL_RELAY_CLIENT.search(to_email, caller_user_id=caller_ident["user_id"])
        for cand in search_res.get("results", []):
            if cand["tag"].lower() == to_email.lower() or cand["id"] == to_email or cand["username"].lower() == to_email.lower():
                target_user_id = cand["id"]
                break
        if not target_user_id and search_res.get("results"):
            target_user_id = search_res["results"][0]["id"]

    if not target_user_id:
        handler._send_json({"success": False, "error": "Target user not found"}, 404)
        return

    res = GLOBAL_RELAY_CLIENT.friend_request(caller_ident["user_id"], caller_ident["secret_key"], target_user_id)
    handler._send_json(res, 200 if res.get("success") else 400)


def handle_post_friend_respond(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "")
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    from_user_id = (req_data.get("from_user_id") or req_data.get("from_id") or req_data.get("target_id") or "").strip()
    from_email = req_data.get("from_email", "").strip()
    request_id = req_data.get("request_id", "").strip()
    action = req_data.get("action", "").strip().lower()

    if not from_user_id:
        if request_id:
            from_user_id = request_id.replace("req_", "")
        elif from_email:
            search_res = GLOBAL_RELAY_CLIENT.search(from_email, caller_user_id=caller_ident["user_id"])
            if search_res.get("results"):
                from_user_id = search_res["results"][0]["id"]

    if not from_user_id:
        handler._send_json({"success": False, "error": "Requester not found"}, 404)
        return

    res = GLOBAL_RELAY_CLIENT.friend_respond(caller_ident["user_id"], caller_ident["secret_key"], from_user_id, action)
    handler._send_json(res, 200 if res.get("success") else 400)


def handle_post_friend_remove(handler, req_data):
    profile = req_data.get("profile", "")
    user_email = req_data.get("user_email", "")
    suffix = resolve_profile_suffix(profile, user_email)
    caller_ident = ensure_cloud_identity(suffix)

    target_user_id = (req_data.get("target_user_id") or req_data.get("target_id") or "").strip()
    target_email = req_data.get("target_email", "").strip()
    if not target_user_id and target_email:
        search_res = GLOBAL_RELAY_CLIENT.search(target_email, caller_user_id=caller_ident["user_id"])
        for cand in search_res.get("results", []):
            if cand["tag"].lower() == target_email.lower() or cand["id"] == target_email:
                target_user_id = cand["id"]
                break

    if not target_user_id:
        handler._send_json({"success": False, "error": "Target user not found"}, 404)
        return

    res = GLOBAL_RELAY_CLIENT.friend_remove(caller_ident["user_id"], caller_ident["secret_key"], target_user_id)
    handler._send_json(res, 200 if res.get("success") else 400)
