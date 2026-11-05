"""Execute original native model assertions with explicit Windows platform build seams."""
import argparse,hashlib,json,os,struct,subprocess,sys,time
from pathlib import Path
import generation_publication_policy as policy
ROOT=policy.ROOT;sha=policy.sha

def projected(raw,name):
 s=raw
 if os.name=='nt':
  s=s.replace(',resource,',',')
  if name=='run_accepted_output.py':
   a=s.index('stack_before=resource.getrlimit');z=s.index('prior=[]',a);s=s[:a]+'# Windows stack is allocated in the actual PE link; no POSIX resource claim.\n'+s[z:]
  else:s='\n'.join(line for line in s.splitlines()if not(line.startswith('resource.setrlimit(')or line.startswith('soft,hard=resource.getrlimit(')))+'\n'
  if name in ('run_joint_output_generation.py','run_saved_output.py'):
   lines=s.splitlines(True);s=''.join(line for line in lines if not(line.startswith("run(['cc','-shared'")or line.startswith("preload=OUT/")))
   a=s.index(' crashes={}\n');z=s.index(' results[opt]=',a);s=s[:a]+' crashes={} # POSIX SIGSTOP/SIGKILL is separately replaced by real Windows event/termination gates.\n'+s[z:]
   s=s.replace("status='JOINT_OUTPUT_AUTOMATIC_ATOMIC_GENERATION_O0_O2_PASS'","status='WINDOWS_JOINT_NATIVE_ASSERTIONS_PASS_TERMINATION_GATE_SEPARATE'").replace("status='SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS'","status='WINDOWS_SAVED_NATIVE_ASSERTIONS_PASS_TERMINATION_GATE_SEPARATE'")
 return s

def worker(args):
 view=args.source_tree.resolve();script=view/'tests/nut-output'/args.recipe;out=args.output.resolve();raw=script.read_text();source=projected(raw,args.recipe)
 ledger=out.parent/(out.name+'-EFFECTIVE_COMPILER.json');calls=[];real_run=subprocess.run;fc=Path(args.compiler).resolve()
 def run(command,*a,**k):
  cmd=list(map(str,command));effective=cmd.copy();is_fc=Path(cmd[0]).name.lower()==fc.name.lower()
  if is_fc and '-o'in cmd and '-c'not in cmd:
   opt=next(x[1:]for x in cmd if x in ('-O0','-O2'));obj=args.publication.resolve()/(opt+'.o');assert obj.is_file()
   index=effective.index('-o');effective[index:index]=[str(obj)]
   if os.name=='nt':effective.insert(1,'-Wl,--stack,67108864')
  start=time.monotonic();r=real_run(effective,*a,**k)
  if is_fc:
   stream=lambda x:x.encode()if isinstance(x,str)else(x or b'')
   calls.append(dict(declared_command=cmd,effective_command=effective,returncode=r.returncode,seconds=time.monotonic()-start,stdout_sha256=sha(stream(r.stdout)),stderr_sha256=sha(stream(r.stderr))))
   ledger.write_text(json.dumps(calls,indent=2)+'\n')
  return r
 subprocess.run=run;os.environ['FC']=str(fc);os.environ['OMP_NUM_THREADS']='1'
 cli=['--output',str(out)]
 for key in ('physical','csv','cold'):
  if getattr(args,key):cli+=['--'+key,str(getattr(args,key).resolve())]
 sys.argv=[str(script),*cli];sys.path.insert(0,str(view/'tests/nut-crop'))
 (out.parent/(out.name+'-RECIPE.json')).write_text(json.dumps(dict(original_recipe=str(script),original_sha256=sha(raw.encode()),projected_sha256=sha(source.encode()),platform=os.name,source_projection=source,scope='Only Windows stack/resource/unsupported POSIX process instrumentation; all physical/native/invalid assertions retained',windows_termination_gate_separate=os.name=='nt'and args.recipe in ('run_joint_output_generation.py','run_saved_output.py')),indent=2)+'\n')
 exec(compile(source,str(script),'exec'),{'__file__':str(script),'__name__':'actual_platform_qualification'})
 if os.name=='nt':
  for call in calls:
   cmd=call['effective_command']
   if '-o'in cmd and '-c'not in cmd and call['returncode']==0:
    exe=Path(cmd[cmd.index('-o')+1]);blob=exe.read_bytes();pe=struct.unpack_from('<I',blob,0x3c)[0];assert blob[pe:pe+4]==b'PE\0\0'and struct.unpack_from('<H',blob,pe+24)[0]==0x20b
    assert struct.unpack_from('<Q',blob,pe+24+72)[0]==67108864,'actual Windows stack reserve differs'

def main(args):
 policy.guard();out=args.output.resolve();out.mkdir(parents=True);view=out/'tree';subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),policy.BASE],cwd=ROOT,check=True,capture_output=True)
 events=[];results={}
 try:
  if args.role=='candidate':
   for n in policy.SOURCES:(view/n).write_text(policy.candidate(n),encoding='utf-8',newline='\n')
   (view/policy.C).write_text(policy.candidate_c(),encoding='utf-8',newline='\n')
  expected=set([*policy.SOURCES,policy.C])if args.role=='candidate'else set();assert set(subprocess.check_output(['git','diff','--name-only'],cwd=view,text=True).splitlines())==expected
  pub=out/'publication';pub.mkdir();source=pub/'publication.c';source.write_text(policy.candidate_c()if args.role=='candidate'else policy.before(policy.C),encoding='utf-8',newline='\n')
  cc=subprocess.check_output([str(args.compiler.resolve()),'-print-prog-name=gcc'],text=True).strip()
  for opt in ('O0','O2'):
   command=[cc,'-'+opt,'-std=c11','-c',str(source),'-o',str(pub/(opt+'.o'))];r=subprocess.run(command,capture_output=True)
   for stream in ('stdout','stderr'):(pub/(opt+'.'+stream)).write_bytes(getattr(r,stream))
   events.append(dict(label='publication-'+opt,command=command,returncode=r.returncode));assert r.returncode==0,r.stderr
  steps=[('accepted','run_accepted_output.py',[]),('csv','run_accepted_output_csv.py',['--physical',out/'accepted']),('joint','run_joint_output_generation.py',['--physical',out/'accepted','--csv',out/'csv']),('cold','run_native_output_project.py',[]),('saved','run_saved_output.py',['--cold',out/'cold'])]
  for label,recipe,more in steps:
   cmd=[sys.executable,'-B',str(Path(__file__).resolve()),'--worker','--source-tree',str(view),'--recipe',recipe,'--compiler',str(args.compiler.resolve()),'--publication',str(pub),'--output',str(out/label),*map(str,more)];start=time.monotonic();r=subprocess.run(cmd,cwd=ROOT,capture_output=True,timeout=1800)
   for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(r,stream))
   events.append(dict(label=label,command=cmd,returncode=r.returncode,seconds=time.monotonic()-start));(out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
   if r.returncode:
    if args.role=='incumbent'and os.name=='nt'and label in ('joint','cold','saved'):
     results[label]=dict(status='ACTUAL_ORIGINAL_WINDOWS_PUBLICATION_FAILURE_RETAINED',returncode=r.returncode);break
    raise AssertionError((label,r.stdout[-2000:],r.stderr[-5000:]))
   results[label]=json.loads((out/label/'result.json').read_text())
  (out/'RESULT.json').write_text(json.dumps(dict(status='FULL_PRIVATE_PLATFORM_MODEL_EXECUTION_COMPLETE'if args.role=='candidate'else'ORIGINAL_PLATFORM_MODEL_OBSERVATIONS_COMPLETE',role=args.role,platform=os.name,results=results,events=events,source_sha256={n:sha((view/n).read_bytes())for n in [*policy.SOURCES,policy.C]},production_source_changed=False,production_admission=False,whole_scientific_admission=False,windows_termination_qualification_pending=os.name=='nt'),indent=2)+'\n');print('Actual original model/receipt/native observations complete',args.role)
 finally:
  assert view.parent==out and view.name=='tree';subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,check=True,capture_output=True)
 policy.guard()
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--role',choices=('incumbent','candidate'));p.add_argument('--worker',action='store_true');p.add_argument('--source-tree',type=Path);p.add_argument('--recipe');p.add_argument('--publication',type=Path)
 for key in ('physical','csv','cold'):p.add_argument('--'+key,type=Path)
 args=p.parse_args();worker(args)if args.worker else main(args)
