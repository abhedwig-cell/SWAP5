"""Read-only complete original-parent closure for undrained ordinary Snow."""
import ast
import hashlib
import inspect
from pathlib import Path
import re

from snow_undrained import selection,codec
import snow_undrained_build as build
import snow_undrained_state as state


def explicit_head_parent(reference,project):
    # Evaluate only the unchanged original renderer before its first write.
    import daily_host
    function=ast.parse(inspect.getsource(daily_host.build)).body[0]
    blocks=[n for n in function.body if isinstance(n,ast.If) and
        ast.unparse(n.test)=='trace_richards or budget_retry']
    if len(blocks)!=1:raise ValueError('Changed original explicit HeadCalc renderer')
    body=blocks[0].body
    writes=[i for i,n in enumerate(body) if isinstance(n,ast.Expr) and isinstance(n.value,ast.Call) and
        isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='write_text']
    if len(writes)!=1:raise ValueError('Changed original explicit HeadCalc write boundary')
    module=ast.fix_missing_locations(ast.Module(body=body[:writes[0]],type_ignores=[]))
    namespace={**vars(daily_host), 'project':project,'donor_build':Path(reference)/'build',
        'case':Path(project.input_directory),'trace_richards':False,'budget_retry':True,
        'strict_water':True,'shared_pond_transfer':False,'refresh_macro_final':False}
    exec(compile(module,'<original-explicit-head-read-only-prefix>','exec'),namespace)
    from lower_boundary_receipt import render_headcalc
    return render_headcalc(namespace['source'],selection(project)['swbotb'])


def checkpoint_parent(reference,selected,project):
    import donor_sources
    function=ast.parse(inspect.getsource(donor_sources.render_checkpoint)).body[0]
    writes=[i for i,n in enumerate(function.body) if isinstance(n,ast.Expr) and isinstance(n.value,ast.Call) and
        isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='write_text']
    if not writes:raise ValueError('Changed original native renderer')
    function.name='read_only_original_native'
    function.body=function.body[:writes[0]]+[ast.Return(value=ast.Name(id='macro',ctx=ast.Load()))]
    namespace=dict(vars(donor_sources));module=ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[]))
    exec(compile(module,'<original-native-read-only-prefix>','exec'),namespace)
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    pond=re.findall(r'(?mi)^[ \t]*SWPONDMX[ \t]*=[ \t]*(\d+)',text)
    if len(pond)!=1:raise ValueError('Ambiguous original pond domain')
    return namespace[function.name](Path(reference)/'build',None,None,runtime=True,nonmacro=True,
        solute_state=project.solute,hydraulic_history=bool(selected['swhyst']),thermal_history=True,
        management_state=True,plant_et_state=selected['et']==1,micro_lookup_state=True,
        scheduled_pond_history=int(pond[0])==1)


def validate_source(bundle,project,identity,reference):
    selected=selection(project);bundle=Path(bundle);folder=Path(__file__).parent
    if selected is None or identity['original_output'].get('native_codec')!=codec(selected).decode():
        raise ValueError('Foreign actual undrained Snow domain')
    def actual(name):return (bundle/name).read_text(encoding='cp1252')
    def equal(name,expected):
        if actual(name)!=expected:raise ValueError('Foreign complete undrained Snow source: '+name)
    from groundwater_snow_retry import inverse,head,time,HEAD_TEMPLATE,TIME_TEMPLATE
    source=actual('headcalc.f90')
    if not selected['swkimpl']:source=inverse(source,head,HEAD_TEMPLATE)
    template=('   use hybrid_step_budget, only: projected_water_residual\n\n   implicit none\n'
        '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.\n')
    def add(text):
        anchor='   use hybrid_step_budget, only: projected_water_residual'
        text=state.replace(text,anchor,'   use MOD_integral,only:hybrid_snow_soil_trial_residual\n'+anchor)
        return build.head_trial(text)
    source=inverse(source,add,template)
    if selected['swkimpl']:
        from ordinary_pond_source_guard import HEADS
        if selected['swbotb']==5:
            from lower_boundary_receipt import render_headcalc
            template=('logical                          :: flboth, flok\n'
                '         budget_step=projected_water_residual()\n'
                '            budget_step = projected_water_residual()\n')
            source=render_headcalc(inverse(source,lambda text:render_headcalc(text,5),template),8)
        if hashlib.sha256(source.encode('cp1252')).hexdigest()!=HEADS['water']:
            raise ValueError('Foreign qualified implicit ordinary Snow HeadCalc parent')
    elif source!=explicit_head_parent(reference,project):
        raise ValueError('Foreign unchanged original explicit Snow HeadCalc parent')

    source=actual('timecontrol.f90')
    if selected['swkimpl']:
        from implicit_conductivity_retry import time_source
        from implicit_pond_event import time_source as event
        source=inverse(source,lambda text:event(time_source(text)),TIME_TEMPLATE)
    else:source=inverse(source,time,TIME_TEMPLATE)
    originals=Path(reference)/'build/swap-selected'
    equal_time=build.timecontrol((originals/'timecontrol.f90').read_text(encoding='cp1252'),selected,project.start_clock)
    if source!=equal_time:raise ValueError('Foreign complete existing undrained Snow TimeControl')
    if selected['swkimpl']:
        from ordinary_implicit_pond_switch import actual_source
        actual_source((bundle/'boundtop.f90').read_bytes(),True)
    else:
        from groundwater_snow_retry import validate as retry_validate
        retry_validate(bundle)
    for name in ('implicit_pond_event_state.f90','implicit_pond_availability.f90',build.clock.DOMAIN+'.f90'):
        equal(name,(folder/name).read_text(encoding='cp1252'))
    snow='cde_interval_snow_state.f90' if project.solute else build.clock.SNOW_PROVIDER+'.f90'
    equal(build.clock.SNOW_PROVIDER+'.f90',(folder/snow).read_text(encoding='cp1252'))
    state.validate_source(bundle,selected)
    expected=state.macro(build.macro(checkpoint_parent(reference,selected,project),selected),selected)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    expected=expected.split(begin,1)[1].split(end,1)[0]
    anchor='      use MOD_grid, only: numnod'
    expected=state.replace(expected,anchor,'      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'+anchor)
    dispatch=re.findall(r'(?m)^([ \t]*)if \(restoring\) then$',expected)
    if len(dispatch)!=1:raise ValueError('Changed original native dispatch')
    anchor=dispatch[0]+'if (restoring) then'
    expected=state.replace(expected,anchor,dispatch[0]+'call assert_no_implicit_pond_event()\n'+anchor)
    if not selected['swkimpl']:
        # The explicit retry owner runs before the native root owner. The
        # implicit retry owner runs after it; retain each actual import order.
        root='      use hybrid_snow_undrained_root_state,only:snow_undrained_root_checkpoint\n'
        event='      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'
        expected=state.replace(expected,root+event,event+root)
    body=actual('macropore.f90').split(begin,1)[1].split(end,1)[0]
    if body!=expected:raise ValueError('Foreign complete original undrained Snow checkpoint procedure')
    raw=(originals/'integral.f90').read_text(encoding='cp1252');stock=(originals/'watstor.f90').read_text(encoding='cp1252')
    equal('integral.f90',build.integral(raw,stock,selected))
    equal('hybrid_age_output_state.f90',build.clock.state_source(project))
    if project.solute:
        import cde_interval_output as interval
        import cde_clock_output as clock
        observer=clock if selected['flprintdt'] or selected['nprintday']>1 else interval
        equal('age_output_calendar_probe.f90',observer.probe_source(project,selected))
        equal('original_cde_output_state.f90',(folder/'cde_interval_output_state.f90').read_text(encoding='cp1252'))
        equal('cde_interval_receipt.f90',(folder/'cde_interval_receipt.f90').read_text(encoding='cp1252'))
        if selected['flprintdt'] or selected['nprintday']>1:equal('cde_clock_events.f90',(folder/'cde_clock_events.f90').read_text(encoding='cp1252'))
    else:equal('age_output_calendar_probe.f90',build.clock.probe_source(project))


LEGACY_COMPOSITION_SHA='49bf3e229919b6782781cb899092ef845f462bad90118f0ba61ef18246e18087'

def unchanged_implicit_metadata(old,expected,project):
    if not isinstance(old,dict) or not isinstance(expected,dict) or selection(project) is not None:return False
    key='implicit_snow_composition_source_sha256'
    if old.get(key)!=LEGACY_COMPOSITION_SHA:return False
    source=Path(__file__).with_name('implicit_snow_composition.py').read_text(encoding='utf-8')
    current='bottom in (1,5,8) and drain in (0,1))'
    original='bottom in (1,5,8) and drain in (0,1) and (bottom==1 or drain==1))'
    if source.count(current)!=1:return False
    parent=source.replace(current,original,1)
    if hashlib.sha256(parent.encode()).hexdigest()!=LEGACY_COMPOSITION_SHA:return False
    actual=hashlib.sha256(source.encode()).hexdigest()
    return expected.get(key)==actual and {**old,key:actual}==expected
