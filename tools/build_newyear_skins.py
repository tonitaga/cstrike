"""Build the INCOMSYSTEM winter collection from the checked-in GoldSrc models."""
from functools import lru_cache
from pathlib import Path
from struct import pack, pack_into, unpack_from
from tempfile import NamedTemporaryFile
from time import sleep

from goldsrc_skin_geometry import print_projection, scale_texture_uvs, studio_meshes
from newyear_surface_art import artwork, material_palette

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "cstrike/models"
OUTPUT = MODELS / "incom/newyear"
WEAPONS = ("m4a1", "ak47", "glock18", "deagle", "knife", "awp", "usp")
TIERS = ("common", "rare", "epic", "legendary")
VARIANT_TIERS = (0, 0, 0, 1, 1, 1, 2, 2, 3)
INVERTED_PLAYER_MODELS = {"m4a1", "glock18", "deagle", "usp"}
BUTTERFLY = MODELS / "incom/knife/butterfly/crimson_web/v_knife.mdl"
KNIFE_FAMILIES = (
    ("butterfly", BUTTERFLY, 4, 4),
    ("skeleton", MODELS / "incom/knife/skeleton/case_hardened/v_knife.mdl", 8, 8),
    ("karambit", MODELS / "incom/knife/karambit/doppler_emerald_v2/v_knife.mdl", 16, 8),
)
BAYONET_FAMILY = ("bayonet", MODELS / "incom/knife/bayonet/chang_specialist/v_knife.mdl", 24, 8)
PRINT_COLORS = 128
LIGHT_LEVELS = (.78, .93, 1.05, 1.17, 1.29)
# Side-panel anchors avoid the support hand.
# Height is measured in physical model height; width follows the artwork aspect.
MOTIF_PLACEMENT = {
    "m4a1": (.61, .33, .29),
    "ak47": (.60, .23, .26),
    "glock18": (.37, .36, .24),
    "deagle": (.32, .23, .24),
    "awp": (.65, .51, .25),
    "usp": (.68, .21, .23),
}


def model_filename(prefix, weapon, variant=0, *, tier=None):
    if variant:
        revision = "f"
        if variant == 9 and weapon in {"glock18", "awp"}:
            revision = "g"
        if variant == 9 and weapon == "ak47":
            revision = "h"
        suffix = f"n{variant:02}{revision}"
    else:
        suffix = "r11a4" if weapon == "knife" else "r13"
        if tier == 3 and weapon == "deagle":
            suffix = "r14"
        if tier == 3 and weapon == "knife":
            suffix = "r15a4"
    if prefix == "p":
        suffix += "p2" if weapon == "awp" else "p"
    return f"{prefix}_{weapon}_{suffix}.mdl"


@lru_cache(maxsize=82)
def print_palette(weapon, tier):
    width,height,rows = artwork(weapon,tier)
    samples = [tone(row[x:x+3], light) for row in rows[::12]
               for x in range(0,3*width,36) for light in LIGHT_LEVELS]
    return material_palette(samples,PRINT_COLORS)


def tone(rgb, light):
    # Use a soft highlight shoulder so bright painted details retain their shape.
    return tuple(min(255, round(value*light if light <= 1 else
                               value+(255-value)*value/255*(light-1))) for value in rgb)


def rarity_finish(color, rarity):
    """Grade indexed paint colors while retaining the source illustration."""
    r,g,b = color
    luma = (.26*r+.60*g+.14*b)/255
    chroma, contrast, lift = (
        (.79,.86,.035), (1.02,1.00,.010), (1.16,1.11,.018), (1.24,1.23,.025)
    )[rarity]
    value = (luma-.5)*contrast+.5+lift
    # Broaden bright details on the highest tiers without tinting their shadows.
    highlight = max(0.0, (luma-.55)/.45)**2
    glint = ((0,0,0),(0,0,0),(3,8,15),(26,18,7))[rarity]
    return tuple(max(0,min(255,round(value*255+(channel-luma*255)*chroma+highlight*glint[i])))
                 for i,channel in enumerate(color))


def nearest(color, palette):
    r,g,b = color
    return min(range(len(palette)), key=lambda i:(r-palette[i][0])**2
               +(g-palette[i][1])**2+(b-palette[i][2])**2)


def texture(data, old_palette, atlas_width, mapping, aspects, weapon, tier, protected, *, player=False, rarity=None):
    width,height,rows = artwork(weapon,tier)
    print_colors = print_palette(weapon,tier)
    lookup = {}
    u_map,v_map,state,lighting = mapping
    stock_luma = [(old_palette[i]*3+old_palette[i+1]*6+old_palette[i+2]) / 2550
                  for i in range(0,768,3)]
    used_luma = sorted({stock_luma[value] for value in data})
    low = used_luma[len(used_luma)//10]
    high = used_luma[len(used_luma)*9//10]
    relief = [max(0.0,min(1.0,(value-low)/max(.18,high-low))) for value in stock_luma]
    pixels = bytearray(len(data))
    motif = MOTIF_PLACEMENT.get(weapon) if tier >= 4 and not player else None
    if motif:
        cx,cy,diameter = motif
        motif_width = diameter*width/height
    exact = sorted({data[pos] for pos in protected})
    preserved = {value: index+len(print_colors) for index,value in enumerate(exact)}
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
        rgb = row[3*col:3*col+3]
        if view == 3 and motif:
            # Fit the main artwork on one panel, independently of total weapon length.
            mx = (u_map[pos]-cx)*aspects[-1]/motif_width+.5
            my = (v_map[pos]-cy)/diameter+.5
            if 0 < mx < 1 and 0 < my < 1:
                edge = min(mx,my,1-mx,1-my)
                mark = 3*int(mx*width)
                detail = rows[int(my*height)][mark:mark+3]
                opacity = min(1.0, edge*10)
                rgb = tuple(round(a+(b-a)*opacity) for a,b in zip(rgb,detail))
        # Keep depth baked into the old material without bringing back its color.
        surface_height = v_map[pos] if view else .5
        facing = lighting[pos]/255
        light = .68 + .35*facing + .25*relief[data[pos]] + .095*(1-surface_height)
        key = tuple(value//4 for value in tone(rgb, light))
        index = lookup.get(key)
        if index is None:
            index = nearest(tuple(value*4+2 for value in key),print_colors)
            lookup[key] = index
        pixels[pos] = index

    if len(print_colors) + len(exact) > 256:
        raise ValueError("Indexed texture palette exceeds 256 colors")
    if rarity is None:
        rarity = tier if tier < len(TIERS) else VARIANT_TIERS[tier-len(TIERS)]
    painted_colors = [rarity_finish(color,rarity) for color in print_colors]
    palette = bytes(channel for color in painted_colors for channel in color)
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
    return not (name.startswith(("view_", "arm.", "gloves.")) or name.endswith("_arm.bmp")
                or "_glove_" in name or flags & 64 or "reticle" in name)


def painted_texture(record):
    # The glass and housing share one material on the stock first-person AWP.
    return visible_texture(record) and record[0] not in {"scope.bmp", "scope_clamps.bmp", "awp_scope_stock.bmp"}


@lru_cache(maxsize=16)
def paint_map(source, idle, inverted, player):
    records = tuple(texture_records(source))
    allowed = {i for i, record in enumerate(records) if painted_texture(record)}
    maps, aspect = print_projection(source, records, allowed, idle, inverted, continuous=player)
    return records, maps, aspect


@lru_cache(maxsize=1)
def isolate_player_awp_scope(source):
    """Split the stock AWP mesh so its optic can keep its own texture and palette."""
    record, = texture_records(source)
    name, flags, width, height, offset = record
    _, _, cursor, *_ = next(studio_meshes(source))
    skin_count, families, _, body_count, body_offset = unpack_from("<5i", source, 192)
    if (name, width, height, skin_count, families, body_count) != ("w_awp.bmp", 512, 128, 1, 1, 1):
        raise ValueError("Unexpected stock AWP player model")
    variants, _, model = unpack_from("<3i", source, body_offset+64)
    mesh_count, mesh = unpack_from("<2i", source, model+72)
    if variants != 1 or mesh_count != 1:
        raise ValueError("Expected a single stock AWP player mesh")

    command_lists = [bytearray(), bytearray()]
    triangle_counts = [0, 0]
    while count := unpack_from("<h", source, cursor)[0]:
        end = cursor + 2 + 8*abs(count)
        corners = [unpack_from("<4h", source, cursor+2+8*i) for i in range(abs(count))]
        tube = all(vertex <= 47 and 236 <= u <= 502 and 76 <= v <= 108
                   for vertex, _, u, v in corners)
        mount = all(72 <= vertex <= 79 and 164 <= u <= 218 and 12 <= v <= 40
                    for vertex, _, u, v in corners)
        optic = int(tube or mount)
        command_lists[optic].extend(source[cursor:end])
        triangle_counts[optic] += abs(count)-2
        cursor = end
    if triangle_counts[1] != 68:
        raise ValueError(f"Unexpected optic mesh: {triangle_counts[1]} triangles")

    result = bytearray(source)
    commands = []
    for command_list in command_lists:
        commands.append(len(result))
        result.extend(command_list + b"\0\0")
    while len(result) % 4:
        result.append(0)
    pack_into("<2i", result, model+72, 2, len(result))
    for material in range(2):
        result.extend(pack("<3i", triangle_counts[material], commands[material], material))
        result.extend(source[mesh+12:mesh+20])
    skins = len(result)
    result.extend(pack("<2h", 0, 1))
    texture_table = len(result)
    body_pixels = texture_table + 160
    atlas = source[offset:offset+width*height+768]
    optic_pixels = body_pixels + len(atlas)
    result.extend(pack("<64s4i", b"w_awp.bmp", flags, width, height, body_pixels))
    result.extend(pack("<64s4i", b"awp_scope_stock.bmp", flags, width, height, optic_pixels))
    result.extend(atlas + atlas)
    pack_into("<3i", result, 180, 2, texture_table, body_pixels)
    pack_into("<3i", result, 192, 2, 1, skins)
    pack_into("<i", result, 72, len(result))
    return bytes(result)


def recolor(source, weapon, tier, prefix, *, rarity=None):
    player = prefix == "p"
    protected = set()
    if player and weapon == "awp":
        source = isolate_player_awp_scope(source)
    result = bytearray(source)
    records, maps, aspect = paint_map(source, prefix == "v", player and weapon in INVERTED_PLAYER_MODELS, player)
    for index, mapping in maps.items():
        name, _, w, h, offset = records[index]
        end = offset+w*h
        pixels,palette = texture(source[offset:end],source[end:end+768],w,mapping,aspect,
                                 "butterfly" if weapon=="knife" else weapon,tier,protected,player=player,rarity=rarity)
        result[offset:end+768] = pixels+palette
    return result


def align_studio_textures(model):
    """Pad indexed atlases for renderers that require multiples of four."""
    records = tuple(texture_records(model))
    if all(w % 4 == 0 and h % 4 == 0 for _, _, w, h, _ in records):
        return model

    result = bytearray(model)
    _, table = unpack_from("<2i", model, 180)
    for index, (_, _, width, height, offset) in enumerate(records):
        padded_width = (width + 3) & ~3
        padded_height = (height + 3) & ~3
        if (width, height) == (padded_width, padded_height):
            continue
        result.extend(bytes(-len(result) % 4))
        new_offset = len(result)
        for y in range(padded_height):
            start = offset + min(y, height - 1) * width
            row = model[start:start + width]
            result.extend(row + row[-1:] * (padded_width - width))
        end = offset + width * height
        result.extend(model[end:end + 768])
        pack_into("<3i", result, table + index * 80 + 68,
                  padded_width, padded_height, new_offset)
    pack_into("<i", result, 72, len(result))
    return result


def checked_model(model):
    if unpack_from("<i", model, 72)[0] != len(model):
        raise ValueError("Incorrect declared MDL length")
    for name, _, w, h, off in texture_records(model):
        if not (w > 0 and h > 0 and off >= 244 and off + w*h + 768 <= len(model)):
            raise ValueError(f"Invalid texture {name}")
    return model


def write_model(path, model):
    model = checked_model(align_studio_textures(model))
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


def knife_art_rarity(variant):
    return variant % 4 if variant < 8 else ((variant - 8) % 8) // 2


def knife_model_path(variant):
    family, _, _, _ = (*KNIFE_FAMILIES, BAYONET_FAMILY)[variant // 8]
    rarity = knife_art_rarity(variant)
    revision = {22: "bf", 23: "bk"}.get(variant, "q" if variant >= 24 else ("b" if rarity == 3 else ""))
    if family != "skeleton":
        revision += "a4"
    return OUTPUT / family / TIERS[rarity] / f"v_knife_k{variant:02}{revision}.mdl"


def build_knife_family(family, lighting, variants=None):
    name, source_path, first, size = family
    source = source_path.read_bytes()
    artwork_family = "butterfly-extra" if name == "butterfly" else name
    count = 0
    for variant in range(first, first+size) if variants is None else variants:
        path = knife_model_path(variant)
        # The two legendary Karambits use separately authored blade projections.
        if variant in (22, 23) and path.is_file():
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        data = recolor(source, artwork_family, variant-first, "v", rarity=knife_art_rarity(variant))
        write_model(path, checked_model(lighting.apply(data, idle=True)))
        count += 1
    return count


def main(*, variants_only=False):
    from newyear_form_lighting import FormLighting

    lighting = FormLighting()
    total = 0
    for weapon in WEAPONS:
        if variants_only and weapon == "knife":
            continue
        sources = (("v", BUTTERFLY),) if weapon == "knife" else (
            ("v", MODELS / f"v_{weapon}.mdl"), ("p", MODELS / f"p_{weapon}.mdl"))
        for prefix, source_path in sources:
            source = source_path.read_bytes()
            if weapon != "knife":
                source = enlarge_atlases(source)
            if not variants_only:
                for tier, rarity in enumerate(TIERS):
                    folder = OUTPUT / ("butterfly" if weapon == "knife" else weapon) / rarity
                    folder.mkdir(parents=True, exist_ok=True)
                    model = recolor(source, weapon, tier, prefix)
                    model = lighting.apply(model, idle=prefix == "v")
                    write_model(folder / model_filename(prefix, weapon, tier=tier), checked_model(model))
                    total += 1
            if weapon != "knife":
                for variant, tier in enumerate(VARIANT_TIERS, 1):
                    folder = OUTPUT / weapon / TIERS[tier]
                    folder.mkdir(parents=True, exist_ok=True)
                    model = recolor(source, weapon, variant + 3, prefix)
                    model = lighting.apply(model, idle=prefix == "v")
                    write_model(folder / model_filename(prefix, weapon, variant), checked_model(model))
                    total += 1
    if not variants_only:
        total += sum(build_knife_family(family, lighting) for family in KNIFE_FAMILIES)
    print(f"Built {total} models under {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
