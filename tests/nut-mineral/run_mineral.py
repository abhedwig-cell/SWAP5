#!/usr/bin/env python3
"""Measured source-oracle/process and actual Richards composition qualification."""
import base64,hashlib,io,json,os,pathlib,re,shlex,subprocess,tarfile,time,sys,struct,zlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=pathlib.Path(os.environ.get('MINERAL_RESULT_DIR',str(ROOT.parent/'mineral-evidence'))).resolve();OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cmd(args,cwd,category):
 t=time.perf_counter();r=subprocess.run(list(map(str,args)),cwd=cwd,capture_output=True)
 i=len(events);(OUT/f'{i:04d}.stdout').write_bytes(r.stdout);(OUT/f'{i:04d}.stderr').write_bytes(r.stderr)
 events.append(dict(category=category,seconds=time.perf_counter()-t,returncode=r.returncode,command=list(map(str,args)),stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode(errors='replace'));print(r.stderr.decode(errors='replace'));r.check_returncode()
 return r.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz') as a:raw=a.extractfile('SWAP/wofost_soil_watern.f90').read()
assert hashlib.sha256(raw).hexdigest()=='b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'
results=dict(source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),baseline=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],authority_sha256=hashlib.sha256(raw).hexdigest(),archive_sha256=sha(archive),runs={})
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir(exist_ok=True)
 oracle=build/'wofost_soil_watern.f90';oracle.write_bytes(raw)
 fixture=build/'oracle_fixture.f90';fixture.write_text('''module MOD_texture_orgmat
 use iso_fortran_env,only:real64
 real(real64)::bdens(1)
end module
subroutine swap_error(a,b)
 character(*),intent(in)::a,b
 print *,a,b
 error stop 1
end subroutine
''')
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build)]
 providers=[ROOT/'src/process'/f'{x}.f90' for x in ['mod_soil_n_pool_state','mod_b111_soil_n_storage_conversion','mod_b111_soil_n_transport','mod_b111_pond_solute_exchange','mod_b111_persistent_pond','mod_soil_n_surface_exchange','mod_b111_soil_n_mineral_owner']]
 objects=[]
 for i,p in enumerate([fixture,oracle]+providers):
  obj=build/f'direct{i}.o';objects.append(obj)
  extra=['-Wall','-Wextra','-Werror'] if p.name in ['mod_soil_n_pool_state.f90','mod_b111_soil_n_storage_conversion.f90','mod_b111_soil_n_transport.f90','mod_b111_soil_n_mineral_owner.f90'] else []
  cmd(FC+flags+extra+['-c',p,'-o',obj],build,'direct_compile')
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
 driver=ROOT/'tests/nut-mineral/test_mineral_owner.f90';inputs[str(driver.relative_to(ROOT))]=sha(driver)
 obj=build/'owner.o';exe=build/'owner'
 cmd(FC+flags+['-c',driver,'-o',obj],build,'direct_compile');cmd(FC+flags+objects+[obj,'-o',exe],build,'direct_link')
 stdout=cmd([exe],build,'direct_native');assert 'MINERAL_FOUR_PROVIDER_LITERAL_ALL_CLASSES_OWNER_BALANCE_ROLLBACK_RESTART=PASS' in stdout
 results['runs'][opt]={'direct_stdout':stdout,'direct_production_provider_count':len(providers)}
 print(opt,stdout,flush=True)
 if '--direct' in sys.argv:continue
 driver=ROOT/'tests/nut-mineral/test_mineral_joint.f90'
 text=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 (build/'matrix_fixture.inc').write_text(text[start:end]+'\n')
 stub_source=ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90'
 stub=build/'mineral_grid_stubs.f90';stub_text=stub_source.read_text()
 stub_text=stub_text.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]')
 stub_text=stub_text.replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]')
 stub_text=stub_text.replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 stub_text=stub_text[:stub_text.index('subroutine swap_error(origin, message)')]
 stub.write_text(stub_text);inputs[str(stub_source.relative_to(ROOT))]=sha(stub_source)
 inputs['tests/physics/test_ppa_wu05d2_mixed_application.f90']=sha(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90')
 sources=list((ROOT/'src').rglob('*.f90'))+[stub]
 mapping={}
 for p in sources:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  if p in active:raise RuntimeError('module cycle '+str(p))
  active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   if name.lower() in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','omp_lib','ieee_exceptions'):continue
   q=mapping.get(name.lower())
   if q is None:raise RuntimeError('unresolved '+name)
   if q!=p:visit(q)
  active.remove(p);seen.add(p);ordered.append(p)
 mapping['mod_texture_orgmat']=fixture
 visit(driver);ordered.remove(driver);ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90');ordered.append(oracle)
 objects=[]
 for i,p in enumerate(ordered):
  obj=build/f'joint{i}.o';objects.append(obj)
  extra=['-Wall','-Wextra','-Werror'] if p.name in ('mod_fmr_b111_mineral_route.f90','mod_fmr_b111_mineral_joint_application.f90','mod_mineral_joint_restart_file.f90') else []
  cmd(FC+flags+extra+['-c',p,'-o',obj],build,'physical_compile');
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
 obj=build/'joint.o';exe=build/'joint'
 cmd(FC+flags+['-c',driver,'-o',obj],build,'physical_compile');cmd(FC+flags+objects+[obj,'-o',exe],build,'physical_link')
 restart=build/'restart.bin';endpoint=build/'expected.bin';fresh=build/'fresh.bin'
 out=cmd([exe,'write',restart,endpoint],build,'physical_native');print(opt,out,flush=True)
 assert 'MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS' in out
 assert 'MINERAL_ACTUAL_LITERAL_AND_NINE_CARRIER_NEGATIVES=PASS' in out
 resumed=cmd([exe,'resume',restart,fresh],build,'physical_native');assert 'MINERAL_FRESH_PROCESS_CONTINUATION=PASS' in resumed
 assert endpoint.read_bytes()==fresh.read_bytes()
 assert endpoint.read_bytes()==pathlib.Path(str(endpoint)+'.opaque').read_bytes()
 raw_restart=restart.read_bytes()
 parameter_count=struct.unpack_from('i',raw_restart,296)[0]
 scalar_offset=300+8*parameter_count
 negatives={'truncated':restart.read_bytes()[:-12]};data=bytearray(restart.read_bytes());data[10]^=1;negatives['crc_corrupt']=bytes(data)
 for label,offset,fmt,value in [('water_clock',136,'d',5.0),('node_count',152,'i',100000),('chemical_revision',280,'q',-1),('chemical_clock',288,'d',5.0),('parameter_nan',300,'d',float('nan')),('water_nan',scalar_offset,'d',float('nan')),('negative_N',scalar_offset+8*(1+2+2),'d',-1.0),('oversized_N',scalar_offset+8*(1+2+2),'d',1e300)]:
  data=bytearray(restart.read_bytes()[:-4]);data[offset:offset+struct.calcsize(fmt)]=struct.pack(fmt,value)
  negatives[label]=bytes(data)+struct.pack('I',zlib.crc32(data)&0xffffffff)
 for label,data in negatives.items():
  path=build/(label+'.bin');path.write_bytes(data);negative=cmd([exe,'reject',path,fresh],build,'physical_native');assert 'MINERAL_INVALID_DISK=PASS' in negative
 inputs[str(driver.relative_to(ROOT))]=sha(driver)
 results['runs'][opt].update(physical_stdout=out,fresh_stdout=resumed,fresh_endpoint_sha256=sha(fresh),physical_provider_count=len(ordered),generated_grid_sha256=sha(stub),generated_fixture_sha256=sha(build/'matrix_fixture.inc'),corruption_negatives=list(negatives))
results['input_sha256']=inputs;results['input_sha256'][str(pathlib.Path(__file__).relative_to(ROOT))]=sha(pathlib.Path(__file__))
results['cost_seconds']={category:sum(e['seconds'] for e in events if e['category']==category) for category in sorted({e['category'] for e in events})}
results['o0_o2_endpoint_identity']=True if '--direct' in sys.argv else (OUT/'O0/expected.bin').read_bytes()==(OUT/'O2/expected.bin').read_bytes()
assert results['o0_o2_endpoint_identity']
results['status']='DIRECT_PASS' if '--direct' in sys.argv else 'SCOPED_LOCAL_QUALIFICATION_PASS_NOT_ADMITTED'
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n');print(results['status'])
