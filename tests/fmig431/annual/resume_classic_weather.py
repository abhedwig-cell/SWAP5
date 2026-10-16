#!/usr/bin/env python3
"""Resume this annual weather qualification after executor loss, without full rebuild."""
import argparse,hashlib,importlib.util,json,os,re,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
a=argparse.ArgumentParser();a.add_argument('--build',required=True);args=a.parse_args();out=Path(args.build).resolve()
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
manifest=json.loads((out/'compiled-inputs-before-drain-merge.json').read_text())
providers=subprocess.check_output(['python',str(ROOT/'tests/support/augment_bartholomeus_backend_sources.py'),'--all','tests/fsi/fsi04_real_headcalc_stubs.f90','src/runtime/mod_fmr_production_application_bootstrap.f90','src/kernel/mod_kernel_committed_persistence.f90'],cwd=ROOT,text=True).splitlines()
assert set(providers)==set(manifest),'provider closure changed; explicit reconciliation required'
changed={p for p,h in manifest.items()if sha(ROOT/p)!=h}
allowed={'src/process/mod_drainage_spatial_distribution.f90','src/runtime/mod_fmr_divdra_runtime_binding.f90','src/runtime/mod_fmr_divdra_serialized_composition.f90','src/runtime/mod_fmr_divdra_serialized_runtime.f90'}
assert changed<=allowed,'unreconciled scientific dependency changes'
# Propagate the actual current module dependencies in original compile order.
mod={};uses={}
for p in providers:
 s=(ROOT/p).read_text();uses[p]=re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?([a-z]\w*)',s,re.I|re.M)
 for m in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)',s,re.I|re.M):mod[m.lower()]=p
flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
events=[];fc=os.environ.get('FC','gfortran');started=time.monotonic()
progress=out/'resume-events.json'
if progress.exists():events=json.loads(progress.read_text())
def run(command,cwd,stage,label,stdout=None):
 t=time.monotonic();r=subprocess.run(command,cwd=cwd,capture_output=True,text=True)
 stem=f'resume-{len(events):03d}-{stage}'
 (cwd/(stem+'.stdout')).write_text(r.stdout);(cwd/(stem+'.stderr')).write_text(r.stderr)
 events.append({'command':command,'stage':stage,'label':label,'exit':r.returncode,'seconds':time.monotonic()-t,'stdout':str((cwd/(stem+'.stdout')).relative_to(out)),'stderr':str((cwd/(stem+'.stderr')).relative_to(out))})
 progress.write_text(json.dumps(events,indent=2)+'\n')
 if stdout:(cwd/stdout).write_text(r.stdout);(cwd/stdout.replace('.txt','.diagnostics')).write_text(r.stderr)
 if r.returncode:raise RuntimeError(label+' failed '+r.stderr[-1000:]+r.stdout[-1000:])
 return r
for opt in [0,2]:
 b=out/f'o{opt}';dirty=set(changed)
 compiled_meta=b/'resume-object-inputs.json';saved=json.loads(compiled_meta.read_text())if compiled_meta.exists()else{}
 for p in providers:
  obj=b/('grid_stubs.o'if p=='tests/fsi/fsi04_real_headcalc_stubs.f90'else Path(p).stem+'.o')
  if not obj.exists()or any(mod.get(m.lower())in dirty for m in uses[p]):dirty.add(p)
  path=out/'grid_stubs.f90' if p=='tests/fsi/fsi04_real_headcalc_stubs.f90'else ROOT/p
  if p in dirty:
   identity={'source_sha256':sha(path),'dependency_sources':{mod[m.lower()]:sha(ROOT/mod[m.lower()])for m in uses[p]if m.lower()in mod}}
   if saved.get(p)!=identity or not obj.exists():
    run([fc,*flags,f'-O{opt}','-J.','-I.','-c',str(path)],b,'compile',p)
    saved[p]=identity;compiled_meta.write_text(json.dumps(saved,indent=2)+'\n')
 helpers=['astro_oracle.f90','daily_meteo_oracle.f90','crop_germination_oracle.f90','initial_owner_oracle.f90','task2_oracle.f90','preparation_oracle.f90','sowing_oracle.f90']
 cmd=[fc,*flags,f'-O{opt}','-J.','-I.',str(out/'driver.f90'),str(ROOT/'src/legacy/b1_10_port/headcalc.f90'),*[str(out/h)for h in helpers],*[str(b/('grid_stubs.o'if p=='tests/fsi/fsi04_real_headcalc_stubs.f90'else Path(p).stem+'.o'))for p in providers],'-o',str(b/'test')]
 run(cmd,b,'link','actual classic Richards driver')
 for moisture in ['neutral','dry','hydraulic']:
  for mode in ['continuous','restart']:
   run([str(b/'test'),*[str(out/f)for f in ['weather.999','altered.999','bad.999','backup.999']],mode,moisture],b,'native',moisture+'-'+mode,moisture+'-'+mode+'.txt')
   assert b'CROP_FILE_WEATHER_PRODUCTION=PASS' in(b/(moisture+'-'+mode+'.txt')).read_bytes()
  assert(b/(moisture+'-continuous.txt')).read_bytes()==(b/(moisture+'-restart.txt')).read_bytes()
for moisture in ['neutral','dry','hydraulic']:
 assert(out/f'o0/{moisture}-restart.txt').read_bytes()==(out/f'o2/{moisture}-restart.txt').read_bytes()
(out/'compiled-inputs-current.json').write_text(json.dumps({p:sha(ROOT/p)for p in providers},indent=2)+'\n')
result={'exit':0,'seconds':time.monotonic()-started,'completed_optimizations':[0,2],'native_programs':12,'resumed_after_executor_loss':True,'recompiled_providers':sum(e['stage']=='compile'for e in events),'compile_seconds':sum(e['seconds']for e in events if e['stage']=='compile'),'link_seconds':sum(e['seconds']for e in events if e['stage']=='link'),'native_seconds':sum(e['seconds']for e in events if e['stage']=='native'),'original_partial_controller':'CENSORED_EXECUTOR_TRANSPORT_LOSS','scope':'Complete existing IDSL0 real Richards/file-weather scenarios, added mortality comparisons, current merged positive drainage source; original thresholds and all scientific assertions retained.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
(out/'stdout').write_text('CROP_FILE_WEATHER_HYDRAULIC_CONTINUOUS_RESTORED_O0_O2=PASS\n'+(out/'o0/hydraulic-restart.txt').read_text())
(out/'stderr').write_text('')
print(json.dumps(result))
