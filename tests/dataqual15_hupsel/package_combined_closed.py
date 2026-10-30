"""Package the executed combined DATAQUAL15 source closure; no model emulation."""
import argparse, hashlib, io, json, subprocess, tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
W = ROOT.parent
sha = lambda b: hashlib.sha256(b).hexdigest()
load = lambda p: json.loads(p.read_text())
p = argparse.ArgumentParser()
p.add_argument('--workspace', type=Path, default=W)
a = p.parse_args()
W = a.workspace.resolve()
destination = ROOT/'integration/dataqual15_hupsel'
destination.mkdir(parents=True, exist_ok=True)
members = {}
def add(name, data):
    if name in members:
        assert members[name] == data, name
    members[name] = data
def file(name, path): add(name, path.read_bytes())
def js(name, value): add(name, (json.dumps(value, indent=2, sort_keys=True)+'\n').encode())

builds = {'grass-O2': 'dq15-combined-grass-O2b',
          'hupsel-O2': 'dq15-combined-hupsel-O2c',
          'hupsel-O2-parent': 'dq15-combined-hupsel-O2b',
          'hupsel-O0': 'dq15-combined-hupsel-O0'}
normalized = {}
source = {}
for label, folder in builds.items():
    base = W/folder
    build = load(base/'BUILD.json')
    file('builds/'+label+'/BUILD.json', base/'BUILD.json')
    if (base/'EVENTS.json').exists(): file('builds/'+label+'/EVENTS.json', base/'EVENTS.json')
    for event in base.glob('*.stdout'): file('builds/'+label+'/'+event.name, event)
    for event in base.glob('*.stderr'): file('builds/'+label+'/'+event.name, event)
    entries = {}
    for original, digest in build['source_sha256'].items():
        path = Path(original)
        data = path.read_bytes()
        assert sha(data) == digest, path
        if path.is_relative_to(ROOT):
            relative = path.relative_to(ROOT).as_posix()
            source[relative] = digest
            key = 'source/repository/'+relative
        else:
            key = 'source/generated/'+label+'/'+path.name
        add(key, data)
        entries[key] = digest
    exe = 'swap5_grass_startup' if label == 'grass-O2' else 'swap5_hupsel_germination'
    assert sha((base/exe).read_bytes()) == build['executable_sha256']
    file('binaries/'+label, base/exe)
    if (base/'read_fallow').exists(): file('binaries/read-fallow-'+label, base/'read_fallow')
    normalized[label] = dict(provider_count=build['provider_count'], compiler=build['compiler'],
        flags=[('-I<BUILD>' if x.startswith('-I') else '-J<BUILD>' if x.startswith('-J') else x) for x in build['flags']],
        source_sha256=entries, executable_sha256=build['executable_sha256'])

extra = ['tools/solute/build_grass_startup.py', 'tools/solute/legacy_reader_sources.py',
         'tests/dataqual15/run_original.py', 'tests/dataqual15/checkpoint_layout.py',
         'tests/dataqual15/qualify_restart.py', 'tests/dataqual15_hupsel/build_and_run.py',
         'tests/dataqual15_hupsel/run.py', 'tests/dataqual15_hupsel/qualify_rotation_restart_guards.py',
         'tests/dataqual15_hupsel/package_combined_closed.py', 'tests/dataqual15_hupsel/verify_combined_closed.py',
         'app/solute_project/read_fallow_project.f90',
         'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',
         'integration/audits/evidence/SWAP431_TTUTIL_AUTHORITY.zip.b64']
for relative in extra:
    data = (ROOT/relative).read_bytes(); source[relative] = sha(data)
    add('source/repository/'+relative, data)

cases = {'grass-full367': 'dq15-combined-grass367-O2',
         'grass-restart365': 'dq15-combined-grass365-restart-O2',
         'grass-guards365': 'dq15-combined-grass365-guards-O2',
         'hupsel-full1096': 'dq15-combined-hupsel1096-O2',
         'hupsel-restart584': 'dq15-combined-hupsel584-restart-O2',
         'hupsel-restart730': 'dq15-combined-hupsel730-restart-O2',
         'hupsel-restart868': 'dq15-combined-hupsel868-restart-O2',
         'hupsel-tail1058-O0': 'dq15-combined-hupsel1058-tail-O0',
         'hupsel-restart1077-O0': 'dq15-combined-hupsel1077-restart-O0',
         'hupsel-guards730-O2': 'dq15-combined-codec730-O2',
         'hupsel-guards868-O2': 'dq15-combined-codec868-O2',
         'hupsel-guards1077-O0': 'dq15-combined-codec1077-O0'}
for label, folder in cases.items():
    base = W/folder
    assert (base/'RESULT.json').exists(), base
    if label.startswith('hupsel-') and 'guards' not in label:
        incoming=load(base/'RESULT.json')['command'][2]
        if incoming!='-': file('cases/'+label+'/restart-origin.bin',Path(incoming))
    for path in base.rglob('*'):
        if not path.is_file() or '.tmp' in path.name: continue
        if path.suffix in ('.csv', '.bin', '.json', '.nml', '.swp', '.crp', '.met', '.dra', '.bbc', '.binding') or path.name in ('stdout', 'stderr', 'prepare.stdout', 'prepare.stderr'):
            file('cases/'+label+'/'+path.relative_to(base).as_posix(), path)

grass = W/'dq15-final-full-O2'
file('golden/grass/LAUNCH.json', grass/'LAUNCH.json')
file('golden/grass/application.binding', grass/'application.binding')
file('golden/grass/checkpoint-367.bin', grass/'checkpoint-367.bin')
for name in ['budget.csv', 'crop.csv']:
    add('golden/grass/'+name, b''.join((grass/name).read_bytes().splitlines(keepends=True)[:368]))
for name in ['RESULT.json','budget.csv','crop.csv']:
    file('context/grass-C2-terminal1786/'+name, grass/name)
hupsel = W/'dq15-hupsel-rotation-full-native-r-O2'
for name in ['RESULT.json', 'budget.csv', 'crop.csv', 'germination.csv', 'endpoint.csv', 'state.csv', 'temperature.csv', 'restart.bin', 'checkpoint.bin']:
    file('golden/hupsel/'+name, hupsel/name)
file('golden/hupsel/BUILD.json', W/'dq15-hupsel-rotation-current-r-O2/BUILD.json')
donor=W/'dq15-hupsel-reference-highprec-scalar'
for name in ['result_output.csv','RESULT.json','LAUNCH.json','NATIVE.json','ORIGINAL_BUILD.json','OUTPUT_ONLY.diff','swap.swp']:
    file('reference/'+name,donor/name)
add('reference/FINAL_REFERENCE_COMPARISON.json',subprocess.check_output(['git','show','4bcadc9:integration/dataqual15_hupsel/FINAL_REFERENCE_COMPARISON.json'],cwd=ROOT))
ttutil = Path('/workspace/scratch/f29d9f3066a3/dq13-reference431/providers/ttobj/libttutil.a')
file('ttutil/libttutil.a', ttutil)

# Record every changed production path, including any code outside the two
# compiled graphs. The verifier rejects an unreviewed new path or byte change.
baseline='3170aa1'
baseline_raw=subprocess.check_output(['git','archive',baseline,'src','app'],cwd=ROOT)
with tarfile.open(fileobj=io.BytesIO(baseline_raw)) as tree:
    baseline_inventory={m.name:sha(tree.extractfile(m).read()) for m in tree if m.isfile()}
js('BASELINE_PRODUCTION_SHA256.json',baseline_inventory)
reviewed={}
changed=subprocess.check_output(['git','diff','--name-only',baseline,'--','src','app'],cwd=ROOT,text=True).splitlines()
for relative in changed:
    path=ROOT/relative
    reviewed[relative]=sha(path.read_bytes()) if path.exists() else None
    if path.exists():
        data=path.read_bytes();source[relative]=sha(data);add('source/repository/'+relative,data)

input_map = {}
for original, target in [('swap.swp','input.swp'),('grass.crp','grass.crp'),('260.met','input.met'),('swap.bbc','swap.bbc'),('swap.dra','swap.dra')]:
    relative = 'reference/swap-4.3.1/projects/2.grassgrowth/'+original
    data = (ROOT/relative).read_bytes(); source[relative] = sha(data); add('source/repository/'+relative,data)
    input_map['cases/grass-full367/'+target] = relative
for name in ['swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra']:
    relative = 'reference/swap-4.3.1/projects/1.hupselbrook/'+name
    data = (ROOT/relative).read_bytes(); source[relative] = sha(data); add('source/repository/'+relative,data)
    input_map['cases/hupsel-full1096/'+name] = relative

receipt = dict(status='COMBINED_ORIGINAL_HUPSEL1096_AND_GRASS367_PRESERVATION_PASS_NOT_PRODUCTION_OR_SCIENTIFIC_EQUIVALENCE',
    compiled_source_commit='ef9a107', merge_source_commit='aa5fa35',
    integration_base_grass='139330b', integration_hupsel='e7b1732',
    repository_source_sha256=source, normalized_builds=normalized, original_input_map=input_map,
    reviewed_production_delta_baseline=baseline,reviewed_production_delta=reviewed,
    ttutil_sha256=sha(members['ttutil/libttutil.a']),
    full_original_hupsel=True, combined_grass_executed_days=367,
    full_scientific_equivalence=False, production_promoted=False, canonically_admitted=False,
    grass_C2_context=dict(source='139330b',completed_days=1786,full_project=False,successor_C3_excluded=True),
    hard_bounds=dict(water_cm=1e-10,solute_mg_cm2=1e-10,heat_j_cm2=1e-9,
        authorities=['app/solute_project/main.f90: numerical transaction mass_tolerance',
        'src/runtime/mod_fmr_b111_pond_thermal_application.f90: chemical receipt closure',
        'src/process/mod_soil_temperature_contract.f90: energy_abs_tolerance_j_cm2']),
    diagnostic_difference='584-to591 restart: only unused post-emergence pressure_average_cm retains a pre-emergence value in uninterrupted CSV and initializes to zero after restart; all physiology, water/solute/heat and complete native state are identical.',
    executions={label: load(W/folder/'RESULT.json') for label,folder in cases.items() if 'guards' not in label})
js('QUALIFICATION.json', receipt)
manifest = {name: sha(data) for name,data in sorted(members.items())}
js('MANIFEST.json', manifest)
archive = destination/'COMBINED_CLOSED_EVIDENCE.tar.xz'
with tarfile.open(archive,'w:xz',preset=6) as tar:
    for name,data in sorted(members.items()):
        item=tarfile.TarInfo(name);item.size=len(data);item.mtime=0;item.mode=0o644
        tar.addfile(item,io.BytesIO(data))
summary={k:v for k,v in receipt.items() if k!='executions'}
summary.update(archive_sha256=sha(archive.read_bytes()),archive_members=len(members),archive_bytes=archive.stat().st_size,
    execution_summaries={k:{x:r.get(x) for x in ['returncode','completed_days','seconds','maximum_water_residual_cm','maximum_solute_residual_mg_cm2','maximum_heat_accounting_residual_j_cm2']} for k,r in receipt['executions'].items()})
(destination/'COMBINED_CLOSED_RESULT.json').write_text(json.dumps(summary,indent=2,sort_keys=True)+'\n')
print(json.dumps({k:summary[k] for k in ['archive_sha256','archive_members','archive_bytes']}))
