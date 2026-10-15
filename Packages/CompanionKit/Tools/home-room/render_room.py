"""Renders HAKU's home room in Blender, one image per layer, for the SpriteKit scene.

Issue #485. Run with Blender's Python (pip install bpy==4.2.0 imagequant pillow in a Python 3.11 venv):
    python render_room.py [--out DIR] [--scale 2] [--samples 64] [--only name,name] [--time day,night]
                          [--paint all|none|sofa,bed,rug,walls]
A full run takes about half an hour on 4 CPU cores. CI does not run it; commit its PNGs and home-layers.json.

Grid coordinates follow HomeGrid.swift: x runs along the back-right wall, y along the back-left wall, z up,
one unit per cell. The camera is a true isometric orthographic camera that puts grid point (x, y, z) at
HomeGrid.plan(x, y, z) inside HomeGrid.canvas, so every layer lines up with the scene's own projection.

Each layer is rendered alone (the rest of the room is hidden from the camera but still casts shadows and
bounces light) for day and night, cropped to its pixels, and listed in home-layers.json with its plan rect.
Paintable pieces are rendered again in each HomePaintable swatch as `<layer>_<index>`.
"""

import argparse
import json
import math
import os
import sys

import bpy
from mathutils import Vector

# HomeGrid.swift
UNIT = 34.0
ORIGIN = (440.0, 240.0)
CANVAS = (124.0, 4.0, 632.0, 604.0)
SIZE = 10.0
WALL_H = 6.2
WALL_T = 0.4
SLAB = 0.5
ISO = math.sqrt(2.0 / 3.0)  # screen length of one world unit in a true isometric view


def hexcolor(h, alpha=1.0):
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

    return (lin((h >> 16) & 255), lin((h >> 8) & 255), lin(h & 255), alpha)


def B(x, y, z=0.0):
    """Blender location of a grid point (the grid's x and y swap so the camera sees them as HomeGrid does)."""
    return Vector((y, x, z))


def plan(x, y, z=0.0):
    cx = math.cos(math.pi / 6) * UNIT
    return (ORIGIN[0] + (x - y) * cx, ORIGIN[1] + (x + y) * 0.5 * UNIT - z * UNIT)


# ---------------------------------------------------------------------------------------------- materials

MATS = {}


def mat(name, color, rough=0.6, metal=0.0, emit=None, emit_strength=0.0, grain=None, bump=0.0, sheen=0.0):
    key = name
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = hexcolor(color)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if sheen:
        bsdf.inputs["Sheen Weight"].default_value = sheen
    if emit is not None:
        bsdf.inputs["Emission Color"].default_value = hexcolor(emit)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    coord = nt.nodes.new("ShaderNodeTexCoord")
    if grain == "wood":
        # Long stretched noise for grain, mixed darker into the base colour.
        mapping = nt.nodes.new("ShaderNodeMapping")
        mapping.inputs["Scale"].default_value = (1.0, 14.0, 1.0)
        noise = nt.nodes.new("ShaderNodeTexWave")
        noise.wave_type = "BANDS"
        noise.inputs["Scale"].default_value = 3.0
        noise.inputs["Distortion"].default_value = 6.0
        noise.inputs["Detail"].default_value = 3.0
        ramp = nt.nodes.new("ShaderNodeMix")
        ramp.data_type = "RGBA"
        ramp.inputs[6].default_value = hexcolor(color)
        dark = [c * 0.72 for c in hexcolor(color)[:3]] + [1.0]
        ramp.inputs[7].default_value = dark
        nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
        nt.links.new(mapping.outputs["Vector"], noise.inputs["Vector"])
        fac = nt.nodes.new("ShaderNodeMath")
        fac.operation = "MULTIPLY"
        fac.inputs[1].default_value = 0.45
        nt.links.new(noise.outputs["Fac"], fac.inputs[0])
        nt.links.new(fac.outputs[0], ramp.inputs["Factor"])
        nt.links.new(ramp.outputs[2], bsdf.inputs["Base Color"])
    elif grain == "fabric" or bump:
        noise = nt.nodes.new("ShaderNodeTexNoise")
        noise.inputs["Scale"].default_value = 60.0
        noise.inputs["Detail"].default_value = 4.0
        bmp = nt.nodes.new("ShaderNodeBump")
        bmp.inputs["Strength"].default_value = bump or 0.12
        nt.links.new(coord.outputs["Object"], noise.inputs["Vector"])
        nt.links.new(noise.outputs["Fac"], bmp.inputs["Height"])
        nt.links.new(bmp.outputs["Normal"], bsdf.inputs["Normal"])
    MATS[key] = m
    return m


def planks_material(name, color, plank=0.55):
    """Floor boards: brick texture stretched into long planks, with grain."""
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.45
    coord = nt.nodes.new("ShaderNodeTexCoord")
    mapping = nt.nodes.new("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (1.0 / plank, 1.0 / (plank * 4.0), 1.0)
    brick = nt.nodes.new("ShaderNodeTexBrick")
    brick.offset = 0.37
    brick.inputs["Color1"].default_value = hexcolor(color)
    brick.inputs["Color2"].default_value = [c * 0.88 for c in hexcolor(color)[:3]] + [1.0]
    brick.inputs["Mortar"].default_value = [c * 0.55 for c in hexcolor(color)[:3]] + [1.0]
    brick.inputs["Scale"].default_value = 1.0
    brick.inputs["Mortar Size"].default_value = 0.012
    brick.inputs["Brick Width"].default_value = 1.0
    brick.inputs["Row Height"].default_value = 0.25
    nt.links.new(coord.outputs["Object"], mapping.inputs["Vector"])
    nt.links.new(mapping.outputs["Vector"], brick.inputs["Vector"])
    nt.links.new(brick.outputs["Color"], bsdf.inputs["Base Color"])
    MATS[name] = m
    return m


# ------------------------------------------------------------------------------------------------ shapes

LAYERS = {}  # layer name -> list of objects


def add(layer, obj):
    LAYERS.setdefault(layer, []).append(obj)
    return obj


def rbox(layer, x0, y0, z0, x1, y1, z1, material, bevel=0.06, segments=4):
    """A box between two grid corners with rounded edges."""
    bpy.ops.mesh.primitive_cube_add(size=1)
    o = bpy.context.active_object
    o.location = B((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
    o.scale = (y1 - y0, x1 - x0, z1 - z0)
    bpy.ops.object.transform_apply(scale=True)
    if bevel > 0:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = min(bevel, (x1 - x0) / 2.01, (y1 - y0) / 2.01, (z1 - z0) / 2.01)
        b.segments = segments
        b.limit_method = "NONE"
        o.modifiers.new("smooth", "WEIGHTED_NORMAL")
        bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    return add(layer, o)


def cushion(layer, x0, y0, z0, x1, y1, z1, material, puff=0.18):
    """A soft cushion: a rounded box, subdivided and squashed so the faces bulge and the corners sag."""
    o = rbox(layer, x0, y0, z0, x1, y1, z1, material, bevel=min(0.16, (z1 - z0) * 0.45), segments=6)
    s = o.modifiers.new("soft", "SUBSURF")
    s.levels = 2
    s.render_levels = 2
    cast = o.modifiers.new("puff", "CAST")
    cast.factor = puff
    cast.cast_type = "SPHERE"
    return o


def lean(o, degrees):
    """Tilts an object back toward the left wall about its own middle."""
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.origin_set(type="ORIGIN_GEOMETRY", center="BOUNDS")
    o.rotation_euler = (math.radians(degrees), 0, 0)


def cyl(layer, x, y, z0, z1, r, material, verts=32, bevel=0.02):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=z1 - z0, location=B(x, y, (z0 + z1) / 2))
    o = bpy.context.active_object
    if bevel:
        b = o.modifiers.new("bevel", "BEVEL")
        b.width = bevel
        b.segments = 3
        bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    return add(layer, o)


def sphere(layer, x, y, z, r, material, scale=(1, 1, 1)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, radius=r, location=B(x, y, z))
    o = bpy.context.active_object
    o.scale = (scale[1], scale[0], scale[2])
    bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    return add(layer, o)


def plane_on_left_wall(layer, y0, y1, z0, z1, material, x=0.01):
    """A flat panel on the back-left wall (x = 0), facing the room."""
    return rbox(layer, x, y0, z0, x + 0.03, y1, z1, material, bevel=0.005, segments=1)


def plane_on_back_wall(layer, x0, x1, z0, z1, material, y=0.01):
    """A flat panel on the back-right wall (y = 0), facing the room."""
    return rbox(layer, x0, y, z0, x1, y + 0.03, z1, material, bevel=0.005, segments=1)


def leaf(layer, x, y, z, length, angle, tilt, material, width=0.16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, radius=1, location=B(x, y, z))
    o = bpy.context.active_object
    o.scale = (width, length / 2, 0.03)
    o.rotation_euler = (math.radians(tilt), 0, math.radians(angle))
    bpy.ops.object.shade_smooth()
    o.data.materials.append(material)
    return add(layer, o)


# ------------------------------------------------------------------------------------------------- room

C = {
    "wall": 0xEDE3D2,
    "wallTop": 0xFFF4DF,
    "cut": 0xEADCC2,
    "slab": 0xE4D2B4,
    "floor": 0xC9915C,
    "wood": 0xC98B4F,
    "woodDark": 0x6B4430,
    "woodMid": 0x9A6440,
    "navy": 0x2F3557,
    "navyLight": 0x434A72,
    "pink": 0xFF5C9D,
    "green": 0x6CC47A,
    "rug": 0x8EA3C8,
    "rugEdge": 0xCFD8EA,
    "white": 0xF4F1EA,
    "linen": 0xE9E4DA,
    "duvet": 0x3E7B5F,
    "ink": 0x1B1C26,
    "red": 0xE8455A,
    "yellow": 0xFFD23F,
    "cyan": 0x3EF0FF,
    "steel": 0x9AA1AD,
    "leaf": 0x4FA85A,
    "pot": 0xF08FB8,
    "terracotta": 0xD9774B,
}


def build_shell():
    wall = mat("wall", C["wall"], rough=0.9, bump=0.03)
    top = mat("wallTop", C["wallTop"], rough=0.9)
    slab = mat("slab", C["slab"], rough=0.85)
    floor = planks_material("floor", C["floor"])
    n, h, t = SIZE, WALL_H, WALL_T
    # Island slab under the floor, with soft edges.
    rbox("shell", -t, -t, -SLAB, n, n, -0.021, slab, bevel=0.12)
    o = rbox("shell", 0, 0, -0.02, n, n, 0.0, floor, bevel=0.0)
    # Back-left wall (x from -t to 0) and back-right wall (y from -t to 0), with the window cut out.
    rbox("shell", -t, -t, 0, 0, n, h, wall, bevel=0.05)
    back = rbox("shell", 0, -t, 0, n, 0, h, wall, bevel=0.05)
    bpy.ops.mesh.primitive_cube_add(size=1)
    hole = bpy.context.active_object
    hole.location = B(2.3, -t / 2, 3.3)
    hole.scale = (t * 3, 2.6, 2.4)
    hole.hide_render = True
    hole.hide_viewport = True
    cut = back.modifiers.new("window", "BOOLEAN")
    cut.object = hole
    cut.operation = "DIFFERENCE"
    back.modifiers.move(len(back.modifiers) - 1, 0)
    # Cream caps on the wall tops, like the page the room sits on.
    rbox("shell", -t, -t, h, 0, n, h + 0.04, top, bevel=0.02)
    rbox("shell", 0, -t, h, n, 0, h + 0.04, top, bevel=0.02)
    # Skirting.
    skirt = mat("skirt", 0xF6EEDF, rough=0.7)
    rbox("shell", 0, 0, 0, 0.06, n, 0.18, skirt, bevel=0.01)
    rbox("shell", 0, 0, 0, n, 0.06, 0.18, skirt, bevel=0.01)
    # Window frame, sill and curtain rail.
    frame = mat("frame", 0xF8F5EE, rough=0.5)
    rbox("shell", 0.95, -0.05, 1.95, 3.65, 0.35, 2.1, frame, bevel=0.03)
    rbox("shell", 0.95, -0.08, 4.5, 3.65, 0.08, 4.6, frame, bevel=0.02)
    rbox("shell", 0.95, -0.08, 2.0, 1.05, 0.08, 4.6, frame, bevel=0.02)
    rbox("shell", 3.55, -0.08, 2.0, 3.65, 0.08, 4.6, frame, bevel=0.02)
    rbox("shell", 2.26, -0.06, 2.0, 2.34, 0.06, 4.6, frame, bevel=0.01)
    rbox("shell", 1.0, -0.06, 3.26, 3.6, 0.06, 3.34, frame, bevel=0.01)
    curtain = mat("curtain", 0xD9CFC0, rough=0.95, grain="fabric")
    for x0 in (0.55, 3.7):
        c = cushion("shell", x0, 0.05, 1.7, x0 + 0.38, 0.28, 4.75, curtain, puff=0.08)
    rbox("shell", 0.4, 0.08, 4.8, 4.25, 0.14, 4.86, mat("rail", 0x6B4430, rough=0.4), bevel=0.02)


def build_desk():
    wood = mat("deskWood", C["wood"], rough=0.55, grain="wood")
    dark = mat("deskDark", C["woodMid"], rough=0.6, grain="wood")
    black = mat("black", C["ink"], rough=0.35)
    white = mat("keys", 0xF2F2F2, rough=0.5)
    rbox("desk", 0.0, 0.4, 1.2, 1.5, 3.4, 1.36, wood, bevel=0.04)
    rbox("desk", 0.08, 0.5, 0.0, 1.42, 1.35, 1.2, dark, bevel=0.03)
    for z in (0.3, 0.72):
        rbox("desk", 1.41, 0.58, z, 1.44, 1.27, z + 0.34, wood, bevel=0.01)
        rbox("desk", 1.44, 0.82, z + 0.15, 1.48, 1.03, z + 0.2, mat("handle", 0xD8C7A8, rough=0.3, metal=0.6), bevel=0.01)
    rbox("desk", 0.1, 3.18, 0.0, 1.38, 3.3, 1.2, dark, bevel=0.02)
    # Monitor: its screen face sits on x = 0.36 between y 1.2-2.8, z 1.65-2.52 (HomeScene draws the screen there).
    rbox("desk", 0.18, 1.12, 1.58, 0.36, 2.88, 2.6, black, bevel=0.03)
    rbox("desk", 0.2, 1.9, 1.36, 0.3, 2.1, 1.6, black, bevel=0.02)
    rbox("desk", 0.15, 1.7, 1.36, 0.55, 2.3, 1.4, black, bevel=0.02)
    rbox("desk", 0.75, 1.45, 1.36, 1.05, 2.45, 1.41, white, bevel=0.02)
    rbox("desk", 0.8, 2.6, 1.36, 1.0, 2.75, 1.4, white, bevel=0.03)
    # Desk lamp, mug.
    lamp = mat("deskLamp", 0x2F3557, rough=0.4)
    cyl("desk", 0.35, 0.75, 1.36, 1.4, 0.13, lamp)
    rbox("desk", 0.33, 0.73, 1.4, 0.37, 0.77, 1.95, lamp, bevel=0.01)
    cyl("desk", 0.5, 0.85, 1.85, 2.02, 0.14, mat("shade", 0xFFE3A3, rough=0.6, emit=0xFFD27A, emit_strength=0.0))
    cyl("desk", 1.2, 3.0, 1.36, 1.58, 0.09, mat("mug", 0xF4F1EA, rough=0.4))


def build_chair():
    seat = mat("chairSeat", C["navy"], rough=0.8, grain="fabric")
    black = mat("chairBase", 0x22242E, rough=0.4, metal=0.3)
    cushion("chairSeat", 1.6, 1.3, 0.5, 2.6, 2.4, 0.7, seat, puff=0.1)
    cyl("chairSeat", 2.1, 1.85, 0.12, 0.5, 0.05, black)
    for a in range(5):
        ang = a * 2 * math.pi / 5
        x, y = 2.1 + 0.4 * math.cos(ang), 1.85 + 0.4 * math.sin(ang)
        rbox("chairSeat", min(2.1, x) - 0.03, min(1.85, y) - 0.03, 0.06, max(2.1, x) + 0.03, max(1.85, y) + 0.03, 0.12, black, 0.02)
        sphere("chairSeat", x, y, 0.05, 0.05, black)
    cushion("chairBack", 2.45, 1.35, 0.75, 2.65, 2.35, 1.75, seat, puff=0.12)


def build_shelf():
    wood = mat("shelfWood", C["wood"], rough=0.55, grain="wood")
    for z in (3.2, 4.2):
        rbox("shelf", 0.0, 4.2, z, 0.55, 7.4, z + 0.1, wood, bevel=0.02)
    rbox("shelf", 0.0, 4.25, 3.0, 0.5, 4.32, 4.3, wood, bevel=0.01)
    rbox("shelf", 0.0, 7.28, 3.0, 0.5, 7.35, 4.3, wood, bevel=0.01)


def build_posters():
    frame = mat("posterFrame", 0x2B2B33, rough=0.4)
    paper1 = mat("poster1", 0xF7F3EA, rough=0.8)
    paper2 = mat("poster2", 0x2D3250, rough=0.8)
    plane_on_left_wall("posters", 0.7, 1.8, 2.7, 4.3, frame)
    plane_on_left_wall("posters", 0.78, 1.72, 2.78, 4.22, paper1, x=0.035)
    rbox("posters", 0.07, 1.0, 3.2, 0.09, 1.5, 3.32, mat("posterGreen", 0x4FA85A, rough=0.8), 0.01, 1)
    rbox("posters", 0.07, 1.1, 3.55, 0.09, 1.45, 3.62, mat("posterPink", C["pink"], rough=0.8), 0.01, 1)
    plane_on_left_wall("posters", 2.0, 3.2, 2.9, 4.8, frame)
    plane_on_left_wall("posters", 2.08, 3.12, 2.98, 4.72, paper2, x=0.035)
    rbox("posters", 0.07, 2.45, 3.4, 0.09, 2.75, 4.3, mat("posterPink", C["pink"], rough=0.8), 0.01, 1)


def build_sofa():
    fabric = mat("sofa", C["navy"], rough=0.85, grain="fabric", sheen=0.3)
    seatfab = mat("sofaSeat", C["navyLight"], rough=0.85, grain="fabric", sheen=0.3)
    legs = mat("sofaLegs", C["woodDark"], rough=0.5)
    # Back: base frame plus two soft back cushions leaning on it.
    rbox("sofaBack", 0.0, 4.4, 0.08, 0.7, 7.6, 1.0, fabric, bevel=0.14, segments=6)
    cushion("sofaBack", 0.25, 4.95, 0.65, 0.75, 6.0, 1.6, seatfab, puff=0.22)
    cushion("sofaBack", 0.25, 6.0, 0.65, 0.75, 7.05, 1.6, seatfab, puff=0.22)
    # Throw pillows lean on the back cushions.
    pinkm = mat("pillowPink", C["pink"], rough=0.9, grain="fabric", sheen=0.4)
    greenm = mat("pillowGreen", C["green"], rough=0.9, grain="fabric", sheen=0.4)
    p = cushion("sofaBack", 0.7, 5.2, 0.75, 0.95, 5.85, 1.35, pinkm, puff=0.35)
    lean(p, -14)
    q = cushion("sofaBack", 0.7, 6.45, 0.75, 0.95, 7.0, 1.28, greenm, puff=0.35)
    lean(q, -12)
    # Arms: rounded rolls.
    rbox("sofaFarArm", 0.6, 4.4, 0.08, 2.2, 5.0, 0.95, fabric, bevel=0.22, segments=8)
    rbox("sofaNearArm", 0.6, 7.0, 0.08, 2.2, 7.6, 0.95, fabric, bevel=0.22, segments=8)
    # Seat base and two seat cushions that sag a little.
    rbox("sofaSeat", 0.7, 5.0, 0.08, 2.15, 7.0, 0.42, fabric, bevel=0.1, segments=5)
    cushion("sofaSeat", 0.72, 5.02, 0.4, 2.18, 5.99, 0.64, seatfab, puff=0.2)
    cushion("sofaSeat", 0.72, 6.01, 0.4, 2.18, 6.98, 0.64, seatfab, puff=0.2)
    for x, y, layer in ((2.0, 4.55, "sofaFarArm"), (2.0, 7.45, "sofaNearArm"), (0.15, 4.55, "sofaBack"), (0.15, 7.45, "sofaBack")):
        cyl(layer, x, y, 0.0, 0.1, 0.05, legs)


def build_table_rug():
    wood = mat("tableWood", C["wood"], rough=0.5, grain="wood")
    dark = mat("tableLegs", C["woodDark"], rough=0.5)
    rbox("table", 3.0, 5.1, 0.42, 4.4, 6.3, 0.56, wood, bevel=0.05)
    for x, y in ((3.12, 5.22), (4.28, 5.22), (3.12, 6.18), (4.28, 6.18)):
        cyl("table", x, y, 0.0, 0.43, 0.05, dark)
    rbox("table", 3.25, 5.35, 0.56, 3.85, 5.8, 0.6, mat("book", 0x3A6B58, rough=0.7), 0.02)
    cyl("table", 4.05, 5.9, 0.56, 0.78, 0.08, mat("can", C["ink"], rough=0.3, metal=0.5))
    rug = mat("rug", C["rug"], rough=1.0, grain="fabric", bump=0.25)
    edge = mat("rugEdge", C["rugEdge"], rough=1.0, grain="fabric")
    rbox("rug", 2.6, 3.8, 0.0, 6.0, 8.2, 0.03, edge, bevel=0.015, segments=2)
    rbox("rug", 2.8, 4.0, 0.0, 5.8, 8.0, 0.04, rug, bevel=0.01, segments=2)
    rbox("doormat", 3.6, 9.05, 0.0, 5.6, 9.95, 0.03, mat("doormat", 0x3A3F5C, rough=1.0, grain="fabric"), 0.02)


def build_bed():
    frame = mat("bedFrame", C["woodDark"], rough=0.5, grain="wood")
    sheet = mat("sheet", C["white"], rough=0.9, grain="fabric", sheen=0.3)
    pillow = mat("pillow", 0xFBFAF6, rough=0.9, grain="fabric", sheen=0.3)
    duvet = mat("duvet", C["duvet"], rough=0.9, grain="fabric", sheen=0.4)
    # Headboard along the back (small y), padded.
    rbox("bed", 6.6, 4.8, 0.0, 9.6, 5.15, 1.75, frame, bevel=0.08)
    cushion("bed", 6.75, 5.1, 0.75, 9.45, 5.25, 1.6, mat("headPad", 0x8C5E44, rough=0.8, grain="fabric"), puff=0.08)
    rbox("bed", 6.6, 5.15, 0.05, 9.6, 8.8, 0.38, frame, bevel=0.06)
    cushion("bed", 6.68, 5.2, 0.36, 9.52, 8.72, 0.68, sheet, puff=0.08)
    cushion("bed", 6.95, 5.3, 0.66, 8.0, 6.0, 0.98, pillow, puff=0.35)
    cushion("bed", 8.2, 5.3, 0.66, 9.25, 6.0, 0.98, pillow, puff=0.35)
    # Folded duvet at the foot when nobody is in bed; drawn over HAKU when he lies down.
    cushion("blanket", 6.56, 7.6, 0.6, 9.64, 8.86, 0.92, duvet, puff=0.12)
    cushion("blanketCover", 6.56, 6.15, 0.62, 9.64, 8.86, 0.98, duvet, puff=0.1)
    rbox("blanketCover", 6.6, 6.1, 0.9, 9.6, 6.45, 1.02, sheet, bevel=0.06)
    # Nightstand and lamp.
    wood = mat("standWood", C["wood"], rough=0.5, grain="wood")
    rbox("nightstand", 9.0, 3.6, 0.0, 9.9, 4.5, 1.0, wood, bevel=0.05)
    rbox("nightstand", 9.0, 4.48, 0.55, 9.85, 4.52, 0.9, wood, bevel=0.01)
    cyl("nightstand", 9.45, 4.05, 1.0, 1.1, 0.14, mat("lampBase", 0x2F3557, rough=0.4))
    cyl("nightstand", 9.45, 4.05, 1.1, 1.3, 0.03, mat("lampBase", 0x2F3557))
    cyl("nightstand", 9.45, 4.05, 1.3, 1.62, 0.2, mat("bedLampShade", 0xFFE7B0, rough=0.7, emit=0xFFC66B, emit_strength=0.0), verts=24)


def build_wardrobe():
    wood = mat("wardrobeWood", 0x8B5A3C, rough=0.55, grain="wood")
    inside = mat("wardrobeInside", 0x3B2418, rough=0.9)
    rbox("wardrobe", 6.8, 0.0, 0.0, 8.9, 1.3, 4.6, wood, bevel=0.05)
    rbox("wardrobe", 7.0, 0.1, 1.25, 8.7, 1.32, 4.42, inside, bevel=0.01)
    rbox("wardrobe", 7.0, 0.6, 4.02, 8.7, 0.66, 4.08, mat("chrome", 0xC3C8D2, rough=0.2, metal=1.0), 0.02)
    rbox("wardrobe", 6.9, 0.15, 0.12, 8.8, 1.33, 1.15, wood, bevel=0.03)
    rbox("wardrobe", 7.6, 1.33, 0.6, 8.1, 1.37, 0.68, mat("handle", 0xD8C7A8), 0.02)
    rbox("wardrobe", 7.0, 0.2, 4.6, 7.8, 1.0, 5.1, mat("boxRed", 0xE8455A, rough=0.6), 0.04)
    rbox("wardrobe", 7.9, 0.25, 4.6, 8.6, 0.95, 4.95, mat("boxBlack", C["ink"], rough=0.6), 0.04)


def build_shop():
    body = mat("vendBody", 0x232638, rough=0.35, metal=0.2)
    glass = mat("vendGlass", 0x14324A, rough=0.05, emit=0x2E8CA8, emit_strength=0.0)
    rbox("shop", 9.0, 0.1, 0.0, 10.0, 1.2, 3.6, body, bevel=0.06)
    rbox("shop", 9.1, 1.18, 1.4, 9.72, 1.22, 3.4, glass, bevel=0.01, segments=1)
    can_colors = [0xFF5C9D, 0xFFD23F, 0x6CC47A]
    for row in range(3):
        for col in range(3):
            x = 9.2 + col * 0.19
            z = 1.6 + row * 0.6
            cyl("shop", x, 1.05, z, z + 0.36, 0.065, mat(f"vendCan{(row + col) % 3}", can_colors[(row + col) % 3], rough=0.3, metal=0.4), verts=16, bevel=0.01)
    side = mat("vendSide", 0x2F3557, rough=0.4)
    rbox("shop", 9.76, 1.18, 1.4, 9.95, 1.22, 3.4, side, bevel=0.01, segments=1)
    bolt = mat("bolt", C["yellow"], rough=0.4, emit=C["yellow"], emit_strength=0.0)
    rbox("shop", 9.82, 1.2, 2.5, 9.9, 1.24, 2.85, bolt, 0.01, 1)
    rbox("shop", 9.8, 1.2, 2.2, 9.88, 1.24, 2.52, bolt, 0.01, 1)
    rbox("shop", 9.2, 1.18, 0.35, 9.8, 1.23, 0.8, mat("tray", 0x0B0C12, rough=0.5), 0.02)
    rbox("shop", 9.08, 1.18, 3.44, 9.95, 1.22, 3.52, mat("vendStrip", C["cyan"], rough=0.3, emit=C["cyan"], emit_strength=0.0), 0.01, 1)


def build_floor_lamp():
    base = mat("lampPole", 0x22242E, rough=0.35, metal=0.4)
    cyl("floorLamp", 0.5, 8.4, 0.0, 0.08, 0.28, base)
    cyl("floorLamp", 0.5, 8.4, 0.08, 2.4, 0.035, base)
    cyl("floorLamp", 0.5, 8.4, 2.35, 3.0, 0.3, mat("floorShade", C["red"], rough=0.8, emit=0xFF8A80, emit_strength=0.0), verts=32)


# ------------------------------------------------------------------------------------------------ items


def build_items():
    pot = mat("pot", C["terracotta"], rough=0.8)
    soil = mat("soil", 0x4A3426, rough=1.0)
    leafm = mat("leaf", C["leaf"], rough=0.6)
    # Floor plant, front-left corner.
    x, y = 1.5, 9.3
    cyl("item-plant", x, y, 0.0, 0.55, 0.26, pot)
    cyl("item-plant", x, y, 0.5, 0.56, 0.23, soil)
    for i in range(9):
        a = i * 40
        leaf("item-plant", x + 0.25 * math.cos(math.radians(a)), y + 0.25 * math.sin(math.radians(a)), 1.0 + (i % 3) * 0.25, 1.0, a, 35 + (i % 3) * 15, leafm, width=0.2)
    # Standing punching bag, sports corner.
    x, y = 5.9, 3.1
    base = mat("bagBase", C["ink"], rough=0.5)
    red = mat("bagRed", 0xD8343F, rough=0.55, sheen=0.2)
    strap = mat("bagStrap", 0x2F3557, rough=0.6)
    cyl("item-bag", x, y, 0.0, 0.3, 0.4, base, bevel=0.08)
    cyl("item-bag", x, y, 0.3, 0.5, 0.12, base)
    cyl("item-bag", x, y, 0.5, 2.3, 0.28, red, bevel=0.06)
    sphere("item-bag", x, y, 2.3, 0.28, red, scale=(1, 1, 0.6))
    for z in (1.0, 1.8):
        cyl("item-bag", x, y, z, z + 0.08, 0.29, strap, bevel=0.01)
    # Cactus on the desk.
    x, y, z = 0.6, 3.0, 1.36
    cyl("item-cactus", x, y, z, z + 0.22, 0.12, mat("cactusPot", 0xF4F1EA, rough=0.5))
    sphere("item-cactus", x, y, z + 0.42, 0.11, mat("cactus", 0x5DAA6A, rough=0.7), scale=(1, 1, 2.0))
    sphere("item-cactus", x + 0.05, y + 0.12, z + 0.45, 0.05, mat("cactus", 0x5DAA6A), scale=(1, 1, 1.6))
    # Speaker by the sofa.
    x, y = 2.6, 8.5
    rbox("item-speaker", x - 0.22, y - 0.22, 0.0, x + 0.22, y + 0.22, 0.8, mat("speaker", 0x22242E, rough=0.4), bevel=0.06)
    for z, r in ((0.55, 0.12), (0.25, 0.09)):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=r, depth=0.04, location=B(x, y + 0.23, z), rotation=(0, math.pi / 2, 0))
        o = bpy.context.active_object
        o.rotation_euler = (math.pi / 2, 0, 0)
        o.data.materials.append(mat("cone", 0x3EF0FF, rough=0.4, emit=0x3EF0FF, emit_strength=0.0))
        add("item-speaker", o)
    # Sports wall on the back wall between the window and the wardrobe: gloves on a hook, a racket, a snowboard.
    hook = mat("hook", 0xC3C8D2, rough=0.2, metal=1.0)
    rbox("item-gloves", 4.35, 0.0, 3.85, 4.45, 0.12, 3.95, hook, 0.02)
    glove = mat("glove", 0xD8343F, rough=0.45, sheen=0.2)
    for dx, dz in ((-0.12, 0.0), (0.12, -0.08)):
        sphere("item-gloves", 4.4 + dx, 0.16, 3.4 + dz, 0.17, glove, scale=(1, 0.8, 1.3))
        cyl("item-gloves", 4.4 + dx, 0.16, 3.55 + dz, 3.75 + dz, 0.09, mat("cuff", 0xF4F1EA, rough=0.6))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.32, minor_radius=0.035, location=B(4.85, 0.1, 3.8))
    o = bpy.context.active_object
    o.scale = (0.75, 1.0, 1.0)
    o.rotation_euler = (0, math.pi / 2, math.pi / 2)
    o.data.materials.append(mat("racket", 0x3EC8FF, rough=0.35))
    add("item-racket", o)
    rbox("item-racket", 4.82, 0.06, 2.9, 4.88, 0.14, 3.5, mat("grip", C["ink"], rough=0.6), 0.02)
    board = mat("board", 0xFFD23F, rough=0.35)
    o = rbox("item-snowboard", 5.12, 0.05, 0.05, 5.5, 0.16, 3.6, board, bevel=0.08, segments=6)
    o.rotation_euler = (math.radians(-6), 0, 0)
    rbox("item-snowboard", 5.16, 0.17, 2.4, 5.46, 0.19, 2.9, mat("boardStripe", C["pink"], rough=0.4), 0.02)
    # Bench press under the sports wall: a padded bench, a rack and a bar with plates.
    pad = mat("benchPad", C["navy"], rough=0.7, grain="fabric")
    steel = mat("steel", 0x2A2C34, rough=0.3, metal=0.8)
    chrome = mat("chrome", 0xC3C8D2, rough=0.2, metal=1.0)
    cushion("item-bench", 4.3, 1.5, 0.45, 4.85, 3.0, 0.62, pad, puff=0.08)
    rbox("item-bench", 4.5, 1.6, 0.0, 4.65, 2.9, 0.45, steel, 0.02)
    for x in (3.95, 5.2):
        rbox("item-bench", x - 0.06, 1.05, 0.0, x + 0.06, 1.17, 1.9, steel, 0.02)
        rbox("item-bench", x - 0.25, 1.0, 0.0, x + 0.25, 1.3, 0.06, steel, 0.02)
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.03, depth=2.1, location=B(4.575, 1.2, 1.75))
    o = bpy.context.active_object
    o.rotation_euler = (math.pi / 2, 0, 0)
    o.data.materials.append(chrome)
    add("item-bench", o)
    for x in (3.75, 5.4):
        bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.24, depth=0.08, location=B(x, 1.2, 1.75))
        o = bpy.context.active_object
        o.rotation_euler = (math.pi / 2, 0, 0)
        o.data.materials.append(mat("plate", 0x1B1C26, rough=0.5))
        add("item-bench", o)


# --------------------------------------------------------------------------------------------- lighting

LIGHTS = {"day": [], "night": []}


def light(kind, name, ltype, loc, energy, color, size=1.0, rot=None):
    data = bpy.data.lights.new(name, ltype)
    data.energy = energy
    data.color = hexcolor(color)[:3]
    if ltype == "AREA":
        data.size = size
    elif ltype in ("POINT", "SPOT"):
        data.shadow_soft_size = size
    elif ltype == "SUN":
        data.angle = math.radians(size)
    o = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(o)
    o.location = loc
    if rot:
        o.rotation_euler = rot
    LIGHTS[kind].append(o)
    return o


def look(o, target):
    d = Vector(target) - o.location
    o.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


def build_lights():
    # Day: soft key from the front left, sun through the window, warm sky fill.
    k = light("day", "key", "AREA", B(4, 16, 12), 2600, 0xFFF4E6, size=10)
    look(k, B(5, 5, 0))
    s = light("day", "sun", "SUN", (0, 0, 0), 4.5, 0xFFE9C4, size=3)
    s.rotation_euler = (math.radians(55), 0, math.radians(-20))
    s.location = B(2.2, -6, 7)
    look(s, B(2.2, 3.5, 0))
    # Night: dim cool key, moonlight through the window, warm practical lights.
    k = light("night", "nightKey", "AREA", B(4, 16, 12), 420, 0x9AA8FF, size=10)
    look(k, B(5, 5, 0))
    m = light("night", "moon", "AREA", B(2.3, -2.5, 5.5), 260, 0x8FA6FF, size=2.5)
    look(m, B(2.6, 3.0, 0))
    light("night", "floorLampL", "POINT", B(0.5, 8.4, 2.7), 140, 0xFF9A8A, size=0.3)
    light("night", "bedLampL", "POINT", B(9.45, 4.05, 1.45), 70, 0xFFC66B, size=0.2)
    light("night", "deskLampL", "POINT", B(0.5, 0.85, 1.8), 45, 0xFFC66B, size=0.15)
    light("night", "vendL", "AREA", B(9.4, 1.6, 2.4), 60, 0x6FE8FF, size=0.8)


def set_time(kind):
    world = bpy.context.scene.world
    bg = world.node_tree.nodes["Background"]
    if kind == "day":
        bg.inputs["Color"].default_value = hexcolor(0xFFF1DE)
        bg.inputs["Strength"].default_value = 0.55
    else:
        bg.inputs["Color"].default_value = hexcolor(0x2A3060)
        bg.inputs["Strength"].default_value = 0.12
    for k, objs in LIGHTS.items():
        for o in objs:
            o.hide_render = k != kind
    night = kind == "night"
    for name, strength in (
        ("shade", 3.0),
        ("bedLampShade", 4.0),
        ("floorShade", 5.0),
        ("vendGlass", 1.6),
        ("vendStrip", 3.0),
        ("bolt", 2.0),
        ("cone", 1.5),
    ):
        m = MATS.get(name)
        if m:
            m.node_tree.nodes["Principled BSDF"].inputs["Emission Strength"].default_value = strength if night else 0.0


# ------------------------------------------------------------------------------------------------ camera


def build_camera(scale):
    cam = bpy.data.cameras.new("iso")
    cam.type = "ORTHO"
    cam.ortho_scale = CANVAS[2] * ISO / UNIT
    o = bpy.data.objects.new("iso", cam)
    bpy.context.scene.collection.objects.link(o)
    bpy.context.scene.camera = o
    # The canvas middle sits over this floor point; see HomeGrid.floor(at:).
    mid = (CANVAS[0] + CANVAS[2] / 2, CANVAS[1] + CANVAS[3] / 2)
    cx = math.cos(math.pi / 6) * UNIT
    a = (mid[0] - ORIGIN[0]) / cx
    b = (mid[1] - ORIGIN[1]) / (0.5 * UNIT)
    target = B((a + b) / 2, (b - a) / 2, 0)
    el = math.atan(1 / math.sqrt(2))
    d = Vector((math.cos(el) * math.cos(math.pi / 4), math.cos(el) * math.sin(math.pi / 4), math.sin(el)))
    o.location = target + d * 60
    look(o, target)
    cam.clip_end = 200
    r = bpy.context.scene.render
    r.resolution_x = int(CANVAS[2] * scale)
    r.resolution_y = int(CANVAS[3] * scale)
    r.resolution_percentage = 100
    return o


def check_projection(cam):
    from bpy_extras.object_utils import world_to_camera_view

    scene = bpy.context.scene
    bpy.context.view_layer.update()
    worst = 0.0
    for p in ((0, 0, 0), (10, 0, 0), (0, 10, 0), (10, 10, 0), (3, 7, 2.5), (0, 0, 6.2)):
        v = world_to_camera_view(scene, cam, B(*p))
        px = CANVAS[0] + v.x * CANVAS[2]
        py = CANVAS[1] + (1 - v.y) * CANVAS[3]
        ex = plan(*p)
        worst = max(worst, abs(px - ex[0]), abs(py - ex[1]))
    if worst > 0.5:
        raise SystemExit(f"camera does not match HomeGrid.plan (off by {worst:.2f} px)")
    print(f"camera matches HomeGrid.plan within {worst:.3f} px")


# ------------------------------------------------------------------------------------------------ render


# Colours the room can be painted in, as HomePaintable.swatches lists them; the first is the default render.
# Each paintable: the materials it recolours (with how much lighter each one is) and the layers that show them.
PAINT = {
    "sofa": ([("sofa", 1.0), ("sofaSeat", 1.25)], ["sofaBack", "sofaFarArm", "sofaSeat", "sofaNearArm"],
             [0x3A6B58, 0xFF8FC8, 0xFF9F43]),
    "bed": ([("duvet", 1.0)], ["blanket", "blanketCover"], [0x2D3250, 0xC7A6FF, 0xFF3B4E]),
    "rug": ([("rug", 1.0), ("rugEdge", 1.45)], ["rug"], [0xEADCC2, 0x7CFF4F, 0xFFE14D]),
    "walls": ([("wall", 1.0)], ["shell"], [0xDDEBD9, 0xE3E0F5, 0xF7D9D9]),
}


ORIGINAL = {}


def paint(materials, color):
    """Recolours `materials` from `color`, or back to how they were built when `color` is None."""
    for name, lift in materials:
        m = bpy.data.materials.get(name)
        if not m:
            continue
        socket = m.node_tree.nodes["Principled BSDF"].inputs["Base Color"]
        ORIGINAL.setdefault(name, tuple(socket.default_value))
        if color is None:
            socket.default_value = ORIGINAL[name]
        else:
            socket.default_value = [min(1.0, v * lift) for v in hexcolor(color)[:3]] + [1.0]


def border(objs, margin=16):
    """Renders only the part of the frame around `objs`; the rest stays transparent."""
    from bpy_extras.object_utils import world_to_camera_view

    scene = bpy.context.scene
    deps = bpy.context.evaluated_depsgraph_get()
    xs, ys = [], []
    for o in objs:
        e = o.evaluated_get(deps)
        for corner in e.bound_box:
            v = world_to_camera_view(scene, scene.camera, e.matrix_world @ Vector(corner))
            xs.append(v.x)
            ys.append(v.y)
    r = scene.render
    mx, my = margin / CANVAS[2], margin / CANVAS[3]
    r.use_border = True
    r.use_crop_to_border = False
    r.border_min_x, r.border_max_x = max(0.0, min(xs) - mx), min(1.0, max(xs) + mx)
    r.border_min_y, r.border_max_y = max(0.0, min(ys) - my), min(1.0, max(ys) + my)


def render_layer(name, kind, out, scale, layer=None):
    scene = bpy.context.scene
    layer = layer or name
    mine = set(id(o) for o in LAYERS[layer])
    # Items that are not bought yet must not cast shadows into the furniture renders.
    for other, objs in LAYERS.items():
        is_item = other.startswith("item-") and other != layer
        for o in objs:
            o.visible_camera = id(o) in mine
            o.hide_render = is_item
            # The two blankets never show together; the cover only renders when it is the layer.
            if other == "blanketCover" and layer != "blanketCover":
                o.hide_render = True
            if other == "blanket" and layer == "blanketCover":
                o.hide_render = True
    border(LAYERS[layer])
    path = os.path.join(out, f"raw-{name}-{kind}.png")
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)
    return path


def crop(path, name, kind, out, scale):
    import numpy as np

    src = bpy.data.images.load(path)
    w, h = src.size
    px = np.empty(w * h * 4, dtype=np.float32)
    src.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)
    rows = np.where(px[:, :, 3].max(axis=1) > 0.004)[0]
    cols = np.where(px[:, :, 3].max(axis=0) > 0.004)[0]
    if len(rows) == 0:
        bpy.data.images.remove(src)
        os.remove(path)
        return None
    pad = 2
    miny, maxy = max(0, rows[0] - pad), min(h - 1, rows[-1] + pad)
    minx, maxx = max(0, cols[0] - pad), min(w - 1, cols[-1] + pad)
    cw, ch = int(maxx - minx + 1), int(maxy - miny + 1)
    part = np.ascontiguousarray(px[miny : maxy + 1, minx : maxx + 1, :]).ravel()
    dst = bpy.data.images.new(f"{name}-{kind}", cw, ch, alpha=True)
    dst.pixels.foreach_set(part)
    dst.filepath_raw = os.path.join(out, f"home-{name}-{kind}.png")
    dst.file_format = "PNG"
    dst.save()
    bpy.data.images.remove(src)
    bpy.data.images.remove(dst)
    os.remove(path)
    # Blender's image rows start at the bottom; plan y points down.
    return {
        "x": round(CANVAS[0] + int(minx) / scale, 2),
        "y": round(CANVAS[1] + (h - 1 - int(maxy)) / scale, 2),
        "width": round(cw / scale, 2),
        "height": round(ch / scale, 2),
    }


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=os.path.join(os.path.dirname(__file__), "..", "..", "Sources", "CompanionKit", "Resources"))
    ap.add_argument("--scale", type=float, default=2.0)
    ap.add_argument("--samples", type=int, default=64)
    ap.add_argument("--only", default="")
    ap.add_argument("--time", default="day,night")
    ap.add_argument("--paint", default="all", help="paintables to render colour variants for, or none")
    args = ap.parse_args(argv)
    out = os.path.abspath(args.out)
    os.makedirs(out, exist_ok=True)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = args.samples
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    world = bpy.data.worlds.new("world")
    world.use_nodes = True
    scene.world = world

    cam = build_camera(args.scale)
    check_projection(cam)
    build_shell()
    build_desk()
    build_chair()
    build_shelf()
    build_posters()
    build_sofa()
    build_table_rug()
    build_bed()
    build_wardrobe()
    build_shop()
    build_floor_lamp()
    build_items()
    build_lights()

    names = [n for n in LAYERS if not args.only or n in args.only.split(",")]
    manifest_path = os.path.join(out, "home-layers.json")
    manifest = {}
    if os.path.exists(manifest_path):
        with open(manifest_path) as f:
            manifest = json.load(f)
    manifest.setdefault("layers", {})
    manifest["scale"] = args.scale
    for kind in args.time.split(","):
        set_time(kind)
        for name in names:
            raw = render_layer(name, kind, out, args.scale)
            rect = crop(raw, name, kind, out, args.scale)
            if rect:
                manifest["layers"].setdefault(name, {})[kind] = rect
            print(f"rendered {name} {kind} {rect}", flush=True)
        for key, (materials, layers, swatches) in PAINT.items():
            if args.paint != "all" and key not in args.paint.split(","):
                continue
            for i, color in enumerate(swatches, start=1):
                paint(materials, color)
                for layer in layers:
                    if args.only and layer not in args.only.split(","):
                        continue
                    name = f"{layer}_{i}"
                    raw = render_layer(name, kind, out, args.scale, layer=layer)
                    rect = crop(raw, name, kind, out, args.scale)
                    if rect:
                        manifest["layers"].setdefault(name, {})[kind] = rect
                    print(f"rendered {name} {kind} {rect}", flush=True)
            paint(materials, None)
    from shrink_pngs import shrink

    for name in sorted(os.listdir(out)):
        if name.startswith("home-") and name.endswith(".png"):
            shrink(os.path.join(out, name))
    manifest["layers"] = dict(sorted(manifest["layers"].items()))
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2, sort_keys=True)
        f.write("\n")


if __name__ == "__main__":
    main()
