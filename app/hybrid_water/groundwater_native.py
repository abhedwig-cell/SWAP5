"""Typed complete original groundwater hydraulic carry; no process equation."""
from pathlib import Path
import math
import re
import struct
from groundwater_boundary_receipt import selected_boundary

POLICY='original-prescribed-groundwater-complete-hydraulic-carry-v1'


def enabled(project):return selected_boundary(project)==1


def magic(project):
    if not enabled(project):raise ValueError('No prescribed groundwater CDE native domain')
    return b'S5GWC001' if project.original_output else b'S5GWC002'


def metadata(project,sha,app):
    if not enabled(project):return None
    return dict(policy=POLICY,source_sha256=sha(app/'groundwater_native.py'),
                provider_sha256=sha(app/'groundwater_native_state.f90'),magic=magic(project).decode(),
                domain_bytes=72,hydraulic_doubles='5*actual_nodes+4',
                placement='after complete old physical state before optional original output calendar',
                cde_prefix_offset=48)


def decode(raw,project):
    if raw[:8]!=magic(project):raise ValueError('Foreign prescribed groundwater native codec')
    n=project.nodes
    header=struct.pack('<9i',1,n,0,1,1,0,0,0,1)
    if raw.count(header+header)!=1:raise ValueError('Foreign prescribed groundwater native domain')
    offset=raw.index(header+header)+72
    if len(raw)<offset+8*(5*n+4):raise ValueError('Incomplete prescribed groundwater hydraulic carry')
    values=struct.unpack_from('<'+str(5*n+4)+'d',raw,offset)
    if not all(map(math.isfinite,values)):raise ValueError('Nonfinite prescribed groundwater hydraulic carry')
    if any(v<0 for v in values[n:5*n+2]) or values[-1]<0:
        raise ValueError('Invalid prescribed groundwater hydraulic carry')
    return dict(heads=list(values[:n]),level=values[-2],volume=values[-1],offset=offset)


def validate_candidate(raw,receipt,project):
    actual=decode(raw,project)
    if (actual['heads']!=receipt.get('pressure_head_cm') or actual['level']!=receipt.get('groundwater_cm')
            or actual['volume']!=receipt.get('stock_end_cm',[None])[0]):
        raise ValueError('Private prescribed groundwater native carry differs from candidate receipt')


def apply_build(output,project,patched):
    if not enabled(project):return patched
    module='groundwater_native_state'
    (output/(module+'.f90')).write_bytes(Path(__file__).with_name(module+'.f90').read_bytes())
    path=output/'macropore.f90';source=path.read_text(encoding='cp1252')
    begin='    subroutine hybrid_macro_checkpoint(';end='    end subroutine hybrid_macro_checkpoint'
    assert source.count(begin)==source.count(end)==1
    first=source.index(begin);last=source.index(end,first)+len(end)
    prefix,suffix=source[:first],source[last:];source=source[first:last]
    codecs=re.findall(r"'(S5[A-Z0-9]{6})'",source)
    assert len(codecs)==2 and len(set(codecs))==1
    source=source.replace(codecs[0],magic(project).decode())
    anchor='      use MOD_grid, only: numnod'
    assert source.count(anchor)==1
    source=source.replace(anchor,'      use hybrid_groundwater_native_state,only:groundwater_native_checkpoint\n'+anchor,1)
    for restoring in ('.true.','.false.'):
        anchor=(f'        call hybrid_output_calendar_checkpoint(unit,{restoring})' if project.original_output else
                ('        read(unit,iostat=ios) trailing' if restoring=='.true.' else '      end if\n      close(unit)'))
        assert source.count(anchor)==1
        source=source.replace(anchor,f'        call groundwater_native_checkpoint(unit,{restoring})\n'+anchor,1)
    path.write_text(prefix+source+suffix,encoding='cp1252')
    return [module,*patched]
