#!/usr/bin/env python3
"""Actual control activation/cap/suppression and full independent finer references."""
import argparse,pathlib,subprocess
ROOT=pathlib.Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--routes',nargs='+',choices=['normal','low_air'],default=['normal','low_air']);p.add_argument('--opts',nargs='+',type=int,choices=[0,2],default=[0,2]);p.add_argument('--gates',nargs='+',choices=['activation','refinements'],default=['activation','refinements']);args=p.parse_args()
assert subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip()=='f1f8351c6cb7ccd2d1a78e79bebb79dce8076c4d'
def run(s,route,label,opt):
 source=pathlib.Path(f'/tmp/frost-b14-{route}-{label}-o{opt}.f90');source.write_text(s)
 b=pathlib.Path('/tmp/ppa-wu05b14-'+route.replace('_','-')+'-runtime')/f'o{opt}'
 if route=='low_air'and opt==2 and not b.exists():b=pathlib.Path('/tmp/ppa-wu05b14-low-air-runtime-parallel/o2')
 assert(b/'mod_fmr_production_application_bootstrap.o').exists()
 flags=['-std=f2008','-ffree-line-length-none','-w','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J'+str(b),'-I'+str(b)]
 base=source.with_suffix('')
 subprocess.run(['gfortran',*flags,'-c',str(source),'-o',str(base)+'.o'],check=True)
 objects=sorted(str(f)for f in b.glob('*.o')if not f.name.startswith('test_'))
 subprocess.run(['gfortran','-fopenmp',f'-O{opt}',*objects,str(base)+'.o','-o',str(base)],check=True)
 with open(str(base)+'.log','w')as so,open(str(base)+'.err','w')as se:subprocess.run([str(base)],stdout=so,stderr=se,check=True)
 return pathlib.Path(str(base)+'.log').read_bytes()
for route in args.routes:
 original=(ROOT/f'tests/frost/test_ppa_wu05b14_{route}_runtime.f90').read_text()
 if 'activation' in args.gates:
  a=original.index('  do extended_configuration=1,4');b=original.index('\ncontains\n',a)
  bottom='-5._real64'if route=='normal'else'drain_depth(2)'
  initialization=''
  if route=='low_air':
   initialization=original[original.index('  block\n'):original.index('  initial%groundwater_level=',original.index('  block\n'))]+'  initial%groundwater_level=-.25_real64\n'
  main=f'''  do extended_configuration=1,4
  call initialize_parameters(parameters,2)
  call enable_bounded_frost(parameters)
  call initialize_physical_state(parameters,.true.,initial,1._real64)
  call initialize_soil_temperature_state([-4._real64,-4._real64,-1._real64,1._real64],initial%soil_temperature,status)
{initialization}  do scenario=1,10
  base_gwl=-2._real64
  if({'.true.'if route=='low_air'else'.false.'})base_gwl=-.25_real64
  initial%groundwater_level=base_gwl
  control_head(2)=base_gwl-.5_real64
  select case(scenario)
  case(2);control_head(2)=base_gwl
  case(3);control_head(2)=base_gwl+.5_real64
  case(4);initial%groundwater_level={bottom}-1._real64;control_head(2)={bottom}-1._real64
  case(5);initial%groundwater_level={bottom}+1._real64;control_head(2)={bottom}+.001_real64
  case(6);initial%groundwater_level={bottom}-101._real64;control_head(2)={bottom}+1._real64
  case(7);initial%groundwater_level=1000._real64;control_head(2)=1000._real64
  case(8);initial%groundwater_level=-.1_real64-1.e-10_real64;control_head(2)=-1._real64
  case(9);initial%groundwater_level=-.1_real64;control_head(2)=-1._real64
  case(10);initial%groundwater_level=-.1_real64+1.e-10_real64;control_head(2)=-1._real64
  end select
  do resistance_index=1,2
  do signum=-1,1,2
  q=real(signum,real64)*.001_real64
  call execute_case(2,0._real64,q,-999999._real64,1.e-10_real64,.false.,.true.,result,observation, &
       frost_case=.true.,initial_physical_state=initial,final_physical_state=final,drain_case=.true.)
  call require(result%committed.and.result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,'actual control branch hard mass')
  raw_expected=expected_proposal(initial%groundwater_level,initial%ponding_depth)
  call require(abs(observation%drainage_response%aggregate%signed_soil_to_drain_rate-raw_expected)<=1.e-12_real64*max(1._real64,abs(raw_expected)),'independent selected raw signed proposal')
  call require(abs(result%mass%storage_change-(q-observation%frost_drainage%total_rate)*1.e-10_real64)<=hard_mass_gate,'one actual final nodal sink')
  call require(observation%drainage_response_mass_accounted_in_trial,'accepted receipt owner')
  cases=cases+1
  end do
  end do
  end do
  end do
  call require(cases==160,'complete actual control/parameter endpoint matrix')
  print '(A,I0)','PPA_WU05B14_SHORT_ACTIVATION_CASES=',cases
  print '(A)','PPA_WU05B14_SHORT_ACTIVATION=PASS'
'''
  if route=='normal':main='  case_temperature=-1._real64\n'+main
  else:
   main='  drain_depth=[-3._real64,-4._real64]\n'+main
   main=main.replace('  raw_expected=expected_proposal(', "  call require(observation%frost_low_air_drainage%low_air_branch,'observed actual low-air branch')\n  raw_expected=expected_proposal(")
  s=original[:a]+main+original[b:]
  s=s.replace('  logical::ok\n','  logical::ok\n  integer::scenario,resistance_index,cases=0\n  real(real64)::base_gwl\n',1)
  needle='    if(missing_control)forcing%drainage_response_controls(1)%resolved_surface_water_head_supplied=.false.'
  s=s.replace(needle,'    parameters%drainage_response_levels(1)%extended%rdrain_day=merge(1._real64,1.e5_real64,resistance_index==1)\n    parameters%drainage_response_levels(1)%extended%rinfi_day=merge(1._real64,1.e5_real64,resistance_index==1)\n'+needle)
  a=s.index('  real(real64) function expected_proposal(');b=s.index('  subroutine configure_response(',a)
  oracle=f'''  real(real64) function expected_proposal(gwl,pond)result(qraw)
    real(real64),intent(in)::gwl,pond
    real(real64)::bottom,level,h,res,entry,wet,depth,wl
    bottom={bottom};wl=control_head(2);qraw=0._real64
    if(wl>=1000._real64.and.gwl>=1000._real64)return
    if(gwl<=bottom+.001_real64.and.wl<=bottom+.001_real64)return
    level=bottom
    if(wl>bottom+.001_real64)level=wl
    h=gwl-level
    if(gwl>-.1_real64)h=h+pond
    if(h<0._real64.and.gwl<bottom-100._real64)h=bottom-100._real64-level
    res=merge(1._real64,1.e5_real64,resistance_index==1);entry=.2_real64
    if(h<=0._real64)entry=.4_real64
    if(b14_kind(extended_configuration)==EXT_DRAIN_OPEN_CHANNEL)then
      wet=12._real64
      if(wl>bottom+.001_real64)then
        depth=wl-bottom;wet=wet+2._real64*depth*sqrt(1._real64+1._real64/4._real64)
      end if
      res=res+entry*200._real64/wet
    end if
    qraw=h/res
  end function

'''
  s=s[:a]+oracle+s[b:]
  outputs=[]
  for opt in args.opts:
   out=run(s,route,'activation',opt);assert b'PPA_WU05B14_SHORT_ACTIVATION=PASS'in out
   outputs.append(out);print(route,opt,'ACTIVATION_PASS',flush=True)
  if len(outputs)==2:assert outputs[0]==outputs[1];print(route,'ACTIVATION_O0_O2_IDENTITY=PASS',flush=True)
 if 'refinements' in args.gates:
  for count in ([16384,32768]if route=='normal'else[131072]):
   s=original.replace('8192'if route=='normal'else'65536',str(count))
   if route=='low_air':s=s.replace('  do extended_configuration=1,4','  do extended_configuration=1,4\n  if(extended_configuration/=1.and.extended_configuration/=4)cycle',1)
   s=s.replace('do pattern=1,3','do pattern=1,2'if route=='normal'else'do pattern=3,3').replace('do signum=-1,1,2','do signum=-1,-1,2')
   a=s.index('  columns(1)%column_id');b=s.index('\ncontains\n',a)
   s=s[:a]+"  end do\n  print '(A)','PPA_WU05B14_ADDITIONAL_REFINEMENT=PASS'\n"+s[b:]
   out=run(s,route,'refinement-'+str(count),0);assert b'PPA_WU05B14_ADDITIONAL_REFINEMENT=PASS'in out
   print(route,count,'REFINEMENT_PASS',flush=True)

