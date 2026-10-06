#!/usr/bin/env python3
"""Replay literal rain representation against the real typed forcing adapter.

Only input representation is compared. No parser, snow/interception composition
or new runtime admission is claimed. Full production module closure is compiled.
"""
import argparse
import base64
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]


def run(output):
    bundle = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(bundle.read_bytes())), mode='r:gz') as archive:
        raw = archive.extractfile('SWAP/MOD_meteo.f90').read()
    source = raw.decode('latin1')
    start = source.index('      ! store raintime and rainflux (SWRAIN = 3)')
    end = source.index('      ! deallocate temporary data', start)
    literal = source[start:end]
    driver = '''program rain_mapping
use mod_ppa_wu03_common_forcing_adapter
use mod_b110_dynamic_top_boundary_provider
implicit none
type(ppa_wu03_common_forcing_config_t)::config
type(ppa_wu03_common_forcing_input_t)::input,bad
type(ppa_wu03_common_forcing_result_t)::result
type(ppa_wu03_common_forcing_diagnostics_t)::diagnostics
type(b110_dynamic_top_boundary_request_t)::base
real(8),allocatable::raintim(:),rainflx(:),arai(:)
real(8)::all_raintime(5)=[10.25d0,10.5d0,11d0,11.5d0,12d0]
real(8)::all_rainamount(5)=[1d0,2d0,0d0,4d0,1d0]
real(8)::expected_rates(5)=[.4d0,.8d0,0d0,.8d0,.2d0]
real(8)::tstart=10d0,tend=11d0,tmeteo,rtim,vsmall=1d-12,left,amount
integer::n_rec=5,rain_rec,i,j
''' + literal + '''
if(any(abs(rainflx(1:5)-expected_rates)>1d-14))error stop 'literal rates'
if(any(abs(arai-[.3d0,.5d0])>1d-14))error stop 'literal daily amounts'
config%reference_et_parameters%pond_evaporation_factor=1d0
input%canopy%crop_emerged=.false.
input%canopy%vegetation_cover_fraction=0d0
input%reference_et%reference_et_mm_per_day=0d0
left=tstart;amount=0d0
do i=1,5
 input%forcing_t0=left;input%forcing_t1=raintim(i)
 input%reference_et%t0=left;input%reference_et%t1=raintim(i)
 input%precipitation_rate_cm_per_day=rainflx(i)
 ! Partition each immutable rain interval into two accepted caller windows.
 do j=1,2
  input%interval%t0=left+(j-1)*(raintim(i)-left)/2d0
  input%interval%t1=left+j*(raintim(i)-left)/2d0
  call materialize_ppa_wu03_common_forcing(config,input,base,result,diagnostics)
  if(diagnostics%status/=PPA_WU03_OK.or..not.result%valid)error stop 'typed rain rejected'
  if(result%top_request%precipitation_rate_cm_per_day/=expected_rates(i))error stop 'typed rate'
  amount=amount+result%top_request%precipitation_rate_cm_per_day*result%top_request%step_duration_day
 end do
 bad=input;bad%interval%t1=raintim(i)+.01d0
 call materialize_ppa_wu03_common_forcing(config,bad,base,result,diagnostics)
 if(result%valid)error stop 'cross-span input silently accepted'
 left=raintim(i)
end do
if(abs(amount-.8d0)>1d-14)error stop 'rain amount not conserved'
! SWRAIN2 is supplied daily cm depth and WET duration, encoded as an
! explicit midnight-start pulse followed by a zero-rate interval.
input%forcing_t0=20d0;input%forcing_t1=20.125d0
input%interval%t0=20d0;input%interval%t1=20.125d0
input%reference_et%t0=20d0;input%reference_et%t1=21d0
input%precipitation_rate_cm_per_day=.25d0/.125d0
call materialize_ppa_wu03_common_forcing(config,input,base,result,diagnostics)
if(.not.result%valid)error stop 'WET pulse rejected'
if(abs(result%top_request%precipitation_rate_cm_per_day*result%top_request%step_duration_day-.25d0)>1d-14) &
 error stop 'WET amount'
input%forcing_t0=20.125d0;input%forcing_t1=21d0
input%interval%t0=20.125d0;input%interval%t1=21d0
input%precipitation_rate_cm_per_day=0d0
call materialize_ppa_wu03_common_forcing(config,input,base,result,diagnostics)
if(.not.result%valid.or.result%top_request%precipitation_rate_cm_per_day/=0d0)error stop 'dry remainder'
print '(A)','RAIN_TYPED_MAPPING_PASS: 10 subintervals; 5 span rejections; 2 WET intervals'
print '(A)','LIMIT: representation only; no legacy parser or snow/interception admission'
end program
'''
    modules = {}
    stub = ROOT / 'tests/fsi/fsi04_real_headcalc_stubs.f90'
    for path in [*ROOT.joinpath('src').rglob('*.f90'), stub]:
        match = re.search(r'^\s*module\s+(?!procedure\b)(\w+)', path.read_text(), re.I | re.M)
        if match:
            modules[match[1].lower()] = path
    ordered, seen, visiting = [], set(), set()
    def visit(name):
        if name in seen or name not in modules:
            return
        assert name not in visiting, name
        visiting.add(name)
        path = modules[name]
        for dependency in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)', path.read_text(), re.I | re.M):
            visit(dependency.lower())
        visiting.remove(name)
        seen.add(name)
        ordered.append(path)
    visit('mod_ppa_wu03_common_forcing_adapter')
    ordered.append(ROOT / 'src/legacy/b1_10_port/headcalc.f90')
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-rain-map-') as tmp:
        work = Path(tmp)
        test = work / 'probe.f90'
        test.write_text(driver)
        for opt in ['-O0', '-O2']:
            build = work / opt[1:]
            build.mkdir()
            flags = [opt, '-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp',
                     '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', '-J', str(build), '-I', str(build)]
            objects = []
            for path in [*ordered, test]:
                obj = build / (path.stem + '.o')
                subprocess.run(['gfortran', *flags, '-c', str(path), '-o', str(obj)], cwd=build, check=True)
                objects.append(str(obj))
            subprocess.run(['gfortran', opt, '-fopenmp', *objects, '-o', str(build / 'probe')], check=True)
            completed = subprocess.run([str(build / 'probe')], check=True, capture_output=True, text=True)
            results.append(dict(optimization=opt, stdout=completed.stdout, stderr=completed.stderr, exit_code=0))
            print(opt + ' RAIN_MAPPING_PASS', flush=True)
    assert results[0]['stdout'] == results[1]['stdout']
    record = dict(schema_version='1.0', baseline='78acf56f931763d2e1d4924b3dea0742f231d2e8',
        source_member='SWAP/MOD_meteo.f90', source_sha256=hashlib.sha256(raw).hexdigest(),
        literal_lines=[source[:start].count('\n')+1, source[:end].count('\n')],
        source_files_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},
        results=results, runtime_admission_created=False,
        claim='Resolved precipitation representation and span/amount identity in the admitted PPA-WU03 adapter. No automated .rain/WET ingestion, all-date source equivalence or snow/interception composition claim.')
    output.write_text(json.dumps(record, indent=2) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
