"""Execute an immutable diagnostic seed; never qualify a cross-executable restart."""
import argparse, hashlib, json, os, shutil, subprocess, time
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
for name in ('bundle', 'origin', 'output'):
    p.add_argument('--' + name, required=True, type=Path)
p.add_argument('--timeout', type=float, default=300)
a = p.parse_args()
bundle, origin, out = a.bundle.resolve(), a.origin.resolve(), a.output.resolve()
sha = lambda path: hashlib.sha256(Path(path).read_bytes()).hexdigest()
meta = json.loads((bundle / 'BUILD.json').read_text())
assert all(sha(n) == h for n, h in meta['source_sha256'].items())
assert all(sha(n) == h for n, h in meta['object_sha256'].items())
out.mkdir()
launch = json.loads((origin.parent / 'LAUNCH.json').read_text())
before = sha(origin)
for name, pin in launch['original_input_sha256'].items():
    assert sha(origin.parent / name) == pin
    shutil.copyfile(origin.parent / name, out / name)
command = launch['command'].copy()
command[0] = str(bundle / 'swap5_hupsel_germination.exe')
command[2] = str(origin)
report = dict(scope='READ_ONLY_DIAGNOSIS_NOT_OWN_RESTART_QUALIFICATION',
              command=command, origin_sha256=before,
              build_sha256=sha(bundle / 'BUILD.json'), executable_sha256=sha(command[0]),
              source_sha256=meta['source_sha256'])
(out / 'START.json').write_text(json.dumps(report, indent=2) + '\n')
start = time.monotonic()
censored = False
with (out / 'stdout').open('wb') as stdout, (out / 'stderr').open('wb') as stderr:
    try:
        r = subprocess.run(command, cwd=out, env=dict(os.environ, OMP_NUM_THREADS='1'),
                           stdout=stdout, stderr=stderr, timeout=a.timeout)
        code = r.returncode
    except subprocess.TimeoutExpired:
        code, censored = -999, True
err = (out / 'stderr').read_bytes()
report.update(seconds=time.monotonic() - start, returncode=code, censored=censored,
              origin_unchanged=sha(origin) == before,
              nonlinear_stop=b'ORIGINAL_GATE_OBSERVATION_STOP' in err,
              temporal_stop=b'NEXT_TEMPORAL_OBSERVATION_STOP' in err,
              admission_stop=b'ADMISSION_OBSERVATION_STOP' in err,
              no_restart_published=not (out / 'restart.bin').exists())
(out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({k: v for k, v in report.items() if k not in ('source_sha256', 'command')}))
assert report['origin_unchanged'] and report['no_restart_published']
assert report['nonlinear_stop'] or report['temporal_stop'] or report['admission_stop'], err[-2000:]
