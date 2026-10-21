"""Current finite-donor production, incumbent native preservation and real joint continuation."""
from pathlib import Path
import argparse,base64,hashlib,io,json,os,re,subprocess,sys,tarfile,time

ROOT=Path(__file__).resolve().parents[2]
ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--output',type=Path,required=True)
ap.add_argument('--reference-result',type=Path,required=True)
ap.add_argument('--direct-only',action='store_true')
ap.add_argument('--reuse-physical',type=Path,help='Exact completed incumbent matrix from the same live execution; verify every source and module/object')
a=ap.parse_args();OUT=a.output.resolve();OUT.mkdir(parents=True,exist_ok=False)
reference=a.reference_result.resolve()
ref=json.loads((reference/'result.json').read_text())
assert ref['native_models']==14 and ref['native_N_steps']==120
sha=lambda b:hashlib.sha256(b).hexdigest()
FC=os.environ.get('FC','gfortran');events=[];inputs={}

def event(command,cwd,category,stdin=None,env=None):
 command=list(map(str,command));t=time.perf_counter()
 exe=Path(command[0])
 if exe.is_file()and exe.is_relative_to(OUT)and exe.read_bytes()[:4]==b'\x7fELF':exe.chmod(0o755)
 r=subprocess.run(command,cwd=cwd,input=stdin,capture_output=True,env=env)
 e=dict(command=command,category=category,returncode=r.returncode,seconds=time.perf_counter()-t)
 for stream in ['stdout','stderr']:
  name=f'{len(events):04d}.{stream}';b=getattr(r,stream);(OUT/name).write_bytes(b)
  e[stream]=name;e[stream+'_sha256']=sha(b)
 events.append(e);(OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:raise RuntimeError('retained failed event '+str(len(events)-1)+' '+r.stdout.decode(errors='replace')+r.stderr.decode(errors='replace'))
 return r.stdout

def input_path(p):
 if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p.read_bytes())

driver=ROOT/'tests/nut-mineral/test_negative_boundary.f90'
driver_text=driver.read_text();input_path(driver)
direct={}
for opt in ['O0','O2']:
 b=OUT/('direct-'+opt);b.mkdir()
 fixture=b/'fixture.f90';fixture.write_text(driver_text[:driver_text.index('program test_negative_boundary')])
 actual=b/'driver.f90';actual.write_text(driver_text[driver_text.index('program test_negative_boundary'):])
 oracle=b/'watern.f90';oracle.write_bytes((reference/'corrected/wofost_soil_watern.f90').read_bytes())
 flags=['-'+opt,'-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b)]
 providers=[ROOT/'src/process'/('mod_'+name+'.f90')for name in ['soil_n_pool_state','b111_soil_n_storage_conversion','b111_soil_n_transport','b111_soil_n_mineral_owner']]
 objects=[]
 for i,p in enumerate([fixture,oracle,*providers,actual]):
  obj=b/f'{i}.o';strict=['-Wall','-Wextra','-Werror']if p in providers else []
  event([FC,*flags,*strict,'-c',p,'-o',obj],b,'direct_compile');objects.append(obj);input_path(p)
 exe=b/'direct';event([FC,*flags,*objects,'-o',exe],b,'direct_link')
 out=event([exe],b,'direct_native',(reference/'direct-input.txt').read_bytes())
 assert b'FINITE_DONOR_REFERENCE_84_OWNER_ATOMIC_OPAQUE=PASS'in out
 direct[opt]=out.decode()
assert direct['O0']==direct['O2']

joint={}
if not a.direct_only:
 capsule=ROOT/'integration/audits/evidence/MC_NUT01_REPRODUCTIVE_PROCESS_SCIENCE_20261016.tar.xz.b64'
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(capsule.read_bytes())))as t:
  literal=t.extractfile('process/literal.f90').read()
 (OUT/'literal.f90').write_bytes(literal)
 env={**os.environ,'N_HIST_RESULT_DIR':str(OUT/'physical'),'REPRODUCTIVE_LITERAL_FILE':str(OUT/'literal.f90'),
      'REPRODUCTIVE_LITERAL_SHA256':sha(literal),'PYTHONDONTWRITEBYTECODE':'1','OMP_NUM_THREADS':'1'}
 physical_root=OUT/'physical'
 if a.reuse_physical:
  physical_root=a.reuse_physical.resolve()
  reuse={'result_sha256':sha((physical_root/'result.json').read_bytes()),
         'events_sha256':sha((physical_root/'events.json').read_bytes()),'artifacts':{}}
  for p in physical_root.rglob('*'):
   if p.suffix in ['.o','.mod']:reuse['artifacts'][str(p.relative_to(physical_root))]=sha(p.read_bytes())
  assert reuse['artifacts']
  (OUT/'PHYSICAL_REUSE.json').write_text(json.dumps(reuse,indent=2)+'\n')
 else:
  event([sys.executable,'-B',ROOT/'tests/nut-crop/run_hist_complete.py'],ROOT,'incumbent_physical',env=env)
 physical=json.loads((physical_root/'result.json').read_text())
 assert physical['status']=='HIST_BOUNDED_PHYSICAL_PASS_NOT_FULL_MIGRATION'
 for p,h in physical['input_sha256'].items():assert sha((ROOT/p).read_bytes())==h
 inputs.update(physical['input_sha256'])
 old_driver=ROOT/'tests/nut-crop/test_b112_retained_joint.f90';include=ROOT/'tests/nut-crop/negative_joint.inc'
 text=old_driver.read_text()
 anchor=" if(trim(selected)=='source-profile'.or."
 index=text.index(anchor)
 text=text[:index]+" if(trim(selected)=='negative-low'.or.trim(selected)=='negative-high')then\n  call negative_joint()\n  stop\n end if\n"+text[index:]
 assert text.count('\ncontains\n')==1
 text=text.replace('\ncontains\n',"\ncontains\n include 'negative_joint.inc'\n",1)
 (OUT/'negative_driver.f90').write_text(text)
 input_path(include);input_path(old_driver)
 ee=json.loads((physical_root/'events.json').read_text())
 for opt in ['O0','O2']:
  providers=physical_root/opt
  b=OUT/('joint-'+opt);b.mkdir()
  link=next(e['command']for e in ee if e['category']=='link'and e['command'][-1]==str(providers/'hist'))
  objects=[x for x in link if x.endswith('.o')][:-1]
  flags=link[1:link.index(objects[0])]+['-I'+str(ROOT/'tests/nut-crop')]
  obj=b/'negative_driver.o';exe=b/'negative'
  event([FC,*flags,'-c',OUT/'negative_driver.f90','-o',obj],b,'joint_compile')
  event([FC,*flags,*objects,obj,'-o',exe],b,'joint_link')
  invalid_driver=ROOT/'tests/nut-reactive/test_finite_donor_invalid.f90'
  invalid_object=b/'invalid.o';invalid_exe=b/'invalid'
  event([FC,*flags,'-c',invalid_driver,'-o',invalid_object],b,'joint_compile')
  event([FC,*flags,*objects,invalid_object,'-o',invalid_exe],b,'joint_link')
  invalid_out=event([invalid_exe],b,'invalid_native')
  assert b'FINITE_DONOR_NONFINITE_ROOT_REJECTED=PASS'in invalid_out
  input_path(invalid_driver)
  for name in ['negative-low','negative-high']:
   path=b/(name+'.restart');endpoint=b/(name+'.endpoint')
   out=event([exe,'write',path,endpoint,name],b,'joint_native')
   assert b'FINITE_DONOR_ACTUAL_RICHARDS_RETIRED_CROP_N_RESTART=PASS'in out
   for day in [3,7]:
    before=Path(str(path)+'.before-'+str(day)).read_bytes()
    assert before==Path(str(path)+'.water-reject-'+str(day)).read_bytes()==Path(str(path)+'.chemical-reject-'+str(day)).read_bytes()
   for day in [1,6]:
    fresh=b/(name+'.fresh-'+str(day))
    resumed=event([exe,'resume',str(path)+'.'+str(day),fresh,name,str(day)],b,'restart_native')
    assert endpoint.read_bytes()==fresh.read_bytes(),'joint native endpoint drift'
    assert Path(str(endpoint)+'.ledger').read_bytes()==Path(str(fresh)+'.ledger').read_bytes(),'joint cumulative flux restart drift'
   joint[opt+'/'+name]=dict(stdout=out.decode(),endpoint_sha256=sha(endpoint.read_bytes()),
       ledger_sha256=sha(Path(str(endpoint)+'.ledger').read_bytes()))
 for name in ['negative-low','negative-high']:
  assert joint['O0/'+name]==joint['O2/'+name],'joint optimization drift'
 if a.reuse_physical:
  assert all(sha((physical_root/p).read_bytes())==h for p,h in reuse['artifacts'].items()), 'reused provider artifact changed'
input_path(Path(__file__))
result=dict(status='FINITE_DONOR_DIRECT_PASS'if a.direct_only else'FINITE_DONOR_PRODUCTION_LOCAL_PASS_NOT_ADMITTED',
 execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),
 direct=direct,joint=joint,input_sha256=inputs,reference_execution=ref['execution_commit'],
 compiler=subprocess.check_output([FC,'--version'],text=True).splitlines()[0],full_capability=False)
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'])
