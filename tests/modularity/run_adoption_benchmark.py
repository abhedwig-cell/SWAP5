#!/usr/bin/env python3
"""Alternating same-candidate independent/shared builds; execute every assertion."""
import argparse
import importlib.util
import subprocess
from pathlib import Path

spec=importlib.util.spec_from_file_location('runner',Path(__file__).with_name('run_modular_tests.py'))
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--output',required=True)
    ap.add_argument('--repeat',type=int,default=3);a=ap.parse_args()
    if a.repeat<3:ap.error('at least three paired rounds required')
    s=m.Session(Path(a.output).resolve());records=[]
    report={'head':subprocess.check_output(['git','rev-parse','HEAD'],cwd=m.ROOT,text=True).strip(),
            'baseline':'Same new production drivers with the incumbent per-driver independent compile policy',
            'candidate':'Shared verified provider artifacts within one controlled session; no cross-run cache',
            'records':records,'status':'RUNNING','events':s.events}
    try:
        for index in range(a.repeat):
            for shared in ([False,True] if index%2==0 else [True,False]):
                s.module_artifacts.clear();s.artifacts.clear();s.share_modules=shared
                for case in m.DEFAULT_CASES:
                    for opt in (0,2):
                        r=s.execute(case,opt);r.update(round=index,policy='shared' if shared else 'independent',build='cold')
                        records.append(r);m.write(s.out/'RESULTS.json',report)
                if shared:
                    for case in m.DEFAULT_CASES:
                        for opt in (0,2):
                            r=s.execute(case,opt,reuse=True);r.update(round=index,policy='shared',build='warm_same_transaction')
                            records.append(r);m.write(s.out/'RESULTS.json',report)
            for case in m.DEFAULT_CASES:
                group=[r for r in records if r['case']==case and r['round']==index]
                if len(group)!=6 or len({r['stdout_sha256'] for r in group})!=1:
                    raise RuntimeError('science/O0/O2/policy identity drift '+case)
                for opt in (0,2):
                    if len({r['executable_sha256'] for r in group if r['optimization']==opt})!=1:
                        raise RuntimeError('executable identity drift '+case)
            print(f'ADOPTION_PAIRED_ROUND_{index}=PASS',flush=True)
        report['status']='PASS';m.write(s.out/'RESULTS.json',report)
    except Exception as exc:
        report.update(status='FAIL',failure=str(exc));m.write(s.out/'RESULTS.json',report);raise
    print('ADOPTION_SAME_CANDIDATE_BENCHMARK=PASS',flush=True)


if __name__=='__main__':main()
