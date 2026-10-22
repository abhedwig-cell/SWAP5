"""Native fallow ETref, original demand, accepted mass and fresh restart."""
import argparse
import base64
import csv
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def rows(p):
    return [{k: float(v) for k, v in r.items()} for r in csv.DictReader(p.open())]


def oracle():
    archive = ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())), mode='r:gz') as t:
        raw = t.extractfile('SWAP/MOD_meteo.f90').read()
    assert hashlib.sha256(raw).hexdigest() == '99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'
    text = raw.decode('latin1')
    a = text.index('   subroutine ETpot')
    b = text.index('   end subroutine ETpot', a) + len('   end subroutine ETpot')
    procedure = text[a:b].replace('use plant_interface, only:', 'use oracle_plant, only:').replace(
        'use variables,       only:', 'use oracle_variables,only:')
    # Compile-time selection of original SWETR=1 excludes the unreachable PM
    # branch. No mock Penman procedure or rewritten ET equation is supplied.
    return '''module oracle_plant
 implicit none
 logical::fl_cropemergence=.false.
 integer::swcf=0
 real(8)::fco2tra=1d0,cf=1d0,vcover=0d0,dt_interc_event,crsflx_in,crsflx_out
end module
module oracle_variables
 implicit none
 integer::swcfbs=0,daynr=1
 real(8)::cfbs=1d0,rsoil=0d0
end module
module original
 implicit none
 integer,parameter::swmetdetail=0,swetr=1,swdivide=0
 real(8)::etr,cfevappond,es0,ep0,et0,ew0,epond,peva,ptra_dry,ptra_wet,eintc,wfrac
contains
''' + procedure + '''
end module
program test
 use original
 use mod_reference_et_demand_process
 implicit none
 type(reference_et_demand_parameters_t)::p
 type(reference_et_demand_forcing_t)::f
 type(reference_et_demand_canopy_view_t)::c
 type(reference_et_demand_result_t)::r
 type(reference_et_demand_diagnostics_t)::d
 real(8)::references(5)=[0d0,.2d0,2d0,10d0,100d0],factors(4)=[0d0,.5d0,1d0,2d0]
 integer::i,j
 do i=1,5
 do j=1,4
 etr=references(i);cfevappond=factors(j)
 call ETpot()
 f%reference_et_mm_per_day=etr;p%pond_evaporation_factor=cfevappond
 call evaluate_restricted_reference_et_demand(p,f,c,r,d)
 if(d%status/=REF_ET_DEMAND_OK.or..not.d%result_produced)error stop 1
 if(r%potential_soil_evaporation_cm_per_day/=peva.or. &
    r%potential_pond_evaporation_cm_per_day/=epond.or. &
    r%potential_transpiration_cm_per_day/=ptra_dry)error stop 2
 end do
 end do
 print '(A)','ORIGINAL_ETPOT_20_EXACT_PASS'
end program
'''


def main():
    ap = argparse.ArgumentParser()
    for opt in ['O0', 'O2']:
        ap.add_argument('--column-' + opt, type=Path, required=True)
        ap.add_argument('--reader-' + opt, type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    inputs = ['tests/nut-sol/qualify_swp_etref.py', 'tests/nut-sol/test_soil_evaporation_pond.f90',
              'tools/solute/run_daily.py', 'app/solute_column/read_swp_daily.f90']
    report = {'status': 'RUNNING', 'inputs': {p: sha(ROOT / p) for p in inputs},
              'builds': {}, 'events': [], 'cases': {}}

    def save():
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(cmd, cwd, valid=True):
        start = time.perf_counter()
        result = subprocess.run(list(map(str, cmd)), cwd=cwd, capture_output=True, input=b'', timeout=120)
        index = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out / f'{index:04d}.{stream}').write_bytes(getattr(result, stream))
        report['events'].append({'command': list(map(str, cmd)), 'cwd': str(cwd),
                                 'returncode': result.returncode, 'expected_success': valid,
                                 'seconds': time.perf_counter() - start})
        save()
        assert (result.returncode == 0) == valid, (cmd, result.stdout, result.stderr)
        return result

    original_swp = (ROOT / 'examples/solute_column/daily_fallow.swp').read_text()
    for opt in ['O0', 'O2']:
        directory = out / opt
        directory.mkdir()
        column, reader = (getattr(args, kind + '_' + opt).resolve() for kind in ['column', 'reader'])
        meta = json.loads((column.parent / 'build-complete.json').read_text())
        rm = json.loads((reader.parent / 'build-complete.json').read_text())
        for exe, build in [(column, meta), (reader, rm)]:
            assert build['status'] == 'BUILT' and build['executable_sha256'] == sha(exe)
            assert all(sha(ROOT / p) == h for p, h in build['input_sha256'].items())
            assert all(sha(exe.parent / p) == h for p, h in build['generated_input_sha256'].items())
        report['builds'][opt] = {'column': meta, 'reader': rm}
        flags = ['-' + opt, '-std=f2008', '-fcheck=all', '-ffpe-trap=invalid,zero,overflow',
                 '-ffree-line-length-none', '-J' + str(directory), '-I' + str(directory)]
        source = directory / 'original.f90'
        source.write_text(oracle())
        direct = directory / 'original'
        run(meta['compiler_command'] + flags + [ROOT / 'src/process/mod_reference_et_demand_process.f90',
                                               source, '-o', direct], directory)
        assert b'ORIGINAL_ETPOT_20_EXACT_PASS' in run([direct], directory).stdout
        pond = directory / 'pond'
        run(meta['compiler_command'] + flags + [ROOT / p for p in [
            'src/process/mod_b111_pond_solute_exchange.f90', 'src/process/mod_b111_persistent_pond.f90',
            'tests/nut-sol/test_soil_evaporation_pond.f90']] + ['-o', pond], directory)
        assert b'SOIL_EVAPORATION_POND_CONTRACT_PASS' in run([pond], directory).stdout
        variants = {'dry': ([0., 0., 0.], [.2, .2, .2], 0., .5),
                    'ponded': ([0., 0., 0.], [.2, .2, .2], .5, .5),
                    'transition': ([1., 0., .5], [.2, 1., .1], 0., .5),
                    'linear': ([0., 0., 0.], [.2, .2, .2], 0., 1.)}
        for name, (rain, et, initial, exponent) in variants.items():
            case = directory / name
            case.mkdir()
            swp = case / 'input.swp'
            swp.write_text(original_swp.replace('daily_fallow.met', 'weather.met').replace(
                'FREXP=.5', f'FREXP={exponent}') + '\nSWREDU=0\nSWCFBS=0\nCFEVAPPOND=1.\n')
            met = case / 'weather.met'
            text = 'DD MM YYYY TMIN TMAX RAIN ETREF\n'
            text += '\n'.join(f'{dd} {mm} 2024 5. 15. {r:.8f} {e:.8f}' for dd, mm, r, e in
                              zip([28, 29, 1], [2, 2, 3], rain, et)) + '\n'
            met.write_text(text)
            common = [sys.executable, ROOT / 'tools/solute/run_daily.py', '--etref',
                      '--reader', reader, '--exe', column, '--swp', swp, '--met', met,
                      '--initial-pond-cm', str(initial), '--temporal-tolerance', '.0001']
            for target, extra in [('full', []), ('split', ['--stop-after', '1']),
                                  ('resumed', ['--restart', case / 'split'])]:
                run(common + ['--output', case / target] + extra, case)
            for p in ['restart.bin', 'state.csv', 'endpoint.csv']:
                assert (case / 'full' / p).read_bytes() == (case / 'resumed' / p).read_bytes()
            budget = rows(case / 'full/budget.csv')
            assert rows(case / 'resumed/budget.csv') == budget[1:]
            for i, b in enumerate(budget):
                gross_residual = b['water_end_cm'] - b['water_start_cm'] - rain[i] * .1 + b['soil_evaporation_cm'] + b['pond_evaporation_cm'] + b['runoff_cm']
                assert abs(gross_residual) < 1e-10
                for substance, unit in [('water', 'cm'), ('solute', 'mg_cm2')]:
                    residual = b[f'{substance}_end_{unit}'] - b[f'{substance}_start_{unit}'] - b[f'{substance}_in_{unit}'] + b[f'{substance}_out_{unit}']
                    assert abs(residual) < 1e-10 and abs(b[f'{substance}_residual_{unit}']) < 1e-10
            if name in ['dry', 'linear']:
                assert abs(sum(b['soil_evaporation_cm'] for b in budget) - .06) < 1e-10
                assert sum(b['pond_evaporation_cm'] for b in budget) == 0.
                assert abs(budget[-1]['solute_end_mg_cm2'] - budget[0]['solute_start_mg_cm2']) < 1e-10
            if name == 'ponded':
                assert abs(sum(b['pond_evaporation_cm'] for b in budget) - .06) < 1e-10
                assert sum(b['soil_evaporation_cm'] for b in budget) == 0.
            if name == 'transition':
                assert sum(b['soil_evaporation_cm'] for b in budget) > 0.
                assert sum(b['pond_evaporation_cm'] for b in budget) > 0.
            report['cases'][opt + '-' + name] = {'budget': budget, 'restart_sha256': sha(case / 'full/restart.bin')}
            save()
        case = directory / 'dry'
        common = [sys.executable, ROOT / 'tools/solute/run_daily.py', '--reader', reader, '--exe', column,
                  '--swp', case / 'input.swp', '--met', case / 'weather.met',
                  '--initial-pond-cm', '0.', '--temporal-tolerance', '.0001']
        run(common + ['--output', directory / 'forbidden-no-opt-in'], directory, False)
        assert not (directory / 'forbidden-no-opt-in').exists()
        for name, old, new in [('black', 'SWREDU=0', 'SWREDU=1'), ('boesten', 'SWREDU=0', 'SWREDU=2'),
                              ('soil_factor', 'SWCFBS=0', 'SWCFBS=1'), ('crop', 'SWCROP=0', 'SWCROP=1')]:
            swp = directory / (name + '.swp')
            swp.write_text((case / 'input.swp').read_text().replace(old, new))
            command = common.copy()
            command[command.index('--swp') + 1] = swp
            run(command + ['--etref', '--output', directory / ('forbidden-' + name)], directory, False)
            assert not (directory / ('forbidden-' + name)).exists()
        changed = directory / 'weather.met'
        changed.write_text((case / 'weather.met').read_text().replace('.20000000', '.30000000'))
        command = common.copy()
        command[command.index('--met') + 1] = changed
        run(command + ['--etref', '--restart', case / 'split', '--output', directory / 'forbidden-restart'], directory, False)
        assert not (directory / 'forbidden-restart').exists()
    report.update(status='PASS', original_etpot_checks=40, native_column_runs=24, fresh_restarts=8,
                  invalid_generations=12, full_historical_migration=False)
    save()
    print(json.dumps({k: v for k, v in report.items() if k not in ['inputs', 'builds', 'events', 'cases']}))


if __name__ == '__main__':
    main()
