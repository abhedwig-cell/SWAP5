#!/usr/bin/env python3
"""Literal B1.11 crop N-demand versus the current WOFOST81 request operator.

An equation discrimination probe, not full-season or runtime admission.
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
PROVIDER = 'src/crop/mod_wofost81_nitrogen.f90'


def run(output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode='r:gz') as archive:
        raw = archive.extractfile('SWAP/wofostnut.f90').read()
    source = raw.decode('latin1')
    start = source.index('      ndeml =', source.index('   subroutine demand_wofost_nut'))
    end = source.index('      return', start)
    literal = source[start:end]
    program = '''module literal_nfix
implicit none
contains
real(8) function reference(dvs,reltr,wso)
real(8),intent(in)::dvs,reltr,wso
real(8)::wlv=1000d0,wst=800d0,wrt=600d0
real(8)::nmaxlv=.03d0,nmaxst=.015d0,nmaxrt=.015d0,nmaxso=.0176d0
real(8)::anlv=0d0,anst=0d0,anrt=0d0,anso=0d0,tcnt=10d0,nfixf=.2d0,dvsnlt=1d0
real(8)::ndeml,ndems,ndemr,ndemso,ndemto,nlimit,NdemandSoil,NdemandBioFix
''' + literal + '''
reference=NdemandBioFix
end function
end module
program probe
use literal_nfix
use mod_wofost81_nitrogen
implicit none
type(WOFOST81_n_param)::p
type(WOFOST81_n_state)::s
type(WOFOST81_n_request)::q
real(8)::dvs(6)=[.5d0,1d0,.5d0,.5d0,.5d0,.5d0]
real(8)::reltr(6)=[1d0,1d0,1d0,1d0,.01d0,.0100001d0]
real(8)::storage(6)=[0d0,0d0,200d0,0d0,0d0,0d0]
real(8)::growth(6)=[0d0,0d0,0d0,20d0,0d0,0d0]
real(8)::old,expected_old(6)=[10.2d0,0d0,10.2d0,10.2d0,0d0,10.2d0]
real(8)::expected_new(6)=[10.2d0,10.2d0,10.904d0,10.32d0,0d0,10.2d0]
integer::i
p%nmaxst_fr=.5d0;p%nmaxrt_fr=.5d0;p%nmaxso=.0176d0
p%tcnt=10d0;p%nfix_fr=.2d0;p%rnuptakemax=100d0;p%dvs_n_transl=.8d0
s=WOFOST81_n_state()
do i=1,6
 old=reference(dvs(i),reltr(i),storage(i))
 call prepare_wofost81_n_request(p,s,dvs(i),.03d0,1000d0,800d0,600d0,storage(i), &
      growth(i),0d0,0d0,0d0,reltr(i),q)
 if(q%status/=WOFN81_OK)error stop 'request invalid'
 if(abs(old-expected_old(i))>1d-12)error stop 'literal source expectation'
 if(abs(q%rnfixation-expected_new(i))>1d-12)error stop 'current equation expectation'
 write(*,'(I2,2ES25.16)')i,old,q%rnfixation
end do
print '(A)','NFIX_REPLACEMENT_DISCRIMINATION_PASS'
end program
'''
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-nfix-') as tmp:
        work = Path(tmp)
        (work / 'probe.f90').write_text(program)
        for opt in ['-O0', '-O2']:
            command = ['gfortran', opt, '-ffree-line-length-none', '-fcheck=all',
                       '-ffpe-trap=invalid,zero,overflow', str(ROOT / PROVIDER),
                       'probe.f90', '-o', 'probe']
            subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
            completed = subprocess.run([str(work / 'probe')], cwd=work, check=True, capture_output=True, text=True)
            results.append(dict(optimization=opt, cases=6, stdout=completed.stdout,
                                stderr=completed.stderr, exit_code=completed.returncode))
    assert results[0]['stdout'] == results[1]['stdout']
    record = dict(schema_version='1.0', baseline=subprocess.check_output(
        ['git', 'rev-parse', 'origin/integration/f-ci-canonical'], cwd=ROOT, text=True).strip(),
        source_member='SWAP/wofostnut.f90', source_sha256=hashlib.sha256(raw).hexdigest(),
        literal_lines=[source[:start].count('\n') + 1, source[:end].count('\n')],
        source_files_sha256={PROVIDER: hashlib.sha256((ROOT / PROVIDER).read_bytes()).hexdigest()},
        results=results, runtime_admission_created=False,
        conclusion='Three witnesses distinguish the source DVS cutoff, storage-demand exclusion and absence of new-growth demand. Moisture threshold agrees. WOFOST81 supplies biological fixation algebra but does not literally implement the B1.11 request contract.',
        nonclaims=['No claim that either biological model is physically wrong.',
                   'No full-season, runtime or Soil-N coupling qualification.',
                   'No global REJECTED or SUPERSEDED decision follows from equation differences alone.'])
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps(dict(cases_per_optimization=6, optimization_identity=True,
                         distinct_equation_witnesses=3, output=str(output))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
