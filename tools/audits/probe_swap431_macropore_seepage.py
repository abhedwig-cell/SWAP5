#!/usr/bin/env python3
"""Compare active Ernst/Youngs components with the literal B1.11 algebra."""
import argparse
import base64
import gzip
import hashlib
import io
import json
from pathlib import Path
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
PROVIDER = 'src/process/macropore/mod_ppa_wu05a6_saturated_exchange_rate.f90'


def run(compiler, output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(gzip.decompress(base64.b64decode(bundle.read_bytes())))) as archive:
        raw = archive.extractfile('SWAP/macrorate.f90').read()
    source = raw.decode('latin1')
    start = source.index('               if (swsep == 1) then')
    end = source.index('               FlwMtxSatDmCp(ic)', start)
    block = source[start:end]
    # Literal branch, including the source partial-top multiplier. The external
    # parameters%pi carrier is explicitly supplied as acos(-1) for this probe.
    oracle = '''module literal_branch
contains
real(8) function reference(swsep,k,d,width,fraction)
integer,intent(in)::swsep
real(8),intent(in)::k,d,width,fraction
real(8)::DiPoCp(1),DZ(1),PpDmCp(1,1),Z(1),KSatHor,RecRes,ResHor,ResVrt,ResRad,Lev
real(8),parameter::pi=acos(-1d0),LogRatSeepFace=log(10d0),GeomFacSeep=16d0
real(8)::shapefacmp
integer::ic,id,CpTpZon
ic=1;id=1;CpTpZon=1;DiPoCp=d;DZ=width;PpDmCp=.3d0;Z=-5d0
KSatHor=k;shapefacmp=.8d0;Lev=Z(1)-.5d0*DZ(1)+fraction*DZ(1)
''' + block + '''reference=RecRes*.7d0*2d0*.125d0
end function
end module
'''
    driver = '''program probe
use mod_ppa_wu05a6_saturated_exchange_rate
use literal_branch
implicit none
type(saturated_exchange_request_t)::r
type(saturated_exchange_result_t)::v
integer::s,a,b,c,d,n
real(8)::ks(3)=[.1d0,1d0,10d0],diam(2)=[2d0,20d0],widths(2)=[1d0,10d0]
real(8)::fractions(2)=[.25d0,1d0],expected,err,worst
r%num_domains=1;r%num_nodes=1;r%matrix_top_saturated_node=1;r%matrix_bottom_saturated_node=1
r%step_duration=.125d0;r%flow_reduction=.7d0;r%shape_factor=.8d0
allocate(r%bottom_domain(1),r%top_macro_saturated_node(1),r%macro_saturated_fraction(1), &
 r%macro_reference_level(1),r%z(1),r%dz(1),r%matrix_head(1),r%ksat_horizontal(1), &
 r%diameter(1),r%domain_fraction(1,1),r%cdarcy(1,1))
r%bottom_domain=1;r%top_macro_saturated_node=1;r%macro_saturated_fraction=0d0
r%macro_reference_level=-5d0;r%z=-5d0;r%matrix_head=2d0;r%domain_fraction=.3d0;r%cdarcy=0d0
n=0;worst=0d0
do s=1,2
do a=1,3
do b=1,2
do c=1,2
do d=1,2
 r%swsep=s;r%ksat_horizontal=ks(a);r%diameter=diam(b);r%dz=widths(c)
 r%matrix_level=r%z(1)-.5d0*r%dz(1)+fractions(d)*r%dz(1)
 call evaluate_saturated_exchange(r,v)
 if(.not.v%valid)error stop 'invalid component result'
 expected=reference(s,ks(a),diam(b),widths(c),fractions(d))
 err=abs(v%signed_matrix_to_macro_amount_cm(1,1)-expected)/expected
 worst=max(worst,err);n=n+1
 if(err>1d-12)error stop 'literal branch mismatch'
 if(v%macro_to_matrix_amount_cm(1,1)/=0d0)error stop 'wrong direction'
enddo
enddo
enddo
enddo
enddo
write(*,'(I0,1X,ES24.16)')n,worst
end program
'''
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-seepage-') as tmp:
        wd = Path(tmp)
        (wd / 'oracle.f90').write_text(oracle)
        (wd / 'driver.f90').write_text(driver)
        for optimization in ['-O0', '-O2']:
            subprocess.run([compiler, optimization, '-ffree-line-length-none', '-fcheck=all',
                            '-ffpe-trap=invalid,zero,overflow', str(ROOT / PROVIDER),
                            'oracle.f90', 'driver.f90', '-o', 'probe'], cwd=wd,
                           check=True, capture_output=True)
            stdout = subprocess.check_output([str(wd / 'probe')], cwd=wd, text=True)
            count, error = stdout.split()
            assert int(count) == 48
            results.append({'optimization': optimization, 'cases': int(count),
                            'max_relative_error': float(error), 'stdout': stdout})
    evidence = {'schema': 'swap5.coverage.macropore_seepage_probe.v1',
                'source_member': 'SWAP/macrorate.f90',
                'source_sha256': hashlib.sha256(raw).hexdigest(),
                'provider': PROVIDER, 'provider_sha256': hashlib.sha256((ROOT / PROVIDER).read_bytes()).hexdigest(),
                'status': 'PASS_LITERAL_ACTIVE_BRANCH_COMPONENT_COMPARISON',
                'results': results, 'runtime_admission_created': False,
                'scope': 'SWSEP1/2 positive-K seepage-face algebra, full/partial top matrix compartment, matrix-to-macro direction only',
                'limitations': ['Explicit pi=acos(-1) external carrier assumption',
                                'No native geometry resolver or Richards callback qualification',
                                'No donor cap, candidate commit, retry, restart or whole-column admission',
                                'Zero horizontal conductivity and all other SATFLOW branches excluded']}
    Path(output).write_text(json.dumps(evidence, indent=2) + '\n')
    print(json.dumps(evidence, indent=2))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--compiler', default='gfortran')
    parser.add_argument('--output', required=True)
    args = parser.parse_args()
    run(args.compiler, args.output)
