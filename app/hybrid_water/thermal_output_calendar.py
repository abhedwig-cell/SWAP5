"""Original water Snow calendars composed from literal thermal/calendar owners."""
from pathlib import Path
import hashlib
import re
import original_output_thermal as prior

ROOT=prior.ROOT
regular=prior.regular
ordinary=prior.ordinary
DOMAIN=prior.DOMAIN
POLICY='original-water-snow-output-calendar-carry-v2'
MAGIC=b'S5CTW002'
SNOW_PROVIDER='thermal_output_snow_calendar_state'
SNOW_FIELDS=('cgsnow','cmelt','csnrai','csubl','isnrai','igsnow','isubl')


def calendar_selection(project):
    if (not getattr(project,'original_output',False) or project.macro or not project.input_directory
            or project.solute or project.age):return None
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous original Snow calendar '+key)
        return values[0][1:-1] if quoted else int(values[0])
    if one('SWSNOW')!=1:return None
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    if len(flags)>1:raise ValueError('Ambiguous original Snow calendar FLPRINTDT')
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if token not in ('.FALSE.','FALSE','.F.','F','.TRUE.','TRUE','.T.','T'):
        raise ValueError('Invalid original Snow calendar FLPRINTDT')
    perstep=token in ('.TRUE.','TRUE','.T.','T')
    nprint=one('NPRINTDAY');monthly=one('SWMONTH')
    requested=0 if monthly else one('PERIOD');dates=0 if monthly else one('SWODAT')
    if nprint==1 and not monthly and not dates and requested==1 and not perstep:return None
    if nprint!=1 or perstep:raise ValueError('Original Snow calendar currently requires one daily output opportunity')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Original Snow calendar requires its original day-seed policy')
    reset=0 if monthly else one('SWRES');fmt=one('SWCSV',0);mode=one('SWHYST')
    if monthly not in (0,1) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366:
        raise ValueError('Invalid original Snow calendar schedule')
    if mode not in (0,1,2) or fmt not in (0,1,2,3):raise ValueError('Invalid original Snow calendar process/format')
    for key,value in dict(SWMACRO=0,SWSOLU=0,SWHEA=1,SWCALT=2,SWFROST=0,SWBR=0,SWDRA=1,SWMETDETAIL=0,SWSOPHY=0).items():
        if one(key)!=value:raise ValueError('Original Snow calendar currently excludes '+key)
    from experimental_project import inspect
    if inspect(project.input_directory,original_output=True)['boundary']['SWBOTB'] not in (5,8):
        raise ValueError('Original Snow calendar currently requires lower boundary5/8')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if precision is not None and not 5<=precision<=12:raise ValueError('Invalid original Snow calendar precision')
    return dict(thermal_output=True,thermal_calendar=True,kind='water',swsnow=1,swhea=1,swcalt=2,swfrost=0,swdra=1,
        swhyst=mode,swcsv=fmt,nprintday=1,swmonth=monthly,swodat=dates,swres=reset,requested_period=requested,
        period=requested,flprintdt=False,groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def selection(project):
    selected=calendar_selection(project)
    return prior.selection(project) if selected is None else selected


def magic(project):return prior.magic(project) if calendar_selection(project) is None else MAGIC


def metadata(project):
    selected=calendar_selection(project)
    if selected is None:return prior.metadata(project)
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,native_codec=MAGIC.decode(),**selected,source_sha256=sha(Path(__file__)),
        predecessor_owner_sha256=sha(Path(prior.__file__)),ordinary_owner_sha256=sha(Path(ordinary.__file__)),
        domain_source_sha256=sha(Path(prior.__file__).with_name(DOMAIN+'.f90')),
        snow_output_source_sha256=sha(Path(__file__).with_name(SNOW_PROVIDER+'.f90')),
        snow_output_fields=list(SNOW_FIELDS),snow_output_domain_bytes=32,snow_output_value_bytes=56,
        calendar_owner_sha256=sha(Path(regular.__file__)),clock_owner_sha256=sha(Path(prior.clock.__file__)),
        receipt_provider_sha256=sha(ROOT/'src/process/mod_original_output_receipt.f90'),
        original_integral_sha256=regular.INTEGRAL_SHA,original_output_epoch=project.start_clock,
        original_hysteresis_sha256=prior.HYSTERESIS_SHA,cde_output_state_sha256=None,
        vector_catalog_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-VECTOR-OUTPUT-01/source.py') if selected['swcsv'] else None,
        binary_correction_sha256=sha(ROOT/'reference/swap-4.3.1/patches/NOMACRO-BINARY-OUTPUT-01/source.py') if selected['swcsv']==3 else None,
        preserves_requested_groups_and_precision=True,undefined_allocation_tails_serialized=False,
        conserved_cde_prefix_offset_bytes=None)


def age_identity(original,project):
    if calendar_selection(project) is None:return prior.age_identity(original,project)
    result=dict(original);result.update(native_codec=MAGIC.decode(),original_output=metadata(project));return result


def render_macro(source):
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert source.count(begin)==source.count(end)==1
    first=source.index(begin);last=source.index(end,first)+len(end);prefix,suffix=source[:first],source[last:];source=source[first:last]
    magics=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(magics)==2 and len(set(magics))==1
    source=source.replace("'"+magics[0]+"'","'"+MAGIC.decode()+"'")
    anchors=re.findall(r'(?m)^      use MOD_grid, only: numnod(?:,dz)?$',source);assert len(anchors)==1
    anchor=anchors[0];source=source.replace(anchor,anchor+'\n      use hybrid_output_thermal_domain,only:hybrid_output_thermal_checkpoint\n      use hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_checkpoint\n      use MOD_integral,only:hybrid_output_calendar_checkpoint',1)
    anchor='        read(unit,iostat=ios) trailing';assert source.count(anchor)==1
    source=source.replace(anchor,'        call hybrid_output_thermal_checkpoint(unit,.true.)\n        call snow_output_calendar_checkpoint(unit,.true.)\n        call hybrid_output_calendar_checkpoint(unit,.true.)\n'+anchor,1)
    anchor='      end if\n      close(unit)';assert source.count(anchor)==1
    source=source.replace(anchor,'        call hybrid_output_thermal_checkpoint(unit,.false.)\n        call snow_output_calendar_checkpoint(unit,.false.)\n        call hybrid_output_calendar_checkpoint(unit,.false.)\n'+anchor,1)
    return prefix+source+suffix


def apply_build(output,donor_build,project,patched):
    selected=calendar_selection(project)
    if selected is None:return prior.apply_build(output,donor_build,project,patched)
    if hashlib.sha256((donor_build/'swap-selected/hysteresis.f90').read_bytes().replace(b'\r\n',b'\n')).hexdigest()!=prior.HYSTERESIS_SHA:
        raise ValueError('Changed original hysteresis provider source')
    (output/(regular.PROVIDER+'.f90')).write_bytes((ROOT/'src/process'/(regular.PROVIDER+'.f90')).read_bytes())
    (output/'hybrid_age_output_state.f90').write_text(regular.state_source(project),encoding='cp1252')
    (output/(DOMAIN+'.f90')).write_bytes(Path(prior.__file__).with_name(DOMAIN+'.f90').read_bytes())
    (output/(SNOW_PROVIDER+'.f90')).write_bytes(Path(__file__).with_name(SNOW_PROVIDER+'.f90').read_bytes())
    original=(donor_build/'swap-selected/integral.f90').read_text(encoding='cp1252')
    (output/'integral.f90').write_text(prior.render_integral(original,None,selected),encoding='cp1252')
    (output/'age_output_calendar_probe.f90').write_text(prior.probe_source(project),encoding='cp1252')
    path=output/'swap.f90';text=regular.render_swap(path.read_text(encoding='cp1252'))
    anchor='use hybrid_day_window, only:';assert text.count(anchor)==1;text=text.replace(anchor,'use MOD_integral,only:hybrid_output_crop_apply\n'+anchor,1)
    anchor='         call hybrid_apply_wofost(fl_cropemergence)';assert text.count(anchor)==1
    path.write_text(text.replace(anchor,anchor+'\n         call hybrid_output_crop_apply()',1),encoding='cp1252')
    path=output/'macropore.f90';path.write_text(render_macro(path.read_text(encoding='cp1252')),encoding='cp1252')
    path=output/'swap_main.f90';text=path.read_text(encoding='cp1252');anchor='use MOD_grid, only: numnod';assert text.count(anchor)==1
    text=text.replace(anchor,anchor+'\nuse MOD_integral,only:hybrid_output_calendar_apply\nuse hybrid_thermal_output_snow_calendar_state,only:snow_output_calendar_apply',1)
    anchor="\n   write(*,'(a,*(1x,es25.17e3))') 'HYBRID_HYDRAULIC', gwl, qbot, h(1:numnod)";assert text.count(anchor)==1
    path.write_text(text.replace(anchor,'\n   call hybrid_output_calendar_apply()\n   call snow_output_calendar_apply()\n   call hybrid_original_output_initial_emit()'+anchor,1),encoding='cp1252')
    if selected['swcsv']:
        path=output/'swap_csv_output.f90';text=path.read_text(encoding='cp1252');original=(donor_build/'swap-selected/swap_csv_output.f90').read_bytes()
        if selected['swcsv']==3:
            anchor='      else if (swcsv == 3) then ! binary\n         ! datetime';assert text.count(anchor)==1
            ordinary.binary_patch().source(original)
            text=text.replace(anchor,'      else if (swcsv == 3) then ! binary\n         allocate(buffer(parlen-1))\n         ! datetime',1)
        for old,new in ordinary.output_patch('vector').edits(original):
            assert text.count(old)==1,old;text=text.replace(old,new,1)
        path.write_text(text,encoding='cp1252')
    patched=[regular.PROVIDER,'hybrid_age_output_state',DOMAIN,'integral',SNOW_PROVIDER,*patched]
    patched.insert(patched.index('swap'),'age_output_calendar_probe');return patched
