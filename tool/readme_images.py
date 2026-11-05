"""Makes the README screenshots in docs/images from the store screenshots.

  flutter test --update-goldens tool/screenshots   # or take them from CI
  python3 tool/readme_images.py                    # needs Pillow

Each image is a Google Play screenshot at half size with rounded corners and a
thin edge, so it reads well on GitHub's light and dark pages.
"""
import pathlib
import sys

from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'tool' / 'screenshots' / 'out' / 'play'
OUT = ROOT / 'docs' / 'images'

# (language, screenshot, file name in docs/images)
SHOTS = [
    ('en', '1_today', 'today'),
    ('en', '2_contractions', 'contractions'),
    ('en', '3_movements', 'movements'),
    ('en', '6_history', 'history'),
    ('en', '4_tools', 'tools'),
    ('en', '5_bag', 'bag'),
    ('en', '7_numbers', 'numbers'),
    ('nb', '1_today', 'today-nb'),
]

WIDTH = 540
RADIUS = 36
EDGE = (120, 100, 90, 70)  # warm grey, partly transparent
SCALE = 4  # draw the corners large, then shrink, for smooth edges


def framed(path):
    shot = Image.open(path).convert('RGBA')
    height = round(shot.height * WIDTH / shot.width)
    shot = shot.resize((WIDTH, height), Image.LANCZOS)

    big = (WIDTH * SCALE, height * SCALE)
    mask = Image.new('L', big, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, big[0] - 1, big[1] - 1), RADIUS * SCALE, fill=255)
    mask = mask.resize((WIDTH, height), Image.LANCZOS)

    edge = Image.new('RGBA', big, (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle((0, 0, big[0] - 1, big[1] - 1), RADIUS * SCALE, outline=EDGE, width=2 * SCALE)
    edge = edge.resize((WIDTH, height), Image.LANCZOS)

    out = Image.new('RGBA', (WIDTH, height), (0, 0, 0, 0))
    out.paste(shot, (0, 0), mask)
    return Image.alpha_composite(out, edge)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for lang, name, target in SHOTS:
        src = SOURCE / lang / f'{name}.png'
        if not src.exists():
            sys.exit(f'Missing {src}. Make the store screenshots first.')
        framed(src).save(OUT / f'{target}.png', optimize=True)
        print(f'docs/images/{target}.png')


if __name__ == '__main__':
    main()
