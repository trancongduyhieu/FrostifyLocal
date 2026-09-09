#!/usr/bin/env python3
"""
Fast Single Track Lyrics Query Helper
Returns JSON lyrics array for a given track path or title
"""
import sys
import json
import os
import sqlite3

def get_lyrics(title, video_id=None):
    db_path = os.path.expanduser('~/Music/SimpMusic/extracted/Music Database')
    if not os.path.exists(db_path):
        return []

    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    raw_lines = None
    if video_id:
        r = c.execute('SELECT lines FROM lyrics WHERE videoId = ?', (video_id,)).fetchone()
        if r and r[0]:
            raw_lines = r[0]

    if not raw_lines:
        r = c.execute('''
            SELECT l.lines FROM lyrics l
            JOIN song s ON s.videoId = l.videoId
            WHERE s.title = ? AND l.lines IS NOT NULL AND l.lines != ""
            LIMIT 1
        ''', (title,)).fetchone()
        if r and r[0]:
            raw_lines = r[0]

    if not raw_lines:
        # Fuzzy match
        r = c.execute('''
            SELECT l.lines FROM lyrics l
            JOIN song s ON s.videoId = l.videoId
            WHERE s.title LIKE ? AND l.lines IS NOT NULL AND l.lines != ""
            LIMIT 1
        ''', (f"%{title}%",)).fetchone()
        if r and r[0]:
            raw_lines = r[0]

    if not raw_lines:
        return []

    try:
        parsed = json.loads(raw_lines)
        results = []
        for line in parsed:
            w = line.get('words', '').strip()
            # Clean sync tags like <00:00.66>
            import re
            clean_w = re.sub(r'<[0-9:.]+>', '', w).strip()
            st = int(line.get('startTimeMs', 0))
            if clean_w:
                results.append({'time': st / 1000.0, 'text': clean_w})
        return results
    except Exception:
        return []

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("[]")
        sys.exit(0)

    title_arg = sys.argv[1]
    vid_arg = sys.argv[2] if len(sys.argv) > 2 else None
    res = get_lyrics(title_arg, vid_arg)
    print(json.dumps(res, ensure_ascii=False))
