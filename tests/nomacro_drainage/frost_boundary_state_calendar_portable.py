"""Actual selected Frost boundary/state/calendar builds and scientific controls."""
import argparse,json,platform,subprocess,sys,time
from pathlib import Path
from frost_boundary_state_calendar_input_contract import source
from frost_boundary_state_calendar_inputs import prepare
R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True)
    p.add_argument('--case',action='append',default=[]);a=p.parse_args()
    assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
    head,contract=source();a.output.mkdir(parents=True)
    names={x['name'] for x in contract['representative_cases']};assert len(a.case)==len(set(a.case)) and set(a.case)<=names
    selected=[x for x in contract['representative_cases'] if not a.case or x['name'] in a.case]
    q=dict(status='RUNNING_ACTUAL_BOUNDARY_STATE_CALENDAR_NOT_QUALIFIED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],public_builder_invocations=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(command,folder,cap):
        with (folder/'controller.stdout').open('xb') as stdout,(folder/'controller.stderr').open('xb') as stderr:
            result=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=cap)
        result.check_returncode()
    save()
    try:
        for case in selected:
            assert source()[0]==head
            folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs';prepare(case,inputs)
            build=a.build_root/case['name']/'bundle';record=folder/'build';record.mkdir()
            command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            b=dict(status='RUNNING_REAL_PUBLIC_BUILD_NOT_QUALIFIED',actual_source=head,input_root=str(inputs),build_root=str(build),command=command,public_builder_invocations=1,compiler_executions='UNKNOWN_UNTIL_ORIGINAL_BUILD_COMPLETES',model_executions=0)
            started=time.perf_counter()
            try:run(command,record,300);b.update(returncode=0,status='ACTUAL_BOUNDARY_STATE_CALENDAR_PUBLIC_BUILD_PASS_NOT_SCIENTIFICALLY_QUALIFIED',compiler_executions=1)
            finally:b['actual_public_builder_wall_seconds']=time.perf_counter()-started;(record/'RESULT.json').write_text(json.dumps(b,indent=2)+'\n')
            q['public_builder_invocations']+=1;item=dict(case=case,build=b,science=None,controls=None);q['contexts'].append(item);save()
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_runtime.py','--build-record',str(record/'RESULT.json'),'--reference-work',str(a.reference_work),'--output',str(folder/'science'),'--days',str(case['days'])]
            if case['start'] and case['start'][5:7]=='12':command.append('--year-seam')
            logs=folder/'science-controller';logs.mkdir();run(command,logs,900)
            item['science']=json.loads((folder/'science/RESULT.json').read_text());assert item['science']['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED';save()
            if case['days']==35:
                logs=folder/'controls-controller';logs.mkdir()
                run([sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_controls.py','--reference-work',str(a.reference_work),'--profile',str(folder/'science'),'--output',str(folder/'controls')],logs,600)
                item['controls']=json.loads((folder/'controls/RESULT.json').read_text());assert item['controls']['status']=='ACTUAL_FROST_CALENDAR_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED';save()
            print('ACTUAL_BOUNDARY_STATE_CALENDAR_PASS',case['name'],case['days'],a.optimization,flush=True)
        assert source()[0]==head and len(q['contexts'])==len(selected)
        q['status']='ACTUAL_SELECTED_BOUNDARY_STATE_CALENDAR_PERIODS_NATIVE_COLD_AND_CONTROLS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_BOUNDARY_STATE_CALENDAR_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
