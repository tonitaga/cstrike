"""Build the INCOMSYSTEM winter collection from the checked-in GoldSrc models."""
from functools import lru_cache
from pathlib import Path
from struct import pack_into, unpack_from
from tempfile import NamedTemporaryFile
from time import sleep

from goldsrc_skin_geometry import print_projection, scale_texture_uvs
from newyear_surface_art import artwork, material_palette

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "cstrike/models"
OUTPUT = MODELS / "incom/newyear"
WEAPONS = ("m4a1", "ak47", "glock18", "deagle", "knife", "awp", "usp")
TIERS = ("common", "rare", "epic", "legendary")
INVERTED_PLAYER_MODELS = {"m4a1", "glock18", "deagle", "usp"}
BUTTERFLY = MODELS / "incom/knife/butterfly/crimson_web/v_knife.mdl"
PRINT_COLORS = 64


@lru_cache(maxsize=28)
def print_palette(weapon, tier):
    width,height,rows = artwork(weapon,tier)
    samples = [tuple(row[x:x+3]) for row in rows[::8] for x in range(0,3*width,24)]
    return material_palette(samples,PRINT_COLORS)


def nearest(color, palette):
    r,g,b = color
    return min(range(len(palette)), key=lambda i:(r-palette[i][0])**2
               +(g-palette[i][1])**2+(b-palette[i][2])**2)


def texture(data, old_palette, atlas_width, mapping, aspects, weapon, tier, protected):
    width,height,rows = artwork(weapon,tier)
    colors = print_palette(weapon,tier)
    lookup = {}
    u_map,v_map,state = mapping
    pixels = bytearray(len(data))
    exact = sorted({data[pos] for pos in protected})
    preserved = {value: index+len(colors) for index,value in enumerate(exact)}
    # One physical scale per view retains proportions and fills the entire face.
    projections = [(aspect,max(aspect/width,1/height)) for aspect in aspects]
    for pos,view in enumerate(state):
        if pos in protected:
            pixels[pos] = preserved[data[pos]]
            continue
        if view:
            aspect,scale = projections[view-1]
            x = (u_map[pos]-.5)*aspect
            y = v_map[pos]-.5
            col = min(width-1,max(0,int(width/2+x/scale)))
            row = rows[min(height-1,max(0,int(height/2+y/scale)))]
        else:
            # UVs of collapsed strips and unused padding still get a print color.
            col = (pos%atlas_width)*width//atlas_width
            row = rows[(pos//atlas_width)*height//(len(data)//atlas_width)]
        key = tuple(value//8 for value in row[3*col:3*col+3])
        index = lookup.get(key)
        if index is None:
            index = nearest(tuple(value*8+4 for value in key),colors)
            lookup[key] = index
        pixels[pos] = index

    palette = bytes(channel for color in colors for channel in color)
    palette += b"".join(old_palette[value*3:value*3+3] for value in exact)
    return pixels,palette.ljust(768,b"\0")


def texture_records(model):
    if model[:8] != b"IDST\x0a\x00\x00\x00":
        raise ValueError("Expected GoldSrc studio model v10")
    count, table = unpack_from("<2i", model, 180)
    for i in range(count):
        name, flags, w, h, offset = unpack_from("<64s4i", model, table + 80 * i)
        yield name.split(b"\0")[0].decode().lower(), flags, w, h, offset


def enlarge_atlases(source):
    """Upsample painted atlases up to the GoldSrc texture budget."""
    result = bytearray(source)
    _, table = unpack_from("<2i", source, 180)
    scales = {}
    for index, record in enumerate(texture_records(source)):
        _, _, width,height,offset = record
        factor = min(4, 512 // max(width,height))
        if not painted_texture(record) or factor < 2:
            continue
        end = offset+width*height
        expanded = bytearray()
        for row in range(height):
            start = offset+row*width
            line = bytes(pixel for value in source[start:start+width] for pixel in (value,)*factor)
            expanded.extend(line*factor)
        new_offset=len(result)
        result.extend(expanded + source[end:end+768])
        pack_into("<3i", result, table+80*index+68, width*factor,height*factor,new_offset)
        scales[index]=(factor,factor)
    scale_texture_uvs(result,scales)
    pack_into("<i", result,72,len(result))
    return bytes(result)


def visible_texture(record):
    name, flags, _, _, _ = record
    return not (name.startswith(("view_", "arm.", "gloves.")) or flags & 64 or "reticle" in name)


def painted_texture(record):
    # The glass and housing share one material on the stock first-person AWP.
    return visible_texture(record) and record[0] not in {"scope.bmp", "scope_clamps.bmp"}


@lru_cache(maxsize=16)
def paint_map(source, idle, inverted):
    records = tuple(texture_records(source))
    allowed = {i for i, record in enumerate(records) if painted_texture(record)}
    maps, aspect = print_projection(source, records, allowed, idle, inverted)
    return records, maps, aspect


def recolor(source, weapon, tier, prefix):
    result = bytearray(source)
    records, maps, aspect = paint_map(source, prefix == "v", prefix == "p" and weapon in INVERTED_PLAYER_MODELS)
    for index, mapping in maps.items():
        name, _, w, h, offset = records[index]
        end = offset+w*h
        protected = set()
        if prefix == "p" and weapon == "awp" and name == "w_awp.bmp":
            # Both lens caps share this island in the stock player atlas.
            sx,sy = w//256,h//64
            protected = {y*w+x for y in range(37*sy,54*sy) for x in range(117*sx,139*sx)}
        pixels,palette = texture(source[offset:end],source[end:end+768],w,mapping,aspect,
                                 "butterfly" if weapon=="knife" else weapon,tier,protected)
        result[offset:end+768] = pixels+palette
    return result


def checked_model(model):
    if unpack_from("<i", model, 72)[0] != len(model):
        raise ValueError("Incorrect declared MDL length")
    for name, _, w, h, off in texture_records(model):
        if not (w > 0 and h > 0 and off >= 244 and off + w*h + 768 <= len(model)):
            raise ValueError(f"Invalid texture {name}")
    return model


def write_model(path, model):
    with NamedTemporaryFile(dir=path.parent, prefix=path.stem, suffix=".tmp", delete=False) as output:
        pending = Path(output.name)
        output.write(model)
    try:
        for attempt in range(3):
            try:
                pending.replace(path)
                return
            except OSError:
                if attempt == 2:
                    raise
                sleep(.2)
    finally:
        pending.unlink(missing_ok=True)


def main():
    total = 0
    for weapon in WEAPONS:
        sources = (("v", BUTTERFLY),) if weapon == "knife" else (
            ("v", MODELS / f"v_{weapon}.mdl"), ("p", MODELS / f"p_{weapon}.mdl"))
        for prefix, source_path in sources:
            source = source_path.read_bytes()
            if weapon != "knife":
                source = enlarge_atlases(source)
            for tier, rarity in enumerate(TIERS):
                folder = OUTPUT / ("butterfly" if weapon == "knife" else weapon) / rarity
                folder.mkdir(parents=True, exist_ok=True)
                model = recolor(source, weapon, tier, prefix)
                write_model(folder / f"{prefix}_{weapon}_r5.mdl", checked_model(model))
                total += 1
    print(f"Built {total} models under {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
