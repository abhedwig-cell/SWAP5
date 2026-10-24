#!/usr/bin/env python3
"""Qualify a proposed daily operator composition through real production seams."""
import argparse,base64,hashlib,io,json,os,pathlib,re,runpy,shlex,subprocess,tarfile,time
import numpy as np
from scipy.integrate import solve_ivp
UNIT=pathlib.Path(__file__).resolve().parent;ROOT=UNIT.parents[2]
BASE='9d888c03643427bd7f5426a3bbf470fb5fbf5c4a';sha=lambda b:hashlib.sha256(b).hexdigest()
organic_oracle=runpy.run_path(str(UNIT/'run_multipool_limited.py'))['oracle']

def mineral(m,source,crop,top,rate):
    # The independent constrained ODE may leave a signed roundoff residue
    # on its invariant N=0 boundary. Reject a real deficit before normalising.
    assert m>=-1e-13
    m=max(0.,m)
    total=crop+top
    def rhs(t,y):return [source-total-rate*y[0],y[0]]
    def zero(t,y):return y[0]
    zero.terminal=True;zero.direction=-1
    if m==0 and source<=total:return 0.,0.,source
    s=solve_ivp(rhs,(0,1),[m,0.],method='DOP853',rtol=2e-12,atol=2e-14,events=zero)
    assert s.success
    spent=s.t[-1];actual=total*spent
    if len(s.t_events[0]):actual+=source*(1-spent);end=0.
    else:end=s.y[0,-1]
    return end,s.y[1,-1],actual

def validate(raw):
    lines=raw.decode().splitlines();assert lines[-1]=='ORGANIC_FIRST_LATE_ROLLBACK_PASS'
    a=np.array([[float(v) for v in l.split()] for l in lines[:-1]])
    assert a.shape==(144,24) and np.array_equal(a[:,0],np.repeat(np.arange(1,25),6))
    assert np.array_equal(a[:,1],np.tile(np.arange(1,7),24))
    error=0.;nerr=0.;cerr=0.;cache={};gas=0;toplimited=0
    for case in range(24):
        data=a[case*6:case*6+6,2:];m,no3,demand,chem=data[0,:4]
        current=np.array([1.,.5,.03,.1,m,no3]);native=current.copy()
        for row in data:
            assert np.array_equal(row[:4],data[0,:4])
            p=dict(kind=1,f=current[:2].tolist(),b=current[2],h=current[3],m=current[4],depth=.3,
                nf=[.001,.025],nb=.08,nh=.02,kf=[10,.3],kb=5,kh=.1,afb=[.5,.2],afh=[.1,.1],ab=.3,ah=.2,dt=1)
            key=tuple(current[:5])
            if key not in cache:cache[key]=organic_oracle(p)[0]
            org=cache[key];carbon=org[5];wfps=.34/.423
            kn=.02*chem*(.9/(1+np.exp(-15*(wfps-.45)))+.1-1/(1+np.exp(-50*(wfps-.95))))
            kd=.03*chem*(max(wfps-.5,0)/.5)**2*carbon/(.1+carbon)
            endn,integral,actual=mineral(org[4],0,demand,2e-6,kn*.34/.6)
            cropn=actual*demand/(demand+2e-6);topn=actual*2e-6/(demand+2e-6)
            nit=kn*.34/.6*integral;remaining=max(0.,demand-cropn)
            end3,int3,act3=mineral(current[5],nit,remaining,5e-6,kd)
            crop3=act3*remaining/(remaining+5e-6);top3=act3*5e-6/(remaining+5e-6);denit=kd*int3
            expected=np.r_[data[0,:4],org[:4],endn,end3,carbon,kn,kd,cropn,crop3,-topn,-top3,2e-6-topn,5e-6-top3,nit,denit,0]
            error=max(error,float(max(abs(row-expected))))
            assert max(abs(row-expected))<2e-7,(case,row,expected)
            assert min(row[4:15])>=0 and min(row[17:21])>=-1e-14 and max(row[15:17])<=0
            assert abs(-row[15]+row[17]-2e-6)<1e-12 and abs(-row[16]+row[18]-5e-6)<1e-12
            assert row[13]+row[14]<=demand+1e-12
            dn=.3*(np.array([.001,.025,.08,.02])@(row[4:8]-native[:4]))+sum(row[8:10])-sum(native[4:])
            residual=dn+row[13]+row[14]-sum(row[15:17])+row[20]
            c_res=.45*.3*sum(row[4:8]-native[:4])+row[10]
            nerr=max(nerr,abs(residual));cerr=max(cerr,abs(c_res))
            assert abs(residual)<1e-12 and abs(c_res)<1e-12 and abs(row[21])<1e-12
            gas+=row[20]>0;toplimited+=max(row[17:19])>1e-14
            native=row[4:10].copy();current=np.r_[org[:4],endn,end3]
    assert gas>0 and toplimited>0
    return dict(runs=24,days_per_run=6,rows=144,max_component_error=error,
                max_n_residual=float(nerr),max_c_residual=float(cerr),gas_days=int(gas),top_limited_days=int(toplimited))

def replay():
    record=json.loads((UNIT/'ORGANIC_FIRST_DAY_RESULT.json').read_bytes());path=UNIT/'ORGANIC_FIRST_DAY_EVIDENCE.tar.xz.b64'
    assert sha(path.read_bytes())==record['evidence_sha256']
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode(path.read_bytes()))) as t:f={m.name:t.extractfile(m).read() for m in t.getmembers() if m.isfile()}
    manifest=json.loads(f['MEMBERS.json']);assert set(f)==set(manifest)|{'MEMBERS.json'}
    for p,h in manifest.items():assert sha(f[p])==h,p
    for p,h in record['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h,p
    assert json.loads(f['result.json'])=={k:v for k,v in record.items() if k!='evidence_sha256'}
    es=json.loads(f['events.json']);assert all(e['returncode']==0 for e in es)
    assert sum(e['category']=='compile' for e in es)==2*record['compiled_sources_per_optimization']
    native=[e for e in es if e['category']=='native'];assert len(native)==2
    for e in es:
        for stream in ['stdout','stderr']:assert sha(f[e[stream]])==e[stream+'_sha256']
    for opt,e in zip(['O0','O2'],native):
        assert f[opt+'.txt']==f[e['stdout']]
        assert validate(f[opt+'.txt'])==record['results'][opt]
    controls=0
    for col,value in [(10,'-1'),(14,'1'),(18,'1'),(23,'1')]:
        lines=f['O0.txt'].decode().splitlines();fields=lines[0].split();fields[col]=value;lines[0]=' '.join(fields)
        try:validate(('\n'.join(lines)+'\n').encode())
        except AssertionError:controls+=1
        else:raise AssertionError('daily corruption accepted')
    return dict(status='ORGANIC_FIRST_DAY_REPLAY_PASS',numerical_controls=controls)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--out',type=pathlib.Path);ap.add_argument('--seal',action='store_true');ap.add_argument('--replay',action='store_true');args=ap.parse_args()
    if args.replay:print(json.dumps(replay(),indent=2));return
    out=args.out.resolve();out.mkdir();events=[]
    def command(cmd,cwd,category):
        start=time.perf_counter();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True);i=len(events);names=[f'{i:04d}.stdout',f'{i:04d}.stderr']
        for name,data in zip(names,[r.stdout,r.stderr]):(out/name).write_bytes(data)
        events.append(dict(command=list(map(str,cmd)),category=category,returncode=r.returncode,seconds=time.perf_counter()-start,
            stdout=names[0],stderr=names[1],stdout_sha256=sha(r.stdout),stderr_sha256=sha(r.stderr)))
        (out/'events.json').write_text(json.dumps(events,indent=2)+'\n')
        if r.returncode:raise RuntimeError(r.stdout.decode()+r.stderr.decode())
        return r.stdout
    fc=shlex.split(os.environ.get('FC','gfortran'));compiler=command(fc+['--version'],out,'compiler').decode()
    providers={}
    research=[UNIT/'mod_multipool_limited_organic.f90',UNIT/'mod_organic_first_day.f90']
    for p in list((ROOT/'src').rglob('*.f90'))+research:
        for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
    ordered=[];seen=set()
    def visit(p):
        if p in seen:return
        seen.add(p)
        for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
            if name.lower() not in ['iso_fortran_env','ieee_arithmetic']:visit(providers[name.lower()])
        ordered.append(p)
    visit(UNIT/'test_organic_first_day.f90');results={};validation=0.
    for opt in ['O0','O2']:
        build=out/opt;build.mkdir();objects=[];flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
        for i,p in enumerate(ordered):
            obj=build/f'{i}.o';objects.append(obj);command(fc+flags+['-c',p,'-o',obj],build,'compile')
        exe=build/'research';command(fc+flags+objects+['-o',exe],build,'link')
        raw=command([exe],build,'native');(out/(opt+'.txt')).write_bytes(raw)
        start=time.perf_counter();results[opt]=validate(raw);validation+=time.perf_counter()-start
    a=np.loadtxt(io.StringIO('\n'.join((out/'O0.txt').read_text().splitlines()[:-1])))
    b=np.loadtxt(io.StringIO('\n'.join((out/'O2.txt').read_text().splitlines()[:-1])))
    assert np.max(abs(a-b))<1e-10
    files=ordered+[pathlib.Path(__file__),UNIT/'run_multipool_limited.py',UNIT/'ORGANIC_FIRST_DAY_CONTRACT.md']
    result=dict(status='PROPOSED_ORGANIC_FIRST_DAY_RESEARCH_PASS',baseline=BASE,production_admitted=False,
        tested_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=compiler,
        compiled_sources_per_optimization=len(ordered),input_sha256={str(p.relative_to(ROOT)):sha(p.read_bytes()) for p in files},results=results,
        cost_seconds={**{c:sum(e['seconds'] for e in events if e['category']==c) for c in ['compile','link','native']},'independent_validation':validation})
    (out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    if args.seal:
        members=[p for p in out.iterdir() if p.is_file()];(out/'MEMBERS.json').write_text(json.dumps({p.name:sha(p.read_bytes()) for p in members},indent=2)+'\n')
        buf=io.BytesIO()
        with tarfile.open(fileobj=buf,mode='w:xz') as t:
            for p in members+[out/'MEMBERS.json']:t.add(p,arcname=p.name)
        path=UNIT/'ORGANIC_FIRST_DAY_EVIDENCE.tar.xz.b64';path.write_bytes(base64.encodebytes(buf.getvalue()))
        result['evidence_sha256']=sha(path.read_bytes());(UNIT/'ORGANIC_FIRST_DAY_RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))

if __name__=='__main__':main()
