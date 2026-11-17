"""Explicit original no-macro mixed saturated reservoir source/state policy."""
import hashlib
import importlib.util
import math
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
POLICY='original-corrected-aquifer-solute-reservoir-v1'
PATCH=ROOT/'reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/source.py'


def enabled(project):
    if not project.input_directory or project.macro or not project.solute:return False
    from experimental_project import inspect
    return inspect(project.input_directory)['selectors']['SWBR']==1


def correction():
    spec=importlib.util.spec_from_file_location('original_corrected_aquifer',PATCH)
    module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
    return module


def metadata():
    source=correction();sha=lambda path:hashlib.sha256(path.read_bytes()).hexdigest()
    return dict(policy=POLICY,source_sha256=sha(Path(__file__)),correction_sha256=sha(PATCH),
                helper_canonical_sha256=source.HELPER,step_policy=source.STEP_POLICY,safety_factor=source.SAFETY,
                state_codec='private-aquifer-solute-native-v1',original_solute_sha256=source.ORIGINAL,
                allowed_subsurface_preimage_sha256=source.SUBSURFACE)


def validate_state(values):
    if len(values)!=7 or not all(map(math.isfinite,values)):
        raise ValueError('Incomplete or nonfinite original aquifer state')
    concentration,capacity,stock,soil,surface,decay,limits=values
    if concentration<0 or capacity<=0 or stock<0 or surface<0 or decay<0 or limits<0 or not limits.is_integer():
        raise ValueError('Invalid original aquifer state domain')
    if abs(concentration*capacity-stock)>1e-10:
        raise ValueError('Original aquifer stock/capacity mismatch')
    return values


def ledger(previous,current,soil_stock_before,soil_ledger):
    validate_state(previous);validate_state(current)
    if current[1]!=previous[1] or any(current[i]<previous[i] for i in (4,5,6)):
        raise ValueError('Original aquifer capacity or cumulative loss changed')
    incoming,outflow,decay=[math.fsum([current[i],-previous[i]]) for i in (3,4,5)]
    end,delta,rain,irrig,bottom,drain,soil_decay,root,reported=soil_ledger
    residual=math.fsum([current[2],-previous[2],-incoming,outflow,decay])
    exchange=math.fsum([incoming,-drain])
    compound=math.fsum([end,current[2],-soil_stock_before,-previous[2],-rain,-irrig,-bottom,soil_decay,root,outflow,decay])
    if any(not math.isfinite(value) or abs(value)>1e-10 for value in (residual,exchange,compound)):
        raise ValueError('Original soil/aquifer candidate exceeds unchanged1e-10 compound mass guard')
    return dict(aquifer_state=current,aquifer_start_mg_cm2=previous[2],aquifer_end_mg_cm2=current[2],
                aquifer_ledger_mg_cm2=[incoming,outflow,decay],aquifer_residual_mg_cm2=residual,
                aquifer_exchange_residual_mg_cm2=exchange,soil_aquifer_residual_mg_cm2=compound)
