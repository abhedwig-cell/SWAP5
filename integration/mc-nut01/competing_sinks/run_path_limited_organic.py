#!/usr/bin/env python3
"""Qualify a proposed continuous single-FOM/NH4 constraint, outside production."""
import argparse, base64, hashlib, io, json, os, pathlib, shlex, subprocess, tarfile, time
import numpy as np
from scipy.integrate import solve_ivp

UNIT=pathlib.Path(__file__).resolve().parent
ROOT=UNIT.parents[2]
BASE='9efc6d3ae532efcc7f6b0f6f8ebc29cdeabe3a14'
sha=lambda b:hashlib.sha256(b).hexdigest()

def oracle(row):
    f,b,m,kf,kb,dt=row[:6];need=.039;nf=.001;nb=.08;cf=.45
    def rhs(t,y):
        f,b,m,c=y
        return [-kf*f,.5*kf*f-kb*b,-need*kf*f+nb*kb*b,cf*(.5*kf*f+kb*b)]
    def zero(t,y):return y[2]
    zero.terminal=True;zero.direction=-1
    def leave(t,y):return need*kf*y[0]-nb*kb*y[1]
    leave.terminal=True;leave.direction=-1
    def limited(t,y):
        release=nb*kb*y[1]
        return [-release/need,nf*kb*y[1]/need,0,cf*(release/need-nf*kb*y[1]/need)]
    y=np.array([f,b,m,0.]);clock=0.;depletion=-1.;release=-1.;duration=0.
    at_boundary=m==0 and need*kf*f>nb*kb*b
    if not at_boundary:
        s=solve_ivp(rhs,(0,dt),y,method='DOP853',rtol=2e-12,atol=2e-14,
                    max_step=.1/max(1,kf,kb),events=zero)
        assert s.success
        clock=s.t[-1];y=s.y[:,-1];at_boundary=len(s.t_events[0])>0
    if at_boundary and clock<dt:
        depletion=clock;y[2]=0.
        if y[1]==0 or kb==0:
            duration=dt-clock
        else:
            s=solve_ivp(limited,(clock,dt),y,method='DOP853',rtol=2e-12,atol=2e-14,events=leave)
            assert s.success
            duration=s.t[-1]-clock;clock=s.t[-1];y=s.y[:,-1]
            if len(s.t_events[0])>0 and clock<dt:
                release=clock
                s=solve_ivp(rhs,(clock,dt),y,method='DOP853',rtol=2e-12,atol=2e-14)
                assert s.success
                y=s.y[:,-1]
    return np.r_[y,depletion,release,duration]

def validate(raw):
    lines=raw.decode().splitlines()
    assert lines[-1]=='PATH_LIMITED_INVALID_ROLLBACK_PASS'
    a=np.array([[float(v) for v in l.split()] for l in lines[:-1]])
    assert a.shape==(96,18) and np.array_equal(a[:,0],np.arange(1,97))
    assert len({tuple(r[:6]) for r in a[:,1:]})==96
    maximum=0.;event_error=0.
    for row in a[:,1:]:
        expected=oracle(row)
        maximum=max(maximum,float(np.max(abs(row[6:10]-expected[:4]))))
        assert np.max(abs(row[6:10]-expected[:4]))<2e-9,(row,expected)
        assert np.array_equal(row[10:12]>=0,expected[4:6]>=0),(row,expected)
        event_error=max(event_error,float(np.max(abs(row[10:13]-expected[4:7]))))
        assert np.max(abs(row[10:13]-expected[4:7]))<2e-9,(row,expected)
        assert min(row[6:10])>=0 and np.max(abs(row[13:15]))<1e-12
        assert row[15]<2e-11 and row[16]>=0
        # Independently reconstruct full N/C balances from the printed endpoints.
        assert abs(.001*(row[6]-row[0])+.08*(row[7]-row[1])+row[8]-row[2])<1e-12
        assert abs(.45*(row[6]-row[0]+row[7]-row[1])+row[9])<1e-12
    hidden=next(r for r in a[:,1:] if tuple(r[:6])==(1,0,.005,10,5,1))
    assert hidden[10]>0 and hidden[8]<1e-13 and hidden[6]>100*np.exp(-10)
    counts=dict(depleted=int(sum(a[:,11]>=0)),released=int(sum(a[:,12]>=0)),
                stalled=int(sum((a[:,11]>=0)&((a[:,5]==0)|((a[:,2]==0)&(a[:,3]==0))))),
                unlimited=int(sum(a[:,11]<0)))
    assert counts['depleted']>0 and counts['released']>0 and counts['unlimited']>0
    return dict(cases=96,endpoint_max_error=maximum,event_max_error=event_error,
                max_n_residual=float(np.max(abs(a[:,14]))),max_c_residual=float(np.max(abs(a[:,15]))),
                max_continuation_error=float(max(a[:,16])),counts=counts,
                hidden_depletion_endpoint=hidden[6:13].tolist())

def unpack():
    path=UNIT/'PATH_LIMITED_EVIDENCE.tar.xz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes()))) as t:
        return {m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}

def replay():
    result=json.loads((UNIT/'PATH_LIMITED_RESULT.json').read_bytes());files=unpack()
    assert sha((UNIT/'PATH_LIMITED_EVIDENCE.tar.xz.b64').read_bytes())==result['evidence_sha256']
    members=json.loads(files['MEMBERS.json']);assert set(files)==set(members)|{'MEMBERS.json'}
    for p,h in members.items():assert sha(files[p])==h,p
    for p,h in result['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
    assert json.loads(files['result.json'])=={k:v for k,v in result.items() if k!='evidence_sha256'}
    events=json.loads(files['events.json']);assert all(e['returncode']==0 for e in events)
    assert sum(e['category']=='compile' for e in events)==10
    native=[e for e in events if e['category']=='native'];assert len(native)==2
    for event in events:
        for stream in ['stdout','stderr']:assert sha(files[event[stream]])==event[stream+'_sha256']
    for opt,event in zip(['O0','O2'],native):
        assert files[opt+'.txt']==files[event['stdout']]
        assert validate(files[opt+'.txt'])==result['results'][opt]
    # Numerical controls bypass the container hashes to exercise the assertions.
    controls=0
    for col,value in [(7,'9'),(11,'-1'),(10,'9'),(9,'-1'),(14,'1')]:
        lines=files['O0.txt'].decode().splitlines();fields=lines[0].split()
        fields[col]=value;lines[0]=' '.join(fields)
        try:validate(('\n'.join(lines)+'\n').encode())
        except AssertionError:controls+=1
        else:raise AssertionError('scientific corruption accepted')
    return dict(status='PATH_LIMITED_RESEARCH_REPLAY_PASS',numerical_corruption_controls=controls)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--out',type=pathlib.Path)
    parser.add_argument('--seal',action='store_true');parser.add_argument('--replay',action='store_true')
    args=parser.parse_args()
    if args.replay:print(json.dumps(replay(),indent=2));return
    assert args.out is not None
    out=args.out.resolve();out.mkdir();events=[]
    def command(cmd,cwd,category):
        start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True);i=len(events)
        names=[f'{i:04d}.stdout',f'{i:04d}.stderr']
        for name,data in zip(names,[r.stdout,r.stderr]):(out/name).write_bytes(data)
        events.append(dict(command=list(map(str,cmd)),category=category,seconds=time.perf_counter()-start,
            returncode=r.returncode,stdout=names[0],stderr=names[1],stdout_sha256=sha(r.stdout),stderr_sha256=sha(r.stderr)))
        (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
        if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
        return r.stdout
    fc=shlex.split(os.environ.get('FC','gfortran'));compiler=command(fc+['--version'],out,'compiler').decode()
    providers=[ROOT/'src/process'/s for s in ['mod_soil_n_pool_state.f90','mod_b111_soil_organic_turnover.f90','mod_b111_soil_organic_dissimilation.f90']]
    sources=providers+[UNIT/'mod_path_limited_organic.f90',UNIT/'test_path_limited_organic.f90']
    results={};validation_seconds=0.
    for opt in ['O0','O2']:
        build=out/opt;build.mkdir();objects=[]
        flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
        for i,p in enumerate(sources):
            obj=build/f'{i}.o';objects.append(obj);command(fc+flags+['-c',p,'-o',obj],build,'compile')
        exe=build/'research';command(fc+flags+objects+['-o',exe],build,'link')
        raw=command([exe],build,'native');(out/(opt+'.txt')).write_bytes(raw)
        start=time.perf_counter();results[opt]=validate(raw);validation_seconds+=time.perf_counter()-start
    a=np.loadtxt(io.StringIO('\n'.join((out/'O0.txt').read_text().splitlines()[:-1])))
    b=np.loadtxt(io.StringIO('\n'.join((out/'O2.txt').read_text().splitlines()[:-1])))
    assert np.max(abs(a-b))<2e-11
    inputs=sources+[pathlib.Path(__file__),UNIT/'PATH_LIMITED_CONTRACT.md']
    result=dict(status='PROPOSED_SINGLE_FOM_PATH_LIMITATION_RESEARCH_PASS',baseline=BASE,production_admitted=False,
        tested_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        compiler=compiler,input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in inputs},results=results,
        cost_seconds={**{c:sum(e['seconds'] for e in events if e['category']==c) for c in ['compile','link','native']},
                      'independent_validation':validation_seconds})
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.seal:
        members=[p for p in out.iterdir() if p.is_file()]
        (out/'MEMBERS.json').write_text(json.dumps({p.name:sha(p.read_bytes()) for p in members},indent=2)+'\n')
        buf=io.BytesIO()
        with tarfile.open(fileobj=buf,mode='w:xz') as t:
            for p in members+[out/'MEMBERS.json']:t.add(p,arcname=p.name)
        capsule=UNIT/'PATH_LIMITED_EVIDENCE.tar.xz.b64';capsule.write_bytes(base64.encodebytes(buf.getvalue()))
        result['evidence_sha256']=sha(capsule.read_bytes())
        (UNIT/'PATH_LIMITED_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
