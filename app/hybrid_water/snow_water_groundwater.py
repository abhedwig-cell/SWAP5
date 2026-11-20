"""Bounded original water/Snow groundwater domain; integration not yet admitted."""
from pathlib import Path
import re
import hashlib

POLICY='existing-water-snow-groundwater-calendar-composition-v1'


def selection(project):
    if not project.original_output or not project.input_directory or project.macro or project.solute or project.age:return None
    from experimental_project import inspect
    report=inspect(project.input_directory,original_output=True);s=report['selectors']
    if s['SWSNOW']!=1 or report['boundary']['SWBOTB']!=1:return None
    required=dict(SWMACRO=0,SWSOLU=0,SWSNOW=1,SWFROST=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOPHY=0)
    if any(s.get(k)!=v for k,v in required.items()) or s['SWKIMPL'] not in (0,1) or s['SWHYST'] not in (0,1,2) or s['SWDRA'] not in (0,1):
        raise ValueError('Water Snow groundwater requires bounded analytical daily thermal history')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Water Snow groundwater requires original day-seed policy')
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if len(models)>1 or models and re.fullmatch(r'1(?:[ \t]+1)*[ \t]*',models[0].strip()) is None or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',remainder):
        raise ValueError('Water Snow groundwater requires original analytical model1')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous water Snow groundwater '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if len(flags)>1 or token not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid water Snow groundwater step flag')
    step=token in ('.TRUE.','TRUE','.T.','T');npd=one('NPRINTDAY');monthly=one('SWMONTH');fmt=one('SWCSV',0)
    dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES');requested=0 if monthly else one('PERIOD')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if not 1<=npd<=1440 or monthly not in (0,1) or fmt not in (0,1,2,3) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366 or precision is not None and not 5<=precision<=12:
        raise ValueError('Invalid water Snow groundwater output domain')
    return dict(groundwater_snow_water_output=True,thermal_output=True,thermal_calendar=True,
        thermal_clock=step or npd>1,thermal_step=step,thermal_reset=step and bool(reset),kind='water',
        swsnow=1,swhea=1,swcalt=2,swfrost=0,swdra=s['SWDRA'],swhyst=s['SWHYST'],et=one('SWCFBS'),
        swkimpl=s['SWKIMPL'],swbotb=1,swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,
        requested_period=requested,period=1 if step or npd>1 else requested,flprintdt=step,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def codec(selected):
    if not selected.get('groundwater_snow_water_output'):raise ValueError('Foreign water Snow groundwater output')
    kind='R' if selected['flprintdt'] and selected['swres'] else 'P' if selected['flprintdt'] else 'C' if selected['nprintday']>1 else 'I'
    return ('S5WG'+kind+f"{selected['swkimpl']:03d}").encode()


def metadata(project,selected):
    import thermal_output_clock as water
    import snow_water_groundwater_state as state
    sha=lambda p:hashlib.sha256(Path(p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    folder=Path(__file__).parent
    return dict(policy=POLICY,native_codec=codec(selected).decode(),**selected,
        source_sha256=sha(__file__),composition_build_sha256=sha(folder/'snow_water_groundwater_build.py'),
        native_composition=state.metadata(project,selected),
        calendar_owner_sha256=sha(water.__file__),step_owner_sha256=sha(folder/'thermal_output_step.py'),
        reset_owner_sha256=sha(folder/'thermal_output_reset.py'),
        domain_source_sha256=sha(folder/(water.DOMAIN+'.f90')),
        snow_output_source_sha256=sha(folder/(water.SNOW_PROVIDER+'.f90')),
        receipt_provider_sha256=sha(water.ROOT/'src/process/mod_original_output_receipt.f90'),
        original_integral_sha256=water.regular.INTEGRAL_SHA,
        original_watstor_sha256=water.clock.WATSTOR_SHA,original_timecontrol_sha256=water.clock.TIME_SHA,
        original_output_epoch=project.start_clock,physical_equations_changed=False,trial_water_guard_cm=1e-10,
        preserves_requested_groups_and_precision=True,new_physical_state=False)
