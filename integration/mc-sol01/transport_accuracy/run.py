"""Separate space/time accuracy of the actual production linear-sorption route."""
import argparse, base64, hashlib, importlib.util, io, json, math, os, subprocess, tarfile, tempfile, time
from pathlib import Path
import numpy as np
import scipy
from scipy.linalg import expm
from scipy.special import erf

ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()

def gaussian(n, kf, alpha, t):
    # R dc/dt = alpha*q d2c/dz2 - q dc/dz - lambda*R*c.
    # Exact cell averages of a unit Gaussian on the infinite line.
    h=40/n; R=.25+1.3*kf; variance=1+2*alpha*.25/R*t
    edges=(np.arange(n+1)*h-15-.25/R*t)/math.sqrt(2*variance)
    return math.sqrt(math.pi/2)*math.exp(-.05*t)*np.diff(erf(edges))/h

def matrix(n, kf, alpha):
    # Independent constant-volume mass equations: inlet concentration zero,
    # internal advective+dispersive flux, convective outlet, total-stock decay.
    h=40/n; mass=(.25+1.3*kf)*h; dispersion=alpha*.25/h
    A=np.diag(np.full(n,-(.25+2*dispersion)/mass-.05))
    A[0,0]+=dispersion/mass; A[-1,-1]+=dispersion/mass
    A+=np.diag(np.full(n-1,(.25+dispersion)/mass),-1)
    A+=np.diag(np.full(n-1,dispersion/mass),1)
    return A

def assess(out):
    report=json.loads((out/'execution.json').read_text())
    assert report['status']=='EXECUTED'
    for p,h in report['inputs'].items(): assert sha(ROOT/p)==h,('source',p)
    assert report['provider_count']==6 and len(report['cases'])==36
    assert len(report['events'])==39 and all(e['returncode']==0 for e in report['events'])
    assert b'GNU Fortran' in (out/report['events'][0]['stdout']).read_bytes()
    builds=[e for e in report['events'] if '-fcheck=all' in e['command']]
    assert len(builds)==2
    for opt,event in zip(['O0','O2'],builds):
        assert all(flag in event['command'] for flag in ['-'+opt,'-std=f2008','-ffpe-trap=invalid,zero,overflow'])
        compiled=[p for p in event['command'] if p.endswith('.f90')]
        assert {str(Path(p).relative_to(ROOT)) for p in compiled}=={p for p in report['inputs'] if p.endswith('.f90')}
    for event in report['events']:
        assert (out/event['stdout']).is_file() and (out/event['stderr']).is_file()
    assert report['cases']==[{**e,**{k:c[k] for k in ['optimization','case','n','dt','axis','sha256']}}
                            for c in report['cases'] for e in report['events'] if e['stdout']==c['stdout']]
    results={}; profiles={}; maxima=0.; cumul=0.
    exact={}; analytic={}
    for c in report['cases']:
        raw=(out/c['stdout']).read_bytes(); assert hashlib.sha256(raw).hexdigest()==c['sha256']
        assert c['returncode']==0
        lines=raw.decode().splitlines(); summary=lines[0].split()
        assert summary[0]=='SUMMARY' and len(summary)==14
        cid,n,steps=map(int,summary[1:4]); vals=list(map(float,summary[4:]))
        dt,kf,alpha,start,total,decay,bottom,balance,residual,expected=vals
        assert (cid,n,steps)==(c['case'],c['n'],round(2/c['dt'])) and dt==c['dt']
        assert (kf,alpha)==((0.,.01) if cid==1 else (.2,.02))
        arr=np.array([[float(v) for v in row.split()[2:]] for row in lines[1:]])
        assert arr.shape==(n,4) and np.isfinite(arr).all() and (arr[:,1:]>=0).all()
        assert all(math.isfinite(v) for v in vals)
        assert all(row.split()[0]=='PROFILE' for row in lines[1:])
        assert [int(row.split()[1]) for row in lines[1:]]==list(range(1,n+1))
        h=40/n; concentration=arr[:,1]
        assert np.max(np.abs(arr[:,0]-(np.arange(n)+.5)*h))<1e-13
        assert np.max(np.abs(arr[:,2]-.25*h*concentration))<1e-13
        assert np.max(np.abs(arr[:,3]-1.3*kf*h*concentration))<1e-12
        assert abs(np.sum(arr[:,2:])-total)<1e-12
        assert max(abs(residual),abs(total+decay+bottom-start),abs(total-expected),balance)<1e-10
        maxima=max(maxima,balance); cumul=max(cumul,abs(residual))
        key=(cid,n)
        if key not in exact:
            exact[key]=expm(matrix(n,kf,alpha)*2)@gaussian(n,kf,alpha,0)
            analytic[key]=gaussian(n,kf,alpha,2)
        assert abs(start-(.25+1.3*kf)*h*np.sum(gaussian(n,kf,alpha,0)))<1e-12
        # A separately assembled dense backward-Euler solve checks the actual
        # coarse-time trajectory, not just an empirical convergence slope.
        if c['axis']=='time' and dt==.2:
            step=np.eye(n)-dt*matrix(n,kf,alpha)
            oracle=gaussian(n,kf,alpha,0)
            for _ in range(steps):oracle=np.linalg.solve(step,oracle)
            assert np.max(np.abs(concentration-oracle))<1e-12
        spatial=h*np.sum(np.abs(exact[key]-analytic[key]))
        temporal=h*np.sum(np.abs(concentration-exact[key]))
        combined=h*np.sum(np.abs(concentration-analytic[key]))
        peak=float(np.max(concentration)); exact_peak=float(np.max(analytic[key]))
        r=dict(n=n,dt=dt,spatial_l1=spatial,temporal_l1=temporal,combined_l1=combined,
               peak=peak,analytic_peak=exact_peak,peak_relative_deficit=1-peak/exact_peak)
        results.setdefault(c['optimization'],{}).setdefault(str(cid),{}).setdefault(c['axis'],[]).append(r)
        profiles[(c['optimization'],cid,c['axis'],n,dt)]=concentration
    assert len(profiles)==36
    for (opt,cid,axis,n,dt),p in profiles.items():
        if opt=='O0': assert np.max(np.abs(p-profiles[('O2',cid,axis,n,dt)]))<1e-12
    for opt,cases in results.items():
        for cid,axes in cases.items():
            for axis,rows in axes.items():
                assert len(rows)==(4 if axis=='space' else 5)
                error=axis=='space' and 'spatial_l1' or 'temporal_l1'
                for a,b in zip(rows,rows[1:]): assert b[error]<.85*a[error],(opt,cid,axis,a,b)
                for a,b in zip(rows,rows[1:]): b['observed_order']=math.log(a[error]/b[error],2)
                if axis=='space':
                    assert all(r['temporal_l1']<.03*r['spatial_l1'] for r in rows)
                    assert all(b['combined_l1']<a['combined_l1'] for a,b in zip(rows,rows[1:]))
    return dict(status='LINEAR_PROCESS_SEPARATE_SPACE_TIME_ACCURACY_O0_O2_PASS',profiles=36,
                results=results,max_step_mass_residual_mg_cm2=maxima,max_cumulative_mass_residual_mg_cm2=cumul,
                domain_tail_bound='Gaussian boundary concentration <1e-40 over t=0..2d; finite-boundary mismatch not asserted zero',
                full_native_grid_convergence=False,nonlinear_Freundlich_accuracy=False,full_mc_sol01_closed=False)

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path);ap.add_argument('--verify-only',action='store_true')
    ap.add_argument('--capsule',type=Path);ap.add_argument('--expected-sha256');a=ap.parse_args()
    if a.capsule:
        raw=base64.b64decode(a.capsule.read_bytes());assert a.expected_sha256 and hashlib.sha256(raw).hexdigest()==a.expected_sha256
        with tarfile.open(fileobj=io.BytesIO(raw),mode='r:xz') as archive:
            members=archive.getmembers()
            assert len(members)==len({m.name for m in members}) and all(m.isfile() and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts for m in members)
            files={m.name:archive.extractfile(m).read() for m in members}
        manifest=json.loads(files.pop('MANIFEST.json'))
        assert manifest=={p:hashlib.sha256(v).hexdigest() for p,v in files.items()}
        execution=json.loads(files['execution.json'])
        for p,h in execution['inputs'].items():assert hashlib.sha256(files['source/'+p]).hexdigest()==h
        with tempfile.TemporaryDirectory() as name:
            folder=Path(name)
            for p,v in files.items():
                q=folder/p;q.parent.mkdir(parents=True,exist_ok=True);q.write_bytes(v)
            result=assess(folder)
        assert result==json.loads(files['result.json'])
        print(json.dumps({k:v for k,v in result.items() if k!='results'},indent=2));return
    assert a.output
    out=a.output.resolve()
    if not a.verify_only:
        out.mkdir(parents=True,exist_ok=False)
        path=ROOT/'tests/support/augment_bartholomeus_backend_sources.py'
        spec=importlib.util.spec_from_file_location('dep',path);dep=importlib.util.module_from_spec(spec);spec.loader.exec_module(dep)
        sources,_=dep.strict_closure(ROOT,[str(HERE/'driver.f90')],[])
        inputs=[*sources,Path(__file__),path]
        report=dict(status='BUILDING',baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
                    inputs={str(p.relative_to(ROOT)):sha(p) for p in inputs},provider_count=len(sources)-1,
                    compiler=os.environ.get('FC','gfortran'),numpy=np.__version__,scipy=scipy.__version__,events=[],cases=[])
        def save():(out/'execution.json').write_text(json.dumps(report,indent=2)+'\n')
        def run(cmd,cwd):
            t=time.monotonic();r=subprocess.run(list(map(str,cmd)),cwd=cwd,capture_output=True,timeout=120)
            i=len(report['events']);stem=f'{i:03d}'
            for stream in ['stdout','stderr']:(out/(stem+'.'+stream)).write_bytes(getattr(r,stream))
            event=dict(command=list(map(str,cmd)),seconds=time.monotonic()-t,returncode=r.returncode,stdout=stem+'.stdout',stderr=stem+'.stderr')
            report['events'].append(event);save();assert r.returncode==0,(event,r.stderr.decode())
            return event,r.stdout
        save();run([report['compiler'],'--version'],out)
        for opt in ['O0','O2']:
            folder=out/opt;folder.mkdir();exe=folder/'transport'
            run([report['compiler'],'-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(folder),*sources,'-o',exe],folder)
            for cid in [1,2]:
                for axis,grid in [('space',[(n,.002) for n in [40,80,160,320]]),('time',[(80,dt) for dt in [.2,.1,.05,.025,.0125]])]:
                    for n,dt in grid:
                        event,raw=run([exe,str(n),str(dt),str(cid)],folder)
                        report['cases'].append(dict(**event,optimization=opt,case=cid,n=n,dt=dt,axis=axis,sha256=hashlib.sha256(raw).hexdigest()));save()
        report['status']='EXECUTED';save()
    result=assess(out);(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({k:v for k,v in result.items() if k!='results'},indent=2))
if __name__=='__main__':main()
