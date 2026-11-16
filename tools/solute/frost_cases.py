"""Explicit bounded original431 frost/snow/hysteresis2 fixtures."""
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[2]
KEYS=('water-frost-undrained','chemical-frost-undrained','water-frost-drained','chemical-frost-drained')


def create(target,key):
    if key not in KEYS:raise ValueError('Unknown bounded frost case')
    target=Path(target);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',target)
    changes=dict(SWMACRO=0,SWSOLU=int(key.startswith('chemical')),SWFROST=1,SWSNOW=1,SWHYST=2,SWDIVD=0,SWDRA=int(key.endswith('-drained')))
    p=target/'swap.swp';text=p.read_text(encoding='cp1252')
    for name,value in changes.items():
        text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert n==1,name
    text,n=re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",text);assert n==1
    text=re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1',r'\g<1>0',text)+'\nNUM_DECIMALS = 12\n';p.write_text(text,encoding='cp1252')
    if not changes['SWSOLU']:
        for p in target.glob('*.crp'):
            text,n=re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)[01]',r'\g<1>0',p.read_text(encoding='cp1252'));assert n==1;p.write_text(text,encoding='cp1252')
    return changes
