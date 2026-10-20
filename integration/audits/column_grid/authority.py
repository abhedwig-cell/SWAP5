"""Exact application-grid proof; original NUT/age assertions remain operative."""
from pathlib import Path
import base64
import hashlib
import io
import json
import subprocess
import tarfile

ROOT = Path(__file__).resolve().parents[3]
BASE = 'e57a94e5f229415111563f8c52822ac3c7ba5491'
STATUS = 'integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json'
GUARD = 'tests/nut-crop/verify_historical_gross.py'
TEST = 'tests/nut-sol/test_column_input.py'
MARKER = " rows={r.split('\\t')[1]:r.split('\\t')[0]for r in git('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}\n"
HOOK = """ # Application-only grid successor owns its exact test and fresh native proof.
 grid=json.loads((ROOT/'integration/audits/MC_NUT_SOL_TRAJECTORY3_STATUS.json').read_text())['column_input_20261020'].get('variable_grid_successor',{})
 if 'evidence'in grid:
  import runpy
  runpy.run_path(str(ROOT/'integration/audits/column_grid/authority.py'),run_name='column_grid_authority')['verify_qualification']()
  require(rows.pop('tests/nut-sol/test_column_input.py',None)=='M','missing grid-owned application test')
"""


def require(ok, label):
    if not ok:
        raise ValueError(label)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def original(path):
    return subprocess.check_output(['git', 'show', BASE + ':' + path], cwd=ROOT)


def verify_qualification():
    nut=json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text()).get('accepted_atmosphere_successor',{})
    if 'evidence'in nut:
        import runpy
        proof=runpy.run_path(str(ROOT/'tests/nut-crop/verify_accepted_atmosphere.py'),run_name='registered_nut_atmosphere')['verify_qualification']()
        return {**proof,'application_grid':True,'process_observations':86,'production_changed':False,'grid_preserved_on_exact_current_providers':True}
    s = json.loads((ROOT / STATUS).read_text())['column_input_20261020']['variable_grid_successor']
    require(s['baseline'] == BASE, 'grid baseline identity')
    owned = {'app/solute_column/main.f90', 'app/solute_column/link_context.f90', TEST,
             'examples/solute_column/deep_grid.nml', GUARD, 'integration/audits/column_grid/authority.py'}
    require(set(s['postimages']) == owned, 'grid source ownership')
    for path, h in s['postimages'].items():
        require(sha((ROOT / path).read_bytes()) == h, 'grid current source ' + path)
    # All old NUT science, source restrictions and negative assertions survive
    # byte for byte, apart from this exact handoff of the application test.
    old = original(GUARD).decode()
    require(old.count(MARKER) == 1 and (ROOT / GUARD).read_text() == old.replace(MARKER, MARKER + HOOK),
            'grid changed original NUT guard beyond exact handoff')
    require(not subprocess.check_output(['git', 'diff', BASE, 'HEAD', '--', 'src', 'reference'], cwd=ROOT),
            'grid changed production/reference science')
    nutpath = 'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
    before = json.loads(original(nutpath))['historical_gross_top_successor']
    current = json.loads((ROOT / nutpath).read_text())['historical_gross_top_successor']
    before['postimages'][GUARD]['sha256'] = sha((ROOT / GUARD).read_bytes())
    require(before == current, 'grid changed NUT admission beyond guard hash')
    e = s['evidence']
    raw = base64.b64decode((ROOT / e['path']).read_bytes())
    require(sha(raw) == e['decoded_sha256'], 'grid capsule integrity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        members = archive.getmembers()
        require(len(members) == len({m.name for m in members}) and all(m.isfile() and not Path(m.name).is_absolute()
                and '..' not in Path(m.name).parts for m in members), 'grid capsule safety')
        files = {m.name: archive.extractfile(m).read() for m in members}
    manifest = json.loads(files.pop('MANIFEST.json'))
    require(set(manifest) == set(files) and all(sha(files[p]) == h for p, h in manifest.items()), 'grid members')
    r = json.loads(files['qualification/result.json'])
    require(r['status'] == 'PASS' and r['test_sha256'] == sha((ROOT / TEST).read_bytes()), 'grid executed test')
    require(r['runner_sha256'] == sha((ROOT / 'tools/solute/run_column.py').read_bytes()), 'grid executed launcher')
    require(r['input_sha256'] == sha((ROOT / 'examples/solute_column/positive_pond.nml').read_bytes()), 'grid old input')
    require(r['results']['O0']['grids'] == r['results']['O2']['grids'], 'grid O0/O2 physical identity')
    require(len(r['events']) == 86, 'grid process inventory')
    for event in r['events']:
        for stream in ['stdout', 'stderr']:
            require('qualification/' + event[stream] in files, 'grid raw process stream')
    for opt in ['O0', 'O2']:
        row = r['results'][opt]
        build = json.loads(files['build-' + opt + '/build-complete.json'])
        require(build['status'] == 'BUILT' and build['provider_count'] == 178, 'grid real provider closure')
        require(build['input_sha256'] == row['source_sha256'] and build['executable_sha256'] == row['executable_sha256'],
                'grid executed build binding')
        for path, h in build['input_sha256'].items():
            require(sha((ROOT / path).read_bytes()) == h, 'grid executed provider ' + path)
        events = build['events']
        require(len(events) == 179 and all(x['returncode'] == 0 for x in events), 'grid compilation and link')
        for event in events:
            c = event['command']
            require('-' + opt in c and '-fcheck=all' in c and '-ffpe-trap=invalid,zero,overflow' in c, 'grid compiler checks')
            for stream in ['stdout', 'stderr']:
                require('build-' + opt + '/' + event[stream] in files, 'grid raw compiler stream')
        require(row['restart_sha256'] == '42d92009baeb4e7a90ef2e2ebbd22c79df69cb05bc7cf0e01e7cea39bf192e4f',
                'grid original endpoint drift')
        require(set(row['grids']) == {'minimum', 'refined', 'deep', 'deep_dry_short', 'maximum'}, 'grid physical cases')
        for name, nodes in [('minimum', 2), ('refined', 8), ('deep', 32), ('deep_dry_short', 32), ('maximum', 256)]:
            g = row['grids'][name]
            require(g['nodes'] == nodes, 'grid physical size')
            prefix = 'qualification/' + opt + '/' + name + '/'
            for filename in ['restart.bin', 'state.csv', 'endpoint.csv']:
                require(files[prefix + 'full/' + filename] == files[prefix + 'resumed/' + filename], 'grid fresh process ' + name)
            require(sha(files[prefix + 'input.nml']) == g['input_sha256'] and
                    sha(files[prefix + 'full/restart.bin']) == g['restart_sha256'], 'grid result binding')
            for b in g['budget']:
                dt = b['t1_day'] - b['t0_day']
                require(abs(b['water_end_cm'] - b['water_start_cm'] - dt + dt * 0.1008 + b['runoff_cm'] +
                            b['pond_evaporation_cm']) < 1e-10, 'grid independent water')
                require(abs(b['solute_end_mg_cm2'] - b['solute_start_mg_cm2'] - dt * 1.625 +
                            b['solute_out_mg_cm2']) < 1e-10, 'grid independent solute')
                require(b['accepted_substeps'] > 1, 'grid accepted substeps')
    return {'application_grid': True, 'qualified': True, 'production_changed': False, 'process_observations': 86}


if __name__ == '__main__':
    print(json.dumps(verify_qualification(), indent=2))
