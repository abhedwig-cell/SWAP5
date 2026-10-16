#!/usr/bin/env python3
"""Compare literal CALCGWL values with the bounded smooth projection service."""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]

STUBS = '''module MOD_swap_base
integer::swmacro=0,i_instance=1
end module
module MOD_grid
integer::numnod=4
real(8)::disnod(4)=[5d0,10d0,10d0,10d0],z(4)=[-5d0,-15d0,-25d0,-35d0]
real(8)::dz(4)=10d0,zbotcp(4)=[-10d0,-20d0,-30d0,-40d0]
end module
module variables
integer::swbotb=2,nodgwl,bpegwl,npegwl
real(8)::gwlinp=-20d0,h(4),pond=0d0,t1900=0d0,gwl,pegwl,pegwl_bot
real(8)::gwlm1=-20d0,gwlconv=1d9,theta(4)=.3d0,thetas(4)=.4d0
end module
module MOD_swap_mp
real(8)::CritUndSatVol=.1d0,gwlflcpzo
integer::nodgwlflcpzo
end module
subroutine swap_error(where,message)
character(*)::where,message
print *,where,message
stop 7
end subroutine
subroutine swap_warning(where,message)
character(*)::where,message
print *,where,message
end subroutine
subroutine dtdpst(format,time,out)
character(*)::format,out
real(8)::time
out='probe'
end subroutine
'''

DRIVER = '''program probe
use MOD_grid
use variables
use MOD_gwl
use mod_b110_smooth_freatic_projection
implicit none
integer::i
real(8)::value,direction,zero(4)=0d0
type(b110_smooth_freatic_projection_diagnostics_t)::diagnostic
do i=1,6
 pond=0d0
 select case(i)
 case(1)
  h=[-20d0,-5d0,5d0,20d0]
 case(2)
  h=[1d0,10d0,20d0,30d0]
 case(3)
  h=[1d0,10d0,20d0,30d0]
  pond=2d0
 case(4)
  h=[-20d0,-20d0,-10d0,-1d0]
 case(5)
  h=[-20d0,-10d0,-5d0,0d0]
 case(6)
  h=0d0
 end select
 call calcgwl()
 call evaluate_b110_smooth_freatic_projection(2,.false.,z,disnod,h,zero,value,direction,diagnostic)
 write(*,'(I2,1X,F12.6,1X,I3,1X,L1,1X,F12.6)')i,gwl,diagnostic%status,diagnostic%value_defined,value
end do
end program
'''


def run(output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode='r:gz') as archive:
        raw = archive.extractfile('SWAP/calcgwl.f90').read()
    current = 'src/solver/mod_b110_smooth_freatic_projection.f90'
    expected = [(-20, 0, True), (-4, 5, False), (2, 5, False),
                (999, 4, False), (-35, 6, False), (0, 6, False)]
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-gwl-') as tmp:
        work = Path(tmp)
        (work / 'stubs.f90').write_text(STUBS)
        (work / 'calcgwl.f90').write_bytes(raw)
        (work / 'driver.f90').write_text(DRIVER)
        for optimization in ['-O0', '-O2']:
            command = ['gfortran', optimization, '-ffree-line-length-none', '-fcheck=all',
                       'stubs.f90', 'calcgwl.f90', str(ROOT / current), 'driver.f90', '-o', 'probe']
            subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
            result = subprocess.run([str(work / 'probe')], cwd=work, check=True, capture_output=True, text=True)
            rows = [line.split() for line in result.stdout.splitlines()]
            assert len(rows) == len(expected), result.stdout
            for row, (value, status, defined) in zip(rows, expected):
                assert float(row[1]) == value and int(row[2]) == status
                assert (row[3] == 'T') == defined
                if defined:
                    assert float(row[4]) == value
            results.append(dict(optimization=optimization, stdout=result.stdout, cases=len(rows), passed=True))
    assert results[0]['stdout'] == results[1]['stdout']
    record = dict(schema_version='1.0', source_member='SWAP/calcgwl.f90',
                  source_sha256=hashlib.sha256(raw).hexdigest(),
                  production_source=current, production_sha256=hashlib.sha256((ROOT / current).read_bytes()).hexdigest(),
                  driver_sha256=hashlib.sha256(DRIVER.encode()).hexdigest(),
                  stubs_sha256=hashlib.sha256(STUBS.encode()).hexdigest(),
                  results=results,
                  conclusion='Literal CALCGWL defines five tested non-smooth/outside-interior values deliberately excluded by the smooth directional service. Interior value agrees.',
                  nonclaims=['No defect in the bounded smooth service.', 'No production runtime qualification or new admission.',
                             'No claim that external MODFLOW head ownership should be replaced by internal diagnostic GWL.'])
    output.write_text(json.dumps(record, indent=2) + '\n')
    print('PASS: six literal/current-service cases per O0/O2; identical stdout')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
