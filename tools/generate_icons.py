"""Renders every platform icon from assets/branding/mooshrevolt_icon.svg.

Run from the repository root:

    uv run --with cairosvg --with pillow tools/generate_icons.py

cairosvg needs the Cairo library (macOS: `brew install cairo`; Debian/Ubuntu:
`apt install libcairo2`). On macOS with Homebrew, expose it to Python with
`DYLD_FALLBACK_LIBRARY_PATH=/opt/homebrew/lib`.
"""

import io
from pathlib import Path

import cairosvg
from PIL import Image, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/branding/mooshrevolt_icon.svg"

# The SVG is drawn on Apple's 824 px icon body; the 1024 px icon grid adds a
# 100 px margin that holds the drop shadow.
CANVAS = 1024
BODY = 824


def render(size: int) -> Image.Image:
    """The icon body (rounded tile, transparent corners) at [size] px."""
    png = cairosvg.svg2png(
        url=str(SOURCE), output_width=size, output_height=size
    )
    return Image.open(io.BytesIO(png)).convert("RGBA")


def on_grid(scale: float = 1.0) -> Image.Image:
    """The body on the 1024 px macOS grid with Apple's soft drop shadow."""
    body = render(BODY)
    offset = (CANVAS - BODY) // 2
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    alpha = body.getchannel("A").point(lambda a: a * 90 // 255)
    shadow.paste((0, 0, 0, 255), (offset, offset + 12), alpha)
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    canvas.alpha_composite(body, (offset, offset))
    return canvas


def save(image: Image.Image, path: Path, size: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.resize((size, size), Image.LANCZOS).save(path)
    print(f"  {path.relative_to(ROOT)} ({size} px)")


def maskable(size: int) -> Image.Image:
    """Full-bleed square for maskable web icons: the content stays inside
    the 80% safe zone, the corners are the tile's own background."""
    image = Image.new("RGBA", (size, size), (21, 28, 38, 255))
    inner = render(int(size * 0.8))
    image.alpha_composite(inner, ((size - inner.width) // 2,) * 2)
    return image


def main() -> None:
    grid = on_grid()
    body = render(1024)

    print("macOS")
    for size in (16, 32, 64, 128, 256, 512, 1024):
        save(grid, ROOT / f"macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_{size}.png", size)

    print("Linux (also used by the Flatpak)")
    for size in (48, 64, 128, 256):
        save(grid, ROOT / f"linux/assets/icons/hicolor/{size}x{size}/apps/ca.richyoung.mooshrevolt.png", size)

    print("Android")
    for density, size in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        save(body, ROOT / f"android/app/src/main/res/mipmap-{density}/ic_launcher.png", size)

    print("Web")
    save(body, ROOT / "web/favicon.png", 16)
    for size in (192, 512):
        save(body, ROOT / f"web/icons/Icon-{size}.png", size)
        path = ROOT / f"web/icons/Icon-maskable-{size}.png"
        maskable(size).save(path)
        print(f"  {path.relative_to(ROOT)} ({size} px, maskable)")

    print("Windows")
    ico = ROOT / "windows/runner/resources/app_icon.ico"
    grid.save(ico, sizes=[(s, s) for s in (16, 24, 32, 48, 64, 128, 256)])
    print(f"  {ico.relative_to(ROOT)}")

    print("In-app logo")
    save(body, ROOT / "assets/images/mooshrevolt_mark.png", 512)


if __name__ == "__main__":
    main()
