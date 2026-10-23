"""Independent source/raw/budget checks, with adversarial evidence controls."""
import argparse,base64,hashlib,io,itertools,json,math,runpy,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def assess(files):
    labels=json.loads(files['ROUNDS.json']);latest=labels[-1];profiles={};worst=0.;steps=0
    for label in labels:
        r=json.loads(files[label+'/execution.json']);raw=files[label+'/checkpoint.raw']
        assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
        for p,h in r['inputs'].items():
            assert sha(files[label+'/source/'+p])==h
            if label==latest:assert sha((ROOT/p).read_bytes())==h,('current source',p)
        for p,h in r['generated'].items():assert sha(files[label+'/'+p])==h
        for e in r['events']:
            for s in ['stdout','stderr']:assert sha(files[label+'/'+e[s]])==e[s+'_sha256']
        if label==latest:
            assert r['status']=='EXECUTED' and all(e['returncode']==0 for e in r['events'])
        elif r['status']=='FAILED':assert r['events'][-1]['returncode']!=0
        else:assert r['status']=='EXECUTED'
    r=json.loads(files[latest+'/execution.json'])
    generation=runpy.run_path(str(HERE/'run.py'))
    assert files[latest+'/joint_driver.f90']==generation['generated_driver']()
    predecessor=runpy.run_path(str(HERE.parent/'fct_accepted_trace/qualify_replay.py'))
    assert files[latest+'/storage_successor.f90']==predecessor['storage_successor']()
    assert not r['production_activated'] and not r['disk_restart_qualified']
    builds=[e for e in r['events'] if '-fcheck=all' in e['command']]
    assert len(builds)==2 and r['provider_count']==172
    expected={p for p in r['inputs'] if p.endswith('.f90')}
    expected.remove('integration/mc-sol01/fct_accepted_trace/water_driver.f90')
    expected.remove(predecessor['STORAGE'])
    for opt,e in zip(['O0','O2'],builds):
        cmd=e['command'];assert '-'+opt in cmd and '-ffpe-trap=invalid,zero,overflow' in cmd and '-fopenmp' in cmd
        actual={str(Path(p).relative_to(ROOT)) for p in cmd if p.endswith('.f90') and Path(p).is_relative_to(ROOT)}
        assert actual==expected
        assert {Path(p).name for p in cmd if p.endswith('.f90') and not Path(p).is_relative_to(ROOT)}=={'joint_driver.f90','storage_successor.f90'}
    assert b'GNU Fortran' in files[latest+'/'+r['events'][0]['stdout']]
    expected_cases=set(itertools.product(['O0','O2'],[40,80],[.8,1.2],[.5,1.,2.]))
    for c in r['cases']:
        key=tuple(c[k] for k in ['optimization','n','factor','exponent']);assert key not in profiles
        assert {k:v for k,v in c.items() if k not in ['optimization','n','factor','exponent']} in r['events']
        raw=files[latest+'/'+c['stdout']];lines=raw.decode().splitlines()
        assert lines[-1]=='LATE_CHEMICAL_WATER_REJECTION_EXACT_RETRY_AND_OPAQUE_CHECKPOINT_PASS'
        windows=[l.split() for l in lines if l.startswith('WINDOW ')]
        assert len(windows)==4 and [int(w[1]) for w in windows]==[1,2,3,4]
        assert all(int(w[2])>1 and int(w[3])==int(w[2])-1 for w in windows)
        ledger=[[float(x) for x in w[4:]] for w in windows];assert all(len(v)==4 for v in ledger)
        assert all(math.isfinite(x) for v in ledger for x in v)
        assert all(min(v[:3])>=0 and max(abs(v[2]),abs(v[3]))<1e-10 for v in ledger)
        head=next(l.split() for l in lines if l.startswith('JOINT_PASS '))
        assert [int(x) for x in head[1:4]]==[c['n'],sum(int(w[2]) for w in windows),20]
        assert [float(x) for x in head[4:6]]==[c['factor'],c['exponent']]
        residual=float(head[6]);assert math.isfinite(residual) and 0<=residual<1e-10 and float(head[7])==.4
        budget=[float(x) for x in next(l.split()[1:] for l in lines if l.startswith('BUDGET '))]
        assert len(budget)==3 and all(math.isfinite(x) and x>=0 for x in budget)
        assert abs(sum(v[0] for v in ledger)-budget[1])<1e-14 and abs(sum(v[1] for v in ledger)-budget[2])<1e-14
        cells=[l.split() for l in lines if l.startswith('CELL ')];assert len(cells)==c['n']
        assert [int(v[1]) for v in cells]==list(range(1,c['n']+1))
        p=[[float(x) for x in v[2:]] for v in cells];assert all(len(v)==4 for v in p)
        assert all(math.isfinite(x) and x>=0 for v in p for x in v)
        h=40/c['n'];mass=sum(v[2]+v[3] for v in p)
        assert abs(mass-budget[0]-budget[1]+budget[2])<1e-10
        for water,concentration,mobile,sorbed in p:
            assert abs(mobile-water*h*concentration)<1e-13
            assert abs(sorbed-.26*h*concentration**c['exponent'])<1e-12
        initial_max=max(.05+math.exp(-.5*((k-.5)*h-15)**2) for k in range(1,c['n']+1))
        assert max(v[1] for v in p)<=initial_max+1e-10
        worst=max(worst,residual,abs(mass-budget[0]-budget[1]+budget[2]));steps+=int(head[2]);profiles[key]=raw
    assert set(profiles)==expected_cases
    for key,raw in profiles.items():
        if key[0]=='O0':assert raw==profiles[('O2',*key[1:])],('optimization drift',key)
    owner=json.loads(files['PRESERVATION.json']);assert owner['qualified'] and owner['controls']>0
    return dict(status='RESEARCH_JOINT_O0_O2_QUALIFIED',cases=24,accepted_substeps=steps,
        rejected_trials=480,late_chemical_rejections=96,exact_retries=96,checkpoint_continuations=48,
        provider_count=172,max_mass_residual=worst,optimization_outputs_byte_exact=True,
        production_activated=False,disk_restart_qualified=False,full_mc_sol01_closed=False)
def controls(files):
    latest=json.loads(files['ROUNDS.json'])[-1];r=json.loads(files[latest+'/execution.json']);c=r['cases'][0];passed=[]
    def reject(name,fn):
        bad=dict(files);fn(bad)
        try:assess(bad)
        except(AssertionError,KeyError,ValueError):passed.append(name);return
        raise AssertionError('accepted corruption '+name)
    reject('missing current driver',lambda f:f.pop(latest+'/joint_driver.f90'))
    reject('missing failed build',lambda f:f.pop('round2/001.stderr'))
    reject('changed current provider snapshot',lambda f:f.__setitem__(latest+'/source/src/kernel/mod_kernel_transactions.f90',b'!'))
    reject('missing public persistence proof',lambda f:f.__setitem__(latest+'/joint_driver.f90',files[latest+'/joint_driver.f90'].replace(b'call restore_kernel_committed_state',b'call fake_restore')))
    def alter(f,old,new):
        path=latest+'/'+c['stdout'];assert old in f[path];f[path]=f[path].replace(old,new,1)
        rr=json.loads(f[latest+'/execution.json'])
        for e in [*rr['events'],*rr['cases']]:
            if e['stdout']==c['stdout']:e['stdout_sha256']=sha(f[path])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('missing late rejection marker with consistent hashes',lambda f:alter(f,b'LATE_CHEMICAL_WATER_REJECTION',b'ABSENT'))
    def negative(f):
        line=next(l for l in f[latest+'/'+c['stdout']].splitlines() if l.startswith(b'CELL '))
        v=line.split();v[4]=b'-1.0';alter(f,line,b' '.join(v))
    reject('negative dissolved mass with consistent hashes',negative)
    reject('wrong surface option',lambda f:f.__setitem__(latest+'/storage_successor.f90',files[latest+'/storage_successor.f90'].replace(b'.true.',b'.false.',1)))
    reject('missing composed owner',lambda f:f.pop('PRESERVATION.json'))
    return passed
def unpack(path,expected):
    raw=base64.b64decode(path.read_bytes());assert sha(raw)==expected
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
        ms=t.getmembers();assert len(ms)==len({m.name for m in ms})
        assert all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
        f={m.name:t.extractfile(m).read() for m in ms}
    manifest=json.loads(f.pop('MANIFEST.json'));assert manifest=={p:sha(v) for p,v in f.items()};return f
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    index=json.loads((HERE/'EVIDENCE_INDEX.json').read_text());f=unpack(HERE/'EVIDENCE.tar.xz.b64',index['decoded_sha256'])
    result=assess(f);assert result==json.loads(f['VERIFICATION.json'])
    if a.self_test:result['controls']=controls(f)
    print(json.dumps(result,indent=2))
