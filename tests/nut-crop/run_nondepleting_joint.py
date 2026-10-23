"""Fresh Richards/crop/soil execution using byte-bound current HIST provider objects."""
from pathlib import Path
import argparse,hashlib,json,os,resource,subprocess,time,struct
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--providers',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
PROVIDERS=a.providers.resolve();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False);events=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((PROVIDERS/'result.json').read_text());assert r['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
for p,h in r['input_sha256'].items():assert sha(ROOT/p)==h,('current provider closure changed',p)
prior=json.loads((PROVIDERS/'events.json').read_text());assert all(e['returncode']==0 for e in prior)
inputs={**r['input_sha256']}
for p in ['tests/nut-crop/nondepleting_joint.inc','tests/nut-crop/run_nondepleting_joint.py']:inputs[p]=sha(ROOT/p)
text=(ROOT/'tests/nut-crop/test_b112_retained_joint.f90').read_text()
at=text.index(" if(trim(selected)=='source-profile'")
text=text[:at]+" if(trim(selected)=='compete'.or.trim(selected)=='immobilise')then\n  call nondepleting_joint()\n  stop\n end if\n"+text[at:]
text=text.replace('\ncontains\n',"\ncontains\n include 'nondepleting_joint.inc'\n",1)
driver=OUT/'driver.f90';driver.write_text(text)
FC=os.environ.get('FC','gfortran')
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
def run(cmd,b,kind):
 t=time.perf_counter();e=subprocess.run(list(map(str,cmd)),cwd=b,capture_output=True,timeout=120);row=dict(command=list(map(str,cmd)),category=kind,seconds=time.perf_counter()-t,returncode=e.returncode)
 for k in ['stdout','stderr']:
  name=f'{len(events):04d}.{k}';(OUT/name).write_bytes(getattr(e,k));row[k]=name
 events.append(row);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n');assert e.returncode==0,(row,e.stdout.decode(),e.stderr.decode())
 return e.stdout
results={};builds={}
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();provider=PROVIDERS/opt
 link=next(e['command']for e in prior if e['category']=='link'and e['command'][-1]==str(provider/'hist'))
 flags=link[1:link.index(next(c for c in link if c.endswith('.o')))];objects=[Path(c)for c in link if c.endswith('.o')][:-1]
 compile_inputs={str(x):sha(x)for x in objects}
 compile_inputs.update({str(x):sha(x)for x in provider.glob('*.mod')})
 obj=b/'driver.o';exe=b/'joint'
 run([FC,*flags,'-c',driver,'-o',obj],b,'compile');run([FC,*flags,*objects,obj,'-o',exe],b,'link')
 for p,h in compile_inputs.items():assert sha(Path(p))==h,'provider object/module changed during build'
 builds[opt]=dict(provider_result_sha256=sha(PROVIDERS/'result.json'),objects_and_modules=compile_inputs,driver_sha256=sha(driver),flags=flags)
 for case in ['compete','immobilise']:
  checkpoint=b/(case+'.restart');endpoint=b/(case+'.endpoint')
  out=run([exe,'write',checkpoint,endpoint,case],b,'native');assert b'NONDEPLETING_COMPETING_JOINT_PASS'in out
  for day in [1,4]:
   dest=b/(case+'.fresh-'+str(day));run([exe,'resume',str(checkpoint)+'.'+str(day),dest,case,str(day)],b,'restart_native')
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(dest)+suffix).read_bytes(),'process restart drift'
  for day in [2,5]:
   before=Path(str(checkpoint)+'.before-'+str(day)).read_bytes()
   for kind in ['exhaust','stale','water']:assert before==Path(str(checkpoint)+'.'+kind+'-reject-'+str(day)).read_bytes(),'rejection leaked committed state'
  ledger=struct.unpack('14d',Path(str(endpoint)+'.ledger').read_bytes());assert ledger[3]>0 and ledger[11]<1e-12 and ledger[12]<1e-10
  assert ledger[9:11]==(0.,0.)and ledger[7]<0 and ledger[8]<0
  if case=='immobilise':assert ledger[4]<0
  if opt=='O2':
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(OUT/'O0'/(case+'.endpoint'))+suffix).read_bytes(),'optimization drift'
  results[opt+'/'+case]=dict(endpoint_sha256=sha(endpoint),ledger=list(ledger),ledger_sha256=sha(Path(str(endpoint)+'.ledger')))
result=dict(status='NONDEPLETING_ACTUAL_CROP_RICHARDS_IMMOBILISATION_O0_O2_PASS',input_sha256=inputs,builds=builds,results=results,actual_runs=4,separate_process_restarts=8,days_per_run=8,opaque_native_endpoints_exact=True,exhaustion_stale_water_rejections_byte_exact=True)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k not in ['input_sha256','builds','results']}))
