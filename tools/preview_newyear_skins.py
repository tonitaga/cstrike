"""Render the actual edited studio triangles in bind pose for visual review."""
import argparse
from pathlib import Path
from struct import pack
from zlib import compress, crc32

from build_newyear_skins import INVERTED_PLAYER_MODELS, OUTPUT, TIERS, WEAPONS, painted_texture, texture_records
from goldsrc_skin_geometry import cross, dot, projection, raster, sub, triangles, unit
from newyear_surface_art import read_rgb_png


def png(path, width, height, pixels):
    def chunk(kind, data):
        return pack(">I", len(data)) + kind + data + pack(">I", crc32(kind + data))
    rows = b"".join(b"\0" + pixels[i:i+width*3] for i in range(0, len(pixels), width*3))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" +
                     chunk(b"IHDR", pack(">2I5B", width,height,8,2,0,0,0)) +
                     chunk(b"IDAT", compress(rows, 6)) + chunk(b"IEND", b""))


def render(model, width, height, back=False, idle=False, inverted=False):
    records = tuple(texture_records(model))
    allowed = {i for i, record in enumerate(records) if painted_texture(record)}
    mesh = list(triangles(model, allowed, first_variant_only=True, idle=idle))
    project, (length, tall), _ = projection(mesh, inverted, invert_horizontal=idle)
    scale = min((width-28)/length, (height-22)/tall)
    projected_w, projected_h = length*scale, tall*scale
    image = bytearray(bytes((46,51,60)) * (width*height))
    depth = [float("-inf")] * (width*height)
    light_direction = unit((.4,.5,1))
    for i, tri in mesh:
        _, _, texture_w, texture_h, offset = records[i]
        palette = offset + texture_w*texture_h
        plane = [project(p) for p,_,_ in tri]
        screen = [((1-x if back else x)*projected_w + (width-projected_w)/2,
                   y*projected_h + (height-projected_h)/2) for x,y,_ in plane]
        point_a,point_b,point_c = (p for p,_,_ in tri)
        norm = unit(cross(sub(point_b,point_a),sub(point_c,point_a)))
        light = .76 + .24*abs(dot(norm,light_direction))
        for x,y,a,b,c in raster(screen,width,height):
            pos = y*width+x
            z = a*plane[0][2]+b*plane[1][2]+c*plane[2][2]
            if back:
                z = -z
            if z <= depth[pos]:
                continue
            depth[pos] = z
            u = int(a*tri[0][1]+b*tri[1][1]+c*tri[2][1]) % texture_w
            v = int(a*tri[0][2]+b*tri[1][2]+c*tri[2][2]) % texture_h
            color = palette + 3*model[offset+v*texture_w+u]
            image[3*pos:3*pos+3] = bytes(round(value*light) for value in model[color:color+3])
    return image


def write_pairs(output):
    for first, second in (("ak47","deagle"), ("m4a1","usp"), ("awp","glock18")):
        width,height,a = read_rgb_png(output/f"{first}.png")
        _,_,b = read_rgb_png(output/f"{second}.png")
        gap = 8
        row = (height-5*gap)//4
        first_view = slice(gap,gap+row)
        player_view = slice(2*gap+row,2*gap+2*row)
        gutter = a[0]
        pixels = b"".join([gutter]*gap + a[first_view] + [gutter]*gap
                          + b[first_view] + [gutter]*gap + a[player_view]
                          + [gutter]*gap + b[player_view] + [gutter]*gap)
        png(output/f"{first}-{second}.png",width,height,pixels)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for weapon in WEAPONS:
        name = "butterfly" if weapon == "knife" else weapon
        views = (("v",False),("v",True)) if weapon == "knife" else (
            ("v",False),("p",False),("v",True),("p",True))
        page_w, page_h = 1920,1080
        gap = 8
        w = (page_w-5*gap)//4
        h = (page_h-(len(views)+1)*gap)//len(views)
        page = bytearray(bytes((13,16,22)) * (page_w*page_h))
        for row,(prefix,back) in enumerate(views):
            for col,tier in enumerate(TIERS):
                path = OUTPUT / name / tier / f"{prefix}_{weapon}.mdl"
                tile = render(path.read_bytes(), w, h, back, prefix == "v",
                              prefix == "p" and weapon in INVERTED_PLAYER_MODELS)
                for y in range(h):
                    index = 3*((gap+row*(h+gap)+y)*page_w+gap+col*(w+gap))
                    page[index:index+3*w] = tile[3*y*w:3*(y+1)*w]
        png(args.output / f"{name}.png", page_w,page_h,page)
    write_pairs(args.output)


if __name__ == "__main__":
    main()
