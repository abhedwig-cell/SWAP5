"""Bound the next existing Frost calendar/state composition; not yet dispatched."""
import hashlib,re
from pathlib import Path

POLICY='existing-frost-original-calendar-state-composition-v1'


def selection(directory,original_output=True):
    from frost_boundary_state_calendar import selection as composed_selection
    composed=composed_selection(directory,original_output)
    if composed is not None:return composed
    if not directory or original_output is False:return None
    from experimental_project import switches,one
    folder=Path(directory);text=(folder/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    selected=switches(text)
    fixed=dict(SWMACRO=0,SWFROST=1,SWSNOW=1,SWHEA=1,SWCALT=2,SWSOPHY=0,
               SWDRA=1,SWBOTB=6,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0,NPRINTDAY=1)
    if any(selected.get(k)!=v for k,v in fixed.items() if k!='NPRINTDAY'):return None
    domains={k:{v} for k,v in fixed.items()}
    domains.update(SWHYST={0,1,2},SWINCO={1,2},SWSOLU={0,1},SWKIMPL={0,1},
                   SWMONTH={0,1},SWODAT={0,1},SWRES={0,1},PERIOD=set(range(367)))
    values={}
    for key,domain in domains.items():
        matches=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(matches)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',matches[0]) is None:return None
        value=int(matches[0])
        if value not in domain:return None
        values[key]=value
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
    if values['SWMONTH']==0 and values['SWODAT']==0 and values['PERIOD']==1:return None
    if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
    name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip();drain=folder/(prefix+name+'.dra')
    if not drain.is_file() or switches(drain.read_text(encoding='cp1252')).get('SWDIVD')!=1:return None
    monthly=values['SWMONTH'];kind='cde' if values['SWSOLU'] else 'water'
    return dict(frost_calendar=True,policy=POLICY,kind=kind,hysteresis=values['SWHYST'],initial=values['SWINCO'],
                implicit=values['SWKIMPL'],swmonth=monthly,swodat=0 if monthly else values['SWODAT'],
                swres=0 if monthly else values['SWRES'],requested_period=0 if monthly else values['PERIOD'],
                physical_equations_changed=False)


def source_identity():
    return hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
