"""Run only the newly affected interval/codecs and drainage-history controls."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[2]
NATIVE=('h2-interval-periodic','h1-interval-explicit-off','h0-interval-monthly-off','h1-clock-step-off')
SOURCE=('h0-interval-monthly-off','h1-interval-explicit-off','h1-clock-step-off')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','cohort','evidence','output'):
        parser.add_argument('--'+name,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--reuse-existing',action='store_true')
    parser.add_argument('--recover-failed-source',action='store_true')
    args=parser.parse_args();args.output.mkdir()
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                native={},source_controls={},repeated_model_periods=0,fresh_compilations=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for group,labels in (('native',NATIVE),('source_controls',SOURCE)):
            for label in labels:
                kind='controls' if group=='native' else 'source-controls'
                target=args.evidence/f'groundwater-interval-{kind}-{label}-{args.optimization}-v1'
                expected=('ACTUAL_GROUNDWATER_CDE_INTERVAL_DRAINAGE_COMPILED_NATIVE_TRANSACTION_PASS' if group=='native'
                          else 'ACTUAL_GROUNDWATER_INTERVAL_DRAINAGE_SOURCE_POLICY_REFUSALS_PASS')
                if group=='source_controls' and args.recover_failed_source and target.exists():
                    failed=json.loads((target/'RESULT.json').read_text())
                    if failed['status']=='FAILED':target=target.with_name(target.name[:-2]+'v2')
                if target.exists():
                    assert args.reuse_existing and json.loads((target/'RESULT.json').read_text())['status']==expected
                    reused=True
                else:
                    controller='groundwater_interval_'+('controls' if group=='native' else 'source_controls')+'.py'
                    command=[sys.executable,'-B',str(Path(__file__).with_name(controller)),
                             '--reference-work',str(args.reference_work),'--profile',str(args.cohort/label),'--output',str(target)]
                    with (args.output/f'{kind}-{label}.stdout').open('x') as out,(args.output/f'{kind}-{label}.stderr').open('x') as err:
                        subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300,check=True)
                    reused=False
                record=json.loads((target/'RESULT.json').read_text())
                assert record['status']==expected
                result[group][label]=dict(actual_root=str(target),reused_original_completed_control=reused)
                save()
        result['status']='ACTUAL_FOUR_NATIVE_THREE_SOURCE_COMPOSITION_CONTEXTS_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
