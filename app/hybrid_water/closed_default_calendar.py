"""Select real original default-Mualem closed pressure/groundwater calendar state owners."""
from pathlib import Path
import re
POLICY='original-closed-default-pressure-nondaily-calendar-composition-v1'
GROUNDWATER_POLICY='original-closed-default-groundwater-nondaily-calendar-composition-v1'
COUPLED_POLICY='original-closed-default-implicit-hysteresis-nondaily-calendar-composition-v1'


def input_domain(text,selectors,original_output=True):
    if original_output is False:return None
    if selectors.get('SWINCO') not in (1,2):return None
    fixed=dict(SWMACRO=0,SWDRA=0,SWBOTB=6,SWFROST=0,SWSNOW=0,
               SWHEA=1,SWCALT=2,SWSOPHY=0,SWBBCFILE=0,SWMETDETAIL=0,SWBR=0)
    if any(selectors.get(k)!=v for k,v in fixed.items()):return None
    if selectors.get('SWSOLU') not in (0,1) or selectors.get('SWHYST') not in (0,1,2) or selectors.get('SWKIMPL') not in (0,1):return None
    # Compose the existing original implicit and hysteresis state owners.
    # Dense output and every older separate-owner policy remain unchanged.
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
    return dict(policy=COUPLED_POLICY if selectors['SWKIMPL'] and selectors['SWHYST'] else POLICY if selectors['SWINCO']==1 else GROUNDWATER_POLICY,hydraulic_model=1,initial=selectors['SWINCO'],drainage=0,bottom=6,
                kind='cde' if selectors['SWSOLU'] else 'water',history=selectors['SWHYST'],
                implicit=selectors['SWKIMPL'],clock=clock,perstep=perstep,
                original_parameter_and_calendar_bytes_preserved=True,
                new_native_codec=False,new_physical_state=False,physical_equations_changed=False)


def selection(project):
    if not project.input_directory or not project.original_output or project.macro or project.age or project.time_step_policy!='original-adaptive-day-seed-v1':return None
    from experimental_project import switches
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    return input_domain(text,switches(text),project.original_output)


def render_regular_counter_validation(source,project):
    """Validate the original periodic counter; never assign a restored state."""
    selected=selection(project)
    if selected is None or not selected['implicit'] or not selected['history'] or project.solute:return source
    from original_output_hysteresis import selection as output_selection
    output=output_selection(project)
    if output['flprintdt'] or output['nprintday']!=1 or output['swmonth'] or output['swodat'] or output['period']<=0:return source
    declaration='integer::header(20),witness_header(20),ios,nreal'
    if source.count(declaration)!=1:raise ValueError('Changed complete joint calendar native declaration')
    source=source.replace(declaration,declaration+'\ninteger::joint_expected,joint_date(6)\nreal(4)::joint_seconds\nreal(8)::joint_day,joint_jan1',1)
    anchor=" if(header(12)/=swres.or.minval(header(7:11))<0)error stop 'Invalid original output calendar counters'"
    if source.count(anchor)!=1:raise ValueError('Changed complete joint calendar native counter guard')
    validation="""
 ! Read only: original TimeControl count modulo PERIOD, including its SWRES1 year reset.
 joint_expected=header(7)
 if(swres==1.and.header(7)>0)then
  joint_day=original_output_start_clock+dble(header(7))-1d0
  call dtdpar(joint_day+0.1d0,joint_date,joint_seconds)
  joint_date(2:6)=0;joint_date(2)=1;joint_date(3)=1
  call dtardp(joint_date,0.0,joint_jan1)
  joint_expected=min(header(7),nint(joint_day-joint_jan1)+1)
 end if
 if(header(8)/=mod(joint_expected,period))error stop 'Foreign original joint regular output counter'
"""
    return source.replace(anchor,anchor+validation,1)


def render_trial_domain(source,project):
    """Compose only the real closed boundary with the original trial receipt."""
    selected=selection(project)
    source=render_regular_counter_validation(source,project)
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
