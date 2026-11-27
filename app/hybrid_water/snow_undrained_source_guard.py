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
    # Paired Snow uses this exact original HeadCalc prefix. Its existing Snow
    # rollback/pond-event owner is checked separately by the complete inverse.
    if selection(project)['swbotb'] in (6,9):return namespace['source']
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


def solute_parent(reference,project):
    """Read the unchanged original CDE renderer up to its first file write."""
    import daily_host
    from conserved_subsurface_solute import enabled as fixed,correction
    from conserved_scheduled_subsurface_solute import enabled as scheduled
    from conserved_aquifer_solute import enabled as aquifer,correction as aquifer_correction
    function=ast.parse(inspect.getsource(daily_host.build)).body[0]
    blocks=[n for n in function.body if isinstance(n,ast.If) and ast.unparse(n.test)=='project.solute'
        and 'module subroutine hybrid_solute_checkpoint' in ast.unparse(n)]
    if len(blocks)!=1:raise ValueError('Changed original CDE renderer')
    body=blocks[0].body
    writes=[i for i,n in enumerate(body) if isinstance(n,ast.Expr) and isinstance(n.value,ast.Call) and
        isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='write_text']
    if len(writes)!=1:raise ValueError('Changed original CDE write boundary')
    namespace={**vars(daily_host),'project':project,'donor_build':Path(reference)/'build',
        'chemical_source':fixed(project) or scheduled(project),'chemical_correction':correction,
        'aquifer_source':aquifer(project),'aquifer_correction':aquifer_correction}
    module=ast.fix_missing_locations(ast.Module(body=body[:writes[0]],type_ignores=[]))
    exec(compile(module,'<original-cde-read-only-prefix>','exec'),namespace)
    from cde_interval_source import source
    from snow_undrained_cde_positive import source as preserve_positive
    return preserve_positive(source(namespace['source']))


def validate_source(bundle,project,identity,reference):
    selected=selection(project);bundle=Path(bundle);folder=Path(__file__).parent
    if selected is None or identity['original_output'].get('native_codec')!=codec(selected).decode():
        raise ValueError('Foreign actual undrained Snow domain')
    def actual(name):
        if not (bundle/name).is_file():raise ValueError('Missing actual undrained Snow source: '+name)
        return (bundle/name).read_text(encoding='cp1252')
    def equal(name,expected):
        if actual(name)!=expected:raise ValueError('Foreign complete undrained Snow source: '+name)
    from groundwater_snow_retry import inverse,head,time,HEAD_TEMPLATE,TIME_TEMPLATE
    from implicit_interception_partition import source as exact_partition
    original_meteo=(Path(reference)/'build/swap-selected/MOD_meteo.f90').read_text(encoding='cp1252')
    equal('MOD_meteo.f90',exact_partition(original_meteo))
    from implicit_closed_desaturation import restore as restore_desaturation
    source=restore_desaturation(actual('headcalc.f90'))
    if not selected['swkimpl']:source=inverse(source,head,HEAD_TEMPLATE)
    template=('   use hybrid_step_budget, only: projected_water_residual\n\n   implicit none\n'
        '         if (abs(budget_total+budget_step)>1d-10*(t1900-budget_start+dt)) flnonconv=.true.\n')
    def add(text):
        anchor='   use hybrid_step_budget, only: projected_water_residual'
        text=state.replace(text,anchor,'   use MOD_integral,only:hybrid_snow_soil_trial_residual\n'+anchor)
        return build.head_trial(text,selected)
    source=inverse(source,add,template)
    if selected['swkimpl']:
        from ordinary_pond_source_guard import HEADS
        if selected['swbotb']==5:
            from lower_boundary_receipt import render_headcalc
            template=('logical                          :: flboth, flok\n'
                '         budget_step=projected_water_residual()\n'
                '            budget_step = projected_water_residual()\n')
            source=render_headcalc(inverse(source,lambda text:render_headcalc(text,5),template),8)
        elif selected['swbotb']==6:
            from lower_boundary_receipt import render_headcalc
            source=render_headcalc(source,8)
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
    from implicit_hydraulic_state import restore_macro
    parent_macro=restore_macro(actual('macropore.f90'),project)
    body=parent_macro.split(begin,1)[1].split(end,1)[0]
    if body!=expected:raise ValueError('Foreign complete original undrained Snow checkpoint procedure')
    raw=(originals/'integral.f90').read_text(encoding='cp1252');stock=(originals/'watstor.f90').read_text(encoding='cp1252')
    equal('integral.f90',build.integral(raw,stock,selected))
    equal('hybrid_age_output_state.f90',build.clock.state_source(project))
    equal('age_output_calendar_probe.f90',build.probe(project,selected))
    if project.solute:
        equal('solute.f90',solute_parent(reference,project))
        equal('original_cde_output_state.f90',(folder/'cde_interval_output_state.f90').read_text(encoding='cp1252'))
        equal('cde_interval_receipt.f90',(folder/'cde_interval_receipt.f90').read_text(encoding='cp1252'))
        if selected['flprintdt'] or selected['nprintday']>1:equal('cde_clock_events.f90',(folder/'cde_clock_events.f90').read_text(encoding='cp1252'))


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


LEGACY_EXPLICIT_ROOT_WRAPPER_SHA='a57890f73cce435f4ed8257051b32219dfd5d85516ddfbb6f0e685cb6e934da2'


def unchanged_explicit_root_metadata(old,expected,project):
    selected=selection(project)
    if selected is None or selected['swkimpl'] or not isinstance(old,dict) or not isinstance(expected,dict):return False
    name='snow_undrained_state.py'
    if old.get('providers',{}).get(name)!=LEGACY_EXPLICIT_ROOT_WRAPPER_SHA:return False
    source=Path(state.__file__).read_text(encoding='utf-8')
    actual=inspect.getsource(state.native_build)
    prefix="    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')\n"
    tail="    path.write_text(macro(text,selected),encoding='cp1252')\n"
    start=actual.find(prefix);end=actual.find(tail)
    if start<0 or end<start:return False
    replacement="    path=output/'macropore.f90';path.write_text(macro(path.read_text(encoding='cp1252'),selected),encoding='cp1252')\n"
    original=actual[:start]+replacement+actual[end+len(tail):]
    if source.count(actual)!=1:return False
    parent=source.replace(actual,original,1)
    if hashlib.sha256(parent.encode()).hexdigest()!=LEGACY_EXPLICIT_ROOT_WRAPPER_SHA:return False
    current=hashlib.sha256(source.encode()).hexdigest()
    if expected.get('providers',{}).get(name)!=current:return False
    return {**old,'providers':{**old['providers'],name:current}}==expected


LEGACY_BUILD_SHA='53fca12f508800d5c57b9727b05d7fbeab71b229d4b5cb0d6b1fc082abedb0d1'
LEGACY_PROBE_CALLSITE="    if project.solute:\n        import cde_clock_output as cclock\n        import cde_interval_output as interval\n        probe=(cclock if selected['flprintdt'] or selected['nprintday']>1 else interval).probe_source(project,selected)\n    else:probe=clock.probe_source(project)\n    (output/'age_output_calendar_probe.f90').write_text(probe,encoding='cp1252')\n"
CURRENT_PROBE_CALLSITE="    (output/'age_output_calendar_probe.f90').write_text(probe(project,selected),encoding='cp1252')\n"


def unchanged_output_metadata(old,expected,project):
    selected=selection(project)
    if selected is None or selected['kind']!='water' or not isinstance(old,dict) or not isinstance(expected,dict):return False
    projected={**old,'providers':dict(old.get('providers',{}))}
    name='snow_undrained_build.py'
    if projected['providers'].get(name)!=expected.get('providers',{}).get(name):
        source=Path(build.__file__).read_text(encoding='utf-8')
        if source.count(POSITIVE_BUILD_NEW)!=1:return False
        source=source.replace(POSITIVE_BUILD_NEW,POSITIVE_BUILD_OLD,1)
        old_sha=projected['providers'].get(name)
        if old_sha==PRE_POSITIVE_BUILD_SHA:
            if hashlib.sha256(source.encode()).hexdigest()!=PRE_POSITIVE_BUILD_SHA:return False
            projected['providers'][name]=expected['providers'][name]
        else:
            if not selected['swkimpl'] or old_sha!=LEGACY_BUILD_SHA:return False
            if not legacy_build_parent(source):return False
            projected['providers'][name]=expected['providers'][name]
        current=hashlib.sha256(Path(build.__file__).read_text(encoding='utf-8').encode()).hexdigest()
        if expected.get('providers',{}).get(name)!=current:return False
    domain='snow_undrained.py'
    if projected['providers'].get(domain)!=expected.get('providers',{}).get(domain):
        current_source=Path(__file__).with_name(domain).read_text(encoding='utf-8')
        if current_source.count(POSITIVE_METADATA)!=1:return False
        parent=current_source.replace(POSITIVE_METADATA,'',1)
        old_sha=projected['providers'].get(domain)
        if old_sha==PRE_POSITIVE_DOMAIN_SHA:
            if hashlib.sha256(parent.encode()).hexdigest()!=PRE_POSITIVE_DOMAIN_SHA:return False
        else:
            if not selected['swkimpl'] or old_sha!=LEGACY_DOMAIN_SHA or parent.count(EXPLICIT_PARTITION_METADATA)!=1:return False
            if hashlib.sha256(parent.replace(EXPLICIT_PARTITION_METADATA,'',1).encode()).hexdigest()!=LEGACY_DOMAIN_SHA:return False
        current=hashlib.sha256(current_source.encode()).hexdigest()
        if expected.get('providers',{}).get(domain)!=current:return False
        projected['providers'][domain]=current
    return projected==expected


def legacy_build_parent(source):
        if source.count(EXPLICIT_PARTITION_BLOCK)!=1:return False
        source=source.replace(EXPLICIT_PARTITION_BLOCK,'',1)
        tree=ast.parse(source);last=tree.body[-1]
        if not isinstance(last,ast.FunctionDef) or last.name!='probe' or last.decorator_list:return False
        lines=source.splitlines(keepends=True)
        if lines[last.lineno-1]!='def probe(project,selected):\n':return False
        prefix=''.join(lines[:last.lineno-1])
        if not prefix.endswith('\n\n') or prefix.count(CURRENT_PROBE_CALLSITE)!=1:return False
        parent=prefix[:-2].replace(CURRENT_PROBE_CALLSITE,LEGACY_PROBE_CALLSITE,1)
        if hashlib.sha256(parent.encode()).hexdigest()!=LEGACY_BUILD_SHA:return False
        return True


EXPLICIT_PARTITION_BLOCK="        from implicit_interception_partition import source as exact_partition\n        meteo=output/'MOD_meteo.f90'\n        parent=(meteo if meteo.exists() else originals/'MOD_meteo.f90').read_text(encoding='cp1252')\n        meteo.write_text(exact_partition(parent),encoding='cp1252')\n        patched=['MOD_meteo',*(name for name in patched if name!='MOD_meteo')]\n"
EXPLICIT_PARTITION_METADATA="    if not selected['swkimpl']:providers.append('implicit_interception_partition.py')\n"
LEGACY_DOMAIN_SHA='73525f3852d99a383bfa12c8cd3f50e2ee9e54a1a863de353757fbbd76480a9e'
PRE_POSITIVE_BUILD_SHA='410d179b577c2499447bfd98bd3b305617733178a989137156e65604dcfac861'
PRE_POSITIVE_DOMAIN_SHA='72830a2b4332b8e5c42e5f668e9c68245db45bdf192e411d0a1da93d184a4dfa'
POSITIVE_BUILD_OLD="        path=output/'solute.f90';path.write_text(bridge.source(path.read_text(encoding='cp1252')),encoding='cp1252')\n"
POSITIVE_BUILD_NEW="        from snow_undrained_cde_positive import source as preserve_positive\n        path=output/'solute.f90';path.write_text(preserve_positive(bridge.source(path.read_text(encoding='cp1252'))),encoding='cp1252')\n"
POSITIVE_METADATA="    if project.solute:providers.append('snow_undrained_cde_positive.py')\n"
