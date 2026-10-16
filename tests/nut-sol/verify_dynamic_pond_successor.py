"""Bounded evolving hydraulic pond with the existing chemical owner and codec."""
from pathlib import Path
from functools import lru_cache
import base64, hashlib, io, json, subprocess, sys, tarfile
sys.dont_write_bytecode=True
ROOT=Path(__file__).resolve().parents[2]
BASE='93c4cb62f0a6c0dbe8bf47b6eeeef0752c39d694'
STATUS='integration/audits/MC_SOL01_SURFACE_INPUT_STATUS.json'
SURFACE=['src','tests','tools','reference','.github']
PRODUCTION={'src/process/mod_pond_water_temporal_difference.f90','src/runtime/mod_fmr_serialized_reference_backend.f90','src/runtime/mod_fmr_b111_pond_joint_application.f90'}
def check(ok,label):
    if not ok:raise ValueError(label)
def sha(raw):return hashlib.sha256(raw).hexdigest()
def blob(raw):return hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def record():return json.loads((ROOT/STATUS).read_text())['dynamic_pond_successor_20261016']
def verify_source(git_reader=None):
    if (ROOT/'tests/nut-crop/verify_reproductive_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/nut-crop'));import verify_reproductive_successor as reproductive
        return reproductive.verify_source(git_reader)
    g=git if git_reader is None else git_reader;r=record()
    check(r['baseline']==BASE,'wrong dynamic pond baseline');g('merge-base','--is-ancestor',BASE,'HEAD')
    check(not g('status','--porcelain','--',*SURFACE),'dirty dynamic pond inputs')
    rows={s.split('\t')[1]:s.split('\t')[0]for s in g('diff','--name-status',BASE,'HEAD','--',*SURFACE).splitlines()}
    check(rows=={p:v['status']for p,v in r['postimages'].items()},'foreign dynamic pond science')
    check({p for p in rows if p.startswith('src/')}==PRODUCTION,'dynamic pond production scope')
    for p,v in r['postimages'].items():check(g('rev-parse','HEAD:'+p)==v['blob']==blob((ROOT/p).read_bytes()),'dynamic pond postimage '+p)
    check(g('rev-parse','HEAD:src')==r['source_tree'],'dynamic pond source tree')
    check(g('rev-parse','HEAD:reference')==g('rev-parse',BASE+':reference'),'dynamic pond reference drift')
    flags={n:True for n in ('pond_successor','dynamic_pond_successor','persistent_surface_restart_successor','material_root_irrigation_successor',
        'b111_request_successor','managed_irrigation_successor','nfix_component_preserved','hyd_successor','daily_density_successor',
        'int12c_successor','co2_successor','swrd3_successor','swrd2_successor','harvest_successor','surface_successor','calendar_successor','input_successor','thermal_successor')}
    return dict(baseline=BASE,source_tree=r['source_tree'],current_source_tree=r['source_tree'],qualified=False,admitted=False,**flags)
def capsule(d):
    raw=base64.b64decode((ROOT/d['path']).read_bytes());check(sha(raw)==d['decoded_sha256'],'dynamic capsule drift')
    with tarfile.open(fileobj=io.BytesIO(raw))as a:
        ms=a.getmembers();check(len(ms)==len({m.name for m in ms}),'duplicate dynamic member')
        check(all(m.isfile()and not Path(m.name).is_absolute()and '..'not in Path(m.name).parts for m in ms),'unsafe dynamic member')
        data={m.name:a.extractfile(m).read()for m in ms}
    manifest=json.loads(data.pop('MANIFEST.json'));check(set(data)==set(manifest),'incomplete dynamic capsule')
    for p,h in manifest.items():check(sha(data[p])==h,'corrupt dynamic member '+p)
    return data
def evidence():return capsule(record()['science_archive'])
def validate_science(data):
    r=json.loads(data['final/result.json']);events=json.loads(data['final/events.json'])
    check(r['status']=='PHYSICAL_PASS_NOT_ADMITTED','unfinished dynamic physics')
    check(r['baseline']==record()['execution_commit'],'wrong dynamic execution')
    check(r['authority_sha256']=='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2','dynamic authority drift')
    check(r['literal_lines']==[[346,355],[361,432],[442,442],[455,455]],'dynamic literal source drift')
    check(PRODUCTION<=r['input_sha256'].keys(),'dynamic providers not tested')
    for p,h in r['input_sha256'].items():
        check(not Path(p).is_absolute()and '..'not in Path(p).parts,'unsafe dynamic input')
        check(sha((ROOT/p).read_bytes())==h,'stale dynamic input '+p)
    leaf=json.loads(data['leaf/result.json']);le=json.loads(data['leaf/events.json'])
    check(leaf['status']=='LEAF_PASS_NOT_RUNTIME_ADMISSION'and leaf['cases_per_opt']==23,'unfinished temporal leaf')
    for p,h in leaf['input_sha256'].items():check(sha((ROOT/p).read_bytes())==h,'stale temporal leaf '+p)
    check(len(le)==6 and len([e for e in le if '-c'not in e['command']and len(e['command'])==1])==2,'temporal leaf command coverage')
    for e in le:
        check(e['returncode']==0 and e['seconds']>=0,'failed temporal leaf event')
        for stream in ('stdout','stderr'):check('leaf/'+e[stream]in data,'missing temporal raw event')
        if len(e['command'])==1:check(b'POND_WATER_TEMPORAL_23_COMPARISONS=PASS'in data['leaf/'+e['stdout']],'temporal leaf native absent')
    oldrec=json.loads((ROOT/STATUS).read_text())['persistent_pond_successor_20261016']
    old=capsule(oldrec['science_archive'])
    for opt in ('O0','O2'):
        row=r['runs'][opt]
        for key in ('physical_stdout','dry_stdout','fill_stdout'):
            check('DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS'in row[key],'missing dynamic scenario '+key)
            check(row[key].count('POND_ACTUAL_LITERAL_TWENTYONE_NEGATIVES_REPLAY=PASS')==2,'dynamic scientific negatives missing')
            check('DYNAMIC_POND_EIGHT_FORCING_REJECTIONS=PASS'in row[key],'dynamic forcing rejection absent')
        for key in ('physical_stdout','fill_stdout'):
            check('DYNAMIC_POND_ZERO_TOLERANCE_REJECTED=PASS'in row[key],'temporal policy rejection absent')
        for stem,key in [('expected','endpoint_sha256'),('dry-expected','dry_endpoint_sha256'),('fill-expected','fill_endpoint_sha256')]:
            check(sha(data['final/'+opt+'/'+stem+'.bin'])==row[key],'dynamic endpoint drift')
        for prefix in ('','dry-','fill-'):
            check(data['final/'+opt+'/'+prefix+'expected.bin']==data['final/'+opt+'/'+prefix+'fresh.bin'],'dynamic fresh process mismatch')
        for variant,stem in [('wet','expected'),('dry','dry-expected')]:
            check(data['final/'+opt+'/'+variant+'-incumbent-expected.bin']==old['final/'+opt+'/'+stem+'.bin'],'admitted1257 endpoint changed')
            check(data['final/'+opt+'/'+variant+'-incumbent-expected.bin']==data['final/'+opt+'/'+variant+'-incumbent-fresh.bin'],'1257 fresh continuation changed')
            check(data['final/'+opt+'/'+variant+'-incumbent.bin']==old['final/'+opt+'/'+('restart'if variant=='wet'else'dry-restart')+'.bin'],'1257 native codec drift')
        check(row['original_surface_endpoint']=='7927b66f0ccf253d00795dd6c174a8323ac6e06d5bd6d384248e9bb0e7331d9e','old surface endpoint drift')
        check(data['final/'+opt+'/old-restart.bin']==old['final/'+opt+'/old-restart.bin'],'original V1 native changed')
        check(len(row['restart_negatives'])==15,'dynamic decoder coverage missing')
        native=[e for e in events if e['category']=='physical_native'and '/'+opt+'/'in e['command'][0]]
        check(len(native)==21,'dynamic native commands missing')
        for i,e in enumerate(native):
            marker=b'DYNAMIC_POND_JOINT_ACTUAL_BALANCE_RESTART=PASS'if i<6 else b'POND_JOINT_INVALID_FILE=PASS'
            check(marker in data['final/'+e['stdout']],'dynamic raw native assertion absent')
        oldnative=[e for e in events if e['category']=='preservation_native'and '/'+opt+'/'in e['command'][0]]
        check(len(oldnative)==6,'admitted native preservation missing')
        for e in oldnative[:4]:check(b'POND_JOINT_ACTUAL_BALANCE_RESTART=PASS'in data['final/'+e['stdout']],'1257 native assertions absent')
        check(b'SURFACE_JOINT_ATOMIC_BALANCE_LITERAL_RESTART=PASS'in data['final/'+oldnative[4]['stdout']],'old surface not executed')
        check(b'SURFACE_JOINT_FRESH_PROCESS=PASS'in data['final/'+oldnative[5]['stdout']],'old surface resume missing')
        compiles=[e for e in events if e['category']=='physical_compile'and '-'+opt in e['command']]
        check(len(compiles)==row['physical_provider_count']+1,'dynamic compile closure missing')
        for p in PRODUCTION:check(sum(str(e['command'][e['command'].index('-c')+1]).endswith('/'+p)for e in compiles)==1,'dynamic provider compile missing')
    for e in events:
        check(e['returncode']==0 and e['seconds']>=0,'failed dynamic event')
        for stream in ('stdout','stderr'):check('final/'+e[stream]in data,'missing dynamic raw event')
        if '-c'in e['command']:check('-fcheck=all'in e['command']and '-ffpe-trap=invalid,zero,overflow'in e['command'],'dynamic checks removed')
    for key in ('endpoint_sha256','dry_endpoint_sha256','fill_endpoint_sha256','original_surface_endpoint'):
        check(r['runs']['O0'][key]==r['runs']['O2'][key],'dynamic O0/O2 drift')
    projections=json.loads(data['review/insertions.json'])
    shared={p for p,v in record()['postimages'].items()if v['status']=='M'}
    check(set(projections)==shared,'dynamic default projection missing')
    for p,insertions in projections.items():
        lines=(ROOT/p).read_text().splitlines(True)
        for q in reversed(insertions):
            a,b=q['range'];check(lines[a:b]==q['inserted'],'changed dynamic island');lines[a:b]=[]
        check(''.join(lines).encode()==subprocess.check_output(['git','show',BASE+':'+p],cwd=ROOT),'changed incumbent source body '+p)
    return dict(dynamic_native_programs=42,incumbent_native_programs=12,actual_variable_pond=True,evaporation_runoff=False)
@lru_cache(None)
def incumbent():
    root=ROOT.parent/('dynamic-pond-incumbent-'+BASE[:12])
    if not root.exists():subprocess.run(['git','worktree','add','--detach',str(root),BASE],cwd=ROOT,check=True,capture_output=True)
    check(subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()==BASE,'dynamic incumbent moved')
    check(not subprocess.check_output(['git','status','--porcelain','-uno'],cwd=root,text=True).strip(),'dynamic incumbent dirty')
    p=subprocess.run([sys.executable,'-B','tests/nut-sol/verify_pond_successor.py'],cwd=root,capture_output=True,text=True)
    check(p.returncode==0,'actual1257 owner rejected '+p.stderr[-1000:]);r=json.loads(p.stdout)
    check(r['qualified']and r['pond_successor'],'1257 incumbent incomplete');return r

def verify_qualification():
    if (ROOT/'tests/nut-crop/verify_reproductive_successor.py').exists():
        sys.path.insert(0,str(ROOT/'tests/nut-crop'));import verify_reproductive_successor as reproductive
        return reproductive.verify_qualification()
    s=verify_source();check(record()['stage']in ('SCIENCE_COMPLETE_ADMISSION_PENDING','QUALIFIED_BOUNDED_NOT_ADMITTED','CANONICALLY_ADMITTED_BOUNDED'),'dynamic science not ready')
    science=validate_science(evidence());old=incumbent()
    return {**old,**s,'qualified':True,'incumbent':old,'science':science,'full_fci':'NOT_SELECTED_AFFECTED_CONTRACTS','highest_low_air':'NOT_SELECTED_POLICY'}
if __name__=='__main__':print(json.dumps(verify_source()if'--source-only'in sys.argv else verify_qualification(),indent=2))
