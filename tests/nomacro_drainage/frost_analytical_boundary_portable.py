"""Twelve representative original analytical Frost compositions on one profile."""
import argparse,json,platform,subprocess,sys
from pathlib import Path
from frost_analytical_boundary_input_contract import source
R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for name in ['reference-work','build-root','output']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--platform',choices=['Windows','Ubuntu'],required=True)
    p.add_argument('--search-cohort',action='store_true')
    p.add_argument('--first-case',type=int,default=0);p.add_argument('--last-case',type=int,default=16);p.add_argument('--continue-after-refusal',action='store_true')
    a=p.parse_args();assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,contract=source()
    indices=([i for i,c in enumerate(contract['representative_cases']) if c['bottom']==6 and any(x!=1 for x in c['effective_models'])] if a.search_cohort else list(range(a.first_case,a.last_case)))
    if a.search_cohort:assert indices==[3,5,7,8,10,12,14,15]
    a.output.mkdir();q=dict(status='RUNNING_ANALYTICAL_FROST_PORTABLE_NOT_QUALIFIED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],refusals=[],selected_case_indices=indices,canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        assert 0<=a.first_case<a.last_case<=len(contract['representative_cases'])
        for index,case in enumerate(contract['representative_cases']):
            if index not in indices:continue
            assert source()[0]==head
            folder=a.output/case['name']
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_analytical_boundary_case.py','--reference-work',str(a.reference_work),'--optimization',a.optimization,'--case',str(index),'--output',str(folder),'--build-output',str(a.build_root/case['name'])]
            with (a.output/(case['name']+'.controller.stdout')).open('xb') as out,(a.output/(case['name']+'.controller.stderr')).open('xb') as err:
                result=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=1500)
            if result.returncode:
                q['refusals'].append(dict(case=case,index=index,returncode=result.returncode,actual_result=str(folder/'RESULT.json'),controller_stdout=str(a.output/(case['name']+'.controller.stdout')),controller_stderr=str(a.output/(case['name']+'.controller.stderr'))));save()
                if a.continue_after_refusal:continue
                result.check_returncode()
            item=json.loads((folder/'RESULT.json').read_text())
            assert item['status']=='ACTUAL_PUBLIC_ANALYTICAL_BOUNDARY_FROST_SCIENCE_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED' and item['actual_source']==head and item['case']==case
            q['contexts'].append(item);save();print('ACTUAL_ANALYTICAL_BOUNDARY_FROST_CONTEXT_PASS',case['name'],a.optimization,flush=True)
        assert source()[0]==head and len(q['contexts'])+len(q['refusals'])==len(indices)
        assert not q['refusals'],'Original selected cases refused; all raw results retained'
        q['status']=('EIGHT_ACTUAL_CHANGED_ANALYTICAL_ZERO_FLUX6_FROST_SEARCH_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED' if a.search_cohort else 'SIXTEEN_ACTUAL_ANALYTICAL_BOUNDARY_FROST_PORTABLE_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED' if (a.first_case,a.last_case)==(0,16) else 'SELECTED_EIGHT_ACTUAL_ANALYTICAL_BOUNDARY_FROST_CONTINUATION_PERIODS_NATIVE_COLD_AND_TRANSACTIONS_PASS_NOT_ADMITTED')
    except Exception as error:q.update(status='FAILED_ANALYTICAL_FROST_PORTABLE_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
