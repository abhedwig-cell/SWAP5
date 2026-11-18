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
                stock_units='mg/cm2',comparison='exact native total and reported end stock',
                physical_equations_changed=False)


def decode(aux,nodes):
    if type(nodes) is not int or not 1<=nodes<=1000:
        raise ValueError('Invalid CDE native receipt shape')
    if len(aux)<48+8*(nodes+2):raise ValueError('Incomplete CDE native receipt state')
    conserved=struct.unpack_from('<'+str(nodes+2)+'d',aux,48)
    if not all(math.isfinite(v) and v>=0 for v in conserved):
        raise ValueError('Unrestartable CDE native conserved state')
    return conserved[-1]


def validate_candidate(aux,receipt,project):
    actual=decode(aux,project.nodes);expected=receipt.get('solute_end_mg_cm2')
    if type(expected) not in (int,float) or not math.isfinite(expected) or expected<0:
        raise ValueError('Invalid CDE candidate reported stock')
    if actual!=expected:raise ValueError('Private CDE native stock differs from candidate receipt')
    return actual
