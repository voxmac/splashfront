# game/SF_Bundle.json: every script's source keyed by where it goes, so Studio's command bar can pull an update with
# HttpService (see game/UPDATE_FROM_GITHUB.lua) — no file download or model import needed.
import os, json
root = 'game/src'
out = {}
for folder, dest in (('shared', 'Shared'), ('server', 'Server'), ('client', 'Client'), ('first', 'First')):
    for f in sorted(os.listdir(f'{root}/{folder}')):
        if not f.endswith('.lua'):
            continue
        if f.endswith('.server.lua'):
            cls, name = 'Script', f[:-11]
        elif f.endswith('.client.lua'):
            cls, name = 'LocalScript', f[:-11]
        else:
            cls, name = 'ModuleScript', f[:-4]
        out.setdefault(dest, []).append({'Name': name, 'Class': cls, 'Source': open(f'{root}/{folder}/{f}', encoding='utf-8').read()})
json.dump(out, open('game/SF_Bundle.json', 'w', encoding='utf-8'), ensure_ascii=False)
print('bundle', sum(len(v) for v in out.values()), os.path.getsize('game/SF_Bundle.json'))
