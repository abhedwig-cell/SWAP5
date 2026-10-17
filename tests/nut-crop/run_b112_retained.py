"""Measured small actual production contracts; no admission inferred."""
from pathlib import Path
import argparse,hashlib,importlib.util,json,os,re,shlex,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--output',required=True,type=Path);p.add_argument('--split-only',action='store_true');a=p.parse_args();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
s=importlib.util.spec_from_file_location('dep',ROOT/'tests/support/augment_bartholomeus_backend_sources.py');dep=importlib.util.module_from_spec(s);s.loader.exec_module(dep)
drivers=['tests/nut-crop/test_b112_retained_split.f90']+([]if a.split_only else['tests/nut-crop/test_b112_retained_day.f90'])
# Explicit existing include authority, also pinned in the result. No provider overrides.
include_authority={'crop_fixture.inc':ROOT/'tests/nut-crop/crop_fixture.inc','material_fixture.inc':ROOT/'tests/nut-material/material_fixture.inc'}
providers={}
for path in sorted((ROOT/'src').rglob('*.f90')):
 for name in dep.MODULE_RE.findall(path.read_text()):
  name=name.lower()
  if name in providers and providers[name]!=path:raise ValueError('duplicate provider '+name)
  providers[name]=path
ordered=[];seen=set();active=set()
def visit(path):
 if path in seen:return
 if path in active:raise ValueError('module cycle '+str(path))
 text=path.read_text()
 if re.search(r'^\s*(?:#|submodule\b)',text,re.I|re.M):raise ValueError('unregistered preprocessing '+str(path))
 for inc in re.findall(r"^\s*include\s+['\"]([^'\"]+)['\"]",text,re.I|re.M):
  if inc not in include_authority:raise ValueError('unregistered include '+inc)
  text+='\n'+include_authority[inc].read_text()
 active.add(path)
 for name in sorted(set(n.lower()for n in dep.USE_RE.findall(text))-dep.INTRINSICS):
  if name not in providers:raise ValueError('unresolved provider '+name)
  if providers[name]!=path:visit(providers[name])
 active.remove(path);seen.add(path);ordered.append(path)
for name in drivers:visit(ROOT/name)
ordered=[p for p in ordered if str(p.relative_to(ROOT))not in drivers]
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];runs={}
def run(cmd,cwd,category):
 cmd=list(map(str,cmd));t=time.perf_counter();r=subprocess.run(cmd,cwd=cwd,capture_output=True);i=len(events)
 for stream in ('stdout','stderr'):(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append({'command':cmd,'category':category,'seconds':time.perf_counter()-t,'returncode':r.returncode,'stdout':f'{i}.stdout','stderr':f'{i}.stderr'});(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode(errors='replace'),r.stderr.decode(errors='replace'));r.check_returncode()
 return r.stdout.decode()
for opt in ('O0','O2'):
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-ffunction-sections','-fdata-sections','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),'-I'+str(ROOT/'tests/nut-crop'),'-I'+str(ROOT/'tests/nut-material')];objects=[];runs[opt]={}
 for i,source in enumerate(ordered):
  obj=b/f'{i}.o';run(FC+flags+['-c',source,'-o',obj],b,'compile');objects.append(obj)
 for name in drivers:
  source=ROOT/name;obj=b/(source.stem+'.o');exe=b/source.stem;run(FC+flags+['-c',source,'-o',obj],b,'driver_compile');run(FC+flags+objects+[obj,'-Wl,--gc-sections','-o',exe],b,'link');runs[opt][source.stem]=run([exe],b,'native')
assert runs['O0']==runs['O2']
result={'status':'B112_SMALL_PRODUCTION_PASS_NOT_ADMITTED','execution_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'runs':runs,'input_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered+[ROOT/n for n in drivers]+[ROOT/'tests/nut-crop/crop_fixture.inc',ROOT/'tests/nut-material/material_fixture.inc',Path(__file__)]},'cost_seconds':{c:sum(e['seconds']for e in events if e['category']==c)for c in {e['category']for e in events}}};(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['cost_seconds'])
