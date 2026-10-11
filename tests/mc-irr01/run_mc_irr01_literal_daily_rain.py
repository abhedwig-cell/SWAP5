#!/usr/bin/env python3
"""Execute authenticated B1.11 DCS rain/depth statements against the owner.

This is a source-policy oracle, not an application weather-hook qualification.
"""
import base64
import hashlib
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
IDENTITIES = {
    "SWAP/irrigation.f90": "65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1",
    "SWAP/MOD_meteo.f90": "99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f",
    "SWAP/swap.f90": "39d1cbd93dbd0f99505e92ef94ac0d23bddb496529c280397d2d7c2b7eb9b58a",
}


def main():
    archive = ROOT / "integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
    sources = {}
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())), mode="r:gz") as bundle:
        for suffix, expected in IDENTITIES.items():
            members = [m for m in bundle.getmembers() if m.name.endswith(suffix)]
            assert len(members) == 1, suffix
            raw = bundle.extractfile(members[0]).read()
            assert hashlib.sha256(raw).hexdigest() == expected, suffix
            sources[suffix] = raw.decode("latin1")

    # Ordinary standalone scheduled selection uses today's Meteo(task2),
    # before timestep Meteo(task3). DLL and MultiSWAP routing are separate.
    daystart = sources["SWAP/swap.f90"].split("if (flDayStart) then", 1)[1]
    assert daystart.index("call Meteo(2)") < daystart.index("call Irrigation(3)")
    assert daystart.index("call Irrigation(3)") < daystart.index("call Meteo(3)")
    meteo = sources["SWAP/MOD_meteo.f90"]
    daily_assignment = next(line.strip() for line in meteo.splitlines() if line.strip() == "grai = arai(meteo_rec)")
    detailed_assignment = next(line.strip() for line in meteo.splitlines() if line.strip() == "grai = grai + arai(i_rec)")
    depth = sources["SWAP/irrigation.f90"].split("! depth - back to field capacity [cm]", 1)[1]
    depth = depth.split("! in case of solutes: allow overirrigation", 1)[0]

    program = '''program literal_daily_rain
use iso_fortran_env, only: real64
use mod_scheduled_irrigation_management_policy
implicit none
type(irrigation_management_policy_parameters_t) :: p
type(irrigation_management_policy_request_t) :: request
type(irrigation_management_policy_result_t) :: result
real(real64) :: grai,raithreshold,grai_red,cdef,dps1,dps2,dvs,ditab(14),fidtab(14)
real(real64) :: irr_depth,irgdepmin,irgdepmax,arai(4),daily_depth,partial_depth
real(real64),parameter :: rain_cases(8)=[0.0_real64,0.5_real64-1e-10_real64,0.5_real64, &
  0.5_real64+1e-10_real64,0.6_real64,1.2_real64,5.0_real64,10.0_real64]
real(real64),parameter :: adjustments(3)=[-1.0_real64,0.0_real64,2.0_real64]
real(real64),parameter :: deficits(3)=[0.0_real64,2.0_real64,5.0_real64]
integer :: dcs,dcslim,ir,ia,ic,mode,status,n,meteo_rec,i_rec
n=0;dvs=1.0_real64;raithreshold=0.5_real64
irgdepmin=5.0_real64;irgdepmax=30.0_real64
do dcs=1,2
do ir=1,8
do ia=1,3
do ic=1,3
do mode=0,1
  grai=rain_cases(ir);cdef=deficits(ic);dcslim=mode
  ditab=0.0_real64;ditab(2)=adjustments(ia)
  fidtab=0.0_real64;fidtab(2)=12.0_real64
  irr_depth=0.0_real64;grai_red=0.0_real64
''' + depth + '''
  p=irrigation_management_policy_parameters_t()
  p%depth_criterion=dcs;p%rainfall_threshold_cm=raithreshold
  p%dcs1_knot_count=2;p%dcs1_dvs(1:2)=[0.0_real64,2.0_real64]
  p%dcs1_adjustment_mm(1:2)=ditab(2)
  p%dcs2_knot_count=2;p%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
  p%dcs2_depth_cm(1:2)=0.1_real64*fidtab(2)
  p%depth_limit_enabled=dcslim==1
  p%minimum_depth_cm=0.1_real64*irgdepmin;p%maximum_depth_cm=0.1_real64*irgdepmax
  request=irrigation_management_policy_request_t()
  request%dvs=dvs;request%field_capacity_deficit_cm=cdef;request%rainfall_cm=grai
  result=irrigation_management_policy_result_t()
  call evaluate_irrigation_management_depth(p,request,result,status)
  if(status/=IRR_MGMT_OK)error stop 1
  if(abs(result%selected_depth_cm-irr_depth)>1e-14_real64)error stop 2
  if(dcs==1)then
    if(result%rainfall_deducted.neqv.(grai_red>0.0_real64))error stop 3
  else
    if(result%rainfall_deducted)error stop 4
  endif
  n=n+1
enddo
enddo
enddo
enddo
enddo
if(n/=288)error stop 5
! Execute literal daily assignment and detailed daily accumulation. Both
! yield the daily selection rain, independent of later interval splitting.
arai=0.15_real64;arai(1)=0.6_real64;meteo_rec=1
''' + daily_assignment + '''
if(abs(grai-0.6_real64)>1e-14_real64)error stop 6
arai=0.15_real64;grai=0.0_real64
do i_rec=1,4
''' + detailed_assignment + '''
enddo
if(abs(grai-0.6_real64)>1e-14_real64)error stop 7
p%depth_criterion=1;p%depth_limit_enabled=.false.
p%dcs1_adjustment_mm(1:2)=-1.0_real64
request%field_capacity_deficit_cm=2.0_real64;request%rainfall_cm=grai
call evaluate_irrigation_management_depth(p,request,result,status)
if(status/=IRR_MGMT_OK)error stop 8
daily_depth=result%selected_depth_cm
request%rainfall_cm=0.25_real64*grai
call evaluate_irrigation_management_depth(p,request,result,status)
if(status/=IRR_MGMT_OK)error stop 9
partial_depth=result%selected_depth_cm
if(abs(daily_depth-1.3_real64)>1e-14_real64)error stop 10
if(abs(partial_depth-1.9_real64)>1e-14_real64)error stop 11
! Equality must not activate the source's strictly-greater rain deduction.
request%rainfall_cm=raithreshold
call evaluate_irrigation_management_depth(p,request,result,status)
if(status/=IRR_MGMT_OK.or.result%rainfall_deducted)error stop 12
if(abs(result%selected_depth_cm-1.9_real64)>1e-14_real64)error stop 13
print '(A)', 'MC_IRR01_LITERAL_DAILY_RAIN_288_CASES=PASS'
print '(A)', 'MC_IRR01_DAILY_VS_QUARTER_WINDOW_1_3_VS_1_9_CM=PASS'
print '(A)', 'MC_IRR01_STRICT_RAIN_THRESHOLD_EQUALITY=PASS'
contains
real(real64) function afgen(table,length,x)
integer,intent(in)::length
real(real64),intent(in)::table(length),x
if(length/=14.or.x<0.0_real64)error stop 14
afgen=table(2)
end function
end program
'''
    outputs = []
    with tempfile.TemporaryDirectory(prefix="mc-irr01-daily-rain-") as directory:
        build = Path(directory)
        oracle = build / "oracle.f90"
        oracle.write_text(program)
        for opt in (0, 2):
            variant = build / f"o{opt}"
            variant.mkdir()
            subprocess.run([
                "gfortran", "-std=f2008", "-ffree-line-length-none", "-Wall", "-Wextra", "-Werror",
                "-fcheck=all", "-ffpe-trap=invalid,zero,overflow", f"-O{opt}",
                "-J", str(variant), "-I", str(variant),
                str(ROOT / "src/process/mod_scheduled_irrigation_management_policy.f90"),
                str(oracle), "-o", str(variant / "test"),
            ], check=True)
            outputs.append(subprocess.check_output([str(variant / "test")]))
    assert outputs[0] == outputs[1], "O0/O2 source-policy mismatch"
    print(outputs[0].decode(), end="")
    print("MC_IRR01_LITERAL_DAILY_RAIN_O0_O2=PASS")


if __name__ == "__main__":
    main()
