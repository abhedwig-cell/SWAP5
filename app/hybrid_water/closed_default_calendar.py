"""Select real original default-Mualem closed pressure/calendar state owners."""
from pathlib import Path
import re
POLICY='original-closed-default-pressure-nondaily-calendar-composition-v1'


def input_domain(text,selectors,original_output=True):
    if original_output is False:return None
    fixed=dict(SWINCO=1,SWMACRO=0,SWDRA=0,SWBOTB=6,SWFROST=0,SWSNOW=0,
               SWHEA=1,SWCALT=2,SWSOPHY=0,SWBBCFILE=0,SWMETDETAIL=0,SWBR=0)
    if any(selectors.get(k)!=v for k,v in fixed.items()):return None
    if selectors.get('SWSOLU') not in (0,1) or selectors.get('SWHYST') not in (0,1,2) or selectors.get('SWKIMPL') not in (0,1):return None
    # The existing qualified non-daily state classes retain their original
    # hysteresis/implicit ownership. Their simultaneous composition is separate.
    if selectors['SWKIMPL'] and selectors['SWHYST']:return None
    active='\n'.join(v.split('!',1)[0] for v in text.splitlines() if not v.lstrip().startswith('*'))
    rows=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]*)',active)
    rest=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if len(rows)>1 or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',rest):return None
    if rows and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',rows[0]) is None:return None
    def integer(key):
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]*)',active)
        if len(values)!=1 or re.fullmatch(r'[+-]?[0-9]+[ \t]*',values[0]) is None:return None
        return int(values[0])
    npd,period,monthly,dates,reset=(integer(k) for k in ['NPRINTDAY','PERIOD','SWMONTH','SWODAT','SWRES'])
    if npd is None or not 1<=npd<=1440 or period is None or not 0<=period<=366 or monthly not in (0,1) or dates not in (0,1) or reset not in (0,1):return None
    rows=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]*)',active)
    if len(rows)>1:return None
    token=rows[0].strip().upper() if rows else '.FALSE.'
    if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):return None
    perstep=token in ('.TRUE.','TRUE','.T.','T');clock=perstep or npd>1
    if monthly and dates or clock and (monthly or dates) or perstep and reset:return None
    if not clock and not monthly and not dates and period==1:return None
    return dict(policy=POLICY,hydraulic_model=1,initial=1,drainage=0,bottom=6,
                kind='cde' if selectors['SWSOLU'] else 'water',history=selectors['SWHYST'],
                implicit=selectors['SWKIMPL'],clock=clock,perstep=perstep,
                original_parameter_and_calendar_bytes_preserved=True,
                new_native_codec=False,new_physical_state=False,physical_equations_changed=False)


def selection(project):
    if not project.input_directory or not project.original_output or project.macro or project.age or project.time_step_policy!='original-adaptive-day-seed-v1':return None
    from experimental_project import switches
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    return input_domain(text,switches(text),project.original_output)


def render_trial_domain(source,project):
    """Compose only the real closed boundary with the original trial receipt."""
    selected=selection(project)
    if selected is None or not selected['clock'] or project.solute:return source
    old="if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop 'Foreign original trial receipt domain'"
    new="if(swmacro/=0.or.swsnow/=0.or.swdra/=0.or.swbotb/=6)error stop 'Foreign original closed default trial receipt domain'"
    if source.count(old)!=1:raise ValueError('Changed complete original default trial domain')
    anchor='real(8) function hybrid_output_trial_residual() result(residual)\n'
    if source.count(anchor)!=1:raise ValueError('Changed original default trial receipt function')
    return source.replace(old,new,1).replace(anchor,anchor+'use variables,only:swbotb\n',1)


def trial_head_parent_inverse(source):
    """Invert the two exact original observer statements, preserving the body."""
    parts=('   use MOD_integral,only:hybrid_output_trial_residual\n',
           '\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.')
    original=source
    for part in parts:
        if source.count(part)!=1:raise ValueError('Foreign complete default clock trial source')
        source=source.replace(part,'',1)
    anchors=('   use hybrid_implicit_pond_event_state,only:request_implicit_pond_event,assert_no_implicit_pond_event',
             '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.')
    if any(source.count(a)!=1 for a in anchors):raise ValueError('Changed original default trial assembly')
    replay=source.replace(anchors[0],parts[0]+anchors[0],1).replace(anchors[1],anchors[1]+parts[1],1)
    if replay!=original:raise ValueError('Incomplete complete default clock trial inverse')
    return source
