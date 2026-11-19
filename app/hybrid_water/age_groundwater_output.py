"""Original young-water AGE with actual prescribed groundwater reaction/state."""
from pathlib import Path
import hashlib,math,re,struct
import age_perstep_output as prior
import groundwater_boundary_receipt as boundary
import groundwater_history_native as native

ROOT=prior.ROOT
ordinary=prior.ordinary
regular=prior.regular
clock=prior.clock
history=prior.history
DOMAIN=prior.DOMAIN
STATE='age_groundwater_native_state'
POLICY='original-young-age-prescribed-groundwater-state-v1'
MAGICS={False:b'S5GAO001',True:b'S5GAH001'}


def active_selection(project):
    if not getattr(project,'original_output',False) or not project.age or project.solute or project.macro or not project.input_directory:return None
    if getattr(project,'age_irrigation_source',False) or getattr(project,'age_direct_soil_source',False):return None
    from experimental_project import inspect
    report=inspect(project.input_directory,original_output=True);s=report['selectors']
    if report['boundary']['SWBOTB']!=1:return None
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('AGE groundwater requires original day-seed policy')
    expected=dict(SWMACRO=0,SWSOLU=2,SWSNOW=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWMETDETAIL=0,SWSOPHY=0)
    if any(s[k]!=v for k,v in expected.items()) or s['SWDRA'] not in (0,1):raise ValueError('Unsupported original AGE groundwater process history')
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original AGE groundwater '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if len(flags)>1 or token not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid original AGE groundwater perstep flag')
    step=token in ('.TRUE.','TRUE','.T.','T');monthly=one('SWMONTH');fmt=one('SWCSV',0);npd=one('NPRINTDAY');hys=one('SWHYST')
    requested=0 if monthly else one('PERIOD');dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES')
    if monthly not in (0,1) or fmt not in (0,1,2,3) or not 1<=npd<=1440 or hys not in (0,1,2) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366:raise ValueError('Invalid original AGE groundwater calendar')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original AGE groundwater precision')
    return dict(age_groundwater_output=True,kind='age',swsnow=0,swhea=1,swcalt=2,swfrost=0,swdra=s['SWDRA'],swhyst=hys,et=s['SWCFBS'],swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1 if step or npd>1 else requested,flprintdt=step,groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=active_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):
    selected=active_selection(project)
    return prior.magic(project) if selected is None else MAGICS[bool(selected['swhyst'])]


def domain(project):
    s=active_selection(project)
    if s is None:raise ValueError('No original AGE groundwater domain')
    return [3,project.nodes,0,2,1,s['swhyst'],0,0,1,2,s['swdra'],s['et'],1]


def state_source():
    text=Path(native.__file__).with_name('groundwater_history_native_state.f90').read_text(encoding='cp1252')
    for old,new in [('hybrid_groundwater_history_native_state','hybrid_age_groundwater_native_state'),('groundwater_history_native_checkpoint','age_groundwater_native_checkpoint'),('swsolu/=1','swsolu/=2'),('(swhyst==0.and.swsnow==0)','(swhea/=1.or.swcalt/=2)'),('swsnow<0.or.swsnow>1','swsnow/=0'),('expected=[2,n,','expected=[3,n,')]:
        assert old in text,old
        text=text.replace(old,new)
    return text


def metadata(project):
    selected=active_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    import conserved_original_age as age
    return dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),predecessor_owner_sha256=sha(Path(prior.__file__)),
        calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),original_output_epoch=project.start_clock,
        receipt_provider_sha256=sha(ROOT/'src/process'/f'{regular.PROVIDER}.f90'),reaction_provider_sha256=sha(ROOT/'src/process/mod_prescribed_groundwater_reaction.f90'),
        state_template_sha256=sha(Path(native.__file__).with_name('groundwater_history_native_state.f90')),state_generated_sha256=hashlib.sha256(state_source().encode('cp1252')).hexdigest(),
        native_domain=domain(project),native_domain_bytes=104,hydraulic_doubles='5*actual_nodes+4',hysteresis_domain_bytes=40 if selected['swhyst'] else 0,
        original_integral_sha256=regular.INTEGRAL_SHA,original_timecontrol_sha256=clock.TIME_SHA,original_watstor_sha256=clock.WATSTOR_SHA,original_hysteresis_sha256=history.HYSTERESIS_SHA,
        age_providers=age.metadata(),physical_equations_changed=False,trial_water_guard_cm=1e-10,trial_receipt_policy='literal-original-integral-clone-actual-groundwater-reaction-and-storage-v1',
        preserves_requested_groups_and_precision=True,original_flprintdt_date_gated=True,undefined_allocation_tails_serialized=False,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None)


def source_age_identity(original,project):
    if active_selection(project) is None:return prior.source_age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def selected_boundary(project):return 1 if active_selection(project) is not None else boundary.selected_boundary(project)


def boundary_metadata(project,sha,app,root):
    if active_selection(project) is None:return boundary.metadata(project,sha,app,root)
    return dict(policy=boundary.POLICY,source_sha256=sha(app/'groundwater_boundary_receipt.py'),composition_sha256=sha(Path(__file__)),predecessor_sha256=sha(app/'lower_boundary_receipt.py'),template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=1,production_sha256=sha(root/'src/process/mod_prescribed_groundwater_reaction.f90'),state='read-only actual Darcy interface and prescribed saturated tail; no new physical store')


render_budget=boundary.render_budget
render_headcalc=boundary.render_headcalc
render_readswap=boundary.render_readswap


def native_metadata(project,sha,app):
    if active_selection(project) is None:return native.metadata(project,sha,app)
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),provider_sha256=hashlib.sha256(state_source().encode('cp1252')).hexdigest(),provider_filename=STATE+'.f90',magic=magic(project).decode(),domain_bytes=104,actual_domain=domain(project),hydraulic_doubles='5*actual_nodes+4',placement='after actual AGE physical/hysteresis state before complete calendar and private AGE tail')


def native_apply_build(output,project,patched):return patched if active_selection(project) is not None else native.apply_build(output,project,patched)


def native_enabled(project):return active_selection(project) is not None or native.enabled(project)


def native_magic(project):return magic(project) if active_selection(project) is not None else native.magic(project)


def validate_candidate(raw,receipt,project):
    if active_selection(project) is None:return native.validate_candidate(raw,receipt,project)
    n=project.nodes;header=struct.pack('<13i',*domain(project))
    if raw[:8]!=magic(project) or raw.count(header+header)!=1:raise ValueError('Foreign original AGE groundwater native domain')
    offset=raw.index(header+header)+104
    if len(raw)<offset+8*(5*n+4):raise ValueError('Incomplete original AGE groundwater hydraulic state')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)) or any(v<0 for v in values[n:5*n+2]) or values[-1]<0:raise ValueError('Invalid original AGE groundwater hydraulic state')
    if list(values[:n])!=receipt.get('pressure_head_cm') or values[-2]!=receipt.get('groundwater_cm') or values[-1]!=receipt.get('stock_end_cm',[None])[0]:raise ValueError('Actual AGE groundwater hydraulic state differs from receipt')


def trial_source(original,watstor):
    source=clock.trial_receipt_source(original,watstor)
    replacements={
      'function hybrid_output_trial_residual()':'function hybrid_groundwater_age_trial(candidate_bottom_cm_d,candidate_matrix_delta_cm)',
      'implicit none\n':'use variables,only:swbotb,thetm1\nimplicit none\nreal(8),intent(in)::candidate_bottom_cm_d,candidate_matrix_delta_cm\n',
      "if(swmacro/=0.or.swsnow/=0.or.swdra/=1)error stop 'Foreign original trial receipt domain'":"if(swmacro/=0.or.swsnow/=0.or.swbotb/=1.or.swdra<0.or.swdra>1)error stop 'Foreign original AGE groundwater trial domain'",
      'qbotts=qbot*dt':'qbotts=candidate_bottom_cm_d*dt',
      'projected_soil=sum(theta(1:numnod)*dz(1:numnod))':'projected_soil=sum(thetm1(1:numnod)*dz(1:numnod))+0d0'}
    for old,new in replacements.items():
        assert source.count(old)==1,old
        source=source.replace(old,new,1)
    return source


def render_integral(original,watstor,selected):
    source=prior.render_integral(original,watstor,selected) if selected['flprintdt'] else ordinary.render_integral(original,watstor if selected['nprintday']>1 else None,selected)
    anchor='end module MOD_integral';assert source.count(anchor)==1
    return source.replace(anchor,trial_source(original,watstor)+'\n'+anchor,1)


def render_macro(original,project,selected):
    source=regular.render_macro(original);assert source.count("'S5AGE003'")==2
    source=source.replace("'S5AGE003'","'"+magic(project).decode()+"'")
    anchor='      use MOD_integral,only:hybrid_output_calendar_checkpoint';assert source.count(anchor)==1
    imports='\n      use hybrid_age_groundwater_native_state,only:age_groundwater_native_checkpoint'
    if selected['swhyst']:imports+='\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint'
    source=source.replace(anchor,anchor+imports,1)
    for restoring in ('.true.','.false.'):
        anchor=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})';assert source.count(anchor)==1
        calls=(f'        call hybrid_output_hysteresis_checkpoint(unit,{restoring})\n' if selected['swhyst'] else '')+f'        call age_groundwater_native_checkpoint(unit,{restoring})\n'
        source=source.replace(anchor,calls+anchor,1)
    return source


def apply_build(output,donor_build,project,patched):
    selected=active_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    (output/(STATE+'.f90')).write_text(state_source(),encoding='cp1252')
    if selected['swhyst']:(output/(DOMAIN+'.f90')).write_bytes(Path(history.__file__).with_name(DOMAIN+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(ordinary.PROBE[:ordinary.PROBE.index('subroutine hybrid_age_output_day_emit()')]+regular.PROBE,encoding='cp1252')
    path=output/'solute.f90';path.write_bytes(prior.render_solute(path.read_bytes()))
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'));anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1;path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project,selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    extra=[]
    if selected['flprintdt'] or selected['nprintday']>1:
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original AGE groundwater clock owners')
        (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_integral,only:hybrid_groundwater_age_trial\n'+anchor,1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+"\n         if(abs(hybrid_groundwater_age_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.",1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1;ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',STATE,*([DOMAIN] if selected['swhyst'] else []),*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
