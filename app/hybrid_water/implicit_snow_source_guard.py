"""Read-only closure to admitted numerical parents, independent of build hashes.

This establishes source composition only. Scientific and canonical admission
remain separate from these development-route source checks.
"""
import hashlib
from pathlib import Path


def validate_source(bundle,project,identity):
    from experimental_project import inspect
    from implicit_snow_composition import input_domain
    report=inspect(project.input_directory)
    output=identity['original_output'];bundle=Path(bundle)
    if (not input_domain(report['selectors'],report['boundary'],project.original_output) or
            (identity.get('implicit_conductivity') or {}).get('implicit_snow_composition') is not True or
            output.get('swsnow')!=1 or output.get('thermal_output') is not True):
        raise ValueError('Foreign implicit Snow source domain')

    from ordinary_pond_source_guard import HEADS
    source=(bundle/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
    groundwater=report['boundary']['SWBOTB']==1
    if groundwater and output.get('cde_clock_output'):
        from groundwater_cde_clock_source_guard import ADDITIONS
        for addition in ADDITIONS:
            if source.count(addition)!=1:
                raise ValueError('Foreign actual implicit Snow groundwater clock trial provider')
            source=source.replace(addition,b'',1)
        # Restore the no-Snow parent guard only for complete source comparison.
        # At runtime its same 1e-10 bound is owned by the existing Snow soil
        # clone above, with the actual Snow net forcing and groundwater delta.
        anchor=b'   use hybrid_step_budget, only: projected_water_residual'
        guard=b'         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
        if source.count(anchor)!=1 or source.count(guard)!=1:
            raise ValueError('Foreign implicit Snow parent trial guard anchors')
        source=source.replace(anchor,b'   use MOD_integral,only:hybrid_implicit_groundwater_trial\n'+anchor,1)
        source=source.replace(guard,guard+b'\n         if(abs(hybrid_implicit_groundwater_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.',1)
    form=('groundwater' if groundwater else
          ('cde' if project.solute else 'water')+('-step' if output.get('flprintdt') else ''))
    if hashlib.sha256(source).hexdigest()!=HEADS[form]:
        raise ValueError('Foreign complete implicit Snow HeadCalc parent')

    # Invert only the existing literal retry/event transforms, then verify the
    # whole previously qualified time body. Never approve a candidate SHA.
    from groundwater_snow_retry import inverse,TIME_TEMPLATE
    from implicit_conductivity_retry import time_source
    from implicit_pond_event import time_source as event
    source=inverse((bundle/'timecontrol.f90').read_text(encoding='cp1252'),
                   lambda text:event(time_source(text)),TIME_TEMPLATE)
    from groundwater_snow_clock import validate as clock_validate,PARENT_SHA,kind
    if output.get('groundwater_snow_cde_output'):
        clock_validate(source,output,output['original_output_epoch'])
    elif hashlib.sha256(source.encode('cp1252')).hexdigest()!=PARENT_SHA[kind(output)]:
        raise ValueError('Foreign complete implicit Snow TimeControl parent')

    from ordinary_implicit_pond_switch import actual_source
    actual_source((bundle/'boundtop.f90').read_bytes(),True)
    folder=Path(__file__).parent
    providers=[('implicit_pond_event_state.f90','implicit_pond_event_state.f90'),
               ('implicit_pond_availability.f90','implicit_pond_availability.f90'),
               ('original_output_thermal_domain.f90','original_output_thermal_domain.f90')]
    if output.get('cde_interval_output'):
        providers.append(('original_cde_output_state.f90','cde_interval_output_state.f90'))
    if output.get('thermal_calendar'):
        providers.append(('thermal_output_snow_calendar_state.f90','cde_interval_snow_state.f90'))
    if groundwater:
        providers.append(('groundwater_history_native_state.f90','groundwater_history_native_state.f90'))
    for actual,parent in providers:
        if (bundle/actual).read_bytes().replace(b'\r\n',b'\n')!=(folder/parent).read_bytes().replace(b'\r\n',b'\n'):
            raise ValueError('Foreign actual implicit Snow private provider: '+actual)
    body=(bundle/'macropore.f90').read_text(encoding='cp1252').split('    subroutine hybrid_macro_checkpoint(',1)[1].split('    end subroutine hybrid_macro_checkpoint',1)[0]
    if (body.count('use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event')!=1 or
            body.count('call assert_no_implicit_pond_event()')!=1):
        raise ValueError('Foreign implicit Snow pending-event native boundary')
