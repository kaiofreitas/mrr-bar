#!/usr/bin/env python3
"""Generate MRR Bar app icon — dark card, green upward bar chart."""
import os, math
from PIL import Image, ImageDraw

def make_icon(size):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Rounded rectangle background — dark slate
    r = size * 0.22
    bg = (28, 32, 42, 255)
    d.rounded_rectangle([0, 0, size, size], radius=r, fill=bg)

    # Bar chart — 4 bars growing left to right
    pad   = size * 0.18
    gap   = size * 0.055
    n     = 4
    total_w = size - 2 * pad
    bar_w = (total_w - gap * (n - 1)) / n
    heights = [0.28, 0.45, 0.62, 0.82]  # relative heights
    bottom  = size - pad * 1.05

    for i, h in enumerate(heights):
        x0 = pad + i * (bar_w + gap)
        x1 = x0 + bar_w
        bar_h = (size - 2 * pad) * h
        y0 = bottom - bar_h
        y1 = bottom

        # Gradient-ish: lighter green for taller bars
        t = h  # 0..1
        g = int(180 + 55 * t)
        b = int(90 + 40 * t)
        color = (30, g, b, 255)

        br = max(2, bar_w * 0.28)
        d.rounded_rectangle([x0, y0, x1, y1], radius=br, fill=color)

    # Small upward tick on tallest bar
    bar_idx = 3
    x0 = pad + bar_idx * (bar_w + gap)
    x1 = x0 + bar_w
    bar_h = (size - 2 * pad) * heights[bar_idx]
    cx = (x0 + x1) / 2
    ty = bottom - bar_h - size * 0.07
    tw = size * 0.065
    th = size * 0.065
    # arrow: ^ shape
    pts = [(cx, ty), (cx - tw, ty + th), (cx + tw, ty + th)]
    d.polygon(pts, fill=(100, 230, 160, 220))

    return img

def make_icns():
    sizes = [16, 32, 64, 128, 256, 512, 1024]
    iconset = "AppIcon.iconset"
    os.makedirs(iconset, exist_ok=True)

    name_map = {
        16:   ("icon_16x16.png",      "icon_16x16@2x.png"),
        32:   ("icon_32x32.png",      "icon_32x32@2x.png"),
        64:   (None,                  "icon_32x32@2x.png"),
        128:  ("icon_128x128.png",    "icon_128x128@2x.png"),
        256:  ("icon_256x256.png",    "icon_256x256@2x.png"),
        512:  ("icon_512x512.png",    "icon_512x512@2x.png"),
        1024: (None,                  "icon_512x512@2x.png"),
    }

    for sz in sizes:
        img = make_icon(sz)
        n1, n2 = name_map[sz]
        if n1:
            img.save(f"{iconset}/{n1}")
        if n2:
            img.save(f"{iconset}/{n2}")
        print(f"  {sz}x{sz}")

    os.system(f"iconutil -c icns {iconset} -o AppIcon.icns")
    os.system(f"rm -rf {iconset}")
    print("Created AppIcon.icns")

if __name__ == "__main__":
    make_icns()
