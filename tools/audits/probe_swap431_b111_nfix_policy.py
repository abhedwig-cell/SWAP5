#!/usr/bin/env python3
"""Exact B1.11 fixation-policy oracle against the separate SWAP5 policy."""
import base64
import io
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROVIDER = ROOT / "src/crop/mod_b111_nfixation_policy.f90"

AUTHORITY_COMMIT = "4e4da22bdea9fa5e5861d6d5726eddd425d20805"
AUTHORITY_PATH = "integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
bundle = ROOT / AUTHORITY_PATH
if bundle.exists():
    encoded = bundle.read_bytes()
else:
    subprocess.run(["git", "fetch", "--depth=1", "origin", AUTHORITY_COMMIT],
                   cwd=ROOT, check=True, capture_output=True)
    encoded = subprocess.run(["git", "show", f"{AUTHORITY_COMMIT}:{AUTHORITY_PATH}"],
                             cwd=ROOT, check=True, capture_output=True).stdout
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(encoded)), mode="r:gz") as archive:
    source = archive.extractfile("SWAP/wofostnut.f90").read().decode("latin1")

start = source.index("      ndeml =", source.index("   subroutine demand_wofost_nut"))
end = source.index("      return", start)
literal = source[start:end]

program = """module literal_nfix
implicit none
contains
subroutine reference(dvs,reltr,wso,fixation)
real(8),intent(in)::dvs,reltr,wso
real(8),intent(out)::fixation
real(8)::wlv=1000d0,wst=800d0,wrt=600d0
real(8)::nmaxlv=.03d0,nmaxst=.015d0,nmaxrt=.015d0,nmaxso=.0176d0
real(8)::anlv=0d0,anst=0d0,anrt=0d0,anso=0d0,tcnt=10d0,nfixf=.2d0,dvsnlt=1d0
real(8)::ndeml,ndems,ndemr,ndemso,ndemto,nlimit,NdemandSoil,NdemandBioFix
""" + literal + """
fixation=NdemandBioFix
end subroutine
end module
program probe
use literal_nfix
use mod_b111_nfixation_policy
implicit none
type(b111_nfixation_result_t)::r
real(8)::dvs(6)=[.5d0,1d0,.5d0,.5d0,.5d0,.5d0]
real(8)::reltr(6)=[1d0,1d0,1d0,1d0,.01d0,.0100001d0]
real(8)::storage(6)=[0d0,0d0,200d0,0d0,0d0,0d0]
real(8)::old
integer::i
do i=1,6
 call reference(dvs(i),reltr(i),storage(i),old)
 call evaluate_b111_nfixation(dvs(i),1d0,reltr(i),.2d0,.03d0,.015d0,.015d0, &
      1000d0,800d0,600d0,0d0,0d0,0d0,r)
 if(r%status/=B111_NFIX_OK)error stop 'policy invalid'
 if(abs(old-r%fixation)>1d-12)then
   write(*,'(A,I0,2ES25.16)')'mismatch case ',i,old,r%fixation
   error stop 1
 end if
end do
print '(A)','B111_NFIXATION_SOURCE_ORACLE_PASS'
end program
"""

with tempfile.TemporaryDirectory(prefix="swap431-b111-nfix-") as td:
    work = Path(td)
    (work / "probe.f90").write_text(program)
    outputs = []
    for opt in ("-O0", "-O2"):
        subprocess.run(["gfortran", opt, "-std=f2008", "-ffree-line-length-none",
                        "-fcheck=all", "-ffpe-trap=invalid,zero,overflow",
                        str(PROVIDER), "probe.f90", "-o", "probe"],
                       cwd=work, check=True)
        cp = subprocess.run([str(work / "probe")], cwd=work, check=True,
                            capture_output=True, text=True)
        outputs.append(cp.stdout)
    if outputs[0] != outputs[1]:
        raise SystemExit("O0/O2 oracle output differs")
    print(outputs[0], end="")
