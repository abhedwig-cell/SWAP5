"""Execute authenticated DCSLIM statements against both existing production depth routes."""
from pathlib import Path
import argparse,base64,tarfile,io,hashlib,importlib.util,json,subprocess,time
ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location('feedback',ROOT/'tests/modularity/run_modular_tests.py');m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

def program():
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())))as t:
  raw=t.extractfile(next(x for x in t.getmembers()if x.name.endswith('SWAP/irrigation.f90'))).read()
 assert hashlib.sha256(raw).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
 s=raw.decode();body=s.split('! depth - limited depth [cm]')[1].split('! in case of solutes: allow overirrigation')[0]
 assert 'irr_depth = max(irr_depth, irgdepmin * 0.1d0)'in body and 'irr_depth = min(irr_depth, irgdepmax * 0.1d0)'in body
 return '''program limits
use iso_fortran_env,only:real64,int64
use, intrinsic::ieee_arithmetic
use mod_scheduled_irrigation_management_policy
use mod_irrigation_process
use mod_process_hydraulic_view
implicit none
type(irrigation_management_policy_parameters_t)::p
type(irrigation_management_policy_request_t)::r
type(irrigation_management_policy_result_t)::result
type(scheduled_irrigation_parameters_t)::sp
type(scheduled_irrigation_request_t)::sr
type(irrigation_state_t)::committed,candidate
type(irrigation_flux_result_t)::flux
type(irrigation_diagnostics_t)::diag
type(process_hydraulic_view_t)::hv
real(real64)::irr_depth,irgdepmin,irgdepmax,rawdepth,lo,hi,nan
real(real64),parameter::lower(5)=[0._real64,.1_real64,1._real64,50._real64,100._real64]
real(real64),parameter::upper(6)=[0._real64,.1_real64,1._real64,100._real64,1000._real64,1.e7_real64]
integer::dcslim,dcs,i,j,k,edge,status,n,fail,route,invalid
logical::expected_limited
n=0;fail=0
sp%scheduled_irrigation_enabled=.true.;sp%active_nodes=1;sp%sensor_node=1;sp%single_ssdi_node=1
sp%tcs7_knot_count=2;sp%tcs7_dvs(1:2)=[0._real64,2._real64];sp%tcs7_pressure_head(1:2)=0._real64
sp%dcs2_knot_count=2;sp%dcs2_dvs(1:2)=[0._real64,2._real64]
sr%t0=0;sr%t1=1._real64/64._real64;sr%dvs=1
sr%selection_opportunity=.true.;sr%irrigation_enabled=.true.;sr%schedule_enabled=.true.
sr%crop_emerged=.true.;sr%irrigation_window_open=.true.
allocate(hv%pressure_head(1),hv%water_content(1))
hv%active_nodes=1;hv%pressure_head=-10;hv%water_content=.25_real64
p%dcs1_knot_count=2;p%dcs1_dvs(1:2)=[0._real64,2._real64];p%dcs1_adjustment_mm=0
p%dcs2_knot_count=2;p%dcs2_dvs(1:2)=[0._real64,2._real64]
r%dvs=1
! Exercise legal bound endpoints and both adjacent representable values at each edge.
do dcslim=0,1
do i=1,size(lower)
 irgdepmin=lower(i);lo=irgdepmin*.1_real64
do j=1,size(upper)
 irgdepmax=upper(j);hi=irgdepmax*.1_real64
 if(irgdepmax<irgdepmin)cycle
 do k=0,8
  select case(k)
  case(0);rawdepth=0
  case(1);rawdepth=nearest(lo,-1._real64);if(lo==0)rawdepth=0
  case(2);rawdepth=lo
  case(3);rawdepth=nearest(lo,1._real64)
  case(4);rawdepth=(lo+hi)*.5_real64
  case(5);rawdepth=nearest(hi,-1._real64);if(hi==0)rawdepth=0
  case(6);rawdepth=hi
  case(7);rawdepth=nearest(hi,1._real64)
  case(8);rawdepth=hi+1
  end select
  ! FID has its own0..40cm domain. Large unconstrained depths are valid DCS1 deficits.
  do dcs=1,2
   if(dcs==2.and.rawdepth>40)cycle
   irr_depth=rawdepth
'''+body+'''
   expected_limited=dcslim==1.and.(rawdepth<lo.or.rawdepth>hi)
   p%depth_criterion=dcs;p%depth_limit_enabled=dcslim==1
   p%minimum_depth_cm=lo;p%maximum_depth_cm=hi
   r%field_capacity_deficit_cm=rawdepth;p%dcs2_depth_cm=rawdepth
   result=irrigation_management_policy_result_t(trigger=.true.)
   call evaluate_irrigation_management_depth(p,r,result,status)
   n=n+1
   if(status/=IRR_MGMT_OK)then
    fail=fail+1
    print *, 'LIMIT_ROOT_STATUS',dcs,dcslim,rawdepth,lo,hi,status
   else
    if(transfer(result%selected_depth_cm,0_int64)/=transfer(irr_depth,0_int64))error stop 2
    if(result%depth_limited.neqv.expected_limited)error stop 3
   endif
   if(dcs/=2)cycle
   sp%depth_limit_enabled=dcslim==1;sp%minimum_depth_cm=lo;sp%maximum_depth_cm=hi;sp%dcs2_depth_cm=rawdepth
   call evaluate_scheduled_irrigation_interval(sp,committed,sr,hv,candidate,flux,diag)
   n=n+1
   if(diag%status/=IRRIGATION_OK)then
    fail=fail+1
    print *, 'LIMIT_SENSOR_STATUS',dcslim,rawdepth,lo,hi,diag%status
   else
    if(diag%depth_limited.neqv.expected_limited)error stop 4
    if(irr_depth>0)then
     if(abs(flux%external_inflow_amount-irr_depth*sr%t1)>1.e-13_real64*max(1._real64,irr_depth))error stop 5
    else
     if(flux%external_inflow_amount/=0.or.flux%applied.or.candidate%active_event)error stop 6
    endif
   endif
   if(committed%active_event.or.committed%next_fixed_event_index/=1)error stop 7
  enddo
 enddo
enddo
enddo
enddo
! DCS1 rain eliminates depth before minimum is applied, exactly the source stage ordering.
p%depth_criterion=1;p%depth_limit_enabled=.true.;p%minimum_depth_cm=.25_real64;p%maximum_depth_cm=.5_real64
r%field_capacity_deficit_cm=.1_real64;r%rainfall_cm=.2_real64;p%rainfall_threshold_cm=.1_real64
call evaluate_irrigation_management_depth(p,r,result,status)
if(status/=IRR_MGMT_OK.or.result%selected_depth_cm/=.25_real64.or..not.result%rainfall_deducted)error stop 8
! Reject malformed active caps; disabled modifier ignores inactive caps as source.
nan=ieee_value(0._real64,ieee_quiet_nan)
do invalid=1,5
p%minimum_depth_cm=.1_real64;p%maximum_depth_cm=.5_real64
select case(invalid)
case(1);p%minimum_depth_cm=-1
case(2);p%maximum_depth_cm=0
case(3);p%minimum_depth_cm=nan
case(4);p%maximum_depth_cm=nan
case(5);p%maximum_depth_cm=ieee_value(0._real64,ieee_positive_inf)
end select
call evaluate_irrigation_management_depth(p,r,result,status)
if(status==IRR_MGMT_OK)error stop 9
enddo
print '(a,i0,a,i0)','LIMIT_SOURCE_VECTORS=',n,'|FAILURES=',fail
if(fail/=0)error stop 10
print '(a)','LIMIT_LITERAL_BOTH_PRODUCTION_ROUTES_O0_O2=PASS'
end program
'''

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',required=True);a=p.parse_args();out=Path(a.output).resolve();session=m.Session(out);start=time.perf_counter()
 code=program();driver=out/'literal.f90';driver.write_text(code)
 paths=['src/process/mod_scheduled_irrigation_management_policy.f90','src/process/mod_irrigation_process.f90','src/process/mod_irrigation_availability_policy.f90','tests/mc-irr01/run_depth_limit_contract.py']
 ordered,_=m.DEP.strict_closure(ROOT,['src/process/mod_irrigation_process.f90'],[])
 providers=[str(q.relative_to(ROOT))for q in ordered]
 inputs={q:m.sha(ROOT/q)for q in set(paths+providers)};rows=[]
 for opt in(0,2):
  build=out/f'o{opt}';build.mkdir();flags=['-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow',f'-O{opt}','-J',str(build),'-I',str(build)]
  exe=build/'literal';session.command([session.compiler,*flags,*[str(ROOT/q)for q in providers],str(ROOT/paths[0]),str(driver),'-o',str(exe)],build,'compile')
  raw,e=session.command([str(exe)],build,'native');rows.append({'opt':opt,'returncode':e['returncode'],'stdout_sha256':hashlib.sha256(raw).hexdigest()})
 assert rows[0]['stdout_sha256']==rows[1]['stdout_sha256']
 assert all(m.sha(ROOT/q)==h for q,h in inputs.items())
 m.write(out/'RESULTS.json',dict(status='PASS',head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs=inputs,rows=rows,events=session.events,generated={'literal.f90':m.sha(driver)},providers=providers,wall_seconds=time.perf_counter()-start))
 print('LIMIT_DIRECT_SOURCE_CONTRACT=PASS',flush=True)
if __name__=='__main__':main()
