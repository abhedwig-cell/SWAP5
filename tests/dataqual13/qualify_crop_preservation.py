"""Focused existing annual and WOFOST81 production contracts, current providers."""
import hashlib,json,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];out=ROOT.parent/'dq13-crop-preservation';out.mkdir(exist_ok=False)
drivers=[ROOT/p for p in ['tests/fmig431/test_swap431_potential_shadow_daily.f90','tests/fwof/pp02/test_wofost81_one_day_candidate_integration.f90','tests/fwof/pp02/test_wofost81_leaf_structural_evolution.f90']]
mapping={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in mapping and mapping[name.lower()]!=p:visit(mapping[name.lower()])
 ordered.append(p)
for p in drivers:visit(p)
ordered=[p for p in ordered if p not in drivers];events=[];hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest()for p in ordered+drivers}
def run(cmd):
 t=time.perf_counter();r=subprocess.run(list(map(str,cmd)),capture_output=True);events.append(dict(command=list(map(str,cmd)),returncode=r.returncode,seconds=time.perf_counter()-t));(out/(str(len(events))+'.stderr')).write_bytes(r.stderr)
 if r.returncode:raise RuntimeError(r.stderr.decode()+r.stdout.decode())
 return r.stdout
for opt in ['O0','O2']:
 f=out/opt;f.mkdir();flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-fbacktrace','-I'+str(f),'-J'+str(f)];objs=[]
 for i,p in enumerate(ordered):
  obj=f/(str(i)+'.o');run(['/usr/bin/x86_64-linux-gnu-gfortran-13',*flags,'-c',p,'-o',obj]);assert obj.stat().st_size>0;objs.append(obj)
 for p in drivers:
  exe=f/p.stem;run(['/usr/bin/x86_64-linux-gnu-gfortran-13',*flags,p,*objs,'-o',exe]);raw=run([exe]);(f/(p.stem+'.stdout')).write_bytes(raw);assert b'PASS'in raw;print(opt,p.stem,'PASS',flush=True)
assert all(hashlib.sha256((ROOT/p).read_bytes()).hexdigest()==h for p,h in hashes.items())
(out/'RESULT.json').write_text(json.dumps(dict(status='EXISTING_CROP_CONTRACTS_PASS',events=events,source_sha256=hashes),indent=2))
