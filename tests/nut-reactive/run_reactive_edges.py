#!/usr/bin/env python3
"""Small independent process edge qualification plus real decoder controls."""
import os,pathlib,subprocess,shlex,re,time,json,hashlib,struct,zlib
ROOT=pathlib.Path(__file__).resolve().parents[2];PRIMARY=pathlib.Path(os.environ['REACTIVE_PRIMARY_DIR']).resolve();OUT=pathlib.Path(os.environ['REACTIVE_EDGE_DIR']).resolve();OUT.mkdir(exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def command(args,cwd,category):
 t=time.perf_counter();r=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True);i=len(events)
 (OUT/f'{i:04d}.stdout').write_bytes(r.stdout);(OUT/f'{i:04d}.stderr').write_bytes(r.stderr)
 events.append({'command':list(map(str,args)),'category':category,'seconds':time.perf_counter()-t,'returncode':r.returncode,'stdout_sha256':hashlib.sha256(r.stdout).hexdigest(),'stderr_sha256':hashlib.sha256(r.stderr).hexdigest(),'stdout_file':f'{i:04d}.stdout','stderr_file':f'{i:04d}.stderr'})
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode());print(r.stderr.decode());raise RuntimeError('edge command failed '+str(i))
 return r.stdout.decode()
primary=json.loads((PRIMARY/'result.json').read_text());assert primary['status']=='SCOPED_REACTIVE_QUALIFICATION_PASS_NOT_ADMITTED'
providers={}
for p in (ROOT/'src').rglob('*.f90'):
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
ordered=[];seen=set()
def visit(p):
 if p in seen:return
 seen.add(p)
 for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
  if name.lower()in ('iso_fortran_env','ieee_arithmetic'):continue
  visit(providers[name.lower()])
 ordered.append(p)
driver=ROOT/'tests/nut-reactive/test_reactive_edges.f90';visit(driver);ordered.remove(driver)
results={'source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'primary_result_sha256':sha(PRIMARY/'result.json'),'runs':{}}
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir(exist_ok=True);flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(ROOT/'tests/nut-reactive')];objects=[]
 for i,p in enumerate(ordered+[driver]):
  obj=build/(str(i)+'.o');objects.append(obj);command(FC+flags+['-c',p,'-o',obj],build,'compile');inputs[str(p.relative_to(ROOT))]=sha(p)
 exe=build/'edges';command(FC+flags+objects+['-o',exe],build,'link');out=command([exe],build,'native')
 assert 'REACTIVE_SUCCESSFUL_IMMOBILISATION_INTERNAL_NITRIFICATION_WATER_COUNTER=PASS'in out
 raw=(PRIMARY/opt/'restart.bin').read_bytes();count=struct.unpack_from('i',raw,296)[0];assert count==38
 for name,index,value in [('organic_rate',15,.05),('reaction_temperature',30,25.0),('enabled_mode',37,0.0)]:
  b=bytearray(raw[:-4]);struct.pack_into('d',b,300+8*index,value);b+=struct.pack('I',zlib.crc32(b)&0xffffffff);path=build/(name+'.bin');path.write_bytes(b)
  negative=command([PRIMARY/opt/'test_reactive_joint','reject',path,build/'unused.bin'],build,'decoder_native')
  assert 'REACTIVE_INVALID_DISK=PASS'in negative
 results['runs'][opt]={'stdout':out,'process_provider_count':len(ordered),'physics_configuration_negatives':['organic_rate','reaction_temperature','enabled_mode']}
for p in [ROOT/'tests/nut-reactive/reactive_parameters.inc',pathlib.Path(__file__)]:inputs[str(p.relative_to(ROOT))]=sha(p)
results['input_sha256']=inputs;results['status']='PASS';results['cost_seconds']={c:sum(e['seconds']for e in events if e['category']==c)for c in ['compile','link','native','decoder_native']}
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
