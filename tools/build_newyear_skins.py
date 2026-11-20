"""Build the INCOMSYSTEM winter collection from the checked-in GoldSrc models."""
from functools import lru_cache
from math import atan2, cos, hypot, pi, sin
from pathlib import Path
from struct import pack_into, unpack_from
from tempfile import NamedTemporaryFile
from time import sleep

from goldsrc_skin_geometry import ART_HEIGHT, ART_WIDTH, atlas_projection, scale_texture_uvs
from newyear_surface_art import projected_artwork

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "cstrike/models"
OUTPUT = MODELS / "incom/newyear"
WEAPONS = ("m4a1", "ak47", "glock18", "deagle", "knife", "awp", "usp")
TIERS = ("common", "rare", "epic", "legendary")
# Shared motifs and palettes for the three matching weapon pairs.
SERIES = {
    "ak47": (0, "ak47"), "deagle": (0, "ak47"),
    "m4a1": (1, "m4a1"), "usp": (1, "m4a1"),
    "glock18": (2, "glock18"), "awp": (2, "glock18"),
    "knife": (3, "knife"),
}
INVERTED_PLAYER_MODELS = {"m4a1", "glock18", "deagle", "usp"}
BUTTERFLY = MODELS / "incom/knife/butterfly/crimson_web/v_knife.mdl"
# Dark finish, festive paint, secondary ink and bright ornament.
PALETTES = {
    "m4a1": (
        ("193a31", "36654c", "a33139", "f4e1bc"), ("57212b", "a62e3b", "f0e2c7", "fff8dd"),
        ("132957", "3262a0", "79bdce", "f7e9b7"), ("77232e", "b53743", "277950", "ffdc84")),
    "ak47": (
        ("344138", "537957", "b64e3b", "fff0cd"), ("263a31", "397549", "c24a3f", "fff0bd"),
        ("2c2351", "573c94", "46b3ad", "f9dc84"), ("182b54", "3d805a", "f15c67", "ffe09a")),
    "glock18": (
        ("542a33", "833845", "ba5948", "fff4db"), ("6b242b", "b73539", "f0d5ad", "fff4d8"),
        ("25442d", "397c45", "c84645", "f5dca0"), ("43206e", "a93771", "47cbca", "ffda7f")),
    "deagle": (
        ("42322b", "785039", "ad4543", "f6dbac"), ("253349", "315d76", "c35e59", "ffe2a6"),
        ("602348", "ab4662", "43aa9d", "ffdda1"), ("533533", "9c6035", "d43d46", "fff19f")),
    "knife": (
        ("42262b", "733a40", "b84b43", "f9d99c"), ("52252e", "b43b47", "e6d1a5", "fff5d9"),
        ("203447", "3d6387", "55a7ab", "f5e1a7"), ("5b203e", "aa3b63", "36b9a4", "ffe384")),
    "awp": (
        ("203c3a", "35605a", "8ca793", "f2ead8"), ("3f3131", "b04745", "4e8559", "ffe1ab"),
        ("21335f", "4469a0", "c05f7a", "fce0a8"), ("212053", "524094", "44c6c4", "ffe19a")),
    "usp": (
        ("273b3d", "467372", "c64b46", "ffe4b6"), ("553529", "a36a43", "c65144", "ffeece"),
        ("383146", "69527d", "b74f65", "ffe4ad"), ("183b38", "317a66", "d94c4c", "ffe393")),
}


def rgb(value):
    return tuple(bytes.fromhex(value))


def snowflake(x, y, cx, cy, size):
    x, y = (x - cx) * 2, y - cy
    radius = hypot(x, y)
    angle = atan2(y, x)
    branch = abs(sin(angle * 3))
    return radius < size and (radius < .017 or branch < .027 / max(radius, .03)
                             or abs(radius - .66 * size) < .023 and branch < .52)


def pine(x, y, cx, base, size):
    height = (base-y)/size
    if .0 < height < 1:
        return abs(x-cx) < size*(.04 + (1-height)*.20 + (height*3 % 1)*.09)
    return -.12 < height <= 0 and abs(x-cx) < size*.045


def star(x, y, cx, cy, radius):
    px, py = (x-cx)*2, y-cy
    distance = hypot(px,py)
    return distance < radius*(.50 + .50*abs(cos(atan2(py,px)*2.5))**5)


def parcel(x, y, cx, cy, size):
    """Return a box, ribbon or bow in the parcel's local coordinates."""
    px, py = (x-cx)*1.8/size, (y-cy)/size
    if abs(px) < 1 and -.39 < py < .66:
        return 3 if abs(px)<.15 or -.27<py<-.12 else 2
    if abs(px)<1.08 and -.50 < py <= -.39:
        return 3 if abs(px)<.15 else 1
    if -.92 < py < -.48:
        loop = ((abs(px)-.28)/.29)**2 + ((py+.70)/.20)**2
        if .43 < loop < 1.15 or abs(px)<.15:
            return 3
    return 0


def firework(x, y, cx, cy, size):
    px, py = (x-cx)*1.9/size, (y-cy)/size
    distance = hypot(px,py)
    if distance < .13:
        return 3
    angle = atan2(py,px)
    ray = (angle*9/pi + .27*distance) % 1
    length = .74 + .18*cos(round(angle*9/pi)*3.7)
    if .23 < distance < length and min(ray,1-ray) < .12:
        return 3 if distance < .55 else 2
    if .82 < distance < 1.08 and .19 < ray < .29:
        return 3
    return 0


def bulb_chain(x, y, lower=False):
    cable = (.65 if lower else .30) + .13*sin(x*17)
    distance = y-cable
    if abs(distance)<.013:
        return 3
    phase = (x*13+.10) % 1 - .5
    if (phase/.16)**2 + ((distance-.067)/.063)**2<1:
        return 2 if int(x*13)%2 else 3
    return 0


# Motifs sit on the receiver, the slide or the handle, where they remain visible
# on the coarse player models. Fireworks and ribbons can continue across seams.
RECEIVER = {
    "m4a1": (.65, .36), "ak47": (.63, .31), "glock18": (.49, .31),
    "deagle": (.49, .31), "knife": (.76, .43), "awp": (.72, .59), "usp": (.65, .29),
}


def pattern(weapon, tier, x, y, part):
    cx, cy = RECEIVER[weapon]
    _, weapon = SERIES[weapon]
    ribbon = (x*5.5-y*1.65) % 1
    wave = sin(x*18 + y*3)
    tree = pine(x,y,cx,cy+.12,.28)
    if tier == 0:
        if weapon in ("ak47","awp"):
            if tree or pine(x,y,cx+.11,cy+.13,.19):
                return 3
            return 1 if y > cy+.06 else (2 if ribbon<.07 else 0)
        if weapon in ("knife","m4a1","usp"):
            if snowflake(x,y,cx,cy,.17) or snowflake(x,y,cx-.18,cy,.095):
                return 3
            return 2 if abs(y-cy-.018*wave)<.024 else int(y<cy+.11)
        if star(x,y,cx,cy,.14) or star(x,y,cx-.12,cy-.04,.08):
            return 3
        return 2 if .58<ribbon<.65 else int(y<cy+.15)

    if tier == 1:
        if weapon in ("knife","glock18","m4a1"):
            if weapon=="knife" and part=="blade":
                return 3 if snowflake(x,y,.31,.44,.18) else int(y>.45)
            return 3 if .12<ribbon<.43 else (2 if .43<=ribbon<.49 else 1)
        if weapon in ("ak47","awp"):
            if any(pine(x,y,cx+dx,cy+.13,size) for dx,size in ((-.10,.22),(.0,.35),(.11,.26))):
                return 3 if y<cy-.04 else 2
            if star(x,y,cx,cy-.19,.10):
                return 3
            return 1 if abs(y-cy-.16-.04*wave)<.06 else 0
        if weapon=="usp":
            if .30<y<.74 and (.13<ribbon<.23 or .54<ribbon<.63):
                return 3
            return 3 if snowflake(x,y,cx,cy,.14) else (2 if ribbon<.11 else int(y<.46))
        lamp = bulb_chain(x,y)
        return lamp or int(y<.29+.09*wave)

    if tier == 2:
        if weapon in ("m4a1","awp","knife"):
            crest = snowflake(x,y,cx,cy,.25) or snowflake(x,y,cx-.20,cy+.04,.14)
            if crest:
                return 3
            if abs(y-cy-.15*sin(x*26)) < .027 or star(x,y,cx-.30,cy,.08):
                return 2
            return int(abs(y-cy-.15*wave)<.21)
        if weapon in ("ak47","glock18","usp"):
            lights = bulb_chain(x,y) or bulb_chain(x,y,True)
            if lights:
                return lights
            if tree:
                return 2
            return int(y<.55+.13*wave)
        gift = parcel(x,y,cx,cy,.21)
        if gift:
            return gift
        return 3 if star(x,y,cx+.17,cy+.02,.09) else int(abs(y-cy-.11*wave)<.21)

    if weapon in ("m4a1","deagle"):
        gift = parcel(x,y,cx,cy,.22)
        if gift:
            return gift
        if star(x,y,cx-.18,cy,.10) or star(x,y,cx+.22,cy,.095):
            return 3
        crease = abs(y-cy-.06*sin(x*22))
        return 3 if crease<.028 else (2 if crease<.10 or .09<ribbon<.18 else 1)

    if weapon in ("ak47","awp"):
        burst = firework(x,y,cx,cy-.02,.23) or firework(x,y,cx-.21,cy+.01,.16)
        if burst:
            return burst
        if weapon=="ak47" and pine(x,y,cx+.18,cy+.23,.29):
            return 1 if y>cy+.09 else 3
        if star(x,y,cx+.19,cy-.11,.07):
            return 3
        return int(y>cy+.15+.04*wave)

    if weapon == "usp":
        ribbon_line = abs(y-cy-.13*sin(x*17))
        ornament = parcel(x,y,cx,cy,.15)
        if ornament:
            return ornament
        if star(x,y,cx-.22,cy,.10):
            return 3
        lights = bulb_chain(x,y) or bulb_chain(x,y,True)
        return lights or (3 if ribbon_line<.025 else int(ribbon_line<.12))

    # Pieces of foil and long curling streamers on the confetti skins.
    if weapon=="knife" and part=="blade":
        return firework(x,y,.28,.44,.21) or int(y<.56)
    for i, (dx,dy) in enumerate(((-.28,-.09),(-.18,.20),(-.12,-.15),(.04,.18),(.16,-.12),
                                 (.24,.13),(.28,-.13),(-.33,.16))):
        px, py = x-cx-dx, y-cy-dy
        if abs(px+.12*py)<.018 and abs(py-.62*px)<.029:
            return 2+i%2
    burst = firework(x,y,cx,cy,.22)
    if burst:
        return burst
    streamer = abs(y-cy-.14*sin(x*27))
    return 3 if streamer<.023 else (2 if streamer<.071 else int(.25<ribbon<.36))


# Four local colors and two transition colors per pair. Keeping all 16 groups
# in the palette allows smooth boundaries without giving up material shading.
COLOR_MIXES = [(i, i, 0) for i in range(4)]
COLOR_MIXES += [(a,b,1/3) for a in range(4) for b in range(4) if a != b]
COLOR_MIX_INDEX = {(a,b):i for i,(a,b,_) in enumerate(COLOR_MIXES)}


@lru_cache(maxsize=None)
def design(weapon, tier, part):
    xs = [x/(ART_WIDTH-1) for x in range(ART_WIDTH)]
    raw = [bytes(pattern(weapon, tier, x, y/(ART_HEIGHT-1), part) for x in xs)
           for y in range(ART_HEIGHT)]
    shaded = []
    for y,row in enumerate(raw):
        edge = bytearray(ART_WIDTH)
        above, below = raw[max(0,y-1)], raw[min(ART_HEIGHT-1,y+1)]
        for x, material in enumerate(row):
            left, right = row[max(0,x-1)], row[min(ART_WIDTH-1,x+1)]
            other = left if left != material else right
            if other == material:
                other = above[x] if above[x] != material else below[x]
            edge[x] = COLOR_MIX_INDEX[material,other]
        shaded.append(bytes(edge))
    return shaded


def texture(data, old_palette, width, weapon, tier, part, uv_map):
    family, motifs = SERIES[weapon]
    colors = tuple(map(rgb, PALETTES[motifs][tier]))
    artwork_tier = "rare" if tier == 3 and family == 1 else TIERS[tier]
    swatches, material = projected_artwork(artwork_tier, family)
    if weapon == "knife" and part == "blade":
        colors = tuple(map(rgb, ("677586", "899faa", "b2c9c8", "fff0cd")))
        if tier == 3:
            colors = tuple(map(rgb, ("342762", "536bbb", "65dfcd", "fff0b5")))
    palette = bytearray()
    # Keep engraved linework at every tier; only the foil tiers use full source color.
    material_light = [(r*3+g*6+b)//10 for r,g,b in swatches]
    dark, bright = min(material_light), max(material_light)
    contrast = (.16, .22, .33, .49)[tier]
    for ink, paint in enumerate(colors):
        for index, swatch in enumerate(swatches):
            luma = material_light[index]
            relief = ((luma-dark)/max(1,bright-dark)-.43)*contrast
            if tier == 3:
                weight = .73 if ink<2 else .41
                if weapon=="knife" and part=="blade":
                    weight *= .76
                combined = [tone*(1-weight)+source*weight for tone,source in zip(paint,swatch)]
            else:
                # Turn the artwork into tonal engraving and reserve color for the
                # localized holiday motifs painted on top of it.
                chroma = (.025, .045, .115)[tier]
                lift = 85 if tier==0 else 105 if tier==1 else 110
                combined = [value*(1+relief)+lift*relief+(source-luma)*chroma
                            for value,source in zip(paint,swatch)]
            for shade in range(4):
                light = .64 + .15*shade
                palette.extend(min(255,max(0,round(channel*light))) for channel in combined)

    luma = [(old_palette[i]*3+old_palette[i+1]*6+old_palette[i+2])//10
            for i in range(0,768,3)]
    peak = max(1,max(luma))
    shading = [value*11//peak + 3 for value in luma]
    art = design(weapon,tier,part if weapon=="knife" else "body")
    u_map,v_map,coverage = uv_map
    dither = (0,2,3,1)
    result = bytearray(len(data))
    for y in range(len(data)//width):
        for x in range(width):
            pos = y*width+x
            u,v = u_map[pos],v_map[pos]
            ink = art[v][u] if coverage[pos] else 0
            if ink >= 4:
                first, second, _ = COLOR_MIXES[ink]
                ink = second if (x+2*y)%3==0 else first
            source_ink = material[v][u] if coverage[pos] else 0
            shade = min(3,(shading[data[pos]]+dither[(y&1)*2+(x&1)])//4)
            result[pos] = ink*64+source_ink*4+shade
    return result,palette


def texture_records(model):
    if model[:8] != b"IDST\x0a\x00\x00\x00":
        raise ValueError("Expected GoldSrc studio model v10")
    count, table = unpack_from("<2i", model, 180)
    for i in range(count):
        name, flags, w, h, offset = unpack_from("<64s4i", model, table + 80 * i)
        yield name.split(b"\0")[0].decode().lower(), flags, w, h, offset


def enlarge_atlases(source, player=False):
    """Upsample painted atlases up to the GoldSrc texture budget."""
    result = bytearray(source)
    _, table = unpack_from("<2i", source, 180)
    scales = {}
    grayscale = bytes(i for shade in range(256) for i in (shade,)*3)
    for index, record in enumerate(texture_records(source)):
        _, _, width,height,offset = record
        factor = min(4 if player else 2, 512 // max(width,height))
        if not painted_texture(record) or factor < 2:
            continue
        end = offset+width*height
        palette = source[end:end+768]
        luma = [(palette[i]*3 + palette[i+1]*6 + palette[i+2])//10 for i in range(0,768,3)]
        raw = bytes(luma[pixel] for pixel in source[offset:end])
        # Upsample the baked lighting separately from the high-resolution new art.
        expanded = bytearray()
        inv_area = factor*factor
        for y in range(height*factor):
            row, fy = divmod(y,factor)
            upper, lower = row*width, min(row+1,height-1)*width
            for x in range(width*factor):
                col, fx = divmod(x,factor)
                right = min(col+1,width-1)
                a = raw[upper+col]*(factor-fx) + raw[upper+right]*fx
                b = raw[lower+col]*(factor-fx) + raw[lower+right]*fx
                expanded.append((a*(factor-fy)+b*fy)//inv_area)
        new_offset=len(result)
        result.extend(expanded + grayscale)
        pack_into("<3i", result, table+80*index+68, width*factor,height*factor,new_offset)
        scales[index]=(factor,factor)
    scale_texture_uvs(result,scales)
    pack_into("<i", result,72,len(result))
    return bytes(result)


def part_for(name):
    blade_parts = {f"part_{index}.bmp" for index in range(5, 14)}
    if name.startswith("blade") or name in blade_parts:
        return "blade"
    if any(word in name for word in ("handle", "stock", "forearm", "wood", "base")):
        return "grip"
    return "body"


def painted_texture(record):
    name, flags, _, _, _ = record
    return not (name.startswith(("view_", "arm.", "gloves.")) or flags & 64 or "reticle" in name)


@lru_cache(maxsize=16)
def paint_map(source, idle, inverted):
    records = tuple(texture_records(source))
    allowed = {i for i, record in enumerate(records) if painted_texture(record)}
    maps = atlas_projection(source, records, allowed, idle, inverted)
    return records, maps


def recolor(source, weapon, tier, prefix):
    result = bytearray(source)
    records, maps = paint_map(source, prefix == "v", prefix == "p" and weapon in INVERTED_PLAYER_MODELS)
    for index, mapping in maps.items():
        name, _, w, h, offset = records[index]
        end = offset + w * h
        pixels, palette = texture(source[offset:end], source[end:end+768], w,
                                  weapon, tier, "atlas" if prefix == "p" else part_for(name), mapping)
        result[offset:end+768] = pixels + palette
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
                source = enlarge_atlases(source, player=prefix == "p")
            for tier, rarity in enumerate(TIERS):
                folder = OUTPUT / ("butterfly" if weapon == "knife" else weapon) / rarity
                folder.mkdir(parents=True, exist_ok=True)
                model = recolor(source, weapon, tier, prefix)
                write_model(folder / f"{prefix}_{weapon}.mdl", checked_model(model))
                total += 1
    print(f"Built {total} models under {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
