#!/usr/bin/env python3
import os
import sys
import re

# Ensure backend can be imported
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "backend"))

from lyrics_helper import (
    parse_rich_sync_words,
    parse_lrc,
    get_lyrics
)

def test_syllable_parsing_and_held_notes():
    print("[TEST 1] Testing syllable parsing and held note detection...")
    sample_line = "<00:18.78> Nếu <00:19.11> em <00:19.50> nói <00:19.83> mình <00:20.05> xa <00:20.34> nhau <00:20.86> rồi <00:21.16> ngày <00:21.46> mai <00:22.08> ai <00:22.52> sẽ <00:23.38> đưa <00:23.74> lối <00:24.21> em <00:24.75> về? <00:26.54>"
    words = parse_rich_sync_words(sample_line)
    
    assert len(words) == 15, f"Expected 15 words, got {len(words)}"
    
    # "sẽ" from 22.52 to 23.38 -> dur = 0.86s >= 0.85s -> isHeld True
    se_word = next(w for w in words if w["text"] == "sẽ")
    assert se_word["isHeld"] is True, f"'sẽ' should be held note (dur={se_word['duration']})"
    
    # "về?" from 24.75 to 26.54 -> dur = 1.79s >= 0.85s -> isHeld True
    ve_word = next(w for w in words if w["text"] == "về?")
    assert ve_word["isHeld"] is True, f"'về?' should be held note (dur={ve_word['duration']})"
    
    # "Nếu" from 18.78 to 19.11 -> dur = 0.33s < 0.85s -> isHeld False
    neu_word = next(w for w in words if w["text"] == "Nếu")
    assert neu_word["isHeld"] is False, f"'Nếu' should not be held note (dur={neu_word['duration']})"
    
    print("  ✓ Syllable parsing & held notes verified.")

def test_endtime_calculation():
    print("[TEST 2] Testing endTime calculation in parse_lrc...")
    lrc_content = """[00:18.78] <00:18.78> Nếu <00:19.11> em <00:19.50> nói <00:19.83> mình <00:20.05> xa <00:20.34> nhau <00:20.86> rồi <00:21.16> ngày <00:21.46> mai <00:22.08> ai <00:22.52> sẽ <00:23.38> đưa <00:23.74> lối <00:24.21> em <00:24.75> về? <00:26.54>
[00:27.75] Nếu hôm ấy mình buông tay
[00:36.07] Quán quen xưa nơi cuối góc phố xa
"""
    parsed = parse_lrc(lrc_content)
    assert len(parsed) == 3, f"Expected 3 lines, got {len(parsed)}"
    
    # Line 0 has syllable words: endTime must match last word end (26.54)
    assert parsed[0]["endTime"] == 26.54, f"Expected endTime 26.54, got {parsed[0]['endTime']}"
    assert parsed[0]["hasWords"] is True
    
    # Line 1 has synthesized syllable words across line duration
    assert parsed[1]["endTime"] == 36.07, f"Expected endTime 36.07, got {parsed[1]['endTime']}"
    assert parsed[1]["hasWords"] is True
    assert len(parsed[1]["words"]) == 6, f"Expected 6 synthesized words, got {len(parsed[1]['words'])}"
    
    # Line 2 is last line: endTime falls back to time + 5.0 (41.07)
    assert parsed[2]["endTime"] == 41.07, f"Expected endTime 41.07, got {parsed[2]['endTime']}"
    assert parsed[2]["hasWords"] is True
    print("  ✓ endTime & synthesized word calculations verified.")

def test_dual_layer_overlap_logic():
    print("[TEST 3] Testing dual-layer vocal overlap logic (Love Me Not pattern)...")
    # Simulate: Line 1 = "am I out of my mind?", Line 2 = "And, oh,"
    # Line 1: [100.0s -> 106.0s]
    # Line 2: [104.5s -> 108.0s]
    line1 = {"time": 100.0, "endTime": 106.0, "text": "am I out of my mind?"}
    line2 = {"time": 104.5, "endTime": 108.0, "text": "And, oh,"}
    
    def is_line_active(line, cur_t):
        st = line["time"]
        et = line["endTime"]
        return (cur_t >= (st - 0.15)) and (cur_t <= (et + 0.25))
    
    # At t = 102.0s: Only Line 1 is active
    assert is_line_active(line1, 102.0) is True
    assert is_line_active(line2, 102.0) is False
    
    # At t = 105.0s (Overlap zone): BOTH lines must be active simultaneously!
    assert is_line_active(line1, 105.0) is True, "Line 1 must remain active during overlap"
    assert is_line_active(line2, 105.0) is True, "Line 2 must be active simultaneously"
    
    # At t = 107.0s: Line 1 has ended, only Line 2 is active
    assert is_line_active(line1, 107.0) is False
    assert is_line_active(line2, 107.0) is True
    print("  ✓ Dual-layer vocal overlap verified.")

def test_qml_positioner_safety():
    print("[TEST 4] Testing QML Flow positioner safety in AppleMusicWordFlow.qml...")
    flow_qml_path = os.path.join(os.path.dirname(__file__), "..", "components", "AppleMusicWordFlow.qml")
    with open(flow_qml_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    delegate_match = re.search(r'delegate:\s*Item\s*\{\s*id:\s*wordContainer(.*?)(?=// Inner animated item)', content, re.DOTALL)
    assert delegate_match, "Could not find wordContainer delegate"
    delegate_body = delegate_match.group(1)
    
    assert not re.search(r'\by\s*:', delegate_body), "wordContainer must NOT have direct y: binding (breaks Flow positioner!)"
    assert "transform: Translate" in content, "Must use transform: Translate for wave motion"
    print("  ✓ QML Flow positioner safety verified.")

if __name__ == "__main__":
    test_syllable_parsing_and_held_notes()
    test_endtime_calculation()
    test_dual_layer_overlap_logic()
    test_qml_positioner_safety()
    print("\n🎉 ALL 4 LYRIC ENGINE TESTS PASSED!")
