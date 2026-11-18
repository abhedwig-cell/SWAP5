"""Original CDE subdaily/per-step clocks with literal private-state providers."""
from pathlib import Path
import hashlib,re
import cde_interval_output as prior
import perstep_output_domain as water
import thermal_output_clock as snow_clock
import original_output_thermal as thermal
import thermal_output_step as snow_macro
import cde_interval_source as bridge

ROOT=prior.ROOT
ordinary=prior.ordinary
regular=prior.regular
DOMAIN=prior.DOMAIN
SNOW_DOMAIN=prior.SNOW_DOMAIN
SNOW_PROVIDER=prior.SNOW_PROVIDER
SNOW_FIELDS=prior.SNOW_FIELDS
POLICY='original-cde-clock-output-and-observed-daily-flux-v1'
MAGICS={'ordinary':b'S5CCC001','history':b'S5CCH001','snow':b'S5CCS001'}


def active_selection(project):
    if not getattr(project,'original_output',False) or project.macro or not project.input_directory or not project.solute or project.age:return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original CDE interval '+key)
        return values[0][1:-1] if quoted else int(values[0])
    swsnow=one('SWSNOW')
    if swsnow not in (0,1):return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if len(flags)>1:raise ValueError('Ambiguous original CDE interval FLPRINTDT')
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):raise ValueError('Invalid original CDE interval FLPRINTDT')
    perstep=token in ('.TRUE.','TRUE','.T.','T');nprint=one('NPRINTDAY')
    if not 1<=nprint<=1440:raise ValueError('Invalid original CDE clock print count')
    if not perstep and nprint==1:return None
    monthly=one('SWMONTH');dates=0 if monthly else one('SWODAT');requested=0 if monthly else one('PERIOD')
    if project.time_step_policy!='original-adaptive-day-seed-v1':return None
    for key,value in dict(SWMACRO=0,SWSOLU=1,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:return None
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):return None
    reset=0 if monthly else one('SWRES');fmt=one('SWCSV',0);hys=one('SWHYST')
    if hys not in (0,1,2):return None
    if monthly not in (0,1) or dates not in (0,1) or reset not in (0,1) or fmt not in (0,1,2,3) or not 0<=requested<=366:raise ValueError('Invalid original CDE interval selectors')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original CDE interval precision')
    return dict(cde_clock_output=True,cde_interval_output=True,thermal_output=bool(swsnow),thermal_calendar=bool(swsnow),thermal_clock=bool(swsnow),thermal_step=bool(swsnow and perstep),kind='cde',swsnow=swsnow,swhea=1,swcalt=2,swfrost=0,swdra=1,
        swhyst=hys,swcsv=fmt,nprintday=nprint,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1,flprintdt=perstep,
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
    folder=Path(__file__).parent;is_snow=bool(selected['swsnow']);domain=SNOW_DOMAIN if is_snow else DOMAIN if selected['swhyst'] else None
    result=dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),predecessor_owner_sha256=sha(Path(prior.__file__)),
        ordinary_owner_sha256=sha(Path(ordinary.__file__)),thermal_owner_sha256=sha(Path(thermal.__file__)),calendar_owner_sha256=sha(Path(regular.__file__)),
        domain_source_sha256=sha(folder/(domain+'.f90')) if domain else None,native_domain_bytes=80 if is_snow else 40 if domain else 0,
        original_integral_sha256=regular.INTEGRAL_SHA,original_solute_sha256=bridge.ORIGINAL_SHA,original_output_epoch=project.start_clock,
        clock_owner_sha256=sha(Path(water.clock.__file__)),snow_clock_owner_sha256=sha(Path(snow_clock.__file__)),perstep_owner_sha256=sha(Path(water.__file__)),
        original_timecontrol_sha256=water.clock.TIME_SHA,original_watstor_sha256=water.clock.WATSTOR_SHA,original_flprintdt_date_gated=selected['flprintdt'],
        annual_counter_policy='original-global-or-completed-year-count-v1' if selected['flprintdt'] else 'original-print-period-counter-v1',
        timecontrol_composition='literal-original-snow-perstep-coincident-end-day-v1' if is_snow and selected['flprintdt'] else 'literal-original-snow-subdaily-coincident-end-day-v1' if is_snow else 'literal-original-bound-output-epoch-v1',
        trial_receipt_policy='literal-original-independent-soil-candidate-bottom-cde-clock-v1',
        private_bridge_source_sha256=sha(Path(bridge.__file__)),private_cde_interval_fields=list(bridge.FIELDS),cde_output_state_sha256=sha(folder/'cde_interval_output_state.f90'),
        cde_output_state_version=2,cde_output_state_reals=20+project.nodes,cde_output_state_private_reals=2,cde_daily_receipt_source_sha256=sha(folder/'cde_interval_receipt.f90'),
        cde_daily_flux_policy='actual-original-six-rhs-increments-including-corrected-ssdi-v1',cde_daily_mass_guard_mg_cm2=1e-10,
        calendar_initial_past_date_policy='original-initial-interval-pointer-remains-one-v1',original_pending_dates_not_normalized=True,
        cde_interval_anchor='actual saved sampro0; validated against actual SAMPRO-sampro0 == original SDSTOR; never reconstructed',
        conserved_cde_prefix_offset_bytes=48,receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,physical_equations_changed=False)
    if is_snow:result.update(snow_output_source_sha256=sha(folder/'cde_interval_snow_state.f90'),snow_output_fields=list(SNOW_FIELDS),snow_output_domain_bytes=32,snow_output_value_bytes=56,
        snow_stock='actual MOD_snow ssnow',snow_increment_slots=[2,3,13])
    return result


def age_identity(original,project):
    if active_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def ordinary_trial_source(original,watstor):
    source=water.prior.trial_source(original,watstor)
    anchor='swdra/=1.or..not.flprintdt.or.nprintday/=1.or. &'
    assert source.count(anchor)==1
    return source.replace(anchor,'swdra/=1.or.nprintday<1.or.nprintday>1440.or. &\n (.not.flprintdt.and.nprintday==1).or. &',1)


def render_integral(original,watstor,selected):
    if selected['flprintdt']:
        source=water.render_integral(original,watstor,selected)
    elif selected['swsnow']:
        source=snow_clock.render_integral(original,watstor,selected)
    else:
        source=ordinary.render_integral(original,watstor,selected)
        anchor='end module MOD_integral';assert source.count(anchor)==1
        source=source.replace(anchor,ordinary_trial_source(original,watstor)+'\n'+anchor,1)
    anchor="if(ioutdatint/=1+count(outdatint>0d0.and.outdatint<t1900-1d-8))error stop 'Inconsistent original interval date pointer'"
    assert source.count(anchor)==1
    guard="""! Original initial explicit date remains pending when it precedes TSTART.
if(outdatint(1)>0d0.and.outdatint(1)<original_output_start_clock-1d-8)then
 if(ioutdatint/=1)error stop 'Inconsistent original pending initial interval date pointer'
else
 """+anchor+"\nend if"
    return source.replace(anchor,guard,1)


def render_macro(original,project,selected):
    if selected['swsnow']:
        source=snow_macro.render_macro(original);assert source.count("'S5SPW001'")==2
        source=source.replace("'S5SPW001'","'"+magic(project).decode()+"'")
    else:
        first=original.index('    subroutine hybrid_macro_checkpoint(');last=original.index('    end subroutine hybrid_macro_checkpoint',first)+len('    end subroutine hybrid_macro_checkpoint')
        prefix,suffix=original[:first],original[last:];source=original[first:last]
        magics=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(magics)==2 and len(set(magics))==1
        source=source.replace("'"+magics[0]+"'","'"+magic(project).decode()+"'")
        anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',source);assert len(anchors)==1
        imports='\n      use MOD_integral,only:hybrid_output_calendar_checkpoint'
        if selected['swhyst']:imports+='\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint'
        source=source.replace(anchors[0],anchors[0]+imports,1)
        for restoring,anchor in [('.true.','        read(unit,iostat=ios) trailing'),('.false.','      end if\n      close(unit)')]:
            assert source.count(anchor)==1;calls=''
            if selected['swhyst']:calls+=f'        call hybrid_output_hysteresis_checkpoint(unit,{restoring})\n'
            calls+=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})\n';source=source.replace(anchor,calls+anchor,1)
        source=prefix+source+suffix
    anchor='      use MOD_integral,only:hybrid_output_calendar_checkpoint';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\n      use hybrid_original_cde_output_state,only:hybrid_cde_output_checkpoint',1)
    for restoring in ('.true.','.false.'):
        anchor=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})';assert source.count(anchor)==1
        source=source.replace(anchor,anchor+f'\n        call hybrid_cde_output_checkpoint(unit,{restoring})',1)
    return source


def probe_source(project,selected):
    if selected['swsnow']:source=snow_clock.probe_source(project)
    else:
        source=ordinary.PROBE.replace('use hybrid_age_output_state','use MOD_solute,only:sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nuse MOD_integral,only:iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\nuse hybrid_age_output_state',1)
        anchor="write(*,'(a,1x,i0,1x,es25.17e3)')'ORIGINAL_DAILY_RECEIPT',daycum,t1900";assert source.count(anchor)==1
        source=source.replace(anchor,"write(*,'(a,9(1x,es25.17e3))')'HYBRID_SOLUTE_LEDGER',sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\nwrite(*,'(a,6(1x,es25.17e3))')'HYBRID_UPTAKE',iptra,iqrot,iqreddry,iqredwet,iqredsol,iqredfrs\n"+anchor,1)
    anchor='subroutine hybrid_age_output_day_emit()';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\nuse iso_fortran_env,only:int64\nuse hybrid_cde_interval_receipt,only:cde_day_close,cde_day_diagnostics,CDE_DAY_OK',1)
    anchor='real(8)::stocks(12),flow(16)';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\nreal(8)::cde_daily(9),cde_initial,cde_flow(6)\ninteger(int64)::cde_counts(6)\nlogical::cde_live',1)
    anchor="write(*,'(a,9(1x,es25.17e3))')'HYBRID_SOLUTE_LEDGER',sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev";assert source.count(anchor)==1
    replacement="""call cde_day_close(sampro,cde_daily,status)
if(status/=CDE_DAY_OK)error stop 'Actual CDE independent daily mass receipt rejected'
call cde_day_diagnostics(cde_initial,cde_flow,cde_counts,cde_live)
if(cde_live)error stop 'Unclosed actual CDE daily receipt'
write(*,'(a,9(1x,es25.17e3))')'HYBRID_SOLUTE_LEDGER',cde_daily
write(*,'(a,17(1x,es25.17e3))')'CDE_INTERVAL_DAILY_AUDIT', &
 cde_initial,sampro,cde_flow,cde_daily(9),sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev
write(*,'(a,6(1x,i0))')'CDE_INTERVAL_INCREMENT_COUNTS',cde_counts"""
    return source.replace(anchor,replacement,1)


def apply_build(output,donor_build,project,patched):
    selected=active_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    if sha(donor_build/'swap-selected/solute.f90')!=bridge.ORIGINAL_SHA:raise ValueError('Changed actual original CDE interval provider source')
    if sha(donor_build/'swap-selected/hysteresis.f90')!=water.history.HYSTERESIS_SHA:raise ValueError('Changed original CDE interval hysteresis source')
    folder=Path(__file__).parent;is_snow=bool(selected['swsnow']);domain=SNOW_DOMAIN if is_snow else DOMAIN if selected['swhyst'] else None
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(snow_clock.state_source(project) if is_snow else regular.state_source(project),encoding='cp1252')
    if domain:(output/(domain+'.f90')).write_bytes((folder/(domain+'.f90')).read_bytes())
    (output/'cde_interval_receipt.f90').write_bytes((folder/'cde_interval_receipt.f90').read_bytes())
    (output/'original_cde_output_state.f90').write_bytes((folder/'cde_interval_output_state.f90').read_bytes())
    path=output/'solute.f90';assert 'solute' in patched and path.exists();path.write_text(bridge.source(path.read_text(encoding='cp1252')),encoding='cp1252')
    patched.insert(patched.index('solute')+1,'original_cde_output_state')
    if is_snow:(output/(SNOW_PROVIDER+'.f90')).write_bytes((folder/'cde_interval_snow_state.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    if sha(donor_build/'swap-selected/watstor.f90')!=water.clock.WATSTOR_SHA:raise ValueError('Changed original CDE clock soil stock source')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(probe_source(project,selected),encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'));anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1;path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project,selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    imports='\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_original_cde_output_state,only:hybrid_cde_output_apply'
    if is_snow:imports+='\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply'
    text=text.replace(anchor,anchor+imports,1);anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    calls='\n   call hybrid_output_calendar_apply()\n   call hybrid_cde_output_apply()'+('\n   call snow_output_calendar_apply()' if is_snow else '')+'\n   call hybrid_original_output_initial_emit()'
    path.write_text(text.replace(anchor,calls+anchor,1),encoding='cp1252')
    if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original CDE clock owners')
    original_time=(donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')
    if is_snow:time_source=(water.snow.render_timecontrol if selected['flprintdt'] else snow_clock.render_timecontrol)(original_time)
    else:time_source=water.clock.render_timecontrol(original_time)
    (output/'timecontrol.f90').write_text(time_source,encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    function='hybrid_snow_soil_trial_residual' if is_snow else 'hybrid_ordinary_trial_residual'
    text=text.replace(anchor,'   use MOD_integral,only:'+function+'\n'+anchor,1)
    anchor='\n   implicit none\n';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\n',1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    guard="""
         if(swbotb==8.and..not.flboth)then
            hybrid_cde_clock_candidate_bottom=0d0
         else
            hybrid_cde_clock_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)
         end if
         hybrid_cde_clock_trial_guard="""+function+"""(hybrid_cde_clock_candidate_bottom)
         if(abs(hybrid_cde_clock_trial_guard)>1d-10)flnonconv=.true."""
    path.write_text(text.replace(anchor,anchor+guard,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1;ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    extra=[regular.PROVIDER,'cde_interval_receipt','hybrid_age_output_state']+([domain] if domain else [])+['integral']+([SNOW_PROVIDER] if is_snow else [])+['timecontrol']
    patched=[*extra,*patched];patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
