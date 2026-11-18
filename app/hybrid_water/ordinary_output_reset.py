"""Original ordinary water FLPRINTDT annual reset; literal physical owners."""
from pathlib import Path
import hashlib,re
import thermal_output_reset as prior
import original_output_hysteresis as history

ROOT=prior.ROOT
ordinary=prior.ordinary
regular=ordinary.regular
clock=ordinary.clock
DOMAIN=history.DOMAIN
POLICY='original-ordinary-water-flprintdt-annual-reset-v1'
MAGIC=b'S5ORW001'
HYST_MAGIC=b'S5ORH001'
ANNUAL_VALIDATION="! TimeControl resets cntper to1 at the first day of each new year for\n! SWRES1/effective period1, including original FLPRINTDT. Validate the actual\n! completed day against the immutable original epoch; never repair a counter.\n if(.not.flprintdt.or.swres/=1)error stop 'Foreign original ordinary annual-reset policy'\n annual_expected=0\n if(header(7)>0)then\n  annual_day=original_output_start_clock+dble(header(7))-1d0\n  call dtdpar(annual_day+0.1d0,annual_date,annual_seconds)\n  annual_date(2:6)=0;annual_date(2)=1;annual_date(3)=1\n  call dtardp(annual_date,0.0,annual_jan1)\n  annual_expected=min(header(7),nint(annual_day-annual_jan1)+1)\n end if\n if(header(8)/=annual_expected)error stop 'Inconsistent original ordinary annual-reset day counter'"


def active_selection(project):
    if (not getattr(project,'original_output',False) or project.macro or not project.input_directory
            or project.solute or project.age):return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original Snow FLPRINTDT '+key)
        return values[0][1:-1] if quoted else int(values[0])
    if one('SWSNOW')!=0:return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if not flags:return None
    if len(flags)!=1 or flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):
        raise ValueError('Invalid original Snow FLPRINTDT flag')
    if flags[0].strip().upper() in ('.FALSE.','FALSE','.F.','F'):return None
    if one('NPRINTDAY')!=1:raise ValueError('Original ordinary FLPRINTDT currently requires NPRINTDAY1')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Original ordinary FLPRINTDT requires original day-seed policy')
    for key,value in dict(SWMACRO=0,SWSOLU=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:raise ValueError('Original ordinary FLPRINTDT currently excludes '+key)
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):raise ValueError('Original ordinary FLPRINTDT requires lower boundary5/8')
    fmt=one('SWCSV',0);hys=one('SWHYST');monthly=one('SWMONTH');dates=0 if monthly else one('SWODAT')
    requested=0 if monthly else one('PERIOD');reset=0 if monthly else one('SWRES')
    if fmt not in (0,1,2,3) or hys not in (0,1,2) or monthly not in (0,1) or dates not in (0,1) or not 0<=requested<=366:
        raise ValueError('Invalid original Snow FLPRINTDT output selectors')
    if reset!=1:return None
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original Snow FLPRINTDT precision')
    return dict(ordinary_reset=True,kind='water',swsnow=0,swhea=1,swcalt=2,swfrost=0,swdra=1,
        swhyst=hys,swcsv=fmt,nprintday=1,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1,flprintdt=True,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)



def selection(project):
    selected=active_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):
    selected=active_selection(project)
    return prior.magic(project) if selected is None else HYST_MAGIC if selected['swhyst'] else MAGIC


def metadata(project):
    selected=active_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),
        predecessor_owner_sha256=sha(Path(prior.__file__)),ordinary_owner_sha256=sha(Path(ordinary.__file__)),
        history_owner_sha256=sha(Path(history.__file__)),domain_source_sha256=sha(Path(history.__file__).with_name(DOMAIN+'.f90')) if selected['swhyst'] else None,
        native_domain_bytes=40 if selected['swhyst'] else 0,calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),
        receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),original_integral_sha256=regular.INTEGRAL_SHA,
        original_watstor_sha256=clock.WATSTOR_SHA,original_timecontrol_sha256=clock.TIME_SHA,original_output_epoch=project.start_clock,
        original_hysteresis_sha256=history.HYSTERESIS_SHA,cde_output_state_sha256=None,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,
        original_flprintdt_date_gated=True,original_pending_dates_not_normalized=True,
        annual_counter_policy='original-completed-day-min-global-and-year-ordinal-v1',
        trial_receipt_policy=clock.TRIAL_RECEIPT_POLICY,trial_water_guard_cm=1e-10,physical_equations_changed=False)


def age_identity(original,project):
    if active_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=magic(project).decode(),original_output=metadata(project));return result


def render_integral(original,watstor,selected):
    source=ordinary.render_integral(original,watstor,selected)
    anchor='integer::header(20),witness_header(20),ios,nreal';assert source.count(anchor)==1
    source=source.replace(anchor,anchor+'\ninteger::annual_date(6),annual_expected\nreal(4)::annual_seconds\nreal(8)::annual_day,annual_jan1',1)
    anchor=" if((period==0.or.flprintdt).and.header(8)/=header(7))error stop 'Inconsistent original zero-period day counter'"
    assert source.count(anchor)==1
    return source.replace(anchor,ANNUAL_VALIDATION,1)


def render_macro(original,project,selected):
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
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=history.HYSTERESIS_SHA:
        raise ValueError('Changed original hysteresis provider source')
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    if selected['swhyst']:(output/(DOMAIN+'.f90')).write_bytes(Path(history.__file__).with_name(DOMAIN+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252');watstor=(donor_build/'swap-selected/watstor.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(render_integral(original,watstor,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(ordinary.PROBE,encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'));anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project,selected),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple original ordinary output clock owners')
    (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'headcalc.f90';text=path.read_text(encoding='cp1252');anchor='   use hybrid_step_budget, only: projected_water_residual';assert text.count(anchor)==1
    text=text.replace(anchor,'   use MOD_integral,only:hybrid_output_trial_residual\n'+anchor,1)
    anchor='         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         if(abs(hybrid_output_trial_residual())>1d-10)flnonconv=.true.',1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1
            ordinary.binary_patch().source(original);text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):
            assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    extra=[regular.PROVIDER,'hybrid_age_output_state']+([DOMAIN] if selected['swhyst'] else [])+['timecontrol','integral']
    patched=[*extra,*patched];patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
