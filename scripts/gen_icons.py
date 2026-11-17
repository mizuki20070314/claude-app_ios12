#!/usr/bin/env python3
"""Generate AppIcon PNGs for ClaudeApp (orange #D97757 + white spark)."""
import os
import math
import json
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                   "ClaudeApp", "Resources", "Assets.xcassets", "AppIcon.appiconset")

BG = (217, 119, 87)
WHITE = (255, 255, 255, 255)

ICONS = [
    ("Icon-20@2x.png", 40),
    ("Icon-20@3x.png", 60),
    ("Icon-29@2x.png", 58),
    ("Icon-29@3x.png", 87),
    ("Icon-40@2x.png", 80),
    ("Icon-40@3x.png", 120),
    ("Icon-60@2x.png", 120),
    ("Icon-60@3x.png", 180),
    ("Icon-20@1x.png", 20),
    ("Icon-29@1x.png", 29),
    ("Icon-40@1x.png", 40),
    ("Icon-76@1x.png", 76),
    ("Icon-76@2x.png", 152),
    ("Icon-83.5@2x.png", 167),
    ("Icon-1024.png", 1024),
]

def draw_icon(size):
    img = Image.new("RGBA", (size, size), BG + (255,))
    d = ImageDraw.Draw(img)
    cx = cy = size / 2.0
    n = 12
    base = size * 0.42
    short = size * 0.26
    width = max(2, int(size * 0.055))
    for i in range(n):
        ang = (2 * math.pi * i) / n
        length = base if (i % 2 == 0) else short
        x1 = cx + math.cos(ang) * (size * 0.06)
        y1 = cy + math.sin(ang) * (size * 0.06)
        x2 = cx + math.cos(ang) * length
        y2 = cy + math.sin(ang) * length
        d.line([(x1, y1), (x2, y2)], fill=WHITE, width=width)
        r = width / 2.0
        d.ellipse([x2 - r, y2 - r, x2 + r, y2 + r], fill=WHITE)
    cr = size * 0.05
    d.ellipse([cx - cr, cy - cr, cx + cr, cy + cr], fill=WHITE)
    return img

def main():
    os.makedirs(OUT, exist_ok=True)
    for name, size in ICONS:
        img = draw_icon(size)
        img.save(os.path.join(OUT, name), "PNG")
    contents = {
        "images": [
            {"size": "20x20", "idiom": "iphone", "filename": "Icon-20@2x.png", "scale": "2x"},
            {"size": "20x20", "idiom": "iphone", "filename": "Icon-20@3x.png", "scale": "3x"},
            {"size": "29x29", "idiom": "iphone", "filename": "Icon-29@2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "iphone", "filename": "Icon-29@3x.png", "scale": "3x"},
            {"size": "40x40", "idiom": "iphone", "filename": "Icon-40@2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "iphone", "filename": "Icon-40@3x.png", "scale": "3x"},
            {"size": "60x60", "idiom": "iphone", "filename": "Icon-60@2x.png", "scale": "2x"},
            {"size": "60x60", "idiom": "iphone", "filename": "Icon-60@3x.png", "scale": "3x"},
            {"size": "20x20", "idiom": "ipad", "filename": "Icon-20@1x.png", "scale": "1x"},
            {"size": "20x20", "idiom": "ipad", "filename": "Icon-20@2x.png", "scale": "2x"},
            {"size": "29x29", "idiom": "ipad", "filename": "Icon-29@1x.png", "scale": "1x"},
            {"size": "29x29", "idiom": "ipad", "filename": "Icon-29@2x.png", "scale": "2x"},
            {"size": "40x40", "idiom": "ipad", "filename": "Icon-40@1x.png", "scale": "1x"},
            {"size": "40x40", "idiom": "ipad", "filename": "Icon-40@2x.png", "scale": "2x"},
            {"size": "76x76", "idiom": "ipad", "filename": "Icon-76@1x.png", "scale": "1x"},
            {"size": "76x76", "idiom": "ipad", "filename": "Icon-76@2x.png", "scale": "2x"},
            {"size": "83.5x83.5", "idiom": "ipad", "filename": "Icon-83.5@2x.png", "scale": "2x"},
            {"size": "1024x1024", "idiom": "ios-marketing", "filename": "Icon-1024.png", "scale": "1x"},
        ],
        "info": {"author": "xcode", "version": 1},
    }
    with open(os.path.join(OUT, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("generated", len(ICONS), "icons")

if __name__ == "__main__":
    main()
