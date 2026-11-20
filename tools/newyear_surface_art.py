"""Read the RGB source artwork and keep its colors in a GoldSrc-friendly palette."""
from functools import lru_cache
from pathlib import Path
from struct import unpack_from
from zlib import decompress

from goldsrc_skin_geometry import ART_HEIGHT, ART_WIDTH

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


def material_palette(samples):
    boxes = [samples]
    while len(boxes)<16:
        groups = []
        for entries in boxes:
            channel = max(range(3), key=lambda i:max(c[i] for c in entries)-min(c[i] for c in entries))
            ordered = sorted(entries,key=lambda c:c[channel])
            midpoint = len(ordered)//2
            groups.extend((ordered[:midpoint],ordered[midpoint:]))
        boxes = groups
    return [tuple(sum(color[i] for color in group)//len(group) for i in range(3)) for group in boxes]


@lru_cache(maxsize=4)
def artwork(rarity):
    width,height,rows = read_rgb_png(MATERIALS/f"{rarity}.png")
    colors = material_palette([tuple(row[x:x+3]) for row in rows[::12] for x in range(0,3*width,36)])
    lookup = {}
    for r in range(0,256,16):
        for g in range(0,256,16):
            for b in range(0,256,16):
                rgb = (r+8,g+8,b+8)
                index = min(range(len(colors)),key=lambda k:sum((a-c)**2 for a,c in zip(rgb,colors[k])))
                lookup[r>>4,g>>4,b>>4] = index
    surface = tuple(bytes(lookup[row[x]>>4,row[x+1]>>4,row[x+2]>>4] for x in range(0,3*width,3))
                    for row in rows)
    return width,height,colors,surface


@lru_cache(maxsize=16)
def projected_artwork(rarity, family):
    width,height,colors,surface = artwork(rarity)
    # Each pair shares the same field and scale so its ornaments occupy corresponding zones.
    crop_x,crop_y,span_x,span_y = (
        (48,52,1320,840), (220,90,1240,850), (80,160,1340,790), (164,210,1270,710)
    )[family]
    xs = [min(width-1, crop_x+x*span_x//(ART_WIDTH-1)) for x in range(ART_WIDTH)]
    plate = tuple(bytes(surface[min(height-1,crop_y+y*span_y//(ART_HEIGHT-1))][x] for x in xs)
                  for y in range(ART_HEIGHT))
    return colors,plate
