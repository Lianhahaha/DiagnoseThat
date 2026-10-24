"""Generates the Midnight-branded Inno Setup wizard images.

Outputs PNGs next to Pulse.iss under branding/:
  wizard-image-<scale>.png        welcome / finish side panel
  wizard-small-image-<scale>.png  top-right mark on inner pages

Sizes follow Inno Setup's modern wizard (164x314 and 55x55 at 100 %), one file
per DPI scale so Setup can pick the sharpest. Colors and fonts come from the
app's Midnight theme (ADR-012) and bundled Geist font.

Usage:  python tools/installer/make_wizard_images.py
Requires Pillow.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = Path(__file__).resolve().parent / "branding"
FONTS = ROOT / "apps" / "pulse_app" / "assets" / "fonts"

# Midnight tokens (apps/pulse_app/lib/app/theme/pulse_theme.dart).
CANVAS = (8, 8, 10)
SURFACE = (17, 17, 20)
LIME = (200, 240, 74)
TEXT_PRIMARY = (244, 244, 245)
TEXT_SECONDARY = (161, 161, 170)
NEUTRAL_BAR = (46, 46, 52)
ERROR = (255, 107, 107)
WARNING = (255, 178, 36)

# Modern wizard image sizes at 100 % DPI.
SIDE_SIZE = (164, 314)
SMALL_SIZE = (55, 55)
SCALES = (100, 125, 150, 175, 200, 250)

# Pulse mark in its 32-unit viewBox (apps/pulse_app/assets/branding/mark.svg).
MARK_PEAK = [(4, 23), (10, 23), (14.5, 7), (19, 23), (28, 23)]
MARK_DOT = (14.5, 7)
MARK_DOT_RADIUS = 2.25
MARK_STROKE = 2.5

# Activity strip on the side panel: 0 = idle slice; colored slices mirror the
# Timeline overview (only problems get color).
ACTIVITY = [0, 1, 0, 0, 2, 0, 1, 0, 0, 3, 0, 0, 1, 0, 2, 0, 0, 4]
ACTIVITY_COLORS = {9: WARNING, 17: ERROR}

SUPERSAMPLE = 4


def draw_mark(draw, origin, size, color):
    """Draws the Pulse peak mark scaled to a size x size box at origin."""
    ox, oy = origin
    unit = size / 32
    points = [(ox + x * unit, oy + y * unit) for x, y in MARK_PEAK]
    width = max(1, round(MARK_STROKE * unit))
    draw.line(points, fill=color, width=width, joint="curve")
    for x, y in (points[0], points[-1]):
        draw.ellipse((x - width / 2, y - width / 2, x + width / 2, y + width / 2), fill=color)
    cx, cy = ox + MARK_DOT[0] * unit, oy + MARK_DOT[1] * unit
    r = MARK_DOT_RADIUS * unit
    draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=color)


def draw_tile(img, box, radius):
    """Lime rounded tile with the dark mark, like the app's icon rail."""
    draw = ImageDraw.Draw(img)
    draw.rounded_rectangle(box, radius=radius, fill=LIME)
    x0, y0, x1, y1 = box
    inset = (x1 - x0) * 0.2
    draw_mark(draw, (x0 + inset, y0 + inset), (x1 - x0) - 2 * inset, CANVAS)


def side_image(scale):
    w, h = (round(v * scale / 100) for v in SIDE_SIZE)
    s = SUPERSAMPLE
    img = Image.new("RGBA", (w * s, h * s), CANVAS + (255,))

    # Soft lime glow behind the tile.
    glow = Image.new("RGBA", img.size, (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    cx, cy, gr = w * s / 2, h * s * 0.36, w * s * 0.42
    gd.ellipse((cx - gr, cy - gr, cx + gr, cy + gr), fill=LIME + (46,))
    glow = glow.filter(ImageFilter.GaussianBlur(w * s * 0.16))
    img = Image.alpha_composite(img, glow)

    tile = w * s * 0.36
    tx, ty = (w * s - tile) / 2, h * s * 0.36 - tile / 2
    draw_tile(img, (tx, ty, tx + tile, ty + tile), radius=tile * 0.24)

    draw = ImageDraw.Draw(img)
    title_font = ImageFont.truetype(str(FONTS / "Geist-Bold.ttf"), round(w * s * 0.2))
    tag_font = ImageFont.truetype(str(FONTS / "Geist-Medium.ttf"), round(w * s * 0.068))
    draw.text((w * s / 2, h * s * 0.57), "Pulse", font=title_font, fill=TEXT_PRIMARY, anchor="mm")
    for i, line in enumerate(("See what Windows", "is really doing.")):
        draw.text(
            (w * s / 2, h * s * (0.65 + i * 0.045)),
            line,
            font=tag_font,
            fill=TEXT_SECONDARY,
            anchor="mm",
        )

    # Activity strip near the bottom.
    bars = len(ACTIVITY)
    margin = w * s * 0.14
    gap = w * s * 0.012
    bar_w = (w * s - 2 * margin - gap * (bars - 1)) / bars
    base = h * s * 0.9
    unit_h = h * s * 0.012
    for i, level in enumerate(ACTIVITY):
        x = margin + i * (bar_w + gap)
        height = max(unit_h * 0.6, level * unit_h * 1.6)
        color = ACTIVITY_COLORS.get(i)
        fill = color if color else NEUTRAL_BAR
        draw.rounded_rectangle((x, base - height, x + bar_w, base), radius=bar_w * 0.25, fill=fill)

    return img.resize((w, h), Image.LANCZOS).convert("RGB")


def small_image(scale):
    w, h = (round(v * scale / 100) for v in SMALL_SIZE)
    s = SUPERSAMPLE
    img = Image.new("RGBA", (w * s, h * s), CANVAS + (255,))
    pad = w * s * 0.06
    draw_tile(img, (pad, pad, w * s - pad, h * s - pad), radius=w * s * 0.22)
    return img.resize((w, h), Image.LANCZOS).convert("RGB")


def main():
    OUT_DIR.mkdir(exist_ok=True)
    for scale in SCALES:
        side_image(scale).save(OUT_DIR / f"wizard-image-{scale}.png", optimize=True)
        small_image(scale).save(OUT_DIR / f"wizard-small-image-{scale}.png", optimize=True)
    print(f"Wrote {len(SCALES) * 2} images to {OUT_DIR}")


if __name__ == "__main__":
    main()
