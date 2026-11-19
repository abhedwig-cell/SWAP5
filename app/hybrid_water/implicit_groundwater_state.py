"""Typed water groundwater carry for the demonstrated implicit restart gap."""
import hashlib
import math
from pathlib import Path
import re
import struct
import age_groundwater_output as prior

STATE='implicit_groundwater_native_state'
POLICY='original-implicit-water-groundwater-complete-hydraulic-carry-v1'


def enabled(project):
    if not project.input_directory or project.macro or project.solute or project.age or not project.original_output:return False
    from experimental_project import inspect
    report=inspect(project.input_directory)
    return report['selectors']['SWKIMPL']==1 and report['boundary']['SWBOTB']==1


def domain(project):
    from experimental_project import inspect
    s=inspect(project.input_directory)['selectors']
    return [4,project.nodes,0,0,1,s['SWHYST'],0,0,1,2,s['SWDRA'],s['SWCFBS'],1]


def magic(project):
    if not enabled(project):return prior.native_magic(project)
    return b'S5IGW001'


def selected_boundary(project):return 1 if enabled(project) else prior.selected_boundary(project)


def boundary_metadata(project,sha,app,root):
    if not enabled(project):return prior.boundary_metadata(project,sha,app,root)
    return dict(policy=prior.boundary.POLICY,source_sha256=sha(app/'groundwater_boundary_receipt.py'),composition_sha256=sha(Path(__file__)),predecessor_sha256=sha(app/'lower_boundary_receipt.py'),template_sha256=sha(app/'hybrid_step_budget.f90'),effective_SWBOTB=1,production_sha256=sha(root/'src/process/mod_prescribed_groundwater_reaction.f90'),state='read-only original Darcy and prescribed saturated-tail reaction; no new physical store')


def state_source():
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
    return source


def native_metadata(project,sha,app):
    if not enabled(project):return prior.native_metadata(project,sha,app)
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),template_sha256=sha(app/'groundwater_history_native_state.f90'),provider_filename=STATE+'.f90',provider_sha256=hashlib.sha256(state_source().encode('cp1252')).hexdigest(),magic=magic(project).decode(),domain_bytes=104,actual_domain=domain(project),hydraulic_doubles='5*actual_nodes+4',placement='after existing physical state before optional original output calendar')


def native_enabled(project):return enabled(project) or prior.native_enabled(project)


def validate_candidate(raw,receipt,project):
    if not enabled(project):return prior.validate_candidate(raw,receipt,project)
    n=project.nodes;header=struct.pack('<13i',*domain(project))
    if raw[:8]!=magic(project) or raw.count(header+header)!=1:raise ValueError('Foreign implicit groundwater native domain')
    offset=raw.index(header+header)+104
    if len(raw)<offset+8*(5*n+4):raise ValueError('Incomplete implicit groundwater native state')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)) or any(v<0 for v in values[n:5*n+2]) or values[-1]<0:raise ValueError('Invalid implicit groundwater native state')
    if list(values[:n])!=receipt.get('pressure_head_cm') or values[-2]!=receipt.get('groundwater_cm') or values[-1]!=receipt.get('stock_end_cm',[None])[0]:
        raise ValueError('Actual implicit groundwater native state differs from receipt')


def native_apply_build(output,project,patched):
    if not enabled(project):return prior.native_apply_build(output,project,patched)
    (output/(STATE+'.f90')).write_text(state_source(),encoding='cp1252')
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
