"""Requalify current HeadCalc/NUT composition using byte-checked unchanged objects.

All assertions of the incumbent HIST runner execute unchanged. Only compilation
receipts for identical input/flags are reused. HeadCalc, links and every native
process execute freshly. Original receipts and compiler/object identities remain
explicit; reused compilation is never presented as fresh execution.
"""
from pathlib import Path
import argparse,ast,hashlib,json,os,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--prior',required=True,type=Path);p.add_argument('--output',required=True,type=Path)
a=p.parse_args();OLD=a.prior.resolve();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=json.loads((OLD/'result.json').read_text());assert report['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
recipe=ROOT/'tests/nut-crop/run_hist_complete.py'
assert sha(recipe)==report['input_sha256'][str(recipe.relative_to(ROOT))]
headcalc='src/legacy/b1_10_port/headcalc.f90'
drift={p for p,h in report['input_sha256'].items()if sha(ROOT/p)!=h}
assert drift=={headcalc},('unqualified provider changes',drift)
previous=json.loads((OLD/'events.json').read_text());assert all(e['returncode']==0 for e in previous)
by_command={tuple(e['command']):e for e in previous if e['category']=='compile'}
assert len(by_command)==654
artifacts={str(p.relative_to(OLD)):sha(p)for p in OLD.rglob('*')if p.suffix in ['.o','.mod']}
for name,h in artifacts.items():
 q=OUT/name;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(OLD/name,q);assert sha(q)==h
compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0]
assert compiler==report['compiler']
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
manifest=dict(prior_result_sha256=sha(OLD/'result.json'),prior_events_sha256=sha(OLD/'events.json'),
 original_runner_sha256=sha(recipe),changed_inputs=list(drift),prior_artifact_sha256=artifacts,
 compiler=compiler,reused_compile_events=0,fresh_compile_events=0,fresh_native_events=0)
ns=dict(__file__=str(recipe),__name__='nut_limits_current_composition');fresh=[]
def run(args,b,category):
 cmd=list(map(str,args));i=len(ns['events'])
 old_cmd=tuple(v.replace(str(OUT),str(OLD))for v in cmd)
 if category=='compile'and '-c'in cmd and cmd[cmd.index('-c')+1]!=str(ROOT/headcalc):
  e=by_command[old_cmd]
  source=Path(cmd[cmd.index('-c')+1]);oldsource=Path(old_cmd[old_cmd.index('-c')+1])
  if source.is_relative_to(ROOT):assert sha(source)==report['input_sha256'][str(source.relative_to(ROOT))]
  else:assert source.read_bytes()==oldsource.read_bytes(),'generated provider drift'
  obj=Path(cmd[cmd.index('-o')+1]);assert sha(obj)==artifacts[str(obj.relative_to(OUT))]
  for stream in ['stdout','stderr']:
   dest=f'{i:04d}.{stream}';(OUT/dest).write_bytes((OLD/e[stream]).read_bytes())
  event={**e,'stdout':f'{i:04d}.stdout','stderr':f'{i:04d}.stderr','receipt_scope':'REUSED_IDENTICAL_PRIOR_COMPILE',
   'current_object_path':str(obj),'current_object_sha256':sha(obj)}
  manifest['reused_compile_events']+=1;out=(OUT/event['stdout']).read_text()
 else:
  start=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True)
  event=dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-start,receipt_scope='FRESH_CURRENT_EXECUTION')
  for stream in ['stdout','stderr']:
   dest=f'{i:04d}.{stream}';(OUT/dest).write_bytes(getattr(r,stream));event[stream]=dest
  if category=='compile':manifest['fresh_compile_events']+=1
  if category in ['native','restart_native','trace_native']:manifest['fresh_native_events']+=1
  fresh.append(event);out=r.stdout.decode()
 ns['events'].append(event);(OUT/'events.json').write_text(json.dumps(ns['events'],indent=2)+'\n')
 (OUT/'REUSE.json').write_text(json.dumps(manifest,indent=2)+'\n')
 if event['returncode']:raise RuntimeError(str(event)+out+(OUT/event['stderr']).read_text())
 return out
text=recipe.read_text();node=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name=='run')
lines=text.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_composition_run\n']
text=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1).replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
ns['_composition_run']=run
os.environ['N_HIST_RESULT_DIR']=str(OUT)
sys.path.insert(0,str(ROOT/'tests/nut-crop'));exec(compile(text,str(recipe),'exec'),ns)
assert manifest['fresh_compile_events']==2 and manifest['reused_compile_events']==652
current=json.loads((OUT/'result.json').read_text())
assert current['results']==report['results'],'incumbent complete HIST physical results drift'
manifest.update(all_original_assertions_completed=True,complete_incumbent_results_exact=True,
 fresh_seconds={c:sum(e['seconds']for e in fresh if e['category']==c)for c in {e['category']for e in fresh}},
 current_input_sha256=current['input_sha256'],current_artifact_sha256={str(p.relative_to(OUT)):sha(p)for p in OUT.rglob('*')if p.suffix in ['.o','.mod']},
 current_execution_commit=current['execution_commit'])
(OUT/'REUSE.json').write_text(json.dumps(manifest,indent=2)+'\n');print('NUT_LIMITS_CURRENT_HEADCALC_HIST_O0_O2_EXACT_PASS')
