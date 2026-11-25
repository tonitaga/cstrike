"""Bake restrained form lighting into active GoldSrc weapon atlases."""
from collections import Counter
from hashlib import blake2b
from math import isfinite
from struct import pack_into, unpack_from

from build_newyear_skins import nearest, painted_texture, texture_records
from goldsrc_skin_geometry import cross, dot, projection, raster, sub, triangles, unit
from newyear_surface_art import material_palette

NEUTRAL = 7
GAINS = (.63, .68, .73, .78, .83, .88, .94, 1., 1.06, 1.12)


def refine_normals(model, painted):
    """Use local faces to refine rigid normals while retaining authored smoothing."""
    result = bytearray(model)
    skins, _, skin_offset, body_count, body_offset = unpack_from("<5i", model, 192)
    textures = unpack_from(f"<{skins}h", model, skin_offset)
    for body in range(body_count):
        count, _, first = unpack_from("<3i", model, body_offset + 76*body + 64)
        for variant in range(count):
            mesh_count, mesh_offset, _, vertex_bones, vertices, _, normal_bones, normals = unpack_from(
                "<8i", model, first + 112*variant + 72)
            protected = set()
            adjacent = {}
            for mesh in range(mesh_count):
                _, command, skin = unpack_from("<3i", model, mesh_offset + 20*mesh)
                edit = textures[skin] in painted
                while (length := unpack_from("<h", model, command)[0]):
                    corners = [unpack_from("<2h", model, command+2+8*i) for i in range(abs(length))]
                    command += 2 + 8*abs(length)
                    if not edit:
                        protected.update(n for _,n in corners)
                        continue
                    for i in range(2,len(corners)):
                        a,b = (0,i-1) if length < 0 else (i-2,i-1)
                        if length > 0 and i%2:
                            a,b = b,a
                        face = [corners[j] for j in (a,b,i)]
                        points = [unpack_from("<3f",model,vertices+12*v) for v,_ in face]
                        direction = unit(cross(sub(points[1],points[0]),sub(points[2],points[0])))
                        if not any(direction):
                            continue
                        bones = {model[vertex_bones+v] for v,_ in face}
                        if len(bones) != 1:
                            continue
                        bone, = bones
                        for _,n in face:
                            if model[normal_bones+n] == bone:
                                adjacent.setdefault(n,set()).add(direction)
            for n in adjacent.keys() - protected:
                offset = normals+12*n
                old = unpack_from("<3f",model,offset)
                faces = sorted(adjacent[n])
                if not all(map(isfinite,old)) or dot(old,old)<.01:
                    new = faces[0]
                else:
                    # Orient geometry toward the authored normal. Leave sharp or
                    # intentionally smooth transitions alone when faces disagree.
                    oriented = [tuple(-v for v in f) if dot(f,old)<0 else f for f in faces]
                    if any(dot(f,old)<.87 for f in oriented):
                        continue
                    mean = unit(tuple(map(sum,zip(*oriented))))
                    if dot(mean,old)>.9998:
                        continue
                    new = unit(tuple(.66*a+.34*b for a,b in zip(old,mean)))
                pack_into("<3f",result,offset,*new)
    return result


class FormLighting:
    def __init__(self):
        self.maps = {}

    def masks(self, model, records, painted, idle):
        # Geometry and bones are identical across rarity variants of most models.
        first_texture = unpack_from("<i", model, 188)[0]
        key = (idle, tuple((i, records[i][2:4]) for i in sorted(painted)),
               blake2b(model[140:first_texture],digest_size=16).digest())
        if key in self.maps:
            return self.maps[key]
        mesh = list(triangles(model, painted, idle=idle))
        _, _, (long,tall,depth) = projection(mesh, invert_horizontal=idle, axes=True)
        masks = {i:bytearray([NEUTRAL])*(records[i][2]*records[i][3]) for i in painted}
        priority = {i:bytearray(len(masks[i])) for i in painted}
        for i,triangle in mesh:
            a,b,c = (p for p,_,_ in triangle)
            normal = unit(cross(sub(b,a),sub(c,a)))
            side, top, end = (abs(dot(normal,axis)) for axis in (depth,tall,long))
            if not (side or top or end):
                continue
            # Emphasize bevels and keep the broad sides bright enough for the print.
            light = .71 + .27*side + .35*top
            level = min(range(len(GAINS)),key=lambda j:abs(GAINS[j]-light))
            preference = 1+round(250*side)
            _,_,w,h,_=records[i]
            for x,y,*_ in raster([(u,v) for _,u,v in triangle],w,h):
                k=y*w+x
                if preference>priority[i][k]:
                    masks[i][k]=level
                    priority[i][k]=preference
        self.maps[key] = masks
        return masks

    def apply(self, model, idle):
        records=tuple(texture_records(model))
        painted={i for i,r in enumerate(records) if painted_texture(r)}
        result=refine_normals(model,painted)
        masks=self.masks(model,records,painted,idle)
        for i in sorted(painted):
            _,_,w,h,offset=records[i]
            end=offset+w*h
            pixels=model[offset:end]
            old=tuple(tuple(model[j:j+3]) for j in range(end,end+768,3))
            mask=masks[i]
            actual = Counter(zip(mask,pixels))
            if not any(level!=NEUTRAL for level,_ in actual):
                continue
            rgb = {(level,index): tuple(min(255,round(c*GAINS[level])) for c in old[index])
                   for level,index in actual}
            samples = [rgb[key] for key in zip(mask[::5],pixels[::5])]
            palette = material_palette(samples,256)
            lookup={key:nearest(color,palette) for key,color in rgb.items()}
            result[offset:end]=bytes(lookup[key] for key in zip(mask,pixels))
            result[end:end+768]=bytes(c for color in palette for c in color)
        return result
