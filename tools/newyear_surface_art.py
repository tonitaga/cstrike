"""Read the RGB source artwork and keep its colors in a GoldSrc-friendly palette."""
from functools import lru_cache
from pathlib import Path
from struct import unpack_from
from zlib import decompress

MATERIALS = Path(__file__).with_name("newyear_materials")


def read_rgb_png(path):
    contents = path.read_bytes()
    width, height, depth, color, _, _, interlace = unpack_from(">IIBBBBB", contents, 16)
    if (contents[:8], depth, color, interlace) != (b"\x89PNG\r\n\x1a\n", 8, 2, 0):
        raise ValueError(f"Expected non-interlaced 8-bit RGB PNG: {path}")
    cursor, compressed = 8, bytearray()
    while cursor < len(contents):
        size, kind = unpack_from(">I4s", contents, cursor)
        if kind == b"IDAT":
            compressed.extend(contents[cursor+8:cursor+8+size])
        cursor += size+12
    raw = decompress(compressed)
    stride = width*3
    rows = []
    previous = bytearray(stride)
    for y in range(height):
        start = y*(stride+1)
        mode = raw[start]
        row = bytearray(raw[start+1:start+1+stride])
        for i in range(stride):
            left = row[i-3] if i>=3 else 0
            top = previous[i]
            diagonal = previous[i-3] if i>=3 else 0
            if mode == 1:
                prediction = left
            elif mode == 2:
                prediction = top
            elif mode == 3:
                prediction = (left+top)//2
            elif mode == 4:
                a, b, c = abs(top-diagonal), abs(left-diagonal), abs(left+top-2*diagonal)
                prediction = left if a<=b and a<=c else top if b<=c else diagonal
            elif mode == 0:
                prediction = 0
            else:
                raise ValueError(f"Unsupported PNG filter {mode}")
            row[i] = (row[i]+prediction)&255
        previous = row
        rows.append(row)
    return width, height, rows


def material_palette(samples, count):
    boxes = [samples]
    while len(boxes) < count:
        groups = []
        for entries in boxes:
            channel = max(range(3), key=lambda i:max(c[i] for c in entries)-min(c[i] for c in entries))
            ordered = sorted(entries,key=lambda c:c[channel])
            midpoint = len(ordered)//2
            groups.extend((ordered[:midpoint],ordered[midpoint:]))
        boxes = groups
    return [tuple(sum(color[i] for color in group)//len(group) for i in range(3)) for group in boxes]


@lru_cache(maxsize=7)
def artwork_sheet(weapon):
    return read_rgb_png(MATERIALS/f"{weapon}.png")


@lru_cache(maxsize=28)
def artwork(weapon, tier):
    width, height, rows = artwork_sheet(weapon)
    width, height = width//2, height//2
    x, y = tier%2*width, tier//2*height
    # Keep generated transitions between tiles out of the print.
    inset = 16
    return width-2*inset, height-2*inset, [
        row[3*(x+inset):3*(x+width-inset)] for row in rows[y+inset:y+height-inset]
    ]
