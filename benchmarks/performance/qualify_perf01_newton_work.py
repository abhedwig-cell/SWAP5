"""Execute original direct contracts against the isolated generated HeadCalc."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--parent', type=Path, required=True)
ap.add_argument('--variant', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
a = ap.parse_args()
parent, variant, out = a.parent.resolve(), a.variant.resolve(), a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
b = json.loads((parent / 'BUILD.json').read_text())
v = json.loads((variant / 'BUILD.json').read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert b['sources'] == v['sources'] and v['newton_work_research_variant'] == 'linefail'
assert sha(variant / 'headcalc_experiment.f90') == v['generated_headcalc_sha256']
assert all(sha(Path(p)) == h for p, h in v['pinned_artifacts'].items())
objects = [parent / f'{i:04d}.o' for i in range(len(b['sources']))]
flags = [p for p in b['flags'] if not p.startswith(('-I', '-J'))] + ['-I'+str(parent), '-J'+str(out)]
report = dict(status='RUNNING', events=[], production_changed=False,
              generated_headcalc_sha256=v['generated_headcalc_sha256'], original_assertions_changed=False)
for name in ['retry', 'desaturation', 'top_derivative', 'warm_start']:
    source = ROOT / ('tests/fsi/test_weather_surface_' + name + '.f90')
    report.setdefault('input_sha256', {})[str(source.relative_to(ROOT))] = sha(source)
    commands = [('link', b['compiler_command'] + flags + [str(source), str(variant/'headcalc_experiment.f90'),
                   *map(str, objects), '-o', str(out/name)]), ('native', [str(out/name)])]
    for category, command in commands:
        start = time.monotonic()
        r = subprocess.run(command, cwd=out, capture_output=True, timeout=120)
        for stream in ['stdout', 'stderr']:
            (out/(name+'.'+category+'.'+stream)).write_bytes(getattr(r, stream))
        report['events'].append(dict(name=name, category=category, command=command, returncode=r.returncode,
                                     seconds=time.monotonic()-start))
        (out/'RESULT.json').write_text(json.dumps(report, indent=2)+'\n')
        if r.returncode:
            break
report['status'] = 'ORIGINAL_DIRECT_CONTRACTS_PASS' if all(e['returncode']==0 for e in report['events']) else 'ORIGINAL_DIRECT_CONTRACT_FAILURE_RETAINED'
(out/'RESULT.json').write_text(json.dumps(report, indent=2)+'\n')
print(report['status'])
