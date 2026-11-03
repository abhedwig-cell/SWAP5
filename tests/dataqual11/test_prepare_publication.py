"""Exercise real original-input adapter publication with the archived TTUTIL library."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--ttutil', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
case = ROOT / 'reference/swap-4.3.1/projects/2.grassgrowth'
weather = (case / '260.met').read_text().splitlines()
records = [i for i, line in enumerate(weather) if line.startswith("'260'")]
results = []
baseline = out / 'baseline_prepare.f90'
baseline.write_bytes(subprocess.check_output([
    'git', 'show', '4d37b256dc60969dc58c9cc2ac26652082bdf001:app/solute_project/prepare_rain_duration.f90'
], cwd=ROOT))
for opt in ('O0', 'O2'):
    build = out / opt
    build.mkdir()
    exe = build / 'prepare.exe'
    subprocess.run(['gfortran', '-' + opt, '-fcheck=all', '-J' + str(build),
                    str(ROOT / 'src/process/mod_daily_rain_duration.f90'),
                    str(ROOT / 'app/solute_project/prepare_rain_duration.f90'),
                    str(a.ttutil.resolve()), '-o', str(exe)], check=True, cwd=build)
    baseline_exe = build / 'baseline.exe'
    subprocess.run(['gfortran', '-' + opt, '-fcheck=all', '-J' + str(build),
                    str(ROOT / 'src/process/mod_daily_rain_duration.f90'), str(baseline),
                    str(a.ttutil.resolve()), '-o', str(baseline_exe)], check=True, cwd=build)
    baseline_run = build / 'baseline'
    baseline_run.mkdir()
    (baseline_run / 'input.swp').write_bytes((case / 'swap.swp').read_bytes())
    (baseline_run / 'input.met').write_bytes((case / '260.met').read_bytes())
    subprocess.run([str(baseline_exe), 'input.swp', 'input.met'], cwd=baseline_run,
                   check=True, capture_output=True, timeout=60)
    baseline_bytes = (baseline_run / 'rain_events.csv').read_bytes()
    for name in ('valid', 'custom', 'missing_last', 'late_gap', 'invalid_last', 'existing',
                 'custom_existing', 'missing_argument', 'empty_output', 'long_output', 'extra_argument'):
        run = build / name
        run.mkdir()
        (run / 'input.swp').write_bytes((case / 'swap.swp').read_bytes())
        lines = weather.copy()
        if name == 'missing_last':
            del lines[records[-1]]
        if name == 'late_gap':
            del lines[records[-2]]
        if name == 'invalid_last':
            fields = lines[records[-1]].split(',')
            fields[-1] = '0.0'  # positive rainfall without duration
            lines[records[-1]] = ','.join(fields)
        (run / 'input.met').write_text('\n'.join(lines) + '\n')
        target = run / ('selected events.csv' if name.startswith('custom') else 'rain_events.csv')
        if name in ('existing', 'custom_existing'):
            target.write_bytes(b'existing-authority\n')
        args = [str(exe), 'input.swp', 'input.met']
        if name.startswith('custom'):
            args.append(target.name)
        if name == 'missing_argument':
            args.pop()
        if name == 'empty_output':
            args.append('')
        if name == 'long_output':
            args.append('x' * 1025)
        if name == 'extra_argument':
            args.extend(['out.csv', 'unexpected'])
        r = subprocess.run(args, cwd=run,
                           capture_output=True, timeout=60)
        (run / 'stdout.txt').write_bytes(r.stdout)
        (run / 'stderr.txt').write_bytes(r.stderr)
        assert (r.returncode == 0) == (name in ('valid', 'custom')), (opt, name, r.stderr)
        if name in ('valid', 'custom'):
            assert target.read_bytes() == baseline_bytes, (opt, name, 'baseline output changed')
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
            if name == 'valid':
                default_digest = digest
            else:
                assert digest == default_digest
                assert not (run / 'rain_events.csv').exists()
        elif name in ('existing', 'custom_existing'):
            assert target.read_bytes() == b'existing-authority\n'
        else:
            assert not target.exists(), (opt, name, 'partial stream published')
        results.append({'optimization': opt, 'case': name, 'returncode': r.returncode})
    if opt == 'O0':
        first_digest = digest
    else:
        assert digest == first_digest
(out / 'RESULT.json').write_text(json.dumps({'cases': results, 'valid_sha256': digest}, indent=2))
print('RAIN_ADAPTER_PUBLICATION_O0_O2_PASS')
