#!/usr/bin/env python
"""Regenerate SportSphere launcher icons from logo.png.

- Legacy mipmap ic_launcher.png: full-bleed circle logo, TRANSPARENT outside
  the artwork (no dark square, no padding).
- Adaptive icon foreground ic_launcher_fg.png (API 26+): artwork sized to the
  72dp visible mask on the 108dp canvas so the launcher mask hugs the logo
  edge-to-edge; background layer is transparent -> no white/dark tile.
Run from repo root:  python scripts/make_launcher_icons.py
"""
from PIL import Image
import os

SRC = "logo.png"
RES = "mobile/android/app/src/main/res"

# legacy: (density, side px). full-bleed artwork on transparent canvas
LEGACY = [("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)]
# adaptive foreground: (density, canvas 108dp px, safe mask 72dp px)
ADAPTIVE = [("mdpi", 108, 72), ("hdpi", 162, 108), ("xhdpi", 216, 144),
            ("xxhdpi", 324, 216), ("xxxhdpi", 432, 288)]

src = Image.open(SRC).convert("RGBA")


def tight(im: Image.Image) -> Image.Image:
    """Crop to the non-transparent bounding box of the artwork."""
    return im.crop(im.getbbox())


def resized_square(im: Image.Image, side: int) -> Image.Image:
    """Resize tight artwork onto a side x side TRANSPARENT canvas, full-bleed."""
    t = tight(im)
    w, h = t.size
    s = max(w, h)  # scale so the larger dimension touches the canvas edge
    nw, nh = max(1, round(w * side / s)), max(1, round(h * side / s))
    t = t.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(t, ((side - nw) // 2, (side - nh) // 2), t)
    return canvas


for density, side in LEGACY:
    img = resized_square(src, side)
    out = f"{RES}/mipmap-{density}/ic_launcher.png"
    os.makedirs(os.path.dirname(out), exist_ok=True)
    img.save(out)
    print("wrote", out, img.size)

for density, canvas_px, mask_px in ADAPTIVE:
    img = resized_square(src, mask_px)
    out = f"{RES}/mipmap-{density}/ic_launcher_fg.png"
    canvas = Image.new("RGBA", (canvas_px, canvas_px), (0, 0, 0, 0))
    canvas.paste(img, ((canvas_px - mask_px) // 2, (canvas_px - mask_px) // 2), img)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    canvas.save(out)
    print("wrote", out, canvas.size)

# round icon resource (used by launchers that request a circle mask)
for density, side in LEGACY:
    img = resized_square(src, side)
    out = f"{RES}/mipmap-{density}/ic_launcher_round.png"
    img.save(out)
    print("wrote", out, img.size)

print("done")
