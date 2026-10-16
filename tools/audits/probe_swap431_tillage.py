#!/usr/bin/env python3
"""Bounded defect probe of the literal B1.11 Adapt_WC_H routine, not admission."""
import argparse
import base64
import gzip
import hashlib
import io
import json
import subprocess
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def probe(compiler):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(base64.b64decode(bundle.read_bytes())))) as archive:
        raw = archive.extractfile('SWAP/tillage.f90').read()
    source = raw.decode('latin1')
    start = source.lower().index('   subroutine adapt_wc_h (test)')
    end = source.lower().index('   end subroutine adapt_wc_h', start)
    routine = source[start:end] + '   end subroutine Adapt_WC_H\n'
    # The saturated one-node case never calls the inverse. The second case
    # deliberately has equal unweighted sums; neither redistribution branch runs.
    prefix = '''module MOD_MvG
contains
real(8) function watcon(i,head)
integer :: i
real(8) :: head
watcon=0.25d0
end function
real(8) function prhead(i,dis,theta,cof,h)
integer :: i
real(8) :: dis,theta,cof(:,:),h(:)
prhead=0d0
end function
end module
module literal_probe
integer,parameter :: MaxNumSoilCP=2
integer :: iRedist,layer(2)=1
real(8) :: h(2)=0d0,theta(2),dz(2),disnod(2)=0d0,ParamVG(8,1)=0d0
real(8) :: CofGen(8,1)=0d0,pond,sumDWC,sumAvail1,sumAvail2
character(10) :: Date='probe'
contains
subroutine swap_error(a,b)
character(*) :: a,b
error stop 'unexpected source error'
end subroutine
'''
    driver = '''end module
program run_probe
use literal_probe
use MOD_MvG, only: watcon
real(8) :: before,after
! Two identical saturated nodes, exact binary fractions and widths.
iRedist=1; theta=0.375d0; dz=4d0; ParamVG(2,1)=0.25d0; pond=0d0
before=sum(theta*dz)+pond
call Adapt_WC_H(.false.)
after=sum(theta*dz)+pond
write(*,'(A,3F12.6)') 'simple ',before,after,pond
if (before/=3d0.or.after/=1d0.or.pond/=-1d0) error stop 'unexpected simple result'
! Equal sum(theta), different thickness-weighted inventory: no branch updates theta.
iRedist=2; theta=[0.375d0,0.125d0]; dz=[8d0,1d0]; pond=0d0
call Adapt_WC_H(.false.)
write(*,'(A,2F12.6)') 'complex_inverse_mismatch ',theta(1)-watcon(1,h(1)),theta(2)-watcon(2,h(2))
if (any(theta/=[0.375d0,0.125d0])) error stop 'unexpected complex result'
end program
'''
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-tillage-') as tmp:
        path = Path(tmp)
        (path / 'probe.f90').write_text(prefix + routine + driver)
        for opt in ['-O0', '-O2']:
            command = [compiler, opt, '-ffree-line-length-none', '-fcheck=all',
                       '-ffpe-trap=invalid,zero,overflow', 'probe.f90', '-o', 'probe']
            subprocess.run(command, cwd=path, check=True, capture_output=True, text=True)
            output = subprocess.check_output([str(path / 'probe')], cwd=path, text=True)
            results.append({'optimization': opt, 'stdout': output})
    assert results[0]['stdout'] == results[1]['stdout']
    return {'schema_version': '1.0', 'authority': 'B1.11',
            'source_member': 'SWAP/tillage.f90', 'source_sha256': hashlib.sha256(raw).hexdigest(),
            'routine': 'Adapt_WC_H', 'literal_source_lines': [270, 376],
            'scope': 'Literal extracted routine with stubbed constitutive queries; no full executable or SWAP5 admission.',
            'findings': [
                {'selector': 'IREDIST=1', 'finding': 'Oversaturation makes summ negative; redistribution is skipped and pond becomes negative. Initial 3 cm becomes 1 cm total water including pond: 2 cm lost.'},
                {'selector': 'IREDIST=2', 'finding': 'Equal unweighted theta sums skip both updates even with unequal cell widths. After material change the retained theta differs from watcon(h) by +/-0.125. This does not prove every IREDIST2 trajectory defective.'}],
            'decision': 'Register reference-defect review and conservative replacement requirements; do not reproduce these results as production physics.',
            'production_reachability': False, 'results': results}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--compiler', default='gfortran')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = probe(args.compiler)
    args.output.write_text(json.dumps(result, indent=2) + '\n')
    print('B1.11 tillage defect probe: reproduced at O0 and O2; no admission claim')
