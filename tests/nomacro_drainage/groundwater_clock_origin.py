"""Restore only an original h0 control dependency, without rebinding evidence.

This bounded recovery targets the original 5c0e2b343 portable artifacts. Their
full model and successful h1/h2 observations remain in the original archive.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

ORIGIN='5c0e2b34358940e02ae6f486f04e0f262df1c040'
ROOT=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('origin','runner-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    read=lambda p:json.loads(p.read_text(encoding='utf-8'))
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    cap=read(a.origin/'source/RESULT.json')
    assert cap['producer_head']==ORIGIN
    git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
    changed=git('diff','--name-only',ORIGIN,'--','app','src','tools/solute','tools/vq','reference').decode().splitlines()
    assert changed==['app/hybrid_water/daily_coupling.py','app/hybrid_water/groundwater_cde_clock_source_guard.py']
    path='app/hybrid_water/daily_coupling.py';now=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    hook=b"    if ((identity.get('original_output') or {}).get('groundwater_cde_clock') and\n            not identity.get('ordinary_implicit_pond_switch')):\n        from groundwater_cde_clock_source_guard import validate as validate_groundwater_clock_source\n        validate_groundwater_clock_source(bundle,identity)\n"
    assert now.count(hook)==1 and now.replace(hook,b'',1)==git('show',ORIGIN+':'+path)
    path='app/hybrid_water/groundwater_cde_clock_source_guard.py';now=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    extra=b"EXPLICIT_PARENT_HEAD='becdfa41163769b4009f5ad596e85af5c4235edf1adde7ba8385e6e09f2c4beb'\n"
    after=b"    expected=PARENT_HEAD if identity.get('implicit_conductivity') else EXPLICIT_PARENT_HEAD\n    if hashlib.sha256(source).hexdigest()!=expected:\n"
    before=b'    if hashlib.sha256(source).hexdigest()!=PARENT_HEAD:\n'
    private=b"    actual=(Path(bundle)/'original_cde_output_state.f90').read_bytes().replace(b'\\r\\n',b'\\n')\n    expected=Path(__file__).with_name('cde_interval_output_state.f90').read_bytes().replace(b'\\r\\n',b'\\n')\n    if actual!=expected:\n        raise ValueError('Foreign actual groundwater CDE clock private-state provider')\n"
    assert now.count(extra)==now.count(after)==now.count(private)==1
    assert now.replace(extra,b'',1).replace(after,before,1).replace(private,b'',1)==git('show',ORIGIN+':'+path)
    controls=a.origin/'groundwater-clock-controls/h0-step-periodic'
    refused=read(controls/'RESULT.json')
    assert refused['status']=='FAILED' and len(refused['clock_refusals'])==50
    assert 'Restored donor state differs from the accepted checkpoint receipt' in refused['error']
    runner=a.runner_root.resolve();targets=[]
    def restore(source,target):
        target=target.resolve();assert target.is_relative_to(runner) and target!=runner and not target.exists()
        shutil.copytree(source,target);targets.append(str(target))
    projection=read(a.origin/'COMPILED_PROJECTION_V1.json');restored={}
    for label in ('h2-periodic','h1-step-explicit','h0-step-periodic','h1-explicit-monthly'):
        profile=a.origin/'groundwater-clock'/label;short=read(profile/'RESULT.json')
        assert short['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
        compiled=projection[short['build_root']];bundle=a.origin/compiled['archive_prefix']
        assert sha(bundle/'BUILD.json')==compiled['actual_BUILD_sha256'];policy=read(bundle/'BUILD.json')
        for name,expected in policy['identity']['donor_generated'].items():assert sha(bundle/name)==expected
        for name,expected in policy['inputs'].items():assert sha(profile/'input'/name)==expected
        actual_profile=Path(short['input_root']).parent
        assert actual_profile==runner/'proof/groundwater-clock'/label
        actual_bundle=Path(short['build_root']);assert actual_bundle.is_relative_to(runner/'builds')
        restore(profile,actual_profile);restore(bundle,actual_bundle)
        for stem in ('day_donor','day_kernel'):
            executable=actual_bundle/stem;assert executable.is_file();executable.chmod(executable.stat().st_mode|0o100)
        assert sha(actual_bundle/'BUILD.json')==compiled['actual_BUILD_sha256']
        restored[label]=dict(actual_BUILD_sha256=sha(actual_bundle/'BUILD.json'),
                             actual_profile_receipt_sha256=sha(actual_profile/'RESULT.json'),
                             origin_compiled_prefix=compiled['archive_prefix'])
    restore(controls,runner/'proof/groundwater-clock-controls/h0-step-periodic')
    out=a.output/'ORIGINAL_DEPENDENCY_V1.json';assert not out.exists()
    out.write_text(json.dumps(dict(status='ACTUAL_ORIGINAL_H0_CONTROL_DEPENDENCY_RESTORED',
        original_run=44682712004,original_source=ORIGIN,restored=restored,
        actual_original_control_receipt_sha256=sha(controls/'RESULT.json'),
        restored_paths=targets,numerical_model_sources_unchanged=True,exact_readonly_source_guard_bridge=changed,
        original_receipts_rebound=False,fresh_model_periods=0),indent=2)+'\n')
    print('ACTUAL_ORIGINAL_H0_CONTROL_DEPENDENCY_RESTORED')


if __name__=='__main__':main()
