"""Explicit file/inline fixtures retaining original fixed-irrigation quantities."""
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[2]
SPECS={'water-file-sprinkler':(0,0,None),'water-file-surface':(0,1,None),
       'water-file-subsurface':(0,2,'-30.0'),'water-file-subsurface-interval':(0,2,'-20.0 -40.0'),
       'chemical-file-sprinkler':(1,0,None),'chemical-file-surface':(1,1,None)}


def create(target,key,*,inline=False):
    solute,kind,zone=SPECS[key];shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',target)
    control=target/'swap.swp';text=control.read_text(encoding='cp1252')
    for name,value in {'SWSOLU':solute,'SWIRFIX':1,'SWIRGFIL':int(not inline)}.items():
        text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert n==1,name
    text,n=re.subn(r"(?m)^([ \t]*IRGFIL[ \t]*=[ \t]*)'[^']+'",r"\g<1>'fixed-irrigation'",text);assert n==1
    table='IRDATE IRDEPTH IRCONC IRTYPE IRRATE\n'+f'2002-01-05 24.0 20.0 {kind} 12.0\n'
    if inline:
        text,n=re.subn(r'(?m)^[ \t]*IRDATE[ \t]+IRDEPTH[^\n]*\n(?:[ \t]*\d{4}-\d{2}-\d{2}[^\n]*\n)+',table,text);assert n==1
        if zone:text+='\nIR_Z = '+zone+'\n'
    else:
        (target/'fixed-irrigation.irg').write_text(table+ ('\nIR_Z = '+zone+'\n' if zone else ''))
    control.write_text(text,encoding='cp1252')
    for crop in target.glob('*.crp'):
        body=crop.read_text(encoding='cp1252')
        values={'SCHEDULE':0}|({'SWSALINITY':0} if not solute else {})
        for name,value in values.items():
            body,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)[01]',lambda m:m[1]+str(value),body);assert n==1
        crop.write_text(body,encoding='cp1252')
    return target
