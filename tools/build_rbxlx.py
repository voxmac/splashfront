import os, sys, itertools
from xml.sax.saxutils import escape
root=sys.argv[1]; out=sys.argv[2]
ref=itertools.count(1)
def script_item(path):
    name=os.path.basename(path)
    if name.endswith('.server.lua'): cls,n='Script',name[:-11]
    elif name.endswith('.client.lua'): cls,n='LocalScript',name[:-11]
    else: cls,n='ModuleScript',name[:-4]
    src=open(path,encoding='utf-8').read()
    assert ']]>' not in src, path
    extra='<bool name="Disabled">false</bool>' if cls!='ModuleScript' else ''
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties><string name="Name">{escape(n)}</string>{extra}<ProtectedString name="Source"><![CDATA[{src}]]></ProtectedString></Properties></Item>'
def children(d):
    return ''.join(script_item(os.path.join(d,f)) for f in sorted(os.listdir(d)) if f.endswith('.lua'))
def item(cls,name,inner=''):
    return f'<Item class="{cls}" referent="RBX{next(ref)}"><Properties><string name="Name">{name}</string></Properties>{inner}</Item>'
x='<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="4">'
x+='<Item class="Workspace" referent="RBX0"><Properties><string name="Name">Workspace</string><bool name="StreamingEnabled">false</bool></Properties></Item>'
x+=item('ReplicatedStorage','ReplicatedStorage', item('Folder','Shared',children(f'{root}/src/shared')))
x+=item('ServerScriptService','ServerScriptService',children(f'{root}/src/server'))
x+=item('StarterPlayer','StarterPlayer', item('StarterPlayerScripts','StarterPlayerScripts',children(f'{root}/src/client')))
x+='</roblox>'
open(out,'w',encoding='utf-8').write(x)
print('wrote',out,len(x))
