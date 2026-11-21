"""Target remaining boundary compositions, active CDE and year crossings once."""
import argparse,concurrent.futures,json,re,shutil,subprocess,sys,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'tests/nomacro_drainage')]
from original_output_baseline import assignment


def main():
 p=argparse.ArgumentParser()
 for key in ('cleanup','work','evidence','reference-work'):p.add_argument('--'+key,type=Path,required=True)
 p.add_argument('--task',required=True);a=p.parse_args();source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip();assert not subprocess.check_output(['git','diff','9cde60cff60e1a0b2d4a21019e69eefb1007bd8b','HEAD','--','app','src','tools/solute','tools/vq','reference'],cwd=ROOT)
 space=json.loads(subprocess.check_output([sys.executable,str(a.cleanup),'check-space'],text=True));assert space['ok']
 specs=[('undrained-water8',8,0,0,6,35,'O2'),('head5-water8',8,0,1,5,35,'O2')]
 for opt in ('O0','O2'):
  specs += [('undrained-active-cde8',8,1,0,6,35,opt),('unit8-active-cde7-8','7 8',1,1,8,35,opt),('head5-active-cde9-10','9 10',1,1,5,35,opt),('undrained-water11',11,0,0,6,367,opt),('head5-active-cde8-11','8 11',1,1,5,367,opt)]
 inputs=a.evidence/'vapor-boundary-inputs-v1';inputs.mkdir();jobs=[]
 for label,models,solute,drain,bottom,days,opt in specs:
  name=f'vapor-boundary-{label}-{opt}-v3';folder=inputs/name;shutil.copytree(a.evidence/'vapor-boundary-original-dispatch-v1/models8-solute0-dra0-bottom6',folder);path=folder/'swap.swp';text=path.read_text(encoding='cp1252')
  for key,value in dict(iHWCKmodel=models,SWSOLU=solute,SWDRA=drain,SWBOTB=bottom).items():text=assignment(text,key,value)
  if solute:
   for key,value in dict(CPRE=.02,CDRAIN=.1,SWBOTBC=1,CSEEP=.15).items():text=assignment(text,key,value)
   pattern=r'(?mi)^([ \t]*CMLTB[ \t]*=[ \t]*\n)((?:[ \t]*[-+]?\d[^\n]*\n)+)';matches=list(re.finditer(pattern,text));assert len(matches)==1
   rows=[line.split() for line in matches[0][2].splitlines()];assert len(rows)==2 and all(len(row)==2 for row in rows)
   replacement=matches[0][1]+''.join(' '+row[0]+' 0.25\n' for row in rows);text=text[:matches[0].start()]+replacement+text[matches[0].end():]
  path.write_text(text,encoding='cp1252')
  command=[sys.executable,str(a.cleanup),'allocate','--task',a.task,'--kind','build','--name',name,'--variant',opt,'--source-ref',source,'--recipe',f'vapor_boundary_runtime {models} solute{solute} drainage{drain} bottom{bottom} {opt} {days}days; activeCDE0.25mg/cm3 initial+0.02rain']
  build=Path(json.loads(subprocess.check_output(command,text=True))['path']);assert build.resolve()==(a.work/name).resolve();jobs.append(dict(name=name,input=folder,build=build,opt=opt,days=days,solute=solute))
 q=dict(status='RUNNING',source=source,profiles={},actual_new_contexts=12,canonical_admission=False);lock=threading.Lock()
 def save():
  with lock:(a.evidence/'VAPOR_BOUNDARY_TARGETED_BATCH_V1.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 def run(item):
  name=item['name'];command=[sys.executable,'-B','tests/nomacro_drainage/vapor_boundary_runtime.py','--input',str(item['input']),'--reference-work',str(a.reference_work),'--build-root',str(item['build']),'--output',str(a.evidence/name),'--optimization',item['opt'],'--days',str(item['days'])]
  with (a.evidence/(name+'.stdout.txt')).open('x') as out,(a.evidence/(name+'.stderr.txt')).open('x') as err:result=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=600)
  q['profiles'][name]=dict(returncode=result.returncode);save();result.check_returncode()
  command=[sys.executable,'-B','tests/nomacro_drainage/vapor_boundary_science.py','--profile',str(a.evidence/name),'--reference-work',str(a.reference_work),'--output',str(a.evidence/(name+'-INDEPENDENT.json'))]
  independent=subprocess.run(command,cwd=ROOT,capture_output=True,text=True);(a.evidence/(name+'-INDEPENDENT.stdout.txt')).write_text(independent.stdout);(a.evidence/(name+'-INDEPENDENT.stderr.txt')).write_text(independent.stderr);independent.check_returncode()
  scientific=json.loads((a.evidence/(name+'-INDEPENDENT.json')).read_text());assert scientific['days']==item['days']
  if item['solute']:assert scientific['CDE_initial_stock']>0 and scientific['exact_private_CDE_stocks']>0
  q['profiles'][name]['independent']=scientific['status'];save();print(name,'PASS',flush=True)
 try:
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:list(pool.map(run,jobs))
  assert len(q['profiles'])==12;q['status']='FOUR_NEW_YEAR_367_EIGHT_NEW_SHORT35_ACTIVE_CDE_BOUNDARY_NATIVE5_INDEPENDENT_EXACT_COLD_PASS'
 except Exception as error:q.update(status='FAILED',error=repr(error));raise
 finally:save()
 print(q['status'],flush=True)


if __name__=='__main__':main()
