"""Run the remaining bounded analytical/output interactions once each."""
import argparse,concurrent.futures,json,subprocess,sys,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]


def main():
 p=argparse.ArgumentParser()
 for key in ('cleanup','work','evidence','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--task',required=True);a=p.parse_args();source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip()
 assert not subprocess.check_output(['git','diff','102e95eb6d33107b81ab06576707fe0be9b215e2','HEAD','--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
 jobs=[]
 for opt in ('O0','O2'):
  for case,days in [('vapor8-nprint2',367),('vapor8-perstep',367),('vapor11-nprint3',35),('model7-nprint2',35),('feddes3-nprint3',35),('mixed7-8-nprint2',35),('vapor8-limit1440',2),*([('vapor8-monthly',367)] if opt=='O0' else [])]:
   name=f'analytical-calendar-{case}-{opt}-v1';profile=a.evidence/name
   if (profile/'RESULT.json').is_file():
    q=json.loads((profile/'RESULT.json').read_text());assert q['status']=='ACTUAL_ORIGINAL_ANALYTICAL_WATER_OUTPUT_CLOCK_AND_TERMINAL_COMPOSITION_POSTIMAGE_EXACT_COLD_PASS_NOT_ADMITTED';continue
   command=[sys.executable,'-B',str(a.cleanup),'allocate','--task',a.task,'--kind','build','--name',name,'--variant',opt,'--source-ref',source,'--recipe',f'analytical_calendar_postimages {case} {opt} {days}days; complete qualified HeadCalc07493/e869 inverse']
   result=subprocess.run(command,capture_output=True,text=True,check=True);build=Path(json.loads(result.stdout)['path']);assert build.resolve()==(a.work/name).resolve()
   jobs.append(dict(name=name,case=case,opt=opt,days=days,build=build))
 assert len(jobs)==13
 q=dict(status='RUNNING',source=source,profiles={},already_completed_contexts=2);lock=threading.Lock()
 def save():
  with lock:(a.evidence/'ANALYTICAL_CALENDAR_TARGETED_BATCH_V1.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 def run(item):
  name=item['name'];command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/analytical_calendar_postimages.py'),'--reference-work',str(a.reference_work),'--build-root',str(item['build']),'--output',str(a.evidence/name),'--case',item['case'],'--optimization',item['opt'],'--days',str(item['days'])]
  with (a.evidence/(name+'.stdout.txt')).open('x') as out,(a.evidence/(name+'.stderr.txt')).open('x') as err:result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=600)
  q['profiles'][name]=dict(returncode=result.returncode,RESULT=str(a.evidence/name/'RESULT.json'));save();result.check_returncode();print(name,'PASS',flush=True)
 try:
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:list(executor.map(run,jobs))
  assert len(q['profiles'])==13;q['status']='THIRTEEN_NEW_ANALYTICAL_OUTPUT_CONTEXTS_PASS_WITH_TWO_COMPLETED_YEAR_CONTEXTS_RETAINED'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)


if __name__=='__main__':main()
