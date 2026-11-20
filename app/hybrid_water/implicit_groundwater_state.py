"""Typed water groundwater carry, with distinct explicit/implicit domains."""
import hashlib
import math
from pathlib import Path
import re
import struct
import age_groundwater_output as prior

STATE='implicit_groundwater_native_state'
POLICY='original-implicit-water-groundwater-complete-hydraulic-carry-v1'


def snow_selection(project):
    from snow_water_groundwater import selection
    return selection(project)


def enabled(project):
    if snow_selection(project) is not None:return True
    if not project.input_directory or project.macro or project.solute or project.age or not project.original_output:return False
    from experimental_project import inspect
    report=inspect(project.input_directory)
    s=report['selectors']
    if report['boundary']['SWBOTB']!=1:return False
    if s['SWKIMPL']==1:return True
    text=(Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252')
    active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
    models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
    remainder=re.sub(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[^\r\n]*','',active)
    if (len(models)>1 or models and re.fullmatch(r'1(?:[ \t]+1)*[ \t]*',models[0].strip()) is None
            or re.search(r'(?i)\b(?:IHWCKMODEL|SWAP_SOILS_DB)\b',remainder)):return False
    required=dict(SWMACRO=0,SWSOLU=0,SWSNOW=0,SWFROST=0,SWHEA=1,SWCALT=2,SWBR=0,SWMETDETAIL=0,SWSOPHY=0)
    return (s['SWKIMPL']==0 and all(s.get(k)==v for k,v in required.items())
            and s['SWHYST'] in (0,1,2) and s['SWDRA'] in (0,1))


def numerical_selector(project):
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWKIMPL']


def domain(project):
    selected=snow_selection(project)
    if selected is not None:
        from snow_water_groundwater_state import domain as snow_domain
        return snow_domain(project,selected)
    from experimental_project import inspect
    s=inspect(project.input_directory)['selectors']
    return [4 if s['SWKIMPL'] else 5,project.nodes,0,0,1,s['SWHYST'],0,0,1,2,s['SWDRA'],s['SWCFBS'],s['SWKIMPL']]


def magic(project):
    selected=snow_selection(project)
    if selected is not None:
        from snow_water_groundwater import codec
        return codec(selected)
    if not enabled(project):return prior.native_magic(project)
    return b'S5IGW001' if numerical_selector(project) else b'S5EGW001'


def selected_boundary(project):return 1 if enabled(project) else prior.selected_boundary(project)


def boundary_metadata(project,sha,app,root):
    if not enabled(project):return prior.boundary_metadata(project,sha,app,root)
    return dict(policy=prior.boundary.POLICY,source_sha256=sha(app/'groundwater_boundary_receipt.py'),composition_sha256=sha(Path(__file__)),predecessor_sha256=sha(app/'lower_boundary_receipt.py'),template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=1,production_sha256=sha(root/'src/process/mod_prescribed_groundwater_reaction.f90'),state='read-only original Darcy and prescribed saturated-tail reaction; no new physical store')


def state_source(project=None):
    selected=snow_selection(project) if project is not None else None
    if selected is not None:
        from snow_water_groundwater_state import state_source as snow_source
        return snow_source(selected['swkimpl'])
    source=Path(__file__).with_name('groundwater_history_native_state.f90').read_text(encoding='cp1252')
    for old,new in [('hybrid_groundwater_history_native_state','hybrid_implicit_groundwater_native_state'),
                    ('groundwater_history_native_checkpoint','implicit_groundwater_native_checkpoint'),
                    ('only: swbotb,swcfbs,','only: swkimpl,swbotb,swcfbs,'),
                    ('swsolu/=1','swsolu/=0.or.swkimpl/=1'),
                    ('swsnow<0.or.swsnow>1','swsnow/=0'),
                    ('(swhyst==0.and.swsnow==0)','(swhea/=1.or.swcalt/=2)'),
                    ('expected=[2,n,','expected=[4,n,')]:
        assert old in source,old
        source=source.replace(old,new)
    if project is not None and numerical_selector(project)==0:
        for old,new in [('swsolu/=0.or.swkimpl/=1','swsolu/=0.or.swkimpl/=0'),('expected=[4,n,','expected=[5,n,'),('swcfbs,1]','swcfbs,0]')]:
            assert source.count(old)==1,old
            source=source.replace(old,new,1)
    return source


def native_metadata(project,sha,app):
    selected=snow_selection(project)
    if selected is not None:
        import snow_water_groundwater_state as snow_state
        return dict(**snow_state.metadata(project,selected),template_sha256=sha(app/'groundwater_history_native_state.f90'),provider_filename=snow_state.STATE+'.f90',magic=magic(project).decode(),domain_bytes=104,placement='after complete original Snow calendar before96byte existing diagnostic tail')
    if not enabled(project):return prior.native_metadata(project,sha,app)
    return dict(policy=POLICY if numerical_selector(project) else 'original-explicit-water-groundwater-complete-hydraulic-carry-v1',source_sha256=sha(Path(__file__)),template_sha256=sha(app/'groundwater_history_native_state.f90'),provider_filename=STATE+'.f90',provider_sha256=hashlib.sha256(state_source(project).encode('cp1252')).hexdigest(),magic=magic(project).decode(),domain_bytes=104,actual_domain=domain(project),hydraulic_doubles='5*actual_nodes+4',placement='after existing physical state before optional original output calendar')


def native_enabled(project):return enabled(project) or prior.native_enabled(project)


def validate_candidate(raw,receipt,project):
    selected=snow_selection(project)
    if selected is not None:
        from snow_water_groundwater_state import validate_candidate as snow_validate
        return snow_validate(raw,receipt,project,selected)
    if not enabled(project):return prior.validate_candidate(raw,receipt,project)
    n=project.nodes;header=struct.pack('<13i',*domain(project))
    if raw[:8]!=magic(project) or raw.count(header+header)!=1:raise ValueError('Foreign implicit groundwater native domain')
    if len(raw)<36:raise ValueError('Incomplete groundwater native prefix')
    nodes,clock,step,canopy=struct.unpack_from('<i3d',raw,8)
    if (nodes!=n or not all(map(math.isfinite,(clock,step,canopy))) or not 0<step<=1 or canopy<0
            or clock!=project.start_clock+receipt.get('day',-1)
            or canopy!=receipt.get('stock_end_cm',[None]*4)[3]):
        raise ValueError('Actual groundwater native prefix differs from accepted receipt')
    offset=raw.index(header+header)+104
    if len(raw)<offset+8*(5*n+4):raise ValueError('Incomplete implicit groundwater native state')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)) or any(v<0 for v in values[n:5*n+2]) or values[-1]<0:raise ValueError('Invalid implicit groundwater native state')
    if list(values[:n])!=receipt.get('pressure_head_cm') or values[-2]!=receipt.get('groundwater_cm') or values[-1]!=receipt.get('stock_end_cm',[None])[0]:
        raise ValueError('Actual implicit groundwater native state differs from receipt')


def native_apply_build(output,project,patched):
    selected=snow_selection(project)
    if selected is not None:
        from snow_water_groundwater_build import native_build
        return native_build(output,project,patched,selected)
    if not enabled(project):return prior.native_apply_build(output,project,patched)
    (output/(STATE+'.f90')).write_text(state_source(project),encoding='cp1252')
    path=output/'macropore.f90';text=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert text.count(begin)==text.count(end)==1
    first=text.index(begin);last=text.index(end,first)+len(end);source=text[first:last]
    codecs=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(codecs)==2 and len(set(codecs))==1
    source=source.replace(codecs[0],magic(project).decode())
    anchor='      use MOD_grid, only: numnod';assert source.count(anchor)==1
    source=source.replace(anchor,'      use hybrid_implicit_groundwater_native_state,only:implicit_groundwater_native_checkpoint\n'+anchor,1)
    for restoring in ('.true.','.false.'):
        anchor=(f'        call hybrid_output_calendar_checkpoint(unit,{restoring})' if project.original_output else ('        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'))
        assert source.count(anchor)==1
        source=source.replace(anchor,f'        call implicit_groundwater_native_checkpoint(unit,{restoring})\n'+anchor,1)
    path.write_text(text[:first]+source+text[last:],encoding='cp1252')
    return [STATE,*patched]
