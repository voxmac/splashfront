"""MVP 엠블럼 아이콘 (승리 판정 보드용) -> assets/icons/mvp.png (512 RGBA)
금색 방패 + 월계수 + 별 + 'MVP' (타이틀 로고와 같은 Montserrat 이탤릭), 4배로 그려 축소"""
import math, os, json
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ICO = os.path.join(ROOT, "assets", "icons")
FONT = "/usr/share/fonts/truetype/google-fonts/ofl/montserrat/Montserrat-Italic[wght].ttf"
S = 2048
NAVY = (16, 14, 40, 255)


def grad_fill(size, top, bottom):
    g = Image.new("RGBA", size)
    d = ImageDraw.Draw(g)
    for y in range(size[1]):
        k = y / max(1, size[1] - 1)
        d.line([(0, y), (size[0], y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * k) for i in range(3)) + (255,))
    return g


def shape(mask_draw_fn):
    m = Image.new("L", (S, S), 0)
    mask_draw_fn(ImageDraw.Draw(m))
    return m


def shield(d, inset=0):
    c = S / 2
    pts = [(c, 250 + inset), (c + 560 - inset, 420 + inset), (c + 520 - inset, 1050), (c, 1720 - inset * 1.3),
           (c - 520 + inset, 1050), (c - 560 + inset, 420 + inset)]
    d.polygon(pts, fill=255)


def leaf_wreath(img):
    d = ImageDraw.Draw(img)
    c = S / 2
    for side_ in (-1, 1):
        d.arc([c - 700, 1080 - 665, c + 700, 1080 + 665], 20 if side_ == 1 else 100, 80 if side_ == 1 else 160, fill=(220, 150, 20, 255), width=34)
    for side in (-1, 1):
        for k in range(8):
            a = math.radians(200 - k * 17) if side == -1 else math.radians(-20 + k * 17)
            r = 700
            x, y = c + math.cos(a) * r * (1 if side == 1 else 1), 1080 - math.sin(a) * r * 0.95
            if side == -1:
                x = c - (x - c) * -1
            ang = a + (math.pi / 2 if side == 1 else -math.pi / 2)
            L, W = 280, 110
            pts = []
            for t in range(21):
                u = t / 20
                px = (u - 0.5) * L
                py = math.sin(u * math.pi) * W / 2
                pts.append((px, py))
            for t in range(20, -1, -1):
                u = t / 20
                pts.append(((u - 0.5) * L, -math.sin(u * math.pi) * W / 2))
            ca, sa = math.cos(ang + 0.5 * side), math.sin(ang + 0.5 * side)
            poly = [(x + px * ca - py * sa, y + px * sa + py * ca) for px, py in pts]
            d.polygon(poly, fill=(255, 196, 40, 255), outline=NAVY, width=18)


def star(d, cx, cy, r, fill):
    pts = []
    for i in range(10):
        a = -math.pi / 2 + i * math.pi / 5
        rr = r if i % 2 == 0 else r * 0.45
        pts.append((cx + math.cos(a) * rr, cy + math.sin(a) * rr))
    d.polygon(pts, fill=fill, outline=NAVY, width=22)


def main():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    # 바깥 네온 글로우
    glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    glow.paste((255, 60, 200, 255), (0, 0), shape(lambda d: shield(d, -70)))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
    leaf_wreath(img)
    # 방패: 남색 테두리 → 금 테두리 → 자홍/보라 안쪽
    img.paste(NAVY, (0, 0), shape(lambda d: shield(d, -40)))
    img.paste(grad_fill((S, S), (255, 236, 140), (220, 130, 10)), (0, 0), shape(lambda d: shield(d, 0)))
    img.paste(NAVY, (0, 0), shape(lambda d: shield(d, 80)))
    img.paste(grad_fill((S, S), (255, 70, 190), (90, 30, 200)), (0, 0), shape(lambda d: shield(d, 110)))
    # 위쪽 하이라이트
    hl = Image.new("RGBA", (S, S), (255, 255, 255, 0))
    ImageDraw.Draw(hl).polygon([(S / 2, 380), (S / 2 + 420, 520), (S / 2 + 380, 760), (S / 2 - 380, 760), (S / 2 - 420, 520)],
                               fill=(255, 255, 255, 50))
    m = shape(lambda d: shield(d, 110))
    hl.putalpha(Image.composite(hl.getchannel("A"), Image.new("L", (S, S), 0), m))
    img.alpha_composite(hl)
    d = ImageDraw.Draw(img)
    star(d, S / 2, 640, 210, (255, 222, 70, 255))
    # MVP 글자: 이탤릭 + 남색 외곽선 + 금 그라데이션
    f = ImageFont.truetype(FONT, 470)
    try:
        f.set_variation_by_axes([900])
    except Exception:
        pass
    text = "MVP"
    bb = d.textbbox((0, 0), text, font=f, stroke_width=40)
    tw, th = bb[2] - bb[0], bb[3] - bb[1]
    tx, ty = (S - tw) / 2 - bb[0], 1040 - th / 2 - bb[1]
    d.text((tx, ty), text, font=f, fill=NAVY, stroke_width=40, stroke_fill=NAVY)
    tm = Image.new("L", (S, S), 0)
    ImageDraw.Draw(tm).text((tx, ty), text, font=f, fill=255)
    img.paste(grad_fill((S, S), (255, 255, 255), (255, 210, 90)), (0, 0), tm)
    # 아래 리본
    rib = [(S / 2 - 640, 1380), (S / 2 + 640, 1380), (S / 2 + 560, 1500), (S / 2 + 640, 1620), (S / 2 - 640, 1620),
           (S / 2 - 560, 1500)]
    d.polygon(rib, fill=(40, 220, 255, 255), outline=NAVY, width=26)
    for x in (-420, 0, 420):
        star(d, S / 2 + x, 1500, 70, (255, 255, 255, 255))
    out = img.resize((512, 512), Image.LANCZOS)
    out.save(os.path.join(ICO, "mvp.png"))
    p = os.path.join(ROOT, "assets", "textures", "images.json")
    j = json.load(open(p))
    if "mvp" not in j["icons"]:
        j["icons"] = sorted(j["icons"] + ["mvp"])
        json.dump(j, open(p, "w"), indent=1)


main()
