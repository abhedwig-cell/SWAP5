#!/usr/bin/env python3
"""Short actual-runtime analytic activation and signed TABLE mixtures."""
import argparse,os,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--routes',nargs='+',default=['normal','low_air']);p.add_argument('--opts',nargs='+',type=int,default=[0,2]);args=p.parse_args()
for route in args.routes:
 original=(ROOT/f'tests/frost/test_ppa_wu05b12_{route}_runtime.f90').read_text()
 a=original.index('  do analytic_family=1,5');b=original.index('\ncontains\n',a)
 main='''  control_head=[-3._real64,-4._real64]
  do analytic_family=1,5
  call initialize_parameters(parameters,2)
  call enable_bounded_frost(parameters)
  call initialize_physical_state(parameters,.true.,initial,1._real64)
  call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],initial%soil_temperature,status)
  do gwl_index=1,3
  initial%groundwater_level=-3._real64+real(gwl_index-2,real64)*.5_real64
  do table_sign=-1,1
  do signum=-1,1,2
  q=real(signum,real64)*.001_real64
  call execute_case(2,0._real64,q,-999999._real64,1.e-8_real64,.false.,.true.,result,observation, &
       frost_case=.true.,initial_physical_state=initial,final_physical_state=final,drain_case=.true.)
  call require(result%committed.and.result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'actual short activation mass')
  raw_expected=expected_proposal(initial%groundwater_level)
  call require(abs(observation%drainage_response%aggregate%signed_soil_to_drain_rate-raw_expected)<=1.e-14_real64,'independent activated raw proposal')
  call require(abs(result%mass%storage_change-(q-observation%frost_drainage%total_rate)*1.e-8_real64)<=hard_mass_gate,'one actual final-node owner')
  call require(observation%drainage_response_mass_accounted_in_trial,'existing receipt owner')
  cases=cases+1
  end do
  end do
  end do
  end do
  print '(A,I0)','PPA_WU05B12_SHORT_ACTIVATION_CASES=',cases
  print '(A)','PPA_WU05B12_SHORT_ACTIVATION=PASS'
'''
 if route=='normal':main='  case_temperature=-1._real64\n'+main
 else:
  block=original[original.index('  block\n'):original.index('  initial%groundwater_level=',original.index('  block\n'))]
  main='  drain_depth=[-3._real64,-4._real64]\n'+main
  main=main.replace('  do gwl_index=1,3',block+'  do gwl_index=1,3')
 s=original[:a]+main+original[b:]
 if route=='low_air':s=s.replace("  raw_expected=expected_proposal(initial%groundwater_level)","  call require(observation%frost_low_air_drainage%low_air_branch,'actual low-air branch in activation')\n  raw_expected=expected_proposal(initial%groundwater_level)")
 s=s.replace('  logical::ok\n','  logical::ok\n  integer::gwl_index,table_sign,cases=0\n',1)
 s=s.replace('qraw=b12_analytic_rate_oracle(analytic_family,gwl,merge(-1._real64,-3._real64,all(control_head>0._real64)))-.005_real64','qraw=b12_analytic_rate_oracle(analytic_family,gwl,-3._real64)-.005_real64*real(table_sign,real64)')
 s=s.replace('qraw=b12_analytic_rate_oracle(analytic_family,gwl,drain_depth(1))-.005_real64','qraw=b12_analytic_rate_oracle(analytic_family,gwl,drain_depth(1))-.005_real64*real(table_sign,real64)')
 s=s.replace('tabulated%signed_exchange_rate=[-.005_real64]','tabulated%signed_exchange_rate=[-.005_real64*real(table_sign,real64)]')
 source=pathlib.Path(f'/tmp/frost-b12-{route}-activation.f90');source.write_text(s);outputs=[]
 for opt in args.opts:
  build=pathlib.Path(os.environ.get('B12_LOW_AIR_BUILD','/tmp/ppa-wu05b12-low-air-runtime') if route=='low_air' else '/tmp/ppa-wu05b12-normal-runtime')/f'o{opt}'
  assert(build/'mod_fmr_production_application_bootstrap.o').exists()
  flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(build),'-I'+str(build)]
  base=pathlib.Path(f'/tmp/frost-b12-{route}-activation-o{opt}')
  subprocess.run(['gfortran',*flags,'-c',str(source),'-o',str(base)+'.o'],check=True)
  objects=sorted(str(p)for p in build.glob('*.o')if p.name!='test.o')
  subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(base)+'.o','-o',str(base)],check=True)
  with open(str(base)+'.log','w')as out,open(str(base)+'.err','w')as err:subprocess.run([str(base)],stdout=out,stderr=err,check=True)
  outputs.append(pathlib.Path(str(base)+'.log').read_bytes());print(route,opt,'ACTIVATION_PASS',flush=True)
 if len(outputs)==2:assert outputs[0]==outputs[1];print(route,'ACTIVATION_O0_O2_IDENTITY=PASS',flush=True)
