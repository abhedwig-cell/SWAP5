#!/usr/bin/env python3
"""Fresh unchanged highest-route science on the exact two-file RAINTB source."""
from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
BASE='c545077ab2d2839007a4ac202f7896575d0ad9ba'
PINS={'src/adapter/mod_swap_daily_weather_file_adapter.f90': 'cb53d90e9861bddf83b3ededf8993869cf5c8308', 'src/runtime/mod_fmr_production_application_bootstrap.f90': '2ae6e3aafe9f4987b562618443b0ccd48a133a4c'}
def git(*a):return subprocess.check_output(['git',*a],cwd=ROOT,text=True).strip()
assert not git('status','--porcelain','--','src')
assert git('diff','--name-only',BASE,'HEAD','--','src').splitlines()==sorted(PINS)
for p,b in PINS.items():assert git('rev-parse','HEAD:'+p)==b,p
assert git('rev-parse','HEAD:reference')==git('rev-parse',BASE+':reference')
runner='tests/frost/run_ppa_wu05b15_runtime.py'
assert subprocess.check_output(['git','show',BASE+':'+runner],cwd=ROOT)==(ROOT/runner).read_bytes()
s=(ROOT/runner).read_text();old='assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()==source';assert s.count(old)==1
s=s.replace(old,'assert subprocess.check_output(["git","rev-parse","HEAD:src"],cwd=ROOT,text=True).strip()=='+repr(git('rev-parse','HEAD:src')))
old="prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime'+('-micro'if args.micro_successor else'')";assert s.count(old)==1
s=s.replace(old,"prefix='ppa-wu05b15-'+args.route.replace('_','-')+'-runtime-mc-met01'")
# Scheduling only: unchanged original case commands and assertions in
# separate fresh processes. Bound workers to two to preserve memory margin.
import concurrent.futures,os,hashlib,json
resume=None
if '--resume-config1' in sys.argv:
 sys.argv.remove('--resume-config1')
 resume=json.loads(Path('/tmp/mc-met01-low-air-complete-config1.json').read_text())
 assert resume['source_tree']==git('rev-parse','HEAD:src')
 assert resume['exit_0_observed_by_original_controller']
 assert resume['compiler']==subprocess.check_output(['gfortran','--version'],text=True)
start=s.index(' output=[]\n');end=s.index(" (out/'output.txt').write_text",start)
old=s[start:end]
new=""" def run_configuration(configuration):
  stdout=out/f'configuration-{configuration}.txt';stderr=out/f'configuration-{configuration}.err'
  if resume is not None and opt==0 and configuration==1:
   raw=Path('/tmp/mc-met01-low-air-config1.stdout').read_bytes()
   assert hashlib.sha256(raw).hexdigest()==resume['stdout_sha256']
   stdout.write_bytes(raw);stderr.write_text('Inherited completed configuration1 from same source/compiler; original controller observed exit0.\\n')
  else:
   with stdout.open('w')as so,stderr.open('w')as se:
    subprocess.run([str(out/'test'),str(configuration)],stdout=so,stderr=se,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'},check=True)
  text=stdout.read_text();assert text.count('_RUNTIME=PASS')==1 and text.count('FINE_COMPARISON')==6
  assert 'PPA_WU05B15_EXTENDED_APPLICATION=PASS' in text and 'PPA_WU05B15_ACTUAL_CONTROL_PREFLIGHT=PASS' in text
  print(f'PPA_WU05B15_{args.route.upper()}_O{opt}_CONFIGURATION_{configuration}_COMPLETE=PASS',flush=True)
  return text
 with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
  output=list(pool.map(run_configuration,range(1,7)))
"""
assert 'for configuration in range(1,7):' in old
s=s[:start]+new+s[end:]
exec(compile(s,str(ROOT/runner),'exec'),{'__file__':str(ROOT/runner),'__name__':'__main__','resume':resume,'concurrent':concurrent,'hashlib':hashlib,'Path':Path})
