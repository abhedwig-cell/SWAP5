"""Reuse the qualified model7 trial receipt/search for original explicit families."""
import hashlib
from pathlib import Path

PARENT_SHA='dc491e5faa9c7ca8e0e1e2a573cac965cb2e7f790d1cb6ad89ab82e7b90a6540'
STATE='model7_terminal_water_receipt'
HEAD_PARENT_SHA='e8693175f3c0497d83fa9a59868250d4c0b76ca4e8a88de8d825ae5c25f6255f'
IMPORT='   use hybrid_model7_terminal_water_receipt, only: model7_terminal_water_residual\n   use variables, only: tcum\n'
ANCHOR='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
GUARD='\n         if(abs(model7_terminal_water_residual())>1d-10)flnonconv=.true.'
CLOCK_IMPORT='   use MOD_integral,only:hybrid_output_trial_residual\n'
CLOCK_GUARD='\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.'
CLOCK_PARENT_SHA='07493a79f44c3d1ca6b3a28d79198f0a1319dc5b664d4ff3465dca1dfdd23e18'
SEARCH="""   ! Numerical search diagonal already present in original default MvG.
   ! Only the fully saturated flux/closed-bottom null mode is affected.
   if(SwKimpl==0.and.swmacro==0.and.swbotb==6.and..not.ftoph.and.NN>1)then
      if(all(h(1:NN)>=0d0).and.all(dimoca(1:NN)==0d0))then
         dFdhM(1:NN)=dFdhM(1:NN)+1d-7*FrArMtrx(1:NN)*dz(1:NN)
      end if
   end if
"""


def enabled(project):
    from model7_capacity import analytical_models
    models=analytical_models(project)
    if not models or not any(model>=3 for model in models) or not project.original_output or project.time_step_policy!='original-adaptive-day-seed-v1':return False
    from experimental_project import switches
    selected=switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'))
    if all(selected.get(name)==value for name,value in dict(SWSNOW=0,SWDRA=1,SWBOTB=6,SWBR=0,SWMETDETAIL=0).items()):return True
    from vapor_boundary_composition import enabled as boundary_enabled
    return all(selected.get(name)==value for name,value in dict(SWSNOW=0,SWBR=0,SWMETDETAIL=0).items()) and boundary_enabled(project)


def source(project=None):
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
    text=text.replace(anchor,"    if(tcum+dt>=1d0-1d-8)write(*,'(a,28(1x,es25.17e3))') 'MODEL7_TERMINAL_WATER_TERMS',terms\n"+anchor,1)
    declaration='  real(8) function model7_terminal_water_residual() result(residual)\n'
    assert text.count(declaration)==1
    text=text.replace(declaration,declaration+'    use variables, only: tcum,dt\n',1)
    if project is not None:
        from vapor_boundary_composition import enabled as boundary_enabled,terminal_source
        if boundary_enabled(project):return terminal_source(text)
    return text


def clock_selection(project):
    if project.solute:
        from cde_clock_output import selection
    else:
        from original_output import selection
    selected=selection(project)
    if selected['nprintday']==1 and not selected['flprintdt']:return None
    if selected['swmonth'] or selected['swodat']:
        raise ValueError('Analytical subdaily trial composition requires ordinary daily output opportunities')
    return selected


def head_parent_inverse(text,project=None):
    if project is not None:
        from analytical_cde_calendar import clock_parent_inverse
        composed=clock_parent_inverse(text,project,HEAD_PARENT_SHA)
        if composed is not None:return composed
        from vapor_boundary_composition import enabled as boundary_enabled,head_parent_inverse as boundary_inverse
        if boundary_enabled(project):return boundary_inverse(text,project,HEAD_PARENT_SHA)
    digest=hashlib.sha256(text.encode('cp1252')).hexdigest()
    if digest==HEAD_PARENT_SHA:return False
    if digest!=CLOCK_PARENT_SHA or text.count(CLOCK_IMPORT)!=1 or text.count(CLOCK_GUARD)!=1:
        raise ValueError('Foreign complete pre-terminal model7 HeadCalc parent')
    inverse=text.replace(CLOCK_IMPORT,'',1).replace(CLOCK_GUARD,'',1)
    if hashlib.sha256(inverse.encode('cp1252')).hexdigest()!=HEAD_PARENT_SHA:
        raise ValueError('Incomplete qualified original output trial HeadCalc inverse')
    return True


def metadata(project):
    if not enabled(project):return None
    result=dict(policy='original-explicit-analytical-independent-terminal-water-trial-guard-v2',
      source_sha256=hashlib.sha256(Path(__file__).read_bytes().replace(b'\r\n',b'\n')).hexdigest(),
      parent_receipt_sha256=PARENT_SHA,complete_before_guard_HeadCalc_sha256=HEAD_PARENT_SHA,provider_sha256=hashlib.sha256(source(project).encode('cp1252')).hexdigest(),
      water_limit_cm=1e-10,trial_projection_period='every original hydraulic trial; same fixed absolute day bound',accepted_state_or_flux_modified=False,new_physical_state=False,native_interface_changed=False,
      search_operator='original default-MvG numerical diagonal, only fully saturated flux/closed-bottom null mode; physical capacity and residual unchanged',
      search_operator_sha256=hashlib.sha256(SEARCH.encode()).hexdigest(),
      inactive_snow_terms='exact zero for the explicitly absent Snow process, matching public export',
      action='Only original Newton nonconvergence/rollback when the independent terminal receipt exceeds the unchanged public bound')
    clock=clock_selection(project)
    if clock is not None:
        result.update(complete_before_guard_HeadCalc_sha256=CLOCK_PARENT_SHA,
            existing_output_trial_receipt_composed=True,
            existing_output_trial_import_sha256=hashlib.sha256(CLOCK_IMPORT.encode()).hexdigest(),
            existing_output_trial_guard_sha256=hashlib.sha256(CLOCK_GUARD.encode()).hexdigest(),
            existing_output_trial_water_limit_cm=1e-10,
            existing_output_trial_owner='original_output',existing_output_trial_unchanged=True)
    if clock is not None and clock.get('analytical_bottom6_calendar'):
        from analytical_cde_calendar import CLOCK6_PARENT_SHA,HEAD_IMPORT,head_guard
        result.update(complete_before_guard_HeadCalc_sha256=CLOCK6_PARENT_SHA,
            existing_output_trial_import_sha256=hashlib.sha256(HEAD_IMPORT.encode()).hexdigest(),
            existing_output_trial_guard_sha256=hashlib.sha256(head_guard(6).encode()).hexdigest(),
            existing_output_trial_owner='cde_clock_output')
    from vapor_boundary_composition import enabled as boundary_enabled,metadata as boundary_metadata,parent_digest
    if boundary_enabled(project):
        result.update(boundary_composition=boundary_metadata(project),complete_before_guard_HeadCalc_sha256=parent_digest(boundary_metadata(project)['bottom']))
    return result


def apply_build(output,project,patched):
    if not enabled(project):return patched
    if STATE in patched:raise ValueError('Multiple model7 terminal receipt owners')
    (output/(STATE+'.f90')).write_text(source(project),encoding='cp1252');patched.insert(0,STATE)
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252')
    if head_parent_inverse(text,project)!=(clock_selection(project) is not None):
        raise ValueError('Original output trial composition differs from actual analytical HeadCalc')
    anchor='   use hybrid_step_budget, only: projected_water_residual'
    if text.count(anchor)!=1 or text.count(ANCHOR)!=1:raise ValueError('Changed model7 complete HeadCalc terminal seam')
    from vapor_boundary_composition import terminal_guard
    text=text.replace(anchor,IMPORT+anchor,1).replace(ANCHOR,ANCHOR+terminal_guard(project,GUARD),1)
    if text.count('end subroutine jacobian_F')!=1:raise ValueError('Changed model7 search operator seam')
    text=text.replace('end subroutine jacobian_F',SEARCH+'end subroutine jacobian_F',1)
    path.write_text(text,encoding='cp1252');return patched


def validate(bundle,project,identity):
    expected=metadata(project)
    if identity.get('model7_terminal_water')!=expected:raise ValueError('Foreign model7 terminal water policy')
    if expected is None:
        if STATE+'.f90' in identity['donor_generated']:raise ValueError('Unselected model7 terminal source')
        return
    if (bundle/(STATE+'.f90')).read_text(encoding='cp1252')!=source(project):raise ValueError('Foreign complete model7 terminal receipt')
    text=(bundle/'headcalc.f90').read_text(encoding='cp1252')
    from vapor_boundary_composition import terminal_guard
    for part in (IMPORT,terminal_guard(project,GUARD),SEARCH):
        if text.count(part)!=1:raise ValueError('Foreign model7 actual terminal guard')
        text=text.replace(part,'',1)
    # The complete pre-guard HeadCalc is separately pinned in the qualification
    # observation; no original numerical statement is removed here.
    if text.count(ANCHOR)!=1 or head_parent_inverse(text,project)!=(clock_selection(project) is not None):
        raise ValueError('Foreign complete original pre-terminal model7 HeadCalc parent')
