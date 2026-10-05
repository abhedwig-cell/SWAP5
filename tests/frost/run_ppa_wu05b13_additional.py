#!/usr/bin/env python3
"""Additional actual interval-control activation and independent refinements."""
import argparse,pathlib,re,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--routes',nargs='+',choices=['normal','low_air'],default=['normal','low_air']);p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--gates',nargs='+',choices=['activation','refinements'],default=['activation','refinements']);args=p.parse_args()
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()=='012b2e9df2fa854f19b31c98a1bcd214d8285662'
def run(s,route,label,opt):
 source=pathlib.Path(f'/tmp/frost-b13-{route}-{label}-o{opt}.f90');source.write_text(s)
 build=pathlib.Path('/tmp/ppa-wu05b13-'+route.replace('_','-')+'-runtime')/f'o{opt}'
 if route=='low_air'and opt==2 and not build.exists():build=pathlib.Path('/tmp/ppa-wu05b13-low-air-runtime-parallel/o2')
 assert(build/'mod_fmr_production_application_bootstrap.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(build),'-I'+str(build)]
 base=source.with_suffix('')
 subprocess.run(['gfortran',*flags,'-c',str(source),'-o',str(base)+'.o'],check=True)
 objects=sorted(str(f)for f in build.glob('*.o')if not f.name.startswith('test_'))
 subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(base)+'.o','-o',str(base)],check=True)
 with open(str(base)+'.log','w')as so,open(str(base)+'.err','w')as se:subprocess.run([str(base)],stdout=so,stderr=se,check=True)
 return pathlib.Path(str(base)+'.log').read_bytes()
for route in args.routes:
 original=(ROOT/f'tests/frost/test_ppa_wu05b13_{route}_runtime.f90').read_text()
 if 'activation' in args.gates:
  a=original.index('  do empirical_configuration=1,6');b=original.index('\ncontains\n',a)
  main='''  do empirical_configuration=1,6
  call initialize_parameters(parameters,2)
  call enable_bounded_frost(parameters)
  call initialize_physical_state(parameters,.true.,initial,1._real64)
  call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],initial%soil_temperature,status)
  do empirical_head_index=1,3
  control_head(2)=initial%groundwater_level+real(empirical_head_index-2,real64)*.5_real64
  do linear_head_index=1,3
  if(b13_level_count(empirical_configuration)==1.and.linear_head_index/=1)cycle
  control_head(1)=initial%groundwater_level+real(linear_head_index-2,real64)*.5_real64
  do coefficient_index=1,2
  do signum=-1,1,2
  q=real(signum,real64)*.001_real64
  call execute_case(2,0._real64,q,-999999._real64,1.e-8_real64,.false.,.true.,result,observation, &
       frost_case=.true.,initial_physical_state=initial,final_physical_state=final,drain_case=.true.)
  call require(result%committed.and.result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'actual controlled activation mass')
  raw_expected=expected_proposal(initial%groundwater_level)
  call require(abs(observation%drainage_response%aggregate%signed_soil_to_drain_rate-raw_expected)<=1.e-14_real64,'independent controlled raw proposal')
  call require(abs(result%mass%storage_change-(q-observation%frost_drainage%total_rate)*1.e-8_real64)<=hard_mass_gate,'one actual final nodal sink')
  call require(observation%drainage_response_mass_accounted_in_trial,'existing accepted receipt owner')
  cases=cases+1
  end do
  end do
  end do
  end do
  end do
  call require(cases==144,'complete actual control/parameter bound activation matrix')
  print '(A,I0)','PPA_WU05B13_SHORT_ACTIVATION_CASES=',cases
  print '(A)','PPA_WU05B13_SHORT_ACTIVATION=PASS'
'''
  if route=='normal':main='  case_temperature=-1._real64\n'+main
  else:
   block=original[original.index('  block\n'):original.index('  initial%groundwater_level=',original.index('  block\n'))]
   main='  drain_depth=[-3._real64,-4._real64]\n'+main
   main=main.replace('  do empirical_head_index=1,3',block+'  initial%groundwater_level=-.25_real64\n  do empirical_head_index=1,3')
   main=main.replace('  raw_expected=expected_proposal(initial%groundwater_level)',"  call require(observation%frost_low_air_drainage%low_air_branch,'observed actual low-air branch')\n  raw_expected=expected_proposal(initial%groundwater_level)")
  s=original[:a]+main+original[b:]
  s=s.replace('  logical::ok\n','  logical::ok\n  integer::empirical_head_index,linear_head_index,coefficient_index,cases=0\n',1)
  s=s.replace('qraw=b13_empirical_rate_oracle(.01_real64,','qraw=b13_empirical_rate_oracle(merge(.01_real64,10._real64,coefficient_index==1),',1)
  s=s.replace('qraw=qraw+(gwl-control_head(1))/200._real64','qraw=qraw+max(0._real64,(gwl-control_head(1))/200._real64)',1)
  needle='    if(missing_control)forcing%drainage_response_controls(n)%drain_head_supplied=.false.'
  s=s.replace(needle,'    parameters%drainage_response_levels(n)%empirical%coefficient=merge(.01_real64,10._real64,coefficient_index==1)\n'+needle,1)
  outputs=[]
  for opt in args.opts:
   out=run(s,route,'activation',opt);assert b'PPA_WU05B13_SHORT_ACTIVATION=PASS' in out
   outputs.append(out);print(route,opt,'ACTIVATION_PASS',flush=True)
  if len(outputs)==2:assert outputs[0]==outputs[1];print(route,'ACTIVATION_O0_O2_IDENTITY=PASS',flush=True)
 if 'refinements' in args.gates:
  for count in ([16384,32768]if route=='normal'else[131072]):
   s=original.replace('8192'if route=='normal'else'65536',str(count))
   selection='  if(empirical_configuration/=1.and.empirical_configuration/=3.and.empirical_configuration/=4.and.empirical_configuration/=6)cycle'if route=='normal'else'  if(empirical_configuration/=1.and.empirical_configuration/=6)cycle'
   s=s.replace('  do empirical_configuration=1,6','  do empirical_configuration=1,6\n'+selection,1)
   s=s.replace('do pattern=1,3','do pattern=1,2'if route=='normal'else'do pattern=3,3').replace('do signum=-1,1,2','do signum=-1,-1,2')
   a=s.index('  columns(1)%column_id');b=s.index('\ncontains\n',a)
   s=s[:a]+"  end do\n  print '(A)','PPA_WU05B13_ADDITIONAL_REFINEMENT=PASS'\n"+s[b:]
   out=run(s,route,'refinement-'+str(count),0);assert b'PPA_WU05B13_ADDITIONAL_REFINEMENT=PASS' in out
   print(route,count,'REFINEMENT_PASS',flush=True)

