"""Compile hash-pinned B1.11 source fragments without changing the reference."""
import argparse
import hashlib
from pathlib import Path
import subprocess
import tempfile

EXPECTED = "f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--compiler", default="gfortran")
    args = parser.parse_args()
    raw = args.source.read_bytes()
    if hashlib.sha256(raw).hexdigest() != EXPECTED:
        raise SystemExit("Reference source SHA-256 mismatch")
    lines = raw.decode("utf-8").splitlines()
    storage = "\n".join(lines[1318:1352])
    inventory = "\n".join(lines[1619:1626])
    program = """program reference_gaps
implicit none
call storage_probe(1)
call storage_probe(2)
call inventory_probe()
contains
subroutine storage_probe(swmbf)
integer,intent(in) :: swmbf
integer :: id,ic,icgwl,NumDm,ICTopMP,ICpBtDm(2)
double precision :: WaSrMp,WaSrMpDm(2),WaUnMpDm(2),QInTopLatDm(2),QInTopVrtDm(2)
double precision :: QExcMtxDmCp(2,3),QOutDrRapCp(3),dt,MPwatbal
double precision :: WaUnMpDmCp(2,3),VlMpDmCp(2,3),WaUnsat(2)
NumDm=2; ICTopMP=1; ICpBtDm=3; dt=1.d0
WaSrMpDm=0.d0; QInTopLatDm=0.d0; QInTopVrtDm=0.d0
QExcMtxDmCp=0.d0; QOutDrRapCp=0.d0
WaUnMpDmCp=0.5d0; VlMpDmCp=1.d0; WaUnsat=0.d0
""" + storage + """
write(*,'(A,I0,A,I0)') 'MODE=',swmbf,' ICGWL=',icgwl
end subroutine
subroutine inventory_probe()
integer :: id,NumDm,NumNod,iteration
double precision :: IWaSrDm1Beg,IWaSrDm2Beg,WaSrDm1,WaSrDm2
double precision :: IWaUnDm1CpBeg(2),IWaUnDm2CpBeg(2),WaUnMpDmCp(2,2)
NumDm=2; NumNod=2; WaSrDm1=1.d0; WaSrDm2=2.d0
IWaUnDm2CpBeg=0.d0; WaUnMpDmCp(1,:)=1.d0; WaUnMpDmCp(2,:)=2.d0
do iteration=1,2
""" + inventory + """
write(*,'(A,I0,A,F4.1)') 'RESET=',iteration,' INTERNAL=',IWaUnDm2CpBeg(1)
end do
end subroutine
end program
"""
    with tempfile.TemporaryDirectory(prefix="swap5-reference-gaps-") as build:
        root = Path(build)
        driver = root / "probe.f90"
        driver.write_text(program, encoding="utf-8")
        for sentinel in (-777, -991):
            transcripts = []
            for opt in ("O0", "O2"):
                exe = root / f"probe-{opt}-{sentinel}.exe"
                command = [args.compiler, "-std=f2008", "-ffree-line-length-none",
                           "-fcheck=all", "-ffpe-trap=invalid,zero,overflow",
                           f"-finit-integer={sentinel}", f"-{opt}", str(driver), "-o", str(exe)]
                subprocess.run(command, check=True, capture_output=True, text=True)
                output = subprocess.run([str(exe)], check=True, capture_output=True, text=True).stdout
                expected = [f"MODE=1 ICGWL={sentinel}", "MODE=2 ICGWL=3",
                            "RESET=1 INTERNAL= 2.0", "RESET=2 INTERNAL= 4.0"]
                if output.splitlines() != expected:
                    raise RuntimeError(f"Unexpected source observation: {output!r}")
                transcripts.append(output)
            if transcripts[0] != transcripts[1]:
                raise RuntimeError("Optimization-dependent source observation")
    print("B111_SOURCE_HASH=PASS")
    print("ICGWL_SWMBF1_UNASSIGNED_TWO_SENTINELS=REPRODUCED")
    print("RESET_INTERNAL_PROFILE_ACCUMULATION=REPRODUCED")
    print("O0_O2_SOURCE_OBSERVATIONS=IDENTICAL")


if __name__ == "__main__":
    main()
