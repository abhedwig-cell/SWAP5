"""Link and execute real warm-start and unchanged corner controls."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time
ROOT = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser(description=__doc__)
ap.add_argument('--build', type=Path, required=True)
ap.add_argument('--output', type=Path, required=True)
args = ap.parse_args()
build, out = args.build.resolve(), args.output.resolve()
out.mkdir(parents=True, exist_ok=False)
meta = json.loads((build / 'BUILD.json').read_text())
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
assert meta['status'] == 'BUILT' and sha(build / 'weather') == meta['executable_sha256']
overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
             'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
             'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
for path, expected in meta['sources'].items():
    assert sha(build / overrides[path] if path in overrides else ROOT / path) == expected, path
assert sha(ROOT / 'src/legacy/b1_10_port/headcalc.f90') == meta['headcalc_sha256']
flags = [f for f in meta['flags'] if not f.startswith(('-I', '-J'))] + ['-I' + str(build), '-J' + str(out)]
objects = [str(build / f'{i:04d}.o') for i in range(len(meta['sources']))]
events = []
for name, marker in [('test_weather_surface_warm_start', 'WEATHER_WARM_START_PRODUCTION_CONTRACT_PASS'),
                     ('test_weather_surface_retry', 'WEATHER_SURFACE_RETRY_PASS'),
                     ('test_weather_surface_desaturation', 'WEATHER_SURFACE_DESATURATION_PASS')]:
    exe = out / name
    command = meta['compiler_command'] + flags + [str(ROOT / 'tests/fsi' / (name + '.f90')),
               str(ROOT / 'src/legacy/b1_10_port/headcalc.f90')] + objects + ['-o', str(exe)]
    for label, cmd in [('link', command), ('native', [str(exe)])]:
        start = time.monotonic(); result = subprocess.run(cmd, capture_output=True, timeout=120)
        for stream in ['stdout', 'stderr']:
            (out / (name + '.' + label + '.' + stream)).write_bytes(getattr(result, stream))
        events.append({'command': cmd, 'returncode': result.returncode, 'seconds': time.monotonic() - start})
        (out / 'events.json').write_text(json.dumps(events, indent=2) + '\n')
        result.check_returncode()
        if label == 'native':
            assert marker.encode() in result.stdout
report = {'status': 'WARM_START_AND_ORIGINAL_CORNER_CONTROLS_PASS', 'build': str(build),
          'flags': flags, 'events': events,
          'input_sha256': {str(p.relative_to(ROOT)): sha(p) for p in [Path(__file__),
             ROOT / 'tests/fsi/test_weather_surface_warm_start.f90',
             ROOT / 'src/adapter/mod_reference_richards_legacy_binding.f90',
             ROOT / 'src/solver/mod_soil_water_solver_contract.f90']}}
(out / 'RESULT.json').write_text(json.dumps(report, indent=2) + '\n')
print(report['status'])
