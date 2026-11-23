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
    """SPLASH(분홍) / FRONT(하늘) 2단 로고 + 흘러내리는 페인트"""
    f1 = latin(int(width * 0.26))
    f2 = latin(int(width * 0.2))
    a = styled_text("SPLASH", f1, PINK)
    b = styled_text("FRONT", f2, CYAN)
    W = max(a.width, b.width) + 40
    H = a.height + b.height - int(width * 0.06) + int(width * 0.12)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    drips(dr, W * 0.12, W * 0.88, a.height * 0.8, PINK[1], 9, 3, width / 900)
    out.alpha_composite(dr)
    out.alpha_composite(a, ((W - a.width) // 2, 0))
    out.alpha_composite(b, ((W - b.width) // 2 + int(width * 0.04), a.height - int(width * 0.08)))
    return out


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


def thumbs():
    # 1) 대표: 큰 로고 + 아래 띠
    im = load("key", (1920, 1080)); vignette(im, 0.28)
    lg = logo(860); im.alpha_composite(lg, ((1920 - lg.width) // 2, 30))
    ribbon(im, "팀 페인트 FPS  ·  2:2  3:3  5:5  솔로  ·  랭크전", 930, kr(54))
    im.convert("RGB").save(os.path.join(M, "thumb_1_key.png"), quality=95)
    # 2) 무기·저격
    im = load("sniper", (1920, 1080)); vignette(im, 0.3)
    lg = logo(460); im.alpha_composite(lg, (40, 30))
    caption(im, "6종 페인트총", (70, 640), kr(120), (255, 225, 90))
    caption(im, "저격 스코프 · 산탄 · 런처 · 제트팩", (76, 800), kr(58))
    im.convert("RGB").save(os.path.join(M, "thumb_2_weapons.png"), quality=95)
    # 3) 맵·페인트 승패
    im = load("map", (1920, 1080)); vignette(im, 0.25)
    lg = logo(420); im.alpha_composite(lg, (1920 - lg.width - 40, 26))
    caption(im, "많이 칠한 팀이 이긴다!", (70, 70), kr(104), (255, 255, 255))
    ribbon(im, "승패 = 페인트 80% + 처치·미션 20%", 940, kr(56), (0, 150, 255))
    im.convert("RGB").save(os.path.join(M, "thumb_3_paint.png"), quality=95)


def game_icon():
    im = load("icon", (1024, 1024)); vignette(im, 0.22)
    lg = logo(760)
    lg = lg.resize((int(lg.width * 0.92), int(lg.height * 0.92)), Image.LANCZOS)
    im.alpha_composite(lg, ((1024 - lg.width) // 2, 1024 - lg.height - 10))
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
    have = [n for n in ("key", "sniper", "map", "icon") if os.path.exists(os.path.join(M, f"raw_{n}.png"))]
    if "icon" in have:
        game_icon()
    if all(n in have for n in ("key", "sniper", "map")):
        thumbs()
    print("done", sorted(f for f in os.listdir(M) if not f.startswith(("raw_", "_"))))
