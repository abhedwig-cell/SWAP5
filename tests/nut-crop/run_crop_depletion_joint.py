"""Actual crop/N composition with either organic receiving-pool rate zero."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,resource,subprocess,time,struct,tarfile
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--providers',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
PROVIDERS=a.providers.resolve();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False);events=[]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
r=json.loads((PROVIDERS/'result.json').read_text());assert r['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
for p,h in r['input_sha256'].items():assert sha(ROOT/p)==h,('current provider closure changed',p)
prior=json.loads((PROVIDERS/'events.json').read_text());assert all(e['returncode']==0 for e in prior)
inputs={**r['input_sha256']}
for p in ['tests/nut-crop/crop_depletion_joint.inc','tests/nut-crop/run_crop_depletion_joint.py']:inputs[p]=sha(ROOT/p)
text=(ROOT/'tests/nut-crop/test_b112_retained_joint.f90').read_text()
at=text.index(" if(trim(selected)=='source-profile'")
text=text[:at]+" if(trim(selected)=='compete'.or.trim(selected)=='immobilise'.or.trim(selected)=='limited'.or.trim(selected)=='zero_pools'.or.trim(selected)=='all_zero'.or.trim(selected)=='bio_zero'.or.trim(selected)=='hum_zero'.or.trim(selected)=='resonant'.or.trim(selected)=='repeated'.or.trim(selected)=='singular'.or.trim(selected)=='small_det'.or.trim(selected)=='empty_nh4'.or.trim(selected)=='empty_both'.or.trim(selected)=='crop_nh4'.or.trim(selected)=='crop_both')then\n  call crop_depletion_joint()\n  stop\n end if\n"+text[at:]
text=text.replace('\ncontains\n',"\ncontains\n include 'crop_depletion_joint.inc'\n",1)
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
 old=b/'preimage';old.mkdir()
 changes=json.loads((ROOT/'integration/mc-nut01/crop_only_depletion/STATUS.json').read_text())
 oldobjects=list(objects);oldhashes={}
 oldflags=[('-J'+str(old))if f.startswith('-J')else f for f in flags]+['-I'+str(old)]
 for i,changed in enumerate(changes['production_changes']):
  oldsrc=old/(str(i)+'.f90');oldsrc.write_bytes(subprocess.check_output(['git','show',changes['baseline']+':'+changed],cwd=ROOT))
  oldobj=old/(str(i)+'.o');run([FC,*oldflags,'-c',oldsrc,'-o',oldobj],b,'previous_compile')
  entry=next(e['command']for e in prior if e['category']=='compile'and e['command'][e['command'].index('-c')+1]==str(ROOT/changed)and '-'+opt in e['command'])
  replace=Path(entry[entry.index('-o')+1]);assert replace in oldobjects
  oldobjects=[oldobj if p==replace else p for p in oldobjects];oldhashes[changed]=sha(oldsrc)
 oldexe=old/'joint';run([FC,*flags,*oldobjects,obj,'-o',oldexe],b,'previous_link')
 for case in ['crop_nh4','crop_both']:
  probe=old/case;run([oldexe,'probe',probe,old/'unused',case],b,'previous_native')
  assert Path(str(probe)+'.probe-before').read_bytes()==Path(str(probe)+'.probe-after').read_bytes(),'preimage rejection leaked state'
 builds[opt]['previous_source_sha256']=oldhashes
 for case in ['compete','immobilise','limited','zero_pools','all_zero','bio_zero','hum_zero','resonant','repeated','singular','small_det','empty_nh4','empty_both','crop_nh4','crop_both']:
  checkpoint=b/(case+'.restart');endpoint=b/(case+'.endpoint')
  out=run([exe,'write',checkpoint,endpoint,case],b,'native');assert b'NONDEPLETING_COMPETING_JOINT_PASS'in out
  for day in [1,4]:
   dest=b/(case+'.fresh-'+str(day));run([exe,'resume',str(checkpoint)+'.'+str(day),dest,case,str(day)],b,'restart_native')
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(dest)+suffix).read_bytes(),'process restart drift'
  for day in [2,5]:
   before=Path(str(checkpoint)+'.before-'+str(day)).read_bytes()
   for kind in ['exhaust','stale','water']:assert before==Path(str(checkpoint)+'.'+kind+'-reject-'+str(day)).read_bytes(),'rejection leaked committed state'
  ledger=struct.unpack('14d',Path(str(endpoint)+'.ledger').read_bytes());assert (ledger[3]==0 if case=='empty_both'else ledger[3]>0)and ledger[11]<1e-12 and ledger[12]<1e-10
  assert ledger[9:11]==(0.,0.)and(ledger[7]==0 if case in ['empty_nh4','empty_both','crop_nh4','crop_both']else ledger[7]<0)and(ledger[8]==0 if case in ['empty_both','crop_nh4','crop_both']else ledger[8]<0)
  if case in ['immobilise','zero_pools','bio_zero','hum_zero','resonant','repeated','singular','small_det']:assert ledger[4]<0
  if case in ['empty_nh4','empty_both','crop_nh4','crop_both']:assert ledger[4]==0.
  if case=='all_zero':assert ledger[4]==0.
  if opt=='O2':
   for suffix in ['', '.ledger']:assert Path(str(endpoint)+suffix).read_bytes()==Path(str(OUT/'O0'/(case+'.endpoint'))+suffix).read_bytes(),'optimization drift'
  results[opt+'/'+case]=dict(endpoint_sha256=sha(endpoint),ledger=list(ledger),ledger_sha256=sha(Path(str(endpoint)+'.ledger')))
archive=ROOT/'integration/mc-nut01/empty_equilibrium/EVIDENCE.tar.xz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:xz')as t:
 prior=json.loads(t.extractfile('joint/result.json').read())
for key,row in prior['results'].items():
 assert results[key]['endpoint_sha256']==row['endpoint_sha256'] and results[key]['ledger_sha256']==row['ledger_sha256'],'incumbent joint byte drift'
result=dict(status='CROP_DEPLETION_ACTUAL_CROP_IMMOBILISATION_O0_O2_PASS',input_sha256=inputs,builds=builds,results=results,actual_runs=30,separate_process_restarts=60,days_per_run=8,opaque_native_endpoints_exact=True,exhaustion_stale_water_rejections_byte_exact=True)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps({k:v for k,v in result.items()if k not in ['input_sha256','builds','results']}))
