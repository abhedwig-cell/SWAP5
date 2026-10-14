#!/usr/bin/env python3
"""Bounded actual fine-step fresh/workspace identity and rejected-input recovery.

A 1024-step independent lifetime control; does not replace owning 65536 loops.
"""
import argparse,hashlib,json,os,pathlib,subprocess,time,resource
from low_air_fine_worker_recipe import reuse_fine_workspace
ROOT=pathlib.Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
 a=argparse.ArgumentParser(description=__doc__);a.add_argument('--build',type=pathlib.Path,required=True);a.add_argument('--output',type=pathlib.Path,required=True);args=a.parse_args();b=args.build.resolve();out=args.output.resolve();out.mkdir(parents=True,exist_ok=False);m=json.loads((b/'RESULTS.json').read_text());flags=m['flags']
 for p,h in m['sources'].items():assert sha(pathlib.Path(p))==h,p
 text=reuse_fine_workspace((b/'low_air_driver.f90').read_text())
 text=text.replace('  logical::ok\n','  type(fmr_b110_physical_state_t)::independent_next,rejected_next\n  type(fmr_serialized_column_result_t)::independent_result\n  type(fmr_serialized_physical_observation_t)::independent_observation\n  logical::ok\n',1)
 needle='      call execute_case(2,0._real64,q,-999999._real64,1.e-4_real64,.false.,.true.,';assert text.count(needle)==2;text=text.replace(needle,needle.replace('1.e-4_real64','1.e-7_real64'))
 text=text.replace('      do i=1,65536','      do i=1,1024',1)
 call='''        call execute_case_workspace(2,0._real64,q,-999999._real64,dt,.false.,.true.,again,observation, &
             frost_case=.true.,initial_physical_state=direct,final_physical_state=next, &
             start_time=real(i-1,real64)*dt,drain_case=.true.,workspace=fine_workspace)'''
 assert text.count(call)==1
 fresh=call.replace('execute_case_workspace','execute_case').replace('again,observation','independent_result,independent_observation').replace('final_physical_state=next','final_physical_state=independent_next').replace(',workspace=fine_workspace','')
 negative=call.replace('final_physical_state=next','final_physical_state=rejected_next')
 checks="""
        call require(again%committed.and.independent_result%committed,'both fine implementations commit')
        call require(all(next%pressure_head==independent_next%pressure_head).and. &
             all(next%water_content==independent_next%water_content),'each fine accepted profile bit identity')
        call require(next%ponding_depth==independent_next%ponding_depth.and. &
             next%groundwater_level==independent_next%groundwater_level,'each fine boundary state bit identity')
        call copy_soil_temperature_profile(next%soil_temperature,tf,status)
        call require(status==0,'workspace thermal profile')
        call copy_soil_temperature_profile(independent_next%soil_temperature,td,status)
        call require(status==0.and.all(tf==td),'each fine thermal bit identity')
        call require(again%mass%storage_change==independent_result%mass%storage_change.and. &
             again%mass%total_in==independent_result%mass%total_in.and. &
             again%mass%total_out==independent_result%mass%total_out,'each fine accounting bit identity')
        call require(again%solver_headcalc_calls==independent_result%solver_headcalc_calls.and. &
             again%solver_nonlinear_iterations==independent_result%solver_nonlinear_iterations,'each fine solver work identity')
"""
 prefix="""        if(i==9)then
          missing_control=.true.
"""+negative+"""
          call require(.not.again%committed.and..not.again%completed,'reused invalid input fails closed')
          call require(all(rejected_next%pressure_head==direct%pressure_head).and. &
               all(rejected_next%water_content==direct%water_content),'reused rejected physical state is atomic')
          missing_control=.false.
        end if
"""
 text=text.replace(call,prefix+fresh+'\n'+call+checks)
 needle='      call copy_soil_temperature_profile(final%soil_temperature,tf,status)';assert text.count(needle)==1;text=text.replace(needle,"      print '(A)','LOW_AIR_FINE_WORKSPACE_PER_STEP_AND_FAILED_REUSE=PASS'\n      stop\n"+needle)
 p=out/'driver.f90';p.write_text(text);objects=[b/f'{i}.o'for i in range(len(m['ordered_sources'])-1)]
 subprocess.run(['gfortran',*flags,'-J',str(b),'-I',str(b),'-c',str(p),'-o',str(out/'driver.o')],check=True)
 subprocess.run(['gfortran',*flags,*map(str,objects),str(out/'driver.o'),'-o',str(out/'test')],check=True)
 before=resource.getrusage(resource.RUSAGE_CHILDREN);start=time.monotonic()
 with (out/'run.stdout').open('w')as so,(out/'run.stderr').open('w')as se:cp=subprocess.run([str(out/'test'),'1'],stdout=so,stderr=se,timeout=60,env={**os.environ,'GFORTRAN_UNBUFFERED_ALL':'y'})
 after=resource.getrusage(resource.RUSAGE_CHILDREN);record={'scope':'BOUNDED_FIRST_FAMILY_1024_EACH_STEP_REFERENCE_AND_FAILED_REUSE','exit':cp.returncode,'wall':time.monotonic()-start,'cpu':after.ru_utime+after.ru_stime-before.ru_utime-before.ru_stime,'build_sha256':sha(b/'RESULTS.json'),'driver_sha256':sha(p),'stdout_sha256':sha(out/'run.stdout'),'full_owning_replaced':False}
 (out/'RESULTS.json').write_text(json.dumps(record,indent=2)+'\n');print(json.dumps(record));assert cp.returncode==0 and 'LOW_AIR_FINE_WORKSPACE_PER_STEP_AND_FAILED_REUSE=PASS' in (out/'run.stdout').read_text()
if __name__=='__main__':main()
