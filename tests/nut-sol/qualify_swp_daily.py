"""Original daily loader differential, real column balances and restart."""
import argparse
import base64
import csv
from datetime import date, timedelta
import hashlib
import io
import json
import re
from pathlib import Path
import subprocess
import sys
import tarfile
import time

ROOT = Path(__file__).resolve().parents[2]
ORIGINAL = '99fbf7ad4d90f71cc86012e8e1c9970ef4ca40ea879f0f0622a02a0c33be4c9f'


def sha(data):
    return hashlib.sha256(data).hexdigest()


def table(path):
    return [{k: float(v) for k, v in r.items()} for r in csv.DictReader(path.open())]


def oracle_source():
    raw = base64.b64decode((ROOT / 'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:gz') as archive:
        original = archive.extractfile('SWAP/MOD_meteo.f90').read()
        functions = archive.extractfile('SWAP/functions.f90').read().decode('latin1')
    assert sha(original) == ORIGINAL
    text = original.decode('latin1')
    start = text.index('   subroutine LoadMeteoData ()')
    end = text.index('   end subroutine LoadMeteoData', start) + len('   end subroutine LoadMeteoData')
    afgen = re.search(r'^\s*real\(8\) function afgen\b.*?^\s*end function afgen\b', functions, re.M | re.I | re.S).group()
    procedure = text[start:end].replace('use MOD_swap_base, only:', 'use oracle_context, only:').replace(
        'use variables,     only:', 'use oracle_context, only:')
    # Complete original procedure; only its two module import names are adapted.
    return '''module oracle_context
 implicit none
 integer::iun_min2=80,iun_max2=99,unit_err=0
 character(200)::pathatm=''
 real(8)::tstart,tend
end module
module original_meteo
 use oracle_context
 implicit none
 integer::swmetfilall=1,swetr=1,swrain=0,meteo_rec,rain_rec
 logical::fl_loadmeteodata=.false.
 character(200)::metfil
 real(8)::tmnmin=-1d5,tmnmax=1d5,tmxmin=-1d5,tmxmax=1d5
 real(8)::radmin=-1d5,radmax=5d6,hummin=-1d5,hummax=1d5,winmin=-1d5,winmax=1d5
 real(8)::raimin=0d0,raimax=1d3,etrmin=-.00001d0,etrmax=100d0
 real(8),allocatable::atmn(:),atmx(:),arad(:),ahum(:),awin(:),aetr(:),arai(:),wet(:)
 real(8),allocatable::raintim(:),rainflx(:),raintb(:)
contains
''' + procedure + '''
end module
subroutine swap_error(where,message)
 character(*)::where,message
 print *,where,message
 error stop 1
end subroutine
program oracle
 use original_meteo
 implicit none
 integer::i,u
 character(200)::swp
 call get_command_argument(1,swp)
 call get_command_argument(2,metfil)
 call rdinit(74,0,trim(swp))
 call rdstim('tstart',tstart)
 call rdstim('tend',tend)
 close(74)
 call LoadMeteoData()
 open(newunit=u,file='oracle.csv',status='new')
 write(u,'(A)')'end_day,t1900,rain_cm_day,tmin_c,tmax_c,tav_c,etref_cm_day'
 do i=1,size(arai)
 write(u,'(I0,6(A,ES25.16E3))')i,',',tstart+i-1,',',arai(i),',',atmn(i),',',atmx(i), &
   ',',(atmx(i)+atmn(i))*.5d0,',',aetr(i)
 end do
 close(u)
 print '(A)','ORIGINAL_DAILY_MET_COMPLETED'
end program
''' + afgen + '\n'


def main():
    parser = argparse.ArgumentParser()
    for opt in ['O0', 'O2']:
        parser.add_argument('--reader-' + opt, type=Path, required=True)
        parser.add_argument('--column-' + opt, type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    paths = ['app/solute_column/read_swp_daily.f90', 'tools/solute/build_daily.py',
             'tools/solute/run_daily.py', 'tests/nut-sol/qualify_swp_daily.py',
             'examples/solute_column/daily_fallow.swp', 'examples/solute_column/daily_fallow.met']
    report = {'status': 'RUNNING', 'inputs': {p: sha((ROOT / p).read_bytes()) for p in paths},
              'events': [], 'builds': {}, 'cases': {}, 'original_sha256': ORIGINAL}

    def save():
        (out / 'result.json').write_text(json.dumps(report, indent=2) + '\n')

    def run(cmd, cwd, valid=True):
        start = time.perf_counter()
        r = subprocess.run(list(map(str, cmd)), cwd=cwd, capture_output=True, input=b'', timeout=120)
        index = len(report['events'])
        for stream in ['stdout', 'stderr']:
            (out / f'{index:04d}.{stream}').write_bytes(getattr(r, stream))
        report['events'].append({'command': list(map(str, cmd)), 'cwd': str(cwd),
                                 'returncode': r.returncode, 'expected_success': valid,
                                 'seconds': time.perf_counter() - start})
        save()
        assert (r.returncode == 0) == valid, (cmd, r.stdout, r.stderr)
        return r

    swp_text = (ROOT / 'examples/solute_column/daily_fallow.swp').read_text()
    met_text = (ROOT / 'examples/solute_column/daily_fallow.met').read_text()
    for opt in ['O0', 'O2']:
        folder = out / opt
        folder.mkdir()
        reader = getattr(args, 'reader_' + opt).resolve()
        column = getattr(args, 'column_' + opt).resolve()
        rb = json.loads((reader.parent / 'build-complete.json').read_text())
        cb = json.loads((column.parent / 'build-complete.json').read_text())
        for exe, meta in [(reader, rb), (column, cb)]:
            assert meta['status'] == 'BUILT' and meta['executable_sha256'] == sha(exe.read_bytes())
            assert all(sha((ROOT / p).read_bytes()) == h for p, h in meta['input_sha256'].items())
            assert all(sha((exe.parent / p).read_bytes()) == h for p, h in meta['generated_input_sha256'].items())
        report['builds'][opt] = {'reader': rb, 'column': cb}
        source = folder / 'original.f90'
        source.write_text(oracle_source())
        oracle = folder / 'original'
        run(rb['compiler_command'] + rb['flags'] + ['-std=legacy', source,
            reader.parent / 'libttutil.a', '-o', oracle], folder)
        # Complete original loader, native table grammar, date slicing and both
        # century leap rules. Every valid case must match the original exactly.
        calendars = [('leap', date(2024, 2, 27)), ('year', date(2023, 12, 30)),
                     ('century_leap', date(2000, 2, 27)), ('century_common', date(2100, 2, 27))]
        for name, begin in calendars:
            case = folder / name
            case.mkdir()
            days = [begin + timedelta(days=i) for i in range(5)]
            start, end = days[1:4:2]
            text = swp_text.replace('28-feb-2024', start.strftime('%d-%b-%Y')).replace(
                '01-mar-2024', end.strftime('%d-%b-%Y'))
            met = '* original native weather table\nDD MM YYYY TMIN TMAX RAIN ETREF\n'
            met += '\n'.join(f'{d.day} {d.month} {d.year} {i}. {i+8}. {i}. 0.'
                             for i, d in enumerate(days)) + '\n'
            (case / 'input.swp').write_text(text)
            (case / 'daily_fallow.met').write_text(met)
            run([reader, 'input.swp', 'daily_fallow.met'], case)
            run([oracle, 'input.swp', 'daily_fallow.met'], case)
            native, original = table(case / 'daily.csv'), table(case / 'oracle.csv')
            assert native == original and len(native) == 3
            assert [r['rain_cm_day'] for r in native] == [.1, .2, .30000000000000004]
            assert [r['t1900'] for r in native] == [native[0]['t1900'] + i for i in range(3)]
            report['cases'][opt + '-' + name] = native
        invalid = {
            'duplicate': (swp_text, met_text.replace('29 2 2024', '28 2 2024')),
            'reverse': (swp_text, met_text.replace('29 2 2024', '26 2 2024')),
            'gap': (swp_text, met_text.replace('29 2 2024 3. 11. 0. 0.\n', '')),
            'missing_first': (swp_text.replace('28-feb-2024', '26-feb-2024'), met_text),
            'missing_last': (swp_text.replace('01-mar-2024', '03-mar-2024'), met_text),
            'nonzero_et': (swp_text, met_text.replace('2. 10. 2. 0.', '2. 10. 2. .1')),
            'negative_et': (swp_text, met_text.replace('2. 10. 2. 0.', '2. 10. 2. -.000001')),
            'nan_rain': (swp_text, met_text.replace('2. 10. 2. 0.', '2. 10. NaN 0.')),
            'negative_rain': (swp_text, met_text.replace('2. 10. 2. 0.', '2. 10. -1. 0.')),
            'invalid_date': (swp_text, met_text.replace('29 2 2024', '30 2 2024')),
            'fractional_start': (swp_text.replace('28-feb-2024', '28-feb-2024_12:00:00'), met_text),
            'reversed_period': (swp_text.replace('28-feb-2024', '02-mar-2024'), met_text),
            'wrong_name': (swp_text.replace('daily_fallow.met', 'other.met'), met_text),
            'missing_field': (swp_text, met_text.replace('ETREF', 'OTHER')),
        }
        for key, old, new in [('crop', 'SWCROP=0', 'SWCROP=1'), ('PM', 'SWETR=1', 'SWETR=0'),
                              ('rain', 'SWRAIN=0', 'SWRAIN=2'), ('snow', 'SWSNOW=0', 'SWSNOW=1'),
                              ('heat', 'SWHEA=0', 'SWHEA=1'), ('frost', 'SWFROST=0', 'SWFROST=1'),
                              ('detail', 'SWMETDETAIL=0', 'SWMETDETAIL=1')]:
            invalid[key] = (swp_text.replace(old, new), met_text)
        for name, (swp, met) in invalid.items():
            case = folder / ('invalid-' + name)
            case.mkdir()
            (case / 'input.swp').write_text(swp)
            (case / 'daily_fallow.met').write_text(met)
            run([reader, 'input.swp', 'daily_fallow.met'], case, False)
            assert not (case / 'daily.csv').exists()
        common = [sys.executable, ROOT / 'tools/solute/run_daily.py', '--reader', reader,
                  '--exe', column, '--swp', ROOT / 'examples/solute_column/daily_fallow.swp',
                  '--met', ROOT / 'examples/solute_column/daily_fallow.met']
        for name, extra in [('full', []), ('split', ['--stop-after', '1']),
                            ('resumed', ['--restart', folder / 'split'])]:
            run(common + ['--output', folder / name] + extra, folder)
        for name in ['state.csv', 'endpoint.csv', 'restart.bin']:
            assert (folder / 'full' / name).read_bytes() == (folder / 'resumed' / name).read_bytes()
        budget = table(folder / 'full/budget.csv')
        assert table(folder / 'resumed/budget.csv') == budget[1:]
        for i, b in enumerate(budget):
            assert abs(b['water_in_cm'] - [.2, 0., .1][i]) < 1e-10
            for substance, unit in [('water', 'cm'), ('solute', 'mg_cm2')]:
                residual = b[f'{substance}_end_{unit}'] - b[f'{substance}_start_{unit}'] - b[f'{substance}_in_{unit}'] + b[f'{substance}_out_{unit}']
                assert abs(residual) < 1e-10 and abs(b[f'{substance}_residual_{unit}']) < 1e-10
        # Same actual native calculation via the incumbent explicit launcher.
        # Remove provenance comments, preserving all numerical/physical values.
        explicit = folder / 'explicit.nml'
        explicit.write_text('\n'.join(line for line in (folder / 'full/input.nml').read_text().splitlines()
                                       if not line.startswith('!')) + '\n')
        run([sys.executable, ROOT / 'tools/solute/run_column.py', '--exe', column,
             '--input', explicit, '--swp', ROOT / 'examples/solute_column/daily_fallow.swp',
             '--output', folder / 'explicit'], folder)
        for name in ['budget.csv', 'state.csv', 'endpoint.csv', 'restart.bin']:
            assert (folder / 'full' / name).read_bytes() == (folder / 'explicit' / name).read_bytes()
        # Change valid bytes outside the selected days: restart must still reject.
        changed = folder / 'daily_fallow.met'
        changed.write_text(met_text.replace('27 2 2024 1. 9.', '27 2 2024 1. 8.'))
        altered = common.copy()
        altered[altered.index('--met') + 1] = changed
        run(altered + ['--restart', folder / 'split', '--output', folder / 'forbidden'], folder, False)
        assert not (folder / 'forbidden').exists()
        # Negative native route must not publish a generation.
        changed.write_text(met_text.replace('2. 10. 2. 0.', '2. 10. 2. .1'))
        run(altered + ['--output', folder / 'forbidden-et'], folder, False)
        assert not (folder / 'forbidden-et').exists()
    report.update(status='PASS', original_comparisons=8, invalid_reader_cases=42,
                  native_column_runs=8, fresh_restarts=2, rejected_generations=4,
                  full_historical_migration=False)
    save()
    print(json.dumps({k: v for k, v in report.items() if k not in ['inputs', 'events', 'builds', 'cases']}))


if __name__ == '__main__':
    main()
