"""Two-provider actual pond kernel replay; no copied production equations."""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['N_SURFACE_LEAF_DIR']).resolve();OUT.mkdir(exist_ok=False)
TRACE=Path(os.environ['N_SURFACE_TRACE_FILE']).resolve();MODE=os.environ.get('N_SURFACE_LEAF_MODE','expect-reject');assert MODE in ['expect-reject','accept']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
providers=[ROOT/'src/process/mod_b111_pond_solute_exchange.f90',ROOT/'src/process/mod_b111_persistent_pond.f90'];driver=ROOT/'integration/audits/test_nut_surface_leaf_trace.f90'
inputs={str(p.relative_to(ROOT)):sha(p)for p in providers+[driver,Path(__file__)]};trace_sha=sha(TRACE);events=[];runs={}
def run(c,b,kind):
 t=time.perf_counter();r=subprocess.run(list(map(str,c)),cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=list(map(str,c)),category=kind,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==0,(r.stdout.decode(),r.stderr.decode());return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
 for i,p in enumerate(providers+[driver]):
  obj=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',obj],b,'compile');objects.append(obj)
 exe=b/'leaf';run(['gfortran',*flags,*objects,'-o',exe],b,'link');runs[opt]=run([exe,TRACE,MODE],b,'native')
assert runs['O0']==runs['O2']
for p,h in inputs.items():assert sha(ROOT/p)==h,p
assert sha(TRACE)==trace_sha
r=dict(status='ORIGINAL_POND_CANCELLATION_WITNESS_CONFIRMED'if MODE=='expect-reject'else'POND_ACTUAL_TRACE_DIRECT_PASS_NOT_ADMITTED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,trace_sha256=trace_sha,runs=runs,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
