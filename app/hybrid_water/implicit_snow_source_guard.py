"""Read-only closure to admitted numerical parents, independent of build hashes.

This establishes source composition only. Scientific and canonical admission
remain separate from these development-route source checks.
"""
import hashlib
from pathlib import Path

# Complete old water TimeControl renderings at canonical f870, from original
# 88b3... (thermal_output_clock/step). These precede implicit Snow development.
WATER_TIME={'clock':'75bf57289000cc1ae4ed411b505bc072c469f355823b272ba8655883d6d11e63',
            'step':'fa2f3581b7ad6552a707ae88d84bd5ddb03aa1fdc75ab0925842a261d94536e3'}


def strip_clock_trial(source,cde):
    declaration=('   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\n' if cde else
                 '   real(8)::hybrid_snow_trial_guard\n')
    guard=('''
         if(swbotb==8.and..not.flboth)then
            hybrid_cde_clock_candidate_bottom=0d0
         else
            hybrid_cde_clock_candidate_bottom=-kmean(NN+1)*hgrad(NN+1)
         end if
         hybrid_cde_clock_trial_guard=hybrid_snow_soil_trial_residual(hybrid_cde_clock_candidate_bottom)
         if(abs(hybrid_cde_clock_trial_guard)>1d-10)flnonconv=.true.''' if cde else '''
         if(swbotb==8.and..not.flboth)then
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(0d0)
         else
            hybrid_snow_trial_guard=hybrid_snow_soil_trial_residual(-kmean(NN+1)*hgrad(NN+1))
         end if
         if(abs(hybrid_snow_trial_guard)>1d-10)flnonconv=.true.''')
    for part in ('   use MOD_integral,only:hybrid_snow_soil_trial_residual\n',declaration,guard):
        raw=part.encode('cp1252')
        if source.count(raw)!=1:raise ValueError('Foreign actual implicit Snow soil clock trial provider')
        source=source.replace(raw,b'',1)
    return source


def validate_source(bundle,project,identity,reference):
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
        anchor=b'   use hybrid_implicit_pond_event_state,only:request_implicit_pond_event,assert_no_implicit_pond_event'
        guard=b'         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.'
        if source.count(anchor)!=1 or source.count(guard)!=1:
            raise ValueError('Foreign implicit Snow parent trial guard anchors')
        source=source.replace(anchor,b'   use MOD_integral,only:hybrid_implicit_groundwater_trial\n'+anchor,1)
        source=source.replace(guard,guard+b'\n         if(abs(hybrid_implicit_groundwater_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.',1)
    if not groundwater:
        if output.get('thermal_clock'):source=strip_clock_trial(source,bool(project.solute))
        if report['boundary']['SWBOTB']==5:
            from groundwater_snow_retry import inverse
            from lower_boundary_receipt import render_headcalc
            template=('logical                          :: flboth, flok\n'
                      '         budget_step=projected_water_residual()\n'
                      '            budget_step = projected_water_residual()\n')
            source=render_headcalc(inverse(source.decode('cp1252'),
                lambda text:render_headcalc(text,5),template),8).encode('cp1252')
    form='groundwater' if groundwater else 'water'
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
    elif hashlib.sha256(source.encode('cp1252')).hexdigest()!=(
            WATER_TIME['step' if output.get('flprintdt') else 'clock']
            if output.get('thermal_clock') and not project.solute else PARENT_SHA[kind(output)]):
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
        providers.append(('thermal_output_snow_calendar_state.f90',
            'cde_interval_snow_state.f90' if output.get('cde_interval_output') else 'thermal_output_snow_calendar_state.f90'))
    if groundwater:
        providers.append(('groundwater_history_native_state.f90','groundwater_history_native_state.f90'))
    for actual,parent in providers:
        if (bundle/actual).read_bytes().replace(b'\r\n',b'\n')!=(folder/parent).read_bytes().replace(b'\r\n',b'\n'):
            raise ValueError('Foreign actual implicit Snow private provider: '+actual)
    body=(bundle/'macropore.f90').read_text(encoding='cp1252').split('    subroutine hybrid_macro_checkpoint(',1)[1].split('    end subroutine hybrid_macro_checkpoint',1)[0]
    if (body.count('use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event')!=1 or
            body.count('call assert_no_implicit_pond_event()')!=1):
        raise ValueError('Foreign implicit Snow pending-event native boundary')

    original=Path(reference)/'build/swap-selected'
    raw=(original/'integral.f90').read_text(encoding='cp1252')
    stock=(original/'watstor.f90').read_text(encoding='cp1252')
    import original_output_thermal as thermal
    if output.get('cde_clock_output'):
        from cde_clock_output import render_integral
        expected=render_integral(raw,stock,output)
    elif output.get('cde_interval_output'):
        if groundwater:
            from implicit_snow_interval import integral
            expected=integral(raw,stock,output)
        else:
            from cde_interval_output import render_integral
            expected=render_integral(raw,output)
    elif output.get('thermal_clock'):
        if output.get('thermal_reset'):
            from thermal_output_reset import render_integral
        elif output.get('flprintdt'):
            from thermal_output_step import render_integral
        else:
            from thermal_output_clock import render_integral
        expected=render_integral(raw,stock,output)
    else:expected=thermal.render_integral(raw,None,output)
    if (bundle/'integral.f90').read_text(encoding='cp1252')!=expected:
        raise ValueError('Foreign complete implicit Snow original integral/soil projection')
