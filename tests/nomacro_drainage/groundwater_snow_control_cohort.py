"""Run only the newly affected interval/codecs and drainage-history controls."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
NATIVE=('h2-snow-clock-periodic','h1-snow-step-explicit','h0-snow-interval-monthly','h2-snow-interval-periodic-off')
SOURCE=('h2-snow-clock-periodic','h1-snow-step-explicit','h0-snow-interval-monthly')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','cohort','evidence','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--reuse-existing',action='store_true')
    parser.add_argument('--version',default='v2',choices=('v2','v3'))
    parser.add_argument('--recover-failed-source',action='store_true')
    parser.add_argument('--source-recovery-map',type=Path)
    args=parser.parse_args();args.output.mkdir()
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                native={},source_controls={},repeated_model_periods=0,fresh_compilations=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        profiles=json.loads((args.cohort/'RESULT.json').read_text())['cases']
        recovery={} if args.source_recovery_map is None else json.loads(args.source_recovery_map.read_text())
        for group,labels in (('native',NATIVE),('source_controls',SOURCE)):
            for label in labels:
                profile_root=Path(profiles[label]['actual_case_root'])
                profile=json.loads((profile_root/'RESULT.json').read_text())
                import hashlib
                actual_build_sha=hashlib.sha256((Path(profile['build_root'])/'BUILD.json').read_bytes()).hexdigest()
                if group=='source_controls' and label in recovery:
                    assert args.reuse_existing
                    roots=[Path(value) for value in recovery[label]]
                    records=[json.loads((root/'RESULT.json').read_text()) for root in roots]
                    assert all(record['actual_BUILD_sha256']==actual_build_sha for record in records)
                    assert all(record['model_executions']==record['compilations']==0 for record in records)
                    inventory=records[-1]['complete_inventory'];observed=[]
                    for record in records:
                        if record['status']=='FAILED':
                            assert record['error']=="AssertionError(('timecontrol-source', 'Foreign complete parent Snow groundwater TimeControl provider'))"
                        else:assert record['status']=='ACTUAL_SELECTED_SNOW_GROUNDWATER_SOURCE_POLICY_REFUSALS_PASS'
                        assert all(value['before_worker'] and value['no_publication'] for value in record['refusals'])
                        observed.extend(value['field'] for value in record['refusals'])
                    assert len(observed)==len(set(observed)) and set(observed)==set(inventory)
                    result[group][label]=dict(actual_roots=[str(root) for root in roots],
                        actual_BUILD_sha256=actual_build_sha,actual_refusals=len(observed),
                        reused_original_completed_control=True,original_failed_producer_preserved=True)
                    save();continue
                kind='controls' if group=='native' else 'source-controls'
                target=args.evidence/f'groundwater-snow-{kind}-{label}-{args.optimization}-{args.version}'
                expected=('ACTUAL_EXPLICIT_SNOW_GROUNDWATER_CDE_COMPILED_NATIVE_TRANSACTION_PASS' if group=='native'
                          else 'ACTUAL_EXPLICIT_SNOW_GROUNDWATER_SOURCE_POLICY_REFUSALS_PASS')
                if group=='source_controls' and args.recover_failed_source and target.exists():
                    failed=json.loads((target/'RESULT.json').read_text())
                    if failed['status']=='FAILED':target=target.with_name(target.name[:-2]+'v2')
                if target.exists():
                    assert args.reuse_existing and json.loads((target/'RESULT.json').read_text())['status']==expected
                    reused=True
                else:
                    controller='groundwater_snow_'+('controls' if group=='native' else 'source_controls')+'.py'
                    command=[sys.executable,'-B',str(Path(__file__).with_name(controller)),
                             '--reference-work',str(args.reference_work),'--profile',str(profile_root),'--output',str(target)]
                    with (args.output/f'{kind}-{label}.stdout').open('x') as out,(args.output/f'{kind}-{label}.stderr').open('x') as err:
                        subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300,check=True)
                    reused=False
                record=json.loads((target/'RESULT.json').read_text())
                assert record['actual_BUILD_sha256']==actual_build_sha
                assert record['status']==expected
                result[group][label]=dict(actual_root=str(target),reused_original_completed_control=reused)
                save()
        result['status']='ACTUAL_FOUR_NATIVE_THREE_SOURCE_SNOW_GROUNDWATER_CONTEXTS_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
