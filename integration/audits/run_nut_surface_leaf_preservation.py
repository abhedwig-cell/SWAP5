"""Exact original-module reference plus current real kernel, O0/O2."""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['N_SURFACE_LEAF_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
SOURCE='src/process/mod_b111_pond_solute_exchange.f90';BASE='e122ff8f682584620717e97ab24ce07933dd0923'
old=subprocess.check_output(['git','show',BASE+':'+SOURCE],cwd=ROOT);assert hashlib.sha256(old).hexdigest()=='7c4c12b2f643d0562bc1c07244ce428271298e1b7635d736fc8a270de16b11af'
reference=OUT/'original_reference.f90';reference.write_bytes(old.replace(b'mod_b111_pond_solute_exchange',b'old_pond_reference'))
driver=ROOT/'integration/audits/test_nut_surface_leaf_preservation.f90';inputs={str(p.relative_to(ROOT)):sha(p)for p in [ROOT/SOURCE,driver,Path(__file__)]};events=[];runs={}
def run(c,b,kind):
 c=list(map(str,c));t=time.perf_counter();r=subprocess.run(c,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=c,category=kind,seconds=time.perf_counter()-t,returncode=r.returncode,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert r.returncode==0,(r.stdout.decode(),r.stderr.decode());return r.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
 for i,p in enumerate([reference,ROOT/SOURCE,driver]):
  obj=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',obj],b,'compile');objects.append(obj)
 exe=b/'preserve';run(['gfortran',*flags,*objects,'-o',exe],b,'link');runs[opt]=run([exe],b,'native')
assert runs['O0']==runs['O2']
for p,h in inputs.items():assert sha(ROOT/p)==h,p
r=dict(status='POND_STABLE_EMPTYING_AND_PREVIOUS_BYTES_O0_O2_PASS_NOT_ADMITTED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,original_commit=BASE,original_sha256=hashlib.sha256(old).hexdigest(),runs=runs,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
