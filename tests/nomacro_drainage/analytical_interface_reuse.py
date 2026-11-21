"""Prove every new compiled source interface equals the admitted model7 closure."""
import json
from model7_search_science import SHA


def compare(build,baseline,models):
    meta=json.loads((build/'BUILD.json').read_text());old=json.loads((baseline/'BUILD.json').read_text())
    actual={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in build.glob('*.f90')}
    prior={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in baseline.glob('*.f90')}
    capacity='WC_K_models_04_11.f90'
    if 7 not in models:
        assert capacity not in actual and SHA(prior.pop(capacity))=='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'
    assert actual==prior
    a=dict(meta['identity']['donor_objects']);b=dict(old['identity']['donor_objects'])
    if 7 not in models:assert a.pop('WC_K_models_04_11.o')
    assert a==b
    for key in ('donor_flags','kernel_flags'):assert meta['identity'][key]==old['identity'][key]
    return dict(status='COMPLETE_COMPILED_FORTRAN_INTERFACE_AND_FLAGS_ORIGINAL_PROVIDER_EXACT',generated_sources={name:SHA(raw) for name,raw in actual.items()},
        donor_objects_except_separately_audited_original_capacity=a,capacity_correction_selected=7 in models,
        admitted_compiled_native_refusals_reused=True,new_compiled_native_attacks=0)
