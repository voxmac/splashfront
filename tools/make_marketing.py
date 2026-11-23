"""SPLASH FRONT store art — 3D renders (Blender Cycles + Freestyle cartoon outlines).
usage: python tools/make_marketing.py [shot ...]      shots: key, sniper, map, icon   (default: all)
Writes assets/marketing/raw_<shot>.png ; tools/compose_marketing.py then adds the logo and text.
Reuses the in-game gun builders from tools/make_models.py so the art matches the game."""
import math, os, random, sys
import bpy
from mathutils import Vector, Euler

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = os.path.join(ROOT, "assets", "marketing")
os.makedirs(OUT, exist_ok=True)
sys.argv = [sys.argv[0]] + [a for a in sys.argv[1:]]
SHOTS = [a for a in sys.argv[1:] if not a.endswith(".py")] or ["key", "sniper", "map", "icon"]
sys.path.insert(0, HERE)
_argv = sys.argv
sys.argv = ["make_models.py", os.path.join(OUT, "_tmp_models")]
import make_models as MM  # noqa: E402
sys.argv = _argv

PINK = (1.0, 0.10, 0.55)
CYAN = (0.0, 0.62, 1.0)
WHITE = (0.93, 0.94, 0.97)
SKIN = (1.0, 0.80, 0.55)


# ------------------------------------------------------------------ materials
def m(name, rgb, rough=0.45, emit=0.0, metal=0.0):
    mt = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mt.use_nodes = True
    b = mt.node_tree.nodes.get("Principled BSDF")
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*rgb, 1)
        b.inputs["Emission Strength"].default_value = emit
    mt.diffuse_color = (*rgb, 1)
    return mt


def assign(o, mt):
    o.data.materials.clear()
    o.data.materials.append(mt)
    return o


def bev(o, w=0.08, seg=3):
    md = o.modifiers.new("b", "BEVEL"); md.width = w; md.segments = seg; md.limit_method = "ANGLE"
    return o


def cube(size, loc, mt, rot=(0, 0, 0), b=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object; o.scale = size
    bpy.ops.object.transform_apply(scale=True)
    assign(o, mt)
    return bev(o, b) if b else o


def ball(r, loc, mt, scale=(1, 1, 1), seg=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object; o.scale = scale
    bpy.ops.object.shade_smooth()
    return assign(o, mt)


NOLINE = None


def noline(o):
    """바닥·페인트 얼룩은 카툰 외곽선을 그리지 않음 (지저분해짐)"""
    for c in list(o.users_collection):
        c.objects.unlink(o)
    NOLINE.objects.link(o)
    return o


_layer = [0]


def disc(r, loc, mt, h=0.03, rot=(0, 0, 0), line=False):
    """두께 없는 채운 원. 겹칠수록 아주 조금씩 위에 놓아 깜빡임·검은 얼룩이 없게"""
    _layer[0] += 1
    off = _layer[0] * 0.0015
    if rot == (0, 0, 0):
        loc = (loc[0], loc[1], 0.01 + off)
    else:
        loc = (loc[0], loc[1] - off, loc[2])
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=r, fill_type="NGON", location=loc, rotation=rot)
    o = bpy.context.active_object
    assign(o, mt)
    return o if line else noline(o)


# ------------------------------------------------------------------ scene pieces
def splat(cx, cy, r, mt, rng, z=0.0):
    """페인트 얼룩: 큰 원 + 주변 겹친 원 + 흩뿌린 방울"""
    disc(r, (cx, cy, z + 0.02), mt)
    for _ in range(rng.randint(4, 7)):
        a = rng.random() * math.tau; d = r * rng.uniform(0.5, 0.95)
        disc(r * rng.uniform(0.35, 0.6), (cx + math.cos(a) * d, cy + math.sin(a) * d, z + 0.021), mt)
    for _ in range(rng.randint(5, 10)):
        a = rng.random() * math.tau; d = r * rng.uniform(1.15, 1.8)
        disc(r * rng.uniform(0.06, 0.16), (cx + math.cos(a) * d, cy + math.sin(a) * d, z + 0.022), mt)


def floor(size, mats, rng, n=60, spread=None, ymin=None):
    noline(cube((size, size, 1), (0, 0, -0.5), mats["floor"], b=0))
    # 줄눈 (타일 느낌)
    for k in range(-int(size / 2), int(size / 2) + 1, 4):
        noline(cube((size, 0.05, 0.01), (0, k, 0.004), mats["grout"], b=0))
        noline(cube((0.05, size, 0.01), (k, 0, 0.004), mats["grout"], b=0))
    spread = spread or size * 0.42
    for i in range(n):
        x = rng.uniform(-spread, spread); y = rng.uniform(ymin if ymin is not None else -spread, spread)
        # 왼쪽은 분홍, 오른쪽은 하늘 우세
        side = mats["pink"] if (x + rng.uniform(-6, 6)) < 0 else mats["cyan"]
        splat(x, y, rng.uniform(0.8, 2.6), side, rng)


def crate(loc, s, mats, rot=0):
    o = cube((s, s, s), (loc[0], loc[1], s / 2), mats["wood"], rot=(0, 0, rot), b=0.06)
    for sx in (-1, 1):
        for sy in (-1, 1):
            p = Vector((sx * (s / 2 - 0.09), sy * (s / 2 - 0.09), 0))
            p.rotate(Euler((0, 0, rot)))
            cube((0.2, 0.2, s + 0.02), (loc[0] + p.x, loc[1] + p.y, s / 2), mats["wood_dark"], rot=(0, 0, rot), b=0.03)
    return o


def wall(loc, size, mats, rot=0):
    cube(size, (loc[0], loc[1], size[2] / 2), mats["wall"], rot=(0, 0, rot), b=0.1)
    cube((size[0] + 0.15, size[1] + 0.15, 0.18), (loc[0], loc[1], size[2] + 0.05), mats["wall_cap"], rot=(0, 0, rot), b=0.05)


def gun(builder, team_mt, mats):
    """make_models의 총 만들기 함수로 총을 만들고 하나로 묶음 (손잡이가 원점, +Y가 총구)"""
    before = set(bpy.data.objects)
    builder()
    objs = [o for o in bpy.data.objects if o not in before]
    for o in objs:
        k = o.get("kind", "Body")
        assign(o, {"Body": mats["gun_body"], "Accent": team_mt, "Metal": mats["metal"]}.get(k, mats["gun_body"]))
    root = bpy.data.objects.new("gun", None)
    bpy.context.scene.collection.objects.link(root)
    for o in objs:
        o.parent = root
    return root


def character(loc, yaw, team_mt, mats, builder, aim_pitch=0.0, lean=0.0, crouch=0.0):
    """Roblox 느낌 블록 캐릭터 (머리·몸·팔·다리 둥근 상자) + 헬멧·조끼·총, 총을 앞으로 겨눈 자세"""
    root = bpy.data.objects.new("char", None)
    bpy.context.scene.collection.objects.link(root)
    parts = []

    def add(o):
        o.parent = root
        parts.append(o)
        return o
    hip = 2.0 - crouch
    # 다리
    for sx in (-1, 1):
        add(cube((0.48, 0.5, 1.0), (sx * 0.27, 0.0 if not crouch else -0.15, hip - 1.0 + 0.5), mats["pants"], b=0.07))
        add(cube((0.52, 0.62, 0.3), (sx * 0.27, 0.05, 0.15), mats["boot"], b=0.08))
    # 몸통 + 조끼(팀 색)
    add(cube((1.05, 0.55, 1.05), (0, 0, hip + 0.52), team_mt, b=0.09))
    add(cube((1.08, 0.6, 0.18), (0, 0, hip + 0.7), mats["armor"], b=0.05))
    add(cube((1.1, 0.62, 0.16), (0, 0, hip + 0.06), mats["belt"], b=0.04))
    # 머리 + 얼굴 + 헬멧
    add(cube((0.78, 0.74, 0.74), (0, 0, hip + 1.45), mats["skin"], b=0.16))
    for sx in (-1, 1):
        add(ball(0.075, (sx * 0.16, -0.375, hip + 1.5), mats["eye"], scale=(1, 0.4, 1.35), seg=16))
        add(cube((0.18, 0.04, 0.05), (sx * 0.17, -0.38, hip + 1.66), mats["eye"], rot=(0, sx * 0.25, 0), b=0.01))
    bpy.ops.mesh.primitive_torus_add(major_radius=0.14, minor_radius=0.025, location=(0, -0.37, hip + 1.36), rotation=(math.radians(90), 0, 0))
    smile = bpy.context.active_object
    assign(smile, mats["eye"])
    # 아래쪽 반만 남겨 웃는 입
    bpy.ops.object.mode_set(mode="EDIT")
    import bmesh
    bm = bmesh.from_edit_mesh(smile.data)
    for v in [v for v in bm.verts if v.co.y > 0]:
        bm.verts.remove(v)
    bmesh.update_edit_mesh(smile.data)
    bpy.ops.object.mode_set(mode="OBJECT")
    add(smile)
    add(ball(0.46, (0, 0.06, hip + 1.8), mats["helmet"], scale=(1, 1, 0.62), seg=32))
    add(cube((0.88, 0.1, 0.1), (0, -0.36, hip + 1.79), team_mt, b=0.04))  # 헬멧 띠
    add(cube((0.66, 0.1, 0.14), (0, -0.39, hip + 1.95), mats["visor"], b=0.04))  # 이마 위 고글
    # 팔 (앞으로 뻗어 총을 듦)
    shoulder_z = hip + 0.92
    for sx in (-1, 1):
        arm = cube((0.42, 0.95, 0.42), (0, -0.42, 0), team_mt if sx > 0 else mats["sleeve"], b=0.07)
        hand = cube((0.4, 0.3, 0.4), (0, -0.98, 0), mats["skin"], b=0.08)
        pivot = bpy.data.objects.new("shoulder", None)
        bpy.context.scene.collection.objects.link(pivot)
        arm.parent = pivot; hand.parent = pivot
        pivot.location = (sx * 0.72 * (0.85 if sx < 0 else 1), 0, shoulder_z)
        pivot.rotation_euler = (math.radians(-aim_pitch), 0, math.radians(-sx * 12 if sx > 0 else 28))
        pivot.parent = root
    g = gun(builder, team_mt, mats)
    g.parent = root
    g.location = (0.45, -1.35, shoulder_z - 0.05)
    g.rotation_euler = (math.radians(-aim_pitch), 0, math.radians(180))  # 총구(+Y) → 캐릭터 앞(-Y)
    g.scale = (1.15, 1.15, 1.15)
    root.location = (loc[0], loc[1], loc[2] if len(loc) > 2 else 0)
    root.rotation_euler = (math.radians(lean), 0, math.radians(yaw))
    return root, g


def paint_stream(start, end, mt, rng, n=14, arc=1.2):
    """총구에서 날아가는 페인트 줄기 (크기가 점점 커지는 방울)"""
    s, e = Vector(start), Vector(end)
    for i in range(n):
        t = (i + rng.random() * 0.3) / n
        p = s.lerp(e, t) + Vector((0, 0, math.sin(t * math.pi) * arc))
        r = 0.12 + t * 0.32 + rng.uniform(-0.04, 0.04)
        ball(r, p, mt, scale=(1, 1, 0.85))
    # 끝에서 튀는 왕관 모양 방울
    for k in range(12):
        a = k / 12 * math.tau
        ball(rng.uniform(0.12, 0.26), e + Vector((math.cos(a) * 0.9, math.sin(a) * 0.9, 0.35 + rng.random() * 0.8)), mt)


def setup(res, mats_override=None):
    MM.reset()  # 빈 장면 + Body/Accent/Metal 재질
    scn = bpy.context.scene
    global NOLINE
    NOLINE = bpy.data.collections.new("NoLine")
    scn.collection.children.link(NOLINE)
    scn.render.engine = "CYCLES"
    scn.cycles.device = "CPU"
    scn.cycles.samples = 28
    scn.cycles.use_denoising = True
    try:
        scn.cycles.denoiser = "OPENIMAGEDENOISE"
    except Exception:
        pass
    scn.cycles.max_bounces = 4
    scn.render.resolution_x, scn.render.resolution_y = res
    scn.render.resolution_percentage = 100
    if os.environ.get("SF_PREVIEW"):  # 빠른 미리보기
        scn.render.resolution_percentage = 30
        scn.cycles.samples = 6
    scn.view_settings.view_transform = "Standard"
    scn.view_settings.look = "None"
    # 카툰 외곽선
    scn.render.use_freestyle = True
    scn.render.line_thickness_mode = "ABSOLUTE"
    scn.render.line_thickness = 2.2 * res[0] / 1920
    ls = scn.view_layers[0].freestyle_settings.linesets[0] if scn.view_layers[0].freestyle_settings.linesets else scn.view_layers[0].freestyle_settings.linesets.new("L")
    if ls.linestyle is None:
        ls.linestyle = bpy.data.linestyles.new("cartoon")
    ls.linestyle.color = (0.10, 0.11, 0.2)
    ls.linestyle.thickness = 2.2 * res[0] / 1920
    ls.select_by_visibility = True
    ls.select_by_collection = True
    ls.collection = NOLINE
    ls.collection_negation = "EXCLUSIVE"
    ls.select_crease = True
    ls.select_silhouette = True
    ls.select_border = True
    # 하늘·햇빛
    w = bpy.data.worlds.new("sky"); scn.world = w; w.use_nodes = True
    bg = w.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.36, 0.66, 1.0, 1); bg.inputs["Strength"].default_value = 0.8
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.3; sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(48), math.radians(12), math.radians(35))
    scn.collection.objects.link(sun)
    mats = {
        "floor": m("floor", WHITE, 0.6), "grout": m("grout", (0.78, 0.81, 0.88), 0.7),
        "pink": m("pink", PINK, 0.55), "cyan": m("cyan", CYAN, 0.55),
        "wood": m("wood", (0.95, 0.55, 0.22), 0.6), "wood_dark": m("wood_dark", (0.62, 0.32, 0.12), 0.6),
        "wall": m("wall", (0.86, 0.88, 0.94), 0.5), "wall_cap": m("wall_cap", (0.98, 0.98, 1.0), 0.4),
        "skin": m("skin", SKIN, 0.5), "eye": m("eye", (0.05, 0.05, 0.08), 0.3), "pants": m("pants", (0.18, 0.2, 0.3), 0.6),
        "boot": m("boot", (0.12, 0.12, 0.16), 0.6), "armor": m("armor", (0.16, 0.17, 0.24), 0.35, metal=0.3),
        "belt": m("belt", (0.36, 0.24, 0.14), 0.6), "helmet": m("helmet", (0.95, 0.96, 1.0), 0.3),
        "visor": m("visor", (0.25, 0.9, 1.0), 0.1, emit=1.5), "sleeve": m("sleeve", (0.96, 0.96, 1.0), 0.5),
        "gun_body": m("gun_body", (0.13, 0.13, 0.17), 0.35), "metal": m("metal", (0.78, 0.8, 0.85), 0.25, metal=0.6),
        "pink_neon": m("pink_neon", PINK, 0.3, emit=2.0), "cyan_neon": m("cyan_neon", CYAN, 0.3, emit=2.0),
    }
    return scn, mats


def camera(scn, loc, target, lens=35):
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = lens
    scn.collection.objects.link(cam); scn.camera = cam
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    return cam


def render(scn, name):
    import time
    scn.render.filepath = os.path.join(OUT, f"raw_{name}.png")
    t = time.time()
    bpy.ops.render.render(write_still=True)
    print("rendered", name, round(time.time() - t, 1), "s", flush=True)


# ------------------------------------------------------------------ shots
def shot_key():
    """대표 이미지: 분홍 vs 하늘 대치, 가운데서 페인트가 부딪혀 터짐"""
    scn, mats = setup((1920, 1080))
    rng = random.Random(7)
    floor(60, mats, rng, n=70, spread=22, ymin=-6)
    crate((-2.5, 3.5), 1.6, mats, 0.3); crate((3.2, 4.5), 1.4, mats, -0.4); crate((-7, -1), 1.6, mats, 0.1)
    crate((8, 1.5), 1.6, mats, 0.6); crate((0.5, 9), 1.8, mats, 0.2)
    wall((-5, 8), (6, 0.6, 2.6), mats, 0.2); wall((6, 9), (5, 0.6, 2.6), mats, -0.3)
    # 서로 마주 보며 카메라 쪽으로 30도 틀어 얼굴이 보이게 (yaw: 앞(-Y)을 돌리는 각도)
    character((-3.6, -3.0), 62, mats["pink"], mats, MM.gun_rifle, aim_pitch=4)
    character((3.8, -2.6), -62, mats["cyan"], mats, MM.gun_smg, aim_pitch=2)
    paint_stream((-2.0, -4.0, 2.9), (0.1, -3.4, 2.5), mats["pink"], rng, arc=0.5)
    paint_stream((2.2, -3.6, 2.9), (0.3, -3.5, 2.5), mats["cyan"], rng, arc=0.4)
    for k in range(26):  # 충돌 지점 큰 스플래시
        a = rng.random() * math.tau; d = rng.uniform(0.3, 1.4)
        ball(rng.uniform(0.1, 0.32), (0.2 + math.cos(a) * d, -3.4 + math.sin(a) * d * 0.4, 2.5 + rng.uniform(-0.7, 1.3)),
             mats["pink"] if k % 2 else mats["cyan"])
    camera(scn, (0.2, -12.5, 3.3), (0.2, -2.5, 2.3), lens=32)
    render(scn, "key")


def shot_sniper():
    """어깨 너머 저격: 분홍 저격수가 멀리 하늘 팀을 조준, 탄도에 페인트 줄"""
    scn, mats = setup((1920, 1080))
    rng = random.Random(11)
    floor(90, mats, rng, n=90, spread=34)
    for p in ((-6, 10), (4, 14), (-2, 22), (8, 26), (-9, 28), (2, 34)):
        crate(p, rng.uniform(1.4, 2), mats, rng.random())
    wall((-10, 18), (8, 0.6, 3), mats, 0.1); wall((11, 20), (8, 0.6, 3), mats, -0.15)
    character((-0.6, 0), 180, mats["pink"], mats, MM.gun_sniper, aim_pitch=1)
    character((1.8, 22), 8, mats["cyan"], mats, MM.gun_shotgun)
    character((-4.2, 28), -14, mats["cyan"], mats, MM.gun_launcher)
    # 저격 탄도 (가늘고 긴 분홍 방울 줄)
    s, e = Vector((-1.1, 2.3, 2.9)), Vector((1.8, 21.6, 3.5))
    for i in range(40):
        t = i / 40
        ball(0.07 + t * 0.05, s.lerp(e, t), mats["pink_neon"], seg=12)
    camera(scn, (2.9, -5.2, 4.6), (0.0, 16, 2.4), lens=34)
    render(scn, "sniper")


def shot_map():
    """경기장 전경: 반은 분홍, 반은 하늘로 칠해진 크로마 스퀘어"""
    scn, mats = setup((1920, 1080))
    rng = random.Random(5)
    floor(120, mats, rng, n=160, spread=46)
    for _ in range(18):
        x, y = rng.uniform(-38, 38), rng.uniform(-30, 30)
        crate((x, y), rng.uniform(1.6, 2.6), mats, rng.random())
    for x in (-22, 0, 22):
        wall((x, 14), (10, 0.8, 3), mats); wall((x, -14), (10, 0.8, 3), mats)
    cube((10, 10, 1.5), (0, 0, 0.75), mats["wall"], b=0.1)  # 가운데 고지대
    for sgn, mt, g in ((-1, mats["pink"], MM.gun_rifle), (1, mats["cyan"], MM.gun_smg)):
        for k in range(3):
            character((sgn * rng.uniform(8, 30), rng.uniform(-18, 18)), -sgn * 90 + rng.uniform(-30, 30), mt, mats, g)
    # 둘레 벽
    for s in (-1, 1):
        cube((100, 1, 4), (0, s * 40, 2), mats["wall"], b=0.1)
        cube((1, 80, 4), (s * 50, 0, 2), mats["wall"], b=0.1)
    camera(scn, (0, -62, 46), (0, -2, 0), lens=30)
    scn.render.line_thickness = 1.4
    render(scn, "map")


def shot_icon():
    """아이콘: 분홍 캐릭터 상반신 + 라이플, 뒤에 하늘색 큰 스플래시"""
    scn, mats = setup((1024, 1024))
    rng = random.Random(3)
    floor(30, mats, rng, n=14, spread=8)
    # 뒤 배경판에 커다란 하늘색 스플래시
    disc(4.2, (0.5, 5, 3.2), mats["cyan"], h=0.1, rot=(math.radians(90), 0, 0))
    for _ in range(14):
        a = rng.random() * math.tau; d = rng.uniform(4.4, 6)
        disc(rng.uniform(0.25, 0.7), (0.5 + math.cos(a) * d, 5, 3.2 + math.sin(a) * d), mats["cyan"], h=0.1, rot=(math.radians(90), 0, 0))
    character((0, 0), 58, mats["pink"], mats, MM.gun_rifle, aim_pitch=8)
    paint_stream((2.0, -1.4, 3.1), (5.5, -3.2, 3.5), mats["pink"], rng, n=8, arc=0.4)
    camera(scn, (0.9, -6.0, 3.3), (0.8, 0, 2.7), lens=42)
    scn.render.line_thickness = 3.0
    render(scn, "icon")


FUNCS = {"key": shot_key, "sniper": shot_sniper, "map": shot_map, "icon": shot_icon}
for sname in SHOTS:
    FUNCS[sname]()
