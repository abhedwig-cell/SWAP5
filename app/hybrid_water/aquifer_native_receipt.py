"""Bind actual original aquifer native state to its proposed accepted receipt."""
import hashlib
import math
from pathlib import Path
import struct
from conserved_aquifer_solute import enabled,validate_state,PATCH

POLICY='original-aquifer-native-receipt-consistency-v1'
WIRE=struct.Struct('<6dq')


def metadata():
    digest=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=POLICY,source_sha256=digest(Path(__file__)),
                physical_checkpoint_owner_canonical_sha256=digest(PATCH),
                conserved_cde_prefix_offset_bytes=48,
                aquifer_offset='48+8*(actual_nodes+2)',
                aquifer_wire='six real64 and one int64',aquifer_bytes=WIRE.size,
                physical_equations_changed=False,chemical_guard_mg_cm2=1e-10)


def decode(aux,nodes):
    if type(nodes) is not int or nodes<1:raise ValueError('Invalid aquifer native receipt shape')
    offset=48+8*(nodes+2)
    if len(aux)<offset+WIRE.size:raise ValueError('Incomplete aquifer native receipt state')
    soil=struct.unpack_from('<d',aux,offset-8)[0]
    actual=list(WIRE.unpack_from(aux,offset))
    validate_state([*actual[:6],float(actual[6])])
    if not math.isfinite(soil) or soil<0:raise ValueError('Invalid aquifer native soil stock')
    return soil,actual


def validate_candidate(aux,receipt,project):
    soil,actual=decode(aux,project.nodes)
    expected=receipt['aquifer_state'];validate_state(expected)
    if soil!=receipt['solute_end_mg_cm2'] or actual!=expected:
        raise ValueError('Private aquifer native state differs from candidate receipt')
    return actual
