"""Bounded nonlinear pond authority, with exact unchanged predecessor execution."""
import argparse
import base64
import hashlib
import io
import json
import os
import runpy
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[2]
BASE = '437d96ff51ac8a5825b605caf788661848c88be5'
STATUS = 'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'
PRODUCTION = 'src/runtime/mod_fmr_b111_pond_solute_route.f90'
CASES = ['1', '0.5', '0.8', '1.0005', '1.5', '2']
SCIENCE = ['src', 'tests', 'tools', 'reference', '.github', 'app', 'examples',
           'integration/performance', 'integration/audits/verify_matrix_thermal.py',
           'integration/audits/verify_nonlinear_pond.py', 'integration/audits/qualify_nonlinear_pond.py']
HOOK = "    if 'evidence' in record().get('nonlinear_pond_successor', {}):\n        return runpy.run_path(str(ROOT / 'integration/audits/verify_nonlinear_pond.py'))['{function}']()\n"

def require(ok, why):
    if not ok:
        raise ValueError(why)

def sha(b):
    return hashlib.sha256(b).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def record():
    return json.loads((ROOT/STATUS).read_text())['nonlinear_pond_successor']

def source(reader=lambda p: (ROOT/p).read_bytes(), changed=None):
    s = record()
    require(s['baseline'] == BASE, 'wrong pond predecessor')
    git('merge-base', '--is-ancestor', BASE, 'HEAD')
    require(not git('status', '--porcelain', '--', *SCIENCE), 'dirty nonlinear pond source')
    changes = changed if changed is not None else {v.split('\t')[1]: v.split('\t')[0] for v in git('diff', '--name-status', BASE, 'HEAD', '--', *SCIENCE).splitlines()}
    expected = {PRODUCTION:'M', 'tests/nut-sol/run_nonlinear_pond.py':'A', 'integration/audits/qualify_nonlinear_pond.py':'A', 'integration/audits/verify_nonlinear_pond.py':'A', 'integration/audits/verify_matrix_thermal.py':'M', 'integration/performance/verify_proposal.py':'M', '.github/workflows/mc-sol01-nonlinear-pond.yml':'A'}
    require(changes == expected == {p: v['status'] for p,v in s['postimages'].items()}, 'foreign pond scientific delta')
    require({p for p in changes if p.startswith('src/')} == {PRODUCTION}, 'pond production boundary')
    for p,v in s['postimages'].items():
        require(sha(reader(p)) == v['sha256'], 'pond postimage '+p)
    old = subprocess.check_output(['git', 'show', BASE+':'+PRODUCTION], cwd=ROOT, text=True)
    require(old.count('p%frexp/=1d0') == 1, 'unknown pond exponent guard')
    require(reader(PRODUCTION).decode() == old.replace('p%frexp/=1d0', 'p%frexp<.5d0.or.p%frexp>2d0'), 'pond physics mutation')
    path = 'integration/audits/verify_matrix_thermal.py'
    expected = subprocess.check_output(['git', 'show', BASE+':'+path], cwd=ROOT, text=True)
    for fn in ['source', 'verify_qualification', 'self_test']:
        expected = expected.replace('def '+fn+'():\n', 'def '+fn+'():\n'+HOOK.replace('{function}',fn), 1)
    require(reader(path).decode() == expected, 'original thermal authority changed')
    path = 'integration/performance/verify_proposal.py'
    expected = subprocess.check_output(['git','show',BASE+':'+path],cwd=ROOT,text=True)
    for fn in ['source','verify_qualification','self_test']:
        marker='def '+fn+('(' if fn=='source' else '():')
        start=expected.index(marker);end=expected.index('\n',start)+1
        hook="    pond_status=ROOT/'integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'\n    if pond_status.exists() and 'evidence' in json.loads(pond_status.read_text()).get('nonlinear_pond_successor', {}):\n        return runpy.run_path(str(ROOT/'integration/audits/verify_nonlinear_pond.py'),run_name='registered_nonlinear_pond')['"+fn+"']("+('reader,changed' if fn=='source' else '')+")\n"
        expected=expected[:end]+hook+expected[end:]
    require(reader(path).decode()==expected,'original PERF01 authority changed')
    return s

def unpack(e):
    raw = base64.b64decode(b''.join((ROOT/e['path']).read_bytes().split()), validate=True)
    require(sha(raw) == e['decoded_sha256'], 'pond archive identity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as archive:
        ms = archive.getmembers()
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms), 'unsafe pond archive')
        require(len(ms) == len({m.name for m in ms}), 'duplicate pond archive')
        f = {m.name: archive.extractfile(m).read() for m in ms}
    manifest = json.loads(f.pop('MANIFEST.json'))
    require(set(f) == set(manifest), 'pond member inventory')
    require(all(sha(f[p]) == h for p,h in manifest.items()), 'pond raw member corruption')
    return f

def capsule():
    return unpack(record()['evidence'])

def validate(files, reader=lambda p: (ROOT/p).read_bytes()):
    build = json.loads(files['1/result.json'])
    for exponent in CASES:
        prefix = exponent+'/'
        p = json.loads(files[prefix+'result.json'])
        events = json.loads(files[prefix+'events.json'])
        require(p['status'] == 'NONLINEAR_POND_PHYSICAL_PASS_NOT_ADMITTED', 'unfinished pond case')
        require(p['exponent'] == float(exponent), 'wrong pond exponent')
        require(p['authority_sha256'] == '2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2', 'historical pond source')
        for path,h in p['input_sha256'].items():
            require(not Path(path).is_absolute() and '..' not in Path(path).parts, 'unsafe pond source')
            require(sha(reader(path)) == h, 'stale executed pond source '+path)
        for i,e in enumerate(events):
            require(e['returncode'] == 0 and e['seconds'] >= 0, 'failed pond native/build event')
            for stream in ['stdout', 'stderr']:
                require(prefix+e[stream] in files, 'missing pond native stream')
            raw = files[prefix+e['stdout']]
            if e['category'] == 'physical_native':
                marker = b'POND_JOINT_INVALID_FILE=PASS' if e['command'][1] == 'reject' else b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS'
                require(marker in raw, 'native pond assertion absent')
            if e['category'] == 'preservation_native':
                marker = b'POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' if Path(e['command'][0]).name == 'incumbent' else (b'SURFACE_JOINT_FRESH_PROCESS=PASS' if e['command'][1] == 'resume' else b'SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS')
                require(marker in raw, 'incumbent native assertion absent')
            if '-c' in e['command']:
                require('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'], 'unchecked pond build')
            if Path(e['command'][0]).name in ['joint', 'incumbent']:
                require(float(e['command'][-1]) == float(exponent), 'unexecuted pond exponent')
        for opt in ['O0','O2']:
            row = p['runs'][opt]
            require(row['physical_provider_count'] == build['runs'][opt]['physical_provider_count'], 'pond closure drift')
            for key in ['physical_stdout','dry_stdout','fill_stdout']:
                require(row[key].count('POND_ACTUAL_LITERAL_TWENTYONE_NEGATIVES_REPLAY=PASS') == 2, 'missing independent nonlinear oracle/rollback')
                require('DYNAMIC_POND_EIGHT_FORCING_REJECTIONS=PASS' in row[key], 'missing forcing negatives')
            for pre in ['', 'dry-', 'fill-']:
                require(files[prefix+opt+'/'+pre+'expected.bin'] == files[prefix+opt+'/'+pre+'fresh.bin'], 'pond fresh-process drift')
            require(files[prefix+opt+'/gross.bin.gross-next'] == files[prefix+opt+'/gross.bin.gross-fresh'], 'gross fresh-process drift')
            require(len(row['restart_negatives']) == 15, 'pond negative decoder coverage')
            require(row['original_surface_endpoint'] == '7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e', 'linear surface preservation')
            gross = [e for e in events if e['category'] == 'gross_native' and '/'+opt+'/' in e['command'][0]]
            require(len(gross) == 2, 'positive gross observation count')
            for e in gross:
                require(b'MC_SOL01_GROSS_POSITIVE_RUNON_RUNOFF_JOINT_V2=PASS' in files[prefix+e['stdout']], 'no positive runon/runoff')
            for pre in ['', 'dry-', 'fill-']:
                require(files[prefix+'O0/'+pre+'expected.bin'] == files[prefix+'O2/'+pre+'expected.bin'], 'pond O0/O2 drift')
            for name in ['test_dynamic_pond_joint.f90','test_pond_joint.f90']:
                raw = reader('tests/nut-sol/'+name).decode()
                require(raw.count('  call parameters(p)') == 1, 'unknown original driver')
                generated = raw.replace('  call parameters(p)', "  call parameters(p)\n  block\n    character(64)::arg\n    call get_command_argument(5,arg)\n    read(arg,*)p%frexp\n  end block")
                require(files[prefix+opt+'/'+name] == generated.encode(), 'changed original driver assertions')
    # Compare actual linear endpoints/restart against the original admitted capsule.
    old = json.loads((ROOT/'integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json').read_text())['dynamic_pond_successor_20261016']
    prior = unpack(old['science_archive'])
    for opt in ['O0','O2']:
        for name in ['expected.bin','restart.bin','dry-expected.bin','dry-restart.bin',
                     'fill-expected.bin','fill-restart.bin','old-expected.bin','old-restart.bin']:
            require(files['1/'+opt+'/'+name] == prior['final/'+opt+'/'+name], 'admitted linear byte drift '+name)
    q = json.loads(files['controls/result.json'])
    require(q['status'] == 'NONLINEAR_POND_SEMANTIC_NATIVE_CONTROLS_PASS_NOT_ADMITTED' and q['native_controls'] == 60, 'missing native config negatives')
    for path,h in q['inputs'].items():
        require(sha(reader(path)) == h, 'stale semantic control input')
    for exponent in CASES:
        require(q['cases'][exponent]['physical_sha256'] == sha(files[exponent+'/result.json']), 'unbound semantic controls')
    for i,e in enumerate(q['events']):
        require(e['returncode'] == 0 and b'POND_JOINT_INVALID_FILE=PASS' in files[f'controls/{i:04d}.stdout'], 'missing semantic native result')
    require(files['controls/original_pond_route.f90'] == subprocess.check_output(['git','show',BASE+':'+PRODUCTION],cwd=ROOT), 'wrong original guard experiment')
    for opt in ['O0','O2']:
        pre = q['preimage'][opt]
        require([e['returncode'] for e in pre[:3]] == [0,0,0] and pre[3]['returncode'] != 0, 'original nonlinear counterexample absent')
        require(b'FAIL smaller retry' in files['controls/preimage/'+opt+'/nonlinear.stdout'], 'original guard failure marker absent')
        require(files['controls/preimage/'+opt+'/expected.bin'] == files['1/'+opt+'/expected.bin'], 'original linear guard control differs')
    column = json.loads(files['column/qualification/result.json'])
    require(column['status'] == 'PASS' and len(column['events']) == 86, 'incumbent file column failed')
    for e in column['events']:
        require('column/qualification/'+e['stdout'] in files and 'column/qualification/'+e['stderr'] in files, 'missing raw column observation')
    for opt in ['O0','O2']:
        require(set(column['results'][opt]['grids']) == {'minimum','refined','deep','deep_dry_short','maximum'}, 'missing grid coverage')
        for name in ['restart.bin','endpoint.csv','state.csv','budget.csv']:
            require(files['column/qualification/O0/full/'+name] == files['column/qualification/O2/full/'+name], 'column O0/O2 endpoint drift')
        for name in ['restart.bin','endpoint.csv','state.csv']:
            require(files['column/qualification/'+opt+'/full/'+name] == files['column/qualification/'+opt+'/resumed/'+name], 'column independent restart drift')
    for opt in ['O0','O2']:
        b = json.loads(files['column/'+opt+'/build-complete.json'])
        require(b['status'] == 'BUILT' and b['provider_count'] == 178, 'missing real file column build')
        for path,h in b['input_sha256'].items():
            require(sha(reader(path)) == h, 'stale current column provider')
    require(sha(reader('tests/nut-sol/test_column_input.py')) == column['test_sha256'], 'column assertions changed')
    require(sha(reader('tools/solute/run_column.py')) == column['runner_sha256'], 'column runner changed')
    return {'nonlinear_pond': True, 'exponents': [float(x) for x in CASES], 'pond_fresh_restart': True,
            'linear_pond_bytes_preserved': True, 'current_column_preserved': True, 'semantic_native_controls': 60}

def predecessor():
    with tempfile.TemporaryDirectory(prefix='swap5-pond-predecessor-') as tmp:
        base = Path(tmp)/'base'
        subprocess.run(['git','worktree','add','--detach',str(base),BASE], cwd=ROOT, check=True, capture_output=True)
        try:
            r = subprocess.run([sys.executable,'-B','integration/audits/verify_matrix_thermal.py'], cwd=base,
                               capture_output=True, text=True, env={**os.environ, 'PYTHONDONTWRITEBYTECODE':'1'})
            require(r.returncode == 0, 'exact admitted predecessor: '+r.stderr[-3000:])
            old = json.loads(r.stdout)
            require(old['qualified'], 'unqualified predecessor')
            return old
        finally:
            subprocess.run(['git','worktree','remove','--force',str(base)], cwd=ROOT, check=True, capture_output=True)

def current_thermal():
    # PERF01 already freshly executed every thermal exponent on its changed
    # runtime. Every thermal compiled/oracle/input byte is still current: the
    # pond guard is absent from that execution closure. Revalidate original
    # raw science here, without rebinding old column proof or rerunning physics.
    perf = runpy.run_path(str(ROOT/'integration/performance/verify_proposal.py'))
    files = perf['capsule']()
    subset = {p.removeprefix('composition/thermal/'):raw for p,raw in files.items() if p.startswith('composition/thermal/')}
    owner = runpy.run_path(str(ROOT/'integration/audits/verify_matrix_thermal_nonlinear.py'))
    result = owner['validate'](subset)
    require(result['nonlinear_dynamic_endpoint_decay'], 'current six-exponent thermal evidence missing')
    report = json.loads(subset['1/physical/result.json'])
    require(PRODUCTION not in report['inputs'], 'pond guard entered thermal closure')
    return {'current_six_exponent_thermal_original_raw_science':True,
            'thermal_native_repetition':'NOT_SELECTED_IMPACT: every PERF01 thermal execution input is current'}

def verify_qualification():
    source()
    current = validate(capsule())
    thermal = current_thermal()
    old = predecessor()
    return {**old, **current, **thermal, 'qualified': True, 'full_capability': False,
            'source_tree': git('rev-parse','HEAD:src'), 'current_source_tree': git('rev-parse','HEAD:src'),
            'incumbent_production_unchanged': False, 'production_delta': 'one pond exponent guard1 ->0.5..2'}

def self_test():
    files = capsule()
    validate(files)
    controls = []
    for name in ['0.5/result.json','2/O2/expected.bin','1.5/O0/fresh.bin',
                 '0.8/O2/gross.bin.gross-fresh','controls/0000.stdout','column/qualification/result.json']:
        bad = dict(files)
        bad.pop(name)
        try:
            validate(bad)
        except (ValueError,KeyError):
            controls.append(name)
        else:
            raise ValueError('missing evidence accepted '+name)
    for path in [PRODUCTION,'src/process/mod_b111_solute_sorption.f90','tests/nut-sol/run_nonlinear_pond.py']:
        try:
            validate(files, lambda p: (ROOT/p).read_bytes()+(b'!' if p == path else b''))
        except ValueError:
            controls.append(path)
        else:
            raise ValueError('stale source accepted '+path)
    source()
    for path in [PRODUCTION, 'integration/performance/verify_proposal.py']:
        try:
            source(lambda p: (ROOT/p).read_bytes()+(b'!' if p == path else b''))
        except ValueError:
            controls.append('source '+path)
        else:
            raise ValueError('unregistered source mutation accepted '+path)
    changes = {p:v['status'] for p,v in record()['postimages'].items()}
    try:
        source(changed={**changes, 'src/foreign.f90':'A'})
    except ValueError:
        controls.append('foreign production delta')
    else:
        raise ValueError('foreign production accepted')
    return {'count':len(controls), 'negative_controls':controls}

if __name__ == '__main__':
    print(json.dumps(self_test() if '--self-test' in sys.argv else verify_qualification(), indent=2))
