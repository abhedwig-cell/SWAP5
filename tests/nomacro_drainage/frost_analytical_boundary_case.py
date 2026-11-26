"""One genuine public analytical Frost build, trajectory, restart and controls."""
import argparse,json,os,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_analytical_boundary_inputs import prepare
from frost_analytical_boundary_input_contract import source
from frost_boundary_convergence import require_convergence


def main():
    p=argparse.ArgumentParser()
    for key in ['reference-work','output','build-output']:p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--case',type=int,required=True)
    a=p.parse_args();head,contract=source();case=contract['representative_cases'][a.case]
    a.output.mkdir();inputs=a.output/'inputs';prepare(case,inputs)
    build=a.build_output/'bundle';env=dict(os.environ,OMP_NUM_THREADS='1',PYTHONDONTWRITEBYTECODE='1')
    q=dict(status='RUNNING_ACTUAL_PUBLIC_ANALYTICAL_BOUNDARY_FROST_NOT_QUALIFIED',actual_source=head,
        optimization=a.optimization,case=case,input_root=str(inputs),build_root=str(build),canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(command,label,cap):
        started=time.perf_counter()
        with (a.output/(label+'.stdout')).open('xb') as out,(a.output/(label+'.stderr')).open('xb') as err:
            result=subprocess.run(command,cwd=R,env=env,stdout=out,stderr=err,timeout=cap)
        q[label]=dict(command=command,returncode=result.returncode,seconds=time.perf_counter()-started);save();result.check_returncode()
        return q[label]
    save()
    try:
        command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER',
            '--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy',
            'original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only',
            '--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
        result=run(command,'actual-public-build',300)
        report=dict(status='ACTUAL_PUBLIC_ANALYTICAL_BOUNDARY_FROST_BUILD_COMPLETE_NOT_SCIENTIFICALLY_QUALIFIED',
            actual_source=head,input_root=str(inputs),build_root=str(build),**result)
        (a.output/'BUILD_RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
        command=[sys.executable,'-B','tests/nomacro_drainage/frost_analytical_boundary_runtime.py',
            '--build-record',str(a.output/'BUILD_RESULT.json'),'--reference-work',str(a.reference_work),
            '--output',str(a.output/'science'),'--days',str(case['days'])]
        if case['start']:command.append('--year-seam')
        run(command,'actual-public-runtime',900)
        q['science']=json.loads((a.output/'science/RESULT.json').read_text());save()
        q['original_convergence']=require_convergence(a.output/'science');save()
        command=[sys.executable,'-B','tests/nomacro_drainage/frost_analytical_boundary_controls.py',
            '--profile',str(a.output/'science'),'--reference-work',str(a.reference_work),'--output',str(a.output/'controls')]
        if case['full_legacy_native_controls']:command.append('--full-legacy-native-controls')
        if case['active_frost_transactions']:command.append('--active-frost-transactions')
        run(command,'actual-compiled-and-transaction-controls',300)
        q['controls']=json.loads((a.output/'controls/RESULT.json').read_text())
        assert q['controls']['status']=='ACTUAL_ANALYTICAL_BOUNDARY_FROST_COMPILED_NATIVE_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
        assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
        q['status']='ACTUAL_PUBLIC_ANALYTICAL_BOUNDARY_FROST_SCIENCE_NATIVE_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_PUBLIC_ANALYTICAL_BOUNDARY_FROST_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],case['name'],a.optimization,head,flush=True)


if __name__=='__main__':main()
