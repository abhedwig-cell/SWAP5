"""Replay the actual retained model7 refusal from existing native day201, then363."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import original_output_matrix as previous
m=previous.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    profile=json.loads((a.profile/'RESULT.json').read_text(encoding='utf-8'))
    assert profile['status']=='FAILED' and profile['error']=="ValueError('Rejected day 364')"
    build=Path(profile['build_root']);inputs=Path(profile['input_root'])
    project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
    meta,case=m.validate_bundle(build,a.reference_work,project)
    warm=[json.loads(line) for line in (a.profile/'trajectory/daily.jsonl').read_text().splitlines()]
    assert len(warm)==364 and all(row['committed'] for row in warm[:-1]) and not warm[-1]['committed']
    refused=warm[-1];assert 1e-10<abs(refused['independent_residual_cm'])<1.01e-10
    q=dict(status='RUNNING',producer=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        actual_BUILD_sha256=m.sha(build/'BUILD.json'),actual_failed_profile_sha256=m.sha(a.profile/'RESULT.json'),
        original_failed_day=364,accepted_prefix_days=363,source_checkpoint_day=201,
        full_periods_replayed=0,whole_model_qualified=False,physical_or_tolerance_correction=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for start,publish in ((201,363),(363,364)):
            source=(a.profile/'trajectory' if start==201 else a.output/'cold-201')/f'accepted-column-1-day-{start}.zip'
            digest=m.sha(source);origin=a.output/('origin-'+str(start))
            receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin)
            target=a.output/('cold-'+str(start));target.mkdir()
            result=m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,target,364,
                checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=publish,
                checkpoint_binding=meta['binding'],model=project.model,project=project)
            rows=m.rows(target);assert len(rows)==364-start
            assert m.physical(rows)==m.physical(warm[start:364])
            assert result['first_refusal']['day']==364 and not rows[-1]['committed']
            assert not list(target.glob('accepted-*-day-364.zip')) and m.sha(source)==digest
            q['cold_'+str(start)]=dict(accepted_days=363-start,refusal_day=364,exact_accepted_suffix_and_refusal=True,
                origin_sha256=digest,origin_unchanged=True,no_rejected_publication=True)
            save()
        q['status']='ACTUAL_MODEL7_DAY364_RETAINED_REFUSAL_EXACT_COLD_SUFFIX_NO_COMMIT'
        print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
