"""Explicit original Hupsel-derived surface input fixtures; no physical defaults."""
from datetime import date,timedelta
from pathlib import Path
import re,shutil
ROOT=Path(__file__).resolve().parents[2]
PULSES_MM={3:8.0,200:12.0,365:6.0,530:10.0,730:4.0}


def create(target,key):
    mode,kind=key.split('-',1)
    if mode not in ('water','chemical') or kind not in ('pond-table','runon-file','surface-combined'):raise ValueError('Unknown original surface input case')
    shutil.copytree(ROOT/'reference/swap-4.3.1/projects/1.hupselbrook',target)
    changes={'SWSOLU':int(mode=='chemical'),'SWPONDMX':int(kind!='runon-file'),'SWRUNON':int(kind!='pond-table')}
    control=target/'swap.swp';text=control.read_text(encoding='cp1252')
    for name,value in changes.items():
        text,n=re.subn(r'(?m)^([ \t]*'+name+r'[ \t]*=[ \t]*)\d+',lambda m:m[1]+str(value),text);assert n==1,name
    if changes['SWPONDMX']:
        text,n=re.subn(r'(?m)^([ \t]*DATEPMX PONDMXTB[^\n]*\n)(?:[ \t]*\d{4}-\d{2}-\d{2}[^\n]*\n)+',
            r'\g<1>  2002-01-01 0.2\n  2002-07-19 0.1\n  2002-07-20 0.8\n  2002-12-31 0.2\n',text);assert n==1
    if changes['SWRUNON']:
        text+="\nRUFIL = 'surface'\n"
        start=date(2002,1,1)
        (target/'surface.ru').write_text('DATE AMOUNT\n'+''.join(f'{start+timedelta(days=day)} {PULSES_MM.get(day,0.0):.1f}\n' for day in range(1097)))
    control.write_text(text,encoding='cp1252')
    if not changes['SWSOLU']:
        for crop in target.glob('*.crp'):
            body,n=re.subn(r'(?m)^([ \t]*SWSALINITY[ \t]*=[ \t]*)[01]',r'\g<1>0',crop.read_text(encoding='cp1252'));assert n==1
            crop.write_text(body,encoding='cp1252')
    return target
