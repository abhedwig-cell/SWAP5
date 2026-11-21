"""Execute the bounded Snow vapor interaction cohort, registering all builds."""
import argparse,concurrent.futures,json,os,subprocess,sys,threading
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser(description=__doc__)
 for key in ('cleanup','work','evidence','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--task',required=True);a=p.parse_args()
 source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 assert not subprocess.check_output(['git','diff','6e77aeb82','HEAD','--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
 cases=[]
 for opt in ('O0','O2'):
  for label,models,flags in (('model11',[11],[1,1]),('mixed7-8',[7,8],[1,1]),('mixed9-10-selective',[9,10],[0,1])):
   for kind in ('water','cde'):
    name=f'snow-vapor-{label}-{kind}-{opt}-short-v1'
    command=[sys.executable,'-B',str(a.cleanup),'allocate','--task',a.task,'--kind','build','--name',name,'--variant',opt,'--source-ref',source,'--recipe',f'snow_vapor_runtime {kind} {opt} {models} flags{flags} 35days; unchanged app core6e77aeb82']
    result=subprocess.run(command,capture_output=True,text=True,check=True)
    build=Path(json.loads(result.stdout)['path']);assert build.resolve()==(a.work/name).resolve()
    cases.append(dict(name=name,kind=kind,optimization=opt,models=models,flags=flags,build=build))
 q=dict(status='RUNNING',source=source,profiles={});lock=threading.Lock()
 def save():
  with lock:(a.evidence/'SNOW_VAPOR_TARGETED_BATCH_V1.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 def run(item):
  name=item['name'];out=a.evidence/name
  command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/snow_vapor_runtime.py'),'--reference-work',str(a.reference_work),'--build-root',str(item['build']),'--output',str(out),'--kind',item['kind'],'--optimization',item['optimization'],'--layer-models',*map(str,item['models']),'--vapor-flags',*map(str,item['flags']),'--days','35']
  with (a.evidence/(name+'.stdout.txt')).open('x') as stdout,(a.evidence/(name+'.stderr.txt')).open('x') as stderr:
   result=subprocess.run(command,cwd=ROOT,stdout=stdout,stderr=stderr,timeout=600)
  q['profiles'][name]=dict(returncode=result.returncode,RESULT=str(out/'RESULT.json'));save()
  result.check_returncode();print(name,'PASS',flush=True)
 try:
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:list(executor.map(run,cases))
  assert len(q['profiles'])==12;q['status']='TWELVE_TARGETED_SNOW_VAPOR_35DAY_CONTEXTS_PASS_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)


if __name__=='__main__':main()
