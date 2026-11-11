"""O0/O2 real heat-body controls against four original implicit solves.

The existing bound O2 native graph supplies unchanged contract dependencies.
Both the private and original heat implementations are freshly compiled at each
optimization. This is not a cold O0 build of the complete application.
"""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--bundle', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
bundle = a.bundle.resolve()
out = a.output.resolve()
out.mkdir(parents=True, exist_ok=False)
build = json.loads((bundle/'BUILD.json').read_text())
assert build['status'] == 'ORIGINAL_INTERVAL_COMPLETED'
sha = lambda p: hashlib.sha256(Path(p).read_bytes()).hexdigest()
for source, h in build['source_sha256'].items():
    assert sha(source) == h, source
for obj, h in build['object_sha256'].items():
    assert sha(obj) == h, obj
sources = list(build['source_sha256'])
objects = list(build['object_sha256'])
assert len(sources) == len(objects)
archive = next(e['command'][-3] for e in build['events'] if e['label'] == 'link')
assert sha(archive) == build['original_input_archive_sha256']
retained = [o for s, o in zip(sources, objects)
            if Path(s).name not in ['mod_restricted_soil_temperature.f90', 'initial_interval.f90']]
original = subprocess.check_output(['git', 'show',
    'f96c9f23ed2234255c0ceeb64e82c3e87f2e77fe:src/process/mod_restricted_soil_temperature.f90'], cwd=ROOT).decode()
control = out/'original_control.f90'
control.write_text(original.replace('mod_restricted_soil_temperature',
                                   'mod_restricted_soil_temperature_control'), newline='\n')
events = []


def run(cmd, folder, label):
    start = time.perf_counter()
    try:
        r = subprocess.run(list(map(str, cmd)), cwd=folder, capture_output=True, timeout=60)
        rc = r.returncode
    except subprocess.TimeoutExpired as e:
        r, rc = e, None
    (folder/(label+'.stdout')).write_bytes(r.stdout or b'')
    (folder/(label+'.stderr')).write_bytes(r.stderr or b'')
    events.append(dict(label=label, profile=folder.name, command=list(map(str, cmd)),
                       seconds=time.perf_counter()-start, returncode=rc))
    (out/'events.json').write_text(json.dumps(events, indent=2)+'\n')
    assert rc == 0, (label, rc)


fc = build['events'][0]['command'][0]
for opt in ['O0', 'O2']:
    folder = out/opt
    folder.mkdir()
    flags = ['-'+opt, '-std=f2008', '-ffree-line-length-none', '-fcheck=all',
             '-fbacktrace', '-ffpe-trap=invalid,zero,overflow',
             '-I'+str(folder), '-I'+str(bundle), '-J'+str(folder)]
    private = ROOT/'src/process/mod_restricted_soil_temperature.f90'
    run([fc, *flags, '-c', private, '-o', folder/'private.o'], folder, 'compile-private')
    run([fc, *flags, '-c', control, '-o', folder/'original.o'], folder, 'compile-original')
    driver = Path(__file__).with_name('test_thermal_subcycle.f90')
    run([fc, *flags, '-fopenmp', driver, folder/'private.o', folder/'original.o',
         *retained, archive, '-o', folder/'control.exe'], folder, 'compile-link-driver')
    run([folder/'control.exe'], folder, 'native')
    assert 'THERMAL_SUBCYCLE_ORIGINAL_SOLVES_FACES_AND_REFUSAL=PASS' in (folder/'native.stdout').read_text()
result = dict(status='REAL_HEAT_BODY_O0_O2_ORIGINAL_SOLVES_FACES_AND_REFUSAL_PASS',
              compiler=build['compiler'], events=events, original_control_sha256=sha(control),
              private_body_sha256=sha(private), driver_sha256=sha(driver),
              scope=__doc__, native_graph_build_sha256=sha(bundle/'BUILD.json'))
(out/'RESULT.json').write_text(json.dumps(result, indent=2)+'\n')
print(result['status'])
