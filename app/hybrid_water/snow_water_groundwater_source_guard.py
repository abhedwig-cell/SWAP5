"""Read-only source closure for the actual water Snow groundwater composition."""
import hashlib
from pathlib import Path

from snow_water_groundwater import selection,codec
import snow_water_groundwater_build as build
import snow_water_groundwater_state as native

EXPLICIT_HEAD='241d188e6c71b7a55bc02768cfc76bb554617b1c7ffc953d73d299a07c911e1f'
IMPLICIT_HEAD='a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9'


def validate_source(bundle,project,identity,reference):
    selected=selection(project);bundle=Path(bundle);folder=Path(__file__).parent
    if selected is None or identity['original_output'].get('native_codec')!=codec(selected).decode():
        raise ValueError('Foreign water Snow groundwater source domain')
    def actual(name):return (bundle/name).read_text(encoding='cp1252')
    def equal(name,expected):
        if actual(name)!=expected:raise ValueError('Foreign actual water Snow groundwater source: '+name)
    from groundwater_snow_retry import inverse,head,time,HEAD_TEMPLATE,TIME_TEMPLATE
    source=actual('headcalc.f90')
    if not selected['swkimpl']:source=inverse(source,head,HEAD_TEMPLATE)
    if hashlib.sha256(source.encode('cp1252')).hexdigest()!=(IMPLICIT_HEAD if selected['swkimpl'] else EXPLICIT_HEAD):
        raise ValueError('Foreign complete qualified water Snow groundwater HeadCalc parent')
    source=actual('timecontrol.f90')
    if selected['swkimpl']:
        from implicit_conductivity_retry import time_source
        from implicit_pond_event import time_source as event
        source=inverse(source,lambda text:event(time_source(text)),TIME_TEMPLATE)
    else:source=inverse(source,time,TIME_TEMPLATE)
    epoch=build.epoch;addition=epoch.declaration(project.start_clock)
    source=native.replace(source,addition,'');source=native.replace(source,epoch.NEW,epoch.OLD)
    kind='step' if selected['flprintdt'] else 'clock' if selected['nprintday']>1 else 'interval'
    if hashlib.sha256(source.encode('cp1252')).hexdigest()!=build.WATER_TIME[kind]:
        raise ValueError('Foreign complete qualified water Snow groundwater TimeControl parent')
    if selected['swkimpl']:
        from ordinary_implicit_pond_switch import actual_source
        actual_source((bundle/'boundtop.f90').read_bytes(),True)
    else:
        from groundwater_snow_retry import validate as retry_validate
        retry_validate(bundle)
    for name in ('implicit_pond_event_state.f90','implicit_pond_availability.f90',build.clock.DOMAIN+'.f90',build.clock.SNOW_PROVIDER+'.f90'):
        equal(name,(folder/name).read_text(encoding='cp1252'))
    hydraulic=native.state_source(selected['swkimpl']);root=native.root_source(selected['swkimpl'])
    equal(native.STATE+'.f90',hydraulic);equal(native.ROOT_STATE+'.f90',root)
    if not actual('macropore.f90').startswith(hydraulic+'\n'+root+'\n'):
        raise ValueError('Actual water Snow native providers absent from compiled module unit')
    body=actual('macropore.f90').split('    subroutine hybrid_macro_checkpoint(',1)[1].split('    end subroutine hybrid_macro_checkpoint',1)[0]
    for token in ('use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event','call assert_no_implicit_pond_event()',
        'use hybrid_snow_water_groundwater_native_state,only:snow_water_groundwater_native_checkpoint',
        'use hybrid_snow_water_groundwater_root_state,only:snow_water_groundwater_root_checkpoint'):
        if body.count(token)!=1:raise ValueError('Foreign actual water Snow native checkpoint dispatch')
    for restoring in ('.true.','.false.'):
        for token in (f'call snow_water_groundwater_native_checkpoint(unit,{restoring})',
            f'call snow_water_groundwater_root_checkpoint(unit,{restoring},clock)'):
            if body.count(token)!=1:raise ValueError('Foreign actual water Snow native carry placement')
    originals=Path(reference)/'build/swap-selected'
    equal('integral.f90',build.integral((originals/'integral.f90').read_text(encoding='cp1252'),
        (originals/'watstor.f90').read_text(encoding='cp1252'),selected))
    equal('hybrid_age_output_state.f90',build.clock.state_source(project))
    equal('age_output_calendar_probe.f90',build.clock.probe_source(project))
