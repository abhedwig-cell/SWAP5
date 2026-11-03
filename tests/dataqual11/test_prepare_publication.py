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
for opt in ('O0', 'O2'):
    build = out / opt
    build.mkdir()
    exe = build / 'prepare.exe'
    subprocess.run(['gfortran', '-' + opt, '-fcheck=all', '-J' + str(build),
                    str(ROOT / 'src/process/mod_daily_rain_duration.f90'),
                    str(ROOT / 'app/solute_project/prepare_rain_duration.f90'),
                    str(a.ttutil.resolve()), '-o', str(exe)], check=True, cwd=build)
    for name in ('valid', 'missing_last', 'late_gap', 'invalid_last', 'existing'):
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
        target = run / 'rain_events.csv'
        if name == 'existing':
            target.write_bytes(b'existing-authority\n')
        r = subprocess.run([str(exe), 'input.swp', 'input.met'], cwd=run,
                           capture_output=True, timeout=60)
        (run / 'stdout.txt').write_bytes(r.stdout)
        (run / 'stderr.txt').write_bytes(r.stderr)
        assert (r.returncode == 0) == (name == 'valid'), (opt, name, r.stderr)
        if name == 'valid':
            digest = hashlib.sha256(target.read_bytes()).hexdigest()
        elif name == 'existing':
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
