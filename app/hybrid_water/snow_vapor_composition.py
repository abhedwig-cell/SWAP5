"""Compose admitted vapor history with original Snow and strict trial receipts."""
import hashlib
from pathlib import Path
import re

STATE='snow_vapor_terminal_water_receipt'
IMPORT='   use hybrid_terminal_water_receipt, only: terminal_water_residual\n   use variables, only: tcum\n'
# Literal admitted Snow terminal phase: Snow(2) changes the whole day's stock
# once at flDayStart, whereas Integral(3) accumulates rates over hydraulic dt.
GUARD='\n         if(tcum+dt>=1d0-1d-8)then\n            if(abs(terminal_water_residual())>1d-10)flnonconv=.true.\n         end if'


def snow_selected(project):
    if not project.input_directory:return False
    from experimental_project import switches
    return switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')).get('SWSNOW')==1


def check_daily_output(active,selected):
    for key,value in dict(NPRINTDAY=1,SWMONTH=0,SWODAT=0,PERIOD=1).items():
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*([^\r\n]+)',active)
        if len(values)!=1 or re.fullmatch(r'[+-]?\d+[ \t]*',values[0]) is None or int(values[0])!=value:
            raise ValueError('Snow vapor requires original dense daily output: '+key)
    values=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^\r\n]+)',active)
    if len(values)>1 or values and values[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F'):
        raise ValueError('Snow vapor excludes per-step output')


def native_source(original):
    text=original.decode('cp1252').replace('\r\n','\n')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!='a181df32399d64a4052f4e8d3d11133bb7388fd890c8f0e9139594bbc29877b0':
        raise ValueError('Changed complete original vapor native3 owner')
    # The native3 owner and every payload statement are inherited literally.
    edits=[('swkimpl/=0.or.swsophy/=0.or.swsnow/=0','swkimpl/=0.or.swsophy/=0.or.swsnow/=1'),
           ('expected(1:14)=[3,','expected(1:14)=[4,')]
    for before,after in edits:
        if text.count(before)!=1:raise ValueError('Changed complete vapor native domain seam')
        text=text.replace(before,after,1)
    return text.encode('cp1252')


def metadata(project):
    if not snow_selected(project):return None
    from model7_terminal_water import PARENT_SHA,HEAD_PARENT_SHA,SEARCH
    return dict(policy='original-snow-active-vapor-state-composition-v1',
        source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
        original_snow_terminal_receipt_sha256=PARENT_SHA,complete_headcalc_parent_sha256=HEAD_PARENT_SHA,
        inherited_search_sha256=hashlib.sha256(SEARCH.encode()).hexdigest(),
        fixed_absolute_terminal_water_limit_cm=1e-10,new_physical_equation=False,
        receipt_phase='Literal qualified Snow terminal day condition tcum+dt>=1d0-1d-8; hydraulic step budget remains checked every trial',
        native_domain_version=4,original_snow_state_owner='original_output_thermal',
        trial_action='Original Newton rejection and rollback only; no physical state or flux repair')


def apply_build(output,project,patched):
    if not snow_selected(project):return patched
    from model7_terminal_water import HEAD_PARENT_SHA,SEARCH,ANCHOR,PARENT_SHA
    if STATE in patched:raise ValueError('Multiple Snow vapor terminal receipt owners')
    source=Path(__file__).with_name('terminal_water_receipt.f90').read_text(encoding='cp1252').encode('cp1252')
    if hashlib.sha256(source).hexdigest()!=PARENT_SHA:raise ValueError('Changed literal original Snow terminal receipt')
    (output/(STATE+'.f90')).write_bytes(source)
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=HEAD_PARENT_SHA:
        raise ValueError('Changed complete Snow vapor HeadCalc parent')
    anchor='   use hybrid_step_budget, only: projected_water_residual'
    if text.count(anchor)!=1 or text.count(ANCHOR)!=1 or text.count('end subroutine jacobian_F')!=1:
        raise ValueError('Changed qualified Snow vapor trial/search seam')
    text=text.replace(anchor,IMPORT+anchor,1)
    text=text.replace(ANCHOR,ANCHOR+GUARD,1)
    text=text.replace('end subroutine jacobian_F',SEARCH+'end subroutine jacobian_F',1)
    path.write_text(text,encoding='cp1252');patched.insert(0,STATE)
    return patched


def validate(bundle,project,identity):
    if not snow_selected(project):return
    from model7_terminal_water import HEAD_PARENT_SHA,SEARCH,ANCHOR,PARENT_SHA
    provider=(bundle/(STATE+'.f90')).read_text(encoding='cp1252')
    if hashlib.sha256(provider.encode('cp1252')).hexdigest()!=PARENT_SHA:
        raise ValueError('Changed complete original Snow terminal receipt')
    text=(bundle/'headcalc.f90').read_text(encoding='cp1252')
    for part in (IMPORT,GUARD,SEARCH):
        if text.count(part)!=1:raise ValueError('Changed actual Snow vapor terminal/search composition')
        text=text.replace(part,'',1)
    if text.count(ANCHOR)!=1 or hashlib.sha256(text.encode('cp1252')).hexdigest()!=HEAD_PARENT_SHA:
        raise ValueError('Changed complete inverse Snow vapor HeadCalc')
