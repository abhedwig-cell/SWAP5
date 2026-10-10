#!/usr/bin/env python3
"""Bounded active SWSEP runtime smoke; no admission or full restart qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
FIXTURE = 'tests/fpm/test_ppa_wu05a8_fmr_macropore_trial.f90'


def run(output):
    original = (ROOT / FIXTURE).read_text()
    replacements = {
        '  integer :: commit_status': '  integer :: commit_status, selected_seep\n  real(real64) :: selected_k\n  character(30) :: argument',
        '  call initialize_parameters(parameters)': '''  call get_command_argument(1,argument)
  read(argument,*)selected_seep
  call get_command_argument(2,argument)
  read(argument,*)selected_k
  call initialize_parameters(parameters)''',
        '  heads=-100.0_real64': '  heads=-1.25_real64-z',
        '  physical%groundwater_level=-1000.0_real64': '  physical%groundwater_level=-1.25_real64',
        '  physical%macropore%water_domain_cp(1,numnod)=0.20_real64':
            '  physical%macropore%water_domain_cp(1,numnod)=0.02_real64',
        '    sorp_max=0.001_real64': '    sorp_max=0.0_real64',
        '    ksat_horizontal=0.0_real64': '    ksat_horizontal=selected_k',
        'sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.0_real64,0,initialized)':
            'sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.0_real64,selected_seep,initialized)',
        '    f%bottom_head=-100.0_real64': '    f%bottom_head=1.75_real64',
        '    p%bottom_mode=7': '    p%bottom_mode=2',
        '    macro_after=sum(s%macropore%water_domain_cp)': '''    macro_after=sum(s%macropore%water_domain_cp)
    write(*,'(*(g0))') 'SEEPAGE_POST|GWL=',s%groundwater_level,'|MACRO=',macro_after, &
         '|HEADS=',s%pressure_head''',
        "    call require(macro_after<macro_before,'postcommit macro storage responds to matrix exchange')":
            '''    if(selected_k>0.0_real64)then
      call require(macro_after>macro_before,'positive seepage alone increases macro storage')
    else
      call require(abs(macro_after-macro_before)<1.0e-14_real64,'zero-K no-exchange control')
    end if''',
    }
    driver = original
    for old, new in replacements.items():
        assert driver.count(old) == 1, old
        driver = driver.replace(old, new)
    modules = {}
    stub = ROOT / 'tests/fsi/fsi04_real_headcalc_stubs.f90'
    for path in [*ROOT.joinpath('src').rglob('*.f90'), stub]:
        for name in re.findall(r'^\s*module\s+(?!procedure\b)(\w+)', path.read_text(), re.I | re.M):
            modules[name.lower()] = path
    ordered, seen, visiting = [stub], {stub}, set()

    def visit(name):
        path = modules.get(name.lower())
        if path is None or path in seen:
            return
        assert path not in visiting, path
        visiting.add(path)
        for dependency in re.findall(r'^\s*use\s*(?:,\s*non_intrinsic\s*)?(?:::)?\s*(\w+)', path.read_text(), re.I | re.M):
            visit(dependency)
        visiting.remove(path)
        seen.add(path)
        ordered.append(path)

    for name in re.findall(r'^\s*use\s+(\w+)', driver, re.I | re.M):
        visit(name)
    ordered.append(ROOT / 'src/legacy/b1_10_port/headcalc.f90')
    results = []
    with tempfile.TemporaryDirectory(prefix='swap431-seep-runtime-') as tmp:
        work = Path(tmp)
        (work / 'probe.f90').write_text(driver)
        for opt in ['-O0', '-O2']:
            build = work / opt[1:]
            build.mkdir()
            flags = [opt, '-std=f2008', '-ffree-line-length-none', '-w', '-fopenmp',
                     '-fcheck=all', '-ffpe-trap=invalid,zero,overflow', '-J', str(build), '-I', str(build)]
            objects = []
            for index, path in enumerate(ordered):
                obj = build / f'{index}.o'
                subprocess.run(['gfortran', *flags, '-c', str(path), '-o', str(obj)], check=True,
                               capture_output=True, text=True)
                objects.append(str(obj))
            exe = build / 'probe'
            subprocess.run(['gfortran', *flags, *objects, str(work / 'probe.f90'), '-o', str(exe)],
                           check=True, capture_output=True, text=True)
            for selector, conductivity in [(2, '0'), (1, '0.1'), (2, '0.1')]:
                result = subprocess.run([str(exe), str(selector), conductivity], capture_output=True,
                                        text=True, timeout=60)
                results.append(dict(optimization=opt, selector=selector, horizontal_k=conductivity,
                                    exit_code=result.returncode, stdout=result.stdout, stderr=result.stderr))
                print(f'{opt} SWSEP={selector} K={conductivity} exit={result.returncode}', flush=True)
    record = dict(schema_version='1.0',
                  baseline=subprocess.check_output(['git', 'rev-parse', 'origin/integration/f-ci-canonical'],
                                                   cwd=ROOT, text=True).strip(),
                  fixture=FIXTURE, fixture_sha256=hashlib.sha256(original.encode()).hexdigest(),
                  fixture_replacements=replacements, generated_fixture_sha256=hashlib.sha256(driver.encode()).hexdigest(),
                  source_files_sha256={str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in ordered},
                  results=results, runtime_admission_created=False,
                  scope='A8-derived four-node physical Richards trial and commit; closed ordinary bottom mode2; saturated matrix with partial top cell; empty-upper macro seepage face; no sorption/Darcy/top/rapid sources.',
                  nonclaims=['No source-equivalence trajectory oracle.', 'No full-top cell case or donor-cap exhaustion.',
                             'No changed-forcing retry or fresh-process restart qualification.',
                             'No new canonical runtime admission.'])
    output.write_text(json.dumps(record, indent=2) + '\n')
    print(json.dumps({'runs': len(results), 'passed': sum(r['exit_code'] == 0 for r in results), 'output': str(output)}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    run(parser.parse_args().output)
