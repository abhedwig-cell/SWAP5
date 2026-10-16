#!/usr/bin/env python3
"""Reproduce the B1.11 SWBR array-index defect; not an aquifer-model oracle."""
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


def run(output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode='r:gz') as archive:
        raw = archive.extractfile('SWAP/solute.f90').read()
    source = raw.decode('latin1')
    start = source.index('            if (swbr == 1) then', source.index('! ---       solute balance in aquifer'))
    end = source.index('! ---       flux to surface water from aquifer', start)
    literal = source[start:end]
    assert 'allocate(bdenskfsatporos(numnod))' in source
    program = '''program probe
implicit none
integer::i,numnod,swbr=1
real(8),allocatable::bdenskfsatporos(:)
real(8)::cdrain=1d0,dtsolu=.1d0,qdrtot,isqdra=.02d0,daquif=100d0,decsat=.01d0,cseep
character(30)::argument
call get_command_argument(1,argument)
read(argument,*)numnod
call get_command_argument(2,argument)
read(argument,*)qdrtot
allocate(bdenskfsatporos(numnod))
! Reproduce the source allocation and completed compartment-loop index.
! Compartment arithmetic is irrelevant to this bounds witness and is not copied.
do i=1,numnod
 bdenskfsatporos(i)=.4d0
end do
write(*,'(A,2I5)')'SOURCE_LOOP_EXIT ',i,numnod
''' + literal + '''
print *,cdrain,cseep
end program
'''
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-aquifer-') as tmp:
        work = Path(tmp)
        (work / 'probe.f90').write_text(program)
        for opt in ['-O0', '-O2']:
            command = ['gfortran', opt, '-ffree-line-length-none', '-fcheck=all',
                       '-ffpe-trap=invalid,zero,overflow', 'probe.f90', '-o', 'probe']
            subprocess.run(command, cwd=work, check=True, capture_output=True, text=True)
            for nodes in [1, 3]:
                for flow in ['0.1', '-0.1']:
                    completed = subprocess.run([str(work / 'probe'), str(nodes), flow],
                                               cwd=work, capture_output=True, text=True)
                    assert completed.returncode != 0, 'source defect unexpectedly absent'
                    expected = f"Index '{nodes + 1}' of dimension 1 of array 'bdenskfsatporos' above upper bound of {nodes}"
                    assert expected in completed.stderr, completed.stderr
                    results.append(dict(optimization=opt, nodes=nodes, qdrtot=flow,
                                        exit_code=completed.returncode,
                                        expected_bounds_failure=True,
                                        stdout=completed.stdout, stderr=completed.stderr))
    record = dict(schema_version='1.0',
                  baseline=subprocess.check_output(['git', 'rev-parse', 'origin/integration/f-ci-canonical'],
                                                   cwd=ROOT, text=True).strip(),
                  source_member='SWAP/solute.f90', source_sha256=hashlib.sha256(raw).hexdigest(),
                  literal_lines=[source[:start].count('\n') + 1, source[:end].count('\n')],
                  literal_sha256=hashlib.sha256(literal.encode()).hexdigest(),
                  allocation_source_line=source[:source.index('allocate(bdenskfsatporos(numnod))')].count('\n') + 1,
                  results=results, runtime_admission_created=False,
                  conclusion='Both signed SWBR branches index a numnod-sized array at the completed loop index numnod+1. Eight O0/O2 bounds witnesses fail as expected.',
                  nonclaims=['Not a full source executable or trajectory replay.',
                             'No proposed replacement index or aquifer mixing law is qualified.',
                             'The intended aquifer capability remains an active migration, not a blanket rejection.'])
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'expected_bounds_failures': len(results), 'probe': 'PASS', 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
