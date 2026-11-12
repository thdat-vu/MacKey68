#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Render the README demo slides from docs/screenshots into a video/GIF.

    python3 scripts/make-demo.py

Requires Pillow and ffmpeg. The ffmpeg encode is done by the caller
(see docs/DEMO.md); this script only writes 1600x1000 slide PNGs.
"""

from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
OUT = Path("/tmp/mackey-demo")
W, H = 1600, 1000
ACCENT = (45, 212, 191)
ORANGE = (245, 158, 11)
TEXT = (244, 244, 245)
MUTED = (161, 161, 170)

FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REG = "/System/Library/Fonts/Supplemental/Arial.ttf"


def font(size: int, bold: bool = False):
    return ImageFont.truetype(FONT_BOLD if bold else FONT_REG, size)


def background() -> Image.Image:
    base = Image.new("RGBA", (W, H))
    top = (19, 19, 24)
    bottom = (10, 10, 13)
    for y in range(H):
        t = y / (H - 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * t) for i in range(3))
        ImageDraw.Draw(base).line([(0, y), (W, y)], fill=color + (255,))

    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    gd.ellipse([W - 520, -260, W + 180, 380], fill=ACCENT + (46,))
    gd.ellipse([-260, H - 360, 420, H + 180], fill=ORANGE + (32,))
    glow = glow.filter(ImageFilter.GaussianBlur(170))
    base.alpha_composite(glow)

    # Faint grid.
    grid = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(grid)
    for x in range(0, W, 80):
        draw.line([(x, 0), (x, H)], fill=(255, 255, 255, 8))
    for y in range(0, H, 80):
        draw.line([(0, y), (W, y)], fill=(255, 255, 255, 8))
    base.alpha_composite(grid)
    return base


def load_shot(name: str, crop_height: int) -> Image.Image:
    image = Image.open(SHOTS / name).convert("RGBA")
    image = image.crop((0, 0, image.width, min(crop_height, image.height)))
    image = ImageEnhance.Brightness(image).enhance(1.12)
    image = ImageEnhance.Contrast(image).enhance(1.03)
    return image


def rounded(image: Image.Image, radius: int = 22) -> Image.Image:
    mask = Image.new("L", image.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, image.width - 1, image.height - 1],
                                           radius=radius, fill=255)
    result = image.copy()
    result.putalpha(mask)
    return result


def place_shot(canvas: Image.Image, image: Image.Image,
               max_w: int = 1280, max_h: int = 660, top: int = 230) -> None:
    scale = min(max_w / image.width, max_h / image.height)
    size = (round(image.width * scale), round(image.height * scale))
    shot = rounded(image.resize(size, Image.LANCZOS))

    x = (W - shot.width) // 2
    y = top

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle([x - 10, y + 14, x + shot.width + 10, y + shot.height + 24],
                         radius=26, fill=(0, 0, 0, 150))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(shot, (x, y))

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle([x, y, x + shot.width, y + shot.height],
                           radius=22, outline=(255, 255, 255, 38), width=2)


def header(canvas: Image.Image, index: int, total: int, title: str, subtitle: str) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.text((80, 54), "MACKEY68", font=font(18, True), fill=ACCENT)
    draw.text((W - 80, 54), f"{index:02d} / {total:02d}",
              font=font(18), fill=MUTED, anchor="ra")
    draw.text((80, 94), title, font=font(52, True), fill=TEXT)
    draw.text((80, 164), subtitle, font=font(24), fill=MUTED)


def footer(canvas: Image.Image) -> None:
    draw = ImageDraw.Draw(canvas)
    draw.text((80, H - 58), "github.com/thdat-vu/MacKey68",
              font=font(18), fill=MUTED)
    draw.text((W - 80, H - 58), "GPL-3.0 · macOS 13+",
              font=font(18), fill=MUTED, anchor="ra")


def pill(draw: ImageDraw.ImageDraw, x: int, y: int, text: str,
         fill=(38, 39, 47, 255), color=(232, 232, 238)) -> int:
    f = font(20)
    bbox = draw.textbbox((0, 0), text, font=f)
    pw = bbox[2] - bbox[0] + 36
    ph = bbox[3] - bbox[1] + 20
    draw.rounded_rectangle([x, y, x + pw, y + ph], radius=ph // 2,
                           fill=fill, outline=(72, 74, 84, 255), width=1)
    draw.text((x + 18, y + 10), text, font=f, fill=color)
    return pw


def intro() -> Image.Image:
    canvas = background()
    icon = Image.open(ROOT / "Assets" / "AppIcon-1024.png").convert("RGBA")
    icon = icon.resize((210, 210), Image.LANCZOS)
    canvas.alpha_composite(icon, ((W - 210) // 2, 140))

    draw = ImageDraw.Draw(canvas)
    draw.text((W // 2, 390), "MacKey68", font=font(86, True), fill=TEXT, anchor="ma")
    draw.text((W // 2, 500),
              "Ziyoulang K68 → a real macOS keyboard",
              font=font(30), fill=MUTED, anchor="ma")

    labels = ["68 / TKL / Full", "Per-app profiles", "Key Test", "VI / EN"]
    widths = [font(20).getlength(t) + 36 for t in labels]
    gap = 14
    x = (W - (sum(widths) + gap * (len(widths) - 1))) // 2
    for text, width in zip(labels, widths):
        pill(draw, x, 590, text)
        x += width + gap

    draw.text((W // 2, 760),
              "No vendor software. Standard HID, remapped at the OS level.",
              font=font(22), fill=(220, 220, 225), anchor="ma")
    draw.text((W // 2, 810), "Open source · GPL-3.0", font=font(20), fill=ACCENT, anchor="ma")
    footer(canvas)
    return canvas


def shot_slide(index: int, total: int, title: str, subtitle: str,
               image: Image.Image, max_w: int, max_h: int, top: int = 232) -> Image.Image:
    canvas = background()
    header(canvas, index, total, title, subtitle)
    place_shot(canvas, image, max_w=max_w, max_h=max_h, top=top)
    footer(canvas)
    return canvas


def outro() -> Image.Image:
    canvas = background()
    draw = ImageDraw.Draw(canvas)
    draw.text((W // 2, 300), "Try it on your keyboard",
              font=font(70, True), fill=TEXT, anchor="ma")
    draw.text((W // 2, 405), "Menu-bar app · 68 / TKL / Full · per-app profiles",
              font=font(26), fill=MUTED, anchor="ma")
    draw.text((W // 2, 520), "github.com/thdat-vu/MacKey68",
              font=font(34, True), fill=ACCENT, anchor="ma")
    draw.text((W // 2, 585), "Download the DMG from GitHub Releases",
              font=font(22), fill=MUTED, anchor="ma")
    draw.text((W // 2, 690), "GPL-3.0-or-later", font=font(20), fill=MUTED, anchor="ma")
    return canvas


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    total = 5

    slides = [
        intro(),
        shot_slide(1, total, "Remap any key",
                   "Click a key, pick a target. Blue = remapped, green = tested.",
                   load_shot("demo-board.png", 1050), 1280, 640),
        shot_slide(2, total, "One app, three layouts",
                   "68-key, TKL and full-size drawings — detected automatically.",
                   load_shot("demo-tkl.png", 1050), 1280, 640),
        shot_slide(3, total, "Test phím / Key Test",
                   "Coverage, raw → mapped keys, chatter detection and a copyable report.",
                   load_shot("demo-keytest.png", 1456), 1180, 640),
        shot_slide(4, total, "Guided from the first launch",
                   "A 4-step guide in Vietnamese and English, reopenable from the menu.",
                   load_shot("demo-guide.png", 1180), 1180, 640),
        outro(),
    ]

    for index, slide in enumerate(slides):
        slide.convert("RGB").save(OUT / f"slide-{index}.png")
    print(f"wrote {len(slides)} slides to {OUT}")


if __name__ == "__main__":
    main()
