"""Compose existing original Frost boundary, hydraulic state and calendar owners."""
import hashlib,re
from pathlib import Path

POLICY='original-frost-boundary58-hysteresis012-initial12-calendar-state-v1'
FIXED=dict(SWMACRO=0,SWFROST=1,SWSNOW=1,SWHEA=1,SWCALT=2,SWSOPHY=0,
           SWDRA=1,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0,NPRINTDAY=1,SWTOPBHEA=2)


def input_domain(selectors,boundary,original_output):
    return bool(original_output is not False and boundary.get('SWBOTB') in (5,8)
                and selectors.get('SWKIMPL') in (0,1)
                and not (selectors.get('SWKIMPL')==1 and selectors.get('SWHYST')==2)
                and selectors.get('SWSOLU') in (0,1)
                and selectors.get('SWHYST') in (0,1,2) and selectors.get('SWINCO') in (1,2)
                and all(selectors.get(key)==value for key,value in FIXED.items() if key!='NPRINTDAY'))


def selection(directory,original_output=True):
    if not directory or original_output is False:return None
    from experimental_project import switches,one
    folder=Path(directory);text=(folder/'swap.swp').read_text(encoding='cp1252');selectors=switches(text)
    if not input_domain(selectors,selectors,original_output):return None
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    domains={key:{value} for key,value in FIXED.items()}
    domains.update(SWBOTB={5,8},SWSOLU={0,1},SWKIMPL={0,1},SWHYST={0,1,2},SWINCO={1,2},
                   SWMONTH={0,1},SWODAT={0,1},SWRES={0,1},PERIOD=set(range(367)))
    values={}
    for key,domain in domains.items():
        rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None:return None
        value=int(rows[0])
        if value not in domain:return None
        values[key]=value
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
    if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    rest=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if re.search(r'(?i)\bIHWCKMODEL\b',rest) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
    name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip();drain=folder/(prefix+name+'.dra')
    if not drain.is_file() or switches(drain.read_text(encoding='cp1252')).get('SWDIVD')!=1:return None
    calendar=values['SWMONTH']!=0 or values['SWODAT']!=0 or values['PERIOD']!=1 or values['SWRES']!=1
    if not calendar and values['SWHYST']==2 and values['SWINCO']==2:return None
    monthly=values['SWMONTH']
    return dict(boundary_state_calendar=True,frost_calendar=True,dense_daily_requested=not calendar,policy=POLICY,
        bottom=values['SWBOTB'],kind='cde' if values['SWSOLU'] else 'water',implicit=values['SWKIMPL'],
        hysteresis=values['SWHYST'],initial=values['SWINCO'],swmonth=monthly,
        swodat=0 if monthly else values['SWODAT'],swres=0 if monthly else values['SWRES'],
        requested_period=0 if monthly else values['PERIOD'],physical_equations_changed=False)


def codec(selected):
    return {('water',0):b'S5BCW001',('cde',0):b'S5BCC001',
            ('water',1):b'S5BCW002',('cde',1):b'S5BCC002'}[(selected['kind'],selected['implicit'])]


def source_identity():return hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
