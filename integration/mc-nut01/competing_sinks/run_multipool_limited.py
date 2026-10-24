#!/usr/bin/env python3
"""Native bounded multi-pool proposal, with a separate event-driven ODE oracle."""
import argparse,base64,hashlib,io,itertools,json,os,pathlib,runpy,shlex,subprocess,tarfile,time
import numpy as np
from scipy.integrate import solve_ivp
UNIT=pathlib.Path(__file__).resolve().parent;ROOT=UNIT.parents[2]
BASE='9be9a09b9c890a8240490d1f72a99c14c0cf72f8'
sha=lambda b:hashlib.sha256(b).hexdigest()

def cases():
    rows=[]
    for kf,kb,m,b,dt in itertools.product([.1,10],[0,5,10],[0,.005],[0,.03],[1,10]):
        rows.append(dict(kind=0,f=[1,0],b=b,h=0,m=m,depth=1,nf=[.001,.001],nb=.08,nh=.02,
            kf=[kf,0],kb=kb,kh=0,afb=[.5,0],afh=[0,0],ab=0,ah=0,dt=dt))
    sets=[dict(nf=[.001,.025],nb=.08,nh=.02,kf=[10,.3],kb=5,kh=.1,afb=[.5,.2],afh=[.1,.1],ab=.3,ah=.2),
          dict(nf=[.06,.001],nb=.04,nh=.08,kf=[.2,3],kb=.4,kh=.05,afb=[.3,.5],afh=[.2,.1],ab=.2,ah=.6),
          dict(nf=[.001,.001],nb=.08,nh=.02,kf=[.5,.05],kb=.01,kh=.001,afb=[.2,.2],afh=[.1,.1],ab=.3,ah=.2)]
    for p,m,seed,dt in itertools.product(sets,[0,1e-5,.005,.05],[False,True],[1,10]):
        rows.append(dict(kind=1,f=[1,.5],b=.03 if seed else 0,h=.1 if seed else 0,m=m,depth=.3,dt=dt,**p))
    return rows

def oracle(p):
    a=np.zeros((4,4));np.fill_diagonal(a,-1)
    a[2,:2]=p['afb'];a[3,:2]=p['afh'];a[2,2]+=p['ab'];a[3,2]=p['ah'];a[2,3]=p['ab'];a[3,3]+=p['ah']
    nf=np.r_[p['nf'],p['nb'],p['nh']];k=np.r_[p['kf'],p['kb'],p['kh']];gamma=-nf@a
    y=np.r_[p['f'],p['b'],p['h'],p['m']/p['depth'],0.];dt=p['dt'];clock=0.;events=0
    def potential(y):
        flow=k*y[:4];return flow,np.maximum(gamma,0)@flow,np.maximum(-gamma,0)@flow
    def rhs(t,y,constrained=False):
        flow,source,demand=potential(y)
        if constrained and demand>source and demand>0:flow=np.where(gamma<0,flow*source/demand,flow)
        org=a@flow
        return np.r_[org,gamma@flow,-.45*sum(org)]
    def depleted(t,y):return y[4]
    depleted.terminal=True;depleted.direction=-1
    def released(t,y):
        _,source,demand=potential(y);return source-demand
    released.terminal=True;released.direction=1
    boundary=y[4]==0 and released(0,y)<0
    for phase in range(64):
        if clock>=dt:break
        if max(abs(rhs(clock,y,boundary)))<1e-30:break
        if boundary:
            s=solve_ivp(lambda t,y:rhs(t,y,True),(clock,dt),y,method='DOP853',rtol=2e-12,atol=2e-14,
                        max_step=.1/max(1,max(k)),events=released)
        else:
            s=solve_ivp(rhs,(clock,dt),y,method='DOP853',rtol=2e-12,atol=2e-14,
                        max_step=.1/max(1,max(k)),events=depleted)
        assert s.success and min(s.y[4])>-1e-11
        old=clock;clock=s.t[-1];y=s.y[:,-1]
        if len(s.t_events[0])==0:break
        events+=1;boundary=not boundary;y[4]=0.
        assert clock>old or phase==0,'oracle phase chatter'
    else:raise AssertionError('oracle event budget')
    y[4:]*=p['depth']
    return y,events

def validate(raw,inputs):
    lines=raw.decode().splitlines();assert lines[-1]=='MULTIPOOL_INVALID_ROLLBACK_PASS'
    a=np.array([[float(v) for v in l.split()] for l in lines[:-1]])
    assert a.shape==(288,15)
    assert np.array_equal(a[:,0],np.repeat(np.arange(1,97),3))
    assert np.array_equal(a[:,1],np.tile([1,2,3],96))
    assert min(a[:,2:8].ravel())>=0 and max(abs(a[:,11]))<1e-12 and max(abs(a[:,12]))<1e-12
    assert np.all(a[:,8]>0) and np.all(a[:,9:11]>=0)
    errors=np.zeros(3);events=0;full_errors=np.zeros(3)
    for i,p in enumerate(inputs):
        ref,nev=oracle(p);events+=nev
        data=a[3*i:3*i+3]
        error=np.max(abs(data[:,2:8]-ref),axis=1);errors=np.maximum(errors,error)
        # Reconstruct balances independently of the printed residuals.
        for row in data:
            before=np.r_[p['f'],p['b'],p['h']];nfrac=np.r_[p['nf'],p['nb'],p['nh']]
            assert abs(p['depth']*(nfrac@(row[2:6]-before))+row[6]-p['m'])<1e-12
            assert abs(.45*p['depth']*sum(row[2:6]-before)+row[7])<1e-12
        if p['kind']==0:full_errors=np.maximum(full_errors,data[:,14])
    assert np.all(errors<[1e-5,1e-6,1e-7]),errors
    assert errors[1]<errors[0]*.3 and errors[2]<errors[1]*.3,errors
    assert max(a[2::3,13])<5e-8 and max(a[2::3,14])<1e-7
    assert sum(a[2::3,10]>0)>0
    return dict(cases=96,tolerance_levels=[1e-5,1e-7,1e-9],max_endpoint_errors=errors.tolist(),
        one_pool_exact_errors=full_errors.tolist(),oracle_events=events,
        limited_fine_cases=int(sum(a[2::3,10]>0)),max_n_residual=float(max(abs(a[:,11]))),
        max_c_residual=float(max(abs(a[:,12]))),max_fine_continuation_error=float(max(a[2::3,13])),
        accepted_fine_steps=int(sum(a[2::3,8])),rejected_fine_steps=int(sum(a[2::3,9])))

def replay():
    record=json.loads((UNIT/'MULTIPOOL_RESULT.json').read_bytes());path=UNIT/'MULTIPOOL_EVIDENCE.tar.xz.b64'
    assert sha(path.read_bytes())==record['evidence_sha256']
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes()))) as t:
        f={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
    manifest=json.loads(f['MEMBERS.json']);assert set(f)==set(manifest)|{'MEMBERS.json'}
    for p,h in manifest.items():assert sha(f[p])==h,p
    for p,h in record['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
    assert json.loads(f['result.json'])=={k:v for k,v in record.items() if k!='evidence_sha256'}
    inputs=json.loads(f['input.json']);assert inputs==cases()
    es=json.loads(f['events.json']);assert all(e['returncode']==0 for e in es)
    assert sum(e['category']=='compile' for e in es)==12
    for e in es:
        for stream in ['stdout','stderr']:assert sha(f[e[stream]])==e[stream+'_sha256']
    native=[e for e in es if e['category']=='native'];assert len(native)==2
    for opt,e in zip(['O0','O2'],native):
        assert f[opt+'.txt']==f[e['stdout']]
        assert validate(f[opt+'.txt'],inputs)==record['results'][opt]
    a=np.loadtxt(io.StringIO('\n'.join(f['O0.txt'].decode().splitlines()[:-1])))
    b=np.loadtxt(io.StringIO('\n'.join(f['O2.txt'].decode().splitlines()[:-1])))
    assert float(np.max(abs(a[:,2:8]-b[:,2:8])))==record['optimization_endpoint_difference']<1e-10
    controls=0
    for col,value in [(2,'-1'),(11,'1'),(12,'1'),(13,'1')]:
        lines=f['O0.txt'].decode().splitlines();fields=lines[2].split();fields[col]=value;lines[2]=' '.join(fields)
        try:validate(('\n'.join(lines)+'\n').encode(),inputs)
        except AssertionError:controls+=1
        else:raise AssertionError('numerical corruption accepted')
    return dict(status='MULTIPOOL_RESEARCH_REPLAY_PASS',numerical_controls=controls)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=pathlib.Path);ap.add_argument('--seal',action='store_true');ap.add_argument('--replay',action='store_true');args=ap.parse_args()
    if args.replay:print(json.dumps(replay(),indent=2));return
    out=args.out.resolve();out.mkdir();es=[];inputs=cases()
    (out/'input.json').write_text(json.dumps(inputs,indent=2)+'\n')
    keys=['kind','f','b','h','m','depth','nf','nb','nh','kf','kb','kh','afb','afh','ab','ah','dt']
    flatten=lambda v:v if isinstance(v,list) else [v]
    (out/'input.txt').write_text(str(len(inputs))+'\n'+'\n'.join(' '.join(str(v) for key in keys for v in flatten(p[key])) for p in inputs)+'\n')
    def command(cmd,cwd,category):
        start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True);i=len(es)
        names=[f'{i:04d}.stdout',f'{i:04d}.stderr']
        for name,data in zip(names,[r.stdout,r.stderr]):(out/name).write_bytes(data)
        es.append(dict(command=list(map(str,cmd)),category=category,returncode=r.returncode,seconds=time.perf_counter()-start,
            stdout=names[0],stderr=names[1],stdout_sha256=sha(r.stdout),stderr_sha256=sha(r.stderr)))
        (out/'events.json').write_text(json.dumps(es,indent=2)+'\n')
        if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
        return r.stdout
    fc=shlex.split(os.environ.get('FC','gfortran'));compiler=command(fc+['--version'],out,'compiler').decode()
    sources=[ROOT/'src/process'/s for s in ['mod_soil_n_pool_state.f90','mod_b111_soil_organic_turnover.f90','mod_b111_soil_organic_dissimilation.f90']]
    sources += [UNIT/p for p in ['mod_path_limited_organic.f90','mod_multipool_limited_organic.f90','test_multipool_limited.f90']]
    results={};validation=0.
    for opt in ['O0','O2']:
        build=out/opt;build.mkdir();objects=[];flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
        for i,p in enumerate(sources):
            obj=build/f'{i}.o';objects.append(obj);command(fc+flags+['-c',p,'-o',obj],build,'compile')
        exe=build/'research';command(fc+flags+objects+['-o',exe],build,'link')
        raw=command([exe,out/'input.txt'],build,'native');(out/(opt+'.txt')).write_bytes(raw)
        start=time.perf_counter();results[opt]=validate(raw,inputs);validation+=time.perf_counter()-start
    a=np.loadtxt(io.StringIO('\n'.join((out/'O0.txt').read_text().splitlines()[:-1])))
    b=np.loadtxt(io.StringIO('\n'.join((out/'O2.txt').read_text().splitlines()[:-1])))
    optimization_error=float(np.max(abs(a[:,2:8]-b[:,2:8])))
    assert optimization_error<1e-10
    files=sources+[pathlib.Path(__file__),UNIT/'MULTIPOOL_CONTRACT.md']
    result=dict(status='PROPOSED_MULTIPOOL_LIMITATION_RESEARCH_PASS',baseline=BASE,production_admitted=False,
        tested_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=compiler,
        input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in files},results=results,
        optimization_endpoint_difference=optimization_error,
        cost_seconds={**{c:sum(e['seconds'] for e in es if e['category']==c) for c in ['compile','link','native']},'independent_validation':validation})
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.seal:
        members=[p for p in out.iterdir() if p.is_file()]
        (out/'MEMBERS.json').write_text(json.dumps({p.name:sha(p.read_bytes()) for p in members},indent=2)+'\n')
        buf=io.BytesIO()
        with tarfile.open(fileobj=buf,mode='w:xz') as t:
            for p in members+[out/'MEMBERS.json']:t.add(p,arcname=p.name)
        path=UNIT/'MULTIPOOL_EVIDENCE.tar.xz.b64';path.write_bytes(base64.encodebytes(buf.getvalue()))
        result['evidence_sha256']=sha(path.read_bytes());(UNIT/'MULTIPOOL_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
