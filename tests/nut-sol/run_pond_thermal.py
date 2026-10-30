#!/usr/bin/env python3
"""Actual Reference/restricted-heat/B1.11 composition; measured O0/O2 closure."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import struct
import zlib
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--exponent', type=float, default=1.0)
    parser.add_argument('--black-rutter',action='store_true',help='Select the newly composed existing Black/Rutter/heat owner contract, without historical equivalence claims')
    parser.add_argument('--reuse-build', type=Path)
    parser.add_argument('--resume-compilation',type=Path)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    fc = shlex.split(os.environ.get('FC', 'gfortran'))
    report = {'candidate': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
              'compiler': subprocess.check_output(fc + ['--version'], text=True).splitlines()[0],
              'status': 'RUNNING', 'inputs': {}, 'events': [], 'results': {}, 'exponent': args.exponent}

    def run(command, cwd, category):
        start = time.perf_counter()
        r = subprocess.run(list(map(str, command)), cwd=cwd, capture_output=True)
        i = len(report['events'])
        (out / f'{i:04d}.stdout').write_bytes(r.stdout)
        (out / f'{i:04d}.stderr').write_bytes(r.stderr)
        report['events'].append({'command': list(map(str, command)), 'category': category,
                                 'seconds': time.perf_counter() - start, 'returncode': r.returncode})
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
        if r.returncode:
            print(r.stdout.decode(errors='replace'), r.stderr.decode(errors='replace'), flush=True)
            r.check_returncode()
        return r.stdout.decode()

    # Reuse the incumbent oracle generator up to, but excluding, any execution.
    # Its literal transport/decay lines and immutable archive SHA assertions stay
    # exactly the existing independently accepted reference policy.
    incumbent = ROOT / 'tests/nut-sol/run_nonlinear_pond.py'
    namespace = {'__file__': str(incumbent)}
    os.environ['DYNAMIC_POND_RESULT_DIR'] = str(out / 'oracle-generator')
    exec(compile(incumbent.read_text().split("\nresults = dict")[0], str(incumbent), 'exec'), namespace)
    oracle = out / 'mod_b111_literal_oracle.f90'
    oracle.write_text(namespace['oracle'])
    report['authority_sha256'] = hashlib.sha256(namespace['raw']).hexdigest()
    fixture = ROOT / 'tests/physics/test_ppa_wu05d2_mixed_application.f90'
    text = fixture.read_text()
    start = text.index('  subroutine initialize_application_config')
    end = text.index('  end subroutine initialize_state_and_forcing') + len('  end subroutine initialize_state_and_forcing')
    (out / 'matrix_fixture.inc').write_text(text[start:end] + '\n')
    driver = ROOT / 'tests/nut-sol/test_pond_thermal.f90'
    context = ROOT / 'tests/modularity/low_air_consistent_grid_stubs.f90'
    sources = list((ROOT / 'src').rglob('*.f90')) + [context, oracle, ROOT / 'tests/nut-sol/matrix_nonlinear_oracle.f90']
    providers = {}
    for p in sources:
        for name in re.findall(r'^\s*module\s+(\w+)\s*$', p.read_text(), re.M | re.I):
            if name.lower() in providers:
                raise ValueError('duplicate provider ' + name)
            providers[name.lower()] = p
    ordered, seen, active = [], set(), set()

    def visit(p):
        if p in seen:
            return
        if p in active:
            raise ValueError('cycle ' + str(p))
        active.add(p)
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)', p.read_text(), re.M | re.I):
            if name.lower() in {'iso_fortran_env', 'iso_c_binding', 'ieee_arithmetic', 'ieee_exceptions', 'omp_lib'}:
                continue
            q = providers[name.lower()]
            if q != p:
                visit(q)
        active.remove(p)
        seen.add(p)
        ordered.append(p)

    visit(driver)
    ordered.remove(driver)
    ordered.append(ROOT / 'src/legacy/b1_10_port/headcalc.f90')
    for p in ordered + [driver, incumbent, fixture, Path(__file__).resolve()]:
        if p.is_relative_to(ROOT):
            report['inputs'][str(p.relative_to(ROOT))] = sha(p)
    for opt in ['O0', 'O2']:
        build = out / opt
        build.mkdir()
        flags = ['-' + opt, '-std=f2008', '-ffree-line-length-none', '-fopenmp', '-fcheck=all', '-fbacktrace',
                 '-ffpe-trap=invalid,zero,overflow', '-J' + str(build), '-I' + str(build), '-I' + str(out)]
        objects = []
        prior_build = args.resume_compilation.resolve() if args.resume_compilation else None
        prior_report = json.loads((prior_build/'result.json').read_text()) if prior_build else None
        for i, p in enumerate([] if args.reuse_build else ordered + [driver]):
            obj = build / f'{i:04d}.o'
            reused = False
            if prior_build and p != driver:
                import shutil
                prior_obj=prior_build/opt/obj.name
                previous=[e for e in prior_report['events'] if e['category']=='compile' and e['returncode']==0 and Path(e['command'][-3]).name==p.name and Path(e['command'][-1]).parent==prior_build/opt]
                if previous:
                    prior_obj=Path(previous[0]['command'][-1])
                    previous_source=Path(previous[0]['command'][-3])
                    assert previous_source.read_bytes()==p.read_bytes(),'provider source changed'
                    if p.is_relative_to(ROOT):
                        assert prior_report['inputs'][str(p.relative_to(ROOT))]==sha(p)
                    assert prior_report['compiler']==report['compiler']
                    shutil.copyfile(prior_obj,obj)
                    report.setdefault('reused_provider_artifacts',{})[str(prior_obj)]=sha(prior_obj)
                    reused=True
                    for mod in (prior_build/opt).glob('*.mod'):
                        shutil.copyfile(mod,build/mod.name)
            if not reused:
                run(fc + flags + ['-c', p, '-o', obj], build, 'compile')
            objects.append(obj)
        if args.reuse_build:
            reused = args.reuse_build.resolve()
            prior = json.loads((reused / 'result.json').read_text())
            assert prior['inputs'] == report['inputs'], 'reused build input drift'
            assert prior['status'] == 'FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
            exe = reused / opt / 'thermal'
            assert sha(exe) == prior['executables'][opt], 'reused executable drift'
            report['reused_physical_sha256'] = sha(reused / 'result.json')
        else:
            exe = build / 'thermal'
            run(fc + flags + objects + ['-o', exe], build, 'link')
        report.setdefault('executables', {})[opt] = sha(exe)
        results = {}
        prefix='rutter-'if args.black_rutter else''
        marker='BLACK_RUTTER_HEAT_REACTIVE_MASS_RESTART=PASS'if args.black_rutter else'THERMAL_PHYSICAL_LITERAL_RESTART=PASS'
        for windows in ([2]if args.black_rutter else[2, 4, 8, 16, 32, 64, 128, 256]):
            case = build / str(windows)
            case.mkdir()
            path, full, resumed = case / 'restart.bin', case / 'full.bin', case / 'resumed.bin'
            outputs = []
            for mode, endpoint in [('full', full), ('split', full), ('resume', resumed)]:
                stdout = run([exe, prefix+mode, path, endpoint, windows, args.exponent], case, 'native')
                assert marker in stdout
                outputs.append(stdout)
            assert full.read_bytes() == resumed.read_bytes(), 'fresh-process endpoint differs'
            results[str(windows)] = {'stdout': outputs, 'restart_sha256': sha(path), 'endpoint_sha256': sha(full)}
        controls = build / 'controls'
        controls.mkdir()
        endpoint = controls / 'control'
        if not args.black_rutter:
            stdout = run([exe, 'controls', controls / 'unused', endpoint, 2, args.exponent], controls, 'native')
            assert 'THERMAL_REJECTION_RETRY_HEAT_OFF=PASS' in stdout
            assert (controls / 'control.before').read_bytes() == (controls / 'control.after').read_bytes()
            assert (controls / 'control.initial').read_bytes() == (controls / 'control.hydraulic').read_bytes()
            results['controls'] = stdout
        # CRC corruption and truncation never publish either owner.
        original = (build / '2/restart.bin').read_bytes()
        for label, raw in [('truncated', original[:-12]), ('crc', original[:20] + bytes([original[20] ^ 1]) + original[21:])]:
            path = controls / (label + '.bin')
            path.write_bytes(raw)
            stdout = run([exe, prefix+'reject', path, endpoint, 2, args.exponent], controls, 'native')
            assert 'THERMAL_INVALID_RESTART=PASS' in stdout
        for mode in ['reject-id', 'reject-heat', 'reject-chemical']:
            stdout = run([exe, prefix+mode, build / '2/restart.bin', endpoint, 2, args.exponent], controls, 'native')
            assert 'THERMAL_INVALID_RESTART=PASS' in stdout
        if args.black_rutter:
            # Native S5PT0004 layout: scalar header, immutable heat vector,
            # existing physical arrays, LDWET, micro carry, typed Rutter record.
            assert original[:8]==b'S5PT0004'
            n,history,physical_id,count=struct.unpack_from('=iiqi',original,148)
            assert n==4 and history==0 and count>0
            micro=168+8*count+8*(3*n+2)+8
            canopy=micro+12
            progress=canopy+12
            params=progress+44
            changes={
                'canopy_nan':(canopy+4,struct.pack('=d',float('nan'))),
                'canopy_negative':(canopy+4,struct.pack('=d',-1.0)),
                'rutter_clock':(progress+36,struct.pack('=d',.0005)),
                'rutter_clock_nan':(progress+36,struct.pack('=d',float('nan'))),
                'source_aggregate_nan':(progress+28,struct.pack('=d',float('nan'))),
                'canopy_cover_invalid':(params+4,struct.pack('=d',2.0)),
                'micro_carry_nan':(micro+4,struct.pack('=d',float('nan'))),
                'unexpected_micro_carry':(micro,struct.pack('=i',1)),
            }
            for label,(offset,replacement) in changes.items():
                raw=bytearray(original);raw[offset:offset+len(replacement)]=replacement
                raw[-4:]=struct.pack('=I',zlib.crc32(raw[:-4]));path=controls/(label+'.bin');path.write_bytes(raw)
                stdout=run([exe,'rutter-reject',path,endpoint,2,args.exponent],controls,'native')
                assert 'THERMAL_INVALID_RESTART=PASS'in stdout
            results['new_codec_negative_controls']=list(changes)
        report['results'][opt] = results
        report['provider_count'] = len(ordered)
        print(opt + ' physical/literal/restart/rollback PASS', flush=True)
    assert report['results']['O0'] == report['results']['O2'], 'O0/O2 results differ'
    assert all(sha(ROOT / p) == h for p, h in report['inputs'].items()), 'source changed during execution'
    report['cost_seconds'] = {category: sum(e['seconds'] for e in report['events'] if e['category'] == category)
                              for category in ['compile', 'link', 'native']}
    report['status'] = 'FOCUSED_BLACK_RUTTER_HEAT_REACTIVE_PASS_NOT_ADMITTED'if args.black_rutter else'FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
    (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')
    print(report['status'])


if __name__ == '__main__':
    main()
