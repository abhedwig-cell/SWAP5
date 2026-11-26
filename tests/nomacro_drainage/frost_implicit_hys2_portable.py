"""One selected implicit plate batch through genuine public build and runtime."""
import argparse,json,platform,subprocess,sys,time
from pathlib import Path
from frost_implicit_hys2_inputs import prepare
from frost_boundary_convergence import require_convergence
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
    p.add_argument('--case',action='append',default=[]);a=p.parse_args()
    assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    head=git('rev-parse','HEAD').decode().strip()
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    from frost_implicit_hys2_metadata import read
    contract=read('FROST_IMPLICIT_HYS2_YEAR06_CONTRACT_V1.json')
    cases=contract['representative_cases'];names={x['name'] for x in cases}
    assert len(a.case)==len(set(a.case)) and set(a.case)<=names
    selected=[x for x in cases if not a.case or x['name'] in a.case];assert selected
    a.output.mkdir(parents=True)
    q=dict(status='RUNNING_ACTUAL_IMPLICIT_HYS2_BOUNDARY_NOT_QUALIFIED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(cmd,folder,cap):
        folder.mkdir()
        with (folder/'controller.stdout').open('xb') as out,(folder/'controller.stderr').open('xb') as err:
            result=subprocess.run(cmd,cwd=R,stdout=out,stderr=err,timeout=cap)
        result.check_returncode()
    save()
    try:
        for case in selected:
            assert git('rev-parse','HEAD').decode().strip()==head
            folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs';prepare(case,inputs)
            build=a.build_root/case['name']/'bundle'
            item=dict(case=case,science=None,controls=None);q['contexts'].append(item);save()
            if case['calendar']=='parent-dense':
                command=[sys.executable,'-B','tests/nomacro_drainage/frost_cde_drainage_runtime.py','--reference-work',str(a.reference_work),'--build-root',str(a.build_root/case['name']),'--output',str(folder/'science'),'--kind',case['kind'],'--optimization',a.optimization,'--phase','short','--existing-input',str(inputs)]
                run(command,folder/'science-controller',600)
                item['science']=json.loads((folder/'science/RESULT.json').read_text())
                assert item['science']['status']=='CANDIDATE_ACTUAL_FROST_SWDIVD1_'+case['kind'].upper()+'_SHORT_PASS_NOT_ADMITTED'
                controls='frost_boundary_controls.py'
            else:
                cmd=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
                started=time.perf_counter();run(cmd,folder/'build-controller',300)
                record=dict(status='ACTUAL_PUBLIC_BUILD_COMPLETE_NOT_SCIENTIFICALLY_QUALIFIED',actual_source=head,input_root=str(inputs),build_root=str(build),returncode=0,command=cmd,seconds=time.perf_counter()-started)
                (folder/'BUILD_RESULT.json').write_text(json.dumps(record,indent=2)+'\n');item['build']=record;save()
                cmd=[sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_runtime.py','--build-record',str(folder/'BUILD_RESULT.json'),'--reference-work',str(a.reference_work),'--output',str(folder/'science'),'--days',str(case['days'])]
                if case['start'] and case['start'][5:7]=='12':cmd.append('--year-seam')
                run(cmd,folder/'science-controller',900)
                item['science']=json.loads((folder/'science/RESULT.json').read_text())
                assert item['science']['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
                controls='frost_calendar_state_controls.py'
            item['convergence']=require_convergence(folder/'science');save()
            if case['days']==35:
                run([sys.executable,'-B','tests/nomacro_drainage/'+controls,'--reference-work',str(a.reference_work),'--profile',str(folder/'science'),'--output',str(folder/'controls')],folder/'controls-controller',600)
                item['controls']=json.loads((folder/'controls/RESULT.json').read_text())
                assert item['controls']['status'] in ('ACTUAL_FROST_BOUNDARY_COMPILED_NATIVE_ROOT_SNOW_AND_ACTIVE_TRANSACTIONS_PASS_NOT_ADMITTED','ACTUAL_FROST_CALENDAR_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED')
            save();print('ACTUAL_IMPLICIT_HYS2_BOUNDARY_PASS',case['name'],case['days'],a.optimization,flush=True)
        q['status']='ACTUAL_SELECTED_IMPLICIT_HYS2_BOUNDARY_PERIODS_NATIVE_COLD_AND_CONTROLS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_IMPLICIT_HYS2_BOUNDARY_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
