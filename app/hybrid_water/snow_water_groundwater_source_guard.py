"""Read-only source closure for the actual water Snow groundwater composition."""
import hashlib
import ast
import inspect
import re
from pathlib import Path

from snow_water_groundwater import selection,codec
import snow_water_groundwater_build as build
import snow_water_groundwater_state as native

# Complete LF body from the admitted explicit water groundwater archive;
# its original Windows CRLF byte hash is241d188e6c71b7a55bc02768cfc76bb554617b1c7ffc953d73d299a07c911e1f.
EXPLICIT_HEAD='adce2758bbc73472579278696924b93188c2d6d6ec02c54f7ec297b23a35896a'
IMPLICIT_HEAD='a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9'
LEGACY_BUILD_SHA='43d7c069e8564f37f790b409aed1797d3fd8df6e43c0bfac005a3ff8e20dee0b'


def unchanged_clock_metadata(old,expected,project):
    """Keep original producer metadata only after exact unchanged-context proof."""
    if not isinstance(old,dict) or not isinstance(expected,dict) or not expected.get('groundwater_snow_water_output'):return False
    selected=selection(project)
    if selected is None or not (selected['flprintdt'] or selected['nprintday']>1):return False
    if old.get('composition_build_sha256')!=LEGACY_BUILD_SHA:return False
    source=Path(build.__file__).read_text(encoding='utf-8');tree=ast.parse(source);last=tree.body[-1]
    if not isinstance(last,ast.FunctionDef) or last.name!='complete_day' or last.decorator_list or last.returns or last.args.defaults:return False
    if len(last.args.args)!=1 or last.args.args[0].arg!='source' or last.args.args[0].annotation:return False
    lines=source.splitlines(keepends=True)
    if lines[last.lineno-1]!='def complete_day(source):\n':return False
    prefix=''.join(lines[:last.lineno-1])
    call="    if kind=='interval':\n        result=complete_day(result)\n"
    if not prefix.endswith('\n\n') or prefix.count(call)!=1:return False
    parent=prefix[:-2].replace(call,'',1)
    if hashlib.sha256(parent.encode('utf-8')).hexdigest()!=LEGACY_BUILD_SHA:return False
    require_current=hashlib.sha256(source.encode('utf-8')).hexdigest()
    if expected.get('composition_build_sha256')!=require_current:return False
    projected={**old,'composition_build_sha256':require_current}
    return projected==expected


def checkpoint_parent(reference,selected,project):
    # Execute only the original pure prefix ending before its first write.
    # The original compiler renderer is unchanged; no files are generated here.
    import donor_sources
    function=ast.parse(inspect.getsource(donor_sources.render_checkpoint)).body[0]
    writes=[i for i,n in enumerate(function.body) if isinstance(n,ast.Expr) and isinstance(n.value,ast.Call) and
        isinstance(n.value.func,ast.Attribute) and n.value.func.attr=='write_text']
    if not writes:raise ValueError('Changed original native checkpoint renderer')
    stop=writes[0];function.name='read_only_original_native'
    function.body=function.body[:stop]+[ast.Return(value=ast.Name(id='macro',ctx=ast.Load()))]
    module=ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[]));namespace=dict(vars(donor_sources))
    exec(compile(module,'<unchanged-original-native-pure-prefix>','exec'),namespace)
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    pond=re.findall(r'(?mi)^[ \t]*SWPONDMX[ \t]*=[ \t]*(\d+)',text)
    if len(pond)!=1:raise ValueError('Ambiguous water Snow pond history domain')
    return namespace[function.name](Path(reference)/'build',None,None,runtime=True,nonmacro=True,
        hydraulic_history=bool(selected['swhyst']),thermal_history=True,management_state=True,
        plant_et_state=selected['et']==1,micro_lookup_state=True,scheduled_pond_history=int(pond[0])==1)


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
    if not selected['flprintdt'] and selected['nprintday']==1:
        patch="""      if(tcum<1d0.and.dt>0d0)then
         if(abs(dt-(1d0-tcum))<=dtCrit)dt=1d0-tcum
      end if

"""
        source=native.replace(source,patch,'')
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
    expected=build.macro(checkpoint_parent(reference,selected,project),selected)
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    expected=expected.split(begin,1)[1].split(end,1)[0]
    anchor='      use MOD_grid, only: numnod'
    expected=native.replace(expected,anchor,'      use hybrid_implicit_pond_event_state,only:assert_no_implicit_pond_event\n'+anchor)
    dispatch=re.findall(r'(?m)^([ \t]*)if \(restoring\) then$',expected)
    if len(dispatch)!=1:raise ValueError('Changed original native dispatch')
    anchor=dispatch[0]+'if (restoring) then'
    expected=native.replace(expected,anchor,dispatch[0]+'call assert_no_implicit_pond_event()\n'+anchor)
    if body!=expected:raise ValueError('Foreign complete original water Snow groundwater checkpoint procedure')
    equal('integral.f90',build.integral((originals/'integral.f90').read_text(encoding='cp1252'),
        (originals/'watstor.f90').read_text(encoding='cp1252'),selected))
    equal('hybrid_age_output_state.f90',build.clock.state_source(project))
    equal('age_output_calendar_probe.f90',build.clock.probe_source(project))
