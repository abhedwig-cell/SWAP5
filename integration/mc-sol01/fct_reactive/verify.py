"""Independent finite-volume equations, analytical mode, raw and source gates."""
import argparse,base64,hashlib,io,itertools,json,math,runpy,tarfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def process(raw,args):
    mode,exponent,steps=args;dt=1/steps;lines=raw.decode().splitlines()
    h=lines[0].split();assert h[0]=='PROCESS_PASS' and [int(x) for x in h[1:3]]==[mode,steps]
    assert [float(x) for x in h[3:]]==[exponent,dt]
    assert lines[-1]=='EXACT_OFF_ZERO_PROCESS_DELEGATION_AND_NEGATIVE_RATE_REJECTION_PASS'
    budget=np.array([float(x) for x in lines[1].split()[1:]]);assert lines[1].startswith('BUDGET ') and len(budget)==6
    assert np.isfinite(budget).all() and min(budget)>=0 and budget[-1]<1e-10
    cells=[l.split() for l in lines[2:-1]];assert len(cells)==16 and [int(v[1]) for v in cells]==list(range(1,17))
    p=np.array([[float(x) for x in v[2:]] for v in cells]);assert p.shape==(16,5) and np.isfinite(p).all()
    before,c,m,s,delta=p.T;assert min(before)>=0 and min(c)>=0 and min(m)>=0 and min(s)>=0
    assert max(abs(m-.3*c))<1e-13 and max(abs(s-.26*c**exponent))<1e-12
    balance=abs(sum(m+s)-budget[0]-budget[1]+budget[2]);assert balance<1e-10
    assert budget[2]>=budget[3] and abs(sum(delta))<1e-12
    residual=0.;mode_error=None
    if mode>0:
        q=.15 if mode==2 else 0.
        conductance=.2*.3**3.33/.423**2+(.25*q if mode==2 else 0.)
        faces=np.r_[q*.05,q*c[:-1]+conductance*(c[:-1]-c[1:]),q*c[-1]]
        rhs=.3*before+.26*before**exponent+delta
        equation=(1+dt*.1)*(.3*c+.26*c**exponent)-rhs-dt*(faces[:-1]-faces[1:])
        residual=float(max(abs(equation)));assert residual<1e-11,('independent equation',args,residual)
        assert min(rhs)>=0 and budget[3]>0
        if mode==2:assert budget[4]>1e-8
        if mode==1 and exponent==1.:
            wave=np.cos(np.pi*(np.arange(16)+.5)/16)
            eigen=4*conductance/(.3+.26)*math.sin(math.pi/32)**2
            discrete=.5/(1+dt*.1)**steps+.2*wave/(1+dt*(.1+eigen))**steps
            assert max(abs(c-discrete))<1e-12,('analytical discrete mode',args)
            continuum=.5*math.exp(-.1)+.2*wave*math.exp(-(.1+eigen))
            mode_error=float(max(abs(c-continuum)))
    return dict(balance=balance,equation_residual=residual,mode_error=mode_error)
def assess(files,process_only=False):
    labels=json.loads(files['ROUNDS.json']);latest=labels[-1]
    for label in labels:
        r=json.loads(files[label+'/execution.json']);raw=files[label+'/checkpoint.raw']
        assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==r['baseline']
        for p,h in r['inputs'].items():
            assert sha(files[label+'/source/'+p])==h
            if label==latest:assert sha((ROOT/p).read_bytes())==h,('current input',p)
        for name,h in r['generated'].items():assert sha(files[label+'/'+name])==h
        for e in r['events']:
            for s in ['stdout','stderr']:assert sha(files[label+'/'+e[s]])==e[s+'_sha256']
        if label==latest:assert r['status']==('PROCESS_EXECUTED' if process_only else 'EXECUTED') and all(e['returncode']==0 for e in r['events'])
    r=json.loads(files[latest+'/execution.json']);g=runpy.run_path(str(HERE/'generate.py'))
    for name,b in g['sources']().items():assert files[latest+'/'+name]==b,('generated transformation',name)
    assert not r['production_activated'] and not r['disk_restart_qualified']
    assert len(r['closures']['process'])==10 and len(r['closures']['joint'])==175
    for e in r['events']:
        if '-fcheck=all' in e['command']:
            assert '-ffpe-trap=invalid,zero,overflow' in e['command'] and '-fopenmp' in e['command']
            category='process' if '/process-' in e['command'][-1] else 'joint'
            actual=[p for p in e['command'] if p.endswith('.f90')];assert actual==r['closures'][category]
    profiles={};worst=equation=drift=0.;errors={}
    for case in r['process_cases']:
        key=(case['optimization'],*case['arguments']);assert key not in profiles
        raw=files[latest+'/'+case['stdout']];result=process(raw,case['arguments']);profiles[key]=raw
        worst=max(worst,result['balance']);equation=max(equation,result['equation_residual'])
        if key[:3]==('O2',1,1.):errors[key[-1]]=result['mode_error']
    expected={tuple([o,*a]) for o in ['O0','O2'] for a in [*itertools.product([0,1,2],[.5,1.,2.],[4]),*[(1,1.,s) for s in [8,16,32]]]}
    assert set(profiles)==expected
    def numeric(raw):
        return np.array([float(x) for line in raw.decode().splitlines()[:-1] for x in line.split()[1:]])
    for key,raw in profiles.items():
        if key[0]=='O0':
            difference=float(max(abs(numeric(raw)-numeric(profiles[('O2',*key[1:])]))));assert difference<1e-12
            drift=max(drift,difference)
    assert set(errors)=={4,8,16,32}
    for a,b in [(4,8),(8,16),(16,32)]:assert .45<errors[b]/errors[a]<.55
    joint={};accepted=decayed=0.
    if not process_only:
        for case in r['joint_cases']:
            opt=case['optimization'];n,factor,exponent=case['arguments'];key=(opt,n,factor,exponent);assert key not in joint
            raw=files[latest+'/'+case['stdout']];lines=raw.decode().splitlines()
            assert lines[-1]=='LATE_CHEMICAL_WATER_REJECTION_EXACT_RETRY_AND_OPAQUE_CHECKPOINT_PASS'
            windows=[l.split() for l in lines if l.startswith('WINDOW ')]
            assert len(windows)==4 and [int(v[1]) for v in windows]==[1,2,3,4]
            for w in windows:
                assert int(w[2])>1 and int(w[3])==int(w[2])-1
                v=list(map(float,w[4:]));assert len(v)==5 and all(math.isfinite(x) for x in v)
                assert v[0]>=0 and v[1]>=v[4]>0 and 0<=v[2]<1e-10 and abs(v[3])<1e-10
                decayed+=v[4]
            head=next(l.split() for l in lines if l.startswith('JOINT_PASS '))
            assert list(map(int,head[1:4]))==[n,sum(int(w[2]) for w in windows),20]
            assert list(map(float,head[4:6]))==[factor,exponent] and 0<=float(head[6])<1e-10 and float(head[7])==.4
            budget=list(map(float,next(l.split()[1:] for l in lines if l.startswith('BUDGET '))))
            cells=[l.split() for l in lines if l.startswith('CELL ')];assert len(cells)==n
            p=np.array([list(map(float,v[2:])) for v in cells]);assert p.shape==(n,4) and np.isfinite(p).all() and p.min()>=0
            water,c,m,s=p.T;h=40/n
            assert max(abs(m-water*h*c))<1e-13 and max(abs(s-.26*h*c**exponent))<1e-12
            balance=abs(sum(m+s)-budget[0]-budget[1]+budget[2]);assert balance<1e-10
            assert max(c)<=max(.05+math.exp(-.5*((k-.5)*h-15)**2) for k in range(1,n+1))+1e-10
            worst=max(worst,balance,float(head[6]));accepted+=int(head[2]);joint[key]=raw
        assert set(joint)==set(itertools.product(['O0','O2'],[40,80],[.8,1.2],[.5,1.,2.]))
        for key,raw in joint.items():
            if key[0]=='O0':
                difference=float(max(abs(numeric(raw)-numeric(joint[('O2',*key[1:])]))));assert difference<1e-12
                drift=max(drift,difference)
    if not process_only:
        owner=json.loads(files['PRESERVATION.json']);assert owner['qualified'] and owner['controls']==134
    return dict(status='PROCESS_ORACLES_PASS' if process_only else 'REACTIVE_FCT_JOINT_O0_O2_QUALIFIED',
        process_cases=24,joint_cases=len(joint),primary_accepted_substeps=int(accepted),rejected_joint_trials=20*len(joint),
        max_mass_residual=worst,max_independent_equation_residual=equation,analytical_mode_errors={str(k):v for k,v in errors.items()},
        summed_decay_mg_cm2=decayed,max_O0_O2_numeric_difference=drift,production_activated=False,disk_restart_qualified=False,full_mc_sol01_closed=False)
def unpack(path,expected):
    raw=base64.b64decode(path.read_bytes());assert sha(raw)==expected
    with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as t:
        ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in ms)
        files={m.name:t.extractfile(m).read() for m in ms}
    manifest=json.loads(files.pop('MANIFEST.json'));assert manifest=={p:sha(b) for p,b in files.items()};return files
def controls(files):
    latest=json.loads(files['ROUNDS.json'])[-1];r=json.loads(files[latest+'/execution.json']);passed=[]
    def reject(name,fn):
        bad=dict(files);fn(bad)
        try:assess(bad)
        except(AssertionError,KeyError,ValueError):passed.append(name);return
        raise AssertionError('accepted '+name)
    for name in ['corrected_reactive.f90','reactive_trace.f90','joint_driver.f90']:
        reject('missing '+name,lambda f,name=name:f.pop(latest+'/'+name))
    case=r['process_cases'][0]
    def corrupt(f):
        p=latest+'/'+case['stdout'];lines=f[p].decode().splitlines();v=lines[2].split();v[4]='-1.0';lines[2]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
        rr=json.loads(f[latest+'/execution.json'])
        for e in [*rr['events'],*rr['process_cases']]:
            if e['stdout']==case['stdout']:e['stdout_sha256']=sha(f[p])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('negative mass with consistent stream hashes',corrupt)
    reject('changed production physics snapshot',lambda f:f.__setitem__(latest+'/source/src/process/mod_b111_reactive_solute_substep.f90',b'!'))
    reject('missing decay ledger',lambda f:f.__setitem__(latest+'/reactive_trace.f90',files[latest+'/reactive_trace.f90'].replace(b'account(5)=account(5)+r%decay_output_mg_cm2',b'account(5)=0d0')))
    analytical=next(c for c in r['process_cases'] if c['arguments']==[1,1.,8])
    def conservative_corruption(f):
        p=latest+'/'+analytical['stdout'];lines=f[p].decode().splitlines()
        for index,change in [(2,.001),(3,-.001)]:
            v=lines[index].split();c=float(v[3])+change
            v[3:6]=[str(c),str(.3*c),str(.26*c)];lines[index]=' '.join(v)
        f[p]=('\n'.join(lines)+'\n').encode();rr=json.loads(f[latest+'/execution.json'])
        for e in [*rr['events'],*rr['process_cases']]:
            if e['stdout']==analytical['stdout']:e['stdout_sha256']=sha(f[p])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('conservative equilibrium-preserving profile violates independent equation',conservative_corruption)
    reject('missing current composed owner',lambda f:f.pop('PRESERVATION.json'))
    return passed
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    i=json.loads((HERE/'EVIDENCE_INDEX.json').read_text());f=unpack(HERE/'EVIDENCE.tar.xz.b64',i['decoded_sha256']);result=assess(f)
    assert result==json.loads(f['VERIFICATION.json'])
    if a.self_test:result['controls']=controls(f)
    print(json.dumps(result,indent=2))
