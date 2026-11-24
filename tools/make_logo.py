"""SPLASH FRONT 로고 (게임 안 로딩 화면·로비 간판용) -> assets/icons/logo.png (1024x420 RGBA)
두꺼운 이탤릭 SPLASH(자홍→보라 광택 그라데이션, 베벨·외곽 발광) + 네온 판 위의 자간 넓힌 FRONT + 잉크 튐"""
import math, os, random
from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "icons", "logo.png")
FONT = "/usr/share/fonts/truetype/google-fonts/ofl/montserrat/Montserrat-Italic[wght].ttf"
S = 3  # 슈퍼샘플링
W, H = 1024 * S, 420 * S
NAVY = (12, 14, 34)


def font(size, weight=900):
    f = ImageFont.truetype(FONT, size)
    try:
        f.set_variation_by_axes([weight])
    except Exception:
        pass
    return f


def vgrad(size, stops):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        for i in range(len(stops) - 1):
            p0, c0 = stops[i]
            p1, c1 = stops[i + 1]
            if p0 <= t <= p1:
                k = (t - p0) / max(1e-6, p1 - p0)
                g.putpixel((0, y), tuple(int(c0[j] + (c1[j] - c0[j]) * k) for j in range(3)))
                break
    return g.resize((w, h))


def text_mask(txt, f, spacing=0):
    l, t, r, b = f.getbbox(txt)
    w = r - l + spacing * len(txt) + 40 * S
    h = b - t + 40 * S
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    x = 20 * S - l
    for ch in txt:
        d.text((x, 20 * S - t), ch, font=f, fill=255)
        x += f.getlength(ch) + spacing
    return m


def grow(mask, px):
    return mask.filter(ImageFilter.MaxFilter(px * 2 + 1)) if px > 0 else mask


def styled(mask, stops, glow, bevel_dark, outline_px=7 * S, white_px=3 * S):
    w, h = mask.size
    pad = 60 * S
    big = Image.new("L", (w + pad * 2, h + pad * 2), 0)
    big.paste(mask, (pad, pad))
    mask = big
    w, h = mask.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    # 바깥 발광
    g = grow(mask, 10 * S).filter(ImageFilter.GaussianBlur(22 * S))
    out.paste(glow + (255,), (0, 0), g.point(lambda v: int(v * 0.75)))
    # 그림자
    sh = Image.new("L", (w, h), 0)
    sh.paste(grow(mask, outline_px), (8 * S, 12 * S))
    out.paste((4, 4, 14, 255), (0, 0), sh.filter(ImageFilter.GaussianBlur(6 * S)).point(lambda v: int(v * 0.7)))
    # 남색 두꺼운 테두리 + 흰 얇은 테두리
    out.paste(NAVY + (255,), (0, 0), grow(mask, outline_px))
    out.paste((255, 255, 255, 255), (0, 0), grow(mask, white_px))
    # 본체 그라데이션
    fill = vgrad((w, h), stops).convert("RGBA")
    out.paste(fill, (0, 0), mask)
    # 아래쪽 베벨(어둡게) + 위쪽 광택 띠
    inner = mask.filter(ImageFilter.MinFilter(9 * S))
    edge = ImageChops.subtract(mask, inner)
    shifted = Image.new("L", (w, h), 0)
    shifted.paste(edge, (0, -4 * S))
    lower = ImageChops.multiply(edge, vgrad((w, h), [(0, (0, 0, 0)), (0.5, (0, 0, 0)), (1, (255, 255, 255))]).convert("L"))
    out.paste(bevel_dark + (255,), (0, 0), lower)
    gloss = Image.new("L", (w, h), 0)
    bbox = mask.getbbox()
    if bbox:
        y0, y1 = bbox[1], bbox[1] + int((bbox[3] - bbox[1]) * 0.42)
        ImageDraw.Draw(gloss).polygon([(0, y0), (w, y0), (w, y1 - 20 * S), (0, y1 + 10 * S)], fill=95)
    out.paste((255, 255, 255, 255), (0, 0), ImageChops.multiply(gloss, inner))
    # 윗가장자리 하이라이트
    hl = ImageChops.subtract(mask, shifted.point(lambda v: 0) if False else ImageChops.offset(mask, 0, 5 * S))
    out.paste((255, 255, 255, 255), (0, 0), hl.point(lambda v: int(v * 0.8)))
    return out.crop(out.getbbox())


def splat(d, cx, cy, r, color, seed):
    rnd = random.Random(seed)
    pts = []
    for k in range(26):
        a = k / 26 * math.tau
        rr = r * (0.75 + rnd.uniform(-0.12, 0.28))
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=color)
    for k in range(9):
        a = rnd.uniform(0, math.tau)
        rr = r * rnd.uniform(1.15, 1.7)
        s = r * rnd.uniform(0.06, 0.16)
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr
        d.ellipse([x - s, y - s, x + s, y + s], fill=color)


img = Image.new("RGBA", (W, H), (0, 0, 0, 0))

# 뒤쪽 잉크 튐 (살짝 투명)
back = Image.new("RGBA", (W, H), (0, 0, 0, 0))
bd = ImageDraw.Draw(back)
splat(bd, 150 * S, 150 * S, 110 * S, (0, 210, 255, 210), 3)
splat(bd, 890 * S, 120 * S, 80 * S, (255, 220, 30, 200), 7)
splat(bd, 820 * S, 300 * S, 60 * S, (150, 60, 255, 190), 11)
img.alpha_composite(back.filter(ImageFilter.GaussianBlur(1 * S)))

# SPLASH
m1 = text_mask("SPLASH", font(212 * S), spacing=-4 * S)
t1 = styled(m1, [(0, (255, 150, 235)), (0.45, (255, 40, 180)), (0.7, (230, 20, 130)), (1, (130, 30, 230))], (255, 40, 200), (90, 10, 90))
x1 = (W - t1.width) // 2 - 10 * S
img.alpha_composite(t1, (x1, 0))

# FRONT 네온 판 (기울어진 평행사변형)
plate_y0, plate_y1 = 270 * S, 380 * S
px0, px1 = 270 * S, 790 * S
sk = 34 * S
plate = Image.new("RGBA", (W, H), (0, 0, 0, 0))
pd = ImageDraw.Draw(plate)
poly = [(px0 + sk, plate_y0), (px1 + sk, plate_y0), (px1 - sk, plate_y1), (px0 - sk, plate_y1)]
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).polygon(poly, fill=255)
img.paste((0, 220, 255, 255), (0, 0), glow.filter(ImageFilter.MaxFilter(9 * S)).filter(ImageFilter.GaussianBlur(14 * S)).point(lambda v: int(v * 0.6)))
pd.polygon(poly, fill=(10, 14, 34, 255))
pd.line(poly + [poly[0]], fill=(0, 230, 255, 255), width=5 * S)
pd.line([(px0 + sk + 14 * S, plate_y0 + 10 * S), (px0 + sk + 120 * S, plate_y0 + 10 * S)], fill=(240, 255, 40, 255), width=4 * S)
img.alpha_composite(plate)

m2 = text_mask("FRONT", font(92 * S), spacing=30 * S)
t2 = styled(m2, [(0, (255, 255, 255)), (0.5, (170, 240, 255)), (1, (0, 170, 255))], (0, 200, 255), (0, 60, 120), outline_px=4 * S, white_px=0)
img.alpha_composite(t2, ((W - t2.width) // 2 + 6 * S, plate_y0 + (plate_y1 - plate_y0 - t2.height) // 2 + 4 * S))

# 반짝임
spark = Image.new("RGBA", (W, H), (0, 0, 0, 0))
sd = ImageDraw.Draw(spark)
for (sx, sy, r) in [(x1 + t1.width - 90 * S, 42 * S, 26 * S), (x1 + 70 * S, 210 * S, 16 * S)]:
    sd.polygon([(sx, sy - r), (sx + r * 0.18, sy - r * 0.18), (sx + r, sy), (sx + r * 0.18, sy + r * 0.18), (sx, sy + r), (sx - r * 0.18, sy + r * 0.18),
                (sx - r, sy), (sx - r * 0.18, sy - r * 0.18)], fill=(255, 255, 255, 255))
img.alpha_composite(spark.filter(ImageFilter.GaussianBlur(0.6 * S)))

img = img.resize((1024, 420), Image.LANCZOS)
img.save(OUT)
print("wrote", OUT)
