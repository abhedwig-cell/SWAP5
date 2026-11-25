"""Actual Linux CLI builds and bounded calendar science, with unchanged limits."""
import argparse,json,subprocess,sys,time
from pathlib import Path
from frost_calendar_state_batch import source
from frost_calendar_state_inputs import prepare

R=Path(__file__).resolve().parents[2]


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    head,contract=source();a.output.mkdir(parents=True);q=dict(status='RUNNING_ACTUAL_UBUNTU_CALENDAR_NOT_ADMITTED',actual_source=head,optimization=a.optimization,contexts=[],compiler_executions=0,canonical_admission=False)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(command,folder,cap):
        with (folder/'controller.stdout').open('xb') as stdout,(folder/'controller.stderr').open('xb') as stderr:
            result=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=cap)
        result.check_returncode()
    save()
    try:
        for case in contract['representative_cases']:
            assert source()[0]==head
            folder=a.output/case['name'];folder.mkdir();inputs=folder/'inputs'
            prepare(case['kind'],case['hysteresis'],case['initial'],case['implicit'],case['calendar'],inputs,reset=case['reset'],start=case['start'])
            build=a.build_root/case['name']/'bundle';record=folder/'build';record.mkdir()
            command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
            b=dict(status='RUNNING_ACTUAL_FROST_CALENDAR_BUILD_NOT_QUALIFIED',actual_source=head,input_root=str(inputs),build_root=str(build),command=command,compiler_executions=1,model_executions=0)
            started=time.perf_counter()
            try:
                run(command,record,300);b.update(returncode=0,status='ACTUAL_FROST_CALENDAR_BUILD_PASS_NOT_QUALIFIED')
            finally:
                b['actual_public_builder_wall_seconds']=time.perf_counter()-started;b['separate_compile_link_validation_seconds']='UNKNOWN';(record/'RESULT.json').write_text(json.dumps(b,indent=2)+'\n')
            q['compiler_executions']+=1;save()
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_runtime.py','--build-record',str(record/'RESULT.json'),'--reference-work',str(a.reference_work),'--output',str(folder/'science'),'--days',str(case['days'])]
            if case['start'][5:7]=='12':command.append('--year-seam')
            run(command,folder,900)
            science=json.loads((folder/'science/RESULT.json').read_text());assert science['status']=='ACTUAL_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
            item=dict(case=case,science=science,controls=None);q['contexts'].append(item);save()
            if case['days']==35:
                logs=folder/'controls-controller';logs.mkdir()
                run([sys.executable,'-B','tests/nomacro_drainage/frost_calendar_state_controls.py','--reference-work',str(a.reference_work),'--profile',str(folder/'science'),'--output',str(folder/'controls')],logs,600)
                item['controls']=json.loads((folder/'controls/RESULT.json').read_text());assert item['controls']['status']=='ACTUAL_FROST_CALENDAR_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED';save()
            print('PASS',case['name'],case['days'],flush=True)
        assert len(q['contexts'])==7 and source()[0]==head
        q['status']='ACTUAL_UBUNTU_FOUR_FULL35_THREE_SHORT_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_UBUNTU_CALENDAR_NOT_QUALIFIED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
