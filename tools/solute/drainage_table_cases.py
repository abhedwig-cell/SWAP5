"""Derived original Hupsel DRAMET1 decks, no new historical projects."""
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[2]
KEYS=('water-drain-table','chemical-drain-table','water-drain-signed','chemical-drain-signed')


def create(target,key):
    if key not in KEYS:raise ValueError('Unknown original table drainage configuration')
    target=Path(target);shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',target)
    main=target/'swap.swp';text=main.read_text(encoding='cp1252');changes=dict(SWMACRO=0,SWSOLU=int(key.startswith('chemical')),SWDRA=1)
    for name,value in changes.items():
        text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert n==1
    text,n=re.subn(r"(?mi)^([ \t]*INLIST_CSV[ \t]*=[ \t]*)'[^']*'",r"\1'WATBAL,ETTERMS,SOLBAL,GWL,CROP,WOFOST,GRASS'",text);assert n==1
    text=re.sub(r'(?m)^([ \t]*SWMONTH[ \t]*=[ \t]*)1',r'\g<1>0',text)+'\nNUM_DECIMALS = 12\n';main.write_text(text,encoding='cp1252')
    drain=target/'swap.dra';text,n=re.subn(r'(?m)^([ \t]*DRAMET[ \t]*=[ \t]*)2',r'\g<1>1',drain.read_text(encoding='cp1252'));assert n==1
    if key.endswith('signed'):
        text,n=re.subn(r'(?m)^([ \t]*GWL[ \t]+QDRAIN[^\n]*\n)[ \t]*-20\.0[ \t]+0\.5\n[ \t]*-100\.0[ \t]+0\.1',r'\g<1>  -20.0    0.25\n -100.0   -0.25',text);assert n==1
    drain.write_text(text,encoding='cp1252')
    if not changes['SWSOLU']:
        for crop in target.glob('*.crp'):
            text,n=re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)[01]',r'\g<1>0',crop.read_text(encoding='cp1252'));assert n==1;crop.write_text(text,encoding='cp1252')
    return dict(**changes,DRAMET=1,SWDIVD=1,signed_table=key.endswith('signed'))
