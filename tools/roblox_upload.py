"""Uploads game assets to Roblox with Open Cloud and records their asset IDs.
usage: ROBLOX_API_KEY=... ROBLOX_CREATOR=user:12345 python tools/roblox_upload.py [audio|models|images|all]
  images : assets/textures/*.png (surface textures) + assets/icons/*.png (HUD icons) as Decals
  audio  : assets/audio/<track>.ogg (BGM 5) + assets/sfx/sfx_atlas.ogg (all 37 effects in one file)
  models : assets/models/*.fbx (6 guns + helmet + backpack)
Skips files already uploaded with the same content (sha1 in assets/roblox_ids.json).
Then run tools/write_asset_ids.py (the workflow does) so the game picks the IDs up.
The creator must own the game (same user, or the group that owns it): Roblox only plays audio / loads models
the experience owner may use. API key permissions: Assets API -> read + write."""
import hashlib, json, os, sys, time
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEY = os.environ.get("ROBLOX_API_KEY", "")
CREATOR = os.environ.get("ROBLOX_CREATOR", "")       # "user:123" or "group:456"
WHAT = sys.argv[1] if len(sys.argv) > 1 else "all"
API = "https://apis.roblox.com/assets/v1"
IDS = os.path.join(ROOT, "assets", "roblox_ids.json")

KEY = KEY.strip()
CREATOR = CREATOR.strip().replace(" ", "").lower()
if CREATOR.isdigit():                       # just a number -> a user id
    CREATOR = "user:" + CREATOR
for prefix in ("userid:", "userid=", "user=", "groupid:", "groupid=", "group="):
    if CREATOR.startswith(prefix):
        CREATOR = ("user:" if prefix.startswith("user") else "group:") + CREATOR[len(prefix):]
def _resolve_name(kind, name):
    """user:VOXCHOI -> user:<numeric id> (group names are resolved via search)."""
    import json as _j, urllib.request as _u
    try:
        if kind == "user":
            req = _u.Request("https://users.roblox.com/v1/usernames/users",
                             data=_j.dumps({"usernames": [name], "excludeBannedUsers": False}).encode(),
                             headers={"Content-Type": "application/json"})
            data = _j.load(_u.urlopen(req, timeout=20)).get("data", [])
            return str(data[0]["id"]) if data else ""
        url = "https://groups.roblox.com/v1/groups/search/lookup?groupName=" + __import__("urllib.parse").parse.quote(name)
        data = _j.load(_u.urlopen(url, timeout=20)).get("data", [])
        return str(data[0]["id"]) if data else ""
    except Exception as e:
        print("name lookup failed:", e)
        return ""
if ":" in CREATOR and not CREATOR.split(":", 1)[1].isdigit() and CREATOR.split(":")[0] in ("user", "group"):
    _k, _n = CREATOR.split(":", 1)
    _id = _resolve_name(_k, _n)
    if _id:
        print(f"resolved {_k} name ({len(_n)} chars) -> id {_id}")
        CREATOR = f"{_k}:{_id}"
if not KEY or ":" not in CREATOR or not CREATOR.split(":", 1)[1].isdigit() or CREATOR.split(":")[0] not in ("user", "group"):
    sys.exit(f"Set ROBLOX_API_KEY and ROBLOX_CREATOR as user:<id> or group:<id> (got a {len(CREATOR)}-character value"
             f"{', no digits' if not any(c.isdigit() for c in CREATOR) else ''})")
kind, cid = CREATOR.split(":", 1)
creator = {"userId": cid} if kind == "user" else {"groupId": cid}
ids = json.load(open(IDS, encoding="utf-8")) if os.path.exists(IDS) else {}
hashes = ids.pop("_sha1", {})


def sha1(path):
    return hashlib.sha1(open(path, "rb").read()).hexdigest()


def upload(key, path, asset_type, name, desc, mime):
    h = sha1(path)
    if ids.get(key) and hashes.get(key) == h:
        print("skip (same file)", key, ids[key]); return
    req = {"assetType": asset_type, "displayName": name[:50], "description": desc[:1000], "creationContext": {"creator": creator}}
    for attempt in range(4):
        r = requests.post(f"{API}/assets", headers={"x-api-key": KEY},
                          files={"request": (None, json.dumps(req), "application/json"),
                                 "fileContent": (os.path.basename(path), open(path, "rb"), mime)}, timeout=120)
        if r.status_code == 429:
            time.sleep(10 * (attempt + 1)); continue
        break
    if r.status_code >= 300:
        print("FAILED", key, r.status_code, r.text[:400]); return
    op = r.json()
    op_id = op.get("operationId") or op.get("path", "").split("/")[-1]
    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(3)
        op = requests.get(f"{API}/operations/{op_id}", headers={"x-api-key": KEY}, timeout=60).json()
    asset_id = (op.get("response") or {}).get("assetId")
    if not asset_id:
        print("NO ASSET ID", key, json.dumps(op)[:400]); return
    ids[key] = int(asset_id); hashes[key] = h
    print("uploaded", key, asset_id, flush=True)
    save()


def save():
    out = dict(ids); out["_sha1"] = hashes
    json.dump(out, open(IDS, "w", encoding="utf-8"), indent=1, ensure_ascii=False)


if WHAT in ("audio", "all"):
    for track in ["lobby", "chroma", "sky", "victory", "defeat"]:
        p = os.path.join(ROOT, "assets", "audio", f"{track}.ogg")
        if os.path.exists(p):
            upload(f"music/{track}", p, "Audio", f"SPLASH FRONT BGM {track}", "SPLASH FRONT background music (ACE-Step 1.5)", "audio/ogg")
        else:
            print("not made yet:", p)
    p = os.path.join(ROOT, "assets", "sfx", "sfx_atlas.ogg")
    upload("sfx/atlas", p, "Audio", "SPLASH FRONT SFX atlas", "All SPLASH FRONT sound effects in one file (synthesised)", "audio/ogg")
if WHAT in ("models", "all"):
    for p in sorted(__import__("glob").glob(os.path.join(ROOT, "assets", "models", "*.fbx"))):
        name = os.path.basename(p)[:-4]
        upload(f"model/{name}", p, "Model", f"SPLASH FRONT {name}", "SPLASH FRONT model (Blender)", "model/fbx")
if WHAT in ("images", "all"):
    import glob as _g
    for folder, prefix in (("textures", "tex"), ("icons", "icon")):
        for p in sorted(_g.glob(os.path.join(ROOT, "assets", folder, "*.png"))):
            name = os.path.basename(p)[:-4]
            if name.startswith("_"):
                continue
            upload(f"{prefix}/{name}", p, "Decal", f"SPLASH FRONT {prefix} {name}", f"SPLASH FRONT {folder[:-1]} (procedural)", "image/png")
save()
print("done:", sum(1 for k, v in ids.items() if v), "asset IDs")
