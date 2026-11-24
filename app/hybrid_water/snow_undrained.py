"""Bounded ordinary Snow drainage-off domain; integration not yet admitted."""
from pathlib import Path
import re
import hashlib

POLICY='existing-ordinary-snow-drainage-off-composition-v1'


def selection(project):
    if not project.original_output or not project.input_directory or project.macro or project.age:return None
    from experimental_project import inspect
    report=inspect(project.input_directory,original_output=True);s=report['selectors']
    if s['SWSNOW']!=1 or s['SWDRA']!=0 or report['boundary']['SWBOTB'] not in (5,8,9):return None
    if report['boundary']['SWBOTB']==9:
        from prescribed_snow_boundary import enabled
        if not enabled(project):return None
    required=dict(SWMACRO=0,SWSOLU=int(project.solute),SWSNOW=1,SWFROST=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOPHY=0)
    if any(s.get(k)!=v for k,v in required.items()) or s['SWKIMPL'] not in (0,1) or s['SWHYST'] not in (0,1,2) or s['SWDRA']!=0:
        raise ValueError('Ordinary Snow drainage-off requires bounded analytical daily thermal history')
    if project.time_step_policy!='original-adaptive-day-seed-v1':raise ValueError('Ordinary Snow drainage-off requires original day-seed policy')
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if len(models)>1 or models and re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0].strip()) is None or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',remainder):
        # New paired9 analytical composition stays explicit with hysteresis0.
        # The actual paired Snow selector above already validated every model.
        if report['boundary']['SWBOTB']!=9 or s['SWKIMPL']!=0 or s['SWHYST']!=0:
            raise ValueError('Ordinary Snow drainage-off requires original analytical model1 or bounded explicit paired analytical Snow')
    def one(key,default=None,quoted=False):
        pattern=r"'[^']*'" if quoted else r'[+-]?\d+'
        values=re.findall(r'(?mi)^[ \t]*'+key+r'[ \t]*=[ \t]*('+pattern+r')[ \t]*(?:!.*)?$',text)
        if not values and default is not None:return default
        if len(values)!=1:raise ValueError('Missing/ambiguous ordinary Snow drainage-off '+key)
        return values[0][1:-1] if quoted else int(values[0])
    flags=re.findall(r'(?mi)^[ \t]*FLPRINTDT[ \t]*=[ \t]*([^!\r\n]+)',text)
    token=flags[0].strip().upper() if flags else '.FALSE.'
    if len(flags)>1 or token not in ('.TRUE.','TRUE','.T.','T','.FALSE.','FALSE','.F.','F'):raise ValueError('Invalid ordinary Snow drainage-off step flag')
    step=token in ('.TRUE.','TRUE','.T.','T');npd=one('NPRINTDAY');monthly=one('SWMONTH');fmt=one('SWCSV',0)
    dates=0 if monthly else one('SWODAT');reset=0 if monthly else one('SWRES');requested=0 if monthly else one('PERIOD')
    precision=one('NUM_DECIMALS',5) if fmt else None
    if not 1<=npd<=1440 or monthly not in (0,1) or fmt not in (0,1,2,3) or dates not in (0,1) or reset not in (0,1) or not 0<=requested<=366 or precision is not None and not 5<=precision<=12:
        raise ValueError('Invalid ordinary Snow drainage-off output domain')
    analytical={}
    if report['boundary']['SWBOTB']==9 and s['SWKIMPL']==s['SWHYST']==0:
        from model7_capacity import analytical_models
        layer_models=analytical_models(project)
        if layer_models and any(value!=1 for value in layer_models):
            analytical={'analytical_snow_models':list(layer_models)}
    return dict(**analytical,**({'paired_snow_boundary':True} if report['boundary']['SWBOTB']==9 else {}),**({'cde_interval_output':True,'cde_clock_output':npd>1 or step} if project.solute else {}),ordinary_snow_undrained_output=True,thermal_output=True,thermal_calendar=True,
        thermal_clock=step or npd>1,thermal_step=step,thermal_reset=step and bool(reset),kind='cde' if project.solute else 'water',
        swsnow=1,swhea=1,swcalt=2,swfrost=0,swdra=s['SWDRA'],swhyst=s['SWHYST'],et=one('SWCFBS'),
        swkimpl=s['SWKIMPL'],swbotb=report['boundary']['SWBOTB'],swcsv=fmt,nprintday=npd,swmonth=monthly,swodat=dates,swres=reset,
        requested_period=requested,period=1 if step or npd>1 else requested,flprintdt=step,
        groups=one('INLIST_CSV',quoted=True) if fmt else None,num_decimals=precision)


def codec(selected):
    if not selected.get('ordinary_snow_undrained_output'):raise ValueError('Foreign ordinary Snow drainage-off output')
    kind='R' if selected['flprintdt'] and selected['swres'] else 'P' if selected['flprintdt'] else 'C' if selected['nprintday']>1 else 'I'
    domain='A' if selected.get('analytical_snow_models') else 'U'
    return ('S5'+domain+('C' if selected['kind']=='cde' else 'W')+kind+f"{selected['swkimpl']:03d}").encode()


def metadata(project,selected):
    import thermal_output_clock as water
    folder=Path(__file__).parent
    sha=lambda p:hashlib.sha256(Path(p).read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    providers=['snow_undrained.py','snow_undrained_build.py','snow_undrained_state.py',
        'thermal_output_clock.py','thermal_output_step.py','thermal_output_reset.py',
        'implicit_snow_root_state.f90','original_output_thermal_domain.f90','thermal_output_snow_calendar_state.f90']
    if selected.get('analytical_snow_models'):providers.append('snow_analytical_native.f90')
    if project.solute:providers+=['cde_clock_output.py','cde_interval_output.py','cde_interval_source.py',
        'cde_interval_output_state.f90','cde_interval_snow_state.f90','cde_interval_receipt.f90','cde_clock_events.f90']
    if not selected['swkimpl']:providers.append('implicit_interception_partition.py')
    if project.solute:providers.append('snow_undrained_cde_positive.py')
    if selected['swbotb']==9:providers+=['prescribed_snow_boundary.py','prescribed_head_flux_boundary.py']
    return dict(policy=POLICY,native_codec=codec(selected).decode(),**selected,
        providers={name:sha(folder/name) for name in providers},
        original_output_epoch=project.start_clock,physical_equations_changed=False,new_physical_state=False,
        trial_water_guard_cm=1e-10,preserves_requested_groups_and_precision=True,
        undefined_allocation_tails_serialized=False,native_domain_bytes=80,native_root_bytes=96,
        original_integral_sha256=water.regular.INTEGRAL_SHA,
        original_watstor_sha256=water.clock.WATSTOR_SHA,original_timecontrol_sha256=water.clock.TIME_SHA)

