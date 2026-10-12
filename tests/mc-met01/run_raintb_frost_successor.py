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
exec(compile(s,str(ROOT/runner),'exec'),{'__file__':str(ROOT/runner),'__name__':'__main__'})
