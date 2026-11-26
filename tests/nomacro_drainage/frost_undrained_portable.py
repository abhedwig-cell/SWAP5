"""One16-case actual public undrained Frost build/runtime/native qualification."""
import argparse,json,platform,subprocess,sys,time
from pathlib import Path
from frost_undrained_state_inputs import prepare
from frost_undrained_input_contract import source
from frost_boundary_convergence import require_convergence
R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
    p.add_argument('--case',action='append',default=[]);a=p.parse_args()
    assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,contract=source();cases=contract['representative_cases'];names={c['name'] for c in cases}
    assert len(a.case)==len(set(a.case)) and set(a.case)<=names
    cases=[c for c in cases if not a.case or c['name'] in a.case];assert cases
    a.output.mkdir(parents=True);q=dict(status='RUNNING_ACTUAL_UNDRAINED_FROST_NOT_QUALIFIED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def run(command,folder,cap):
        folder.mkdir()
        with (folder/'controller.stdout').open('xb') as out,(folder/'controller.stderr').open('xb') as err:
            result=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=cap)
        result.check_returncode()
    save()
    try:
        for case in cases:
            assert source()[0]==head
            folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs';prepare(case,inputs);build=a.build_root/case['name']/'bundle'
            item=dict(case=case,science=None,controls=None);q['contexts'].append(item);save()
            command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            started=time.perf_counter();run(command,folder/'build-controller',300)
            record=dict(status='ACTUAL_PUBLIC_BUILD_COMPLETE_NOT_SCIENTIFICALLY_QUALIFIED',actual_source=head,input_root=str(inputs),build_root=str(build),returncode=0,command=command,seconds=time.perf_counter()-started)
            (folder/'BUILD_RESULT.json').write_text(json.dumps(record,indent=2)+'\n');item['build']=record;save()
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_undrained_state_runtime.py','--build-record',str(folder/'BUILD_RESULT.json'),'--reference-work',str(a.reference_work),'--output',str(folder/'science'),'--days',str(case['days'])]
            if case['start'] and case['start'][5:7]=='12':command.append('--year-seam')
            run(command,folder/'science-controller',900);item['science']=json.loads((folder/'science/RESULT.json').read_text())
            assert item['science']['status']=='ACTUAL_UNDRAINED_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
            item['convergence']=require_convergence(folder/'science');save()
            if case['days']==35:
                run([sys.executable,'-B','tests/nomacro_drainage/frost_undrained_state_controls.py','--reference-work',str(a.reference_work),'--profile',str(folder/'science'),'--output',str(folder/'controls')],folder/'controls-controller',600)
                item['controls']=json.loads((folder/'controls/RESULT.json').read_text());assert item['controls']['status']=='ACTUAL_UNDRAINED_FROST_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
            save();print('ACTUAL_UNDRAINED_FROST_CONTEXT_PASS',case['name'],case['days'],a.optimization,flush=True)
        assert source()[0]==head
        q['status']='ACTUAL_SELECTED_UNDRAINED_FROST_PERIODS_NATIVE_COLD_AND_CONTROLS_PASS_NOT_ADMITTED'
    except Exception as exc:q.update(status='FAILED_ACTUAL_UNDRAINED_FROST_NOT_QUALIFIED',error=repr(exc));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
