#!/usr/bin/env python3
"""Further independent fine trajectories for representative B12 analytic cases."""
import argparse,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--routes',nargs='+',default=['normal','low_air']);args=p.parse_args()
for route in args.routes:
 original=(ROOT/f'tests/frost/test_ppa_wu05b12_{route}_runtime.f90').read_text()
 for count in ([16384,32768]if route=='normal'else[131072]):
  source=original.replace('8192'if route=='normal'else'65536',str(count))
  source=source.replace('do analytic_family=1,5','do analytic_family=1,5\n  if(analytic_family/=1.and.analytic_family/=2.and.analytic_family/=5)cycle'if route=='normal'else'do analytic_family=1,5\n  if(analytic_family/=1.and.analytic_family/=5)cycle')
  source=source.replace('do pattern=1,3','do pattern=1,2'if route=='normal'else'do pattern=3,3')
  source=source.replace('do signum=-1,1,2','do signum=-1,-1,2')
  a=source.index('  columns(1)%column_id');b=source.index('\ncontains\n',a)
  source=source[:a]+"  end do\n  print '(A)','PPA_WU05B12_ADDITIONAL_REFINEMENT=PASS'\n"+source[b:]
  path=pathlib.Path(f'/tmp/frost-b12-{route}-refinement-{count}.f90');path.write_text(source)
  build=pathlib.Path(f'/tmp/ppa-wu05b12-{route.replace("_","-")}-runtime/o0')
  flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-O0','-J'+str(build),'-I'+str(build)]
  base=pathlib.Path(f'/tmp/frost-b12-{route}-refinement-{count}')
  subprocess.run(['gfortran',*flags,'-c',str(path),'-o',str(base)+'.o'],check=True)
  objects=sorted(str(p)for p in build.glob('*.o')if p.name!='test.o')
  subprocess.run(['gfortran','-fopenmp','-O0',*objects,str(base)+'.o','-o',str(base)],check=True)
  with open(str(base)+'.log','w')as out,open(str(base)+'.err','w')as err:subprocess.run([str(base)],stdout=out,stderr=err,check=True)
  assert 'PPA_WU05B12_ADDITIONAL_REFINEMENT=PASS'in pathlib.Path(str(base)+'.log').read_text()
  print(route,count,'PASS',flush=True)
