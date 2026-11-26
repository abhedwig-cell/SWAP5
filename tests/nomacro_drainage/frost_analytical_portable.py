"""Twelve representative original analytical Frost compositions on one profile."""
import argparse,json,platform,subprocess,sys
from pathlib import Path
from frost_analytical_input_contract import source
R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for name in ['reference-work','build-root','output']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True)
    a=p.parse_args();assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,contract=source();a.output.mkdir();q=dict(status='RUNNING_ANALYTICAL_FROST_PORTABLE_NOT_QUALIFIED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for index,case in enumerate(contract['representative_cases']):
            assert source()[0]==head
            folder=a.output/case['name']
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_analytical_case.py','--reference-work',str(a.reference_work),'--optimization',a.optimization,'--case',str(index),'--output',str(folder),'--build-output',str(a.build_root/case['name'])]
            with (a.output/(case['name']+'.controller.stdout')).open('xb') as out,(a.output/(case['name']+'.controller.stderr')).open('xb') as err:
                result=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=1500)
            result.check_returncode();item=json.loads((folder/'RESULT.json').read_text())
            assert item['status']=='ACTUAL_PUBLIC_ANALYTICAL_FROST_SCIENCE_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and item['actual_source']==head and item['case']==case
            q['contexts'].append(item);save();print('ACTUAL_ANALYTICAL_FROST_CONTEXT_PASS',case['name'],a.optimization,flush=True)
        assert source()[0]==head and len(q['contexts'])==12
        q['status']='TWELVE_ACTUAL_ANALYTICAL_FROST_PORTABLE_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ANALYTICAL_FROST_PORTABLE_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
