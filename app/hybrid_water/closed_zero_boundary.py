"""Select existing default-Mualem no-drainage original zero boundary owners."""
import re

def input_domain(text,selectors,original_output=True):
    if original_output is False:return False
    fixed=dict(SWMACRO=0,SWDRA=0,SWBOTB=7,SWBR=0,SWSOPHY=0,SWFROST=0,
               SWHEA=1,SWCALT=2,SWMETDETAIL=0)
    if any(selectors.get(k)!=v for k,v in fixed.items()):return False
    if any(selectors.get(k) not in values for k,values in
           [('SWSOLU',(0,1)),('SWSNOW',(0,1)),('SWHYST',(0,1,2)),('SWKIMPL',(0,1)),('SWINCO',(1,2))]):return False
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    rest=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if len(rows)>1 or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',rest):return False
    implicit_analytical=False
    if rows and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',rows[0]) is None:
        if selectors['SWKIMPL']!=1 or selectors['SWHYST']!=0:return False
        from implicit_hydraulic_state import input_models
        if input_models(text,selectors,selectors,original_output) is None:return False
        implicit_analytical=True
    from closed_default_calendar import input_domain as default_calendar_domain
    if default_calendar_domain(text,selectors,original_output) is not None:return True
    if selectors['SWSNOW']==0 and not implicit_analytical:
        # Ordinary non-daily initialization needs its own complete output-owner
        # qualification; this predicate does not claim that remaining gap.
        dense=dict(NPRINTDAY=1,PERIOD=1,SWMONTH=0,SWODAT=0,SWRES=1)
        for key,value in dense.items():
            rows=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
            if len(rows)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',rows[0]) is None or int(rows[0])!=value:return False
        step=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(step)>1 or step and step[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):return False
    return True


def implicit_selection(project):
    """Select the actual existing per-layer closed implicit state, never an input projection."""
    from implicit_hydraulic_state import selected
    item=selected(project)
    if item is None or item.get('frost',0)!=0 or item['bottom']!=6 or item.get('drainage',1)!=0:return None
    return item
