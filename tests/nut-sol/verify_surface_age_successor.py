"""Bounded Reference surface-age successor. Exact source and executed evidence."""
from pathlib import Path
import base64,hashlib,io,json,subprocess,tarfile
ROOT=Path(__file__).resolve().parents[2]
STATUS='integration/audits/MC_SOL01_SURFACE_AGE01_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
def check(ok,label):
    if not ok: raise ValueError(label)
def sha(b):return hashlib.sha256(b).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())
def ci_successor():
    if not (ROOT/'integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json').exists():return None
    # run_path does not create a bytecode cache inside a source guard.
    import runpy
    return runpy.run_path(str(ROOT/'integration/audits/surface_age_ci/authority.py'),run_name='ci_source_authority')
def verify_source():
    s=record();base=s['baseline']
    ci=ci_successor()
    if ci is not None:ci['verify_source']()
    # A registered, freshly qualified NUT successor may change its own
    # source surface while preserving every age physical input and postimage.
    nut_path=ROOT/'integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json'
    if nut_path.exists():
        g=json.loads(nut_path.read_text()).get('historical_guard',{})
        coexist=g.get('surface_age_coexistence',{})
        if g.get('humus_experiment') and coexist.get('status_sha256')==sha((ROOT/STATUS).read_bytes()):
            import sys
            sys.path.insert(0,str(ROOT/'tests/nut-crop'))
            import verify_hist_native_successor as hist
            hist.verify_source()
            return dict(surface_age_successor=True,full_capability=False,qualified=False,
                        current_source_tree=git('rev-parse','HEAD:src'),nut_coexistence=True)
    git('merge-base','--is-ancestor',base,'HEAD')
    check(not git('status','--porcelain','--',*SURFACE),'dirty surface-age dependency surface')
    rows={r.split('\t')[1]:r.split('\t')[0] for r in git('diff','--name-status',base,'HEAD','--',*SURFACE).splitlines()}
    expected=dict(s['postimages']);ci=ci_successor()
    if ci is not None:
        ci['verify_source']()
        for p,v in ci['record']()['postimages'].items():
            if p.split('/')[0]in SURFACE:
                expected[p]={**v,'status':expected.get(p,v)['status']}
    check(rows=={p:v['status'] for p,v in expected.items()},'foreign surface-age delta')
    for p,v in expected.items():
        check(sha((ROOT/p).read_bytes())==v['sha256'],'unqualified surface-age postimage '+p)
    check(not git('diff',base,'HEAD','--','reference'),'historical reference mutation')
    return dict(surface_age_successor=True,full_capability=False,qualified=False,current_source_tree=git('rev-parse','HEAD:src'))
def evidence():
    e=record()['evidence'];raw=base64.b64decode((ROOT/e['path']).read_bytes())
    check(sha(raw)==e['decoded_sha256'],'surface-age archive integrity')
    with tarfile.open(fileobj=io.BytesIO(raw)) as t:
        members=t.getmembers()
        check(all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members),'unsafe surface-age archive')
        check(len(members)==len({m.name for m in members}),'duplicate surface-age members')
        files={m.name:t.extractfile(m).read() for m in members}
    manifest=json.loads(files.pop('MANIFEST.json'))
    check(set(manifest)==set(files),'surface-age archive inventory')
    for p,h in manifest.items():check(sha(files[p])==h,'surface-age evidence corruption '+p)
    return files
def validate(files,reader=lambda p:(ROOT/p).read_bytes()):
    r=json.loads(files['physical/result.json']);events=json.loads(files['physical/events.json'])
    check(r['baseline']==record()['execution_commit'],'unbound surface-age execution')
    check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished physical surface-age execution')
    check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','historical age oracle drift')
    for p,h in r['input_sha256'].items():check(sha(reader(p))==h,'stale executed surface-age input '+p)
    for e in events:
        check(e['returncode']==0 and e['seconds']>=0,'failed surface-age event')
        for stream in ['stdout','stderr']:check('physical/'+e[stream] in files,'missing raw surface-age event')
        c=e['command']
        if '-c' in c:
            check('-fcheck=all' in c and '-ffpe-trap=invalid,zero,overflow' in c,'unchecked surface-age compilation')
    for opt in ['O0','O2']:
        row=r['runs'][opt]
        check('AGE_LITERAL_150_STEPS_PRODUCTION_UNITS_BALANCE_INVALID_RETRY=PASS' in row['process_stdout'],'historical age process missing')
        text=row['surface']['stdout']
        check('SURFACE_AGE_REAL_REFERENCE_TRIPLET=PASS' in text and 'REJECTED_NUMERICAL_TRIAL' in text and 'ACTUAL_REFINEMENT_POND_CM_DAY' in text,'missing physical triplet/rejection/refinement')
        prefix='physical/'+opt+'/'
        check(files[prefix+'surface_expected.bin']==files[prefix+'surface_fresh.bin'],'fresh-process surface-age mismatch')
        check(sha(files[prefix+'surface_expected.bin'])==row['surface']['endpoint_sha256'],'surface endpoint digest')
        check(files[prefix+'expected.bin']==files[prefix+'fresh.bin']==files['incumbent/'+opt+'/expected.bin'],'incumbent age physical drift')
        check(set(row['surface']['snapshot_negatives'])=={'truncated','overlong','outer_crc','inner_crc'},'snapshot negatives missing')
        native=[e for e in events if e['category']=='surface_native' and '/'+opt+'/' in e['command'][0]]
        check(len(native)==6,'missing surface-age native executions')
        for e in native[2:]:check(b'SURFACE_AGE_INVALID_SNAPSHOT=PASS' in files['physical/'+e['stdout']],'snapshot rejection not executed')
    check(files['physical/O0/surface_expected.bin']==files['physical/O2/surface_expected.bin'],'optimization changes triplet')
    check(b'MC_SOL01_SURFACE_AGE_ANALYTIC_FIRST_ORDER=PASS' in files['isolated.stdout'],'analytic first-order proof missing')
    check(b'MC_SOL01_SURFACE_AGE_BUDGET_O2=PASS' in files['isolated.stdout'],'isolated O2 absent')
    return dict(physical_triplet=True,fresh_process=True,incumbent_age_preserved=True)
def verify_qualification():
    perf=ROOT/'integration/performance/authority.py'
    if perf.exists():
        import runpy
        return runpy.run_path(str(perf),run_name='registered_perf01_age')['verify_qualification']()
    ci=ci_successor()
    if ci is not None:ci['verify_qualification']()
    return {**verify_source(),**validate(evidence()),'qualified':True,'full_capability':False,'full_fci':'NOT_SELECTED_IMPACT','rossfast':'FROZEN_UNCHANGED'}
if __name__=='__main__':print(json.dumps(verify_qualification(),indent=2))
