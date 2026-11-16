"""Explicit bounded original431 frost/snow/hysteresis2 fixtures."""
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[2]
KEYS=('water-frost-free','chemical-frost-free','water-frost-drained')
REFUSED='chemical-frost-drained'


def create(target,key):
    if key not in (*KEYS,REFUSED):raise ValueError('Unknown bounded frost case')
    target=Path(target);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',target)
    changes=dict(SWMACRO=0,SWSOLU=int(key.startswith('chemical')),SWFROST=1,SWSNOW=1,SWHYST=2,SWDRA=int(key.endswith('-drained')),
                 SWBOTB=6 if key.endswith('-drained') else 7,SWTOPBHEA=2)
    p=target/'swap.swp';text=p.read_text(encoding='cp1252')
    for name,value in changes.items():
        text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert n==1,name
    text,n=re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",text);assert n==1
    text=re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1',r'\g<1>0',text)+'\nNUM_DECIMALS = 12\n';p.write_text(text,encoding='cp1252')
    if changes['SWDRA']:
        p=target/'swap.dra';text,n=re.subn(r'(?m)^([ \t]*SWDIVD[ \t]*=[ \t]*)1',r'\g<1>0',p.read_text(encoding='cp1252'));assert n==1;p.write_text(text,encoding='cp1252')
    for p in target.glob('*.crp'):
        text,n=re.subn(r'(?m)^([ \t]*SWDROUGHT[ \t]*=[ \t]*)[123]',r'\g<1>1',p.read_text(encoding='cp1252'));assert n==1;p.write_text(text,encoding='cp1252')
        if not changes['SWSOLU']:
            text,n=re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)[01]',r'\g<1>0',p.read_text(encoding='cp1252'));assert n==1;p.write_text(text,encoding='cp1252')
    # Original prescribed surface-temperature input: explicit derived winter
    # and crop-season partial-freeze/thaw pulses, not altered weather or limits.
    lines=['DATET TTOP','2002-01-01 5.0']
    for year in (2002,2003,2004):
        lines += [f'{year}-01-10 5.0',f'{year}-01-11 -0.5',f'{year}-02-09 -0.5',f'{year}-02-10 5.0',
                  f'{year}-06-19 5.0',f'{year}-06-20 -0.5',f'{year}-07-03 -0.5',f'{year}-07-04 20.0',f'{year}-12-01 5.0']
    lines += ['2004-12-31 5.0'];(target/'swap.tss').write_text('\n'.join(lines)+'\n')
    changes['future_crop_SWDROUGHT']=1
    return changes
