"""Read studio mesh triangles and map between a model's surfaces and its texture atlas."""
from array import array
from math import cos, sin, sqrt
from struct import pack_into, unpack_from


def dot(a, b):
    return sum(x*y for x, y in zip(a, b))


def cross(a, b):
    return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])


def unit(a):
    length = sqrt(dot(a, a))
    return tuple(x / length for x in a) if length else (0., 0., 0.)


def sub(a, b):
    return tuple(x-y for x, y in zip(a,b))


def idle_animation(model):
    count, offset = unpack_from("<2i", model, 164)
    for sequence in range(count):
        base = offset + 176*sequence
        label = model[base:base+32].split(b"\0")[0]
        group = unpack_from("<i", model, base + 156)[0]
        if label.startswith(b"idle") and group == 0:
            return unpack_from("<i", model, base + 124)[0]
    return None


def bone_transforms(model, idle=False):
    count, offset = unpack_from("<2i", model, 140)
    frames = []
    animation = idle_animation(model) if idle else None
    for index in range(count):
        base = offset + index * 112
        parent = unpack_from("<i", model, base + 32)[0]
        values = list(unpack_from("<6f", model, base + 64))
        if animation is not None:
            channels = animation + 12*index
            for i, delta in enumerate(unpack_from("<6H", model, channels)):
                if delta and model[channels + delta]:
                    raw = unpack_from("<h", model, channels + delta + 2)[0]
                    values[i] += raw * unpack_from("<f", model, base + 88 + 4*i)[0]
        x, y, z, roll, pitch, yaw = values
        sx, cx, sy, cy, sz, cz = sin(roll), cos(roll), sin(pitch), cos(pitch), sin(yaw), cos(yaw)
        rows = ((cz*cy, cz*sy*sx-sz*cx, cz*sy*cx+sz*sx),
                (sz*cy, sz*sy*sx+cz*cx, sz*sy*cx-cz*sx),
                (-sy, cy*sx, cy*cx))
        origin = (x, y, z)
        if parent >= 0:
            basis, pivot = frames[parent]
            origin = tuple(dot(row, origin) + t for row, t in zip(basis, pivot))
            cols = tuple(zip(*rows))
            rows = tuple(tuple(dot(row, col) for col in cols) for row in basis)
        frames.append((rows, origin))
    return frames


def studio_meshes(model):
    skin_count, _, skin_offset, body_count, body_offset = unpack_from("<5i", model, 192)
    textures = unpack_from(f"<{skin_count}h", model, skin_offset)
    for body in range(body_count):
        alternatives, _, first = unpack_from("<3i", model, body_offset + 76 * body + 64)
        for variant in range(alternatives):
            mesh_count, mesh_offset, vertex_count, bone_offset, vertex_offset = unpack_from(
                "<5i", model, first + 112 * variant + 72)
            for mesh in range(mesh_count):
                _, cursor, skin = unpack_from("<3i", model, mesh_offset + 20 * mesh)
                yield variant, textures[skin], cursor, vertex_count, bone_offset, vertex_offset


def scale_texture_uvs(model, scales):
    visited = set()
    for _, texture, cursor, *_ in studio_meshes(model):
        if texture not in scales or cursor in visited:
            continue
        visited.add(cursor)
        sx, sy = scales[texture]
        while count := unpack_from("<h", model, cursor)[0]:
            cursor += 2
            for index in range(abs(count)):
                offset = cursor + 8*index + 4
                u, v = unpack_from("<2h", model, offset)
                pack_into("<2h", model, offset, u*sx, v*sy)
            cursor += 8*abs(count)


def triangles(model, wanted, first_variant_only=False, idle=False):
    frames = bone_transforms(model, idle)
    meshes = {}
    for variant, texture, cursor, vertex_count, bone_offset, vertex_offset in studio_meshes(model):
        if texture not in wanted or (first_variant_only and variant):
            continue
        if vertex_offset not in meshes:
            vertices = []
            for index in range(vertex_count):
                xyz = unpack_from("<3f", model, vertex_offset + 12 * index)
                basis, origin = frames[model[bone_offset + index]]
                vertices.append(tuple(dot(row, xyz)+t for row,t in zip(basis,origin)))
            meshes[vertex_offset] = vertices
        vertices = meshes[vertex_offset]
        while count := unpack_from("<h", model, cursor)[0]:
            size = abs(count)
            cursor += 2
            corners = []
            for index in range(size):
                vertex, _, u, v = unpack_from("<4h", model, cursor + 8 * index)
                corners.append((vertices[vertex], u, v))
            cursor += 8 * size
            for i in range(2, size):
                a, b = (0,i-1) if count < 0 else (i-2,i-1)
                if count > 0 and i % 2:
                    a,b = b,a
                yield texture, (corners[a], corners[b], corners[i])


def projection(mesh, invert_vertical=False, invert_horizontal=False):
    points = list({xyz for _, tri in mesh for xyz,_,_ in tri})
    center = tuple(sum(p[i] for p in points)/len(points) for i in range(3))
    cloud = [sub(p,center) for p in points]
    def axis(cloud, initial):
        vector = initial
        for _ in range(16):
            total = [0.,0.,0.]
            for point in cloud:
                scale = dot(point, vector)
                for i in range(3):
                    total[i] += point[i] * scale
            vector = unit(total)
        return vector
    long = axis(cloud, (1,.51,.19))
    # Make the short axis point up whenever the original rest pose allows it.
    remaining = [tuple(p[i]-dot(p,long)*long[i] for i in range(3)) for p in cloud]
    tall = axis(remaining, (.13,.21,1))
    if (tall[2] < 0) != invert_vertical:
        tall = tuple(-x for x in tall)
    reverse = long[0] < -.15 or abs(long[0]) <= .15 and long[1] < 0
    if reverse != invert_horizontal:
        long = tuple(-x for x in long)
    depth = unit(cross(long,tall))
    raw = [(dot(p,long), dot(p,tall)) for p in points]
    xmin, ymin = map(min, zip(*raw))
    xmax, ymax = map(max, zip(*raw))
    def project(point):
        return ((dot(point,long)-xmin)/(xmax-xmin),
                1-(dot(point,tall)-ymin)/(ymax-ymin), dot(point,depth))
    return project, (xmax-xmin, ymax-ymin), depth


def raster(points, width, height):
    (x0,y0),(x1,y1),(x2,y2)=points
    dx1, dy1, dx2, dy2 = x1-x0, y1-y0, x2-x0, y2-y0
    det = dx1*dy2-dy1*dx2
    if abs(det) < 1e-9:
        return
    for y in range(max(0, int(min(y0,y1,y2))), min(height, int(max(y0,y1,y2))+1)):
        for x in range(max(0, int(min(x0,x1,x2))), min(width, int(max(x0,x1,x2))+1)):
            px,py=x+.5-x0,y+.5-y0
            b,c=(px*dy2-py*dx2)/det,(dx1*py-dy1*px)/det
            a=1-b-c
            if min(a,b,c)>=-1e-7:
                yield x,y,a,b,c


ART_WIDTH = 1024
ART_HEIGHT = 512


def atlas_projection(model, records, allowed, idle=False, invert_vertical=False):
    mesh = list(triangles(model, allowed, idle=idle))
    project, _, depth = projection(mesh, invert_vertical, invert_horizontal=idle)
    sizes = {i: (records[i][2], records[i][3]) for i in allowed}
    # Prefer a side face when UVs are shared by multiple physical faces.
    maps = {
        i: (array("H", [0])*(w*h), array("H", [0])*(w*h), bytearray(w*h))
        for i, (w,h) in sizes.items()
    }
    for i,tri in mesh:
        w,h=sizes[i]
        hmap,vmap,rank=maps[i]
        a,b,c=(xyz for xyz,_,_ in tri)
        normal=unit(cross(sub(b,a),sub(c,a)))
        priority=1+int(abs(dot(normal,depth))*100)
        uv=[(u,v) for _,u,v in tri]
        plane=[project(xyz) for xyz,_,_ in tri]
        for x,y,a,b,c in raster(uv,w,h):
            pos=y*w+x
            if priority > rank[pos]:
                rank[pos]=priority
                hmap[pos]=min(ART_WIDTH-1, max(0, round((ART_WIDTH-1)*(a*plane[0][0]+b*plane[1][0]+c*plane[2][0]))))
                vmap[pos]=min(ART_HEIGHT-1, max(0, round((ART_HEIGHT-1)*(a*plane[0][1]+b*plane[1][1]+c*plane[2][1]))))
    # Extend edge colors into atlas padding so bilinear sampling keeps seams clean.
    for i, (hmap, vmap, rank) in maps.items():
        w, h = sizes[i]
        for _ in range(2):
            existing = bytes(rank)
            for pos, filled in enumerate(existing):
                if filled:
                    continue
                x = pos % w
                for neighbor in (pos - 1 if x else -1, pos + 1 if x < w-1 else -1, pos - w, pos + w):
                    if 0 <= neighbor < len(existing) and existing[neighbor]:
                        hmap[pos], vmap[pos], rank[pos] = hmap[neighbor], vmap[neighbor], 1
                        break
    return maps
