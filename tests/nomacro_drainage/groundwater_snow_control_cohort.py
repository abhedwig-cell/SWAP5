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
    args=parser.parse_args();args.output.mkdir()
    result=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                native={},source_controls={},repeated_model_periods=0,fresh_compilations=0)
    def save():(args.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for group,labels in (('native',NATIVE),('source_controls',SOURCE)):
            for label in labels:
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
                             '--reference-work',str(args.reference_work),'--profile',str(args.cohort/label),'--output',str(target)]
                    with (args.output/f'{kind}-{label}.stdout').open('x') as out,(args.output/f'{kind}-{label}.stderr').open('x') as err:
                        subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=300,check=True)
                    reused=False
                record=json.loads((target/'RESULT.json').read_text())
                profile=json.loads((args.cohort/label/'RESULT.json').read_text())
                import hashlib
                assert record['actual_BUILD_sha256']==hashlib.sha256((Path(profile['build_root'])/'BUILD.json').read_bytes()).hexdigest()
                assert record['status']==expected
                result[group][label]=dict(actual_root=str(target),reused_original_completed_control=reused)
                save()
        result['status']='ACTUAL_FOUR_NATIVE_THREE_SOURCE_SNOW_GROUNDWATER_CONTEXTS_PASS'
    except Exception as error:
        result.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(result['status'])


if __name__=='__main__':main()
