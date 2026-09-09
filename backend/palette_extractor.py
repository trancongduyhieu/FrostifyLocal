#!/usr/bin/env python3
"""
Frostify Local - Wallpaper Palette & Local Luminance Extractor
Extracts 3 high-contrast triad colors (Line 1, Line 2, Flame) and detects
local luminance at desktop lyrics placement coordinates.
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

    return None

def rgb_to_hex(r, g, b) -> str:
    return f"#{int(r):02x}{int(g):02x}{int(b):02x}"

def get_luminance(r, g, b) -> float:
    # Standard sRGB perceptual luminance (0.0 to 1.0)
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255.0

def analyze_crop_luminance(img: Image.Image, box_norm: tuple) -> float:
    """Calculate mean luminance of a normalized bounding box (x1, y1, x2, y2)."""
    w, h = img.size
    x1 = int(box_norm[0] * w)
    y1 = int(box_norm[1] * h)
    x2 = int(box_norm[2] * w)
    y2 = int(box_norm[3] * h)

    crop = img.crop((max(0, x1), max(0, y1), min(w, x2), min(h, y2))).convert("RGB")
    crop_small = crop.resize((32, 16))
    pixels = list(crop_small.getdata())
    if not pixels:
        return 0.5
    total_lum = sum(get_luminance(r, g, b) for r, g, b in pixels)
    return total_lum / len(pixels)

def extract_triad_palette(img: Image.Image):
    """
    Extract 3 harmonious, high-contrast colors from wallpaper:
    1. Line 1 Accent (Warm / Ruby / Crimson tone or primary distinct hue)
    2. Line 2 Accent (Cool / Cyan / Azure tone or secondary distinct hue)
    3. Flame Ignition Burst (High vibrancy, luminous spark/ember color)
    """
    # Downsample for fast analysis
    thumb = img.resize((128, 128)).convert("RGB")
    quantized = thumb.quantize(colors=32, method=Image.Quantize.MEDIANCUT)
    palette_raw = quantized.getpalette()[: 32 * 3]
    color_counts = quantized.getcolors()

    # Sort colors by frequency
    sorted_colors = sorted(color_counts, key=lambda x: x[0], reverse=True)

    candidates = []
    for count, idx in sorted_colors:
        r = palette_raw[idx * 3]
        g = palette_raw[idx * 3 + 1]
        b = palette_raw[idx * 3 + 2]
        h, s, v = colorsys.rgb_to_hsv(r / 255.0, g / 255.0, b / 255.0)
        # Score based on count and saturation (we want visible colors, not pure mud)
        score = (count ** 0.5) * (0.3 + 0.7 * s) * (0.4 + 0.6 * v)
        candidates.append({
            "rgb": (r, g, b),
            "hex": rgb_to_hex(r, g, b),
            "hsv": (h, s, v),
            "score": score,
            "lum": get_luminance(r, g, b)
        })

    # Pick the most vibrant/prominent color
    vibrant_candidates = [c for c in candidates if c["hsv"][1] > 0.18 and c["hsv"][2] > 0.25]
    if not vibrant_candidates:
        vibrant_candidates = candidates

    # 1. Line 1 Accent: First vibrant color
    c1 = vibrant_candidates[0]

    # 2. Line 2 Accent: Color with the largest angular hue distance from c1
    c2 = None
    max_hue_dist = -1
    for c in vibrant_candidates:
        hue_dist = abs(c["hsv"][0] - c1["hsv"][0])
        if hue_dist > 0.5:
            hue_dist = 1.0 - hue_dist
        if hue_dist > max_hue_dist and hue_dist > 0.12:
            max_hue_dist = hue_dist
            c2 = c

    if c2 is None:
        # Fallback: synthesize complementary triad if wallpaper is monochromatic
        h2 = (c1["hsv"][0] + 0.45) % 1.0
        r2, g2, b2 = colorsys.hsv_to_rgb(h2, max(0.45, c1["hsv"][1]), max(0.70, c1["hsv"][2]))
        c2 = {
            "rgb": (int(r2 * 255), int(g2 * 255), int(b2 * 255)),
            "hex": rgb_to_hex(r2 * 255, g2 * 255, b2 * 255),
            "hsv": (h2, c1["hsv"][1], c1["hsv"][2]),
            "lum": get_luminance(r2 * 255, g2 * 255, b2 * 255)
        }

    # 3. Flame Color: High-luminance fire/ignition spark (Golden Amber / Radiant Flame)
    flame_hue = (c1["hsv"][0] + 0.18) % 1.0
    rf, gf, bf = colorsys.hsv_to_rgb(flame_hue, 0.85, 0.98)
    flame_hex = rgb_to_hex(rf * 255, gf * 255, bf * 255)

    return c1["hex"], c2["hex"], flame_hex

def main():
    wp_path = get_current_wallpaper()
    if not wp_path or not wp_path.exists():
        print("Warning: Wallpaper not found, using default radiant palette.", file=sys.stderr)
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

    # Coordinates for Line 1 (x: ~14% to ~50%, y: ~77% to ~86%)
    # Coordinates for Line 2 (x: ~25% to ~61%, y: ~87% to ~96%)
    line1_lum = analyze_crop_luminance(img, (0.13, 0.77, 0.50, 0.86))
    line2_lum = analyze_crop_luminance(img, (0.24, 0.87, 0.61, 0.96))

    line1_is_light = line1_lum > 0.52
    line2_is_light = line2_lum > 0.52

    line1_color, line2_color, flame_color = extract_triad_palette(img)

    # Noctalia wallbash fallback check
    wallbash_file = Path.home() / ".config" / "noctalia" / "wallbash_colors.json"
    if wallbash_file.exists():
        try:
            wb = json.loads(wallbash_file.read_text())
            if wb.get("mError"):
                line1_color = wb["mError"]
            if wb.get("mOnSurfaceVariant"):
                line2_color = wb["mOnSurfaceVariant"]
        except Exception:
            pass

    palette_data = {
        "wallpaper": str(wp_path),
        "line1Color": line1_color,
        "line2Color": line2_color,
        "flameColor": flame_color,
        "line1Luminance": round(line1_lum, 3),
        "line2Luminance": round(line2_lum, 3),
        "line1IsLightArea": line1_is_light,
        "line2IsLightArea": line2_is_light,
        "lightAreaStyle": {
            "textColor": "#0c0e12",
            "outlineColor": "#ffffff",
            "activeAura": line1_color,
            "runeColor": line1_color
        },
        "darkAreaStyle": {
            "textColor": "#ffffff",
            "outlineColor": "#08090c",
            "activeAura": line1_color,
            "runeColor": line1_color
        }
    }

    # Save to ~/.config/noctalia/frostify_palette.json
    out_dir = Path.home() / ".config" / "noctalia"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / "frostify_palette.json"
    out_file.write_text(json.dumps(palette_data, indent=2))

    # Also save to project assets for local fallback
    script_dir = Path(__file__).resolve().parent.parent
    local_out = script_dir / "assets" / "frostify_palette.json"
    local_out.parent.mkdir(parents=True, exist_ok=True)
    local_out.write_text(json.dumps(palette_data, indent=2))

    print(f"Successfully generated palette at {out_file}")
    print(json.dumps(palette_data, indent=2))

if __name__ == "__main__":
    main()
