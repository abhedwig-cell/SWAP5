#!/usr/bin/env python3
"""Retain incumbent equation/test assertions while qualifying the additive module."""
from pathlib import Path
import subprocess,tempfile
ROOT=Path(__file__).resolve().parents[2]
def main():
 p='src/process/mod_reference_et_demand_process.f90';base='bd17f0a9a7c19516e66af8f80e2b7128890b3aee'
 old=subprocess.check_output(['git','show',base+':'+p],cwd=ROOT,text=True);current=(ROOT/p).read_text()
 assert old.split('\ncontains\n',1)[0]==current.split('  integer, parameter :: PM_IDENTITY_KIND',1)[0]
 assert old.split('\ncontains\n',1)[1].split('end module',1)[0].rstrip()==current.split('\ncontains\n',1)[1].split('  pure subroutine evaluate_traditional_pm_daily',1)[0].rstrip()
 test='tests/fvq/test_fvq35_reference_et_demand_oracle.f90'
 assert subprocess.check_output(['git','show',base+':'+test],cwd=ROOT)==(ROOT/test).read_bytes()
 with tempfile.TemporaryDirectory(prefix='mc-met01-demand-reference-') as tmp:
  d=Path(tmp);outputs=[]
  for opt in [0,2]:
   exe=d/f'test{opt}';subprocess.run(['gfortran','-std=f2008','-ffree-line-length-none','-Wall','-Wextra','-Werror','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-I',str(d),'-J',str(d),str(ROOT/p),str(ROOT/test),'-o',str(exe)],cwd=d,check=True)
   r=subprocess.run([str(exe)],capture_output=True,text=True,check=True);assert 'FVQ35_INDEPENDENT_GRID_CASES=1700' in r.stdout;print(r.stdout,end='');outputs.append(r.stdout)
  assert outputs[0]==outputs[1]
 print('MC_MET01_INCUMBENT_LITERAL_REFERENCE_ET_PRESERVATION_O0_O2=PASS')
if __name__=='__main__':main()
