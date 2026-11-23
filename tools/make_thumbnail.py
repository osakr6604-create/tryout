#!/usr/bin/env python3
"""Makes the project thumbnail (3:2) for the Devpost gallery from real frames.

    python tools/make_thumbnail.py

Uses the screenshots in media/screenshots, the game's own fonts and colours.
Writes media/thumbnail.png (1500 x 1000).
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

REPO = Path(__file__).resolve().parent.parent
SHOTS = REPO / "media" / "screenshots"
FONTS = REPO / "assets" / "fonts"
W, H = 1500, 1000

INK = (244, 248, 255)
DIM = (143, 163, 200)
SKY = (46, 197, 255)
PINK = (255, 79, 163)
BG = (7, 11, 23)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def main() -> None:
    # Background: the report screen, blurred and dimmed.
    back = Image.open(SHOTS / "report.png").convert("RGB").resize((1780, 1001), Image.LANCZOS).crop((140, 0, 140 + W, H))
    back = back.filter(ImageFilter.GaussianBlur(14))
    back = Image.blend(back, Image.new("RGB", (W, H), BG), 0.62)
    d = ImageDraw.Draw(back)

    # The title with its coloured echo, as on the attract screen.
    title = font("BarlowCondensed-ExtraBoldItalic.ttf", 330)
    x, y = 70, 40
    d.text((x + 12, y + 8), "TRYOUT", font=title, fill=(150, 50, 100))
    d.text((x - 10, y - 8), "TRYOUT", font=title, fill=(30, 140, 190))
    d.text((x, y), "TRYOUT", font=title, fill=INK)

    d.text((78, 400), "THINK YOU COULD GO PRO?", font=font("BarlowCondensed-Bold.ttf", 98), fill=SKY)
    d.text((80, 510), "60 seconds. 8 drills. One scouting report.", font=font("BarlowCondensed-Medium.ttf", 58), fill=DIM)

    # Two real screens, tilted cards along the bottom.
    for name, box, angle in (("drill.png", (70, 618, 580), -3), ("report.png", (800, 606, 610), 2.5)):
        shot = Image.open(SHOTS / name).convert("RGBA")
        w = box[2]
        shot = shot.resize((w, round(w * shot.height / shot.width)), Image.LANCZOS)
        frame = Image.new("RGBA", (shot.width + 12, shot.height + 12), SKY + (255,))
        frame.paste(shot, (6, 6))
        frame = frame.rotate(angle, expand=True, resample=Image.BICUBIC)
        back.paste(frame, (box[0], box[1]), frame)

    out = REPO / "media" / "thumbnail.png"
    back.save(out)
    print("wrote", out, back.size)


if __name__ == "__main__":
    main()
