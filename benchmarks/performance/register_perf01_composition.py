"""Generate exact current source bindings from sealed physical observations."""
import hashlib
import json
from pathlib import Path
import runpy
import subprocess

ROOT = Path(__file__).resolve().parents[2]
guard = runpy.run_path(str(ROOT / 'integration/performance/verify_weather_composed_successor.py'))
git = guard['git']
sha = guard['sha']
path = ROOT / guard['STATUS']
status = json.loads(path.read_text())
previous = status['source_successor_20261022']
physical = json.loads((ROOT / 'benchmarks/performance/PERF01_ROOT_COMPOSITION_20261022_EVIDENCE.json').read_text())
index = json.loads((ROOT / 'benchmarks/performance/PERF01_ROOT_COMPOSITION_20261022_EVIDENCE.index.json').read_text())
harvest = json.loads((ROOT / 'benchmarks/performance/PERF01_HARVEST_COMPOSITION_20261022.json').read_text())
inputs = dict(physical['current_inputs'])
controller = inputs.pop(guard['ROOT_PARENT'])
inputs.update(json.loads(Path('/tmp/perf01-compose2-nut-harvest/result.json').read_text())['input_sha256'])
for p, h in inputs.items():
    assert sha((ROOT / p).read_bytes()) == h, p
delta = {line.split('\t')[1]: line.split('\t')[0] for line in
         git('diff', '--name-status', guard['BASE'], 'HEAD', '--', *guard['SCIENCE']).splitlines()}
manifest = json.loads((ROOT / guard['MANIFEST']).read_text())
candidate = '48d61aafcc152122de0f6e43b3e1fe3bcddbf0cb'
native_inputs = {d['path'] for d in manifest['dependencies']}
native_inputs.update(['src/legacy/b1_10_port/soilwater.f90',
                      'src/adapter/mod_b110_production_soil_water_task2.f90'])
native_hashes = {}
for p in sorted(native_inputs):
    old = subprocess.check_output(['git', 'show', candidate + ':' + p], cwd=ROOT)
    assert old == (ROOT / p).read_bytes(), p
    native_hashes[p] = sha(old)
compiler = '/workspace/scratch/4112bba79f91/compiler-bin/gfortran'
binary = '/workspace/scratch/4112bba79f91/compiler/usr/bin/x86_64-linux-gnu-gfortran-13'
status[guard['KEY']] = dict(
    baseline=guard['BASE'], physical_baseline=guard['PHYSICAL_BASE'],
    stage='CURRENT_NATIVE_PASS_SOURCE_QUALIFICATION_PENDING', qualified=False, canonically_admitted=False,
    evidence=dict(path='benchmarks/performance/PERF01_ROOT_COMPOSITION_20261022_EVIDENCE.tar.xz', **index),
    harvest_evidence=harvest['evidence'], source_delta=delta,
    postimages={p: sha((ROOT / p).read_bytes()) for p in delta},
    executed_input_sha256=inputs,
    historical_controller=dict(path=guard['ROOT_PARENT'], sha256=controller,
        scope='Only the noncompiled authority controller is projected for immutable physical-capsule replay; live original owner bodies are pinned by exact additive projection.'),
    frozen_owner_controls=36, frozen_latest_owner_controls=18,
    frozen_fsi35_successors=previous['frozen_fsi35_successors'],
    fsi35_native='INHERITED_TERMINAL_O0_O2_IDENTICAL_27_PROVIDERS_NATIVE_BODY_COMPILER',
    fsi35_native_inheritance=dict(candidate=candidate, input_sha256=native_hashes,
        receipt=previous['native_receipt']['path'], compiler_command=compiler,
        toolchain_sha256={p: sha(Path(p).read_bytes()) for p in [compiler, binary]}),
    test_selection='benchmarks/performance/PERF01_CANONICAL_RECONCILIATION_20261022.md',
    warm_start_default=False)
status['canonical_observed'] = guard['BASE']
status['next_action'] = 'Complete exact current source-owner, rejection, original FSI35 source and docs gates; publish and safely admit the bounded qualified repair. Keep optional warm start OFF.'
path.write_text(json.dumps(status, indent=2) + '\n')
print(json.dumps(dict(paths=len(delta), executed_inputs=len(inputs), native_inputs=len(native_hashes))))
