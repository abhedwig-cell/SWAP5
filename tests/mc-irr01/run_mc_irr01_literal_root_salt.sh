#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"
BUILD="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/mc-irr01-literal-root-salt-$$"
mkdir -p "$BUILD"
trap 'rm -rf "$BUILD"' EXIT
python3 - "$BUILD" <<'PY'
import base64,tarfile,io,hashlib,pathlib,sys
b64=pathlib.Path('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes()
t=tarfile.open(fileobj=io.BytesIO(base64.b64decode(b64)),mode='r:gz')
b=t.extractfile(next(m for m in t.getmembers() if m.name.endswith('SWAP/irrigation.f90'))).read()
assert hashlib.sha256(b).hexdigest()=='65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1'
s=b.decode()
# Execute actual pinned source statements; no rewritten oracle predicates.
timing=s.split('! timing - depletion of readily available water (fraction)')[1].split('! timing - critical pressure head at dcrit')[0]
depth=s.split('! depth - back to field capacity [cm]')[1].split('! Rates')[0]
program='''program literal_management
use iso_fortran_env, only: real64
use mod_scheduled_irrigation_management_policy
use mod_irrigation_process, only: apply_irrigation_salinity_excess
use ieee_arithmetic, only: ieee_value,ieee_quiet_nan
implicit none
type(irrigation_management_policy_parameters_t)::p
type(irrigation_management_policy_state_t)::state,candidate
type(irrigation_management_policy_request_t)::request
type(irrigation_management_policy_result_t)::result
real(real64)::awlh,awmh,awah,cdef,dvs,rawtab(14),tawtab(14),dwatab(14),ditab(14),fidtab(14)
real(real64)::tps2,tps3,tps4,depl,irgthreshold,dps1,dps2,grai,raithreshold,grai_red,irr_depth,irgdepmin,irgdepmax
integer::tcs,dcs,dcslim,dayfix,irrigevent,mode,edge,status,n,swsolu,swcirrthres,nodsen
real(real64)::cml(1),cirrthres,perirrsurp,negative_depth
logical::salt_applied,salt_ok
n=0
 do tcs=2,6
 if(tcs==5)cycle
 do dcs=1,2
 do mode=0,1
 do edge=0,2
 p=irrigation_management_policy_parameters_t()
 state=irrigation_management_policy_state_t()
 request=irrigation_management_policy_request_t()
 awlh=10.0_real64;awmh=6.0_real64;awah=8.0_real64+real(edge-1,real64)*1e-8_real64
 cdef=awlh-awah;dvs=1.0_real64
 rawtab=0.0_real64;rawtab(2)=0.5_real64
 tawtab=0.0_real64;tawtab(2)=0.2_real64
 dwatab=0.0_real64;dwatab(2)=20.0_real64
 ditab=0.0_real64;ditab(2)=-1.0_real64
 fidtab=0.0_real64;fidtab(2)=12.0_real64
 irgthreshold=10.0_real64;dayfix=6;irrigevent=0
 grai=0.6_real64;raithreshold=0.5_real64
 dcslim=mode;irgdepmin=25.0_real64;irgdepmax=30.0_real64
 swsolu=1;swcirrthres=1;nodsen=1;cirrthres=1.0_real64;perirrsurp=25.0_real64
 cml(1)=1.0_real64+real(edge-1,real64)*1e-8_real64
 irr_depth=0.0_real64
'''+timing+'''
 if(irrigevent==2)then
'''+depth+'''
 endif
 p%timing_criterion=tcs;p%depth_criterion=dcs
 p%tcs2_knot_count=2;p%tcs2_dvs(1:2)=[0.0_real64,2.0_real64];p%tcs2_fraction(1:2)=rawtab(2)
 p%tcs3_knot_count=2;p%tcs3_dvs(1:2)=[0.0_real64,2.0_real64];p%tcs3_fraction(1:2)=tawtab(2)
 p%tcs4_knot_count=2;p%tcs4_dvs(1:2)=[0.0_real64,2.0_real64];p%tcs4_depletion_mm(1:2)=dwatab(2)
 p%tcs6_threshold_mm=irgthreshold
 p%dcs1_knot_count=2;p%dcs1_dvs(1:2)=[0.0_real64,2.0_real64];p%dcs1_adjustment_mm(1:2)=ditab(2)
 p%dcs2_knot_count=2;p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64];p%dcs2_depth_cm(1:2)=0.1_real64*fidtab(2)
 p%rainfall_threshold_cm=raithreshold;p%depth_limit_enabled=dcslim==1
 p%minimum_depth_cm=0.1_real64*irgdepmin;p%maximum_depth_cm=0.1_real64*irgdepmax
 state%weekly_day_counter=6
 request%dvs=dvs;request%total_available_water_cm=awlh;request%stress_to_wilting_available_cm=awmh
 request%actual_available_water_cm=awah;request%field_capacity_deficit_cm=cdef;request%rainfall_cm=grai
 call evaluate_irrigation_management_policy(p,state,request,candidate,result,status)
 if(status/=IRR_MGMT_OK)error stop 1
 if(result%trigger.neqv.(irrigevent==2))error stop 2
 if(result%trigger)then
 call apply_irrigation_salinity_excess(.true.,.true.,cirrthres,perirrsurp,cml(1),result%selected_depth_cm,salt_applied,salt_ok)
 if(.not.salt_ok)error stop 7
 endif
 if(abs(result%selected_depth_cm-irr_depth)>1e-14_real64)error stop 3
 if(tcs==6.and.candidate%weekly_day_counter/=dayfix)error stop 4
 n=n+1
 enddo
 enddo
 enddo
 enddo
 if(n/=48)error stop 5
 negative_depth=1.0_real64
 call apply_irrigation_salinity_excess(.true.,.true.,1.0_real64,25.0_real64, &
 ieee_value(0.0_real64,ieee_quiet_nan),negative_depth,salt_applied,salt_ok)
 if(salt_ok.or.salt_applied.or.abs(negative_depth-1.0_real64)>epsilon(1.0_real64))error stop 8
 call apply_irrigation_salinity_excess(.true.,.true.,1.0_real64,25.0_real64,-1.0_real64,negative_depth,salt_applied,salt_ok)
 if(salt_ok.or.salt_applied.or.abs(negative_depth-1.0_real64)>epsilon(1.0_real64))error stop 9
 print '(A)','MC_IRR01_LITERAL_ROOT_SALT_48_CASES=PASS'
 print '(A)','MC_IRR01_ROOT_SALT_INVALID_CONCENTRATION=PASS'
contains
 real(real64) function afgen(table,length,x)
 integer,intent(in)::length
 real(real64),intent(in)::table(length),x
 ! These witnesses use constant tables. Identity guards bind the actual
 ! decision/depth operators, interpolation is separately covered by owner tests.
 if(length/=14.or.x<0.0_real64)error stop 6
 afgen=table(2)
 end function
end program
'''
pathlib.Path(sys.argv[1],'oracle.f90').write_text(program)
PY
for opt in 0 2; do
  mkdir -p "$BUILD/o$opt"
  gfortran -std=f2008 -ffree-line-length-none -Wall -Wextra -Werror -Wno-error=compare-reals -Wno-error=unused-dummy-argument -fcheck=all -ffpe-trap=invalid,zero,overflow -O"$opt" \
    -J "$BUILD/o$opt" -I "$BUILD/o$opt" src/solver/mod_soil_water_solver_contract.f90 src/solver/mod_process_hydraulic_view.f90 src/process/mod_irrigation_availability_policy.f90 src/process/mod_irrigation_process.f90 src/process/mod_scheduled_irrigation_management_policy.f90 "$BUILD/oracle.f90" -o "$BUILD/o$opt/test"
  "$BUILD/o$opt/test" > "$BUILD/o$opt/output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
cat "$BUILD/o0/output"
