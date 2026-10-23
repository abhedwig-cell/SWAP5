"""Execute every incumbent HIST assertion; reuse only unchanged compile closures."""
import argparse,ast,hashlib,json,os,re,resource,shutil,subprocess,sys,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('--prior',type=Path,required=True);p.add_argument('--literal',type=Path,required=True)
 p.add_argument('--output',type=Path,required=True);p.add_argument('--prior-compiler',type=Path,required=True);a=p.parse_args()
 old=a.prior.resolve();out=a.output.resolve();out.mkdir();prior=json.loads((old/'result.json').read_text())
 assert prior['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
 assert sha(a.literal)==prior['literal_sha256']
 fc=shutil.which('gfortran');assert fc
 version=subprocess.check_output([fc,'--version'],text=True).splitlines()[0];assert version==prior['compiler']
 toolchain={}
 for option in ['-print-prog-name=f951','-print-prog-name=as','-print-prog-name=ld','-print-file-name=libgfortran.a','-print-file-name=libgcc.a','-print-file-name=libgomp.a']:
  def resolved(command):
   path=subprocess.check_output([*command,option],text=True).strip();return Path(shutil.which(path)or path).resolve()
  current=resolved([fc]);previous=resolved(['sh',str(a.prior_compiler)])
  assert current.is_file()and previous.is_file()and sha(current)==sha(previous),('compiler identity',option)
  toolchain[option]=dict(sha256=sha(current),current=str(current),previous=str(previous))
 es=json.loads((old/'events.json').read_text());assert all(e['returncode']==0 for e in es)
 drift={p for p,h in prior['input_sha256'].items()if sha(ROOT/p)!=h}
 permitted={'src/transaction/mod_transaction_reference.f90','src/process/mod_pond_water_temporal_difference.f90',
  'src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_b111_pond_joint_application.f90'}
 assert drift and drift<=permitted,('unexpected HIST drift',drift)
 def key(path):
  for marker in ['/src/','/tests/']:
   if marker in str(path):return marker[1:]+str(path).split(marker,1)[1]
  return Path(path).name
 compiles={};sources={}
 for e in es:
  if e['category']!='compile':continue
  cmd=e['command'];opt=next(v[1:]for v in cmd if v in ['-O0','-O2']);k=key(cmd[cmd.index('-c')+1]);assert(opt,k)not in compiles
  compiles[opt,k]=e;path=ROOT/k if k.startswith(('src/','tests/'))else old/opt/Path(k).name
  if not path.exists():path=a.literal.resolve();assert path.name==k
  text=path.read_text();assert k not in sources or sources[k]==text;sources[k]=text
 assert len(compiles)==654
 providers={m.lower():k for k,s in sources.items()for m in re.findall(r'^\s*module\s+(\w+)\s*$',s,re.M|re.I)}
 impacted=set(drift)
 while True:
  more={k for k,s in sources.items()if any(providers.get(m.lower())in impacted for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',s,re.M|re.I))}
  if more<=impacted:break
  impacted|=more
 artifacts={str(p.relative_to(old)):sha(p)for p in old.rglob('*')if p.suffix in ['.o','.mod']}
 for name,h in artifacts.items():
  dest=out/name;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(old/name,dest);assert sha(dest)==h
 events=[];counts=dict(fresh_compile_events=0,reused_compile_events=0,fresh_native_events=0)
 def flags(cmd):return [v if not v.startswith(('-I','-J'))else v[:2]+('tests/'+v.split('/tests/',1)[1]if'/tests/'in v else'BUILD')for v in cmd[1:cmd.index('-c')]]
 def run(args,b,category):
  cmd=list(map(str,args));idx=len(events);reuse=False
  if category=='compile':
   opt=next(v[1:]for v in cmd if v in ['-O0','-O2']);src=Path(cmd[cmd.index('-c')+1]);k=key(src);e=compiles[opt,k]
   assert flags(cmd)==flags(e['command']),'changed compile flags'
   obj=Path(cmd[cmd.index('-o')+1]);assert obj.name==Path(e['command'][-1]).name
   if k not in impacted:
    if k.startswith(('src/','tests/')):assert sha(src)==prior['input_sha256'][k]
    else:
     expected=old/opt/src.name
     if not expected.exists():expected=a.literal.resolve()
     assert src.read_bytes()==expected.read_bytes()
    assert sha(obj)==artifacts[str(obj.relative_to(out))];reuse=True;counts['reused_compile_events']+=1
    for stream in ['stdout','stderr']:(out/f'{idx:04d}.{stream}').write_bytes((old/e[stream]).read_bytes())
    row=dict(command=cmd,category=category,returncode=0,seconds=0.,receipt_scope='REUSED_EXACT_SOURCE_FLAGS_TOOLCHAIN_UNCHANGED_CLOSURE',object_sha256=sha(obj));stdout=(old/e['stdout']).read_text()
  if not reuse:
   start=time.perf_counter();cp=subprocess.run(cmd,cwd=b,capture_output=True,timeout=180)
   for stream in ['stdout','stderr']:(out/f'{idx:04d}.{stream}').write_bytes(getattr(cp,stream))
   row=dict(command=cmd,category=category,returncode=cp.returncode,seconds=time.perf_counter()-start,receipt_scope='FRESH_CURRENT_EXECUTION');stdout=cp.stdout.decode()
   if category=='compile':counts['fresh_compile_events']+=1
   if category in ['native','restart_native','trace_native']:counts['fresh_native_events']+=1
  row.update(stdout=f'{idx:04d}.stdout',stderr=f'{idx:04d}.stderr');events.append(row);(out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
  assert row['returncode']==0,stdout+(out/row['stderr']).read_text();return stdout
 resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
 recipe=ROOT/'tests/nut-crop/run_hist_complete.py';text=recipe.read_text();node=next(n for n in ast.parse(text).body if isinstance(n,ast.FunctionDef)and n.name=='run')
 lines=text.splitlines(True);lines[node.lineno-1:node.end_lineno]=['run=_current_run\n'];text=''.join(lines).replace('OUT.mkdir(exist_ok=False)','OUT.mkdir(exist_ok=True)',1).replace('b=OUT/opt;b.mkdir()','b=OUT/opt;b.mkdir(exist_ok=True)',1)
 os.environ['N_HIST_RESULT_DIR']=str(out);os.environ['REPRODUCTIVE_LITERAL_FILE']=str(a.literal.resolve());sys.path.insert(0,str(ROOT/'tests/nut-crop'))
 exec(compile(text,str(recipe),'exec'),dict(__file__=str(recipe),__name__='perf01_current_hist',_current_run=run))
 current=json.loads((out/'result.json').read_text());assert current['results']==prior['results']
 assert counts['fresh_compile_events']+counts['reused_compile_events']==654 and counts['fresh_native_events']==78
 (out/'REUSE.json').write_text(json.dumps(dict(**counts,status='TYPED_CURRENT_HIST_ALL_ASSERTIONS_AND_ENDPOINTS_EXACT',changed_inputs=sorted(drift),transitive_recompile_sources=sorted(impacted),
  toolchain_identity=toolchain,prior_result_sha256=sha(old/'result.json'),prior_result=prior,original_recipe_sha256=sha(recipe),old_artifacts=artifacts,all_original_assertions_completed=True),indent=2)+'\n')
 print(json.dumps(counts))
if __name__=='__main__':main()
