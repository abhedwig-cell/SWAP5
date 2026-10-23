"""Exact default-OFF typed line-search successor; physical and FSI gates separate."""
import hashlib
import io
import json
from pathlib import Path
import runpy
import subprocess
import tarfile

ROOT=Path(__file__).resolve().parents[2]
BASE='17a6c17a478238e5fafc469aa275313bcdf2e184'
STATUS='benchmarks/performance/PERF01_LINE_SEARCH_RETRY_20261022_STATUS.json'
SELF='integration/performance/verify_weather_line_search_successor.py'
PARENT='integration/performance/verify_weather_composed_successor.py'
CHECKER='benchmarks/performance/verify_perf01_line_search_composition.py'
PROOF_SHA='bcf446368a5cc8a1cfe41deac4718bc3f66f05712abe05972a17446c2fd16f3d'
RUNNER='tests/fci/run_fci93_non_m1_fixed_k_qualification.sh'
SCIENCE=['src','app','tests','tools','reference','examples','.github','integration/audits','integration/performance','integration/diagnostics']
PRODUCTION={'src/adapter/mod_reference_richards_legacy_binding.f90',
    'src/legacy/b1_10_port/headcalc.f90','src/runtime/mod_fmr_serialized_reference_backend.f90',
    'src/solver/mod_soil_water_solver_contract.f90'}
sha=lambda raw:hashlib.sha256(raw).hexdigest()
def require(ok,why):
    if not ok:raise ValueError(why)
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record(reader=lambda p:(ROOT/p).read_bytes()):return json.loads(reader(STATUS))['source_successor']
def projection():
    text=subprocess.check_output(['git','show',BASE+':'+PARENT],cwd=ROOT,text=True)
    for name,args in [('source','reader, changed'),('verify',''),('self_test',''),('fsi35_successors','')]:
        at=text.index('\n',text.index('def '+name+'('))+1
        hook=("    if (ROOT/'"+STATUS+"').is_file() and 'postimages' in json.loads((ROOT/'"+STATUS+"').read_text()).get('source_successor', {}):\n"+
              "        return runpy.run_path(str(ROOT/'"+SELF+"'))['"+name+"']("+args+")\n")
        text=text[:at]+hook+text[at:]
    return text.encode()
def source(reader=lambda p:(ROOT/p).read_bytes(),changed=None):
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_fallow_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_fallow_output.py'))['retry_source'](reader,changed)
    r=record(reader);require(r['baseline']==BASE,'retry source baseline')
    git('merge-base','--is-ancestor',BASE,'HEAD')
    lines=git('diff','--name-status',BASE,'HEAD','--',*SCIENCE).splitlines()
    delta={line.split('\t')[1]:line.split('\t')[0]for line in lines}
    require(delta==r['source_delta'] and set(delta)==set(r['postimages']),'foreign retry source delta')
    require(set(delta)==PRODUCTION|{SELF,PARENT},'bounded retry provider surface')
    for p,h in {**r['source_inputs'],**r['postimages']}.items():require(sha(reader(p))==h,'retry input/postimage '+p)
    require(reader(PARENT)==projection(),'original composed owner assertion bodies changed')
    require(reader(RUNNER)==subprocess.check_output(['git','show',BASE+':'+RUNNER],cwd=ROOT),'original FSI35 runner changed')
    require(not git('status','--porcelain','--',*SCIENCE),'dirty retry scientific source')
    if changed is not None:
        for p in changed:
            if p not in delta:require(subprocess.run(['git','cat-file','-e',BASE+':'+p],cwd=ROOT,capture_output=True).returncode==0,'unknown caller path '+p)
    return json.loads(reader('integration/audits/MC_SOL01_DYNAMIC_DECAY_STATUS.json'))['swp_water_successor']
def fsi35_successors():
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_fallow_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_fallow_output.py'))['fsi35_successors']()
    source();rows={p:dict(v)for p,v in record()['frozen_fsi35_successors'].items()}
    for p,row in rows.items():
        if p in PRODUCTION:row['canonical_blob']=git('rev-parse','HEAD:'+p)
        require(row['canonical_blob']==git('rev-parse','HEAD:'+p),'stale FSI35 successor '+p)
    return rows
def capsule():
    r=record()['evidence'];raw=(ROOT/r['path']).read_bytes()
    require(sha(raw)==r['sha256']==PROOF_SHA and len(raw)==r['bytes'],'retry physical capsule identity')
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
        ms=t.getmembers();require(len(ms)==r['members']==len({m.name for m in ms}),'retry physical census')
        require(all(m.isfile() and not Path(m.name).is_absolute() and '..'not in Path(m.name).parts for m in ms),'unsafe retry member')
        return {m.name:t.extractfile(m).read()for m in ms}
def verify():
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_fallow_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_fallow_output.py'))['verify']()
    source();files=capsule();science=runpy.run_path(str(ROOT/CHECKER))['verify'](files)
    frozen=json.loads(files['frozen-canonical-owner.json'])
    require(frozen['qualified'] and frozen['current_source_tree']==git('rev-parse',BASE+':src') and
            frozen['current_harvest_output']['qualified'] and frozen['current_saved_output']['qualified'],'complete exact predecessor authority')
    require(len(json.loads(files['frozen-canonical-controls.json']))==34,'complete predecessor controls')
    native=record().get('native_fsi35')
    if native:
        raw=(ROOT/native['receipt']).read_bytes();require(sha(raw)==native['sha256'],'fresh FSI35 receipt identity')
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz')as t:
            terminal=json.loads(t.extractfile('RESULT.json').read());stdout=t.extractfile('stdout').read()
            require(terminal['status']=='PASS' and terminal['returncode']==0 and
                    sha(stdout)==terminal['raw_sha256']['stdout'] and
                    b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS'in stdout,'fresh FSI35 native incomplete')
            for p,h in terminal['input_sha256'].items():require(sha((ROOT/p).read_bytes())==h,'fresh FSI35 input '+p)
    # Scientific/source qualification precedes the independently selected full
    # FSI35 runner. Admission requires its later terminal receipt explicitly.
    return {**frozen,'current_source_tree':git('rev-parse','HEAD:src'),'source_tree':git('rev-parse','HEAD:src'),
        'qualified':True,'qualification_scope':'BOUNDED_TYPED_WEATHER_LINE_SEARCH_AND_CURRENT_DEFAULT_PRESERVATION',
        'line_search_retry':science,'fsi35_native':'PASS'if native else'PENDING_SEPARATE_ORIGINAL_NATIVE_GATE',
        'canonically_admitted':False,'default_on':False}
def self_test():
    if 'postimages' in json.loads((ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json').read_text())['extended_output_component_20261021'].get('thermal_fallow_successor_20261022',{}):return __import__('runpy').run_path(str(ROOT/'integration/audits/verify_nut_thermal_fallow_output.py'))['self_test']()
    controls=[]
    for p in set(record()['postimages'])|{'src/crop/mod_crop_soil_n_day.f90',RUNNER}:
        try:source(lambda q:(ROOT/q).read_bytes()+(b'!'if q==p else b''))
        except(ValueError,KeyError):controls.append('source:'+p)
        else:raise AssertionError('accepted source corruption '+p)
    try:source(changed={'src/foreign_line_search.f90':'A'})
    except ValueError:controls.append('foreign scientific source')
    else:raise AssertionError('accepted foreign source')
    files=capsule();checker=runpy.run_path(str(ROOT/CHECKER))
    for p in ['on-season-O2-4x/native/stdout','season-O0-4x/native/stdout',
              'root-substep-transaction/0001.stdout','nut-owner/thermal/O2/output.restart.environment-after',
              'saved-owner/physical/O2/deferred-continue-3.day-4','on-restart-native/stdout']:
        bad=dict(files);bad.pop(p)
        try:checker['verify'](bad)
        except(ValueError,KeyError,AssertionError):controls.append('missing:'+p)
        else:raise AssertionError('accepted incomplete proof '+p)
    return controls
if __name__=='__main__':
    import sys
    print(json.dumps(self_test()if'--self-test'in sys.argv else verify(),indent=2))
