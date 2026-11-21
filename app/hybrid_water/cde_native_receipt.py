"""Bind actual original conserved CDE native SAMPRO to external candidate stock."""
import hashlib
import math
from pathlib import Path
import struct

ROOT=Path(__file__).resolve().parents[2]
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-SUBSURFACE-SOLUTE-01/source.py'
POLICY='original-cde-native-stock-receipt-consistency-v1'


def enabled(project):
    return bool(project.input_directory and not project.macro and project.solute)


def metadata():
    digest=lambda path:hashlib.sha256(path.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,source_sha256=digest(Path(__file__)),
                physical_checkpoint_owner_canonical_sha256=digest(PATCH),
                conserved_cde_prefix_offset_bytes=48,
                native_stock_offset='48+8*(actual_nodes+1)',
                native_stock='actual original saved SAMPRO, not reconstructed CMSY',
                optional_native_prefixes={'S5HVC003':'48 + 8*(14+2*actual_layers), checked duplicated vapor domain'},
                stock_units='mg/cm2',comparison='exact native total and reported end stock',
                physical_equations_changed=False)


def decode(aux,nodes,project=None):
    if type(nodes) is not int or not 1<=nodes<=1000:
        raise ValueError('Invalid CDE native receipt shape')
    offset=48
    if aux[:8]==b'S5HVC003':
        if len(aux)<offset+56:raise ValueError('Incomplete CDE vapor domain')
        domain=struct.unpack_from('<14i',aux,offset);layers=domain[2]
        if not 1<=layers<=1000 or domain!=(3,nodes,layers,0,1,0,0,0,0,0,1,2,1,6):
            raise ValueError('Foreign CDE vapor domain')
        count=14+2*layers;size=4*count
        if len(aux)<offset+2*size:raise ValueError('Incomplete CDE vapor domain witness')
        header=struct.unpack_from('<'+str(count)+'i',aux,offset)
        if header!=struct.unpack_from('<'+str(count)+'i',aux,offset+size):
            raise ValueError('Foreign CDE vapor domain witness')
        models=header[14:14+layers];flags=header[14+layers:]
        if any(m not in range(1,12) for m in models) or any(f not in (0,1) for f in flags) or not any(flags) or any(f and m<8 for m,f in zip(models,flags)):
            raise ValueError('Foreign CDE vapor layer context')
        if project is not None:
            from hydraulic_vapor import describe
            selected=describe(project)
            if selected is None or tuple(selected['models'])!=models or tuple(f if m>=8 else 0 for m,f in zip(selected['models'],selected['SWVAPOR']))!=flags:
                raise ValueError('CDE vapor native differs from project layers')
        offset+=2*size
    if len(aux)<offset+8*(nodes+2):raise ValueError('Incomplete CDE native receipt state')
    conserved=struct.unpack_from('<'+str(nodes+2)+'d',aux,offset)
    if not all(math.isfinite(v) and v>=0 for v in conserved):
        raise ValueError('Unrestartable CDE native conserved state')
    return conserved[-1]


def validate_candidate(aux,receipt,project):
    actual=decode(aux,project.nodes,project);expected=receipt.get('solute_end_mg_cm2')
    if type(expected) not in (int,float) or not math.isfinite(expected) or expected<0:
        raise ValueError('Invalid CDE candidate reported stock')
    if actual!=expected:raise ValueError('Private CDE native stock differs from candidate receipt')
    return actual
