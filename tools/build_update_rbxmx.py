# Builds SF_Update.rbxmx: a model with the latest scripts, for updating a collaborative (Team Create) place
# whose local-file "Publish As" hangs. Insert it in Studio, then run the command printed in game/UPDATE_COMMAND.lua.
import os, sys, importlib.util
root = sys.argv[1] if len(sys.argv) > 1 else 'game'
out = sys.argv[2] if len(sys.argv) > 2 else 'game/SF_Update.rbxmx'
spec = importlib.util.spec_from_file_location('b', 'tools/build_rbxlx.py')
src = open('tools/build_rbxlx.py', encoding='utf-8').read().split("x='<roblox")[0]
ns = {'__name__': 'b'}
sys_argv = sys.argv; sys.argv = ['x', root, '/dev/null']
exec(src, ns)
sys.argv = sys_argv
item, children = ns['item'], ns['children']
x = '<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">'
x += item('Folder', 'SF_Update',
          item('Folder', 'Shared', children(f'{root}/src/shared')) +
          item('Folder', 'Server', children(f'{root}/src/server')) +
          item('Folder', 'Client', children(f'{root}/src/client')))
x += '</roblox>'
open(out, 'w', encoding='utf-8').write(x)
print('wrote', out, len(x))
