"""Build third-person holiday knives using the stock player-model skeleton."""
from collections import defaultdict
from math import atan2, cos, hypot, radians, sin
from struct import pack, pack_into, unpack_from

from build_newyear_skins import MODELS, OUTPUT, TIERS, knife_model_path, model_filename, texture_records, visible_texture, write_model
from goldsrc_skin_geometry import bone_transforms, cross, dot, projection, sub, triangles, unit

VERTEX_LIMIT = 1900

# Grip position along each handle and length relative to the stock knife.
GRIP_PROFILES = {
    "butterfly": (.23, .77),
    "skeleton": (.25, .76),
    "karambit": (.365, .627),
    "bayonet": (.19, .76),
}


def bone_index(model, label):
    count, offset = unpack_from("<2i", model, 140)
    return next(i for i in range(count)
                if model[offset + i * 112:offset + i * 112 + 32].split(b"\0")[0] == label)


def weapon_axes(mesh, hand):
    _, _, (long, up, _) = projection(mesh, axes=True)
    points = {point for _, triangle in mesh for point, _, _ in triangle}
    ends = [dot(p, long) for p in points]
    if dot(hand, long) > (min(ends) + max(ends)) * .5:
        long = tuple(-v for v in long)
        ends = [-v for v in ends]
    side = unit(cross(long, up))
    return points, long, up, side, min(ends), max(ends)


def grip_center(mesh, axis, up, side, position):
    """Find the center of the handle where it crosses the palm plane."""
    section = []
    for _, triangle in mesh:
        points = [point for point, _, _ in triangle]
        for start, end in zip(points, points[1:] + points[:1]):
            a, b = dot(start, axis), dot(end, axis)
            if a == b or not min(a, b) <= position <= max(a, b):
                continue
            fraction = (position - a) / (b - a)
            section.append(tuple(x + (y - x) * fraction for x, y in zip(start, end)))
    if not section:
        raise ValueError("Knife grip plane does not intersect the model")
    height = [dot(point, up) for point in section]
    width = [dot(point, side) for point in section]
    return (min(height) + max(height)) / 2, (min(width) + max(width)) / 2


def player_model_path(view):
    revision = {"bayonet": "h2", "karambit": "h8", "butterfly": "h5", "skeleton": "h10"}[view.parent.parent.name]
    return view.with_name("p" + view.stem[1:] + revision + ".mdl")


def third_person(view, template, name, family):
    records = tuple(texture_records(view))
    visible = {i for i, record in enumerate(records) if visible_texture(record)}
    mesh = list(triangles(view, visible, first_variant_only=True, idle=True))
    hand = bone_index(view, b"v_weapon.Bip01_R_Hand")
    source_hand = bone_transforms(view, idle=True)[hand][1]
    points, axis, up, side, low, high = weapon_axes(mesh, source_hand)
    if family == "karambit":
        # The finger ring identifies the handle even when the hand bone is
        # projected near the middle of the curved model.
        ring = {i for i,r in enumerate(records) if r[0] in
                {"part_17.bmp", "part_18.bmp", "part_19.bmp", "part_20.bmp", "part_21.bmp", "part_26.bmp"}}
        ring_points = {p for texture, triangle in mesh if texture in ring for p,_,_ in triangle}
        if not ring_points:
            raise ValueError("Missing Karambit ring geometry")
        ring_position = sum(dot(p, axis) for p in ring_points) / len(ring_points)
        if ring_position > (low + high) / 2:
            axis = tuple(-v for v in axis)
            side = tuple(-v for v in side)
            low, high = -high, -low

    base_mesh = list(triangles(template, {0}, first_variant_only=True))
    hand_bone = bone_index(template, b"Bip01 R Hand")
    basis, pivot = bone_transforms(template)[hand_bone]
    _, forward, vertical, lateral, base_low, base_high = weapon_axes(base_mesh, pivot)
    stock_grip = base_low + (base_high - base_low) * .19
    stock_up, stock_side = grip_center(base_mesh, forward, vertical, lateral, stock_grip)
    stock_palm = tuple(stock_grip * a + stock_up * b + stock_side * c
                       for a, b, c in zip(forward, vertical, lateral))

    grip_fraction, length_ratio = GRIP_PROFILES[family]
    grip_axis = low + (high - low) * grip_fraction
    middle_up, middle_side = grip_center(mesh, axis, up, side, grip_axis)
    scale = (base_high - base_low) * length_ratio / (high - low)
    base_forward = forward
    if family in {"butterfly", "karambit"}:
        # Pitch about the palm and roll the edge down without mirroring the mesh.
        pitch = radians(34 if family == "butterfly" else 30)
        pitched_forward = tuple(cos(pitch)*f - sin(pitch)*v for f,v in zip(forward,vertical))
        pitched_up = tuple(sin(pitch)*f + cos(pitch)*v for f,v in zip(forward,vertical))
        forward = pitched_forward
        vertical = tuple(-v for v in pitched_up)
        lateral = tuple(-v for v in lateral)

    palm_offset = sub(stock_palm, pivot)

    def grip_vector(point):
        length = (dot(point, axis) - grip_axis) * scale
        height = (dot(point, up) - middle_up) * scale
        thickness = (dot(point, side) - middle_side) * scale
        return tuple(length * a + height * b + thickness * c
                     for a, b, c in zip(forward, vertical, lateral))

    tip_angles = {"butterfly": 30, "karambit": 15, "skeleton": 15}
    if family in tip_angles:
        # Match the approved side preview, measured from the palm to the tip.
        horizontal = unit((base_forward[0], base_forward[1], 0))
        coordinates = [(dot(v, horizontal), v[2]) for v in map(grip_vector, points)]
        x, y = max(coordinates, key=lambda p: p[0]**2 + p[1]**2)
        adjustment = radians(tip_angles[family]) - atan2(y, x)
        cos_angle, sin_angle = cos(adjustment), sin(adjustment)

    def transform(point):
        vector = grip_vector(point)
        if family in tip_angles:
            x, y = dot(vector, horizontal), vector[2]
            dx, dy = x*cos_angle - y*sin_angle - x, x*sin_angle + y*cos_angle - y
            vector = (vector[0] + dx*horizontal[0], vector[1] + dx*horizontal[1], y + dy)
        placed = tuple(a+b for a,b in zip(palm_offset,vector))
        return tuple(round(dot(column, placed), 5) for column in zip(*basis))

    groups = defaultdict(list)
    for texture, triangle in mesh:
        groups[texture].append(tuple((transform(p), u, v) for p, u, v in triangle))
    used = sorted(groups)
    skins = {texture: i for i, texture in enumerate(used)}

    texture_start = unpack_from("<i", template, 188)[0]
    result = bytearray(template[:texture_start])
    def append(data):
        result.extend(bytes(-len(result) % 4))
        position = len(result)
        result.extend(data)
        return position
    def put(offset, fmt, *values):
        pack_into("<" + fmt, result, offset, *values)

    def bounds(values):
        return tuple(min(v[i] for v in values) for i in range(3)) + \
            tuple(max(v[i] for v in values) for i in range(3))

    # Smooth shallow facets without rounding bevels or sharp material borders.
    faces = defaultdict(list)
    adjacent = defaultdict(set)
    for texture in used:
        for triangle in groups[texture]:
            a, b, c = (p for p, _, _ in triangle)
            normal = tuple(round(v, 4) for v in unit(cross(sub(b, a), sub(c, a))))
            if not any(normal):
                continue
            faces[texture].append((triangle, normal))
            for point in (a, b, c):
                adjacent[texture, point].add(normal)

    batches = []
    for texture in used:
        batch, verts, normals = [], set(), set()
        cache = {}
        for triangle, face_normal in faces[texture]:
            corners = []
            for point, u, v in triangle:
                key = point, face_normal
                if key not in cache:
                    close = sorted(n for n in adjacent[texture, point] if dot(n, face_normal) >= .84)
                    smooth = unit(tuple(sum(axis) for axis in zip(*close)))
                    cache[key] = tuple(round(value, 4) for value in smooth)
                corners.append((point, u, v, cache[key]))
            points = {corner[0] for corner in corners}
            directions = {corner[3] for corner in corners}
            if len(verts | points) > VERTEX_LIMIT or len(normals | directions) > VERTEX_LIMIT:
                batches.append((texture, batch))
                batch, verts, normals = [], set(), set()
            batch.append(corners)
            verts.update(points)
            normals.update(directions)
        if batch:
            batches.append((texture, batch))
    assert len(batches) <= 32 and sum(len(batch) for _, batch in batches) <= 20000

    body = append(bytes(76 * len(batches)))
    table = append(bytes(80 * len(used)))
    skin = append(pack("<" + "h" * len(used), *range(len(used))))
    texels = {}
    for i, texture in enumerate(used):
        label, flags, w, h, offset = records[texture]
        divisor = max(1, (max(w, h) + 383) // 384)
        width, height = max(1, w // divisor), max(1, h // divisor)
        pixels = bytes(view[offset + min(h-1, y * divisor) * w + min(w-1, x * divisor)]
                       for y in range(height) for x in range(width))
        texels[texture] = (divisor, width, height, pixels + view[offset+w*h:offset+w*h+768])

    for i, (texture, batch) in enumerate(batches):
        vertices, normals = {}, {}
        commands = bytearray()
        divisor, width, height, _ = texels[texture]
        for triangle in batch:
            commands.extend(pack("<h", -3))
            for point, u, v, normal in triangle:
                normal_id = normals.setdefault(normal, len(normals))
                vertex = vertices.setdefault(point, len(vertices))
                commands.extend(pack("<4h", vertex, normal_id,
                    max(0, min(width-1, u // divisor)), max(0, min(height-1, v // divisor))))
        commands.extend(b"\0\0")
        submodel = append(bytes(112))
        mesh_offset = append(bytes(20))
        command_offset = append(commands)
        vertex_bones = append(bytes([hand_bone]) * len(vertices))
        vertex_data = append(b"".join(pack("<3f", *p) for p in vertices))
        normal_bones = append(bytes([hand_bone]) * len(normals))
        normal_data = append(b"".join(pack("<3f", *n) for n in normals))
        put(body + 76*i, "64s3i", f"Knife {i}".encode(), 1, 1, submodel)
        put(submodel, "64sif10i", b"knife", 0, max(hypot(*p) for p in vertices),
            1, mesh_offset, len(vertices), vertex_bones, vertex_data, len(normals), normal_bones, normal_data, 0, 0)
        put(mesh_offset, "5i", len(batch), command_offset, skins[texture], len(normals), 0)

    texture_data = len(result) + (-len(result) % 4)
    for i, texture in enumerate(used):
        label, flags, _, _, _ = records[texture]
        _, width, height, data = texels[texture]
        offset = append(data)
        put(table + i * 80, "64s4i", label.encode(), flags, width, height, offset)
    world = [tuple(dot(row, transform(p)) + v for row, v in zip(basis, pivot)) for p in points]
    put(88, "12f", *bounds(world), *bounds(world))
    seq_count, seq_table = unpack_from("<2i", template, 164)
    for i in range(seq_count):
        put(seq_table + 176*i + 96, "6f", *bounds(world))
    put(180, "8i", len(used), table, texture_data, len(used), 1, skin, len(batches), body)
    result[8:72] = name.encode().ljust(64, b"\0")
    put(72, "i", len(result))
    assert len(list(triangles(result, set(range(len(used))), first_variant_only=True))) == sum(len(batch) for _, batch in batches)
    return result


def main():
    template = (MODELS / "p_knife.mdl").read_bytes()
    views = [OUTPUT / "butterfly" / tier / model_filename("v", "knife", tier=i)
             for i, tier in enumerate(TIERS)]
    views.extend(knife_model_path(variant) for variant in range(4, 32))
    for view in views:
        dest = player_model_path(view)
        data = third_person(view.read_bytes(), template, dest.name, view.parent.parent.name)
        write_model(dest, data)
        print(dest, len(data), flush=True)


if __name__ == "__main__":
    main()
