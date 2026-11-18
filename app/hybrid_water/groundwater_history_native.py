"""Original groundwater hydraulic/thermal histories; ordinary GWC delegates literally."""
from pathlib import Path
import math
import re
import struct
import groundwater_native as prior

POLICY='original-prescribed-groundwater-complete-process-history-carry-v1'


def selection(project):
    if not project.input_directory or project.macro or not project.solute:return None
    from experimental_project import inspect
    report=inspect(project.input_directory);s=report['selectors']
    if report['boundary']['SWBOTB']!=1 or not (s['SWHYST'] or s['SWSNOW']):return None
    if s['SWFROST'] or s['SWBR'] or s['SWMETDETAIL'] or s['SWSOPHY']:
        raise ValueError('Unsupported prescribed groundwater process history')
    return dict(hysteresis=s['SWHYST'],snow=s['SWSNOW'],heat=s['SWHEA'],calculation=s['SWCALT'] if s['SWHEA'] else 0,
                drainage=s['SWDRA'],et=s['SWCFBS'])


def enabled(project):return selection(project) is not None or prior.enabled(project)


def magic(project):
    s=selection(project)
    if s is None:return prior.magic(project)
    index=2*s['hysteresis']+(1 if project.original_output else 2) if s['snow'] else 2*(s['hysteresis']-1)+(1 if project.original_output else 2)
    return (('S5GTC' if s['snow'] else 'S5GHC')+f'{index:03d}').encode()


def domain(project):
    s=selection(project)
    if s is None:raise ValueError('No prescribed groundwater history domain')
    return [2,project.nodes,0,1,1,s['hysteresis'],s['snow'],0,s['heat'],s['calculation'],s['drainage'],s['et'],1]


def metadata(project,sha,app):
    s=selection(project)
    if s is None:return prior.metadata(project,sha,app)
    return dict(policy=POLICY,source_sha256=sha(app/'groundwater_history_native.py'),
                provider_sha256=sha(app/'groundwater_history_native_state.f90'),predecessor_sha256=sha(app/'groundwater_native.py'),
                predecessor_provider_sha256=sha(app/'groundwater_native_state.f90'),magic=magic(project).decode(),
                domain_bytes=104,actual_domain=domain(project),hydraulic_doubles='5*actual_nodes+4',
                placement='after literal physical/history/output-domain state before optional original calendar',cde_prefix_offset=48)


def decode(raw,project):
    if selection(project) is None:return prior.decode(raw,project)
    if raw[:8]!=magic(project):raise ValueError('Foreign groundwater history native codec')
    n=project.nodes;header=struct.pack('<13i',*domain(project))
    if raw.count(header+header)!=1:raise ValueError('Foreign groundwater history native domain')
    offset=raw.index(header+header)+104
    if len(raw)<offset+8*(5*n+4):raise ValueError('Incomplete groundwater history hydraulic carry')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)):raise ValueError('Nonfinite groundwater history hydraulic carry')
    if any(v<0 for v in values[n:5*n+2]) or values[-1]<0:raise ValueError('Invalid groundwater history hydraulic carry')
    return dict(heads=list(values[:n]),level=values[-2],volume=values[-1],offset=offset)


def validate_candidate(raw,receipt,project):
    if selection(project) is None:return prior.validate_candidate(raw,receipt,project)
    actual=decode(raw,project)
    if (actual['heads']!=receipt.get('pressure_head_cm') or actual['level']!=receipt.get('groundwater_cm')
            or actual['volume']!=receipt.get('stock_end_cm',[None])[0]):
        raise ValueError('Private groundwater history native carry differs from candidate receipt')


def apply_build(output,project,patched):
    if selection(project) is None:return prior.apply_build(output,project,patched)
    module='groundwater_history_native_state'
    (output/(module+'.f90')).write_bytes(Path(__file__).with_name(module+'.f90').read_bytes())
    path=output/'macropore.f90';source=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert source.count(begin)==source.count(end)==1
    first=source.index(begin);last=source.index(end,first)+len(end);prefix,suffix=source[:first],source[last:];source=source[first:last]
    codecs=re.findall(r"'(S5[A-Z0-9]{6})'",source);assert len(codecs)==2 and len(set(codecs))==1
    source=source.replace(codecs[0],magic(project).decode())
    anchor='      use MOD_grid, only: numnod';assert source.count(anchor)==1
    source=source.replace(anchor,'      use hybrid_groundwater_history_native_state,only:groundwater_history_native_checkpoint\n'+anchor,1)
    for restoring in ('.true.','.false.'):
        anchor=(f'        call hybrid_output_calendar_checkpoint(unit,{restoring})' if project.original_output else
                ('        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'))
        assert source.count(anchor)==1
        source=source.replace(anchor,f'        call groundwater_history_native_checkpoint(unit,{restoring})\n'+anchor,1)
    path.write_text(prefix+source+suffix,encoding='cp1252')
    return [module,*patched]
