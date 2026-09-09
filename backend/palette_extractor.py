#!/usr/bin/env python3
"""
Frostify Local - Intelligent Adaptive Wallpaper Palette & Luminance Inversion Engine
Analyzes the desktop wallpaper and local lyric region (x: 14%..52%, y: 69%..77%).
Detects light vs dark background contrast, extracts harmonic highlight colors,
and outputs dynamic styling parameters to ~/.config/noctalia/frostify_palette.json.
"""

import sys
import os
import json
import re
import colorsys
from pathlib import Path
from PIL import Image

def get_current_wallpaper() -> Path:
    # 1. Check CLI argument
    if len(sys.argv) > 1 and sys.argv[1].strip():
        candidate = Path(os.path.expanduser(sys.argv[1].strip()))
        if candidate.exists():
            return candidate

    home = Path.home()

    # 2. Check theme_hook.log for most recent wallpaper change
    theme_log = home / "theme_hook.log"
    if theme_log.exists():
        try:
            lines = theme_log.read_text(encoding="utf-8", errors="ignore").splitlines()
            for line in reversed(lines):
                match = re.search(r"Wallpaper changed to (.*?) on", line)
                if match:
                    p = Path(match.group(1).strip())
                    if p.exists():
                        return p
        except Exception:
            pass

    # 3. Check noctalia settings.json
    settings_file = home / ".config" / "noctalia" / "settings.json"
    if settings_file.exists():
        try:
            data = json.loads(settings_file.read_text(encoding="utf-8"))
            wp_list = data.get("wallpaper", {}).get("monitors", [])
            for m in wp_list:
                p_str = m.get("path", "")
                if p_str:
                    p = Path(os.path.expanduser(p_str))
                    if p.exists():
                        return p
        except Exception:
            pass

    # 4. Check wallbash thumb
    thumb = Path("/tmp/noctalia_wallbash/thumb.png")
    if thumb.exists():
        return thumb

    return Path.home() / "Pictures" / "Wallpapers" / "wallhaven_k8d276.jpg"

def analyze_crop(img: Image.Image, box_norm=(0.14, 0.69, 0.52, 0.77)):
    """Analyze mean luminance and bright pixel ratio of lyric region."""
    w, h = img.size
    x1, y1 = int(box_norm[0] * w), int(box_norm[1] * h)
    x2, y2 = int(box_norm[2] * w), int(box_norm[3] * h)

    crop = img.crop((max(0, x1), max(0, y1), min(w, x2), min(h, y2))).convert("RGB")
    crop_small = crop.resize((48, 24))
    pixels = list(crop_small.convert("RGB").getdata())
    if not pixels:
        return 0.3, 0.0, False

    lums = [(0.299 * r + 0.587 * g + 0.114 * b) / 255.0 for r, g, b in pixels]
    mean_lum = sum(lums) / len(lums)
    bright_ratio = sum(1 for l in lums if l > 0.55) / len(lums)
    is_light = (mean_lum > 0.45) or (bright_ratio > 0.20)

    return round(mean_lum, 3), round(bright_ratio, 3), is_light

def extract_adaptive_palette(img: Image.Image, is_light: bool):
    """Extract aesthetic, readable colors based on wallpaper tone and brightness."""
    thumb = img.resize((96, 96)).convert("RGB")
    pixels = list(thumb.getdata())

    # Count hues across color spectrum (0 to 360 deg)
    hue_counts = {
        "purple": 0,   # 250 - 330 deg (lilac, violet, magenta)
        "blue": 0,     # 180 - 250 deg (cyan, azure, navy)
        "green": 0,    # 80 - 180 deg (emerald, olive, jade)
        "gold": 0,     # 30 - 65 deg (wheat, amber, champagne)
        "red": 0,      # 330 - 30 deg (crimson, coral, ruby)
    }

    saturated_colors = []

    for r, g, b in pixels:
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        deg = h * 360
        if s >= 0.20 and v >= 0.20:
            saturated_colors.append((r, g, b, h, s, v, deg))
            if 250 <= deg <= 330:
                hue_counts["purple"] += 1
            elif 180 <= deg < 250:
                hue_counts["blue"] += 1
            elif 80 <= deg < 180:
                hue_counts["green"] += 1
            elif 30 <= deg <= 65:
                hue_counts["gold"] += 1
            else:
                hue_counts["red"] += 1

    # Determine dominant theme
    total_saturated = len(saturated_colors)
    top_theme = "warm_classic"
    if total_saturated > 150:
        sorted_hues = sorted(hue_counts.items(), key=lambda x: x[1], reverse=True)
        top_name, top_count = sorted_hues[0]
        if top_count > total_saturated * 0.22:
            top_theme = top_name

    # Theme-specific color mappings
    if top_theme == "purple":
        dark_hl = "#d8b4fe"   # Luminous Lilac
        light_hl = "#7e22ce"  # Royal Purple Jewel Tone
    elif top_theme == "blue":
        dark_hl = "#38bdf8"   # Electric Cyan
        light_hl = "#1d4ed8"  # Cobalt Sapphire
    elif top_theme == "green":
        dark_hl = "#34d399"   # Luminous Jade
        light_hl = "#047857"  # Deep Emerald
    elif top_theme == "gold":
        dark_hl = "#deb06c"   # Vintage Champagne Gold
        light_hl = "#b45309"  # Rich Warm Amber Gold
    elif top_theme == "red":
        dark_hl = "#fb7185"   # Luminous Rose Coral
        light_hl = "#be123c"  # Deep Ruby Crimson
    else:
        dark_hl = "#deb06c"   # Classic Champagne Gold
        light_hl = "#b45309"  # Rich Warm Amber Gold

    if is_light:
        # LIGHT AREA: Dark Ink typography with soft white halo
        base_text = "#0f172a"       # Deep Slate Ink
        hl_color = light_hl         # Rich vibrant jewel tone
        dead_text = "#475569"       # Muted slate
        shadow_dir = "#33000000"    # Soft directional shadow
        shadow_amb = "#b3ffffff"    # 70% soft white halo for crisp separation
    else:
        # DARK AREA: Luminous typography with deep ambient drop shadow
        base_text = "#f8fafc"       # Crisp Pure White
        hl_color = dark_hl          # Luminous vibrant accent
        dead_text = "#cbd5e1"       # Soft misty white
        shadow_dir = "#a6020305"    # 65% deep dark
        shadow_amb = "#66000000"    # 40% black

    return {
        "theme": top_theme,
        "isLightArea": is_light,
        "baseTextColor": base_text,
        "highlightColor": hl_color,
        "deadTextColor": dead_text,
        "shadowDirectional": shadow_dir,
        "shadowAmbient": shadow_amb
    }

def main():
    wp_path = get_current_wallpaper()
    if not wp_path or not wp_path.exists():
        wp_path = Path.home() / "Pictures" / "Wallpapers" / "wallhaven_k8d276.jpg"

    print(f"Analyzing wallpaper: {wp_path}")

    # Handle video files if needed
    img_to_open = wp_path
    if wp_path.suffix.lower() in [".mp4", ".webm", ".mkv", ".gif"]:
        thumb = Path("/tmp/noctalia_wallbash/thumb.png")
        if thumb.exists():
            img_to_open = thumb
        else:
            os.system(f'magick "{wp_path}[0]" /tmp/noctalia_wallbash_frame.png')
            img_to_open = Path("/tmp/noctalia_wallbash_frame.png")

    try:
        img = Image.open(img_to_open).convert("RGB")
    except Exception as e:
        print(f"Error opening image {img_to_open}: {e}", file=sys.stderr)
        sys.exit(1)

    mean_lum, bright_ratio, is_light = analyze_crop(img, (0.14, 0.69, 0.52, 0.77))
    palette_info = extract_adaptive_palette(img, is_light)

    result = {
        "wallpaper": str(wp_path),
        "meanLuminance": mean_lum,
        "brightRatio": bright_ratio,
        "isLightArea": palette_info["isLightArea"],
        "theme": palette_info["theme"],
        "baseTextColor": palette_info["baseTextColor"],
        "highlightColor": palette_info["highlightColor"],
        "deadTextColor": palette_info["deadTextColor"],
        "shadowDirectional": palette_info["shadowDirectional"],
        "shadowAmbient": palette_info["shadowAmbient"]
    }

    out_file = Path.home() / ".config" / "noctalia" / "frostify_palette.json"
    out_file.parent.mkdir(parents=True, exist_ok=True)
    out_file.write_text(json.dumps(result, indent=2), encoding="utf-8")

    local_out = Path(__file__).resolve().parent.parent / "assets" / "frostify_palette.json"
    local_out.parent.mkdir(parents=True, exist_ok=True)
    local_out.write_text(json.dumps(result, indent=2), encoding="utf-8")

    print(f"Successfully generated palette at {out_file}")
    print(json.dumps(result, indent=2))

if __name__ == "__main__":
    main()
