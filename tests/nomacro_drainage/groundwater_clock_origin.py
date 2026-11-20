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
    assert not subprocess.check_output(['git','diff',ORIGIN,'--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
    profile=a.origin/'groundwater-clock/h0-step-periodic';short=read(profile/'RESULT.json')
    assert short['status']=='ACTUAL_ORIGINAL_IMPLICIT_CONDUCTIVITY_SHORT_PHYSICAL_COMPLETE_NATIVE_OUTPUT_PASS'
    assert tuple(short['parameters'][k] for k in ('solute','hysteresis','bottom','kmean','perstep','mode','format','reset','nprintday'))==(1,0,1,3,True,'periodic',2,0,1)
    compiled=read(a.origin/'COMPILED_PROJECTION_V1.json')[short['build_root']]
    bundle=a.origin/compiled['archive_prefix'];assert sha(bundle/'BUILD.json')==compiled['actual_BUILD_sha256']
    policy=read(bundle/'BUILD.json')
    for name,expected in policy['identity']['donor_generated'].items():assert sha(bundle/name)==expected
    for name,expected in policy['inputs'].items():assert sha(profile/'input'/name)==expected
    controls=a.origin/'groundwater-clock-controls/h0-step-periodic'
    refused=read(controls/'RESULT.json')
    assert refused['status']=='FAILED' and len(refused['clock_refusals'])==50
    assert 'Restored donor state differs from the accepted checkpoint receipt' in refused['error']
    runner=a.runner_root.resolve();targets=[]
    def restore(source,target):
        target=target.resolve();assert target.is_relative_to(runner) and target!=runner and not target.exists()
        shutil.copytree(source,target);targets.append(str(target))
    actual_profile=Path(short['input_root']).parent
    assert actual_profile==runner/'proof/groundwater-clock/h0-step-periodic'
    actual_bundle=Path(short['build_root']);assert actual_bundle.is_relative_to(runner/'builds')
    restore(profile,actual_profile);restore(bundle,actual_bundle)
    restore(controls,runner/'proof/groundwater-clock-controls/h0-step-periodic')
    for stem in ('day_donor','day_kernel'):
        executable=actual_bundle/stem
        assert executable.is_file();executable.chmod(executable.stat().st_mode|0o100)
    assert sha(actual_bundle/'BUILD.json')==compiled['actual_BUILD_sha256']
    out=a.output/'ORIGINAL_DEPENDENCY_V1.json';assert not out.exists()
    out.write_text(json.dumps(dict(status='ACTUAL_ORIGINAL_H0_CONTROL_DEPENDENCY_RESTORED',
        original_run=44682712004,original_source=ORIGIN,actual_BUILD_sha256=sha(actual_bundle/'BUILD.json'),
        actual_profile_receipt_sha256=sha(actual_profile/'RESULT.json'),actual_original_control_receipt_sha256=sha(controls/'RESULT.json'),
        restored_paths=targets,source_app_unchanged=True,original_receipts_rebound=False,fresh_model_periods=0),indent=2)+'\n')
    print('ACTUAL_ORIGINAL_H0_CONTROL_DEPENDENCY_RESTORED')


if __name__=='__main__':main()
