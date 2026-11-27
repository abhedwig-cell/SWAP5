"""Finite dependency-surface closed default pressure/calendar batch, retaining every failure."""
import argparse,json,subprocess,sys,time
from pathlib import Path
R=Path(__file__).resolve().parents[2]
P=R/'integration/f-ci/nomacro-complete01'


def main():
    p=argparse.ArgumentParser()
    for name in ['output','build-root','reference-work']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--case',action='append');p.add_argument('--scope',choices=['all','independent'],default='all');a=p.parse_args()
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain=v1','--untracked-files=all','--ignored'],cwd=R)
    plan=json.loads((P/'CLOSED_DEFAULT_CALENDAR_STATE14_FINITE_CASE_PLAN_V1.json').read_text());cases=plan['cases']
    if a.scope=='independent':cases=[v for v in cases if v['name'] in plan['independent_qualification_cases']]
    if a.case:
        assert set(a.case)<=set(v['name'] for v in cases)
        cases=[v for v in cases if v['name'] in a.case]
    a.output.mkdir();a.build_root.mkdir()
    q=dict(status='RUNNING_ACTUAL_CLOSED_DEFAULT_CALENDAR_FINITE_BATCH_NOT_QUALIFIED',actual_source=head,optimization=a.optimization,scope=a.scope,deferred_numerical_cases=[],contexts=[],canonical_admission=False)
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    save()
    def run(command,name):
        started=time.perf_counter()
        with (a.output/(name+'.stdout')).open('xb') as out,(a.output/(name+'.stderr')).open('xb') as err:
            child=subprocess.run([sys.executable,'-B',*map(str,command)],cwd=R,stdout=out,stderr=err,timeout=900)
        return dict(command=list(map(str,command)),returncode=child.returncode,seconds=time.perf_counter()-started)
    for spec in cases:
        name=spec['name'];folder=a.output/name;item=dict(case=name)
        try:
            item['runtime']=run(['tests/nomacro_drainage/closed_default_calendar_feedback.py','--case',name,
                '--optimization',a.optimization,'--output',folder,'--build-output',a.build_root/name,'--reference-work',a.reference_work],name)
            if item['runtime']['returncode']==0:
                item['native']=run(['tests/nomacro_drainage/closed_default_calendar_native_controls.py','--profile',folder,
                    '--output',a.output/(name+'-native-controls'),'--reference-work',a.reference_work],name+'-native')
                item['status']='PASS_NOT_QUALIFIED' if item['native']['returncode']==0 else 'NATIVE_FAILURE_RETAINED'
            else:item['status']='RUNTIME_FAILURE_RETAINED'
        except Exception as error:item.update(status='CONTROLLER_FAILURE_RETAINED',error=repr(error))
        q['contexts'].append(item);save();print(name,item['status'],flush=True)
        assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip()==head
    q['status']='ALL_SELECTED_CLOSED_DEFAULT_CALENDAR_LOCAL_CONTEXTS_AND_NATIVE_CONTROLS_PASS_NOT_QUALIFIED' if all(v['status']=='PASS_NOT_QUALIFIED' for v in q['contexts']) else 'CLOSED_DEFAULT_CALENDAR_BATCH_FAILURES_RETAINED_NOT_QUALIFIED'
    save();print(q['status'],flush=True)
    if any(v['status']!='PASS_NOT_QUALIFIED' for v in q['contexts']):raise SystemExit(1)

if __name__=='__main__':main()
