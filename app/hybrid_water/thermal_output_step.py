"""Original Snow FLPRINTDT output with literal prior process and native owners."""
from pathlib import Path
import hashlib
import re
import thermal_output_clock as prior

ROOT=prior.ROOT
regular=prior.regular
ordinary=prior.ordinary
thermal=prior.thermal
clock=thermal.clock
DOMAIN=prior.DOMAIN
SNOW_PROVIDER=prior.SNOW_PROVIDER
SNOW_FIELDS=prior.prior.SNOW_FIELDS
POLICY='original-water-snow-flprintdt-clock-v1'
MAGIC=b'S5SPW001'


def clock_selection(project):
    if (not getattr(project,'original_output',False) or project.macro or not project.input_directory
            or project.solute or project.age):return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original Snow FLPRINTDT '+key)
        return values[0][1:-1] if quoted else int(values[0])
    if one('SWSNOW')!=1:return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if not flags:return None
    if len(flags)!=1 or flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):
        raise ValueError('Invalid original Snow FLPRINTDT flag')
    if flags[0].strip().upper() in ('.FALSE.','FALSE','.F.','F'):return None
    if one('NPRINTDAY')!=1:raise ValueError('Original Snow FLPRINTDT currently requires NPRINTDAY1')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Original Snow FLPRINTDT requires original day-seed policy')
    for key,value in dict(SWMACRO=0,SWSOLU=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:raise ValueError('Original Snow FLPRINTDT currently excludes '+key)
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):raise ValueError('Original Snow FLPRINTDT requires lower boundary5/8')
    fmt=one('SWCSV',0);hys=one('SWHYST');monthly=one('SWMONTH');dates=0 if monthly else one('SWODAT')
    requested=0 if monthly else one('PERIOD');reset=0 if monthly else one('SWRES')
    if fmt not in (0,1,2,3) or hys not in (0,1,2) or monthly not in (0,1) or dates not in (0,1) or not 0<=requested<=366:
        raise ValueError('Invalid original Snow FLPRINTDT output selectors')
    if reset!=0:raise ValueError('Original Snow FLPRINTDT currently requires cumulative SWRES0')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original Snow FLPRINTDT precision')
    return dict(thermal_output=True,thermal_calendar=True,thermal_clock=True,thermal_step=True,kind='water',swsnow=1,swhea=1,swcalt=2,swfrost=0,swdra=1,
        swhyst=hys,swcsv=fmt,nprintday=1,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1,flprintdt=True,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=clock_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):return prior.magic(project) if clock_selection(project) is None else MAGIC


def metadata(project):
    selected=clock_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=MAGIC.decode(),**selected,source_sha256=sha(Path(__file__)),
        predecessor_owner_sha256=sha(Path(prior.__file__)),ordinary_owner_sha256=sha(Path(ordinary.__file__)),
        domain_source_sha256=sha(Path(__file__).with_name(DOMAIN+'.f90')),
        snow_output_source_sha256=sha(Path(__file__).with_name(SNOW_PROVIDER+'.f90')),
        snow_output_fields=list(SNOW_FIELDS),snow_output_domain_bytes=32,snow_output_value_bytes=56,
        calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),
        receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
        original_integral_sha256=regular.INTEGRAL_SHA,original_watstor_sha256=clock.WATSTOR_SHA,original_timecontrol_sha256=clock.TIME_SHA,
        original_output_epoch=project.start_clock,original_hysteresis_sha256=thermal.HYSTERESIS_SHA,cde_output_state_sha256=None,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,conserved_cde_prefix_offset_bytes=None,
        original_flprintdt_date_gated=True,original_pending_dates_not_normalized=True,
        snow_stock='actual MOD_snow ssnow',snow_increment_slots=[2,3,13],physical_equations_changed=False,native_domain_bytes=80,
        soil_trial_control_volume='actual soil and pond with original net soil forcing; separate unchanged whole-day Snow/canopy ledger',
        soil_trial_bottom='actual qualified original Darcy/soil-air constraint; never reconstructed candidate qbot',soil_trial_guard_cm=1e-10)


def age_identity(original,project):
    if clock_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=MAGIC.decode(),original_output=metadata(project));return result


def state_source(project):return prior.state_source(project)


def soil_trial_source(original,watstor):
    source=prior.soil_trial_source(original,watstor)
    anchor='use variables,only:swbotb,nprintday';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+',flprintdt',1)
    anchor='swdra/=1.or.nprintday<2.or.';assert source.count(anchor)==1
    return source.replace(anchor,'swdra/=1.or.(nprintday/=1.or..not.flprintdt).or.',1)


def render_integral(original,watstor,selected):
    source=prior.render_integral(original,watstor,selected)
    old=prior.soil_trial_source(original,watstor);assert source.count(old)==1
    return source.replace(old,soil_trial_source(original,watstor),1)


def probe_source(project):return prior.probe_source(project)


def render_macro(source):
    source=prior.render_macro(source);assert source.count("'S5STW001'")==2
    return source.replace("'S5STW001'","'"+MAGIC.decode()+"'")


def render_timecontrol(source):
    text=prior.render_timecontrol(source)
    anchor='if(flprintshort.and..not.flprintdt.and.';assert text.count(anchor)==3
    return text.replace(anchor,'if(flprintshort.and.flprintdt.and.')


def apply_build(output,donor_build,project,patched):
    selected=clock_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=thermal.HYSTERESIS_SHA:
        raise ValueError('Changed original hysteresis provider source')
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(state_source(project),encoding='cp1252')
    for name in (DOMAIN,SNOW_PROVIDER):(output/(name+'.f90')).write_bytes(Path(__file__).with_name(name+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(probe_source(project),encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1;text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()\n   call snow_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original Snow output clock owners')
    (output/'timecontrol.f90').write_text(render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_integral,only:hybrid_snow_soil_trial_residual\n'+anchor,1)
    anchor='\n   implicit none\n';assert text.count(anchor)==1;text=text.replace(anchor,anchor+'   real(8)::hybrid_snow_trial_guard\n',1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    guard="""
         if(swbotb==8.and..not.flboth)then
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(0d0)
         else
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(-kmean(NN+1)*hgrad(NN+1))
         end if
         if(abs(hybrid_snow_trial_guard)>1d-10)flnonconv=.true."""
    path.write_text(text.replace(anchor,anchor+guard,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1
            ordinary.binary_patch().source(original);text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):
            assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',DOMAIN,'integral',SNOW_PROVIDER,'timecontrol',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
