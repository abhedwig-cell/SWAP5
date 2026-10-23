"""Source-verified isolated Newton-policy experiments; production stays intact."""
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
ap.add_argument('--variant', choices=['baseline', 'cap12', 'cap8', 'linefail'], required=True)
ap.add_argument('--driver', type=Path, help='Previously qualified generated control driver; pin its exact bytes')
ap.add_argument('--observe-work', action='store_true')
a = ap.parse_args()
build, out = a.build.resolve(), a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
meta = json.loads((build / 'BUILD.json').read_text())
assert meta['status'] == 'BUILT' and sha(build / 'weather') == meta['executable_sha256']
assert sha(build / 'driver.f90') == meta['generated_driver_sha256']
overrides = {'tests/fsi/fsi04_real_headcalc_stubs.f90': 'grid_stubs.f90',
             'src/runtime/mod_fmr_serialized_multiswap_runtime.f90': 'observed_serial_runtime.f90',
             'src/runtime/mod_fmr_production_application_bootstrap.f90': 'observed_bootstrap.f90'}
for path, h in meta['sources'].items():
    assert sha(build / overrides[path] if path in overrides else ROOT / path) == h, path
for path, key in [('src/runtime/mod_fmr_serialized_multiswap_runtime.f90', 'observer_original_sha256'),
                  ('src/runtime/mod_fmr_production_application_bootstrap.f90', 'surface_observer_original_sha256')]:
    assert sha(ROOT / path) == meta[key], path
head = ROOT / 'src/legacy/b1_10_port/headcalc.f90'
assert sha(head) == meta['headcalc_sha256']
driver = (build / 'driver.f90').read_text()
if a.driver:
    driver = a.driver.read_text()
anchor = '  config%tiles(1)%parameters%max_iterations=20'
assert driver.count(anchor) == 1
if a.variant in ['cap12', 'cap8']:
    driver = driver.replace(anchor, anchor.replace('=20', '=' + a.variant[3:]), 1)
if a.observe_work:
    for old, new in [
        ('accepted,heads,rejections\n', 'accepted,heads,rejections,njac,nback,nfailed\n'),
        ('residual=0d0;accepted=0;heads=0;rejections=0', 'residual=0d0;accepted=0;heads=0;rejections=0;njac=0;nback=0;nfailed=0'),
        ('      rejections=rejections+rr(1)%temporal_rejections',
         '      njac=njac+rr(1)%solver_jacobian_builds;nback=nback+rr(1)%solver_backtracking_attempts\n' +
         '      nfailed=nfailed+rr(1)%solver_rejections\n      rejections=rejections+rr(1)%temporal_rejections'),
        ('    call cpu_time(endcpu)', "    call cpu_time(endcpu)\n    write(*,'(a,4(1x,i0))') 'NEWTON_WORK',d+1,njac,nback,nfailed")]:
        assert driver.count(old) == 1, old
        driver = driver.replace(old, new, 1)
text = head.read_text()
if a.variant == 'linefail':
    anchor = ' 1    continue\n\n!     check on convergence of solution'
    assert text.count(anchor) == 1
    text = text.replace(anchor, ' 1    continue\n' +
        '      if (itry > MaxBackTr .and. sump >= sumold .and. Fmax >= CritDevBalCp) exit\n' +
        '\n!     check on convergence of solution', 1)
(out / 'driver.f90').write_text(driver)
(out / 'headcalc_experiment.f90').write_text(text)
flags = [v for v in meta['flags'] if not v.startswith(('-I', '-J'))]
flags += ['-I' + str(build), '-J' + str(out)]
objects = [build / f'{i:04d}.o' for i in range(len(meta['sources']))]
pinned = {str(p): sha(p) for p in [*objects, *sorted(build.glob('*.mod'))]}
compiler = {str(Path(p).resolve()): sha(Path(p)) for p in meta['compiler_command']}
command = meta['compiler_command'] + flags + [str(out / 'driver.f90'), str(out / 'headcalc_experiment.f90')]
command += [str(p) for p in objects] + ['-o', str(out / 'weather')]
start = time.monotonic()
result = subprocess.run(command, capture_output=True)
for stream in ['stdout', 'stderr']:
    (out / ('link.' + stream)).write_bytes(getattr(result, stream))
result.check_returncode()
assert all(sha(Path(p)) == h for p, h in pinned.items()), 'shared build changed'
(out / 'weather.999').write_bytes((build / 'weather.999').read_bytes())
meta.update(executable_sha256=sha(out / 'weather'), generated_driver_sha256=sha(out / 'driver.f90'),
            newton_work_research_variant=a.variant, generated_headcalc_sha256=sha(out / 'headcalc_experiment.f90'),
            production_changed=False, parent_build=str(build), pinned_artifacts=pinned,
            observe_work=a.observe_work,
            compiler_command_sha256=compiler, compiler_version=subprocess.check_output(meta['compiler_command'] + ['--version'], text=True),
            experiment_link=dict(command=command, returncode=result.returncode, seconds=time.monotonic() - start),
            experiment_source_commit=subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip())
if a.driver:
    meta['control_driver'] = dict(path=str(a.driver.resolve()), sha256=sha(a.driver))
(out / 'BUILD.json').write_text(json.dumps(meta, indent=2) + '\n')
print(json.dumps(dict(status='BUILT_GENERATED_RESEARCH_ONLY', variant=a.variant,
                      seconds=meta['experiment_link']['seconds'])))
