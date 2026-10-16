#!/usr/bin/env python3
"""Compare the existing codec1 writer at real old/current APIs."""
import argparse,hashlib,importlib.util,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3];BASE='9b05521b2df3579869f1906cb13900078fdeeda4'
a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args();out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
spec=importlib.util.spec_from_file_location('d',ROOT/'tests/support/augment_bartholomeus_backend_sources.py');d=importlib.util.module_from_spec(spec);spec.loader.exec_module(d)
ordered,_=d.strict_closure(ROOT,['src/runtime/mod_fmr_wofost_crop_transaction.f90','src/kernel/mod_kernel_committed_persistence.f90','tests/fwof/mod_fwof40_external_crop_restart_adapter.f90'])
changes=set(subprocess.check_output(['git','diff','--name-only',BASE,'HEAD','--','src'],cwd=ROOT,text=True).splitlines())|{'tests/fwof/mod_fwof40_external_crop_restart_adapter.f90'}
records=[];fc=os.environ.get('FC','gfortran');flags=['-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow']
for opt in [0,2]:
 for profile in ['baseline','current']:
  b=out/f'o{opt}-{profile}';b.mkdir();sources=[]
  for i,p in enumerate(ordered):
   if profile=='baseline' and str(p.relative_to(ROOT)) in changes:
    q=b/f'input-{i}.f90';q.write_bytes(subprocess.check_output(['git','show',BASE+':'+str(p.relative_to(ROOT))],cwd=ROOT));sources.append(q)
   else:sources.append(p)
  command=[fc,*flags,f'-O{opt}',*[str(p)for p in sources],str(ROOT/'tests/fmig431/annual/test_zero_restart.f90'),'-o',str(b/'zero')]
  t=time.monotonic();r=subprocess.run(command,cwd=b,capture_output=True,text=True);(b/'compile.stdout').write_text(r.stdout);(b/'compile.stderr').write_text(r.stderr)
  rec={'opt':opt,'profile':profile,'command':command,'compile_link_seconds':time.monotonic()-t,'compile_exit':r.returncode};records.append(rec)
  if r.returncode:raise SystemExit(r.returncode)
  r=subprocess.run([str(b/'zero')],cwd=b,capture_output=True,text=True);(b/'stdout').write_text(r.stdout);(b/'stderr').write_text(r.stderr);rec['native_exit']=r.returncode
  if r.returncode:raise SystemExit(r.returncode)
 assert(out/f'o{opt}-baseline/zero.restart').read_bytes()==(out/f'o{opt}-current/zero.restart').read_bytes(),'old codec bytes changed'
assert(out/'o0-current/zero.restart').read_bytes()==(out/'o2-current/zero.restart').read_bytes()
result={'zero_counter_codec1_bytes_identical':True,'baseline':BASE,'runs':records,'artifact_sha256':hashlib.sha256((out/'o0-current/zero.restart').read_bytes()).hexdigest()};(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({'zero_counter_codec1_bytes_identical':True}))
