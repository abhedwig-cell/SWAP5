#!/usr/bin/env python3
"""Falsify blanket DRAMET3 replacement by the admitted EXTENDED provider.

Runs the literal DRAMET3 branch with a constant OWLTAB evaluator. This isolates
the response rules; it does not qualify time interpolation or a full trajectory.
"""
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
PROVIDER = 'src/process/mod_drainage_extended_exchange.f90'
VIEW = 'src/solver/mod_process_hydraulic_view.f90'
CONTRACT = 'src/solver/mod_soil_water_solver_contract.f90'


def run(output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode='r:gz') as archive:
        raw = archive.extractfile('SWAP/drainage.f90').read()
    source = raw.decode('latin1')
    start = source.index('         do lev = 1,nrlevs', source.index('else if (dramet == 3) then'))
    end = source.index('         end do', start) + len('         end do')
    branch = source[start:end]
    program = '''module literal_dramet3
implicit none
contains
real(8) function afgen(table,n,t)
integer,intent(in)::n
real(8),intent(in)::table(n),t
afgen=table(2)
end function
real(8) function reference(gwl,wl,allow,limit)
real(8),intent(in)::gwl,wl
integer,intent(in)::allow,limit
integer::lev,nrlevs=1,nowltab(1)=1,swmacro=0,swdrrap=0,numlevrapdra=1
integer::swdtyp(1)=2,swallo(1),swliminf,swnrsrf=0
real(8)::owltab(1,2),drainl(1),zbotdr(1)=-100d0,diffl(1),qdrain(1)
real(8)::drares(1)=100d0,infres(1)=200d0,cofintfl=1d0,expintfl=1d0
real(8)::t1900=1d0,dt=1d0,zdrabas
swallo=allow;swliminf=limit;owltab(1,:)=[0d0,wl]
''' + branch + '''
reference=qdrain(1)
end function
end module
program probe
use literal_dramet3
use mod_drainage_extended_exchange
use mod_process_hydraulic_view
implicit none
type(extended_drainage_parameters_t)::p
type(extended_drainage_control_t)::c
type(extended_drainage_result_t)::r
type(extended_drainage_diagnostics_t)::d
type(process_hydraulic_view_t)::v
real(8)::g(4)=[-150d0,-90d0,-99.9995d0,-80d0]
real(8)::w(4)=[-80d0,-80d0,-100d0,-90d0]
real(8)::q
integer::i
p%zbotdr_cm=-100d0;p%drain_type=EXT_DRAIN_OPEN_CHANNEL
p%width_cm=10d0;p%talud=1d0;p%spacing_cm=1000d0
p%rdrain_day=100d0;p%rinfi_day=200d0
p%rentry_day=0d0;p%rexit_day=0d0;p%gwlinf_cm=-100d0;p%pondmx_cm=1d0
v%ponding_depth=0d0
do i=1,4
 v%groundwater_level=g(i);c%resolved_surface_water_head_cm=w(i)
 call evaluate_extended_drainage_exchange(p,v,c,r,d)
 if(d%status/=EXT_DRAIN_OK)error stop 'provider invalid'
 q=reference(g(i),w(i),1,1)
 write(*,'(I2,2ES25.16)') i,q,r%signed_soil_to_surface_rate_cm_day
 if(i/=3.and.abs(q-r%signed_soil_to_surface_rate_cm_day)>1d-14)error stop 'bulk mismatch'
 if(i==3.and.(q<=0d0.or.r%signed_soil_to_surface_rate_cm_day/=0d0))error stop 'missing seam witness'
end do
! Direction controls produce distinct outputs on the same physical inputs.
if(reference(-80d0,-90d0,2,1)/=0d0)error stop 'drain-only suppression'
if(reference(-90d0,-80d0,3,1)/=0d0)error stop 'infiltration suppression'
if(abs(reference(-150d0,-80d0,1,0)+.35d0)>1d-14)error stop 'uncapped infiltration'
if(abs(reference(-150d0,-80d0,1,1)+.1d0)>1d-14)error stop 'capped infiltration'
write(*,'(A)')'DRAMET3_REPLACEMENT_COUNTEREXAMPLE_PASS'
end program
'''
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-dramet3-') as tmp:
        work = Path(tmp)
        (work / 'probe.f90').write_text(program)
        for optimization in ['-O0', '-O2']:
            command = ['gfortran', optimization, '-ffree-line-length-none', '-fcheck=all',
                       '-ffpe-trap=invalid,zero,overflow', str(ROOT / CONTRACT), str(ROOT / VIEW),
                       str(ROOT / PROVIDER), 'probe.f90', '-o', 'probe']
            subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
            stdout = subprocess.check_output([str(work / 'probe')], cwd=work, text=True)
            results.append({'optimization': optimization, 'stdout': stdout})
    assert results[0]['stdout'] == results[1]['stdout']
    evidence = {
        'schema_version': '1.0', 'source_member': 'SWAP/drainage.f90',
        'source_sha256': hashlib.sha256(raw).hexdigest(),
        'source_files_sha256': {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in [CONTRACT, VIEW, PROVIDER]},
        'scope': 'Literal DRAMET3 branch; constant OWLTAB stub; four response comparisons and four direction/cap checks per optimization. No complete source runtime.',
        'finding': 'Zero-entry/exit-resistance EXTENDED with GWLINF=ZBOTDR reproduces the three ordinary bulk cases, but suppresses a positive DRAMET3 flux of approximately 5e-6 cm/day within its independent 0.001cm activation seam. Therefore blanket source-equivalent replacement is unproven and numerically false at this valid input.',
        'runtime_admission_created': False, 'results': results,
    }
    output.write_text(json.dumps(evidence, indent=2) + '\n')
    print('DRAMET3 source counterexample reproduced at O0/O2')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
