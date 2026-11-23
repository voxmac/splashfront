"""SPLASH FRONT 3D models, built procedurally with Blender (bpy) — same approach as MOIMEUN's landmark GLB generator.
usage: python tools/make_models.py assets/models
Each item = one FBX with up to three meshes, named for the game code:
  <Item>_Body    painted by the weapon skin (Cosmetics) or a dark default
  <Item>_Accent  team colour (neon stripes, ink tanks)
  <Item>_Metal   fixed light metal
Units: 1 Blender unit = 1 stud. Guns point along +Y (FBX forward -Z = Roblox LookVector), grip at the origin.
Also writes preview PNGs and models.json (triangle counts, sizes)."""
import json, math, os, sys
import bpy, bmesh
from mathutils import Vector

OUT = sys.argv[-1] if len(sys.argv) > 1 and not sys.argv[-1].endswith(".py") else "assets/models"
os.makedirs(OUT, exist_ok=True)

COLORS = {"Body": (0.12, 0.12, 0.15, 1), "Accent": (1.0, 0.18, 0.67, 1), "Metal": (0.72, 0.74, 0.78, 1),
          "Anchor": (0, 1, 0, 1), "Muzzle": (1, 0, 0, 1)}
# Anchor / Muzzle: 0.05-stud marker meshes. The game hides them and uses them as the hold point (grip, head centre,
# back of the torso) and the shot origin, so placement never depends on how an importer sets the model pivot.
MUZZLE = {"Gun_Pistol": (0, 1.31, 0.08), "Gun_Rifle": (0, 2.11, 0.12), "Gun_SMG": (0, 1.29, 0.1), "Gun_Shotgun": (0, 1.95, 0.12),
          "Gun_Sniper": (0, 2.92, 0.1), "Gun_Launcher": (0, 1.50, 0.12)}


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, c in COLORS.items():
        m = bpy.data.materials.new(name); m.diffuse_color = c


def mat(obj, kind):
    obj.data.materials.clear(); obj.data.materials.append(bpy.data.materials[kind]); obj["kind"] = kind
    return obj


def bevel(obj, w=0.03, seg=2):
    m = obj.modifiers.new("bevel", "BEVEL"); m.width = w; m.segments = seg; m.limit_method = "ANGLE"
    return obj


def box(name, size, loc, kind="Body", rot=(0, 0, 0), bev=0.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    return bevel(mat(o, kind), bev) if bev else mat(o, kind)


def cyl(name, r, depth, loc, kind="Body", axis="Y", verts=20, rot=None, bev=0.015):
    r_ = {"Y": (math.radians(90), 0, 0), "X": (0, math.radians(90), 0), "Z": (0, 0, 0)}[axis] if rot is None else rot
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth, location=loc, rotation=r_)
    o = bpy.context.active_object; o.name = name
    return bevel(mat(o, kind), bev, 1) if bev else mat(o, kind)


def sphere(name, r, loc, kind="Accent", scale=(1, 1, 1), seg=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object; o.name = name; o.scale = scale
    bpy.ops.object.transform_apply(scale=True)
    return mat(o, kind)


def torus(name, R, r, loc, kind="Metal", rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=R, minor_radius=r, major_segments=20, minor_segments=8, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    return mat(o, kind)


def cone(name, r1, r2, depth, loc, kind="Metal", axis="Y"):
    rot = {"Y": (math.radians(-90), 0, 0), "Z": (0, 0, 0)}[axis]
    bpy.ops.mesh.primitive_cone_add(vertices=20, radius1=r1, radius2=r2, depth=depth, location=loc, rotation=rot)
    o = bpy.context.active_object; o.name = name
    return mat(o, kind)


def finish(item):
    """Apply modifiers, join per material kind -> <item>_Body/_Accent/_Metal, export FBX, return stats."""
    groups = {}
    for o in list(bpy.data.objects):
        if o.type != "MESH": continue
        bpy.context.view_layer.objects.active = o
        for m in list(o.modifiers): bpy.ops.object.modifier_apply(modifier=m.name)
        groups.setdefault(o["kind"], []).append(o)
    stats = {"parts": {}}
    for kind, objs in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for o in objs: o.select_set(True)
        bpy.context.view_layer.objects.active = objs[0]
        if len(objs) > 1: bpy.ops.object.join()
        o = bpy.context.active_object; o.name = f"{item}_{kind}"; o.data.name = o.name
        bpy.ops.object.shade_auto_smooth(angle=math.radians(35)) if hasattr(bpy.ops.object, "shade_auto_smooth") else None
        me = o.data; me.calc_loop_triangles()
        stats["parts"][kind] = len(me.loop_triangles)
    bpy.ops.object.select_all(action="SELECT")
    pts = [o.matrix_world @ Vector(c) for o in bpy.data.objects if o.type == "MESH" for c in o.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    stats["size_xyz"] = [round(v, 2) for v in (hi - lo)]
    stats["triangles"] = sum(stats["parts"].values())
    bpy.ops.export_scene.fbx(filepath=f"{OUT}/{item}.fbx", use_selection=True, axis_forward="-Z", axis_up="Y",
                             apply_unit_scale=True, global_scale=1.0, object_types={"MESH"}, mesh_smooth_type="FACE",
                             use_mesh_modifiers=True, add_leaf_bones=False)
    return stats


# ---------------------------------------------------------------- guns (grip at origin, barrel along +Y)
def g_common_grip(kind="Body", tilt=18):
    box("grip", (0.22, 0.26, 0.55), (0, -0.05, -0.3), kind, rot=(math.radians(-tilt), 0, 0))
    torus("guard", 0.13, 0.025, (0, 0.14, -0.14), "Metal", rot=(0, math.radians(90), 0))

def gun_pistol():
    g_common_grip()
    box("body", (0.28, 1.0, 0.34), (0, 0.3, 0.05))
    box("slide", (0.3, 0.7, 0.12), (0, 0.4, 0.26), "Metal", bev=0.02)
    cyl("barrel", 0.09, 0.5, (0, 0.95, 0.08), "Metal")
    cone("nozzle", 0.12, 0.06, 0.12, (0, 1.24, 0.08))
    sphere("ink", 0.17, (0, 0.05, 0.36), "Accent")
    box("stripe", (0.3, 0.6, 0.05), (0, 0.35, -0.08), "Accent", bev=0.01)

def gun_rifle():
    g_common_grip()
    box("body", (0.3, 1.5, 0.4), (0, 0.45, 0.05))
    box("stock", (0.24, 0.9, 0.34), (0, -0.75, 0.0), rot=(math.radians(6), 0, 0))
    cyl("barrel", 0.08, 0.9, (0, 1.55, 0.12), "Metal")
    cyl("shroud", 0.13, 0.5, (0, 1.25, 0.12), "Body", verts=8)
    cone("nozzle", 0.11, 0.07, 0.12, (0, 2.04, 0.12))
    cyl("cartridge", 0.13, 0.45, (0, 0.55, -0.35), "Accent", axis="Z")
    box("rail", (0.12, 0.8, 0.06), (0, 0.45, 0.3), "Metal", bev=0.01)
    box("sight", (0.1, 0.18, 0.14), (0, 0.65, 0.39), "Metal", bev=0.01)
    box("fore", (0.16, 0.2, 0.3), (0, 1.0, -0.22), rot=(math.radians(-10), 0, 0))
    box("stripe", (0.32, 1.2, 0.05), (0, 0.45, -0.12), "Accent", bev=0.01)

def gun_smg():
    g_common_grip()
    box("body", (0.3, 1.05, 0.38), (0, 0.32, 0.05))
    cyl("drum", 0.25, 0.22, (0.24, 0.35, -0.08), "Accent", axis="X", verts=24)
    cyl("barrel", 0.08, 0.45, (0, 1.05, 0.1), "Metal")
    for i in range(3): cyl(f"ring{i}", 0.11, 0.04, (0, 0.92 + i * 0.1, 0.1), "Metal", bev=0)
    box("stockbar", (0.06, 0.6, 0.06), (0, -0.45, 0.1), "Metal", bev=0.01)
    box("stockpad", (0.2, 0.08, 0.32), (0, -0.75, 0.0), bev=0.02)
    box("stripe", (0.32, 0.8, 0.05), (0, 0.32, 0.27), "Accent", bev=0.01)

def gun_shotgun():
    g_common_grip()
    box("body", (0.36, 1.3, 0.42), (0, 0.35, 0.05))
    box("stock", (0.28, 0.85, 0.38), (0, -0.7, -0.02), rot=(math.radians(8), 0, 0))
    for x in (-0.09, 0.09): cyl(f"barrel{x}", 0.09, 0.9, (x, 1.35, 0.12), "Metal")
    cone("flare", 0.24, 0.16, 0.16, (0, 1.86, 0.12))
    box("pump", (0.3, 0.45, 0.2), (0, 1.15, -0.1), "Metal", bev=0.04)
    cyl("tank", 0.14, 0.7, (0, 0.35, 0.38), "Accent")
    box("stripe", (0.38, 1.0, 0.05), (0, 0.35, -0.15), "Accent", bev=0.01)

def gun_sniper():
    g_common_grip(tilt=12)
    box("body", (0.28, 1.4, 0.36), (0, 0.4, 0.05))
    box("stock", (0.22, 1.0, 0.42), (0, -0.85, -0.02), rot=(math.radians(4), 0, 0))
    box("cheek", (0.2, 0.4, 0.1), (0, -0.7, 0.25), bev=0.03)
    cyl("barrel", 0.065, 1.7, (0, 1.95, 0.1), "Metal")
    cone("nozzle", 0.1, 0.06, 0.12, (0, 2.85, 0.1))
    cyl("scope", 0.11, 0.9, (0, 0.45, 0.42), "Body")
    cyl("lensF", 0.14, 0.12, (0, 0.92, 0.42), "Metal")
    cyl("lensB", 0.13, 0.1, (0, -0.02, 0.42), "Metal")
    for y in (0.2, 0.7): box(f"mount{y}", (0.08, 0.08, 0.16), (0, y, 0.28), "Metal", bev=0.01)
    cyl("pressure", 0.1, 0.9, (0, 1.4, -0.12), "Accent")
    cyl("bolt", 0.04, 0.2, (0.2, 0.1, 0.15), "Metal", axis="X")
    box("stripe", (0.3, 1.0, 0.05), (0, 0.4, -0.12), "Accent", bev=0.01)

def gun_launcher():
    g_common_grip()
    cyl("tube", 0.33, 1.7, (0, 0.55, 0.12), "Body", verts=24)
    cyl("mouth", 0.38, 0.14, (0, 1.42, 0.12), "Metal", verts=24)
    cyl("rear", 0.36, 0.1, (0, -0.3, 0.12), "Metal", verts=24)
    cyl("bucket", 0.24, 0.38, (0, 0.4, 0.62), "Accent", axis="Z", verts=20)
    torus("bucketrim", 0.24, 0.03, (0, 0.4, 0.81), "Metal")
    box("handle", (0.08, 0.5, 0.06), (0, 0.4, 0.95), "Metal", bev=0.01)
    box("fore", (0.14, 0.18, 0.32), (0, 0.95, -0.3), rot=(math.radians(-10), 0, 0))
    for y in (0.2, 0.9): torus(f"band{y}", 0.34, 0.03, (0, y, 0.12), "Accent", rot=(math.radians(90), 0, 0))

# ---------------------------------------------------------------- crew gear
def gear_helmet():
    # sized for an R15 head (about 1.2 studs); origin = head centre
    sphere("dome", 0.72, (0, 0, 0.12), "Body", scale=(1.0, 1.05, 0.85), seg=24)
    box("cut", (1.6, 1.6, 0.8), (0, 0, -0.55), "Body", bev=0)     # removed below by boolean
    dome, cut = bpy.data.objects["dome"], bpy.data.objects["cut"]
    b = dome.modifiers.new("cut", "BOOLEAN"); b.object = cut; b.operation = "DIFFERENCE"
    bpy.context.view_layer.objects.active = dome; bpy.ops.object.modifier_apply(modifier="cut")
    bpy.data.objects.remove(cut)
    torus("band", 0.7, 0.05, (0, 0, -0.12), "Accent")
    box("ridge", (0.12, 1.2, 0.1), (0, 0, 0.72), "Accent", bev=0.03)
    for x in (-0.24, 0.24):
        cyl(f"goggle{x}", 0.19, 0.12, (x, 0.66, 0.08), "Metal", verts=20)
        cyl(f"lens{x}", 0.15, 0.04, (x, 0.73, 0.08), "Accent", verts=20)
    box("strap", (0.12, 0.06, 0.08), (0, 0.66, 0.08), "Metal", bev=0.01)
    for x in (-0.74, 0.74): cyl(f"ear{x}", 0.16, 0.1, (x, 0, -0.08), "Metal", axis="X")

def gear_backpack():
    # origin = centre of the UpperTorso's back surface; the pack sits behind it: -Y (exported as Roblox +Z, the back)
    box("frame", (0.9, 0.18, 1.1), (0, -0.12, 0), "Body", bev=0.05)
    cyl("tank", 0.36, 1.15, (0, -0.5, 0.05), "Accent", axis="Z", verts=24)
    for z in (-0.55, 0.65): cyl(f"cap{z}", 0.38, 0.1, (0, -0.5, z), "Metal", axis="Z", verts=24)
    for z in (-0.25, 0.3): torus(f"belt{z}", 0.37, 0.03, (0, -0.5, z), "Metal")
    cyl("valve", 0.08, 0.22, (0, -0.5, 0.8), "Metal", axis="Z")
    # hose from the valve over the right shoulder toward the gun
    cyl("hose1", 0.045, 0.5, (0.18, -0.38, 0.92), "Body", rot=(math.radians(60), 0, math.radians(-30)), bev=0)
    cyl("hose2", 0.045, 0.45, (0.36, -0.08, 0.98), "Body", rot=(math.radians(90), 0, math.radians(-20)), bev=0)
    for x in (-0.3, 0.3): box(f"strap{x}", (0.12, 0.06, 1.0), (x, 0.0, 0.05), "Body", bev=0.02)


ITEMS = {
    "Gun_Pistol": gun_pistol, "Gun_Rifle": gun_rifle, "Gun_SMG": gun_smg, "Gun_Shotgun": gun_shotgun,
    "Gun_Sniper": gun_sniper, "Gun_Launcher": gun_launcher, "Gear_Helmet": gear_helmet, "Gear_Backpack": gear_backpack,
}


def preview(item):
    scn = bpy.context.scene
    scn.render.engine = "BLENDER_WORKBENCH"
    scn.display.shading.light = "STUDIO"; scn.display.shading.color_type = "MATERIAL"
    scn.display.shading.show_cavity = True; scn.display.shading.show_shadows = False
    scn.render.resolution_x = scn.render.resolution_y = 420
    scn.render.film_transparent = False
    if scn.world is None: scn.world = bpy.data.worlds.new("w")
    pts = [o.matrix_world @ Vector(c) for o in bpy.data.objects if o.type == "MESH" for c in o.bound_box]
    ctr = sum(pts, Vector()) / len(pts); rad = max((p - ctr).length for p in pts)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); scn.collection.objects.link(cam); scn.camera = cam
    d = rad * 3.3
    cam.location = ctr + Vector((d * 0.75, -d * 0.35, d * 0.45))
    cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
    scn.render.filepath = f"{OUT}/preview_{item}.png"
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    report = {}
    for item, fn in ITEMS.items():
        reset(); fn()
        box("anchor", (0.05, 0.05, 0.05), (0, 0, 0), "Anchor", bev=0)
        if item in MUZZLE: box("muzzle", (0.05, 0.05, 0.05), MUZZLE[item], "Muzzle", bev=0)
        report[item] = finish(item)
        preview(item)
        print(item, report[item], flush=True)
    json.dump(report, open(f"{OUT}/models.json", "w"), indent=1)
