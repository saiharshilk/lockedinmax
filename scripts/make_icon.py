#!/usr/bin/env python3
"""Generate the lockedinmax App Store icon variants (1024x1024, opaque sRGB PNG)."""
from pathlib import Path
from PIL import Image, ImageDraw

SIZE = 1024
BG = (0x1C, 0x18, 0x0D)
SURFACE = (0x26, 0x22, 0x1A)
ACCENT = (0xCC, 0xFF, 0x00)
OUT = Path(__file__).resolve().parents[1] / "lockedinmax/Assets.xcassets/AppIcon.appiconset"


def make_icon(background=BG, skyline=SURFACE, chart=ACCENT, filename="AppIcon.png"):
    image = Image.new("RGB", (SIZE, SIZE), background)
    draw = ImageDraw.Draw(image)

    # A restrained skyline along the lower third.
    buildings = [
        (0, 0.88), (0.06, 0.76), (0.12, 0.84), (0.18, 0.70),
        (0.24, 0.82), (0.31, 0.66), (0.38, 0.80), (0.45, 0.72),
        (0.52, 0.84), (0.59, 0.64), (0.66, 0.79), (0.73, 0.69),
        (0.80, 0.83), (0.87, 0.73), (0.93, 0.82), (1.0, 0.76),
    ]
    skyline_points = [(round(x * SIZE), round(y * SIZE)) for x, y in buildings]
    skyline_points.extend([(SIZE, SIZE), (0, SIZE)])
    draw.polygon(skyline_points, fill=skyline)

    # Chart stays within the center 80% icon safe zone; PIL's joint curve rounds joins.
    chart_points = [
        (round(0.17 * SIZE), round(0.64 * SIZE)),
        (round(0.34 * SIZE), round(0.55 * SIZE)),
        (round(0.47 * SIZE), round(0.58 * SIZE)),
        (round(0.63 * SIZE), round(0.43 * SIZE)),
        (round(0.81 * SIZE), round(0.34 * SIZE)),
    ]
    draw.line(chart_points, fill=chart, width=30, joint="curve")
    radius = 19
    x, y = chart_points[-1]
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=chart)
    image.save(OUT / filename, format="PNG", optimize=True)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    make_icon()
    # Dark appearance keeps the same restrained palette while lifting chart contrast.
    make_icon(background=(0x12, 0x10, 0x09), skyline=(0x20, 0x1C, 0x14), filename="AppIcon-dark.png")
    # Tinted appearance is monochrome on black as required by iOS tinted icons.
    make_icon(background=(0, 0, 0), skyline=(0x18, 0x18, 0x18), chart=(0xD8, 0xD8, 0xD8),
              filename="AppIcon-tinted.png")
    for filename in ("AppIcon.png", "AppIcon-dark.png", "AppIcon-tinted.png"):
        image = Image.open(OUT / filename)
        assert image.size == (1024, 1024) and image.mode == "RGB", (filename, image.size, image.mode)
        print(f"{OUT / filename}: {image.size}, {image.mode}")


if __name__ == "__main__":
    main()
