"""Explicit original water-age units, source identity and accepted-state ledger."""
import hashlib
import importlib.util
import math
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/source.py'
MAGIC=b'S5AGE001'


def correction():
    spec=importlib.util.spec_from_file_location('original_age_correction',PATCH)
    s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s);return s


def metadata():
    s=correction();sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    return dict(policy=s.POLICY,source_sha256=sha(Path(__file__)),correction_sha256=sha(PATCH),
                providers={name:sha(ROOT/'src/process'/(name+'.f90')) for name in s.PROVIDERS},
                age_tolerance='8192*epsilon*max(1,actual_age_inventory,actual_age_fluxes)',
                units='cm day',native_codec=MAGIC.decode(),chemical_mass_guard_changed=False)


def tolerance(*values):return 8192*sys.float_info.epsilon*max(1.,*map(abs,values))


def validate(values):
    if len(values)!=11 or not all(map(math.isfinite,values)) or any(values[i]<0 for i in (0,1,2,3,4,5,8,9,10)):
        raise ValueError('Invalid or nonfinite original age state')
    if abs(math.fsum([values[0],values[1],-values[2]]))>tolerance(*values[:3]):
        raise ValueError('Inconsistent original soil/pond age stock')
    return values


def ledger(previous,current):
    validate(previous);validate(current)
    if any(current[i]<previous[i] for i in (3,4,5,8,9,10)):
        raise ValueError('Original age cumulative source/loss moved backward')
    prod,pondprod,external,drain,bottom,root,runoff,infil=flows=[math.fsum([current[i],-previous[i]]) for i in range(3,11)]
    soil=math.fsum([current[0],-previous[0],-prod,-infil,-bottom,drain,root])
    pond=math.fsum([current[1],-previous[1],-pondprod,-external,infil,runoff])
    combined=math.fsum([current[2],-previous[2],-prod,-pondprod,-external,-bottom,drain,root,runoff])
    limit=tolerance(*previous[:3],*current[:3],*flows)
    if any(not math.isfinite(v) or abs(v)>limit for v in (soil,pond,combined)):
        raise ValueError('Original age candidate exceeds accepted age balance policy')
    return dict(age_state_cm_day=current,age_start_cm_day=previous[2],age_end_cm_day=current[2],
                age_ledger_cm_day=flows,age_soil_residual_cm_day=soil,age_pond_residual_cm_day=pond,
                age_combined_residual_cm_day=combined,age_tolerance_cm_day=limit)
