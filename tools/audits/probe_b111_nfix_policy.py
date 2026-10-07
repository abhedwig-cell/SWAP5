#!/usr/bin/env python3
"""Exact B1.11 NFIX demand oracle against the separate SWAP5 B1.11 policy."""
import base64
import io
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
bundle = ROOT / "integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64"
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode="r:gz") as archive:
    raw = archive.extractfile("SWAP/wofostnut.f90").read()
source = raw.decode("latin1")
start = source.index("      ndeml =", source.index("   subroutine demand_wofost_nut"))
end = source.index("      return", start)
literal = source[start:end]

program = """module literal_nfix
implicit none
contains
real(8) function reference(dvs,reltr,wso)
real(8),intent(in)::dvs,reltr,wso
real(8)::wlv=1000d0,wst=800d0,wrt=600d0
real(8)::nmaxlv=.03d0,nmaxst=.015d0,nmaxrt=.015d0,nmaxso=.0176d0
real(8)::anlv=0d0,anst=0d0,anrt=0d0,anso=0d0,tcnt=10d0,nfixf=.2d0,dvsnlt=1d0
real(8)::ndeml,ndems,ndemr,ndemso,ndemto,nlimit,NdemandSoil,NdemandBioFix
""" + literal + """
reference=NdemandBioFix
end function
end module
program probe
use literal_nfix
use mod_b111_crop_n_fixation_policy
implicit none
type(b111_nfix_request_t)::q
real(8)::dvs(6)=[.5d0,1d0,.5d0,.5d0,.5d0,.5d0]
real(8)::reltr(6)=[1d0,1d0,1d0,1d0,.01d0,.0100001d0]
real(8)::storage(6)=[0d0,0d0,200d0,0d0,0d0,0d0]
real(8)::growth(6)=[0d0,0d0,0d0,20d0,0d0,0d0]
real(8)::old
integer::i
do i=1,6
 old=reference(dvs(i),reltr(i),storage(i))
 call prepare_b111_nfix_request(dvs(i),reltr(i),1d0,.2d0,1000d0,800d0,600d0, &
      .03d0,.015d0,.015d0,0d0,0d0,0d0,q)
 if(q%status/=B111_NFIX_OK)error stop 'policy invalid'
 if(abs(old-q%fixation_request)>1d-12)error stop 'literal mismatch'
 write(*,'(I2,2ES25.16)')i,old,q%fixation_request
end do
print '(A)','B111_NFIX_LITERAL_ORACLE_PASS'
end program
"""

with tempfile.TemporaryDirectory(prefix="swap431-b111-nfix-") as tmp:
    work = Path(tmp)
    (work / "probe.f90").write_text(program)
    outputs = []
    for opt in ("-O0", "-O2"):
        subprocess.run([
            "gfortran", opt, "-ffree-line-length-none", "-fcheck=all",
            "-ffpe-trap=invalid,zero,overflow",
            str(ROOT / "src/crop/mod_b111_crop_n_fixation_policy.f90"),
            "probe.f90", "-o", "probe",
        ], cwd=work, check=True)
        run = subprocess.run([str(work / "probe")], cwd=work, check=True, capture_output=True, text=True)
        outputs.append(run.stdout)
    if outputs[0] != outputs[1]:
        raise SystemExit("O0/O2 output mismatch")
    print(outputs[0], end="")
