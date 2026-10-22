"""Actual cold production harvest/fallow with complete diagnostic-memory restart.

Use a source-bound current cold proof to share compilation only. All new physical
programs execute freshly; cold/native incumbent terminal evidence is kept separate.
"""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,resource,signal,struct,subprocess,tarfile,time,zlib
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser();p.add_argument('--cold',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
COLD=a.cold.resolve();OUT=a.output.resolve();OUT.mkdir(exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
c=json.loads((COLD/'result.json').read_text())
assert c['status']=='NATIVE_TRUE_OUTPUT_PROJECT_O0_O2_FRESH_PASS'
for name,h in c['input_sha256'].items():assert sha(ROOT/name)==h,name
old_events=json.loads((COLD/'events.json').read_text());assert all(e['returncode']==0 for e in old_events)
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as t:
 wofostnut_raw=t.extractfile('SWAP/wofostnut.f90').read()
assert hashlib.sha256(wofostnut_raw).hexdigest()=='071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2'
original=wofostnut_raw.decode('cp1252').replace('\r\n','\n')
for name,start,end in [('dm','            idwrt = idwrt + HarLosOrm_rt','            HarLosNit_rt = anrt'),('n','            inlossl = inlossl + HarLosNit_lv','            anlv = anlv - FraHarLosOrm_lv * anlv')]:
 assert original.count(start)==1 and original.count(end)==1
 (OUT/('original_harvest_'+name+'.inc')).write_text(original[original.index(start):original.index(end)])
resource.setrlimit(resource.RLIMIT_STACK,(64*1024*1024,resource.getrlimit(resource.RLIMIT_STACK)[1]))
imports=' use mod_crop_ext_saved_residue\n use mod_crop_soil_n_saved_harvest\n use mod_crop_n_saved_generation\n use mod_crop_soil_n_saved_output\n use mod_crop_soil_n_output_harvest\n'
s=(COLD/'driver.f90').read_text().replace(' implicit none',imports+' implicit none',1)
s=s.replace('\ncontains\n',"\ncontains\n include 'saved_output_proof.inc'\n",1)
anchor=" if(trim(mode)=='reject')then";assert s.count(anchor)==1
s=s.replace(anchor," if(trim(mode)=='saved-resume'.or.trim(mode)=='saved-reject'.or.trim(mode)=='saved-reject-live')then\n  call saved_resume_mode()\n  stop\n end if\n"+anchor,1)
anchor='  before_n=crop_soil_whole_n(n);before_dm=crop_soil_organic_mass(n)';assert s.count(anchor)==1
s=s.replace(anchor,"  call saved_output_proof(prefix//'.saved',w,n,.false.)\n  call saved_output_proof(prefix//'.deferred',w,n,.true.)\n"+anchor,1)
(OUT/'driver.f90').write_text(s)
events=[];pinned={};results={}
def run(cmd,b,category):
 cmd=list(map(str,cmd));started=time.perf_counter();r=subprocess.run(cmd,cwd=b,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(command=cmd,category=category,returncode=r.returncode,seconds=time.perf_counter()-started,stdout=f'{i:04d}.stdout',stderr=f'{i:04d}.stderr'))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError(str(i)+' '+r.stdout.decode()+r.stderr.decode())
 return r.stdout.decode()
providers=['mod_crop_ext_saved_residue','mod_crop_soil_n_saved_harvest','mod_crop_n_saved_generation','mod_crop_soil_n_output_harvest','mod_crop_soil_n_saved_output']
preload=OUT/'rename-stop.so'
run(['cc','-shared','-fPIC',ROOT/'tests/nut-output/rename_stop.c','-ldl','-o',preload],OUT,'preload_compile')
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir();old=COLD/opt
 link=next(e['command']for e in old_events if e['category']=='link'and e['command'][-1]==str(old/'hist'))
 objects=[v for v in link if v.endswith('.o')][:-1]
 for obj in objects:pinned[obj]=sha(Path(obj))
 for mod in old.glob('*.mod'):pinned[str(mod)]=sha(mod)
 flags=[('-J'+str(b))if v.startswith('-J')else v for v in link[1:link.index(objects[0])]]
 flags+=['-I'+str(old),'-I'+str(OUT),'-I'+str(ROOT/'tests/nut-output')]
 fc=os.environ.get('FC','gfortran');new=[]
 for provider in providers:
  obj=b/(provider+'.o');run([fc,*flags,'-c',ROOT/('src/adapter/'+provider+'.f90'),'-o',obj],b,'provider_compile');new.append(obj)
 driver=b/'driver.o';exe=b/'saved'
 run([fc,*flags,'-c',OUT/'driver.f90','-o',driver],b,'driver_compile')
 run([fc,*flags,*objects,*new,driver,'-o',exe],b,'link')
 restart=b/'original.restart';end=b/'endpoint';fresh=b/'fresh'
 run([exe,'write',restart,end],b,'actual_native')
 run([exe,'resume',restart,fresh],b,'original_fresh')
 assert end.read_bytes()==fresh.read_bytes()==(old/'default.endpoint').read_bytes(),'incumbent physical endpoint changed'
 hashes={}
 for suffix,delayed in [('saved',False),('deferred',True)]:
  prefix=Path(str(end)+'.stages.'+suffix)
  # Recover exact prefix from generated driver's owning call, not a wildcard.
  if not Path(str(prefix)+'.phase-1').exists():prefix=Path(str(end)+'.'+suffix)
  assert Path(str(prefix)+'.before-stage').read_bytes()==Path(str(prefix)+'.failed-stage').read_bytes()
  assert not Path(str(prefix)+'.invalid').exists()
  for phase in [1,2,3]:
   gen=Path(str(prefix)+'.phase-'+str(phase))
   assert gen.read_bytes()==Path(str(prefix)+'.replay-'+str(phase)).read_bytes()
   assert Path(str(prefix)+'.actual-'+str(phase)).read_bytes()==Path(str(prefix)+'.manual-'+str(phase)).read_bytes()
   if phase>1:assert Path(str(prefix)+'.failed-'+str(phase)).read_bytes()==Path(str(prefix)+'.phase-'+str(phase-1)).read_bytes()
   rd=b/(suffix+'-roundtrip-'+str(phase));run([exe,'saved-resume',gen,rd,'','roundtrip'],b,'phase_roundtrip');assert rd.read_bytes()==gen.read_bytes()
   out=b/(suffix+'-continue-'+str(phase));run([exe,'saved-resume',gen,out,'','delayed'if delayed else'continue'],b,'phase_fresh_fallow')
   for day in [3,4]:assert Path(str(out)+'.day-'+str(day)).read_bytes()==Path(str(prefix)+'.day-'+str(day)).read_bytes(),'phase fresh continuation changed'
  for day in [3,4]:
   tag=str(day);before=Path(str(prefix)+'.before-day-'+tag).read_bytes()
   for failed in ['failed-day-','bad-roots-','nan-day-']:assert before==Path(str(prefix)+'.'+failed+tag).read_bytes()
   assert Path(str(prefix)+'.day-'+tag).read_bytes()==Path(str(prefix)+'.replay-day-'+tag).read_bytes()
   assert Path(str(prefix)+'.day-'+tag).read_bytes()==Path(str(prefix)+'.view-day-'+tag).read_bytes()==Path(str(prefix)+'.view-memory-'+tag).read_bytes()
   assert Path(str(prefix)+'.actual-day-'+tag).read_bytes()==Path(str(prefix)+'.manual-day-'+tag).read_bytes()
  gen=Path(str(prefix)+'.day-3');out=b/(suffix+'-day3-continue')
  run([exe,'saved-resume',gen,out,'','delayed'if delayed else'continue'],b,'fallow_fresh')
  assert Path(str(out)+'.day-4').read_bytes()==Path(str(prefix)+'.day-4').read_bytes()
  hashes[suffix]={str(d):sha(Path(str(prefix)+'.day-'+str(d)))for d in [3,4]}
  # Byte corruption plus valid-CRC semantic defects. Both nested codecs execute.
  raw=Path(str(prefix)+'.phase-3').read_bytes()
  cases=[raw[:100],raw+b'x',raw[:8]+b'\0\0\0\0'+raw[12:]]
  for offset,value in [(0,b'BADMAGIC'),(8,struct.pack('<i',-1)),(12,struct.pack('<d',3.)),(20,struct.pack('<d',-1.)),(52,struct.pack('<d',float('nan'))),(84,b'BADINNER')]:
   x=bytearray(raw);x[offset:offset+len(value)]=value;x[-4:]=struct.pack('<I',zlib.crc32(x[:-4]));cases.append(bytes(x))
  for i,x in enumerate(cases):
   bad=b/(suffix+'-invalid-'+str(i));bad.write_bytes(x)
   run([exe,'saved-reject',bad,b/'unused'],b,'invalid_generation')
   live=Path(str(prefix)+'.phase-3');run([exe,'saved-reject-live',bad,live],b,'invalid_live_generation')
   assert live.read_bytes()==Path(str(live)+'.before-invalid').read_bytes()==Path(str(live)+'.after-invalid').read_bytes()
  run([exe,'saved-reject',Path(str(prefix)+'.phase-3'),b/'unused','','wrong-water'],b,'invalid_identity')
 for day in [3,4]:
  assert Path(str(end)+'.stages.saved.actual-day-'+str(day)).read_bytes()==Path(str(end)+'.stages.deferred.actual-day-'+str(day)).read_bytes(),'report schedule changes physics'
 crashes={}
 for phase in ['before','after']:
  case=b/('crash-'+phase);case.mkdir();target=case/'generation'
  old=Path(str(end)+'.stages.saved.phase-2');good=Path(str(end)+'.stages.saved.phase-3')
  target.write_bytes(old.read_bytes())
  env={**os.environ,'LD_PRELOAD':str(preload),'OUTPUT_TEST_TARGET':str(target),'OUTPUT_TEST_PHASE':phase,'OUTPUT_TEST_RENAME_COUNT':'1'}
  started=time.perf_counter()
  with (case/'stdout').open('wb')as out,(case/'stderr').open('wb')as err:
   child=subprocess.Popen([str(exe),'saved-resume',str(good),str(target),'','roundtrip'],cwd=case,stdout=out,stderr=err,env=env)
   _,state=os.waitpid(child.pid,os.WUNTRACED)
   assert os.WIFSTOPPED(state)and os.WSTOPSIG(state)==signal.SIGSTOP,(phase,state,(case/'stderr').read_text())
   child.kill();child.wait();assert child.returncode==-signal.SIGKILL
  want=old if phase=='before'else good
  assert target.read_bytes()==want.read_bytes(),'partial outer generation after crash'
  recovered=case/'recovered';run([exe,'saved-resume',target,recovered,'','roundtrip'],case,'crash_reconstruction')
  assert recovered.read_bytes()==target.read_bytes()
  crashes[phase]=dict(returncode=child.returncode,complete=True,sha256=sha(target))
  (case/'result.json').write_text(json.dumps(dict(**crashes[phase],seconds=time.perf_counter()-started),indent=2)+'\n')
 results[opt]=dict(generations=hashes,crashes=crashes)
assert results['O0']==results['O2'],'saved output optimization drift'
assert all(sha(Path(p))==h for p,h in pinned.items()),'controlled provider artifacts changed'
inputs=['src/adapter/'+p+'.f90'for p in providers]+['tests/nut-output/run_saved_output.py','tests/nut-output/saved_output_proof.inc','tests/nut-output/rename_stop.c',str(archive.relative_to(ROOT))]
r=dict(status='SAVED_HARVEST_FALLOW_OUTPUT_O0_O2_ATOMIC_FRESH_PASS',execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),results=results,incumbent_default_sha256={opt:c['results'][opt]['default_endpoint']for opt in ['O0','O2']},input_sha256={p:sha(ROOT/p)for p in inputs},cold_input_sha256=c['input_sha256'],cold_proof_sha256=sha(COLD/'result.json'),original_wofostnut_sha256=hashlib.sha256(wofostnut_raw).hexdigest(),original_fragment_sha256={p.name:sha(p)for p in OUT.glob('original_harvest_*.inc')},generated_driver_sha256=sha(OUT/'driver.f90'),pinned_artifacts=pinned,cost_seconds={k:sum(e['seconds']for e in events if e['category']==k)for k in sorted({e['category']for e in events})},thermal_selected=False,crash_selected=True,full_work_unit_closed=False)
(OUT/'result.json').write_text(json.dumps(r,indent=2)+'\n');print(r['status'])
