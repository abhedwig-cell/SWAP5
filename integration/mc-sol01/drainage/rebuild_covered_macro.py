"""Rebuild changed actual production providers and their transitive consumers."""
import argparse,hashlib,json,re,shutil,subprocess,time,runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
p=argparse.ArgumentParser();p.add_argument('--macro-heat',action='store_true');p.add_argument('--macro-initial',action='store_true');p.add_argument('--base',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();base=a.base.resolve();out=a.output.resolve();out.mkdir();b=json.loads((base/'build-complete.json').read_text());before=json.loads(json.dumps(b));events=[]
if not(base/'legacy_swp_original.f90').exists():runpy.run_path(str(ROOT/'tools/solute/legacy_reader_sources.py'))['materialize'](ROOT,base)
for p,h in b['generated_input_sha256'].items():assert sha(base/p)==h,p
shutil.copyfile(base/'legacy_swp_original.f90',out/'legacy_swp_original.f90')
shutil.copytree(base/'historical-input',out/'historical-input')
for x in base.iterdir():
 if x.is_file()and(x.suffix in ['.o','.mod']or x.name=='libttutil.a'):shutil.copyfile(x,out/x.name)
changed={p for p,h in b['input_sha256'].items()if sha(ROOT/p)!=h};assert changed and changed<={'src/runtime/mod_macropore_single_column_runtime.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',*(['src/runtime/mod_fmr_restart_state_contract.f90'] if a.macro_heat else []),*(['src/process/macropore/mod_macropore_dynamic_shrinkage.f90','src/process/macropore/mod_macropore_standard_storage.f90','tools/solute/legacy_reader_sources.py']if a.macro_initial else[])},changed
source_hashes={p:sha(ROOT/p)for p in b['input_sha256']}
modules=set();fresh=[];reused=[]
for e in b['events']:
 if e['category']!='compile':continue
 cmd=e['command'];src=Path(cmd[cmd.index('-c')+1]);path=str(src.relative_to(ROOT))if src.is_relative_to(ROOT)else str(src)
 text=src.read_text();imports=set(m.lower()for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',text,re.M|re.I));obj=out/Path(cmd[-1]).name
 if path in changed or imports&modules:
  modules.update(x.lower()for x in re.findall(r'^\s*module\s+(\w+)\s*$',text,re.M|re.I));cmd=[x.replace(str(base),str(out))for x in cmd];t=time.monotonic();cp=subprocess.run(cmd,cwd=out,capture_output=True);label='compile-'+str(len(events));(out/(label+'.stdout')).write_bytes(cp.stdout);(out/(label+'.stderr')).write_bytes(cp.stderr);events.append(dict(category='compile',command=cmd,seconds=time.monotonic()-t,returncode=cp.returncode));(out/'rebuild-events.json').write_text(json.dumps(events,indent=2)+'\n');assert cp.returncode==0,cp.stderr.decode()[-2000:];fresh.append(path)
 else:reused.append({'path':path,'object_sha256':sha(obj)})
link=[x.replace(str(base),str(out))for x in next(e['command']for e in b['events']if e['category']=='link')];t=time.monotonic();cp=subprocess.run(link,cwd=out,capture_output=True);(out/'link.stderr').write_bytes(cp.stderr);events.append(dict(category='link',command=link,seconds=time.monotonic()-t,returncode=cp.returncode));assert cp.returncode==0,cp.stderr.decode()[-2000:]
assert all(sha(ROOT/p)==h for p,h in source_hashes.items()),'source changed during rebuild'
b.update(status='BUILT',candidate=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),flags=[x.replace(str(base),str(out))for x in b['flags']],input_sha256={p:sha(ROOT/p)for p in b['input_sha256']},events=[dict(e,command=[x.replace(str(base),str(out))for x in e['command']])for e in b['events']],executable_sha256=sha(out/'swap5_solute_column'),rebuild_events=events,recompiled_sources=fresh,reused_objects=reused,predecessor_build=before)
(out/'build-complete.json').write_text(json.dumps(b,indent=2)+'\n');print(json.dumps({'rebuilt':len(fresh),'reused':len(reused),'seconds':sum(e['seconds']for e in events)}))
