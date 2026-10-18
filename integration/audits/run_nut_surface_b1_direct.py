"""Measured real corrected surface-N owner closure, no inherited native PASS."""
from pathlib import Path
import hashlib,json,os,re,subprocess,time
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['N_SURFACE_RESULT_DIR']).resolve();OUT.mkdir(exist_ok=False)
providers={}
for p in (ROOT/'src').rglob('*.f90'):
 for m in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.I|re.M):providers[m.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for m in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.I|re.M):
  if m.lower() in providers:visit(providers[m.lower()])
 ordered.append(p)
driver=ROOT/'integration/audits/test_nut_surface_b1.f90';visit(driver)
events=[];outputs={}
def run(args,b,category):
 args=list(map(str,args));t=time.perf_counter();p=subprocess.run(args,cwd=b,capture_output=True);i=len(events)
 for st in ['stdout','stderr']:(OUT/f'{i:03d}.{st}').write_bytes(getattr(p,st))
 events.append(dict(command=args,category=category,returncode=p.returncode,seconds=time.perf_counter()-t));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if p.returncode:raise RuntimeError(p.stdout.decode()+p.stderr.decode())
 return p.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)];objects=[]
 for i,p in enumerate(ordered):
  o=b/f'{i}.o';run(['gfortran',*flags,'-c',p,'-o',o],b,'compile');objects.append(o)
 exe=b/'test';run(['gfortran',*flags,*objects,'-o',exe],b,'link');outputs[opt]=run([exe],b,'native')
assert outputs['O0']==outputs['O2']
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=dict(status='SURFACE_N_B1_DIRECT_PASS_NOT_INTEGRATED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),inputs={str(p.relative_to(ROOT)):sha(p) for p in ordered+[Path(__file__)]},outputs=outputs,production_providers=len(ordered)-1,cost_seconds={k:sum(e['seconds'] for e in events if e['category']==k) for k in ['compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
