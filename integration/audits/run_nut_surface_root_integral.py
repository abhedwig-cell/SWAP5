"""One exact ABI-compatible provider rebuild; fresh real route O0/O2 science."""
from pathlib import Path
import hashlib,json,os,subprocess,time
ROOT=Path(__file__).resolve().parents[2];BASE=Path(os.environ['N_SURFACE_PROVIDERS']).resolve()
OUT=Path(os.environ['N_SURFACE_ROOT_DIR']).resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
prior=json.loads((BASE/'result.json').read_text());assert prior['status']=='SURFACE_N_B1_ACTUAL_PHYSICAL_PASS_NOT_ADMITTED'
route='src/runtime/mod_fmr_b111_mineral_route.f90';old=subprocess.check_output(['git','show','01c4b8a1c891b1c29ecab93ae4a77a2a5ed63ea1:'+route],cwd=ROOT)
assert hashlib.sha256(old).hexdigest()==prior['input_sha256'][route]
inputs={}
for p,h in prior['input_sha256'].items():
 if p!=route:assert sha(ROOT/p)==h,p
 inputs[p]=sha(ROOT/p)
for p in [Path(__file__),ROOT/'integration/audits/test_nut_surface_root_integral.f90']:inputs[str(p.relative_to(ROOT))]=sha(p)
origin=json.loads((BASE/'events.json').read_text());assert all(e['returncode']==0 for e in origin)
events=[];artifacts={};runs={}
def run(c,b,category):
 c=list(map(str,c));t=time.perf_counter();p=subprocess.run(c,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i}.{stream}').write_bytes(getattr(p,stream))
 events.append(dict(command=c,category=category,seconds=time.perf_counter()-t,returncode=p.returncode,stdout=f'{i}.stdout',stderr=f'{i}.stderr'));(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 assert p.returncode==0,(category,p.stdout.decode(),p.stderr.decode());return p.stdout.decode()
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();base=BASE/opt;ce=[e for e in origin if e['category']=='compile'and '-'+opt in e['command']]
 original=next(e['command']for e in ce if e['command'][e['command'].index('-c')+1]==str(ROOT/route))
 fc=original[:1];flags=original[1:original.index('-c')];flags=[('-J'+str(b)if x.startswith('-J')else x)for x in flags];flags+=['-I'+str(b)]
 objects=[]
 for e in ce:
  source=Path(e['command'][e['command'].index('-c')+1])
  if source==ROOT/route or source.name=='test_surface_n_rotation.f90':continue
  obj=Path(e['command'][-1]);artifacts[str(obj)]=sha(obj);objects.append(obj)
 for p in base.glob('*.mod'):artifacts[str(p)]=sha(p)
 obj=b/'route.o';run(fc+flags+['-c',ROOT/route,'-o',obj],b,'provider_compile');objects.append(obj)
 assert(b/'mod_fmr_b111_mineral_route.mod').read_bytes()==(base/'mod_fmr_b111_mineral_route.mod').read_bytes(),'public module ABI changed'
 driver=ROOT/'integration/audits/test_nut_surface_root_integral.f90';obj=b/'driver.o';exe=b/'trace'
 run(fc+flags+['-c',driver,'-o',obj],b,'driver_compile');run(fc+flags+objects+[obj,'-o',exe],b,'link');runs[opt]=run([exe],b,'native')
assert runs['O0']==runs['O2']
for p,h in artifacts.items():assert sha(Path(p))==h,p
for p,h in inputs.items():assert sha(ROOT/p)==h,p
r=dict(status='SURFACE_ROOT_DIRECT_PASS_NOT_ADMITTED',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),input_sha256=inputs,reused_artifacts=artifacts,original_result_sha256=sha(BASE/'result.json'),exact_recompiled_provider=route,original_provider_sha256=hashlib.sha256(old).hexdigest(),runs=runs,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in ['provider_compile','driver_compile','link','native']})
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
