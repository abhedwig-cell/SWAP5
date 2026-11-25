"""Register and build one actual original Frost calendar context on real HEAD."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
TASK='01a1e8b4-228b-75f1-8ac4-b07ca1e15713'
TOOL=Path('C:/Users/Veldh012/OneDrive - Wageningen University & Research/Documents/ChatGPT/SWAP5-finaliseren/tools/storage/cleanup.py')


def main():
    p=argparse.ArgumentParser()
    for name in ('inputs','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--label',required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
    head=git('rev-parse','HEAD').decode().strip();assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    storage=lambda *args:json.loads(subprocess.check_output([sys.executable,'-B',str(TOOL),*args]))
    space=storage('check-space','--large-job');allocated=storage('allocate','--task',TASK,'--kind','build','--name',a.label,'--variant',a.optimization,'--source-ref',head,'--recipe','Actual '+head+' original Frost calendar '+str(a.inputs)+' '+a.optimization+' public CLI build; original limits; no completed parent period replay')
    build=Path(allocated['path'])/'bundle';a.output.mkdir()
    command=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(a.inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(build)]
    q=dict(status='RUNNING_ACTUAL_FROST_CALENDAR_BUILD_NOT_QUALIFIED',actual_source=head,input_root=str(a.inputs),build_root=str(build),command=command,space_preflight=space,compiler_executions=1,model_executions=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        with (a.output/'build.stdout').open('xb') as stdout,(a.output/'build.stderr').open('xb') as stderr:r=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=240)
        q['returncode']=r.returncode;r.check_returncode();assert git('rev-parse','HEAD').decode().strip()==head
        q['status']='ACTUAL_FROST_CALENDAR_BUILD_PASS_NOT_QUALIFIED'
    except Exception as error:q.update(status='FAILED_ACTUAL_FROST_CALENDAR_BUILD_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
