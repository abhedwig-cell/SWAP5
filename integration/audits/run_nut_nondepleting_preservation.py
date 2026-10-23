"""Unchanged HIST assertions, fresh changed provider closure and all native runs."""
from pathlib import Path
import argparse,ast,hashlib,json,os,re,resource,shutil,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--prior',required=True,type=Path);p.add_argument('--output',required=True,type=Path);a=p.parse_args()
OLD=a.prior.resolve();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report=json.loads((OLD/'result.json').read_text());assert report['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
recipe=ROOT/'tests/nut-crop/run_hist_complete.py'
drift={p for p,h in report['input_sha256'].items()if sha(ROOT/p)!=h}
expected=set(json.loads((ROOT/'integration/mc-nut01/nondepleting_top/STATUS.json').read_text())['production_changes'])
headcalc='src/legacy/b1_10_port/headcalc.f90'
if headcalc in drift:
 admitted=json.loads((OLD.parent/'nut-limits-current-hist/result.json').read_text())
 assert sha(ROOT/headcalc)==admitted['input_sha256'][headcalc], 'changed admitted HeadCalc'
 expected.add(headcalc)
assert drift==expected,(drift,expected)
previous=json.loads((OLD/'events.json').read_text());assert all(e['returncode']==0 for e in previous)
by_command={tuple(e['command']):e for e in previous if e['category']=='compile'};assert len(by_command)==654
sources={}
for e in by_command.values():
 cmd=e['command'];path=Path(cmd[cmd.index('-c')+1]);assert path.is_file();sources[str(path)]=path.read_text()
providers={}
for p,s in sources.items():
 for mod in re.findall(r'^\s*module\s+(\w+)\s*$',s,re.M|re.I):providers[mod.lower()]=p
impacted={str(ROOT/p)for p in drift}
while True:
 added={p for p,s in sources.items()if any(providers.get(m.lower())in impacted for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s,re.M|re.I))}
 if added<=impacted:break
 impacted|=added
artifacts={str(p.relative_to(OLD)):sha(p)for p in OLD.rglob('*')if p.suffix in ['.o','.mod']}
for n,h in artifacts.items():
 q=OUT/n;q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(OLD/n,q);assert sha(q)==h
compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0];assert compiler==report['compiler']
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
manifest=dict(prior_result_sha256=sha(OLD/'result.json'),prior_events_sha256=sha(OLD/'events.json'),original_runner_sha256=sha(recipe),changed_inputs=sorted(drift),transitive_recompile_sources=sorted(impacted),prior_artifact_sha256=artifacts,compiler=compiler,reused_compile_events=0,fresh_compile_events=0,fresh_native_events=0)
ns=dict(__file__=str(recipe),__name__='nut_nondepleting_preservation');fresh=[]
def run(args,b,category):
 cmd=list(map(str,args));i=len(ns['events']);old_cmd=tuple(v.replace(str(OUT),str(OLD))for v in cmd)
 oldsource=old_cmd[old_cmd.index('-c')+1]if category=='compile'and'-c'in cmd else None
 if category=='compile'and oldsource not in impacted:
  e=by_command[old_cmd];source=Path(cmd[cmd.index('-c')+1])
  if source.is_relative_to(ROOT):assert sha(source)==report['input_sha256'][str(source.relative_to(ROOT))]
  else:assert source.read_bytes()==Path(oldsource).read_bytes(),'generated source changed'
  obj=Path(cmd[cmd.index('-o')+1]);assert sha(obj)==artifacts[str(obj.relative_to(OUT))]
  for k in ['stdout','stderr']:(OUT/f'{i:04d}.{k}').write_bytes((OLD/e[k]).read_bytes())
  event={**e,'stdout':f'{i:04d}.stdout','stderr':f'{i:04d}.stderr','receipt_scope':'REUSED_IDENTICAL_SOURCE_FLAGS_AND_UNCHANGED_MODULE_CLOSURE','object_sha256':sha(obj)}
  manifest['reused_compile_events']+=1;out=(OUT/event['stdout']).read_text()
 else:
  t=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True,timeout=120)
  event=dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-t,receipt_scope='FRESH_CURRENT_EXECUTION')
  for k in ['stdout','stderr']:(OUT/f'{i:04d}.{k}').write_bytes(getattr(r,k));event[k]=f'{i:04d}.{k}'
  manifest['fresh_compile_events']+=category=='compile';manifest['fresh_native_events']+=category in ['native','restart_native','trace_native']
  fresh.append(event);out=r.stdout.decode()
 ns['events'].append(event);(OUT/'events.json').write_text(json.dumps(ns['events'],indent=2)+'\n');(OUT/'REUSE.json').write_text(json.dumps(manifest,indent=2)+'\n')
 if event['returncode']:raise RuntimeError(str(event)+out+(OUT/event['stderr']).read_text())
 return out
text=recipe.read_text();node=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name=='run')
lines=text.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_preservation_run\n']
text=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1).replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
ns['_preservation_run']=run;os.environ['N_HIST_RESULT_DIR']=str(OUT)
sys.path.insert(0,str(ROOT/'tests/nut-crop'));exec(compile(text,str(recipe),'exec'),ns)
current=json.loads((OUT/'result.json').read_text());assert current['results']==report['results'],'default HIST physical drift'
assert manifest['fresh_compile_events']+manifest['reused_compile_events']==654 and manifest['fresh_native_events']==78
manifest.update(all_original_assertions_completed=True,complete_incumbent_results_exact=True,current_execution_commit=current['execution_commit'],fresh_seconds={c:sum(e['seconds']for e in fresh if e['category']==c)for c in {e['category']for e in fresh}})
(OUT/'REUSE.json').write_text(json.dumps(manifest,indent=2)+'\n');print(json.dumps({k:v for k,v in manifest.items()if k!='prior_artifact_sha256'}))
