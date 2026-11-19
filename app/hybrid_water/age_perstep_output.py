"""Original young-water AGE FLPRINTDT state with literal transport providers."""
from pathlib import Path
import hashlib,re
import cde_clock_output as prior
import perstep_output_domain as water
import original_output_hysteresis as history

ROOT=prior.ROOT
ordinary=history.ordinary
regular=ordinary.regular
clock=ordinary.clock
DOMAIN=history.DOMAIN
POLICY='original-age-perstep-calendar-and-native-state-v1'
MAGICS={False:b'S5APA001',True:b'S5APH001'}


def active_selection(project):
    if not getattr(project,'original_output',False) or project.macro or not project.input_directory or not project.age or project.solute:return None
    if getattr(project,'age_irrigation_source',False) or getattr(project,'age_direct_soil_source',False):return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original AGE perstep '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if not flags:return None
    if len(flags)!=1 or flags[0].strip().upper() not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid original AGE perstep flag')
    if flags[0].strip().upper() in ('.FALSE.','FALSE','.F.','F'):return None
    if project.time_step_policy!='original-adaptive-day-seed-v1':return None
    for key,value in dict(SWMACRO=0,SWSOLU=2,SWSNOW=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:return None
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):return None
    npd=one('NPRINTDAY');monthly=one('SWMONTH');fmt=one('SWCSV',0);hys=one('SWHYST')
    dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES');requested=0 if monthly else one('PERIOD')
    if not 1<=npd<=1440 or monthly not in (0,1) or fmt not in (0,1,2,3) or hys not in (0,1,2) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366:raise ValueError('Invalid original AGE perstep selector domain')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original AGE perstep precision')
    return dict(age_perstep_output=True,kind='age',swsnow=0,swhea=1,swcalt=2,swfrost=0,swdra=1,swhyst=hys,swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1,flprintdt=True,groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=active_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):
    selected=active_selection(project)
    return prior.magic(project) if selected is None else MAGICS[bool(selected['swhyst'])]


def metadata(project):
    selected=active_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    import conserved_original_age as age
    return dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),predecessor_owner_sha256=sha(Path(prior.__file__)),
        perstep_owner_sha256=sha(Path(water.__file__)),ordinary_owner_sha256=sha(Path(ordinary.__file__)),calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),
        domain_source_sha256=sha(Path(__file__).with_name(DOMAIN+'.f90')) if selected['swhyst'] else None,native_domain_bytes=40 if selected['swhyst'] else 0,
        original_integral_sha256=regular.INTEGRAL_SHA,original_timecontrol_sha256=clock.TIME_SHA,original_watstor_sha256=clock.WATSTOR_SHA,original_hysteresis_sha256=history.HYSTERESIS_SHA,
        receipt_provider_sha256=sha(ROOT/'src/process'/f'{regular.PROVIDER}.f90'),age_providers=age.metadata(),original_output_epoch=project.start_clock,
        annual_counter_policy='original-global-or-completed-year-count-v1',calendar_initial_past_date_policy='original-initial-pending-one-and-perstep-nonfuture-pointer-v1',
        original_flprintdt_date_gated=True,original_pending_dates_not_normalized=True,trial_receipt_policy='literal-original-independent-darcy-perstep-family-v1',trial_water_guard_cm=1e-10,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,physical_equations_changed=False,young_water_source=True,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None)


def age_identity(original,project):
    if active_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def render_integral(original,watstor,selected):
    source=water.render_integral(original,watstor,selected)
    anchor="if(ioutdatint>1+count(outdatint>0d0.and.outdatint<t1900-1d-8))error stop 'Future original per-step date pointer'"
    assert source.count(anchor)==1
    return source.replace(anchor,"""! Preserve the actual original pending initial date before immutable TSTART.
if(outdatint(1)>0d0.and.outdatint(1)<original_output_start_clock-1d-8)then
 if(ioutdatint/=1)error stop 'Inconsistent original AGE pending initial interval pointer'
else
 """+anchor+'\nend if',1)


def render_macro(original,project,selected):
    source=regular.render_macro(original)
    assert source.count("'S5AGE003'")==2
    source=source.replace("'S5AGE003'","'"+magic(project).decode()+"'")
    if selected['swhyst']:
        anchor='      use MOD_integral,only:hybrid_output_calendar_checkpoint';assert source.count(anchor)==1
        source=source.replace(anchor,anchor+'\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint',1)
        for restoring in ('.true.','.false.'):
            anchor=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})';assert source.count(anchor)==1
            source=source.replace(anchor,f'        call hybrid_output_hysteresis_checkpoint(unit,{restoring})\n'+anchor,1)
    return source


def apply_build(output,donor_build,project,patched):
    selected=active_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    assert sha(donor_build/'swap-selected/hysteresis.f90')==history.HYSTERESIS_SHA
    assert sha(donor_build/'swap-selected/watstor.f90')==clock.WATSTOR_SHA
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    if selected['swhyst']:(output/(DOMAIN+'.f90')).write_bytes(Path(__file__).with_name(DOMAIN+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(ordinary.PROBE[:ordinary.PROBE.index('subroutine hybrid_age_output_day_emit()')]+regular.PROBE,encoding='cp1252')
    path=output/'solute.f90';path.write_bytes(regular.render_solute(path.read_bytes()))
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'));anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1;path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project,selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original AGE perstep clock owners')
    (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_integral,only:hybrid_ordinary_trial_residual\n'+anchor,1)
    anchor='\n   implicit none\n';assert text.count(anchor)==1;text=text.replace(anchor,anchor+'   real(8)::hybrid_age_trial_guard,hybrid_age_candidate_bottom\n',1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    guard="""
         if(swbotb==8.and..not.flboth)then
            hybrid_age_candidate_bottom=0d0
         else
            hybrid_age_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)
         end if
         hybrid_age_trial_guard=hybrid_ordinary_trial_residual(hybrid_age_candidate_bottom)
         if(abs(hybrid_age_trial_guard)>1d-10)flnonconv=.true."""
    path.write_text(text.replace(anchor,anchor+guard,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1;ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    extra=[regular.PROVIDER,'hybrid_age_output_state']+([DOMAIN] if selected['swhyst'] else [])+['timecontrol','integral']
    patched=[*extra,*patched];patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
