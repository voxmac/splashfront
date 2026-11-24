"""SPLASH FRONT situational sound effects, synthesised from scratch (no samples, no third-party audio).
usage: python tools/make_sfx.py assets/sfx   -> <name>.ogg for Roblox + _preview.mp3 (all sounds in a row) + sfx.json
Paint guns are air-powered toys that shoot liquid: every shot = pneumatic pop + body tone + wet spray, sized per weapon."""
import json, os, subprocess, sys
import numpy as np
from scipy.signal import butter, sosfilt, fftconvolve

SR = 44100
rng = np.random.default_rng(2026)
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/sfx"
os.makedirs(OUT, exist_ok=True)


# ---------------------------------------------------------------- building blocks
def t_(d): return np.arange(int(SR * d)) / SR
def noise(d): return rng.standard_normal(int(SR * d))
def bp(x, lo, hi, o=2): return sosfilt(butter(o, [lo, min(hi, SR / 2 - 100)], btype="band", fs=SR, output="sos"), x)
def lp(x, f, o=2): return sosfilt(butter(o, f, btype="low", fs=SR, output="sos"), x)
def hp(x, f, o=2): return sosfilt(butter(o, f, btype="high", fs=SR, output="sos"), x)
def edecay(d, k): return np.exp(-t_(d) * k)
def sweep(f0, f1, d, shape="exp"):
    t = t_(d)
    f = f0 * (f1 / f0) ** (t / d) if shape == "exp" else f0 + (f1 - f0) * t / d
    return np.sin(2 * np.pi * np.cumsum(f) / SR)
def tri(f, d):
    ph = (np.cumsum(np.full(int(SR * d), f)) / SR) % 1
    return 2 * np.abs(2 * ph - 1) - 1
def attack(x, ms=2):
    n = max(1, int(SR * ms / 1000)); x = x.copy(); x[:n] *= np.linspace(0, 1, n); return x
def fadeout(x, ms=30):
    n = min(len(x), int(SR * ms / 1000)); x = x.copy(); x[-n:] *= np.linspace(1, 0, n) ** 2; return x
def mix(*parts):
    n = max(int(start * SR) + len(p) for start, p in parts)
    out = np.zeros(n)
    for start, p in parts:
        s = int(start * SR); e = min(n, s + len(p)); out[s:e] += p[: e - s]
    return out
def pad(x, d): return np.concatenate([x, np.zeros(int(SR * d))])
def room(x, size=0.25, wet=0.18):
    """Small bright room: short noise impulse response."""
    ir = noise(size) * edecay(size, 18 / size * 0.35); ir = hp(ir, 300); ir /= np.abs(ir).sum() / 6
    y = fftconvolve(x, ir)[: len(x) + int(SR * size)]
    return pad(x, size)[: len(y)] * (1 - wet) + y * wet
def note(m): return 440 * 2 ** ((m - 69) / 12)
def bell(m, d=0.8, vol=0.4):
    f = note(m); t = t_(d)
    x = sum(a * np.sin(2 * np.pi * f * k * t) * np.exp(-t * r) for k, a, r in [(1, 1, 4), (2.0, .5, 6), (3.01, .25, 9), (4.2, .12, 12)])
    return attack(x, 1) * vol


# ---------------------------------------------------------------- paint guns
def wet(d, lo, hi, k):
    """Liquid spray: band noise with fast random amplitude flutter (droplets)."""
    n = bp(noise(d), lo, hi)
    flutter = 0.55 + 0.45 * np.abs(lp(noise(d), 120))
    return n * flutter * edecay(d, k)

def gunshot(pop_f, body_f0, body_f1, d, spray_lo, spray_hi, spray_k, weight=1.0, click=0.3):
    pop = bp(noise(0.03), 1500, 9000) * edecay(0.03, 160) * click                      # valve click
    puff = lp(noise(d), 900) * edecay(d, 22) * 0.9 * weight                             # air burst
    body = sweep(body_f0, body_f1, d) * edecay(d, 18) * 0.55 * weight                    # gun body tone
    thump = np.sin(2 * np.pi * pop_f * t_(0.12)) * edecay(0.12, 35) * 0.6 * weight       # low punch
    spray = wet(d * 1.2, spray_lo, spray_hi, spray_k) * 0.7                             # liquid leaving
    return room(attack(mix((0, pop), (0, puff), (0, body), (0, thump), (0.005, spray))), 0.18, 0.12)

def fire_pistol():   return gunshot(140, 900, 300, 0.18, 1200, 6000, 20)
def fire_rifle():    return gunshot(120, 700, 260, 0.14, 1000, 5500, 26, 1.1, 0.4)
def fire_smg():      return gunshot(170, 1200, 500, 0.09, 1800, 7000, 40, 0.8, 0.35)
def fire_shotgun():
    x = gunshot(80, 500, 120, 0.32, 600, 5000, 9, 1.6, 0.5)
    for i in range(7):   # pellets scattering
        x = mix((0, x), (0.02 + 0.012 * i, wet(0.08, 2000, 7000, 40) * 0.25))
    return x
def fire_sniper():
    charge = sweep(300, 1800, 0.12) * np.linspace(0, 1, int(SR * 0.12)) ** 2 * 0.25       # pressure build
    shot = gunshot(70, 600, 90, 0.45, 800, 8000, 7, 1.8, 0.7)
    crack = hp(noise(0.05), 3000) * edecay(0.05, 90) * 0.6
    tailw = bp(noise(0.9), 400, 2500) * edecay(0.9, 4) * 0.12                             # whistling drop trail
    return mix((0, charge), (0.1, shot), (0.1, crack), (0.15, tailw))
def fire_launcher():
    thunk = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 60, int(SR * 0.25))) / SR) * edecay(0.25, 12)
    glug = sum(sweep(320 + 90 * i, 140, 0.12) * edecay(0.12, 25) * 0.25 for i in range(3))
    return room(mix((0, thunk * 0.9), (0, lp(noise(0.3), 700) * edecay(0.3, 15) * 0.6), (0.03, glug), (0.06, glug * 0.7)), 0.25, 0.2)
def low_ink():
    c = hp(noise(0.02), 2500) * edecay(0.02, 200)
    sput = wet(0.15, 400, 2000, 30) * 0.3
    return mix((0, c * 0.8), (0.01, sput), (0.12, c * 0.5))


# ---------------------------------------------------------------- real guns (K-series): crack + blast + low thump + bolt + echo tail
def real_shot(crack=1.0, blast_lo=250, blast_hi=3200, blast_d=0.14, thump_f=(95, 45), weight=1.0, bolt=0.35, tail=0.6, tail_lo=180, tail_hi=1400):
    crack_ = hp(noise(0.02), 2600) * edecay(0.02, 260) * 1.2 * crack                    # 총구 파열음
    blast = bp(noise(blast_d), blast_lo, blast_hi) * edecay(blast_d, 30) * 0.95 * weight   # 폭발 압력
    th = np.sin(2 * np.pi * np.cumsum(np.linspace(thump_f[0], thump_f[1], int(SR * 0.16))) / SR) * edecay(0.16, 22) * 0.9 * weight
    mech = bp(noise(0.012), 3000, 7000) * edecay(0.012, 300) * 0.35
    boltc = bp(noise(0.02), 2200, 6000) * edecay(0.02, 220) * bolt                      # 노리쇠 소리
    echo = bp(noise(tail), tail_lo, tail_hi) * edecay(tail, 5.5 / tail) * 0.22 * weight   # 건물 사이 메아리
    x = mix((0, crack_), (0, blast), (0, th), (0, mech), (0.055, boltc), (0.03, echo))
    return room(attack(x, 1), 0.35, 0.16)
def fire_k2():    return real_shot(1.0, 250, 3200, 0.13, (95, 45), 1.0, 0.3, 0.55)
def fire_k2c1():  return real_shot(1.15, 350, 4200, 0.10, (110, 55), 0.85, 0.3, 0.45)
def fire_k3():    return real_shot(0.9, 180, 2600, 0.15, (80, 38), 1.25, 0.25, 0.6, 150, 1200)
def fire_k14():
    x = real_shot(1.4, 150, 3800, 0.24, (70, 30), 1.7, 0.0, 1.4, 120, 1100)
    bolt_cycle = mix((0, bp(noise(0.03), 1500, 5000) * edecay(0.03, 120) * 0.35), (0.09, bp(noise(0.03), 1800, 6000) * edecay(0.03, 140) * 0.3))
    return mix((0, x), (0.55, bolt_cycle))
def fire_k5():    return real_shot(1.2, 400, 4500, 0.08, (130, 70), 0.7, 0.45, 0.35, 250, 1800)
def hit_real():
    # 몸통 명중: 둔탁한 타격 + 짧은 금속성 틱 (총알이 박히는 느낌)
    thud = lp(noise(0.09), 700) * edecay(0.09, 45) * 0.9
    knock = np.sin(2 * np.pi * np.cumsum(np.linspace(180, 70, int(SR * 0.07))) / SR) * edecay(0.07, 55) * 0.8
    tick = bp(noise(0.015), 2500, 6000) * edecay(0.015, 250) * 0.45
    return attack(mix((0, thud), (0, knock), (0, tick)), 1)
def hit_real_head():
    ding = mix((0, bell(98, 0.35, 0.4)), (0, bell(105, 0.3, 0.2)))
    return mix((0, hit_real() * 0.9), (0.004, ding))


# ---------------------------------------------------------------- hits and kills
def splat(size=1.0):
    d = 0.35 * size
    body = lp(noise(d), 1800) * edecay(d, 14 / size)
    smack = np.sin(2 * np.pi * np.cumsum(np.linspace(260, 90, int(SR * 0.08))) / SR) * edecay(0.08, 40)
    drops = np.zeros(int(SR * d * 1.6))
    for _ in range(int(6 * size)):
        s = rng.uniform(0.04, d); f = rng.uniform(700, 1600)
        p = sweep(f, f * 0.55, 0.05) * edecay(0.05, 60) * rng.uniform(0.1, 0.25)
        i = int(s * SR); drops[i:i + len(p)] += p[: len(drops) - i]
    return attack(mix((0, body * 0.8), (0, smack * 0.7), (0, drops)))
def hit():       return room(splat(0.8), 0.15, 0.1)
def hit_head():
    ding = mix((0, bell(96, 0.5, 0.35)), (0, bell(103, 0.4, 0.15)))
    return mix((0, splat(0.8)), (0.005, ding))
def kill():
    big = splat(1.8)
    chime = mix((0, bell(84, 0.6, 0.25)), (0.07, bell(88, 0.6, 0.25)), (0.14, bell(91, 0.9, 0.3)))
    whoosh = bp(noise(0.4), 600, 4000) * np.sin(np.pi * t_(0.4) / 0.4) ** 2 * 0.2
    return room(mix((0, big), (0.02, whoosh), (0.08, chime)), 0.3, 0.2)
def hurt():
    thud = np.sin(2 * np.pi * np.cumsum(np.linspace(150, 55, int(SR * 0.18))) / SR) * edecay(0.18, 14)
    return mix((0, thud * 0.9), (0, lp(splat(0.6), 900) * 0.6))
def splashed():   # you were splashed (death)
    down = sweep(700, 120, 0.7) * edecay(0.7, 3) * 0.3
    return mix((0, splat(2.2)), (0.05, down), (0.1, lp(noise(0.8), 500) * edecay(0.8, 4) * 0.3))
def paint_land(): return splat(0.45) * 0.6


# ---------------------------------------------------------------- movement and map
def jump_pad():
    boing = np.sin(2 * np.pi * np.cumsum(280 * 2.4 ** (t_(0.35) / 0.35) * (1 + 0.05 * np.sin(2 * np.pi * 24 * t_(0.35)))) / SR) * edecay(0.35, 6)
    whoosh = bp(noise(0.6), 500, 5000) * np.linspace(1, 0, int(SR * 0.6)) ** 1.5 * 0.35
    return room(mix((0, boing * 0.5), (0, lp(noise(0.06), 400) * edecay(0.06, 50)), (0.05, whoosh)), 0.2, 0.15)
def zipline_start():
    clank = sum(np.sin(2 * np.pi * f * t_(0.25)) * edecay(0.25, k) for f, k in [(1250, 14), (1870, 18), (2950, 25)]) * 0.18
    return mix((0, attack(clank)), (0, hp(noise(0.02), 2000) * edecay(0.02, 150) * 0.5))
def zipline_ride():
    d = 1.6; t = t_(d)
    whir = bp(noise(d), 900, 3500) * (0.6 + 0.4 * np.sin(2 * np.pi * 9 * t)) * 0.35
    tone = sweep(520, 820, d) * 0.06
    return fadeout(attack(whir + tone, 60) * np.minimum(1, t / 0.3), 300)
def land():       return lp(noise(0.08), 600) * edecay(0.08, 40) * 0.7
def respawn():
    up = sweep(300, 1200, 0.45) * np.sin(np.pi * t_(0.45) / 0.45) * 0.25
    return mix((0, up), (0, bp(noise(0.45), 1500, 6000) * np.sin(np.pi * t_(0.45) / 0.45) ** 2 * 0.15), (0.4, bell(88, 0.4, 0.15)))


# ---------------------------------------------------------------- objectives and match flow
def flag_capturing(): return bell(79, 0.12, 0.25) + 0.3 * np.sin(2 * np.pi * 1568 * t_(0.12)) * edecay(0.12, 40)
def flag_captured():
    notes = [72, 76, 79, 84]
    return room(mix(*[(0.09 * i, bell(m, 0.8, 0.3)) for i, m in enumerate(notes)], (0.3, splat(1.0) * 0.4)), 0.4, 0.2)
def flag_lost():
    return mix(*[(0.12 * i, tri(note(m), 0.2) * edecay(0.2, 10) * 0.2) for i, m in enumerate([76, 72, 67])])
def mission_start():
    stab = sum(tri(note(m), 0.35) * edecay(0.35, 7) for m in (69, 72, 76)) * 0.15
    return mix((0, stab), (0.18, stab * 0.8), (0, bp(noise(0.3), 2000, 7000) * edecay(0.3, 10) * 0.15))
def mission_success():
    return room(mix(*[(0.08 * i, bell(m, 0.7, 0.28)) for i, m in enumerate([79, 83, 86, 91])]), 0.4, 0.2)
def mission_fail(): return mix((0, tri(note(64), 0.25) * edecay(0.25, 8) * 0.2), (0.18, tri(note(59), 0.4) * edecay(0.4, 6) * 0.2))
def countdown_tick(): return tri(note(81), 0.12) * edecay(0.12, 30) * 0.3
def countdown_go():
    return mix((0, sum(tri(note(m), 0.5) * edecay(0.5, 5) for m in (81, 85, 88)) * 0.15), (0, splat(0.7) * 0.4))
def final_splash():
    d = 1.4; t = t_(d)
    siren = np.sin(2 * np.pi * np.cumsum(700 + 300 * np.sin(2 * np.pi * 3 * t)) / SR) * 0.15
    riser = bp(noise(d), 500, 5000) * (t / d) ** 2 * 0.3
    return fadeout(mix((0, siren), (0, riser), (d - 0.05, splat(1.3) * 0.6)), 80)
def special_ready(): return mix(*[(0.06 * i, bell(m, 0.5, 0.22)) for i, m in enumerate([84, 88, 91, 96])])
def special_throw():
    return mix((0, bp(noise(0.45), 400, 3000) * np.sin(np.pi * t_(0.45) / 0.45) ** 2 * 0.35), (0, sweep(400, 900, 0.3) * edecay(0.3, 6) * 0.15))
def special_boom():
    boom = np.sin(2 * np.pi * np.cumsum(np.linspace(95, 32, int(SR * 1.2))) / SR) * edecay(1.2, 3) * 0.9
    return room(mix((0, boom), (0, splat(3.0) * 0.8), (0.05, lp(noise(1.0), 1200) * edecay(1.0, 3) * 0.4)), 0.5, 0.25)


# ---------------------------------------------------------------- UI, shop, crate
def ui_click(): return mix((0, hp(noise(0.01), 3000) * edecay(0.01, 300) * 0.4), (0, np.sin(2 * np.pi * 1800 * t_(0.04)) * edecay(0.04, 90) * 0.25))
def ui_buy():
    coin = lambda m: (np.sin(2 * np.pi * note(m) * t_(0.3)) + 0.4 * np.sin(2 * np.pi * note(m) * 2.7 * t_(0.3))) * edecay(0.3, 9) * 0.22
    return mix((0, coin(88)), (0.08, coin(95)))
def ui_error(): return mix((0, tri(220, 0.12) * edecay(0.12, 15) * 0.25), (0.13, tri(196, 0.18) * edecay(0.18, 12) * 0.25))
def crate_shake():
    return mix(*[(0.08 * i, lp(noise(0.06), 1500) * edecay(0.06, 40) * 0.5 + np.sin(2 * np.pi * 180 * t_(0.06)) * edecay(0.06, 30) * 0.3) for i in range(6)])
def crate_reveal(level):
    base = {"rare": [72, 76, 79], "epic": [72, 76, 79, 84, 88], "legendary": [72, 76, 79, 84, 88, 91, 96]}[level]
    parts = [(0.07 * i, bell(m, 1.0, 0.25)) for i, m in enumerate(base)]
    parts.append((0, splat(1.0 + 0.5 * len(base) / 7) * 0.5))
    if level == "legendary":
        parts.append((0.5, bp(noise(1.2), 4000, 12000) * edecay(1.2, 2.5) * 0.12))   # sparkle shimmer
    return room(mix(*parts), 0.5, 0.25)


SOUNDS = {
    # 무기 (발사)
    "fire_pistol": fire_pistol, "fire_rifle": fire_rifle, "fire_smg": fire_smg, "fire_shotgun": fire_shotgun,
    "fire_sniper": fire_sniper, "fire_launcher": fire_launcher, "low_ink": low_ink,
    # 명중·처치
    "hit": hit, "hit_head": hit_head, "kill": kill, "hurt": hurt, "splashed": splashed, "paint_land": paint_land,
    # 이동·맵
    "jump_pad": jump_pad, "zipline_start": zipline_start, "zipline_ride": zipline_ride, "land": land, "respawn": respawn,
    # 목표·경기 흐름
    "flag_capturing": flag_capturing, "flag_captured": flag_captured, "flag_lost": flag_lost,
    "mission_start": mission_start, "mission_success": mission_success, "mission_fail": mission_fail,
    "countdown_tick": countdown_tick, "countdown_go": countdown_go, "final_splash": final_splash,
    "special_ready": special_ready, "special_throw": special_throw, "special_boom": special_boom,
    # UI·상점·크레이트
    "ui_click": ui_click, "ui_buy": ui_buy, "ui_error": ui_error, "crate_shake": crate_shake,
    "crate_rare": lambda: crate_reveal("rare"), "crate_epic": lambda: crate_reveal("epic"), "crate_legendary": lambda: crate_reveal("legendary"),
    # 실총 (K 시리즈) — 기존 소리 순서·난수가 바뀌지 않게 맨 뒤에 추가
    "fire_k2": fire_k2, "fire_k2c1": fire_k2c1, "fire_k3": fire_k3, "fire_k14": fire_k14, "fire_k5": fire_k5,
    "hit_real": hit_real, "hit_real_head": hit_real_head,
}

if __name__ == "__main__":
    import soundfile as sf
    info, chain = {}, []
    for name, fn in SOUNDS.items():
        x = np.asarray(fn(), dtype=np.float64)
        x = fadeout(x, 15)
        peak = np.abs(x).max()
        assert np.isfinite(x).all() and peak > 0, name
        x = x / peak * 0.89                                  # -1 dBFS
        sf.write(f"/tmp/{name}.wav", x.astype(np.float32), SR)
        subprocess.run(f"ffmpeg -loglevel error -y -i /tmp/{name}.wav -c:a libvorbis -q:a 6 {OUT}/{name}.ogg", shell=True, check=True)
        info[name] = round(len(x) / SR, 2)
        chain += [x, np.zeros(int(SR * 0.45))]
    # atlas: every sound in one file (one Roblox upload instead of 37) -> Sound.PlaybackRegion plays one slice
    atlas, pos, regions = [], 0.0, {}
    for name in SOUNDS:
        import soundfile as _sf
        x, _ = _sf.read(f"/tmp/{name}.wav")
        regions[name] = [round(pos, 3), round(pos + len(x) / SR, 3)]
        atlas += [x, np.zeros(int(SR * 0.5))]; pos += len(x) / SR + 0.5
    sf.write("/tmp/sfx_atlas.wav", np.concatenate(atlas).astype(np.float32), SR)
    subprocess.run(f"ffmpeg -loglevel error -y -i /tmp/sfx_atlas.wav -c:a libvorbis -q:a 6 {OUT}/sfx_atlas.ogg", shell=True, check=True)
    json.dump(regions, open(f"{OUT}/atlas.json", "w"), indent=1)
    sf.write("/tmp/_preview.wav", np.concatenate(chain).astype(np.float32), SR)
    subprocess.run(f"ffmpeg -loglevel error -y -i /tmp/_preview.wav -b:a 160k {OUT}/_preview.mp3", shell=True, check=True)
    json.dump({"order": list(SOUNDS), "seconds": info, "note": "synthesised by tools/make_sfx.py, no samples"},
              open(f"{OUT}/sfx.json", "w"), indent=1)
    print(len(info), "sounds", round(sum(info.values()), 1), "s total")
