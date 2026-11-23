"""SPLASH FRONT surface textures + HUD icons (procedural, no source images).
usage: python tools/make_textures.py   -> assets/textures/*.png (512, seamless), assets/icons/*.png (256 RGBA), assets/textures/_preview.png
Style: bright cartoon (light surfaces so team paint pops), soft shading, dark navy outlines on icons.
Everything is drawn at 4x and downsampled for clean anti-aliased edges."""
import math, os, json, random
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEX = os.path.join(ROOT, "assets", "textures")
ICO = os.path.join(ROOT, "assets", "icons")
os.makedirs(TEX, exist_ok=True)
os.makedirs(ICO, exist_ok=True)
SS = 4            # supersampling
N = 512           # texture size
OUT = (40, 44, 70)  # outline navy


def noise(size, scale, seed, amp):
    """smooth tileable value noise in [-amp, amp]"""
    rng = np.random.default_rng(seed)
    g = rng.random((scale, scale))
    x = np.linspace(0, scale, size, endpoint=False)
    xi = x.astype(int)
    xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    x1 = (xi + 1) % scale
    a = g[np.ix_(xi, xi)]; b = g[np.ix_(xi, x1)]; c = g[np.ix_(x1, xi)]; d = g[np.ix_(x1, x1)]
    top = a + (b - a) * xf[None, :]
    bot = c + (d - c) * xf[None, :]
    v = top + (bot - top) * xf[:, None]
    return (v - 0.5) * 2 * amp


def finish(img, name, grain=4, seed=1):
    a = np.asarray(img.convert("RGB")).astype(np.float32)
    n = noise(N, 32, seed, grain) + noise(N, 8, seed + 7, grain * 0.6)
    a += n[:, :, None]
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(os.path.join(TEX, name + ".png"))


def big(color):
    return Image.new("RGB", (N * SS, N * SS), color)


# 1) 바닥 타일: 흰 바닥 + 2×2 타일 줄눈 + 칸 가운데 작은 '+' (레퍼런스의 깔끔한 경기장 바닥)
def floor_tile():
    im = big((236, 239, 246)); d = ImageDraw.Draw(im)
    S = N * SS; cell = S // 2
    for i in range(3):
        p = i * cell
        d.rectangle([p - 6 * SS // 2, 0, p + 6 * SS // 2, S], fill=(214, 219, 232))
        d.rectangle([0, p - 6 * SS // 2, S, p + 6 * SS // 2], fill=(214, 219, 232))
    for cx in range(2):
        for cy in range(2):
            x0, y0 = cx * cell, cy * cell
            # 타일 안쪽 살짝 밝은 면(베벨)
            d.rectangle([x0 + 14 * SS, y0 + 14 * SS, x0 + cell - 14 * SS, y0 + cell - 14 * SS], fill=(241, 243, 249))
            mx, my = x0 + cell // 2, y0 + cell // 2
            L, W = 22 * SS, 5 * SS
            d.rounded_rectangle([mx - L, my - W, mx + L, my + W], radius=W, fill=(204, 211, 228))
            d.rounded_rectangle([mx - W, my - L, mx + W, my + L], radius=W, fill=(204, 211, 228))
    finish(im.resize((N, N), Image.LANCZOS), "floor_tile", 3, 11)


# 2) 벽 패널: 큰 패널 4장 + 이음새 + 모서리 리벳 + 아래쪽 살짝 어두운 띠
def wall_panel():
    im = big((226, 230, 241)); d = ImageDraw.Draw(im)
    S = N * SS; h = S // 2
    for i in range(3):
        p = i * h
        d.rectangle([p - 5 * SS, 0, p + 5 * SS, S], fill=(196, 203, 222))
        d.rectangle([0, p - 5 * SS, S, p + 5 * SS], fill=(196, 203, 222))
    for cx in range(2):
        for cy in range(2):
            x0, y0 = cx * h, cy * h
            d.rectangle([x0 + 10 * SS, y0 + 10 * SS, x0 + h - 10 * SS, y0 + 22 * SS], fill=(236, 239, 247))   # 윗면 하이라이트
            d.rectangle([x0 + 10 * SS, y0 + h - 22 * SS, x0 + h - 10 * SS, y0 + h - 10 * SS], fill=(212, 217, 232))
            for rx, ry in ((24, 34), (h // SS - 24, 34), (24, h // SS - 34), (h // SS - 24, h // SS - 34)):
                r = 6 * SS
                X, Y = x0 + rx * SS, y0 + ry * SS
                d.ellipse([X - r, Y - r, X + r, Y + r], fill=(176, 184, 206))
                d.ellipse([X - r + 2 * SS, Y - r + 2 * SS, X + r - 3 * SS, Y + r - 3 * SS], fill=(238, 241, 248))
    finish(im.resize((N, N), Image.LANCZOS), "wall_panel", 3, 21)


# 3) 나무 상자: 가로 판자 4장 + 나뭇결 + 판자 사이 어두운 틈 (따뜻한 카툰 오렌지)
def crate_wood():
    im = big((236, 172, 98)); d = ImageDraw.Draw(im)
    S = N * SS; ph = S // 4
    rng = random.Random(5)
    for i in range(4):
        y0 = i * ph
        base = (236 - i % 2 * 10, 172 - i % 2 * 8, 98 - i % 2 * 4)
        d.rectangle([0, y0, S, y0 + ph], fill=base)
        d.rectangle([0, y0, S, y0 + 9 * SS], fill=(248, 196, 128))          # 윗면 빛
        d.rectangle([0, y0 + ph - 10 * SS, S, y0 + ph], fill=(168, 104, 52))  # 틈
        for _ in range(7):  # 나뭇결: 좌우로 이어지는 물결선 (x 주기 맞춤 → 이음매 없음)
            yy = y0 + rng.randint(18, ph // SS - 22) * SS
            amp = rng.uniform(2, 6) * SS
            k = rng.choice([1, 2, 3])
            pts = [(x, yy + amp * math.sin(2 * math.pi * k * x / S)) for x in range(0, S + 1, 16)]
            d.line(pts, fill=(204, 136, 72), width=3 * SS)
        # 못
        for nx in (0.12, 0.62):
            X, Y, r = int(S * nx), y0 + ph // 2, 7 * SS
            d.ellipse([X - r, Y - r, X + r, Y + r], fill=(120, 80, 50))
            d.ellipse([X - r + 3 * SS, Y - r + 3 * SS, X + r - 4 * SS, Y + r - 4 * SS], fill=(190, 150, 110))
    finish(im.resize((N, N), Image.LANCZOS), "crate_wood", 5, 31)


# 4) 컨테이너 골판: 세로 골(밝음→어두움) 8개 + 녹 얼룩 약간 (색은 파트 색을 곱해서 씀 → 흰 톤으로)
def container_rib():
    S = N
    x = np.arange(S)
    t = (x % (S // 8)) / (S // 8)
    shade = 0.82 + 0.18 * np.sin(t * 2 * math.pi)
    a = np.ones((S, S, 3), np.float32) * 240
    a *= shade[None, :, None]
    a[:, :, 2] *= 0.98
    img = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))
    finish(img, "container_rib", 1.5, 41)


# 5) 경사로 체크 철판: 연회색 + 엇갈린 다이아몬드 돌기
def ramp_plate():
    im = big((196, 202, 218)); d = ImageDraw.Draw(im)
    S = N * SS; step = S // 8
    for gy in range(8):
        for gx in range(8):
            cx = gx * step + step // 2
            cy = gy * step + step // 2
            ang = 45 if (gx + gy) % 2 == 0 else -45
            L, W = step * 0.32, step * 0.08
            ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
            pts = [(cx + ca * L, cy + sa * L), (cx - sa * W, cy + ca * W), (cx - ca * L, cy - sa * L), (cx + sa * W, cy - ca * W)]
            d.polygon([(px + 3 * SS, py + 3 * SS) for px, py in pts], fill=(160, 168, 188))
            d.polygon(pts, fill=(228, 232, 242))
    finish(im.resize((N, N), Image.LANCZOS), "ramp_plate", 3, 51)


# 6) 경고 띠(점프패드 테두리·스폰 가장자리용)
def hazard():
    im = big((255, 206, 40)); d = ImageDraw.Draw(im)
    S = N * SS; w = S // 4
    for k in range(-4, 8):
        x = k * w
        d.polygon([(x, 0), (x + w // 2, 0), (x + w // 2 + S, S), (x + S, S)], fill=(40, 40, 52))
    finish(im.resize((N, N), Image.LANCZOS), "hazard", 3, 61)


# ---------------- 아이콘 (256, 투명 배경, 굵은 남색 외곽선) ----------------
I = 256


def canvas():
    return Image.new("RGBA", (I * SS, I * SS), (0, 0, 0, 0))


def save_icon(im, name):
    im = im.resize((I, I), Image.LANCZOS)
    im.save(os.path.join(ICO, name + ".png"))


def P(x, y):
    return (x * SS * I / 100, y * SS * I / 100)


def poly(d, pts, fill, outline=OUT, w=5):
    d.polygon([P(*p) for p in pts], fill=fill)
    d.line([P(*p) for p in pts + [pts[0]]], fill=outline, width=int(w * SS * I / 256), joint="curve")


def ell(d, x0, y0, x1, y1, fill, outline=OUT, w=5):
    d.ellipse([*P(x0, y0), *P(x1, y1)], fill=fill, outline=outline, width=int(w * SS * I / 256))


def coin():
    im = canvas(); d = ImageDraw.Draw(im)
    ell(d, 8, 12, 92, 96, (214, 138, 20))            # 옆면(두께)
    ell(d, 8, 6, 92, 90, (255, 200, 50))
    ell(d, 20, 18, 80, 78, (255, 222, 100), (220, 150, 30), 4)
    star = []
    for k in range(10):
        r = 22 if k % 2 == 0 else 9
        a = -math.pi / 2 + k * math.pi / 5
        star.append((50 + r * math.cos(a), 48 + r * math.sin(a)))
    poly(d, star, (255, 245, 190), (220, 150, 30), 3)
    d.ellipse([*P(24, 16), *P(42, 26)], fill=(255, 250, 220, 200))
    save_icon(im, "coin")


def flame():
    im = canvas(); d = ImageDraw.Draw(im)
    outer = [(50, 4), (62, 22), (74, 18), (88, 46), (86, 70), (72, 92), (50, 98), (28, 92), (14, 70), (14, 48), (26, 30), (34, 40), (38, 20)]
    poly(d, outer, (255, 70, 40))
    mid = [(50, 30), (60, 46), (68, 44), (74, 62), (68, 82), (50, 90), (32, 82), (28, 64), (36, 50), (42, 56)]
    poly(d, mid, (255, 150, 30), (255, 150, 30), 1)
    core = [(50, 52), (58, 64), (60, 78), (50, 86), (40, 78), (42, 64)]
    poly(d, core, (255, 235, 120), (255, 235, 120), 1)
    save_icon(im, "flame")


def skull():
    im = canvas(); d = ImageDraw.Draw(im)
    ell(d, 14, 6, 86, 74, (248, 248, 252))
    poly(d, [(30, 62), (70, 62), (68, 90), (32, 90)], (248, 248, 252))
    d.rectangle([*P(31, 60), *P(69, 66)], fill=(248, 248, 252))
    ell(d, 24, 32, 46, 54, (40, 44, 70), OUT, 1)
    ell(d, 54, 32, 76, 54, (40, 44, 70), OUT, 1)
    poly(d, [(50, 56), (56, 66), (44, 66)], (40, 44, 70), OUT, 1)
    for x in (40, 50, 60):
        d.line([P(x, 74), P(x, 90)], fill=OUT, width=int(4 * SS))
    save_icon(im, "skull")


def crown():
    im = canvas(); d = ImageDraw.Draw(im)
    pts = [(10, 34), (30, 56), (50, 22), (70, 56), (90, 34), (82, 80), (18, 80)]
    poly(d, pts, (255, 200, 40))
    d.rectangle([*P(18, 76), *P(82, 90)], fill=(240, 170, 30), outline=OUT, width=int(5 * SS))
    for x, y, c in ((50, 60, (255, 60, 110)), (30, 66, (60, 190, 255)), (70, 66, (90, 230, 120))):
        ell(d, x - 6, y - 6, x + 6, y + 6, c, OUT, 3)
    for x, y in ((10, 34), (50, 22), (90, 34)):
        ell(d, x - 6, y - 6, x + 6, y + 6, (255, 230, 120), OUT, 3)
    save_icon(im, "crown")


def hourglass():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([*P(18, 4), *P(82, 14)], radius=int(4 * SS), fill=(150, 100, 60), outline=OUT, width=int(5 * SS))
    d.rounded_rectangle([*P(18, 86), *P(82, 96)], radius=int(4 * SS), fill=(150, 100, 60), outline=OUT, width=int(5 * SS))
    poly(d, [(26, 14), (74, 14), (54, 50), (74, 86), (26, 86), (46, 50)], (210, 236, 255))
    poly(d, [(34, 20), (66, 20), (52, 42), (48, 42)], (255, 205, 80), (255, 205, 80), 1)
    poly(d, [(50, 60), (68, 82), (32, 82)], (255, 205, 80), (255, 205, 80), 1)
    save_icon(im, "hourglass")


def quest():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([*P(10, 14), *P(90, 92)], radius=int(10 * SS), fill=(250, 250, 255), outline=OUT, width=int(5 * SS))
    d.rounded_rectangle([*P(10, 14), *P(90, 34)], radius=int(10 * SS), fill=(255, 80, 110), outline=OUT, width=int(5 * SS))
    for x in (30, 70):
        d.rounded_rectangle([*P(x - 4, 6), *P(x + 4, 22)], radius=int(3 * SS), fill=(120, 126, 150), outline=OUT, width=int(3 * SS))
    d.line([P(28, 62), P(44, 76), P(74, 46)], fill=(40, 190, 100), width=int(10 * SS), joint="curve")
    save_icon(im, "quest")


def check():
    im = canvas(); d = ImageDraw.Draw(im)
    ell(d, 6, 6, 94, 94, (60, 210, 120))
    d.line([P(28, 52), P(44, 68), P(74, 36)], fill=(255, 255, 255), width=int(12 * SS), joint="curve")
    save_icon(im, "check")


def bomb():
    im = canvas(); d = ImageDraw.Draw(im)
    ell(d, 10, 24, 82, 96, (60, 62, 84))
    d.ellipse([*P(22, 36), *P(40, 52)], fill=(130, 136, 170))
    d.rounded_rectangle([*P(50, 16), *P(66, 30)], radius=int(3 * SS), fill=(110, 114, 140), outline=OUT, width=int(4 * SS))
    d.line([P(60, 16), P(70, 8), P(80, 10)], fill=(150, 110, 70), width=int(5 * SS))
    for k in range(8):
        a = k * math.pi / 4
        d.line([P(84, 10), P(84 + 10 * math.cos(a), 10 + 10 * math.sin(a))], fill=(255, 210, 60), width=int(4 * SS))
    ell(d, 79, 5, 89, 15, (255, 240, 150), (255, 160, 40), 2)
    save_icon(im, "bomb")


def target():
    im = canvas(); d = ImageDraw.Draw(im)
    ell(d, 6, 6, 94, 94, (255, 255, 255))
    ell(d, 18, 18, 82, 82, (255, 70, 90), OUT, 4)
    ell(d, 30, 30, 70, 70, (255, 255, 255), OUT, 3)
    ell(d, 41, 41, 59, 59, (255, 70, 90), OUT, 3)
    save_icon(im, "target")


def chest():
    im = canvas(); d = ImageDraw.Draw(im)
    d.rounded_rectangle([*P(8, 40), *P(92, 92)], radius=int(8 * SS), fill=(200, 120, 50), outline=OUT, width=int(5 * SS))
    d.rounded_rectangle([*P(8, 22), *P(92, 46)], radius=int(12 * SS), fill=(226, 146, 70), outline=OUT, width=int(5 * SS))
    for x in (24, 76):
        d.rectangle([*P(x - 5, 22), *P(x + 5, 92)], fill=(255, 200, 60), outline=OUT, width=int(3 * SS))
    d.rounded_rectangle([*P(40, 40), *P(60, 60)], radius=int(4 * SS), fill=(255, 220, 90), outline=OUT, width=int(4 * SS))
    d.ellipse([*P(47, 46), *P(53, 52)], fill=OUT)
    save_icon(im, "chest")


def trophy():
    im = canvas(); d = ImageDraw.Draw(im)
    for side in (-1, 1):
        cx = 50 + side * 32
        d.arc([*P(cx - 14, 18), *P(cx + 14, 50)], 0, 360, fill=OUT, width=int(6 * SS))
    poly(d, [(24, 10), (76, 10), (70, 46), (58, 58), (42, 58), (30, 46)], (255, 200, 40))
    d.rectangle([*P(44, 56), *P(56, 74)], fill=(240, 170, 30), outline=OUT, width=int(4 * SS))
    d.rounded_rectangle([*P(26, 74), *P(74, 92)], radius=int(4 * SS), fill=(130, 90, 60), outline=OUT, width=int(5 * SS))
    poly(d, [(50, 18), (55, 30), (67, 30), (57, 37), (61, 49), (50, 42), (39, 49), (43, 37), (33, 30), (45, 30)], (255, 245, 190), (220, 150, 30), 2)
    save_icon(im, "trophy")


def scope_overlay():
    """스코프 화면: 가운데 원은 투명(표적이 보임), 바깥은 검정, 얇은 십자선·눈금·빨간 점"""
    S = 1024 * 2
    im = Image.new("RGBA", (S, S), (6, 6, 10, 255))
    d = ImageDraw.Draw(im)
    r = int(S * 0.48)
    c = S // 2
    d.ellipse([c - r, c - r, c + r, c + r], fill=(0, 0, 0, 0))
    # 렌즈 가장자리 그늘(안쪽으로 살짝 어두운 띠)
    for k in range(18):
        rr = r - k * 3
        d.ellipse([c - rr, c - rr, c + rr, c + rr], outline=(0, 0, 0, max(0, 150 - k * 9)), width=4)
    lw = 4
    d.line([(c - r, c), (c - 70, c)], fill=(10, 10, 14, 255), width=lw)
    d.line([(c + 70, c), (c + r, c)], fill=(10, 10, 14, 255), width=lw)
    d.line([(c, c - r), (c, c - 70)], fill=(10, 10, 14, 255), width=lw)
    d.line([(c, c + 70), (c, c + r)], fill=(10, 10, 14, 255), width=lw)
    d.line([(c - 70, c), (c + 70, c)], fill=(10, 10, 14, 230), width=2)
    d.line([(c, c - 70), (c, c + 70)], fill=(10, 10, 14, 230), width=2)
    for k in range(1, 9):
        o = k * 70
        L = 14 if k % 2 == 0 else 8
        for sgn in (-1, 1):
            d.line([(c + sgn * o, c - L), (c + sgn * o, c + L)], fill=(10, 10, 14, 255), width=3)
            d.line([(c - L, c + sgn * o), (c + L, c + sgn * o)], fill=(10, 10, 14, 255), width=3)
    d.ellipse([c - 7, c - 7, c + 7, c + 7], fill=(255, 40, 60, 255))
    im.resize((1024, 1024), Image.LANCZOS).save(os.path.join(ICO, "scope.png"))


for f in (floor_tile, wall_panel, crate_wood, container_rib, ramp_plate, hazard):
    f()
for f in (coin, flame, skull, crown, hourglass, quest, check, bomb, target, chest, trophy, scope_overlay):
    f()

# 미리보기 한 장
texs = sorted(x for x in os.listdir(TEX) if x.endswith(".png") and not x.startswith("_"))
icons = sorted(x for x in os.listdir(ICO) if x.endswith(".png"))
pv = Image.new("RGB", (256 * 6, 256 + 128 + 20), (30, 30, 46))
for i, t in enumerate(texs[:6]):
    pv.paste(Image.open(os.path.join(TEX, t)).resize((256, 256)), (i * 256, 0))
for i, ic in enumerate(icons):
    im = Image.open(os.path.join(ICO, ic)).resize((128, 128))
    pv.paste(im, (i * (256 * 6 // len(icons)) + 4, 256 + 10), im)
pv.save(os.path.join(TEX, "_preview.png"))
json.dump({"textures": [t[:-4] for t in texs], "icons": [i[:-4] for i in icons]}, open(os.path.join(TEX, "images.json"), "w"), indent=1)
print("textures:", texs)
print("icons:", icons)
