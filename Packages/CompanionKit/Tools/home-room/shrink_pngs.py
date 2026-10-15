"""Shrinks the rendered room PNGs to 256-colour palettes with libimagequant, about five times smaller.

Issue #485. render_room.py calls this after rendering; it can also run alone:
    python shrink_pngs.py DIR [name ...]
Needs `pip install imagequant pillow`.
"""

import os
import sys

import imagequant
from PIL import Image


def shrink(path):
    image = Image.open(path).convert("RGBA")
    small = imagequant.quantize_pil_image(image, dithering_level=1.0, max_colors=256, min_quality=70, max_quality=95)
    small.save(path, optimize=True)


def main():
    folder = sys.argv[1]
    names = sys.argv[2:] or sorted(n for n in os.listdir(folder) if n.startswith("home-") and n.endswith(".png"))
    for name in names:
        shrink(os.path.join(folder, name))
        print(f"shrank {name}", flush=True)


if __name__ == "__main__":
    main()
