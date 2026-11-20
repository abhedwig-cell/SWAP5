"""Compose existing water calendar owners with prescribed-groundwater carry."""
from pathlib import Path
import hashlib,re
import age_groundwater_output as prior
import perstep_output_domain as step_owner

ROOT=prior.ROOT
ordinary=prior.ordinary
regular=prior.regular
clock=prior.clock
history=prior.history
DOMAIN=history.DOMAIN
POLICY='original-groundwater-water-complete-state-calendar-v1'


def active_selection(project):
    from snow_water_groundwater import selection as snow_selection
    snow=snow_selection(project)
    if snow is not None:return snow
    if not project.original_output or not project.input_directory or project.macro or project.solute or project.age:return None
    from implicit_groundwater_state import enabled,numerical_selector
    if not enabled(project):return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous groundwater water calendar '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if len(flags)>1 or token not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid groundwater water step flag')
    step=token in ('.TRUE.','TRUE','.T.','T');npd=one('NPRINTDAY')
    # Literal existing implicit daily water ownership remains authoritative.
    if numerical_selector(project)==1 and npd==1 and not step:return None
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Groundwater water calendar requires original day-seed policy')
    monthly=one('SWMONTH');fmt=one('SWCSV',0);hys=one('SWHYST')
    dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES');requested=0 if monthly else one('PERIOD')
    if monthly not in (0,1) or fmt not in (0,1,2,3) or not 1<=npd<=1440 or hys not in (0,1,2) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366:raise ValueError('Invalid groundwater water calendar domain')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid groundwater water output precision')
    return dict(groundwater_water_output=True,kind='water',swsnow=0,swhea=1,swcalt=2,swfrost=0,swdra=one('SWDRA'),swhyst=hys,et=one('SWCFBS'),swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,period=1 if step or npd>1 else requested,flprintdt=step,groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=active_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):
    if active_selection(project) is None:return prior.magic(project)
    from implicit_groundwater_state import magic as native_magic
    return native_magic(project)


def metadata(project):
    from snow_undrained import selection as undrained_selection,metadata as undrained_metadata
    undrained=undrained_selection(project)
    if undrained is not None:return undrained_metadata(project,undrained)
    from snow_water_groundwater import selection as snow_selection,metadata as snow_metadata
    snow=snow_selection(project)
    if snow is not None:return snow_metadata(project,snow)
    selected=active_selection(project)
    if selected is None:
        result=prior.metadata(project)
        from implicit_snow_root_carry import metadata as snow_root_metadata
        root=snow_root_metadata(project,result['native_codec']) if result else None
        if root:
            result={**result,'native_codec':root['new_codec'],'implicit_snow_root_carry':root}
        from implicit_snow_cde_root_carry import metadata as cde_root_metadata
        root=cde_root_metadata(project,result['native_codec']) if result else None
        if root:
            result={**result,'native_codec':root['new_codec'],'implicit_snow_root_carry':root}
        return result
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=magic(project).decode(),**selected,source_sha256=sha(Path(__file__)),calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(clock.__file__)),perstep_owner_sha256=sha(Path(step_owner.__file__)),history_owner_sha256=sha(Path(history.__file__)),receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),original_integral_sha256=regular.INTEGRAL_SHA,original_watstor_sha256=clock.WATSTOR_SHA,original_timecontrol_sha256=clock.TIME_SHA,original_output_epoch=project.start_clock,physical_equations_changed=False,trial_water_guard_cm=1e-10,undefined_allocation_tails_serialized=False,preserves_requested_groups_and_precision=True)


def source_age_identity(original,project):return prior.source_age_identity(original,project)


def render_integral(original,watstor,selected):
    # Existing calendar implementations own all calendar arithmetic. The
    # unused ordinary boundary trial helper keeps its original5/8 guard;
    # implicit_groundwater_trial adds the actual groundwater reaction clone.
    if selected['flprintdt']:return step_owner.render_integral(original,watstor,selected)
    return ordinary.render_integral(original,watstor,selected)


def render_macro(original,project,selected):
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert original.count(begin)==original.count(end)==1
    first=original.index(begin);last=original.index(end,first)+len(end);source=original[first:last]
    codecs=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(codecs)==2 and len(set(codecs))==1
    source=source.replace(codecs[0],magic(project).decode())
    anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',source);assert len(anchors)==1
    imports='\n      use MOD_integral,only:hybrid_output_calendar_checkpoint'
    if selected['swhyst']:imports+='\n      use hybrid_output_hysteresis_domain,only:hybrid_output_hysteresis_checkpoint'
    source=source.replace(anchors[0],anchors[0]+imports,1)
    for restoring in ('.true.','.false.'):
        anchor='        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'
        assert source.count(anchor)==1
        calls=f'        call hybrid_output_calendar_checkpoint(unit,{restoring})\n'
        if selected['swhyst']:calls=f'        call hybrid_output_hysteresis_checkpoint(unit,{restoring})\n'+calls
        source=source.replace(anchor,calls+anchor,1)
    return original[:first]+source+original[last:]


def apply_build(output,donor_build,project,patched):
    from snow_undrained import selection as undrained_selection
    undrained=undrained_selection(project)
    if undrained is not None:
        from snow_undrained_build import apply_build as undrained_build
        return undrained_build(output,donor_build,project,patched,undrained)
    from snow_water_groundwater import selection as snow_selection
    snow=snow_selection(project)
    if snow is not None:
        from snow_water_groundwater_build import apply_build as snow_build
        return snow_build(output,donor_build,project,patched,snow)
    selected=active_selection(project)
    if selected is None:
        patched=prior.apply_build(output,donor_build,project,patched)
        from implicit_snow_cde_root_carry import apply_build as cde_root_build
        return cde_root_build(output,project,patched)
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=history.HYSTERESIS_SHA:raise ValueError('Changed original groundwater water hysteresis provider')
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
    extra=[]
    if selected['flprintdt'] or selected['nprintday']>1:
        if 'timecontrol' in patched or (output/'timecontrol.f90').exists():raise ValueError('Multiple groundwater water calendar clock owners')
        (output/'timecontrol.f90').write_text(clock.render_timecontrol((donor_build/'swap-selected/timecontrol.f90').read_text(encoding='cp1252')),encoding='cp1252');extra=['timecontrol']
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1;ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',*([DOMAIN] if selected['swhyst'] else []),*extra,'integral',*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
