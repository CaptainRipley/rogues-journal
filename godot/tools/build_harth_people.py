# Original Harth townspeople. Run with Blender 4:
#   blender -b --python godot/tools/build_harth_people.py
#
# Authored meshes, skins, and clips. No downloaded character pack and no Mixamo.
# Blender is Z-up; the character faces -Y. glTF export turns that into Y-up.

import math
import os
import struct
import json

import bpy
import bmesh
from mathutils import Vector

OUT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "assets", "psx-characters"))
PREVIEW_DIR = "/tmp/harth-people"

CELL = {
    "skin": (0, 0),
    "skin2": (1, 0),
    "cloth": (2, 0),
    "cloth2": (3, 0),
    "cloth_dark": (0, 1),
    "leather": (1, 1),
    "metal": (2, 1),
    "metal_dark": (3, 1),
    "hair": (0, 2),
    "boot": (1, 2),
    "white": (2, 2),
    "eye": (3, 2),
    "trim": (0, 3),
    "wood": (1, 3),
    "rust": (2, 3),
    "veil": (3, 3),
}

# Canonical walk, degrees, local X. Positive swings a limb forward.
# thigh, knee, foot, upper arm, forearm. Frames 1, 5, 9, 13. Frame 17 matches 1.
WALK = {
    1: (30, -12, 6, -28, -24),
    5: (2, -8, -4, -2, -16),
    9: (-26, -14, 10, 24, -30),
    13: (8, -64, 18, 6, -18),
}


def clamp(v, lo=0.0, hi=1.0):
    return max(lo, min(hi, v))


def rad(deg):
    return deg * math.pi / 180.0


def paint_image(name, colors):
    img = bpy.data.images.new(name, 64, 64, alpha=False)
    px = [0.05] * (64 * 64 * 4)
    for cell, (cx, cy) in CELL.items():
        col = colors.get(cell, (40, 32, 28))
        for y in range(16):
            for x in range(16):
                light = (y / 15.0 - 0.45) * 0.16
                side = 0.0
                grain = 0.0
                stain = 0.0
                stitch = 0.0
                c = []
                for channel in range(3):
                    c.append(clamp(col[channel] / 255.0 + light + side + grain + stain + stitch))
                xx = cx * 16 + x
                yy = cy * 16 + y
                i = (yy * 64 + xx) * 4
                px[i] = c[0]
                px[i + 1] = c[1]
                px[i + 2] = c[2]
                px[i + 3] = 1.0
    img.pixels.foreach_set(px)
    img.pack()
    return img


def uv_span(cell, normal):
    cx, cy = CELL[cell]
    # One stable patch per face. Nearest filtering stays inside the cell.
    _ = normal
    u0 = (cx * 16 + 2) / 64.0
    v0 = (cy * 16 + 2) / 64.0
    u1 = (cx * 16 + 14) / 64.0
    v1 = (cy * 16 + 14) / 64.0
    return (u0, v0, u1, v1)


class MeshBuilder:
    def __init__(self):
        self.bm = bmesh.new()
        self.pending = []
        self.face_cell = []
        self.markers = {}

    def vert(self, pos, weights, marker=None):
        v = self.bm.verts.new(pos)
        self.pending.append((v, dict(weights)))
        if marker:
            self.markers[marker] = v
        return v

    def face(self, verts, cell):
        f = self.bm.faces.new(verts)
        self.face_cell.append((f, cell))
        return f

    def ring(self, center, rx, ry, weights, marker=None, sides=6):
        c = Vector(center)
        verts = []
        for i in range(sides):
            ang = (i / float(sides)) * math.tau
            verts.append(self.vert(c + Vector((math.cos(ang) * rx, -math.sin(ang) * ry, 0.0)), weights))
        if marker:
            self.markers[marker] = verts[0]
        return verts

    def bridge(self, a, b, cell):
        n = len(a)
        for i in range(n):
            j = (i + 1) % n
            self.face((a[i], a[j], b[j], b[i]), cell)

    def cap(self, ring_verts, cell, weights, flip=False):
        verts = list(reversed(ring_verts)) if flip else list(ring_verts)
        center_co = Vector()
        for v in verts:
            center_co += v.co
        center = self.vert(center_co / len(verts), weights)
        for i in range(len(verts)):
            j = (i + 1) % len(verts)
            self.face((verts[i], verts[j], center), cell)

    def box(self, center, size, cell, weights):
        hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
        c = Vector(center)
        vs = []
        for z in (-hz, hz):
            for y in (-hy, hy):
                for x in (-hx, hx):
                    vs.append(self.vert(c + Vector((x, y, z)), weights))
        quads = (
            (0, 2, 3, 1),
            (4, 5, 7, 6),
            (0, 1, 5, 4),
            (2, 6, 7, 3),
            (0, 4, 6, 2),
            (1, 3, 7, 5),
        )
        for q in quads:
            self.face(tuple(vs[i] for i in q), cell)

    def finish(self, obj_name, image):
        self.bm.normal_update()
        uv = self.bm.loops.layers.uv.new("UVMap")
        for face, cell in self.face_cell:
            n = face.normal
            u0, v0, u1, v1 = uv_span(cell, n)
            corners = ((u0, v0), (u1, v0), (u1, v1), (u0, v1))
            for loop, uv_xy in zip(face.loops, corners):
                loop[uv].uv = uv_xy
        me = bpy.data.meshes.new(obj_name)
        self.bm.to_mesh(me)
        self.bm.free()
        me.shade_flat()
        obj = bpy.data.objects.new(obj_name, me)
        bpy.context.collection.objects.link(obj)
        for _ in range(len(obj.vertex_groups)):
            pass
        return obj


def normalize(weights):
    total = sum(max(0.0, w) for w in weights.values())
    if total <= 1e-8:
        return {"Hips": 1.0}
    return {k: v / total for k, v in weights.items() if v > 0.001}


def bind_weights(obj, builder):
    names = set()
    for _v, w in builder.pending:
        names.update(w.keys())
    groups = {name: obj.vertex_groups.new(name=name) for name in sorted(names)}
    obj.data.vertices.foreach_set("index", list(range(len(obj.data.vertices))))
    # bmesh vert order matches mesh vert order from to_mesh.
    for index, (_v, w) in enumerate(builder.pending):
        for bone, weight in normalize(w).items():
            groups[bone].add([index], weight, "REPLACE")


def new_bone(arm, name, head, tail, parent, roll_forward=True):
    bone = arm.data.edit_bones.new(name)
    bone.head = Vector(head)
    bone.tail = Vector(tail)
    if parent is not None:
        bone.parent = parent
        bone.use_connect = False
    aim = Vector((0, -1, 0)) if roll_forward else Vector((0, 0, 1))
    bone.align_roll(aim)
    return bone


def build_armature(name, j):
    arm_data = bpy.data.armatures.new(name + "Rig")
    arm = bpy.data.objects.new(name + "Rig", arm_data)
    bpy.context.collection.objects.link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    hips = new_bone(arm, "Hips", j["pelvis"], j["waist"], None)
    spine = new_bone(arm, "Spine", j["waist"], j["chest"], hips)
    chest = new_bone(arm, "Chest", j["chest"], j["shoulder"], spine)
    neck = new_bone(arm, "Neck", j["shoulder"], j["neck"], chest)
    new_bone(arm, "Head", j["neck"], j["head_top"], neck)
    for side, sign in (("R", -1.0), ("L", 1.0)):
        sh = j["shoulder_" + side]
        el = j["elbow_" + side]
        wr = j["wrist_" + side]
        hd = j["hand_" + side]
        hip = j["hip_" + side]
        knee = j["knee_" + side]
        ankle = j["ankle_" + side]
        toe = j["toe_" + side]
        up = new_bone(arm, "UpperArm." + side, sh, el, chest)
        fore = new_bone(arm, "ForeArm." + side, el, wr, up)
        new_bone(arm, "Hand." + side, wr, hd, fore)
        th = new_bone(arm, "Thigh." + side, hip, knee, hips)
        shn = new_bone(arm, "Shin." + side, knee, ankle, th)
        new_bone(arm, "Foot." + side, ankle, toe, shn)
        # sign is unused; positions already carry the side. Kept so the loop reads as a pair.
        _ = sign
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def attach(mesh_obj, arm):
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mod.use_vertex_groups = True
    mesh_obj.parent = arm


def joints_for(spec):
    hip_x = spec["hip_x"]
    sh_x = spec["sh_x"]
    arm_out = spec["arm_out"]
    j = {
        "pelvis": Vector((0, 0, spec["pelvis_z"])),
        "waist": Vector((0, 0, spec["waist_z"])),
        "chest": Vector((0, spec["chest_y"], spec["chest_z"])),
        "shoulder": Vector((0, spec["chest_y"] * 0.4, spec["shoulder_z"])),
        "neck": Vector((0, spec["neck_y"], spec["neck_z"])),
        "head_bot": Vector((0, spec["neck_y"], spec["neck_z"])),
        "head_top": Vector((0, spec["head_y"], spec["height"])),
        "jaw": Vector((0, spec["face_y"], spec["jaw_z"])),
        "brow": Vector((0, spec["face_y"], spec["brow_z"])),
        "crown": Vector((0, spec["head_y"], spec["height"] - 0.02)),
    }
    for side, sign in (("R", -1.0), ("L", 1.0)):
        xh = sign * hip_x
        xs = sign * sh_x
        j["hip_" + side] = Vector((xh, 0.0, spec["pelvis_z"]))
        j["knee_" + side] = Vector((xh, spec["knee_y"], spec["knee_z"]))
        j["ankle_" + side] = Vector((xh, 0.0, spec["ankle_z"]))
        j["toe_" + side] = Vector((xh, spec["toe_y"], spec["toe_z"]))
        j["shoulder_" + side] = Vector((xs, spec["arm_y"], spec["shoulder_z"]))
        j["elbow_" + side] = Vector((sign * (sh_x + arm_out * 0.45), spec["elbow_y"], spec["elbow_z"]))
        j["wrist_" + side] = Vector((sign * (sh_x + arm_out), spec["wrist_y"], spec["wrist_z"]))
        j["hand_" + side] = Vector((sign * (sh_x + arm_out), spec["hand_y"], spec["hand_z"]))
    return j


def build_body(builder, spec, j):
    t = spec["thick"]
    cells = spec["cells"]
    pelvis = builder.ring(j["pelvis"], t["hip_w"], t["hip_d"], {"Hips": 1.0})
    waist = builder.ring(j["waist"], t["waist_w"], t["waist_d"], {"Hips": 0.4, "Spine": 0.6})
    chest = builder.ring(j["chest"], t["chest_w"], t["chest_d"], {"Chest": 1.0})
    shoulder = builder.ring(j["shoulder"], t["sh_w"], t["sh_d"], {"Chest": 1.0})
    neck = builder.ring(j["neck"], t["neck_w"], t["neck_d"], {"Neck": 0.65, "Head": 0.35})
    jaw = builder.ring(j["jaw"], t["jaw_w"], t["jaw_d"], {"Head": 1.0})
    brow = builder.ring(j["brow"], t["head_w"], t["head_d"], {"Head": 1.0})
    crown = builder.ring(j["crown"], t["crown_w"], t["crown_d"], {"Head": 1.0})
    builder.bridge(pelvis, waist, cells["torso"])
    builder.bridge(waist, chest, cells["torso"])
    builder.bridge(chest, shoulder, cells["chest"])
    builder.bridge(shoulder, neck, cells["collar"])
    builder.bridge(neck, jaw, cells["neck"])
    builder.bridge(jaw, brow, cells["skin"])
    builder.bridge(brow, crown, cells["skin"])
    builder.cap(crown, cells["hair_cap"], {"Head": 1.0})
    if spec.get("hem", 0) > 0.04:
        hem_z = spec["pelvis_z"] - spec["hem"]
        hem = builder.ring((0, spec.get("hem_y", 0.01), hem_z), t["hip_w"] + spec.get("hem_flare", 0.03), t["hip_d"] + 0.02, {"Hips": 1.0})
        builder.bridge(pelvis, hem, cells["hem"])
        builder.cap(hem, cells["hem"], {"Hips": 1.0}, flip=True)
    else:
        builder.cap(pelvis, cells["torso"], {"Hips": 1.0}, flip=True)

    def limb(a, b, c, ra, rb, rc, cell_a, cell_b, bone_a, bone_b, bone_c, marker):
        w_a = {bone_a: 0.72, bone_b: 0.28} if bone_b else {bone_a: 1.0}
        # parent blend at the root, hinge at the middle, child at the end
        root_w = {bone_a: 0.62}
        parent = "Chest" if "Arm" in bone_a else "Hips"
        if "Arm" in bone_a:
            root_w = {"Chest": 0.38, bone_a: 0.62}
        else:
            root_w = {"Hips": 0.3, bone_a: 0.7}
        mid_w = {bone_a: 0.5, bone_b: 0.5}
        end_w = {bone_b: 0.45, bone_c: 0.55}
        tip_w = {bone_c: 1.0}
        r0 = builder.ring(a, ra[0], ra[1], root_w, marker=marker)
        r1 = builder.ring((Vector(a) + Vector(b)) * 0.5, (ra[0] + rb[0]) * 0.5, (ra[1] + rb[1]) * 0.5, {bone_a: 1.0}, marker=marker + "_mid" if marker else None)
        r2 = builder.ring(b, rb[0], rb[1], mid_w)
        r3 = builder.ring((Vector(b) + Vector(c)) * 0.5, (rb[0] + rc[0]) * 0.5, (rb[1] + rc[1]) * 0.5, {bone_b: 1.0})
        r4 = builder.ring(c, rc[0], rc[1], end_w)
        builder.bridge(r0, r1, cell_a)
        builder.bridge(r1, r2, cell_a)
        builder.bridge(r2, r3, cell_b)
        builder.bridge(r3, r4, cell_b)
        builder.cap(r0, cell_a, root_w, flip=True)
        return r4

    for side in ("R", "L"):
        foot = limb(
            j["hip_" + side], j["knee_" + side], j["ankle_" + side],
            spec["thigh"], spec["knee"], spec["shin"],
            cells["thigh"], cells["shin"],
            "Thigh." + side, "Shin." + side, "Foot." + side,
            "thigh_" + side,
        )
        ankle = j["ankle_" + side]
        toe = j["toe_" + side]
        boot_c = Vector((ankle.x, (ankle.y + toe.y) * 0.55, 0.035))
        builder.box(boot_c, (spec["foot"][0] * 2.1, abs(toe.y) + 0.04, 0.07), cells["boot"], {"Foot." + side: 1.0})
        # Short cuff so the shin meets the boot instead of ending in a point.
        cuff = builder.ring((ankle.x, ankle.y, ankle.z * 0.55), spec["shin"][0] * 1.15, spec["shin"][1] * 1.15, {"Foot." + side: 0.8, "Shin." + side: 0.2})
        builder.bridge(foot, cuff, cells["boot"])
        builder.cap(cuff, cells["boot"], {"Foot." + side: 1.0})
        hand = limb(
            j["shoulder_" + side], j["elbow_" + side], j["wrist_" + side],
            spec["upper"], spec["elbow"], spec["fore"],
            cells["sleeve"], cells["fore"],
            "UpperArm." + side, "ForeArm." + side, "Hand." + side,
            "arm_" + side,
        )
        tip = j["hand_" + side]
        mitt = builder.ring(tip, spec["hand"][0], spec["hand"][1], {"Hand." + side: 1.0})
        builder.bridge(hand, mitt, cells["hand"])
        builder.cap(mitt, cells["hand"], {"Hand." + side: 1.0})
        # Thumb on the inner side, so the mitts read as hands.
        inner = -1.0 if side == "R" else 1.0
        thumb_c = (Vector(j["wrist_" + side]) + Vector(tip)) * 0.5
        thumb_c.x += inner * spec["hand"][0] * 0.35
        thumb_c.y -= 0.012
        builder.box(thumb_c, (spec["hand"][0] * 0.7, spec["hand"][1] * 0.55, spec["hand"][0] * 0.7), cells["hand"], {"Hand." + side: 1.0})


def add_face(builder, spec, j):
    if not spec.get("face", True):
        return
    cells = spec["cells"]
    front = spec["face_y"] - spec["thick"]["head_d"]
    eye_z = (spec["jaw_z"] + spec["brow_z"]) * 0.58
    eye_y = front - 0.012
    span = spec["thick"]["head_w"] * 0.38
    for sign in (-1.0, 1.0):
        builder.box((sign * span, eye_y, eye_z), (0.026, 0.012, 0.016), "eye", {"Head": 1.0})
    builder.box((0, front - 0.02, eye_z - 0.015), (0.028, 0.03, 0.036), cells["skin"], {"Head": 1.0})
    builder.box((0, front - 0.014, spec["jaw_z"] + 0.012), (0.046, 0.01, 0.012), "eye", {"Head": 1.0})
    builder.box(
        (0, front - 0.01, spec["brow_z"] - 0.012),
        (spec["thick"]["head_w"] * 1.55, 0.016, 0.018),
        cells.get("brow", "hair"),
        {"Head": 1.0},
    )


def add_accessories(builder, spec, j):
    kind = spec["kind"]
    cells = spec["cells"]
    t = spec["thick"]
    head_c = Vector((0, (spec["face_y"] + spec["head_y"]) * 0.5, (spec["neck_z"] + spec["height"]) * 0.5))
    if kind == "hob":
        # Hood sits behind and above the face so the beard and eyes stay visible.
        front = spec["face_y"] - t["head_d"]
        builder.box((0, 0.02, spec["height"] - 0.045), (t["head_w"] * 2.2, t["head_d"] * 2.0, 0.08), "cloth2", {"Head": 1.0})
        builder.box((0, t["head_d"] * 0.85, head_c.z + 0.01), (t["head_w"] * 2.2, 0.045, t["head_w"] * 1.7), "cloth2", {"Head": 1.0})
        for sign in (-1.0, 1.0):
            builder.box((sign * t["head_w"] * 1.12, 0.03, head_c.z), (0.04, t["head_d"] * 1.35, t["head_w"] * 1.45), "cloth2", {"Head": 1.0})
        builder.box((0, 0.01, spec["neck_z"] - 0.015), (t["neck_w"] * 2.8, t["neck_d"] * 2.2, 0.07), "cloth2", {"Neck": 0.45, "Head": 0.55})
        builder.box((0, front - 0.02, spec["jaw_z"] - 0.045), (0.08, 0.04, 0.065), "hair", {"Head": 1.0})
        builder.box((0, 0.015, spec["waist_z"]), (t["waist_w"] * 2.15, t["waist_d"] * 2.15, 0.045), "leather", {"Hips": 0.5, "Spine": 0.5})
    elif kind == "ralf":
        builder.box((0, 0.01, spec["height"] - 0.015), (t["head_w"] * 2.3, t["head_d"] * 2.2, 0.055), "hair", {"Head": 1.0})
        builder.box((0, spec["face_y"] - t["head_d"] * 0.2, spec["brow_z"] + 0.02), (t["head_w"] * 2.2, 0.04, 0.045), "hair", {"Head": 1.0})
        for sign in (-1.0, 1.0):
            builder.box((sign * t["head_w"] * 0.95, 0.01, spec["brow_z"] - 0.04), (0.035, t["head_d"] * 1.4, 0.1), "hair", {"Head": 1.0})
        builder.box((0, spec["face_y"] - 0.01, spec["jaw_z"] - 0.035), (0.06, 0.03, 0.04), "hair", {"Head": 1.0})
        # Open vest: two front panels, cloth shows between them.
        builder.box((-t["chest_w"] * 0.55, spec["chest_y"] - t["chest_d"] - 0.01, (spec["chest_z"] + spec["waist_z"]) * 0.5), (t["chest_w"] * 0.7, 0.02, (spec["chest_z"] - spec["waist_z"]) * 0.85), "cloth_dark", {"Chest": 0.6, "Spine": 0.4})
        builder.box((t["chest_w"] * 0.55, spec["chest_y"] - t["chest_d"] - 0.01, (spec["chest_z"] + spec["waist_z"]) * 0.5), (t["chest_w"] * 0.7, 0.02, (spec["chest_z"] - spec["waist_z"]) * 0.85), "cloth_dark", {"Chest": 0.6, "Spine": 0.4})
        builder.box((0, 0.01, spec["waist_z"]), (t["waist_w"] * 2.05, t["waist_d"] * 2.05, 0.035), "leather", {"Spine": 0.5, "Hips": 0.5})
    elif kind == "pell":
        builder.box((0, 0.0, spec["height"] - 0.01), (t["head_w"] * 2.5, t["head_d"] * 2.5, 0.05), "white", {"Head": 1.0})
        builder.box((0, t["head_d"] * 0.7, head_c.z - 0.02), (t["head_w"] * 2.35, 0.04, 0.22), "veil", {"Head": 0.7, "Neck": 0.3})
        builder.box((0, t["head_d"] * 0.9, spec["chest_z"]), (0.1, 0.025, 0.28), "veil", {"Chest": 0.8, "Neck": 0.2})
        for sign in (-1.0, 1.0):
            builder.box((sign * t["head_w"] * 1.05, spec["face_y"] * 0.3, spec["jaw_z"]), (0.03, t["head_d"] * 1.5, 0.12), "white", {"Head": 1.0})
        builder.box((0, 0.0, spec["neck_z"] - 0.03), (t["neck_w"] * 3.4, t["neck_d"] * 2.8, 0.07), "white", {"Neck": 1.0})
        builder.box((0, spec["chest_y"] - t["chest_d"] - 0.012, spec["chest_z"]), (0.012, 0.012, 0.07), "wood", {"Chest": 1.0})
        builder.box((0, spec["chest_y"] - t["chest_d"] - 0.012, spec["chest_z"]), (0.05, 0.012, 0.012), "wood", {"Chest": 1.0})
        builder.box((0, 0.0, spec["waist_z"]), (t["waist_w"] * 2.2, t["waist_d"] * 2.2, 0.04), "leather", {"Spine": 0.4, "Hips": 0.6})
    elif kind == "marta":
        builder.box((0, 0.03, spec["height"] - 0.03), (t["head_w"] * 2.15, t["head_d"] * 2.0, 0.05), "hair", {"Head": 1.0})
        builder.box((0, t["head_d"] * 0.85, spec["brow_z"]), (0.07, 0.06, 0.07), "hair", {"Head": 1.0})
        apron_top = Vector((0, spec["chest_y"] - t["chest_d"] - 0.02, spec["chest_z"] - 0.04))
        apron_mid = Vector((0, spec["chest_y"] - t["chest_d"] - 0.025, spec["waist_z"]))
        apron_low = Vector((0, 0.03, spec["pelvis_z"] - spec["hem"] * 0.85))
        builder.box(apron_top, (t["chest_w"] * 1.7, 0.02, 0.16), "leather", {"Chest": 1.0})
        builder.box(apron_mid, (t["waist_w"] * 1.9, 0.018, 0.16), "leather", {"Spine": 0.5, "Hips": 0.5})
        builder.box(apron_low, (t["hip_w"] * 1.8, 0.018, spec["hem"] * 0.9), "leather", {"Hips": 1.0})
        builder.box((-t["sh_w"] * 0.65, spec["chest_y"], spec["shoulder_z"] + 0.01), (0.03, 0.02, 0.1), "leather", {"Chest": 1.0})
        builder.box((0, 0.01, spec["waist_z"]), (t["waist_w"] * 2.2, t["waist_d"] * 2.1, 0.05), "cloth_dark", {"Hips": 0.45, "Spine": 0.55})
    elif kind == "bren":
        builder.box((0, spec["head_y"], (spec["neck_z"] + spec["height"]) * 0.5 + 0.01), (t["head_w"] * 2.7, t["head_d"] * 2.9, (spec["height"] - spec["neck_z"]) * 1.05), "metal", {"Head": 1.0})
        builder.box((0, spec["face_y"] - t["head_d"] - 0.03, (spec["jaw_z"] + spec["brow_z"]) * 0.5), (t["head_w"] * 1.3, 0.02, 0.028), "eye", {"Head": 1.0})
        builder.box((0, 0.0, spec["height"] + 0.015), (0.03, t["head_d"] * 2.2, 0.045), "metal_dark", {"Head": 1.0})
        for side, sign in (("R", -1.0), ("L", 1.0)):
            builder.box((sign * spec["sh_x"], spec["arm_y"], spec["shoulder_z"] + 0.03), (0.14, 0.12, 0.08), "metal", {"Chest": 1.0})
        builder.box((0, 0.01, spec["waist_z"]), (t["waist_w"] * 2.25, t["waist_d"] * 2.15, 0.05), "leather", {"Spine": 0.4, "Hips": 0.6})
    elif kind == "cole":
        builder.box((0, 0.0, spec["height"] - 0.02), (t["head_w"] * 2.2, t["head_d"] * 2.2, 0.09), "metal", {"Head": 1.0})
        builder.box((0, spec["face_y"] * 0.5, spec["brow_z"] + 0.02), (t["head_w"] * 3.3, t["head_d"] * 2.8, 0.025), "metal_dark", {"Head": 1.0})
        builder.box((0, spec["face_y"] - 0.02, spec["jaw_z"] - 0.04), (0.07, 0.035, 0.05), "hair", {"Head": 1.0})
        for side, sign in (("R", -1.0), ("L", 1.0)):
            builder.box((sign * spec["sh_x"], spec["arm_y"], spec["shoulder_z"] + 0.02), (0.11, 0.1, 0.06), "rust", {"Chest": 1.0})
        builder.box((0, t["chest_d"] + 0.03, spec["chest_z"]), (t["sh_w"] * 1.6, 0.02, 0.22), "cloth_dark", {"Chest": 1.0})
        builder.box((0, t["hip_d"] + 0.035, spec["pelvis_z"] - 0.08), (t["hip_w"] * 1.5, 0.018, 0.28), "cloth_dark", {"Hips": 0.7, "Chest": 0.3})
        builder.box((0, 0.01, spec["waist_z"]), (t["waist_w"] * 2.15, t["waist_d"] * 2.1, 0.045), "leather", {"Hips": 0.5, "Spine": 0.5})


def material_for(name, image):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    mat.use_backface_culling = True
    nt = mat.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    if "Specular IOR Level" in bsdf.inputs:
        bsdf.inputs["Specular IOR Level"].default_value = 0.0
    elif "Specular" in bsdf.inputs:
        bsdf.inputs["Specular"].default_value = 0.0
    return mat


def key_euler(pb, frame, x=0.0, y=0.0, z=0.0):
    pb.rotation_mode = "XYZ"
    pb.rotation_euler = (rad(x), rad(y), rad(z))
    pb.keyframe_insert("rotation_euler", frame=frame)


def key_world_loc(pb, frame, offset):
    local = pb.bone.matrix_local.to_3x3().inverted() @ Vector(offset)
    pb.location = local
    pb.keyframe_insert("location", frame=frame)


def polish(action, linear_frames=()):
    for fc in action.fcurves:
        for kp in fc.keyframe_points:
            if int(round(kp.co[0])) in linear_frames:
                kp.interpolation = "LINEAR"
            else:
                kp.interpolation = "BEZIER"
                kp.handle_left_type = "AUTO_CLAMPED"
                kp.handle_right_type = "AUTO_CLAMPED"


def action_on(arm, name):
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    if arm.animation_data is None:
        arm.animation_data_create()
    arm.animation_data.action = act
    return act


def key_walk(arm, slouch):
    act = action_on(arm, "walk")
    pose = arm.pose.bones
    for side, shift in (("R", 0), ("L", 8)):
        for frame in (1, 5, 9, 13, 16):
            src = 1 if frame == 16 else frame
            src = ((src - 1 + shift) % 16) + 1
            thigh, knee, foot, upper, fore = WALK[src]
            key_euler(pose["Thigh." + side], frame, x=thigh)
            key_euler(pose["Shin." + side], frame, x=knee)
            key_euler(pose["Foot." + side], frame, x=foot)
            key_euler(pose["UpperArm." + side], frame, x=upper)
            key_euler(pose["ForeArm." + side], frame, x=fore)
    hip_keys = {
        1: (Vector((-0.025, 0.0, 0.0)), 5.0),
        5: (Vector((0.0, 0.0, -0.028)), 0.0),
        9: (Vector((0.025, 0.0, 0.0)), -5.0),
        13: (Vector((0.0, 0.0, -0.028)), 0.0),
        16: (Vector((-0.025, 0.0, 0.0)), 5.0),
    }
    for frame, (loc, yaw) in hip_keys.items():
        key_world_loc(pose["Hips"], frame, loc)
        key_euler(pose["Hips"], frame, y=yaw)
        key_euler(pose["Spine"], frame, x=slouch * 0.45, y=-yaw * 0.75)
        key_euler(pose["Chest"], frame, x=4 + slouch * 0.2, y=-yaw * 0.35)
        key_euler(pose["Neck"], frame, x=-2, y=yaw * 0.4)
        key_euler(pose["Head"], frame, x=-3, y=yaw * 0.25)
    polish(act)
    return act


def key_idle(arm, slouch, head_pitch):
    act = action_on(arm, "idle")
    pose = arm.pose.bones
    keys = {
        1: (0.0, 0.0, 0.0),
        12: (4.2, 4.5, 1.6),
        24: (0.4, 0.0, 0.0),
        36: (-2.2, -4.0, -1.4),
        48: (0.0, 0.0, 0.0),
    }
    for frame, (breath, sway, shift) in keys.items():
        bob = -0.006 * abs(math.sin(breath * 0.2))
        key_world_loc(pose["Hips"], frame, Vector((shift * 0.004, 0.0, bob)))
        key_euler(pose["Hips"], frame, z=shift)
        key_euler(pose["Spine"], frame, x=slouch * 0.65 + breath * 0.25)
        key_euler(pose["Chest"], frame, x=slouch * 0.25 + breath)
        key_euler(pose["Neck"], frame, x=breath * 0.3)
        key_euler(pose["Head"], frame, x=head_pitch + breath * 0.45, z=sway * 0.15)
        key_euler(pose["UpperArm.R"], frame, x=-6 - sway * 0.35, z=2)
        key_euler(pose["UpperArm.L"], frame, x=-6 + sway * 0.35, z=-2)
        key_euler(pose["ForeArm.R"], frame, x=-18)
        key_euler(pose["ForeArm.L"], frame, x=-16)
        key_euler(pose["Thigh.R"], frame, z=shift * 0.15)
        key_euler(pose["Thigh.L"], frame, z=shift * 0.15)
    polish(act)
    return act


def key_strike(arm):
    act = action_on(arm, "strike")
    pose = arm.pose.bones
    # u follows the old anvil timing: raise, slam, recover. 20 frames at 24 fps.
    samples = {
        1: (-18, -28, 6, 4),
        8: (-70, -48, 0, 8),
        13: (-108, -58, -6, 14),
        16: (58, -8, 24, -2),
        19: (-18, -28, 6, 4),
    }
    for frame, (upper, fore, torso, hips) in samples.items():
        key_euler(pose["UpperArm.R"], frame, x=upper, z=8)
        key_euler(pose["ForeArm.R"], frame, x=fore)
        key_euler(pose["Hand.R"], frame, x=fore * 0.15)
        key_euler(pose["UpperArm.L"], frame, x=-20, z=-10)
        key_euler(pose["ForeArm.L"], frame, x=-28)
        key_euler(pose["Spine"], frame, x=torso * 0.45)
        key_euler(pose["Chest"], frame, x=torso)
        key_euler(pose["Neck"], frame, x=torso * -0.2)
        key_euler(pose["Head"], frame, x=8)
        key_euler(pose["Hips"], frame, x=hips)
        key_world_loc(pose["Hips"], frame, Vector((0.0, 0.0, -0.01 if frame == 16 else 0.0)))
    polish(act, linear_frames=(13, 16))
    return act


def look_at(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_still(path, arm, frame, eye, target):
    scene = bpy.context.scene
    scene.frame_set(frame)
    cam = bpy.data.objects.get("PreviewCam")
    if cam is None:
        cam_data = bpy.data.cameras.new("PreviewCam")
        cam = bpy.data.objects.new("PreviewCam", cam_data)
        bpy.context.collection.objects.link(cam)
        scene.camera = cam
    cam.location = Vector(eye)
    look_at(cam, target)
    cam.data.lens = 50
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def assert_hinge(arm, mesh_obj, markers):
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    pose = arm.pose.bones
    for pb in pose:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    rest = mesh_rest_positions(mesh_obj, deps)
    pose["Shin.R"].rotation_euler.x = rad(-70)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    bent = mesh_rest_positions(mesh_obj, deps)
    thigh = markers["thigh_R_mid"]
    # The mid marker is on the first ring vert; the true mid-segment vert is the next ring.
    # Use a vertex whose rest weight is the thigh and whose index was stored.
    thigh_move = (bent[markers["thigh_R_mid"]] - rest[markers["thigh_R_mid"]]).length
    pose["Shin.R"].rotation_euler.x = 0.0
    pose["ForeArm.R"].rotation_euler.x = rad(-70)
    bpy.context.view_layer.update()
    deps = bpy.context.evaluated_depsgraph_get()
    bent_arm = mesh_rest_positions(mesh_obj, deps)
    arm_move = (bent_arm[markers["arm_R_mid"]] - rest[markers["arm_R_mid"]]).length
    pose["ForeArm.R"].rotation_euler.x = 0.0
    if thigh_move > 0.03:
        raise RuntimeError("thigh sheared when the knee bent: %.3f" % thigh_move)
    if arm_move > 0.03:
        raise RuntimeError("upper arm sheared when the elbow bent: %.3f" % arm_move)
    # Forward axis check: a positive thigh rotation must carry the knee toward -Y.
    pose["Thigh.R"].rotation_euler.x = rad(40)
    bpy.context.view_layer.update()
    head = arm.matrix_world @ pose["Shin.R"].head
    pose["Thigh.R"].rotation_euler.x = 0.0
    bpy.context.view_layer.update()
    rest_head = arm.matrix_world @ pose["Shin.R"].head
    delta = head - rest_head
    if delta.y > -0.01:
        raise RuntimeError("positive thigh X did not swing forward, delta %s" % (delta,))
    for pb in pose:
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


def mesh_rest_positions(mesh_obj, deps):
    ev = mesh_obj.evaluated_get(deps)
    me = ev.to_mesh()
    out = [Vector(v.co) for v in me.vertices]
    ev.to_mesh_clear()
    return out


def export_glb(arm, path):
    bpy.context.view_layer.objects.active = arm
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    for child in arm.children:
        child.select_set(True)
    bpy.context.view_layer.objects.active = arm
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_animations=True,
        export_animation_mode="ACTIONS",
        export_frame_range=False,
        export_skins=True,
        export_morph=False,
        export_apply=False,
        export_materials="EXPORT",
        export_image_format="AUTO",
        export_texcoords=True,
        export_normals=True,
        export_cameras=False,
        export_lights=False,
        export_def_bones=False,
        export_optimize_animation_size=False,
        export_force_sampling=True,
        export_rest_position_armature=True,
        export_nla_strips=False,
        export_bake_animation=True,
    )


def assert_glb(path, expect_strike):
    data = open(path, "rb").read()
    length = struct.unpack_from("<I", data, 12)[0]
    gltf = json.loads(data[20:20 + length])
    names = [a["name"] for a in gltf.get("animations", [])]
    if "idle" not in names or "walk" not in names:
        raise RuntimeError("%s clips %s" % (path, names))
    if expect_strike and "strike" not in names:
        raise RuntimeError("%s missing strike" % path)
    if not gltf.get("skins"):
        raise RuntimeError("%s has no skin" % path)
    print("glb", os.path.basename(path), "anims", names, "bytes", len(data))


def specs():
    def base(**kw):
        return kw

    skin = (158, 118, 90)
    return [
        base(
            kind="hob", file="hob",
            height=1.62, pelvis_z=0.74, waist_z=0.92, chest_z=1.08, shoulder_z=1.22,
            neck_z=1.32, jaw_z=1.40, brow_z=1.50, knee_z=0.40, ankle_z=0.07, elbow_z=0.96,
            wrist_z=0.74, hand_z=0.62, toe_z=0.035,
            hip_x=0.10, sh_x=0.20, arm_out=0.035,
            chest_y=0.012, neck_y=-0.01, head_y=-0.012, face_y=-0.02,
            knee_y=-0.02, elbow_y=0.03, arm_y=0.0, wrist_y=0.02, hand_y=-0.015, toe_y=-0.16,
            hem=0.13, hem_flare=0.035, hem_y=0.008,
            slouch=2.0, head_pitch=0.0, face=True, strike=False,
            thigh=(0.085, 0.08), knee=(0.07, 0.065), shin=(0.055, 0.05),
            upper=(0.058, 0.055), elbow=(0.05, 0.048), fore=(0.044, 0.042),
            foot=(0.05, 0.07), hand=(0.034, 0.028),
            thick=dict(hip_w=0.16, hip_d=0.11, waist_w=0.17, waist_d=0.12, chest_w=0.19, chest_d=0.13,
                       sh_w=0.20, sh_d=0.12, neck_w=0.055, neck_d=0.05, jaw_w=0.08, jaw_d=0.075,
                       head_w=0.105, head_d=0.095, crown_w=0.09, crown_d=0.085),
            cells=dict(torso="cloth", chest="cloth", collar="cloth2", neck="skin", skin="skin",
                       hair_cap="cloth2", hem="cloth", thigh="cloth_dark", shin="cloth_dark",
                       boot="boot", sleeve="cloth", fore="cloth", hand="skin", brow="hair"),
            colors=dict(skin=skin, skin2=skin, cloth=(92, 64, 42), cloth2=(68, 50, 36),
                        cloth_dark=(48, 38, 30), leather=(110, 74, 46), hair=(42, 28, 22),
                        boot=(26, 20, 16), eye=(16, 10, 8), white=(170, 160, 140)),
        ),
        base(
            kind="ralf", file="ralf",
            height=1.88, pelvis_z=0.96, waist_z=1.14, chest_z=1.30, shoulder_z=1.46,
            neck_z=1.56, jaw_z=1.64, brow_z=1.76, knee_z=0.50, ankle_z=0.075, elbow_z=1.16,
            wrist_z=0.92, hand_z=0.80, toe_z=0.035,
            hip_x=0.09, sh_x=0.18, arm_out=0.02,
            chest_y=0.02, neck_y=-0.005, head_y=-0.01, face_y=-0.02,
            knee_y=-0.02, elbow_y=0.025, arm_y=0.0, wrist_y=0.015, hand_y=-0.02, toe_y=-0.17,
            hem=0.08, hem_flare=0.01, hem_y=0.0,
            slouch=10.0, head_pitch=6.0, face=True, strike=False,
            thigh=(0.07, 0.065), knee=(0.058, 0.052), shin=(0.045, 0.04),
            upper=(0.042, 0.04), elbow=(0.038, 0.036), fore=(0.034, 0.032),
            foot=(0.045, 0.075), hand=(0.03, 0.024),
            thick=dict(hip_w=0.13, hip_d=0.09, waist_w=0.125, waist_d=0.09, chest_w=0.15, chest_d=0.10,
                       sh_w=0.16, sh_d=0.10, neck_w=0.045, neck_d=0.042, jaw_w=0.062, jaw_d=0.06,
                       head_w=0.078, head_d=0.075, crown_w=0.07, crown_d=0.068),
            cells=dict(torso="cloth", chest="cloth", collar="cloth", neck="skin", skin="skin",
                       hair_cap="hair", hem="cloth", thigh="cloth_dark", shin="cloth_dark",
                       boot="boot", sleeve="cloth", fore="cloth", hand="skin", brow="hair"),
            colors=dict(skin=(176, 146, 118), skin2=(176, 146, 118), cloth=(154, 142, 118),
                        cloth2=(154, 142, 118), cloth_dark=(58, 46, 40), leather=(96, 64, 42),
                        hair=(168, 138, 74), boot=(36, 28, 22), eye=(20, 14, 12)),
        ),
        base(
            kind="pell", file="pell",
            height=1.70, pelvis_z=0.82, waist_z=0.98, chest_z=1.14, shoulder_z=1.28,
            neck_z=1.38, jaw_z=1.46, brow_z=1.56, knee_z=0.42, ankle_z=0.07, elbow_z=1.02,
            wrist_z=0.80, hand_z=0.70, toe_z=0.03,
            hip_x=0.09, sh_x=0.16, arm_out=0.02,
            chest_y=0.0, neck_y=0.0, head_y=0.0, face_y=-0.015,
            knee_y=-0.015, elbow_y=0.02, arm_y=0.0, wrist_y=0.01, hand_y=-0.01, toe_y=-0.13,
            hem=0.0, hem_flare=0.0, hem_y=0.0,
            slouch=-2.0, head_pitch=4.0, face=True, strike=False,
            thigh=(0.115, 0.10), knee=(0.09, 0.08), shin=(0.07, 0.06),
            upper=(0.055, 0.05), elbow=(0.05, 0.046), fore=(0.048, 0.044),
            foot=(0.042, 0.06), hand=(0.026, 0.022),
            thick=dict(hip_w=0.15, hip_d=0.10, waist_w=0.145, waist_d=0.10, chest_w=0.155, chest_d=0.105,
                       sh_w=0.15, sh_d=0.10, neck_w=0.05, neck_d=0.048, jaw_w=0.068, jaw_d=0.062,
                       head_w=0.082, head_d=0.078, crown_w=0.08, crown_d=0.076),
            cells=dict(torso="veil", chest="veil", collar="white", neck="white", skin="skin",
                       hair_cap="white", hem="veil", thigh="veil", shin="veil",
                       boot="boot", sleeve="veil", fore="veil", hand="skin", brow="white"),
            colors=dict(skin=(190, 164, 148), cloth=(28, 30, 36), cloth2=(28, 30, 36),
                        cloth_dark=(22, 24, 30), veil=(24, 26, 34), white=(186, 176, 156),
                        leather=(128, 102, 68), hair=(186, 176, 156), boot=(22, 20, 18),
                        eye=(24, 16, 14), wood=(92, 64, 40)),
        ),
        base(
            kind="marta", file="marta",
            height=1.76, pelvis_z=0.84, waist_z=1.02, chest_z=1.18, shoulder_z=1.34,
            neck_z=1.44, jaw_z=1.52, brow_z=1.64, knee_z=0.44, ankle_z=0.075, elbow_z=1.06,
            wrist_z=0.82, hand_z=0.70, toe_z=0.04,
            hip_x=0.11, sh_x=0.22, arm_out=0.04,
            chest_y=0.015, neck_y=-0.005, head_y=-0.008, face_y=-0.02,
            knee_y=-0.02, elbow_y=0.03, arm_y=0.0, wrist_y=0.02, hand_y=-0.02, toe_y=-0.16,
            hem=0.16, hem_flare=0.02, hem_y=0.01,
            slouch=4.0, head_pitch=2.0, face=True, strike=True,
            thigh=(0.09, 0.085), knee=(0.075, 0.07), shin=(0.06, 0.055),
            upper=(0.07, 0.065), elbow=(0.06, 0.055), fore=(0.05, 0.048),
            foot=(0.055, 0.08), hand=(0.038, 0.032),
            thick=dict(hip_w=0.16, hip_d=0.11, waist_w=0.155, waist_d=0.11, chest_w=0.20, chest_d=0.13,
                       sh_w=0.22, sh_d=0.13, neck_w=0.055, neck_d=0.05, jaw_w=0.072, jaw_d=0.068,
                       head_w=0.088, head_d=0.084, crown_w=0.08, crown_d=0.076),
            cells=dict(torso="cloth_dark", chest="cloth_dark", collar="cloth_dark", neck="skin", skin="skin",
                       hair_cap="hair", hem="cloth_dark", thigh="cloth_dark", shin="cloth_dark",
                       boot="boot", sleeve="cloth_dark", fore="skin", hand="skin", brow="hair"),
            colors=dict(skin=(162, 104, 74), skin2=(140, 86, 60), cloth=(48, 42, 38),
                        cloth2=(48, 42, 38), cloth_dark=(36, 32, 30), leather=(118, 76, 46),
                        hair=(28, 18, 14), boot=(24, 18, 16), eye=(18, 10, 8)),
        ),
        base(
            kind="bren", file="bren",
            height=1.84, pelvis_z=0.88, waist_z=1.06, chest_z=1.24, shoulder_z=1.40,
            neck_z=1.50, jaw_z=1.58, brow_z=1.70, knee_z=0.46, ankle_z=0.08, elbow_z=1.10,
            wrist_z=0.86, hand_z=0.74, toe_z=0.04,
            hip_x=0.12, sh_x=0.26, arm_out=0.03,
            chest_y=0.01, neck_y=0.0, head_y=0.0, face_y=-0.02,
            knee_y=-0.015, elbow_y=0.02, arm_y=0.0, wrist_y=0.01, hand_y=-0.015, toe_y=-0.15,
            hem=0.06, hem_flare=0.02, hem_y=0.0,
            slouch=0.0, head_pitch=0.0, face=False, strike=False,
            thigh=(0.10, 0.09), knee=(0.085, 0.075), shin=(0.07, 0.06),
            upper=(0.07, 0.065), elbow=(0.06, 0.055), fore=(0.055, 0.05),
            foot=(0.055, 0.08), hand=(0.04, 0.034),
            thick=dict(hip_w=0.18, hip_d=0.12, waist_w=0.18, waist_d=0.12, chest_w=0.22, chest_d=0.15,
                       sh_w=0.24, sh_d=0.14, neck_w=0.07, neck_d=0.065, jaw_w=0.09, jaw_d=0.09,
                       head_w=0.10, head_d=0.10, crown_w=0.09, crown_d=0.09),
            cells=dict(torso="metal_dark", chest="metal", collar="metal", neck="metal_dark", skin="skin",
                       hair_cap="metal", hem="metal_dark", thigh="metal_dark", shin="boot",
                       boot="boot", sleeve="metal", fore="metal", hand="metal", brow="metal"),
            colors=dict(skin=(140, 106, 80), metal=(70, 72, 76), metal_dark=(40, 42, 46),
                        cloth_dark=(40, 42, 46), leather=(96, 62, 40), boot=(28, 24, 22),
                        eye=(8, 8, 10), hair=(40, 42, 46)),
        ),
        base(
            kind="cole", file="cole",
            height=1.94, pelvis_z=0.98, waist_z=1.18, chest_z=1.36, shoulder_z=1.54,
            neck_z=1.64, jaw_z=1.72, brow_z=1.84, knee_z=0.52, ankle_z=0.08, elbow_z=1.22,
            wrist_z=0.98, hand_z=0.86, toe_z=0.04,
            hip_x=0.10, sh_x=0.20, arm_out=0.025,
            chest_y=0.0, neck_y=-0.005, head_y=-0.008, face_y=-0.018,
            knee_y=-0.02, elbow_y=0.02, arm_y=0.0, wrist_y=0.015, hand_y=-0.015, toe_y=-0.16,
            hem=0.1, hem_flare=0.02, hem_y=0.0,
            slouch=1.0, head_pitch=0.0, face=True, strike=False,
            thigh=(0.08, 0.075), knee=(0.068, 0.06), shin=(0.05, 0.048),
            upper=(0.05, 0.048), elbow=(0.044, 0.042), fore=(0.04, 0.038),
            foot=(0.048, 0.075), hand=(0.032, 0.028),
            thick=dict(hip_w=0.145, hip_d=0.10, waist_w=0.14, waist_d=0.10, chest_w=0.17, chest_d=0.11,
                       sh_w=0.18, sh_d=0.11, neck_w=0.05, neck_d=0.048, jaw_w=0.07, jaw_d=0.066,
                       head_w=0.084, head_d=0.08, crown_w=0.078, crown_d=0.074),
            cells=dict(torso="metal_dark", chest="metal_dark", collar="rust", neck="skin", skin="skin",
                       hair_cap="metal", hem="metal_dark", thigh="cloth_dark", shin="boot",
                       boot="boot", sleeve="metal_dark", fore="rust", hand="metal", brow="hair"),
            colors=dict(skin=(150, 114, 86), metal=(78, 74, 66), metal_dark=(36, 34, 32),
                        cloth_dark=(42, 36, 32), rust=(110, 72, 46), leather=(90, 60, 40),
                        hair=(64, 44, 32), boot=(30, 24, 20), eye=(16, 10, 8)),
        ),
    ]


def setup_render():
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.render.resolution_x = 420
    scene.render.resolution_y = 640
    scene.render.film_transparent = False
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_backface_culling = True
    scene.render.fps = 24
    world = scene.world
    if world is None:
        world = bpy.data.worlds.new("World")
        scene.world = world
    world.color = (0.05, 0.045, 0.04)


def build_one(spec, previews):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    setup_render()
    j = joints_for(spec)
    image = paint_image(spec["file"] + "_tex", spec["colors"])
    builder = MeshBuilder()
    build_body(builder, spec, j)
    add_face(builder, spec, j)
    add_accessories(builder, spec, j)
    builder.bm.verts.index_update()
    saved = {name: vert.index for name, vert in builder.markers.items()}
    mesh_obj = builder.finish(spec["file"], image)
    bind_weights(mesh_obj, builder)
    mat = material_for(spec["file"], image)
    mesh_obj.data.materials.append(mat)
    arm = build_armature(spec["file"], j)
    attach(mesh_obj, arm)
    lowest = min(v.co.z for v in mesh_obj.data.vertices)
    highest = max(v.co.z for v in mesh_obj.data.vertices)
    if lowest < -0.02 or lowest > 0.04:
        raise RuntimeError("%s feet at %.3f" % (spec["file"], lowest))
    if abs(highest - spec["height"]) > 0.35:
        raise RuntimeError("%s height %.3f expected %.3f" % (spec["file"], highest, spec["height"]))
    assert_hinge(arm, mesh_obj, saved)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="POSE")
    key_idle(arm, spec["slouch"], spec["head_pitch"])
    key_walk(arm, spec["slouch"])
    if spec["strike"]:
        key_strike(arm)
    # Clear the evaluated pose back to rest for export. Actions keep the keys.
    for pb in arm.pose.bones:
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)
    if previews:
        os.makedirs(PREVIEW_DIR, exist_ok=True)
        target = (0, 0, spec["height"] * 0.48)
        render_still(
            os.path.join(PREVIEW_DIR, spec["file"] + "_rest.png"),
            arm, 1, (1.15, -2.6, spec["height"] * 0.62), target,
        )
        # Walk contact is frame 1 of the walk action. Switch action so the pose shows.
        arm.animation_data.action = bpy.data.actions["walk"]
        render_still(
            os.path.join(PREVIEW_DIR, spec["file"] + "_walk.png"),
            arm, 1, (2.15, -1.55, spec["height"] * 0.55), target,
        )
        render_still(
            os.path.join(PREVIEW_DIR, spec["file"] + "_swing.png"),
            arm, 13, (2.3, -0.35, spec["height"] * 0.5), target,
        )
        arm.animation_data.action = bpy.data.actions["idle"]
        render_still(
            os.path.join(PREVIEW_DIR, spec["file"] + "_idle.png"),
            arm, 12, (0.9, -2.7, spec["height"] * 0.62), target,
        )
        if spec["strike"]:
            arm.animation_data.action = bpy.data.actions["strike"]
            render_still(
                os.path.join(PREVIEW_DIR, spec["file"] + "_raise.png"),
                arm, 13, (1.8, -1.7, spec["height"] * 0.6), target,
            )
            render_still(
                os.path.join(PREVIEW_DIR, spec["file"] + "_hit.png"),
                arm, 16, (1.8, -1.7, spec["height"] * 0.55), target,
            )
        for pb in arm.pose.bones:
            pb.rotation_euler = (0.0, 0.0, 0.0)
            pb.location = (0.0, 0.0, 0.0)
        arm.animation_data.action = None
    path = os.path.join(OUT_DIR, spec["file"] + ".glb")
    export_glb(arm, path)
    assert_glb(path, spec["strike"])
    print("built", spec["file"], "verts", len(mesh_obj.data.vertices), "height", round(highest, 3))


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    only = os.environ.get("ONLY", "")
    for spec in specs():
        if only and spec["file"] not in only.split(","):
            continue
        build_one(spec, previews=True)
    print("done")


if __name__ == "__main__":
    main()
