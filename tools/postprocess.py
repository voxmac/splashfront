"""BGM takes -> game-ready files.  usage: python tools/postprocess.py bgm/SF01.json DOWNLOAD_DIR assets/audio
For each track: score every take (no silence/NaN, steady loudness = loops well, no long fade-out), pick the best
(or spec["pick"][track]), then
  - looping tracks (duration >= 30 s): cut to whole 4-bar phrases and blend the audio after the cut into the start,
    so Sound.Looped plays without a seam
  - jingles: trim silence, short fade-out
Loudness: BGM -16 LUFS, jingles -13 LUFS. Writes <track>.ogg (Roblox upload) + <track>.mp3 (listening) + manifest.json."""
import glob, json, os, subprocess, sys
import numpy as np
import soundfile as sf

spec_path, src_dir, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
spec = json.load(open(spec_path, encoding="utf-8"))
os.makedirs(out_dir, exist_ok=True)
picks = spec.get("pick", {})


def find(name):
    hits = glob.glob(os.path.join(src_dir, "**", name), recursive=True)
    return hits[0] if hits else None


def score(x, sr):
    """Higher is better. Steady RMS (loops well), no silence, no fade-out over the last 8 s."""
    mono = x.mean(axis=1) if x.ndim > 1 else x
    if not np.isfinite(mono).all() or np.abs(mono).max() < 1e-3:
        return -1e9, {}
    win = sr
    rms = np.array([np.sqrt(np.mean(mono[i:i + win] ** 2)) for i in range(0, len(mono) - win, win)])
    if len(rms) < 4:
        return -1e9, {}
    body = rms[2:-2] if len(rms) > 8 else rms
    cv = float(body.std() / (body.mean() + 1e-9))
    silent = float((rms < 0.01).mean())
    tail = float(rms[-8:].mean() / (body.mean() + 1e-9)) if len(rms) > 10 else 1.0
    s = -cv * 2 - silent * 5 - max(0.0, 0.7 - tail)
    return s, {"loudness_variation": round(cv, 3), "silent_share": round(silent, 3), "tail_level": round(tail, 2)}


def loop_cut(x, sr, bpm):
    bar = 4 * 60 / bpm
    phrase = 4 * bar
    start = int(round(2 * bar * sr)) if len(x) / sr > 40 else 0     # skip a two-bar intro on long tracks
    usable = len(x) / sr - start / sr - 6                            # leave room for the blend and the ending
    n = max(1, int(usable // phrase))
    end = start + int(round(n * phrase * sr))
    L = int(round(bar / 2 * sr))                                     # half a bar of crossfade
    y = x[start:end].copy()
    tail = x[end:end + L]
    L = min(L, len(tail))
    fade = np.linspace(0, 1, L)[:, None] if y.ndim > 1 else np.linspace(0, 1, L)
    y[:L] = y[:L] * fade + tail[:L] * (1 - fade)
    return y, round(n * phrase, 2)


def jingle_cut(x, sr):
    mono = np.abs(x.mean(axis=1) if x.ndim > 1 else x)
    on = np.where(mono > 0.01)[0]
    a, b = (on[0], on[-1]) if len(on) else (0, len(x))
    y = x[max(0, a - int(0.01 * sr)): min(len(x), b + int(0.3 * sr))].copy()
    L = min(len(y), int(0.4 * sr))
    fade = np.linspace(1, 0, L)[:, None] if y.ndim > 1 else np.linspace(1, 0, L)
    y[-L:] *= fade
    return y


def export(y, sr, name, lufs):
    tmp = f"/tmp/{name}.wav"
    sf.write(tmp, y, sr)
    for ext, codec in (("ogg", "-c:a libvorbis -q:a 6"), ("mp3", "-b:a 192k")):
        subprocess.run(f'ffmpeg -loglevel error -y -i {tmp} -af loudnorm=I={lufs}:TP=-1.5:LRA=11 -ar 44100 {codec} "{out_dir}/{name}.{ext}"',
                       shell=True, check=True)


manifest = {"job": spec["id"], "tracks": {}}
for t in spec["tracks"]:
    name = t["name"]
    takes = []
    for i, _ in enumerate(t.get("seeds", [])):
        f = find(f"{name}_v{i + 1}.wav")
        if not f:
            continue
        x, sr = sf.read(f, dtype="float32", always_2d=True)
        sc, info = score(x, sr)
        takes.append({"version": i + 1, "file": os.path.basename(f), "score": round(sc, 3), **info, "_x": x, "_sr": sr})
    if not takes:
        print("no takes for", name); continue
    want = picks.get(name)
    best = next((k for k in takes if k["version"] == want), None) or max(takes, key=lambda k: k["score"])
    x, sr = best["_x"], best["_sr"]
    if t.get("duration", 90) >= 30:
        y, length = loop_cut(x, sr, t.get("bpm", 120)); kind, lufs = "loop", -16
    else:
        y = jingle_cut(x, sr); length = round(len(y) / sr, 2); kind, lufs = "jingle", -13
    export(y, sr, name, lufs)
    manifest["tracks"][name] = {"kind": kind, "seconds": length, "picked": best["version"], "picked_by": "spec" if want else "auto",
                                "takes": [{k: v for k, v in tk.items() if not k.startswith("_")} for tk in takes]}
    print(name, kind, length, "s  <- v%d" % best["version"], flush=True)
json.dump(manifest, open(os.path.join(out_dir, "manifest.json"), "w"), indent=1, ensure_ascii=False)
