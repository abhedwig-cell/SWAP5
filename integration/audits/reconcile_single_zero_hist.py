"""Resume the failed O0 fixture attempt with exact unchanged compile closures."""
from pathlib import Path
import argparse,ast,hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--prior',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--literal',required=True,type=Path);a=p.parse_args()
old=a.prior.resolve();out=a.output.resolve();out.mkdir();events=[]
BASE='4689d335';FIXTURE='tests/nut-crop/test_b112_retained_joint.f90'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
assert subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src','tests'],cwd=ROOT,text=True).splitlines()==[FIXTURE]
prior=json.loads((old/'events.json').read_text());assert prior[-1]['category']=='native'and prior[-1]['returncode']!=0
assert b'stage singular organic trial'in(old/prior[-1]['stdout']).read_bytes()
compiled={Path(e['command'][e['command'].index('-c')+1]):e for e in prior if e['category']=='compile'}
artifacts={str(p.relative_to(old)):sha(p)for p in old.rglob('*')if p.suffix in ['.o','.mod']}
for name,h in artifacts.items():
 d=out/name;d.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(old/name,d);assert sha(d)==h
counts={'fresh':0,'reused':0}
def normalized(cmd):return [v.replace(str(out),'<BUILD>').replace(str(old),'<BUILD>')for v in cmd[1:]]
def run(args,b,category):
 cmd=list(map(str,args));i=len(events);reuse=False
 if category=='compile'and'-O0'in cmd:
  src=Path(cmd[cmd.index('-c')+1]);previous=src if src.is_relative_to(ROOT)or src==a.literal.resolve()else old/'O0'/src.name
  e=compiled[previous];assert normalized(cmd)==normalized(e['command'])
  if src!=ROOT/FIXTURE:
   if src.is_relative_to(ROOT):assert src.read_bytes()==subprocess.check_output(['git','show',BASE+':'+str(src.relative_to(ROOT))],cwd=ROOT)
   else:assert src.read_bytes()==previous.read_bytes()
   obj=Path(cmd[cmd.index('-o')+1]);assert sha(obj)==artifacts[str(obj.relative_to(out))]
   reuse=True;counts['reused']+=1
   for k in ['stdout','stderr']:(out/f'{i:04d}.{k}').write_bytes((old/e[k]).read_bytes())
   stdout=(old/e['stdout']).read_text();row=dict(command=cmd,category=category,returncode=0,seconds=0.,receipt_scope='REUSED_EXACT_FAILED_ATTEMPT_UNCHANGED_CLOSURE',object_sha256=sha(obj))
 if not reuse:
  t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True,timeout=180)
  for k in ['stdout','stderr']:(out/f'{i:04d}.{k}').write_bytes(getattr(r,k))
  row=dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,receipt_scope='FRESH_CURRENT_EXECUTION');stdout=r.stdout.decode()
  if category=='compile':counts['fresh']+=1
 row.update(stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr');events.append(row);(out/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert row['returncode']==0,stdout+(out/row['stderr']).read_text()
 return stdout
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
recipe=ROOT/'tests/nut-crop/run_hist_complete.py';s=recipe.read_text();node=next(n for n in ast.parse(s).body if isinstance(n,ast.FunctionDef)and n.name=='run');lines=s.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_current_run\n'];s=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1).replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
os.environ['N_HIST_RESULT_DIR']=str(out);os.environ['REPRODUCTIVE_LITERAL_FILE']=str(a.literal.resolve());sys.path.insert(0,str(ROOT/'tests/nut-crop'))
exec(compile(s,str(recipe),'exec'),dict(__file__=str(recipe),__name__='current_hist',_current_run=run))
assert counts['fresh']+counts['reused']==654
(out/'REUSE.json').write_text(json.dumps(dict(**counts,source_base=BASE,changed_inputs=[FIXTURE],original_recipe_sha256=sha(recipe),old_artifacts=artifacts,all_original_assertions_completed=True),indent=2)+'\n')
print(json.dumps(counts))
