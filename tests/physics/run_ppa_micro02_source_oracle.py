"""Compare standalone de Willigen with corrected literal B1.11 nonlinear source."""
import hashlib
import json
import os
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[2]
MEMBER = "reference/swap-4.3.1/b1_11_frost_source/SWAP/RWU_micro.f90"
PIN = "cac3d723cc11fb001878d53f2747bbff9fd53fb22949b682906df4361cb90477"
raw = (ROOT / MEMBER).read_bytes()
assert hashlib.sha256(raw).hexdigest() == PIN
source = raw.decode().replace("\r\n", "\n")
patches = [
    ("public :: do_RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table",
     "public :: do_RWU_micro, RWU_micro, read_rwu_micro_input, PP, PL, UpwPot, swAlpTot, M_table, K_table"),
    ("      start = int(100.d0*dlog10(-wiltpoint))",
     "      M_table=0d0; K_table=0d0\n      start = int(100.d0*dlog10(-wiltpoint))"),
    ("         M_table(start,lay) = 0.0d0",
     """         K_table(start,lay)=conduc1
         wcontent=watcon(i,wiltpoint)
         conduc2=hconduc(i,wiltpoint,wcontent,10d0)
         K_table(start+1,lay)=conduc2
         M_table(start,lay)=0.5d0*(conduc1+conduc2)*(phead1-wiltpoint)"""),
    ("      else if (H > -1.023293d0) then",
     """      else if (H <= -10d0**(dble(int(100d0*dlog10(-wiltpoint)))/100d0)) then
         start=int(100d0*dlog10(-wiltpoint))
         phead1=-10d0**(dble(start)/100d0)
         c0=H-wiltpoint
         c1=c0/(phead1-wiltpoint)
         M=K_table(start+1,lay)*c0+0.5d0*(K_table(start,lay)-K_table(start+1,lay))*c0*c1
         if(Kpresent)K=K_table(start+1,lay)+(K_table(start,lay)-K_table(start+1,lay))*c1
      else if (H > -1.023293d0) then"""),
    ("   ! convergence reached (NB: we assume TolConv > Tol_2)",
     "   fxp = myFun(xp) ! synchronize X with the selected pressure after endpoint acceptance\n"
     "   ! convergence reached (NB: we assume TolConv > Tol_2)"),
]
for old, new in patches:
    assert source.count(old) == 1, old
    source = source.replace(old, new)

STUBS = """module parameters
implicit none
real(8),parameter::pi=3.1415926535897932384626433832795d0
end module
module MOD_grid
implicit none
integer,parameter::numnod=2,numlay=1
integer::layer(2)=[1,1],nod1lay(1)=[1]
real(8)::dz(2)=[10d0,10d0]
end module
module MOD_arrays
implicit none
integer,parameter::macp=128
end module
module MOD_swap_base
implicit none
integer,parameter::unit_log=6,unit_err=6
logical::fl_do_not_read_crpfile=.true.
end module
module plant_interface
implicit none
integer::unit_crp=10,sw_oxygen=0
character(80)::crpfilnam='unused'
end module
module MOD_re_global
implicit none
real(8)::hroot(2),mroot(2),mflux(2)
end module
module variables
implicit none
real(8)::h(2),t1900=0d0,ksatfit(1)=[.01d0]
character(10)::date='2000-01-01'
end module
module MOD_MvG
implicit none
contains
real(8) function watcon(i,h)
integer,intent(in)::i
real(8),intent(in)::h
watcon=.3d0
end function
real(8) function hconduc(i,h,w,t)
integer,intent(in)::i
real(8),intent(in)::h,w,t
hconduc=.01d0
end function
end module
"""
TRAILER = """subroutine swap_error(where,message)
character(*),intent(in)::where,message
print *,where,message
error stop 99
end subroutine
subroutine swap_warning(where,message)
character(*),intent(in)::where,message
print *,where,message
end subroutine
subroutine rdinit(unit_in,unit_err,name)
integer,intent(in)::unit_in,unit_err
character(*),intent(in)::name
error stop 98
end subroutine
logical function rdinqr(name)
character(*),intent(in)::name
rdinqr=.false.
end function
subroutine rdsdor(name,lower,upper,value)
character(*),intent(in)::name
real(8),intent(in)::lower,upper
real(8),intent(out)::value
error stop 97
end subroutine
subroutine rdsinr(name,lower,upper,value)
character(*),intent(in)::name
integer,intent(in)::lower,upper
integer,intent(out)::value
error stop 96
end subroutine
"""
SOURCES = ["src/process/mod_root_micro_matric_flux_table.f90",
           "src/process/mod_root_micro_de_willigen_process.f90",
           "tests/physics/test_ppa_micro02_source_oracle.f90"]
outputs = {}
with tempfile.TemporaryDirectory(prefix="micro02-oracle-") as tmp:
    tmp = pathlib.Path(tmp)
    literal = tmp / "corrected_literal.f90"
    literal.write_text(STUBS + source + TRAILER)
    for opt in ("O0", "O2"):
        build = tmp / opt
        build.mkdir()
        binary = build / "test"
        subprocess.run(["gfortran", "-" + opt, "-ffree-line-length-none", "-fcheck=all",
                        "-ffpe-trap=invalid,zero,overflow", "-J" + str(build), "-I" + str(build),
                        str(literal), *(str(ROOT / p) for p in SOURCES), "-o", str(binary)],
                       cwd=build, check=True)
        execution = subprocess.run([str(binary)], capture_output=True, text=True, cwd=build)
        print(execution.stdout, end="")
        if execution.returncode:
            print(execution.stderr, end="")
            execution.check_returncode()
        outputs[opt] = execution.stdout
assert outputs["O0"] == outputs["O2"]
print("MICRO02_CORRECTED_LITERAL_O0_O2_IDENTICAL=PASS")
if os.environ.get("MICRO02_ORACLE_RESULT"):
    pathlib.Path(os.environ["MICRO02_ORACLE_RESULT"]).write_text(json.dumps({
        "schema": "swap5.micro02.corrected_literal.v1",
        "postimage": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "reference_sha256": PIN,
        "corrected_literal_sha256": hashlib.sha256(source.encode()).hexdigest(),
        "explicit_patches": patches,
        "source_sha256": {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [MEMBER, *SOURCES, "tests/physics/run_ppa_micro02_source_oracle.py"]},
        "runs": outputs,
        "claim_ceiling": "Homogeneous conductivity and bounded de Willigen source comparison only; no runtime admission",
    }, indent=2) + "\n")
