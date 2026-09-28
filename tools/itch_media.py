"""Build itch.io media from the capture scene's output.

    python tools/itch_media.py <capture_dir> <out_dir>

Makes: fold.gif (the fold + slam loop), cover.png (630x500) and screenshot_N.png copies.
Needs Pillow. Run the capture first (see scripts/tests/capture.gd).
"""
import os
import shutil
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

INK = (58, 42, 28)
PARCHMENT = (234, 217, 176)
TABLE = (42, 29, 20)
GOLD = (217, 164, 58)
RED = (168, 50, 45)
FONT_BOLD = "C:/Windows/Fonts/georgiab.ttf"
FONT_ITALIC = "C:/Windows/Fonts/georgiai.ttf"


def make_gif(cap, out):
    frames_dir = os.path.join(cap, "gif")
    names = sorted(f for f in os.listdir(frames_dir) if f.endswith(".png"))
    frames = [Image.open(os.path.join(frames_dir, n)).convert("RGB") for n in names]
    # hold the last frame a moment before looping
    durations = [45] * len(frames)
    durations[-1] = 900
    pal = [f.quantize(colors=128, method=Image.Quantize.MEDIANCUT) for f in frames]
    pal[0].save(os.path.join(out, "fold.gif"), save_all=True, append_images=pal[1:],
                duration=durations, loop=0, optimize=True)


def outlined(draw, xy, text, font, fill, outline, width):
    x, y = xy
    for dx in range(-width, width + 1):
        for dy in range(-width, width + 1):
            if dx * dx + dy * dy <= width * width:
                draw.text((x + dx, y + dy), text, font=font, fill=outline)
    draw.text(xy, text, font=font, fill=fill)


def make_cover(cap, out, root):
    W, H = 630, 500
    cover = Image.new("RGB", (W, H), TABLE)
    # right: the slam moment, tilted like a map lying on the table
    shot = Image.open(os.path.join(cap, "shot_3_aim.png")).convert("RGBA")
    shot = shot.resize((int(shot.width * 520 / shot.height), 520), Image.LANCZOS)
    shadow = Image.new("RGBA", shot.size, (0, 0, 0, 150)).filter(ImageFilter.GaussianBlur(6))
    rot = shot.rotate(-6, expand=True, resample=Image.BICUBIC)
    rsh = shadow.rotate(-6, expand=True, resample=Image.BICUBIC)
    x = W - rot.width + 40
    cover.paste(rsh, (x + 10, -2), rsh)
    cover.paste(rot, (x, -12), rot)
    # left: title card on parchment
    card = Image.new("RGBA", (350, 420), PARCHMENT + (255,))
    d = ImageDraw.Draw(card)
    d.rectangle([6, 6, 343, 413], outline=INK, width=3)
    d.rectangle([12, 12, 337, 407], outline=(110, 75, 42), width=1)
    keep = Image.open(os.path.join(root, "assets/sprites/buildings/keep.png")).convert("RGBA")
    keep = keep.resize((190, int(keep.height * 190 / keep.width)), Image.LANCZOS)
    card.alpha_composite(keep, ((350 - keep.width) // 2, 196))
    title = ImageFont.truetype(FONT_BOLD, 58)
    sub = ImageFont.truetype(FONT_ITALIC, 21)
    for i, word in enumerate(["FOLDED", "KEEP"]):
        w = d.textlength(word, font=title)
        outlined(d, ((350 - w) / 2, 34 + i * 62), word, title, RED if i else INK, PARCHMENT, 2)
    tag = "Fold the map. Crush the siege."
    w = d.textlength(tag, font=sub)
    d.text(((350 - w) / 2, 168), tag, font=sub, fill=INK)
    d.line([60, 162, 290, 162], fill=GOLD, width=2)
    card = card.rotate(3, expand=True, resample=Image.BICUBIC)
    cs = Image.new("RGBA", card.size, (0, 0, 0, 0))
    ImageDraw.Draw(cs).rectangle([8, 8, card.width - 8, card.height - 8], fill=(0, 0, 0, 140))
    cs = cs.filter(ImageFilter.GaussianBlur(8))
    cover.paste(cs, (22, 48), cs)
    cover.paste(card, (14, 36), card)
    cover.save(os.path.join(out, "cover.png"))


def main():
    cap, out = sys.argv[1], sys.argv[2]
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    os.makedirs(out, exist_ok=True)
    make_gif(cap, out)
    make_cover(cap, out, root)
    picks = ["shot_3_aim", "shot_4_slam", "shot_6_torn", "shot_7_boss", "shot_1_build"]
    for i, n in enumerate(picks, 1):
        shutil.copy(os.path.join(cap, n + ".png"), os.path.join(out, "screenshot_%d.png" % i))
    print("wrote", out)


if __name__ == "__main__":
    main()
