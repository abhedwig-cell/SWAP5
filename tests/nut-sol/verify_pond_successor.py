"""Exact bounded pond successor with executed native and incumbent evidence."""
from pathlib import Path
import base64
from functools import lru_cache
import hashlib
import io
import json
import subprocess
import sys
import tarfile

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
BASE = 'efe79f5fd58f564f54dde5ca5e575bb138c4bbb1'
STATUS = 'integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json'
SURFACE = ['src', 'tests', 'tools', 'reference', '.github']
PRODUCTION = {
    'src/process/mod_b111_persistent_pond.f90',
    'src/runtime/mod_fmr_b111_pond_solute_route.f90',
    'src/runtime/mod_fmr_b111_pond_joint_application.f90',
    'src/runtime/mod_fmr_serialized_reference_backend.f90',
}

def check(ok, label):
    if not ok:
        raise ValueError(label)

def sha(raw):
    return hashlib.sha256(raw).hexdigest()

def blob(raw):
    return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def record():
    return json.loads((ROOT/STATUS).read_text())['persistent_pond_successor_20261016']

def verify_source(git_reader=None):
    if (ROOT/'tests/nut-sol/verify_dynamic_pond_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_dynamic_pond_successor as dynamic
        return dynamic.verify_source(git_reader)
    g = git if git_reader is None else git_reader
    r = record()
    check(r['baseline'] == BASE, 'wrong pond baseline')
    g('merge-base', '--is-ancestor', BASE, 'HEAD')
    check(not g('status', '--porcelain', '--', *SURFACE), 'dirty pond inputs')
    rows = {s.split('\t')[1]: s.split('\t')[0] for s in g('diff', '--name-status', BASE, 'HEAD', '--', *SURFACE).splitlines()}
    check(rows == {p:v['status'] for p,v in r['postimages'].items()}, 'foreign pond scientific delta')
    check({p for p in rows if p.startswith('src/')} == PRODUCTION, 'pond production scope changed')
    for p,v in r['postimages'].items():
        check(g('rev-parse', 'HEAD:'+p) == v['blob'] == blob((ROOT/p).read_bytes()), 'pond postimage drift '+p)
    check(g('rev-parse', 'HEAD:src') == r['source_tree'], 'pond source tree drift')
    check(g('rev-parse', 'HEAD:reference') == g('rev-parse', BASE+':reference'), 'pond reference drift')
    flags={n:True for n in ('persistent_surface_restart_successor','material_root_irrigation_successor','b111_request_successor','managed_irrigation_successor',
        'nfix_component_preserved','hyd_successor','daily_density_successor','int12c_successor','co2_successor',
        'swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor')}
    return dict(baseline=BASE, source_tree=r['source_tree'], current_source_tree=r['source_tree'],
                pond_successor=True, qualified=False, admitted=False, **flags)

def evidence():
    d = record()['science_archive']
    raw = base64.b64decode((ROOT/d['path']).read_bytes())
    check(sha(raw) == d['decoded_sha256'], 'pond capsule drift')
    with tarfile.open(fileobj=io.BytesIO(raw), mode='r:xz') as a:
        ms = a.getmembers()
        check(len(ms) == len({m.name for m in ms}), 'duplicate pond members')
        check(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms), 'unsafe pond member')
        data = {m.name:a.extractfile(m).read() for m in ms}
    manifest = json.loads(data.pop('MANIFEST.json'))
    check(set(manifest) == set(data), 'incomplete pond archive')
    for p,h in manifest.items():
        check(sha(data[p]) == h, 'pond raw corruption '+p)
    return data

def validate_science(data):
    r = json.loads(data['final/result.json'])
    events = json.loads(data['final/events.json'])
    leaf = json.loads(data['leaf/result.json'])
    check(r['status'] == 'PHYSICAL_PASS_NOT_ADMITTED', 'unfinished pond composition')
    check(r['baseline'] == record()['execution_commit'], 'wrong pond execution')
    check(r['authority_sha256'] == '2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2', 'wrong pond authority')
    check(r['literal_lines'] == [[346,355],[361,432],[442,442],[455,455]], 'pond literal source changed')
    check(leaf['status'] == 'LEAF_PASS_NOT_RUNTIME_ADMISSION' and leaf['providers'] == 2, 'unfinished pond leaf')
    for dataset in (r, leaf):
        for p,h in dataset['input_sha256'].items():
            check(not Path(p).is_absolute() and '..' not in Path(p).parts, 'unsafe pond input')
            check(sha((ROOT/p).read_bytes()) == h, 'stale pond executed input '+p)
    check(PRODUCTION <= r['input_sha256'].keys(), 'untested pond production')
    for opt in ('O0', 'O2'):
        row = r['runs'][opt]
        check('POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in row['physical_stdout'], 'missing wet pond science')
        check('POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in row['dry_stdout'], 'missing dry pond science')
        for key in ('physical_stdout', 'dry_stdout'):
            check(row[key].count('POND_ACTUAL_LITERAL_TWENTYONE_NEGATIVES_REPLAY=PASS') == 2, 'incomplete pond negatives')
        for stem,key in (('expected', 'endpoint_sha256'), ('dry-expected', 'dry_endpoint_sha256')):
            check(sha(data['final/'+opt+'/'+stem+'.bin']) == row[key], 'pond endpoint drift')
        check(data['final/'+opt+'/expected.bin'] == data['final/'+opt+'/fresh.bin'], 'wet fresh process mismatch')
        check(data['final/'+opt+'/dry-expected.bin'] == data['final/'+opt+'/dry-fresh.bin'], 'dry fresh process mismatch')
        check(row['original_surface_endpoint'] == '7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e', 'admitted surface changed')
        check('SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS' in row['original_surface_stdout'], 'incumbent surface not executed')
        check(len(row['restart_negatives']) == 15, 'pond decoder coverage missing')
        native = [e for e in events if e['category']=='physical_native' and '/'+opt+'/' in e['command'][0]]
        check(len(native) == 19, 'pond native command coverage missing')
        check([e['command'][1] for e in native[:4]] == ['write','resume','write','resume'], 'pond fresh process commands missing')
        for e in native[:4]:
            check(b'POND_JOINT_ACTUAL_BALANCE_RESTART=PASS' in data['final/'+e['stdout']], 'pond native assertions missing')
        for e in native[4:]:
            check(b'POND_JOINT_INVALID_FILE=PASS' in data['final/'+e['stdout']], 'pond decoder negative missing')
        compiles = [e for e in events if e['category']=='physical_compile' and '-'+opt in e['command']]
        check(len(compiles) == row['physical_provider_count']+1, 'pond compilation incomplete')
        for p in PRODUCTION:
            check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p) for e in compiles)==1, 'pond provider not compiled '+p)
        old = [e for e in events if e['category']=='preservation_native' and '/'+opt+'/' in e['command'][0]]
        check(len(old)==2, 'original surface native absent')
        check(b'SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS' in data['final/'+old[0]['stdout']], 'original surface assertions absent')
        check(b'SURFACE_JOINT_FRESH_PROCESS=PASS' in data['final/'+old[1]['stdout']], 'original surface fresh process absent')
    leaf_events=json.loads(data['leaf/events.json'])
    leaf_native=[e for e in leaf_events if e['category']=='native']
    check(len(leaf_native)==2, 'pond leaf execution absent')
    for e in leaf_native:
        check(data['leaf/'+e['stdout']].decode()==leaf['stdout'], 'pond leaf raw assertions missing')
    # The optional extension must leave the complete old native file identical.
    predecessor=json.loads((ROOT/STATUS).read_text())['canonical_composition']['evidence']
    oldraw=base64.b64decode((ROOT/predecessor['path']).read_bytes())
    check(sha(oldraw)=='fc1e8bc4d5c9d9ea70e57ef7df1d2175c04e4615ab128cb3a35a76a3019f08fb','old surface native authority drift')
    with tarfile.open(fileobj=io.BytesIO(oldraw),mode='r:xz') as old:
        for opt in ('O0','O2'):
            check(data['final/'+opt+'/old-restart.bin']==old.extractfile('stable/'+opt+'/restart.bin').read(),'old native file changed')
    for prefix,items in [('final',events),('leaf',json.loads(data['leaf/events.json']))]:
        for e in items:
            check(e.get('returncode',e.get('exit'))==0, 'failed pond execution')
            check(e['seconds']>=0, 'unmeasured pond execution')
            for stream in ('stdout','stderr'):
                check(prefix+'/'+e[stream] in data, 'pond raw event missing')
            if '-c' in e['command']:
                check('-fcheck=all' in e['command'] and '-ffpe-trap=invalid,zero,overflow' in e['command'], 'pond runtime checks removed')
    for key in ('endpoint_sha256','dry_endpoint_sha256','original_surface_endpoint'):
        check(r['runs']['O0'][key] == r['runs']['O2'][key], 'pond O0/O2 drift')
    check('PERSISTENT_POND_LITERAL_240_DRY_REWET_BALANCE_REPLAY_RESTORE_NEGATIVES=PASS' in leaf['stdout'], 'pond leaf assertions absent')
    # Review exact shared observation/codec patches; old source bodies remain pinned.
    patches = json.loads(data['review/modified_patches.json'])
    shared = {p for p,v in record()['postimages'].items() if v['status']=='M'}
    check(set(patches) == shared, 'shared pond review incomplete')
    for p,patch in patches.items():
        actual = subprocess.check_output(['git','diff',BASE,'HEAD','--',p],cwd=ROOT)
        check(actual.decode()==patch, 'unreviewed shared pond change '+p)
    projections=json.loads(data['review/default_projections.json'])
    check(set(projections)==shared,'default body review incomplete')
    for p,patches in projections.items():
        lines=(ROOT/p).read_text().splitlines(True)
        for q in reversed(patches):
            a,b=q['range']
            check(lines[a:b]==q['inserted'],'changed default source island')
            lines[a:b]=[]
        check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'incumbent assertions/body changed '+p)
    return {'leaf_literal_cases':240, 'physical_native_programs':38, 'original_surface_programs':4,
            'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS', 'general_variable_pond_level':False}

@lru_cache(None)
def incumbent():
    root = ROOT.parent/('pond-incumbent-'+BASE[:12])
    if not root.exists():
        subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
    check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE, 'pond incumbent moved')
    check(not subprocess.check_output(['git','status','--porcelain','-uno'],cwd=root,text=True).strip(), 'pond incumbent dirty')
    p = subprocess.run([sys.executable,'-B','tests/mc-irr01/verify_material_root_successor.py'],cwd=root,capture_output=True,text=True)
    check(p.returncode==0, 'actual incumbent owner rejected '+p.stderr[-1200:])
    r = json.loads(p.stdout)
    check(r['qualified'] and r['material_root_irrigation_successor'], 'incumbent owner incomplete')
    return r

def verify_qualification():
    if (ROOT/'tests/nut-sol/verify_dynamic_pond_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/nut-sol'));import verify_dynamic_pond_successor as dynamic
        return dynamic.verify_qualification()
    s = verify_source()
    check(record()['stage'] in ('SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED','CANONICALLY_ADMITTED_BOUNDED'), 'pond science not ready')
    science = validate_science(evidence())
    old = incumbent()
    return {**old, **s, 'qualified':True, 'incumbent':old, 'science':science, 'scope':record()['scope'],
            'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS', 'highest_low_air':'NOT_SELECTED_POLICY'}

if __name__=='__main__':
    print(json.dumps(verify_source() if '--source-only' in sys.argv else verify_qualification(),indent=2))
