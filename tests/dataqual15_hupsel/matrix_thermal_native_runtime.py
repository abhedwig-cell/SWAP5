"""Execute original complete matrix/heat/solute assertions in exact private views."""
import argparse,json,os,struct,subprocess,sys,time
from pathlib import Path
import matrix_thermal_native_policy as policy
ROOT=policy.ROOT;sha=policy.sha

def worker(a):
 script=a.tree/'tests/nut-sol/run_matrix_thermal.py';raw=script.read_text();source=raw
 if os.name=='nt':source=source.replace(" / 'thermal'", " / 'thermal.exe'")
 ledger=[];real=subprocess.run
 def run(command,*args,**kwargs):
  cmd=list(map(str,command));effective=cmd.copy();compiler=Path(cmd[0]).name.lower()==Path(a.compiler).name.lower();response=None
  if compiler and '-o'in cmd and '-c'not in cmd:
   opt=next(x[1:]for x in cmd if x in ('-O0','-O2'));i=effective.index('-o');effective[i:i]=[str(a.publication/(opt+'.o'))]
   if os.name=='nt':
    effective.insert(1,'-Wl,--stack,67108864');response=a.output.parent/('link-'+str(len(ledger))+'.args');response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in effective[1:])+'\n',encoding='utf-8',newline='\n');actual=[effective[0],'@'+str(response)]
   else:actual=effective
  else:actual=effective
  start=time.monotonic();r=real(actual,*args,**kwargs)
  if compiler:
   ledger.append(dict(declared=cmd,effective=effective,executed=actual,returncode=r.returncode,seconds=time.monotonic()-start,response_sha256=sha(response.read_bytes())if response else None));(a.output.parent/'COMPILER.json').write_text(json.dumps(ledger,indent=2)+'\n')
  return r
 subprocess.run=run;os.environ['FC']=str(a.compiler);os.environ['OMP_NUM_THREADS']='1';sys.argv=[str(script),'--output',str(a.output)]
 (a.output.parent/'RECIPE.json').write_text(json.dumps(dict(original_sha256=sha(raw.encode()),projected_sha256=sha(source.encode()),source_projection=source,platform=os.name,scope='Original physical/numerical/native/refusal assertions unchanged; Windows executable suffix/response/64MiB PE stack and matching C support object are explicit build seams'),indent=2)+'\n')
 exec(compile(source,str(script),'exec'),{'__file__':str(script),'__name__':'__main__'})

def main(a):
 policy.guard();out=a.output.resolve();out.mkdir(parents=True);view=out/'tree';events=[]
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),policy.BASE],cwd=ROOT,check=True,capture_output=True)
 try:
  if a.role=='candidate':(view/policy.SOURCE).write_text(policy.candidate(),encoding='utf-8',newline='\n')
  expected=[policy.SOURCE]if a.role=='candidate'else[];assert subprocess.check_output(['git','diff','--name-only'],cwd=view,text=True).splitlines()==expected
  publication=out/'publication';publication.mkdir();c=publication/'publication.c';c.write_text(policy.before('app/support/restart_publish.c'),encoding='utf-8',newline='\n');cc=subprocess.check_output([str(a.compiler),'-print-prog-name=gcc'],text=True).strip()
  for opt in ('O0','O2'):
   cmd=[cc,'-'+opt,'-std=c11','-c',str(c),'-o',str(publication/(opt+'.o'))];r=subprocess.run(cmd,capture_output=True);events.append(dict(label='C-'+opt,command=cmd,returncode=r.returncode));assert r.returncode==0,r.stderr
  cmd=[sys.executable,'-B',str(Path(__file__).resolve()),'--worker','--tree',str(view),'--publication',str(publication),'--compiler',str(a.compiler),'--output',str(out/'physical')];start=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=1800)
  for stream in ('stdout','stderr'):(out/('physical.'+stream)).write_bytes(getattr(r,stream))
  events.append(dict(label='physical',command=cmd,returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
  record=dict(role=a.role,platform=os.name,source_sha256=sha((view/policy.SOURCE).read_bytes()),publication_sha256=sha(c.read_bytes()),events=events,production_admission=False,whole_scientific_admission=False)
  if r.returncode:
   record.update(status='ACTUAL_ORIGINAL_PLATFORM_FAILURE_RETAINED'if a.role=='incumbent'else'ACTUAL_CANDIDATE_FAILURE_REQUIRES_DIAGNOSIS',returncode=r.returncode)
  else:
   report=json.loads((out/'physical/result.json').read_text());assert report['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED';record.update(status='ACTUAL_COMPLETE_MATRIX_THERMAL_O0_O2_NATIVE_PHYSICAL_PASS',physical=report)
   if os.name=='nt':
    for opt in ('O0','O2'):
     blob=(out/'physical'/opt/'thermal.exe').read_bytes();pe=struct.unpack_from('<I',blob,0x3c)[0];assert blob[pe:pe+4]==b'PE\0\0'and struct.unpack_from('<Q',blob,pe+24+72)[0]==67108864
  (out/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n');print(record['status'],flush=True)
  if a.role=='candidate':assert r.returncode==0,r.stderr[-4000:]
 finally:
  assert view.parent==out and view.name=='tree';subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,check=True,capture_output=True)
 policy.guard()
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--worker',action='store_true');p.add_argument('--tree',type=Path);p.add_argument('--publication',type=Path);p.add_argument('--role',choices=('incumbent','candidate'));p.add_argument('--compiler',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.compiler=a.compiler.resolve();a.output=a.output.resolve();worker(a)if a.worker else main(a)
