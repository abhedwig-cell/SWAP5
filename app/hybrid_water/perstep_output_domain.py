"""Original ordinary/Snow per-step print-count domain; literal physical owners."""
from pathlib import Path
import hashlib,re
import ordinary_output_reset as prior
import thermal_output_step as snow
import thermal_output_reset as snow_reset
import original_output_hysteresis as history

ROOT=prior.ROOT
ordinary=prior.ordinary
regular=prior.regular
clock=prior.clock
DOMAIN=history.DOMAIN
SNOW_DOMAIN=snow.DOMAIN
SNOW_PROVIDER=snow.SNOW_PROVIDER
SNOW_FIELDS=snow.SNOW_FIELDS
POLICY='original-water-perstep-clock-domain-v1'
MAGICS={'ordinary':b'S5OPW001','history':b'S5OPH001','snow':b'S5SPN001'}
ANNUAL_VALIDATION=prior.ANNUAL_VALIDATION.replace('swres/=1','(swres/=0.and.swres/=1)').replace(
 'annual_expected=min(header(7),nint(annual_day-annual_jan1)+1)',
 'annual_expected=header(7)\n  if(swres==1)annual_expected=min(header(7),nint(annual_day-annual_jan1)+1)').replace('original ordinary annual-reset','original per-step clock-domain')


def active_selection(project):
    if not getattr(project,'original_output',False) or project.macro or not project.input_directory or project.solute or project.age:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original per-step domain '+key)
        return values[0][1:-1] if quoted else int(values[0])
    swsnow=one('SWSNOW')
    if swsnow not in (0,1):return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if not flags:return None
    if len(flags)!=1 or flags[0].strip().upper() not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid original per-step flag')
    if flags[0].strip().upper() in ('.FALSE.','FALSE','.F.','F'):return None
    nprint=one('NPRINTDAY');monthly=one('SWMONTH');reset=0 if monthly else one('SWRES')
    if not 1<=nprint<=1440 or monthly not in (0,1) or reset not in (0,1):raise ValueError('Invalid original per-step count/reset domain')
    if nprint==1 and (swsnow or reset==1):return None
    if project.time_step_policy!='original-adaptive-day-seed-v1':return None
    for key,value in dict(SWMACRO=0,SWSOLU=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:return None
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):return None
    fmt=one('SWCSV',0);hys=one('SWHYST');dates=0 if monthly else one('SWODAT');requested=0 if monthly else one('PERIOD')
    if hys not in (0,1,2):return None
    if fmt not in (0,1,2,3) or dates not in (0,1) or not 0<=requested<=366:raise ValueError('Invalid original per-step output selectors')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original per-step precision')
    return dict(perstep_domain=True,kind='water',swsnow=swsnow,swhea=1,swcalt=2,swfrost=0,swdra=1,swhyst=hys,swcsv=fmt,
        nprintday=nprint,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1,flprintdt=True,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=active_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):
    selected=active_selection(project)
    return prior.magic(project) if selected is None else MAGICS['snow' if selected['swsnow'] else 'history' if selected['swhyst'] else 'ordinary']


def metadata(project):
    selected=active_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    is_snow=selected['swsnow']==1;domain=SNOW_DOMAIN if is_snow else DOMAIN if selected['swhyst'] else None
    result=dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),
        predecessor_owner_sha256=sha(Path(prior.__file__)),snow_owner_sha256=sha(Path(snow.__file__)),snow_reset_owner_sha256=sha(Path(snow_reset.__file__)),
        ordinary_owner_sha256=sha(Path(ordinary.__file__)),history_owner_sha256=sha(Path(history.__file__)),
        domain_source_sha256=sha(Path(__file__).with_name(domain+'.f90')) if domain else None,native_domain_bytes=80 if is_snow else 40 if domain else 0,
        calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
        original_integral_sha256=regular.INTEGRAL_SHA,original_watstor_sha256=clock.WATSTOR_SHA,original_timecontrol_sha256=clock.TIME_SHA,
        original_output_epoch=project.start_clock,original_hysteresis_sha256=history.HYSTERESIS_SHA,cde_output_state_sha256=None,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,
        original_flprintdt_date_gated=True,original_pending_dates_not_normalized=True,annual_counter_policy='original-global-or-completed-year-count-v1',
        trial_receipt_policy='literal-original-independent-darcy-perstep-family-v1',trial_water_guard_cm=1e-10,
        trial_bottom='actual original Darcy/soil-air constraint before Fluxes; never candidate-volume closure',
        legacy_trial_comparison_diagnostic=not is_snow,physical_equations_changed=False,
        thermal_output=is_snow,thermal_calendar=is_snow,thermal_clock=is_snow,thermal_step=is_snow)
    if is_snow:result.update(snow_output_source_sha256=sha(Path(__file__).with_name(SNOW_PROVIDER+'.f90')),snow_output_fields=list(SNOW_FIELDS),snow_output_domain_bytes=32,snow_output_value_bytes=56,
        snow_stock='actual MOD_snow ssnow',snow_increment_slots=[2,3,13],soil_trial_guard_cm=1e-10)
    return result


def age_identity(original,project):
    if active_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def render_integral(original,watstor,selected):
    source=snow_reset.render_integral(original,watstor,selected) if selected['swsnow'] else prior.render_integral(original,watstor,selected)
    old=prior.ANNUAL_VALIDATION.replace('original ordinary','original Snow') if selected['swsnow'] else prior.ANNUAL_VALIDATION
    assert source.count(old)==1;source=source.replace(old,ANNUAL_VALIDATION,1)
    assert source.count('nprintday/=1')==1
    return source.replace('nprintday/=1','(nprintday<1.or.nprintday>1440)',1)


def render_macro(original,project,selected):
    if selected['swsnow']:
        source=snow.render_macro(original);assert source.count("'S5SPW001'")==2
        return source.replace("'S5SPW001'","'"+magic(project).decode()+"'")
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert original.count(begin)==original.count(end)==1
    first=original.index(begin);last=original.index(end,first)+len(end);prefix,suffix=original[:first],original[last:];source=original[first:last]
    magics=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(magics)==2 and len(set(magics))==1
    source=source.replace("'"+magics[0]+"'","'"+magic(project).decode()+"'")
    anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',source);assert len(anchors)==1
    imports='\n      use MOD_integral,only:hybrid_output_calendar_checkpoint'
    if selected['swhyst']:imports+='\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint'
    source=source.replace(anchors[0],anchors[0]+imports,1)
    anchor='        read(unit,iostat=ios) trailing';assert source.count(anchor)==1
    calls='        call hybrid_output_calendar_checkpoint(unit,.true.)\n'
    if selected['swhyst']:calls='        call hybrid_output_hysteresis_checkpoint(unit,.true.)\n'+calls
    source=source.replace(anchor,calls+anchor,1)
    anchor='      end if\n      close(unit)';assert source.count(anchor)==1
    calls='        call hybrid_output_calendar_checkpoint(unit,.false.)\n'
    if selected['swhyst']:calls='        call hybrid_output_hysteresis_checkpoint(unit,.false.)\n'+calls
    return prefix+source.replace(anchor,calls+anchor,1)+suffix



def apply_build(output,donor_build,project,patched):
    selected=active_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    is_snow=selected['swsnow']==1
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=history.HYSTERESIS_SHA:raise ValueError('Changed original hysteresis provider source')
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(snow.state_source(project) if is_snow else regular.state_source(project),encoding='cp1252')
    domain=SNOW_DOMAIN if is_snow else DOMAIN if selected['swhyst'] else None
    for name in ([domain] if domain else [])+([SNOW_PROVIDER] if is_snow else []):(output/(name+'.f90')).write_bytes(Path(__file__).with_name(name+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(snow.probe_source(project) if is_snow else ordinary.PROBE,encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'));anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1;path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project,selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    imports='\nuse MOD_integral,only:hybrid_output_calendar_apply'
    if is_snow:imports+='\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply'
    text=text.replace(anchor,anchor+imports,1);anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    calls='\n   call hybrid_output_calendar_apply()'+('\n   call snow_output_calendar_apply()' if is_snow else '')+'\n   call hybrid_original_output_initial_emit()'
    path.write_text(text.replace(anchor,calls+anchor,1),encoding='cp1252')
    if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original per-step clock-domain owners')
    (output/'timecontrol.f90').write_text(snow.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')) if is_snow else clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    function='hybrid_snow_soil_trial_residual' if is_snow else 'hybrid_ordinary_trial_residual'
    imports='   use MOD_integral,only:'+function
    if not is_snow:imports+=',hybrid_output_trial_residual\n   use hybrid_age_output_state,only:original_output_start_clock'
    text=text.replace(anchor,imports+'\n'+anchor,1);anchor='\n   implicit none\n';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'   real(8)::hybrid_perstep_trial_guard,hybrid_perstep_candidate_bottom\n',1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    guard="""
         if(swbotb==8.and..not.flboth)then
            hybrid_perstep_candidate_bottom=0d0
         else
            hybrid_perstep_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)
         end if
         hybrid_perstep_trial_guard="""+function+"""(hybrid_perstep_candidate_bottom)
"""
    if not is_snow:guard+="""         if(.not.flnonconv.and.t1900<original_output_start_clock+1d0)then
            if(abs(hybrid_perstep_trial_guard)<=1d-10.and.abs(hybrid_output_trial_residual())>1d-10)then
               write(*,'(a,6(1x,es25.17e3))')'ORDINARY_STALE_BOTTOM_TRIAL_WITNESS', &
                t1900,dt,qbot,hybrid_perstep_candidate_bottom,hybrid_output_trial_residual(),hybrid_perstep_trial_guard
            end if
         end if
"""
    guard+='         if(abs(hybrid_perstep_trial_guard)>1d-10)flnonconv=.true.';path.write_text(text.replace(anchor,anchor+guard,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1;ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    extra=[regular.PROVIDER,'hybrid_age_output_state']+([domain] if domain else [])+(['integral',SNOW_PROVIDER,'timecontrol'] if is_snow else ['timecontrol','integral'])
    patched=[*extra,*patched];patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
