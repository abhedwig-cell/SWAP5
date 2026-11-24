"""Bounded existing explicit Frost/state composition; qualification pending."""
import hashlib
import re
from pathlib import Path

POLICY='existing-explicit-frost-hysteresis01-initial12-dense-v1'
IMPLICIT_POLICY='existing-implicit-frost-hysteresis01-initial12-dense-v1'


def implicit_input_domain(selectors,boundary,original_output):
    fixed=dict(SWMACRO=0,SWFROST=1,SWSNOW=1,SWHEA=1,SWCALT=2,SWSOPHY=0,
               SWDRA=1,SWBR=0,SWMETDETAIL=0,SWKIMPL=1)
    return bool(original_output is not False and boundary.get('SWBOTB')==6
                and selectors.get('SWHYST') in (0,1) and selectors.get('SWINCO') in (1,2)
                and selectors.get('SWSOLU') in (0,1)
                and all(selectors.get(key)==value for key,value in fixed.items()))


def selection(directory,original_output=True):
    if not directory or original_output is False:return None
    from experimental_project import switches,one
    folder=Path(directory);text=(folder/'swap.swp').read_text(encoding='cp1252');selected=switches(text)
    fixed=dict(SWMACRO=0,SWFROST=1,SWSNOW=1,SWHEA=1,SWCALT=2,SWSOPHY=0,
               SWDRA=1,SWBOTB=6,SWBR=0,SWBBCFILE=0,SWMETDETAIL=0)
    domains={key:{value} for key,value in fixed.items()}
    domains.update(SWHYST={0,1},SWINCO={1,2},SWSOLU={0,1},SWKIMPL={0,1},NPRINTDAY={1},
                   PERIOD={1},SWMONTH={0},SWODAT={0},SWRES={1})
    if any(selected.get(key) not in values for key,values in domains.items() if key in fixed or key in ('SWHYST','SWINCO','SWSOLU')):return None
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    for key,values in domains.items():
        rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None or int(rows[0]) not in values:return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return None
    if re.search(r'(?i)\bSWAP_SOILS_DB\b',active):return None
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if re.search(r'(?i)\bIHWCKMODEL\b',remainder) or len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0]) is None:return None
    name=one(text,'DRFIL',r"'[^']+'").strip("'");prefix=one(text,'PATHDRAIN',r"'[^']*'").strip("'").strip()
    drain=folder/(prefix+name+'.dra')
    if not drain.is_file() or switches(drain.read_text(encoding='cp1252')).get('SWDIVD')!=1:return None
    return dict(policy=IMPLICIT_POLICY if selected['SWKIMPL'] else POLICY,hysteresis=selected['SWHYST'],initial=selected['SWINCO'],
                kind='cde' if selected['SWSOLU'] else 'water',implicit=selected['SWKIMPL'],
                physical_equations_changed=False,new_native_codec=False)


def metadata(project):
    selected=selection(project.input_directory,project.original_output)
    if selected is None:return None
    return dict(selected,source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest())
