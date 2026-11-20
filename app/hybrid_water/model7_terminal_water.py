"""Compose the existing read-only terminal receipt with explicit no-Snow model7."""
import hashlib
from pathlib import Path

PARENT_SHA='dc491e5faa9c7ca8e0e1e2a573cac965cb2e7f790d1cb6ad89ab82e7b90a6540'
STATE='model7_terminal_water_receipt'
HEAD_PARENT_SHA='e8693175f3c0497d83fa9a59868250d4c0b76ca4e8a88de8d825ae5c25f6255f'
IMPORT='   use hybrid_model7_terminal_water_receipt, only: model7_terminal_water_residual\n   use variables, only: tcum\n'
ANCHOR='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
GUARD='\n         if(tcum+dt>=1d0-1d-8)then\n            if(abs(model7_terminal_water_residual())>1d-10)flnonconv=.true.\n         end if'


def enabled(project):
    from model7_capacity import enabled as capacity
    if not capacity(project) or not project.original_output or project.time_step_policy!='original-adaptive-day-seed-v1':return False
    from experimental_project import switches
    selected=switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'))
    return all(selected.get(name)==value for name,value in dict(SWSNOW=0,SWDRA=1,SWBOTB=6,SWBR=0,SWMETDETAIL=0).items())


def source():
    text=Path(__file__).with_name('terminal_water_receipt.f90').read_text(encoding='cp1252')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=PARENT_SHA:raise ValueError('Qualified terminal receipt source changed')
    edits=[('hybrid_terminal_water_receipt','hybrid_model7_terminal_water_receipt'),
      ('terminal_water_terms','model7_terminal_water_terms'),('terminal_water_residual','model7_terminal_water_residual'),
      ('only: swmacro, swsnow, swdra','only: swmacro, swsnow, swdra, swfrost, swhyst'),
      ('ivolbeg,ipondbeg,issnowbeg,isicbeg','ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl'),
      ('swmacro/=0.or.swsnow/=1.or.swdra/=1','swmacro/=0.or.swsnow/=0.or.swdra/=1.or.swfrost/=0.or.swhyst/=0.or.swkimpl/=0'),
      ('[igrai+graidt*dt,isnrai+snrai*dt,igsnow+gsnow*dt, &','[igrai+graidt*dt,0d0,0d0, &'),
      ('ievap+reva*dt,isubl+subl*dt,iqdra+qdrtot*dt','ievap+reva*dt,0d0,iqdra+qdrtot*dt'),
      ('[ivolbeg,ipondbeg,issnowbeg,isicbeg,0d0,0d0]','[ivolbeg,ipondbeg,0d0,isicbeg,0d0,0d0]'),
      (')),pond,ssnow,canopy,0d0,0d0]', ')),pond,0d0,canopy,0d0,0d0]')]
    # Initial-store import and vector share a prefix: constrain the import edit
    # separately to its actual full line, preserving the complete body inverse.
    edits[4]=('      ivolbeg,ipondbeg,issnowbeg,isicbeg\n','      ivolbeg,ipondbeg,issnowbeg,isicbeg,swkimpl\n')
    for before,after in edits:
        if before not in text:raise ValueError('Qualified terminal receipt seam changed: '+before)
        text=text.replace(before,after)
    anchor='    residual=real(sum(real(terms,real128)),8)'
    assert text.count(anchor)==1
    text=text.replace(anchor,"    write(*,'(a,28(1x,es25.17e3))') 'MODEL7_TERMINAL_WATER_TERMS',terms\n"+anchor,1)
    return text


def metadata(project):
    if not enabled(project):return None
    return dict(policy='original-explicit-model7-independent-terminal-water-trial-guard-v1',
      source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
      parent_receipt_sha256=PARENT_SHA,complete_before_guard_HeadCalc_sha256=HEAD_PARENT_SHA,provider_sha256=hashlib.sha256(source().encode('cp1252')).hexdigest(),
      water_limit_cm=1e-10,accepted_state_or_flux_modified=False,new_physical_state=False,native_interface_changed=False,
      inactive_snow_terms='exact zero for the explicitly absent Snow process, matching public export',
      action='Only original Newton nonconvergence/rollback when the independent terminal receipt exceeds the unchanged public bound')


def apply_build(output,project,patched):
    if not enabled(project):return patched
    if STATE in patched:raise ValueError('Multiple model7 terminal receipt owners')
    (output/(STATE+'.f90')).write_text(source(),encoding='cp1252');patched.insert(0,STATE)
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
    if hashlib.sha256(text.encode('cp1252')).hexdigest()!=HEAD_PARENT_SHA:
        raise ValueError('Foreign complete pre-terminal model7 HeadCalc parent')
    anchor='   use hybrid_step_budget, only: projected_water_residual'
    if text.count(anchor)!=1 or text.count(ANCHOR)!=1:raise ValueError('Changed model7 complete HeadCalc terminal seam')
    text=text.replace(anchor,IMPORT+anchor,1).replace(ANCHOR,ANCHOR+GUARD,1)
    path.write_text(text,encoding='cp1252');return patched


def validate(bundle,project,identity):
    expected=metadata(project)
    if identity.get('model7_terminal_water')!=expected:raise ValueError('Foreign model7 terminal water policy')
    if expected is None:
        if STATE+'.f90' in identity['donor_generated']:raise ValueError('Unselected model7 terminal source')
        return
    if (bundle/(STATE+'.f90')).read_text(encoding='cp1252')!=source():raise ValueError('Foreign complete model7 terminal receipt')
    text=(bundle/'headcalc.f90').read_text(encoding='cp1252')
    for part in (IMPORT,GUARD):
        if text.count(part)!=1:raise ValueError('Foreign model7 actual terminal guard')
        text=text.replace(part,'',1)
    # The complete pre-guard HeadCalc is separately pinned in the qualification
    # observation; no original numerical statement is removed here.
    if text.count(ANCHOR)!=1 or hashlib.sha256(text.encode('cp1252')).hexdigest()!=HEAD_PARENT_SHA:
        raise ValueError('Foreign complete original pre-terminal model7 HeadCalc parent')
