"""Renders Littlebrook's cottages, the windmill and its sails as small illustrated map sprites.

Coordinates are in map units (the map is 360x640 units); every sprite is drawn supersampled and
saved at OUT px per unit. decor.gd / ambient.gd place them with the offsets printed at the end.
Run: python tools/draw_hamlet.py
"""
import math
import random
from PIL import Image, ImageDraw, ImageFilter

OUT = 4          # px per map unit in the saved sprite
SS = 4           # supersampling factor on top of OUT
S = OUT * SS
DEST = "assets/sprites/terrain/"

INK = (58, 42, 28)
TIMBER = (84, 56, 34)
PLASTER = (241, 228, 197)
PLASTER_SHADE = (196, 176, 136)
STONE = (205, 190, 160)
STONE_SHADE = (150, 131, 100)
TILE = (170, 66, 52)
TILE_DARK = (122, 42, 34)
THATCH = (205, 164, 88)
THATCH_DARK = (150, 110, 52)
GLOW = (246, 196, 92)
GRASS = (142, 159, 92)


class Canvas:
    def __init__(self, left, top, w, h):
        self.left, self.top, self.w, self.h = left, top, w, h
        self.img = Image.new("RGBA", (int(w * S), int(h * S)), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def p(self, pt):
        return ((pt[0] - self.left) * S, (pt[1] - self.top) * S)

    def poly(self, pts, fill=None, outline=INK, width=0.42):
        q = [self.p(pt) for pt in pts]
        if fill:
            self.d.polygon(q, fill=fill)
        if outline and width > 0:
            self.d.line(q + [q[0]], fill=outline, width=max(1, int(width * S)), joint="curve")

    def line(self, a, b, color=INK, width=0.35):
        self.d.line([self.p(a), self.p(b)], fill=color, width=max(1, int(width * S)))

    def ellipse(self, c, rx, ry, fill=None, outline=None, width=0.35):
        x, y = self.p(c)
        self.d.ellipse([x - rx * S, y - ry * S, x + rx * S, y + ry * S], fill=fill, outline=outline,
                       width=max(1, int(width * S)) if outline else 0)

    def save(self, name):
        out = self.img.resize((int(self.w * OUT), int(self.h * OUT)), Image.LANCZOS)
        out.save(DEST + name)
        print(f"{name}: rect offset ({self.left}, {self.top}) size ({self.w}, {self.h})")


def shadow(c, pts, blur=0.9, alpha=70):
    """Soft cast shadow (light from the upper left) blurred onto its own layer."""
    layer = Image.new("RGBA", c.img.size, (0, 0, 0, 0))
    ImageDraw.Draw(layer).polygon([c.p(pt) for pt in pts], fill=INK + (alpha,))
    layer = layer.filter(ImageFilter.GaussianBlur(blur * S))
    c.img.alpha_composite(layer)


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def mix(c1, c2, t):
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3))


def quad_rows(c, a, b, top_a, top_b, rows, color, width=0.22):
    """Lines across a quad (a-b bottom edge, top_a-top_b top edge), e.g. roof tile courses."""
    for i in range(1, rows):
        t = i / rows
        c.line(lerp(a, top_a, t), lerp(b, top_b, t), color, width)


def cottage(name, width, roof, windows, seed):
    rnd = random.Random(seed)
    depth = (3.2, -1.9)       # oblique receding direction of the gable end
    wall_h = 5.6
    rise = 5.2                # ridge height above the eaves
    left = -width / 2
    right = width / 2
    c = Canvas(-9, -18, 20, 21)
    A, B = (left, 0.0), (right, 0.0)
    C, D = (right, -wall_h), (left, -wall_h)
    Bd = (B[0] + depth[0], B[1] + depth[1])
    Cd = (C[0] + depth[0], C[1] + depth[1])
    apex = (right + depth[0] / 2, -wall_h + depth[1] / 2 - rise)
    ridge_l = (left + depth[0] / 2, apex[1])
    shadow(c, [A, B, Bd, (Bd[0] + 4.5, Bd[1] + 1.2), (B[0] + 4.2, 1.6), (left + 1.0, 1.4)])
    # gable end (in shade) and front wall (lit)
    c.poly([B, Bd, Cd, apex, C], fill=PLASTER_SHADE)
    c.poly([A, B, C, D], fill=PLASTER)
    # timber framing on the front wall
    for x in [left + 0.25, right - 0.25] + [left + width * k / 3 for k in (1, 2)]:
        c.line((x, -0.1), (x, -wall_h + 0.1), TIMBER, 0.55)
    c.line((left, -wall_h * 0.5), (right, -wall_h * 0.5), TIMBER, 0.45)
    third = width / 3
    c.line((left + 0.3, -wall_h * 0.5), (left + third, -wall_h + 0.2), TIMBER, 0.4)
    c.line((right - 0.3, -wall_h * 0.5), (right - third, -wall_h + 0.2), TIMBER, 0.4)
    # gable timbers
    c.line(lerp(B, Bd, 0.5), lerp(C, Cd, 0.5), TIMBER, 0.4)
    c.line(C, Cd, TIMBER, 0.4)
    # door and windows
    dx = left + third * 1.5 - 0.9
    c.poly([(dx, 0), (dx + 1.8, 0), (dx + 1.8, -2.9), (dx + 0.9, -3.5), (dx, -2.9)], fill=(92, 58, 34), width=0.3)
    for wx in windows:
        x = left + wx * width
        c.poly([(x - 0.8, -2.2), (x + 0.8, -2.2), (x + 0.8, -3.8), (x - 0.8, -3.8)], fill=GLOW, width=0.3)
        c.line((x, -2.2), (x, -3.8), TIMBER, 0.22)
        c.line((x - 0.8, -3.0), (x + 0.8, -3.0), TIMBER, 0.22)
    gw = lerp(lerp(B, Bd, 0.5), lerp(C, Cd, 0.5), 0.55)
    c.poly([(gw[0] - 0.55, gw[1] + 0.8), (gw[0] + 0.55, gw[1] + 0.45), (gw[0] + 0.55, gw[1] - 0.8),
            (gw[0] - 0.55, gw[1] - 0.45)], fill=mix(GLOW, PLASTER_SHADE, 0.35), width=0.25)
    # chimney behind the ridge on the left
    cx = left + width * 0.22
    chim_top = apex[1] - 2.6
    base_y = apex[1] + 1.6
    c.poly([(cx, base_y), (cx + 1.6, base_y), (cx + 1.6, chim_top), (cx, chim_top)], fill=STONE)
    c.poly([(cx + 1.6, base_y), (cx + 2.3, base_y - 0.4), (cx + 2.3, chim_top - 0.4), (cx + 1.6, chim_top)], fill=STONE_SHADE)
    c.poly([(cx - 0.2, chim_top), (cx + 1.8, chim_top), (cx + 2.5, chim_top - 0.45), (cx + 0.5, chim_top - 0.45)], fill=STONE_SHADE)
    # roof: front slope with overhang, gable barge line
    o = 0.7
    eave_l, eave_r = (left - o, -wall_h + 0.6), (right + o * 0.4, -wall_h + 0.6)
    ridge_r = (apex[0] + 0.5, apex[1])
    ridge_ll = (ridge_l[0] - o, ridge_l[1])
    base, dark = (THATCH, THATCH_DARK) if roof == "thatch" else (TILE, TILE_DARK)
    c.poly([eave_l, eave_r, ridge_r, ridge_ll], fill=base, width=0.45)
    if roof == "thatch":
        for _ in range(int(width * 9)):
            t = rnd.random()
            s = rnd.uniform(0.15, 0.9)
            a = lerp(lerp(eave_l, ridge_ll, s), lerp(eave_r, ridge_r, s), t)
            c.line(a, (a[0] + 0.25, a[1] + rnd.uniform(0.7, 1.3)), dark, 0.16)
        c.line(ridge_ll, ridge_r, dark, 0.7)
    else:
        quad_rows(c, eave_l, eave_r, ridge_ll, ridge_r, 5, dark, 0.2)
        for k in range(int(width * 1.4)):
            row = k % 5
            t0, t1 = row / 5, (row + 1) / 5
            x = (k * 0.93 + row * 0.45) % (width + 1.0)
            a = lerp(lerp(eave_l, ridge_ll, t0), lerp(eave_r, ridge_r, t0), x / (width + 1.0))
            b = lerp(lerp(eave_l, ridge_ll, t1), lerp(eave_r, ridge_r, t1), x / (width + 1.0))
            c.line(a, b, dark, 0.14)
        c.line(ridge_ll, ridge_r, TILE_DARK, 0.6)
    # light catching the lower edge of the roof
    c.line((eave_l[0] + 0.4, eave_l[1] - 0.25), (eave_r[0] - 0.4, eave_r[1] - 0.25), mix(base, (255, 245, 220), 0.35), 0.3)
    c.line(eave_r, ridge_r, INK, 0.45)
    c.line(ridge_r, (Cd[0] + 0.35, Cd[1] + 0.35), INK, 0.5)
    c.save(name)
    return (cx + 0.8, chim_top - 0.3)


def windmill():
    c = Canvas(-11, -24, 26, 28)
    shadow(c, [(-5, 0), (5, 0), (12, 2.5), (9, 3.4), (-3, 2.6)], 1.1, 80)
    # grassy mound
    c.ellipse((0, 0.6), 9.5, 2.6, fill=mix(GRASS, (234, 217, 176), 0.4), outline=mix(GRASS, INK, 0.45), width=0.35)
    bottom, top, h = 5.0, 3.1, 16.0
    # tapered stone tower: lit left half, shaded right half, coursed stonework
    rnd = random.Random(9)
    c.poly([(-bottom, 0), (bottom, 0), (top, -h), (-top, -h)], fill=STONE, width=0)
    c.poly([(bottom * 0.25, 0), (bottom, 0), (top, -h), (top * 0.25, -h)], fill=STONE_SHADE, width=0)
    rows = 11
    for i in range(1, rows + 1):
        y0, y1 = -h * (i - 1) / rows, -h * i / rows
        w = bottom + (top - bottom) * (i - 0.5) / rows
        if i < rows:
            c.line((-w, y1), (w, y1), mix(STONE_SHADE, INK, 0.35), 0.16)
        x = -w + rnd.uniform(0.6, 1.8)
        while x < w - 0.5:
            c.line((x, y0), (x, y1), mix(STONE_SHADE, INK, 0.35), 0.14)
            x += rnd.uniform(1.6, 2.6)
    c.poly([(-bottom, 0), (bottom, 0), (top, -h), (-top, -h)], width=0.45)
    # gallery half way up
    gy = -7.5
    gw = bottom + (top - bottom) * (7.5 / h)
    c.poly([(-gw - 1.6, gy), (gw + 1.6, gy), (gw + 1.2, gy + 0.7), (-gw - 1.2, gy + 0.7)], fill=TIMBER, width=0.3)
    c.line((-gw - 1.5, gy - 1.6), (gw + 1.5, gy - 1.6), TIMBER, 0.3)
    for k in range(9):
        x = -gw - 1.5 + (2 * gw + 3.0) * k / 8
        c.line((x, gy), (x, gy - 1.6), TIMBER, 0.2)
    # door, window
    c.poly([(-1.1, 0), (1.1, 0), (1.1, -2.8), (0, -3.6), (-1.1, -2.8)], fill=(92, 58, 34), width=0.3)
    c.poly([(-0.7, -11.2), (0.7, -11.2), (0.7, -12.8), (-0.7, -12.8)], fill=GLOW, width=0.28)
    # cap: an ogee-ish boat cap in dark shingles
    cap = [(-top - 0.9, -h + 0.3), (top + 0.9, -h + 0.3), (top + 0.4, -h - 2.4), (1.2, -h - 4.3), (0, -h - 5.0),
           (-1.2, -h - 4.3), (-top - 0.4, -h - 2.4)]
    c.poly(cap, fill=TILE)
    c.poly([(0.4, -h + 0.3), (top + 0.9, -h + 0.3), (top + 0.4, -h - 2.4), (1.2, -h - 4.3), (0.4, -h - 4.8)],
           fill=TILE_DARK, width=0)
    for y in (-h - 1.0, -h - 2.4, -h - 3.6):
        c.line((-top, y), (top, y), TILE_DARK, 0.18)
    c.poly(cap, width=0.45)
    c.ellipse((0, -h - 5.3), 0.45, 0.45, fill=INK)
    # the windshaft boss the sails turn on (sails drawn separately)
    c.ellipse((0, -h - 1.6), 1.2, 1.2, fill=TIMBER, outline=INK, width=0.3)
    c.save("windmill.png")
    return (0, -h - 1.6)


def sails():
    R = 13.0
    c = Canvas(-R - 1, -R - 1, 2 * R + 2, 2 * R + 2)
    cloth = (243, 234, 210, 235)
    for k in range(4):
        a = k * math.pi / 2
        d = (math.cos(a), math.sin(a))
        n = (-d[1], d[0])
        at = lambda r, s: (d[0] * r + n[0] * s, d[1] * r + n[1] * s)
        c.poly([at(3.2, 0.5), at(R, 0.5), at(R, 3.6), at(3.2, 3.3)], fill=cloth, width=0)
        # lattice: sail bars across and the hemlath along the outer edge
        for i in range(8):
            r = 3.2 + (R - 3.2) * i / 7
            c.line(at(r, 0.4), at(r, 3.4 + 0.3 * i / 7), TIMBER, 0.2)
        c.line(at(3.2, 1.9), at(R, 2.05), mix(TIMBER, (243, 234, 210), 0.4), 0.14)
        c.line(at(3.2, 3.3), at(R, 3.6), TIMBER, 0.28)
        c.line(at(0, 0), at(R + 0.4, 0), INK, 0.5)   # the stock
    c.ellipse((0, 0), 1.1, 1.1, fill=(177, 135, 60), outline=INK, width=0.28)
    c.save("windmill_sails.png")


if __name__ == "__main__":
    tops = [cottage("cottage_a.png", 9.0, "thatch", [0.2, 0.8], 1),
            cottage("cottage_b.png", 8.0, "tile", [0.78], 2),
            cottage("cottage_c.png", 10.0, "tile", [0.18, 0.82], 3)]
    print("chimney tops:", [tuple(round(v, 2) for v in t) for t in tops])
    print("sail hub:", windmill())
    sails()
