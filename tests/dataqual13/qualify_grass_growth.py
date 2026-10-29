"""Original grass input, original compiled biomass oracle, current crop owners."""
import hashlib,json,re,subprocess,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT.parent/'dq13-grass-growth-d';out.mkdir(exist_ok=False)
ref=ROOT.parent/'dq13-reference431/providers';original=(ref/'selected/wofost.f90').read_text();oracle=out/'original_wofost.f90';oracle.write_text(original.replace('   private\n','   private\n   public :: read_wofost,initialize_wofost,initialize_grass,update_dvs_rate,update_wofost,r_act\n',1))
shutil.copyfile(ROOT/'reference/swap-4.3.1/projects/2.grassgrowth/grass.crp',out/'grass.crp')
driver=ROOT/'tests/dataqual13/grass_growth_oracle_driver.f90';mapping={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=p:visit(mapping[name.lower()])
 ordered.append(p)
visit(driver);ordered.remove(driver);events=[]
source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered+[driver]}
def run(cmd,**kw):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True,**kw);events.append(dict(command=list(map(str,cmd)),seconds=time.perf_counter()-t,returncode=r.returncode));(out/(str(len(events))+'.stderr')).write_bytes(r.stderr);(out/'EVENTS.json').write_text(json.dumps(events,indent=2))
 if r.returncode:raise RuntimeError(r.stderr.decode()+r.stdout.decode())
 return r.stdout
fc='/usr/bin/x86_64-linux-gnu-gfortran-13'
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(f),'-J'+str(f),'-I'+str(ref/'swobj'),'-I'+str(ref/'ttobj')];objs=[]
 for i,p in enumerate(ordered+[oracle]):
  obj=f/(str(i)+'.o');run([fc,*flags,'-c',p,'-o',obj]);assert obj.stat().st_size>0;objs.append(obj)
 original_objects=[p for p in(ref/'swobj').glob('*.o')if p.name.lower()!='wofost.o']
 run([fc,*flags,driver,*objs,*original_objects,ref/'ttobj/libttutil.a','-o',f/'test'])
 stdout=run([f/'test'],cwd=out);(f/'stdout').write_bytes(stdout);assert b'ORIGINAL_GRASS_BIOMASS_CANDIDATE_PASS'in stdout;print(opt,stdout.decode(),flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in source_hashes.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='GRASS_BODY_COMPONENT_PASS_NOT_HYDRAULIC_MODEL',events=events,source_sha256=source_hashes),indent=2))
