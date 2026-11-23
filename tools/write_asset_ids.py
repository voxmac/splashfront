"""Writes game/src/shared/AssetIds.lua from assets/roblox_ids.json (filled by roblox_upload.py) + assets/sfx/atlas.json.
usage: python tools/write_asset_ids.py     (0 = not uploaded yet -> the game uses its built-in fallback)"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ids = {}
p = os.path.join(ROOT, "assets", "roblox_ids.json")
if os.path.exists(p):
    ids = json.load(open(p, encoding="utf-8"))
regions = json.load(open(os.path.join(ROOT, "assets", "sfx", "atlas.json"), encoding="utf-8"))
MUSIC = ["lobby", "chroma", "sky", "victory", "defeat"]
MODELS = ["Gun_Pistol", "Gun_Rifle", "Gun_SMG", "Gun_Shotgun", "Gun_Sniper", "Gun_Launcher", "Gear_Helmet", "Gear_Backpack"]

def num(key):
    return int(ids.get(key, 0) or 0)

lines = ["-- 자동 생성 파일: tools/write_asset_ids.py (tools/roblox_upload.py가 업로드 후 다시 만듦). 직접 고치지 마세요.",
         "-- 0 = 아직 업로드 안 됨 → 게임이 내장 대체음·대체 모델을 씀", "return {", "\tMusic = {"]
lines += [f"\t\t{m} = {num('music/' + m)}," for m in MUSIC]
lines += ["\t},", f"\tSfxAtlas = {num('sfx/atlas')},", "\tSfxRegions = {"]
lines += [f"\t\t{n} = {{ {a}, {b} }}," for n, (a, b) in regions.items()]
lines += ["\t},", "\tModels = {"]
lines += [f"\t\t{m} = {num('model/' + m)}," for m in MODELS]
lines += ["\t},", "}", ""]
out = os.path.join(ROOT, "game", "src", "shared", "AssetIds.lua")
os.makedirs(os.path.dirname(out), exist_ok=True)
open(out, "w", encoding="utf-8").write("\n".join(lines))
print("wrote", out, "uploaded:", sum(1 for v in ids.values() if v))
