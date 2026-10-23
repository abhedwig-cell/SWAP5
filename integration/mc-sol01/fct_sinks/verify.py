"""Independent storage/sink algebra, finite volumes, raw/source and state gates."""
import argparse,base64,hashlib,io,itertools,json,math,runpy,tarfile
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda b:hashlib.sha256(b).hexdigest()
def process(raw,args):
    mode,exponent,uptake,kind,steps=args;dt=1/steps
    lines=raw.decode().splitlines();head=lines[0].split()
    assert head[0]=='SINK_CASE' and list(map(int,head[1:4]))==[mode,kind,steps]
    assert list(map(float,head[4:]))==[exponent,uptake]
    assert lines[-1]=='EXACT_OFF_ZERO_SINK_AND_FIVE_ATOMIC_REJECTIONS_PER_STEP_PASS'
    assert len(lines)==1+17*steps+2
    root=.02 if kind!=2 else 0.;drain=.01 if kind!=1 else 0.
    initial=np.full(16,.5) if mode==0 else .05+np.exp(-.5*(np.arange(16)+.5-8)**2)
    expected_initial=float(sum(.3*initial+.26*initial**exponent))
    prev=initial;theta0=.3;totalin=totalout=totalroot=totaldrain=0.;worst=oracle=0.;last=None
    for k in range(steps):
        step=lines[1+17*k].split();assert step[0]=='STEP' and int(step[1])==k+1
        oldtheta,theta,inc,out,roots,drains=map(float,step[2:]);assert oldtheta==theta0
        assert abs(theta-(oldtheta-dt*(root+drain)))<1e-15
        cells=[x.split() for x in lines[2+17*k:18+17*k]]
        assert [int(x[1]) for x in cells]==list(range(1,17)) and all(x[0]=='CELL' for x in cells)
        a=np.array([list(map(float,x[2:])) for x in cells]);assert a.shape==(16,5) and np.isfinite(a).all()
        before,c,m,s,delta=a.T
        assert np.max(abs(before-prev))<1e-15 and min(c)>=0 and min(m)>=0 and min(s)>=0
        assert max(abs(m-theta*c))<1e-13 and max(abs(s-.26*c**exponent))<1e-12
        assert abs(sum(delta))<1e-12
        q=.15 if mode==2 else 0.;rate=.1*theta/.3 if mode==2 else 0.
        conductance=.2*theta**3.33/.423**2+.25*q if mode==2 else 0.
        faces=np.r_[q*.05,q*c[:-1]+conductance*(c[:-1]-c[1:]),q*c[-1]]
        rhs=oldtheta*before+.26*before**exponent+delta
        equation=(1+dt*rate)*(m+s)+dt*(uptake*root+drain)*c-rhs-dt*(faces[:-1]-faces[1:])
        residual=float(max(abs(equation)));assert residual<1e-11,('independent finite volume',args,k,residual)
        worst=max(worst,residual)
        assert abs(inc-dt*q*.05)<1e-12
        assert abs(roots-dt*uptake*root*sum(c))<1e-12
        assert abs(drains-dt*drain*sum(c))<1e-12
        assert abs(out-dt*(q*c[-1]+rate*sum(m+s)+(uptake*root+drain)*sum(c)))<1e-12
        if mode<2:
            # Independent monotone scalar bisection; no production partition call.
            lo=np.zeros(16);hi=np.maximum(1.,2*before)
            storage=oldtheta*before+.26*before**exponent
            for _ in range(80):
                mid=(lo+hi)/2
                below=(theta+dt*(uptake*root+drain))*mid+.26*mid**exponent<storage
                lo=np.where(below,mid,lo);hi=np.where(below,hi,mid)
            error=float(max(abs(c-(lo+hi)/2)));assert error<1e-12
            assert max(abs(delta))<1e-12;oracle=max(oracle,error)
        if mode==0:
            if uptake==1 or kind==2:assert max(abs(c-.5))<1e-12
            else:assert min(c)>.5
        totalin+=inc;totalout+=out;totalroot+=roots;totaldrain+=drains
        prev=c;theta0=theta;last=a
    budget=np.array(list(map(float,lines[-2].split()[1:])));assert lines[-2].startswith('BUDGET ') and len(budget)==8
    assert np.isfinite(budget).all() and min(budget)>=0
    assert abs(budget[0]-expected_initial)<1e-12 and abs(budget[1]-totalin)<1e-12 and abs(budget[2]-totalout)<1e-12
    assert abs(budget[4]-totalroot)<1e-12 and abs(budget[5]-totaldrain)<1e-12
    assert abs(budget[2]-budget[3]-budget[4]-budget[5]-(.15*dt*sum(float(lines[2+17*k+15].split()[3]) for k in range(steps)) if mode==2 else 0.))<1e-12
    balance=abs(sum(last[:,2]+last[:,3])-budget[0]-budget[1]+budget[2]);assert balance<1e-10 and budget[6]<1e-10
    if mode==2:assert budget[7]>1e-8 and budget[3]>0
    return dict(balance=balance,equation_residual=worst,scalar_oracle_error=oracle)
def numeric(raw):
    return np.array([float(x) for line in raw.decode().splitlines()[:-1] for x in line.split()[1:]])
def assess(files,process_only=False):
    identity=json.loads(files['validation/identity.json']);raw=files['validation/checkpoint.raw']
    assert hashlib.sha1(b'commit '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==identity['commit']
    for name in ['verify.py','seal.py']:assert files['validation/'+name]==(HERE/name).read_bytes()
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
    r=json.loads(files[latest+'/execution.json'])
    assert r['status']==('PROCESS_EXECUTED' if process_only else 'EXECUTED') and all(e['returncode']==0 for e in r['events'])
    generated=runpy.run_path(str(HERE/'generate.py'))['sources']()
    for name,b in generated.items():assert files[latest+'/'+name]==b
    assert not r['production_activated'] and not r['disk_restart_qualified']
    assert {k:len(v) for k,v in r['closures'].items()}=={'process':11,'joint':176}
    assert len(r['toolchain_files'])==4
    for e in r['events']:
        if '-fcheck=all' in e['command']:
            assert '-ffpe-trap=invalid,zero,overflow' in e['command'] and '-fopenmp' in e['command']
            category=Path(e['command'][-1]).parent.name.split('-')[0]
            actual=[p for p in e['command'] if p.endswith('.f90')];assert actual==r['closures'][category]
            for p in actual:
                if Path(p).name in generated:assert Path(p)==Path(e['command'][-1]).parent.parent/Path(p).name
                else:assert str(Path(p).relative_to(ROOT)) in r['inputs'],('unbound compiled source',p)
    profiles={};joint={};worst=equation=oracle=drift=0.;accepted=0;rootmass=drainmass=0.
    for case in r['process_cases']:
        key=(case['optimization'],*case['arguments']);assert key not in profiles and case in [dict(**e,optimization=case['optimization'],arguments=case['arguments']) for e in r['events']]
        raw=files[latest+'/'+case['stdout']];result=process(raw,case['arguments']);profiles[key]=raw
        worst=max(worst,result['balance']);equation=max(equation,result['equation_residual']);oracle=max(oracle,result['scalar_oracle_error'])
    assert set(profiles)==set(itertools.product(['O0','O2'],[0,1,2],[.5,1.,2.],[0.,.5,1.],[1,2,3],[4]))
    if not process_only:
        for case in r['joint_cases']:
            opt=case['optimization'];n,factor,exponent,uptake=case['arguments'];key=(opt,*case['arguments']);assert key not in joint
            assert case in [dict(**e,optimization=opt,arguments=case['arguments']) for e in r['events']]
            raw=files[latest+'/'+case['stdout']];lines=raw.decode().splitlines()
            assert lines[-1]=='LATE_CHEMICAL_WATER_REJECTION_EXACT_RETRY_AND_OPAQUE_CHECKPOINT_PASS'
            windows=[l.split() for l in lines if l.startswith('WINDOW ')];assert len(windows)==4
            assert [int(v[1]) for v in windows]==[1,2,3,4]
            for w in windows:
                assert int(w[2])>1 and int(w[3])==int(w[2])-1
                v=list(map(float,w[4:]));assert len(v)==7 and all(math.isfinite(x) for x in v)
                assert v[0]>=0 and v[1]>=sum(v[4:]) and v[4]>0 and v[6]>0
                assert v[5]==0 if uptake==0 else v[5]>0
                assert 0<=v[2]<1e-10 and abs(v[3])<1e-10
                rootmass+=v[5];drainmass+=v[6]
            head=next(l.split() for l in lines if l.startswith('JOINT_PASS '))
            assert list(map(int,head[1:4]))==[n,sum(int(w[2]) for w in windows),20]
            assert list(map(float,head[4:6]))==[factor,exponent] and 0<=float(head[6])<1e-10 and float(head[7])==.4
            budget=list(map(float,next(l.split()[1:] for l in lines if l.startswith('BUDGET '))))
            cells=[l.split() for l in lines if l.startswith('CELL ')];assert len(cells)==n and [int(v[1]) for v in cells]==list(range(1,n+1))
            p=np.array([list(map(float,v[2:])) for v in cells]);assert p.shape==(n,4) and np.isfinite(p).all() and p.min()>=0
            water,c,m,s=p.T;h=40/n
            assert max(abs(m-water*h*c))<1e-13 and max(abs(s-.26*h*c**exponent))<1e-12
            balance=abs(sum(m+s)-budget[0]-budget[1]+budget[2]);assert balance<1e-10
            worst=max(worst,balance,float(head[6]));accepted+=int(head[2]);joint[key]=raw
        assert set(joint)==set(itertools.product(['O0','O2'],[40,80],[.8,1.2],[.5,1.,2.],[0.,1.]))
        owner=json.loads(files['PRESERVATION.json']);assert owner['qualified'] and owner['controls']>=179 and owner['pulse_controls']==8
    for group in [profiles,joint]:
        for key,raw in group.items():
            if key[0]=='O0':
                difference=float(max(abs(numeric(raw)-numeric(group[('O2',*key[1:])]))));assert difference<1e-12
                drift=max(drift,difference)
    return dict(status='PROCESS_ORACLES_PASS' if process_only else 'EXTRACTING_ROOT_DRAIN_FCT_O0_O2_QUALIFIED',process_cases=len(profiles),joint_cases=len(joint),
      primary_accepted_substeps=accepted,process_atomic_rejections=5*4*len(profiles),joint_atomic_rejections=20*len(joint),
      exact_joint_retries=4*len(joint),exact_checkpoint_continuation_windows=2*len(joint),max_mass_residual=worst,
      max_independent_equation_residual=equation,max_scalar_oracle_error=oracle,max_O0_O2_numeric_difference=drift,
      summed_root_output_mg_cm2=rootmass,summed_drain_output_mg_cm2=drainmass,production_activated=False,new_disk_restart_qualified=False,full_mc_sol01_closed=False)
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
    for name in ['sink_composed.f90','sink_trace.f90','joint_driver.f90']:
        reject('missing '+name,lambda f,name=name:f.pop(latest+'/'+name))
    reject('changed production physics',lambda f:f.__setitem__(latest+'/source/src/process/mod_b111_reactive_solute_substep.f90',b'!'))
    reject('missing composed owner',lambda f:f.pop('PRESERVATION.json'))
    case=next(c for c in r['process_cases'] if c['arguments']==[0,1.,0.,1,4])
    def rewrite(f,negative):
        p=latest+'/'+case['stdout'];lines=f[p].decode().splitlines();v=lines[2].split()
        if negative:v[4]='-1'
        else:
            c=float(v[3])+.001;v[3:6]=[str(c),str(float(lines[1].split()[3])*c),str(.26*c)]
        lines[2]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode();rr=json.loads(f[latest+'/execution.json'])
        for e in [*rr['events'],*rr['process_cases']]:
            if e['stdout']==case['stdout']:e['stdout_sha256']=sha(f[p])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('negative mass with rebound hashes',lambda f:rewrite(f,True))
    reject('equilibrium-preserving wrong water-only extraction with rebound hashes',lambda f:rewrite(f,False))
    def unbound(f):
        rr=json.loads(f[latest+'/execution.json']);e=next(e for e in rr['events'] if '-fcheck=all' in e['command'])
        rr['inputs'].pop(next(p for p in rr['inputs'] if e['command'].count(str(ROOT/p))))
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('compiled production source removed from input binding',unbound)
    def no_ledger(f):
        rr=json.loads(f[latest+'/execution.json']);c=rr['joint_cases'][0];p=latest+'/'+c['stdout'];lines=f[p].decode().splitlines()
        v=lines[0].split();v[-1]='0';lines[0]=' '.join(v);f[p]=('\n'.join(lines)+'\n').encode()
        for e in [*rr['events'],*rr['joint_cases']]:
            if e['stdout']==c['stdout']:e['stdout_sha256']=sha(f[p])
        f[latest+'/execution.json']=json.dumps(rr).encode()
    reject('missing drainage execution with rebound hashes',no_ledger)
    return passed
if __name__=='__main__':
    ap=argparse.ArgumentParser();ap.add_argument('--self-test',action='store_true');a=ap.parse_args()
    i=json.loads((HERE/'EVIDENCE_INDEX.json').read_text());f=unpack(HERE/'EVIDENCE.tar.xz.b64',i['decoded_sha256']);result=assess(f)
    assert result==json.loads(f['VERIFICATION.json'])
    if a.self_test:result['controls']=controls(f)
    print(json.dumps(result,indent=2))
