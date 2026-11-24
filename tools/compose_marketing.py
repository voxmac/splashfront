"""SPLASH FRONT store art — adds logo/text to the Blender renders and draws the product images.
usage: python tools/compose_marketing.py
in : assets/marketing/raw_{key,sniper,map,icon}.png (tools/make_marketing.py)
out: assets/marketing/
  game_icon.png (512)            thumb_1_key.png / thumb_2_weapons.png / thumb_3_paint.png (1920x1080)
  pass_vip.png, product_crate.png, product_coins_500.png / _1200.png / _3000.png (512, circle-safe)"""
import math, os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
M = os.path.join(ROOT, "assets", "marketing")
ICONS = os.path.join(ROOT, "assets", "icons")
LATIN = "/usr/share/fonts/truetype/google-fonts/ofl/montserrat/Montserrat-Italic[wght].ttf"
LATIN_FALLBACK = "/usr/share/fonts/truetype/google-fonts/Poppins-Bold.ttf"
KR = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"
NAVY = (22, 20, 48)
PINK = [(255, 120, 200), (255, 30, 140)]
CYAN = [(120, 235, 255), (0, 140, 255)]
GOLD = [(255, 236, 140), (255, 170, 20)]


def latin(size):
    try:
        f = ImageFont.truetype(LATIN, size)
        try:
            f.set_variation_by_name("Black Italic")
        except Exception:
            f.set_variation_by_axes([900])
        return f
    except Exception:
        return ImageFont.truetype(LATIN_FALLBACK, size)


def kr(size):
    for idx in (1, 0, 2, 3):  # ttc 안의 한국어(KR) 서체 찾기
        f = ImageFont.truetype(KR, size, index=idx)
        if "KR" in " ".join(f.getname()):
            return f
    return ImageFont.truetype(KR, size)


def gradient(size, c1, c2):
    w, h = size
    g = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)))
    return g.resize((w, h))


def styled_text(text, font, colors, stroke=None, inner=None, shadow=True):
    """굵은 남색 외곽선 + 흰 안쪽 테두리 + 위→아래 그라데이션 + 그림자"""
    stroke = stroke if stroke is not None else max(4, font.size // 9)
    inner = inner if inner is not None else max(2, font.size // 22)
    l, t, r, b = font.getbbox(text, stroke_width=stroke)
    w, h = r - l + stroke * 2 + 20, b - t + stroke * 2 + 30
    ox, oy = -l + stroke + 10, -t + stroke + 8
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    if shadow:
        sh = Image.new("L", (w, h), 0)
        ImageDraw.Draw(sh).text((ox + 6, oy + 10), text, font=font, fill=200, stroke_width=stroke, stroke_fill=200)
        out.paste((10, 8, 30, 170), (0, 0), sh.filter(ImageFilter.GaussianBlur(5)))
    d = ImageDraw.Draw(out)
    d.text((ox, oy), text, font=font, fill=NAVY, stroke_width=stroke, stroke_fill=NAVY)
    d.text((ox, oy), text, font=font, fill=(255, 255, 255), stroke_width=inner, stroke_fill=(255, 255, 255))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).text((ox, oy), text, font=font, fill=255)
    fill = gradient((w, h), *colors).convert("RGBA")
    out.paste(fill, (0, 0), mask)
    # 윗부분 하이라이트
    hl = Image.new("L", (w, h), 0)
    ImageDraw.Draw(hl).text((ox, oy), text, font=font, fill=70)
    top = Image.new("L", (w, h), 0)
    ImageDraw.Draw(top).rectangle([0, 0, w, oy + (b - t) * 0.42], fill=255)
    out.paste((255, 255, 255, 255), (0, 0), Image.composite(hl, Image.new("L", (w, h), 0), top))
    return out


def drips(img, x0, x1, y, color, n, rng_seed=1, scale=1.0):
    import random
    rng = random.Random(rng_seed)
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x = rng.uniform(x0, x1)
        w = rng.uniform(10, 20) * scale
        L = rng.uniform(20, 70) * scale
        d.rounded_rectangle([x - w / 2, y - 6, x + w / 2, y + L], radius=w / 2, fill=color, outline=NAVY, width=int(4 * scale))
        d.ellipse([x - w * 0.75, y + L - w * 0.6, x + w * 0.75, y + L + w * 0.9], fill=color, outline=NAVY, width=int(4 * scale))


def logo(width):
    """게임 입장 타이틀과 같은 로고 (tools/make_logo.py가 만든 assets/marketing/logo_hi.png)"""
    hi = os.path.join(M, "logo_hi.png")
    if not os.path.exists(hi):
        hi = os.path.join(ICONS, "logo.png")
    im = Image.open(hi).convert("RGBA")
    return im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)


def sf_plate(img, text, y, font, edge=(0, 230, 255), accent=(240, 255, 40), fill=(10, 14, 34), cx=None):
    """입장 타이틀의 FRONT 판과 같은 SF 네온 평행사변형 띠"""
    l, t, r, b = font.getbbox(text)
    pad_x, pad_y = 70, 26
    w, h = r - l + pad_x * 2, b - t + pad_y * 2
    cx = img.width // 2 if cx is None else cx
    x0, x1 = cx - w // 2, cx + w // 2
    sk = h * 0.32
    poly = [(x0 + sk, y), (x1 + sk, y), (x1 - sk, y + h), (x0 - sk, y + h)]
    glow = Image.new("L", img.size, 0)
    ImageDraw.Draw(glow).polygon(poly, fill=255)
    img.paste(edge + (255,), (0, 0), glow.filter(ImageFilter.MaxFilter(15)).filter(ImageFilter.GaussianBlur(18)).point(lambda v: int(v * 0.55)))
    d = ImageDraw.Draw(img)
    d.polygon(poly, fill=fill + (235,))
    d.line(poly + [poly[0]], fill=edge + (255,), width=6)
    d.line([(x0 + sk + 24, y + 12), (x0 + sk + 170, y + 12)], fill=accent + (255,), width=6)
    d.text((cx - (r - l) // 2 - l, y + pad_y - t), text, font=font, fill=(255, 255, 255), stroke_width=2, stroke_fill=(10, 14, 34))


def neon_caption(img, text, xy, font, fill=(255, 255, 255), glow=(255, 40, 200)):
    """두꺼운 글자 + 남색 테두리 + 네온 번짐"""
    g = Image.new("L", img.size, 0)
    ImageDraw.Draw(g).text(xy, text, font=font, fill=255, stroke_width=max(6, font.size // 8), stroke_fill=255)
    img.paste(glow + (255,), (0, 0), g.filter(ImageFilter.GaussianBlur(font.size // 5)).point(lambda v: int(v * 0.7)))
    ImageDraw.Draw(img).text(xy, text, font=font, fill=fill, stroke_width=max(4, font.size // 11), stroke_fill=(10, 12, 30))


def grade(img, tint=(30, 20, 70), strength=0.18):
    """입장 화면 톤(남색·자홍)으로 살짝 색 보정 + 위아래 어둡게"""
    w, h = img.size
    over = Image.new("RGBA", (w, h), tint + (int(255 * strength),))
    img.alpha_composite(over)
    band = Image.new("L", (w, h), 0)
    bd = ImageDraw.Draw(band)
    for y in range(h):
        k = max(0.0, (abs(y - h * 0.55) / (h * 0.55)) - 0.35) / 0.65
        bd.line([(0, y), (w, y)], fill=int(170 * min(1, k) ** 1.6))
    img.paste((6, 6, 20, 255), (0, 0), band)


def ribbon(img, text, y, font, color=(255, 46, 170), pad=26):
    d = ImageDraw.Draw(img)
    l, t, r, b = font.getbbox(text)
    w, h = r - l + pad * 2, b - t + pad
    x = (img.width - w) // 2
    sh = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(sh).rounded_rectangle([x + 6, y + 8, x + w + 6, y + h + 8], radius=h // 2, fill=(10, 8, 30, 140))
    img.alpha_composite(sh.filter(ImageFilter.GaussianBlur(6)))
    d.rounded_rectangle([x, y, x + w, y + h], radius=h // 2, fill=color, outline=NAVY, width=6)
    d.text((x + pad - l, y + pad // 2 - t - 2), text, font=font, fill=(255, 255, 255), stroke_width=3, stroke_fill=NAVY)


def caption(img, text, xy, font, fill=(255, 255, 255)):
    ImageDraw.Draw(img).text(xy, text, font=font, fill=fill, stroke_width=max(4, font.size // 10), stroke_fill=NAVY)


def vignette(img, strength=0.35):
    w, h = img.size
    v = Image.new("L", (w, h), 0)
    ImageDraw.Draw(v).ellipse([-w * 0.15, -h * 0.25, w * 1.15, h * 1.25], fill=255)
    v = v.filter(ImageFilter.GaussianBlur(w // 12))
    dark = Image.new("RGBA", (w, h), (20, 16, 50, int(255 * strength)))
    img.alpha_composite(Image.composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), dark, v))


def load(name, size):
    im = Image.open(os.path.join(M, f"raw_{name}.png")).convert("RGBA")
    return im.resize(size, Image.LANCZOS) if im.size != size else im


CAP = os.path.join(M, "captures")


def capture(name, size=(1920, 1080), zoom=1.0, focus=(0.5, 0.5)):
    """인게임 스크린샷을 썸네일 크기로 채워 자르기 (zoom>1이면 focus 지점을 확대)"""
    im = Image.open(os.path.join(CAP, name)).convert("RGBA")
    sc = max(size[0] / im.width, size[1] / im.height) * zoom
    im = im.resize((int(im.width * sc), int(im.height * sc)), Image.LANCZOS)
    cx, cy = int(im.width * focus[0]), int(im.height * focus[1])
    x0 = min(max(0, cx - size[0] // 2), im.width - size[0])
    y0 = min(max(0, cy - size[1] // 2), im.height - size[1])
    return im.crop((x0, y0, x0 + size[0], y0 + size[1]))


def hud_bands(img, top=330, bottom=170, color=(8, 8, 24)):
    """스크린샷 위·아래의 HUD(미션·점수판·체력바)를 흐리게 + 짙은 그라데이션으로 덮어 로고·문구 자리로"""
    w, h = img.size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    for y in range(top):
        k = 1.0 if y < top * 0.55 else 1 - (y - top * 0.55) / (top * 0.45)
        d.line([(0, y), (w, y)], fill=int(255 * k))
    for y in range(h - bottom, h):
        k = min(1.0, (y - (h - bottom)) / (bottom * 0.5))
        d.line([(0, y), (w, y)], fill=int(255 * k))
    blurred = img.filter(ImageFilter.GaussianBlur(26))
    img.paste(blurred, (0, 0), m)
    img.paste(color + (255,), (0, 0), m.point(lambda v: int(v * 0.82)))


def thumbs():
    # 1) 대표: 실제 시가전 교전 장면 + 큰 로고
    im = capture("city_kill.png"); hud_bands(im, 420, 210)
    lg = logo(900); im.alpha_composite(lg, ((1920 - lg.width) // 2, -10))
    sf_plate(im, "팀 페인트 FPS  ·  2:2  3:3  5:5  솔로  ·  랭크전", 945, kr(48))
    im.convert("RGB").save(os.path.join(M, "thumb_1_key.png"), quality=95)
    # 2) 실총 시가전
    im = capture("city_rifle.png"); hud_bands(im, 420, 230)
    lg = logo(560); im.alpha_composite(lg, (30, 0))
    neon_caption(im, "실총으로 즐기는 시가전", (640, 70), kr(96), (255, 236, 90), (255, 120, 0))
    sf_plate(im, "K2 · K2C1 · K3 기관총 · K14 저격 · K5", 925, kr(50))
    im.convert("RGB").save(os.path.join(M, "thumb_2_weapons.png"), quality=95)
    # 3) 페인트 승패: 칠해진 바닥을 확대
    im = capture("city_kill.png", zoom=1.35, focus=(0.42, 0.72)); hud_bands(im, 300, 210)
    lg = logo(520); im.alpha_composite(lg, (1920 - lg.width - 20, 0))
    neon_caption(im, "많이 칠한 팀이 이긴다!", (60, 60), kr(100), (255, 255, 255), (0, 200, 255))
    sf_plate(im, "승패 = 페인트 80% + 처치·미션 20%", 930, kr(52), edge=(255, 40, 200))
    im.convert("RGB").save(os.path.join(M, "thumb_3_paint.png"), quality=95)


def game_icon():
    """아이콘 = 입장 화면 타이틀 그대로 (남색 그라데이션 + 네온 사선 + 로고)"""
    S = 1024
    im = gradient((S, S), (26, 34, 70), (6, 8, 18)).convert("RGBA")
    stripes = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stripes)
    for i in range(7):
        x = -300 + i * 230
        col = (255, 40, 200, 34) if i % 2 == 0 else (240, 255, 40, 30)
        sd.polygon([(x, S), (x + 18, S), (x + 18 + S * 0.45, 0), (x + S * 0.45, 0)], fill=col)
    im.alpha_composite(stripes)
    lg = logo(960)
    im.alpha_composite(lg, ((S - lg.width) // 2, (S - lg.height) // 2 - 10))
    im.resize((512, 512), Image.LANCZOS).convert("RGB").save(os.path.join(M, "game_icon.png"))


# ---------------- 상품 이미지 (원형으로 잘려도 안전하게 가운데 배치)
def badge(colors, icon_names, title, sub, out, ring=(255, 255, 255)):
    S = 1024
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    circle = Image.new("L", (S, S), 0)
    ImageDraw.Draw(circle).ellipse([20, 20, S - 20, S - 20], fill=255)
    im.paste(gradient((S, S), *colors).convert("RGBA"), (0, 0), circle)
    # 방사형 빛줄기
    rays = Image.new("L", (S, S), 0)
    dr = ImageDraw.Draw(rays)
    for k in range(16):
        a0 = k * math.tau / 16
        dr.polygon([(S / 2, S / 2), (S / 2 + math.cos(a0) * S, S / 2 + math.sin(a0) * S),
                    (S / 2 + math.cos(a0 + 0.12) * S, S / 2 + math.sin(a0 + 0.12) * S)], fill=60)
    im.paste((255, 255, 255, 255), (0, 0), Image.composite(rays, Image.new("L", (S, S), 0), circle))
    ImageDraw.Draw(im).ellipse([20, 20, S - 20, S - 20], outline=NAVY, width=22)
    ImageDraw.Draw(im).ellipse([44, 44, S - 44, S - 44], outline=ring, width=10)
    n = len(icon_names)
    for i, nm in enumerate(icon_names):
        ic = Image.open(os.path.join(ICONS, nm + ".png")).convert("RGBA")
        size = 520 if n == 1 else (420 if n <= 3 else 340)
        ic = ic.resize((size, size), Image.LANCZOS)
        if n == 1:
            pos = ((S - size) // 2, 170)
        else:
            a = (i - (n - 1) / 2) * 0.55
            pos = (int(S / 2 - size / 2 + math.sin(a) * 210), int(240 - math.cos(a) * 30 + abs(i - (n - 1) / 2) * 40))
        im.alpha_composite(ic, pos)
    t = styled_text(title, kr(150) if not title.isascii() else latin(190), GOLD if title == "VIP" else [(255, 255, 255), (220, 228, 255)])
    im.alpha_composite(t, ((S - t.width) // 2, 640))
    if sub:
        s = styled_text(sub, kr(64), [(255, 255, 255), (230, 236, 255)], shadow=False)
        im.alpha_composite(s, ((S - s.width) // 2, 830))
    im.resize((512, 512), Image.LANCZOS).save(os.path.join(M, out))


def products():
    badge([(255, 210, 80), (230, 120, 10)], ["crown"], "VIP", "코인 1.25배", "pass_vip.png")
    badge([(180, 100, 255), (90, 30, 190)], ["chest"], "크레이트", "스킨 · 패턴 · 이펙트", "product_crate.png")
    badge([(90, 220, 255), (0, 110, 230)], ["coin"], "500", "코인", "product_coins_500.png")
    badge([(90, 220, 255), (0, 110, 230)], ["coin", "coin", "coin"], "1,200", "코인", "product_coins_1200.png")
    badge([(90, 220, 255), (0, 110, 230)], ["coin", "coin", "coin", "coin", "coin"], "3,000", "코인", "product_coins_3000.png")


if __name__ == "__main__":
    products()
    game_icon()
    if all(os.path.exists(os.path.join(CAP, n)) for n in ("city_kill.png", "city_rifle.png")):
        thumbs()
    print("done", sorted(f for f in os.listdir(M) if not f.startswith(("raw_", "_"))))
