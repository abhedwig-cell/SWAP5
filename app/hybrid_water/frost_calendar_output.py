"""Compose original calendar and Snow totals with the existing Frost event owner."""
import hashlib,re
from pathlib import Path
import original_output_thermal as thermal
import cde_interval_output as chemical
from frost_calendar_state import selection as input_selection,POLICY

ROOT=thermal.ROOT
regular=thermal.regular
ordinary=thermal.ordinary
DOMAIN=thermal.DOMAIN
SNOW_PROVIDER='thermal_output_snow_calendar_state'
SNOW_FIELDS=('cgsnow','cmelt','csnrai','csubl','isnrai','igsnow','isubl')
CODECS={(0,'water'):b'S5FCW001',(0,'cde'):b'S5FCC001',
        (1,'water'):b'S5FCW002',(1,'cde'):b'S5FCC002'}


def selection(project):
    if not getattr(project,'original_output',False) or project.macro or project.age or not project.input_directory:return None
    selected=input_selection(project.input_directory,project.original_output)
    if selected is None:return None
    if project.time_step_policy!='original-adaptive-event-closure-v1':
        raise ValueError('Original Frost calendar requires its original event-closure policy')
    if project.solute!=(selected['kind']=='cde'):raise ValueError('Frost calendar chemical model disagrees with original reader')
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original Frost calendar '+key)
        return values[0][1:-1] if quoted else int(values[0])
    fmt=one('SWCSV',0);precision=one('NUM_DECIMALS',5) if fmt else None
    if fmt not in (0,1,2,3) or precision is not None and not 5<=precision<=12:
        raise ValueError('Invalid original Frost calendar output format/precision')
    return dict(thermal_output=True,thermal_calendar=True,frost_calendar=True,
        cde_interval_output=bool(project.solute),kind=selected['kind'],swsnow=1,swhea=1,swcalt=2,
        swfrost=1,swdra=1,swhyst=selected['hysteresis'],swcsv=fmt,nprintday=1,
        swmonth=selected['swmonth'],swodat=selected['swodat'],swres=selected['swres'],
        requested_period=selected['requested_period'],period=selected['requested_period'],flprintdt=False,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def codec(project):
    selected=input_selection(project.input_directory,project.original_output)
    if selected is None:raise ValueError('Outside bounded original Frost calendar native domain')
    return CODECS[(selected['implicit'],selected['kind'])]


def metadata(project):
    selected=selection(project)
    if selected is None:return None
    folder=Path(__file__).parent;sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    providers=[Path(__file__).name,'frost_calendar_state.py','original_output_thermal.py',
               'original_output_thermal_domain.f90','age_output_calendar.py',
               'frost_drainage_composition.py','implicit_frost_composition.py','implicit_frost_root_state.py',
               'frost_calendar_terminal_water.py']
    providers.append('cde_interval_snow_state.f90' if project.solute else SNOW_PROVIDER+'.f90')
    if project.solute:providers+=['cde_interval_output.py','cde_interval_source.py','cde_interval_receipt.f90','cde_interval_output_state.f90']
    return dict(policy=POLICY,native_codec=codec(project).decode(),**selected,
        providers={name:sha(folder/name) for name in providers},
        original_integral_sha256=regular.INTEGRAL_SHA,original_hysteresis_sha256=thermal.HYSTERESIS_SHA,
        original_output_epoch=project.start_clock,receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
        snow_output_fields=list(SNOW_FIELDS),snow_output_domain_bytes=32,snow_output_value_bytes=56,
        cde_output_state_version=2 if project.solute else None,
        cde_output_state_reals=20+project.nodes if project.solute else None,
        cde_output_state_private_reals=2 if project.solute else None,
        cde_daily_mass_guard_mg_cm2=1e-10 if project.solute else None,
        conserved_cde_prefix_offset_bytes=48 if project.solute else None,
        original_pending_dates_not_normalized=True,preserves_requested_groups_and_precision=True,
        undefined_allocation_tails_serialized=False,physical_equations_changed=False,new_physical_state=False,
        timecontrol_provider='UNCHANGED_EXISTING_FROST_EVENT_CLOSURE',new_native_format=True,
        terminal_water_trial_projection='ACTUAL_DAY_FRAME_WITH_UNCHANGED_ORIGINAL_TERMS_AND_1E_10_LIMIT')


def source_age_identity(original,project):
    result=dict(original);result.update(native_codec=codec(project).decode(),original_output=metadata(project));return result


def render_macro(source,project):
    # The existing real thermal renderer retains the complete actual history,
    # calendar and chemical frames. Add the original seven Snow totals once.
    text=thermal.render_macro(source,project)
    anchor='      use MOD_integral,only:hybrid_output_calendar_checkpoint';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\n      use hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_checkpoint',1)
    for flag in ('.true.','.false.'):
        anchor='        call hybrid_output_calendar_checkpoint(unit,'+flag+')';assert text.count(anchor)==1
        text=text.replace(anchor,'        call snow_output_calendar_checkpoint(unit,'+flag+')\n'+anchor,1)
    return text


def apply_build(output,donor_build,project,patched):
    selected=selection(project)
    if selected is None:raise ValueError('Missing bounded original Frost calendar build selection')
    folder=Path(__file__).parent;sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    if sha(donor_build/'swap-selected/hysteresis.f90')!=thermal.HYSTERESIS_SHA:
        raise ValueError('Changed original Frost calendar hysteresis source')
    from frost_calendar_terminal_water import install as terminal_day_install
    terminal_day_install(output)
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    (output/(DOMAIN+'.f90')).write_bytes((folder/(DOMAIN+'.f90')).read_bytes())
    (output/(SNOW_PROVIDER+'.f90')).write_bytes((folder/('cde_interval_snow_state.f90' if project.solute else SNOW_PROVIDER+'.f90')).read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    integral=chemical.render_integral(original,selected) if project.solute else thermal.render_integral(original,None,selected)
    (output/'integral.f90').write_text(integral,encoding='cp1252')
    probe=chemical.probe_source(project,selected) if project.solute else thermal.probe_source(project)
    (output/'age_output_calendar_probe.f90').write_text(probe,encoding='cp1252')
    extra=[regular.PROVIDER,'hybrid_age_output_state',DOMAIN,'integral',SNOW_PROVIDER]
    if project.solute:
        if sha(donor_build/'swap-selected/solute.f90')!=chemical.bridge.ORIGINAL_SHA:
            raise ValueError('Changed original Frost calendar CDE source')
        (output/'cde_interval_receipt.f90').write_bytes((folder/'cde_interval_receipt.f90').read_bytes())
        (output/'original_cde_output_state.f90').write_bytes((folder/'cde_interval_output_state.f90').read_bytes())
        path=output/'solute.f90';assert 'solute' in patched and path.is_file()
        path.write_text(chemical.bridge.source(path.read_text(encoding='cp1252')),encoding='cp1252')
        patched.insert(patched.index('solute')+1,'original_cde_output_state');extra.insert(1,'cde_interval_receipt')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1
    text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252'),project),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    imports='\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply'
    calls='\n   call hybrid_output_calendar_apply()\n   call snow_output_calendar_apply()'
    if project.solute:
        imports+='\nuse hybrid_original_cde_output_state,only:hybrid_cde_output_apply';calls+='\n   call hybrid_cde_output_apply()'
    text=text.replace(anchor,anchor+imports,1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,calls+'\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1
            ordinary.binary_patch().source(original);text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for before,after in ordinary.output_patch('vector').edits(original):
            assert text.count(before)==1;text=text.replace(before,after,1)
        path.write_text(text,encoding='cp1252')
    patched=[*extra,*patched];patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
