#!/usr/bin/env python3
"""Source-corrected reference first, then real process/runtime qualification."""
import base64,hashlib,io,json,os,pathlib,re,shlex,subprocess,tarfile,time,sys,struct,zlib
ROOT=pathlib.Path(__file__).resolve().parents[2]
OUT=pathlib.Path(os.environ.get('REACTIVE_RESULT_DIR',str(ROOT.parent/'reactive-evidence'))).resolve();OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={}
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def cmd(args,cwd,category):
 args=list(map(str,args));t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 (OUT/f'{i:04d}.stdout').write_bytes(r.stdout);(OUT/f'{i:04d}.stderr').write_bytes(r.stderr)
 events.append(dict(category=category,seconds=time.perf_counter()-t,returncode=r.returncode,command=args,stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode(errors='replace'));print(r.stderr.decode(errors='replace'));raise RuntimeError('command failed; retained event '+str(i))
 return r.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
pins={'wofost_soil_declarations.f90':'0f24a437b1374fcb92dfdb760ca960a602c8e97ce03baa934093065af85c527d','wofost_soil_orgmatn.f90':'85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6','wofost_soil_rateconstants.f90':'0d869c9acbf290b731c2e7344a0a9df7413eba4da44dcd48d124da994f4adcc6','wofost_soil_watern.f90':'b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722'}
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())),mode='r:gz')as a:raws={n:a.extractfile('SWAP/'+n).read()for n in pins}
assert all(hashlib.sha256(b).hexdigest()==pins[n]for n,b in raws.items())
old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio'
new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
assert raws['wofost_soil_orgmatn.f90'].count(old)==1
corrected=raws['wofost_soil_orgmatn.f90'].replace(old,new)
correction={'reference':'MC-NUT01-R1','preimage_sha256':pins['wofost_soil_orgmatn.f90'],'postimage_sha256':hashlib.sha256(corrected).hexdigest(),'exact_preimage':old.decode(),'exact_postimage':new.decode(),'replacement_count':1,'global_reference_manifest_changed':False}
(OUT/'reference_correction.json').write_text(json.dumps(correction,indent=2)+'\n')
results={'execution_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),'source_tree':subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),'compiler':subprocess.check_output(FC+['--version'],text=True).splitlines()[0],'authority':pins,'reference_correction':correction,'runs':{}}
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir(exist_ok=True)
 for n,b in raws.items():(build/n).write_bytes(b)
 original=build/'orgmatn_original.f90';original.write_bytes(raws['wofost_soil_orgmatn.f90'])
 oracle=build/'wofost_soil_orgmatn.f90';oracle.write_bytes(corrected)
 fixture=build/'oracle_fixture.f90';fixture.write_text('module MOD_texture_orgmat\n use iso_fortran_env,only:real64\n real(real64)::bdens(1)\nend module\nsubroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(ROOT/'tests/nut-reactive')]
 decl=build/'wofost_soil_declarations.f90';declobj=build/'declarations.o'
 cmd(FC+flags+['-c',decl,'-o',declobj],build,'reference_compile')
 witness=ROOT/'tests/nut-reactive/test_organic_reference.f90';wobj=build/'witness.o';cmd(FC+flags+['-c',witness,'-o',wobj],build,'reference_compile')
 witnesses={}
 for mode,src in [('legacy',original),('corrected',oracle)]:
  obj=build/(mode+'.o');exe=build/('reference-'+mode)
  cmd(FC+flags+['-c',src,'-o',obj],build,'reference_compile');cmd(FC+flags+[declobj,obj,wobj,'-o',exe],build,'reference_link')
  witnesses[mode]=cmd([exe,mode],build,'reference_native')
 assert 'ORIGINAL_ORGANIC_REFERENCE_DEFECT_WITNESS=PASS'in witnesses['legacy']
 assert 'CORRECTED_ORGANIC_REFERENCE_WHOLE_N=PASS'in witnesses['corrected']
 text=(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text()
 text=text.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 stub=build/'reactive_grid_stubs.f90';stub.write_text(text[:text.index('subroutine swap_error(origin, message)')])
 providers={}
 for p in list((ROOT/'src').rglob('*.f90'))+[fixture,decl,stub]:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
 def closure(driver):
  ordered=[];seen=set();active=set()
  def visit(p):
   if p in seen:return
   if p in active:raise RuntimeError('module cycle '+str(p))
   active.add(p)
   for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
    if name.lower()in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
    q=providers.get(name.lower())
    if q is None:raise RuntimeError('unresolved '+name)
    if q!=p:visit(q)
   active.remove(p);seen.add(p);ordered.append(p)
  visit(driver);ordered.remove(driver)
  # USE in source includes is not seen by the module scanner. Pin explicit literal providers.
  for p in [fixture,decl]:
   if p not in ordered:ordered.append(p)
  ordered.extend([oracle,build/'wofost_soil_rateconstants.f90',build/'wofost_soil_watern.f90'])
  return ordered
 outputs={'reference':witnesses}
 drivers=[ROOT/'tests/nut-reactive/test_reactive_owner.f90']
 if '--direct'not in sys.argv:drivers.append(ROOT/'tests/nut-reactive/test_reactive_joint.f90')
 for driver in drivers:
  physical=driver.stem.endswith('joint');category='physical'if physical else'direct'
  if physical:
   source=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';text=source.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
   (build/'matrix_fixture.inc').write_text(text[start:end]+'\n');inputs[str(source.relative_to(ROOT))]=sha(source)
  ordered=closure(driver)
  if physical:ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
  objects=[]
  for i,p in enumerate(ordered):
   obj=build/(category+str(i)+'.o');objects.append(obj)
   strict=['-Wall','-Wextra','-Werror']if p.name in ['mod_b111_soil_n_reactive_owner.f90','mod_b111_soil_n_organic_rate_environment.f90','mod_fmr_b111_reactive_n_route.f90']else[]
   cmd(FC+flags+strict+['-c',p,'-o',obj],build,category+'_compile')
   if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
  obj=build/(category+'-driver.o');exe=build/driver.stem
  cmd(FC+flags+['-c',driver,'-o',obj],build,category+'_compile');cmd(FC+flags+objects+[obj,'-o',exe],build,category+'_link')
  inputs[str(driver.relative_to(ROOT))]=sha(driver)
  if not physical:
   output=cmd([exe],build,'direct_native');assert 'REACTIVE_LITERAL_16_ENVIRONMENTS_TRANSPORT_OFF_MASS_IMMOBILISATION_RESTART=PASS'in output
   outputs['direct_stdout']=output;outputs['direct_production_provider_count']=len([p for p in ordered if p.is_relative_to(ROOT/'src')])
  else:
   restart=build/'restart.bin';endpoint=build/'expected.bin';fresh=build/'fresh.bin'
   output=cmd([exe,'write',restart,endpoint],build,'physical_native');assert 'REACTIVE_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'in output
   resumed=cmd([exe,'resume',restart,fresh],build,'physical_native');assert 'REACTIVE_FRESH_PROCESS_CONTINUATION=PASS'in resumed
   assert endpoint.read_bytes()==fresh.read_bytes()==pathlib.Path(str(endpoint)+'.opaque').read_bytes()
   assert pathlib.Path(str(endpoint)+'.off-old').read_bytes()==pathlib.Path(str(endpoint)+'.off-new').read_bytes()
   # Original admitted physical driver, fresh native execution on the shared verified build.
   olddriver=ROOT/'tests/nut-mineral/test_mineral_joint.f90';oldobj=build/'original-mineral-driver.o';oldexe=build/'original-mineral-driver'
   cmd(FC+flags+['-c',olddriver,'-o',oldobj],build,'incumbent_compile')
   cmd(FC+flags+objects+[oldobj,'-o',oldexe],build,'incumbent_link')
   oldrestart=build/'mineral-restart.bin';oldendpoint=build/'mineral-expected.bin';oldfresh=build/'mineral-fresh.bin'
   oldstdout=cmd([oldexe,'write',oldrestart,oldendpoint],build,'incumbent_native')
   assert 'MINERAL_ACTUAL_RICHARDS_DAILY_ATOMIC_OPAQUE_DISK=PASS'in oldstdout
   oldresume=cmd([oldexe,'resume',oldrestart,oldfresh],build,'incumbent_native')
   assert 'MINERAL_FRESH_PROCESS_CONTINUATION=PASS'in oldresume
   assert oldendpoint.read_bytes()==oldfresh.read_bytes()==pathlib.Path(str(oldendpoint)+'.opaque').read_bytes()
   cap=ROOT/'integration/audits/evidence/MC_NUT01_MINERAL_TRANSPORT_20261015.tar.xz.b64'
   with tarfile.open(fileobj=io.BytesIO(base64.b64decode(cap.read_bytes())),mode='r:xz')as a:
    assert oldendpoint.read_bytes()==a.extractfile(opt+'/expected.bin').read()
    assert oldrestart.read_bytes()==a.extractfile(opt+'/restart.bin').read()
   oldraw=oldrestart.read_bytes();oldcount=struct.unpack_from('i',oldraw,296)[0];oldwater=300+8*oldcount
   oldneg={'truncated':oldraw[:-12]};damaged=bytearray(oldraw);damaged[10]^=1;oldneg['crc_corrupt']=bytes(damaged)
   for label,offset,fmt,value in [('water_clock',136,'d',5.0),('node_count',152,'i',100000),('chemical_revision',280,'q',-1),('chemical_clock',288,'d',5.0),('parameter_nan',300,'d',float('nan')),('water_nan',oldwater,'d',float('nan')),('negative_N',oldwater+40,'d',-1.0),('oversized_N',oldwater+40,'d',1e300)]:
    damaged=bytearray(oldraw[:-4]);damaged[offset:offset+struct.calcsize(fmt)]=struct.pack(fmt,value)
    oldneg[label]=bytes(damaged)+struct.pack('I',zlib.crc32(damaged)&0xffffffff)
   for label,data in oldneg.items():
    invalid=build/('old-'+label+'.bin');invalid.write_bytes(data)
    assert 'MINERAL_INVALID_DISK=PASS'in cmd([oldexe,'reject',invalid,oldfresh],build,'incumbent_native')
   inputs[str(olddriver.relative_to(ROOT))]=sha(olddriver)
   outputs.update(incumbent_stdout=oldstdout,incumbent_fresh_stdout=oldresume,incumbent_endpoint_sha256=sha(oldendpoint),incumbent_admitted_byte_identity=True,incumbent_decoder_negatives=list(oldneg),off_endpoint_sha256=sha(pathlib.Path(str(endpoint)+'.off-new')))
   negatives={'truncated':restart.read_bytes()[:-12]};data=bytearray(restart.read_bytes());data[10]^=1;negatives['crc_corrupt']=bytes(data)
   count=struct.unpack_from('i',restart.read_bytes(),296)[0];water_offset=300+8*count
   for label,offset,fmt,value in [('water_clock',136,'d',5.0),('node_count',152,'i',100000),('revision',280,'q',-1),('chemical_clock',288,'d',5.0),('parameter_nan',300,'d',float('nan')),('water_nan',water_offset,'d',float('nan')),('negative_N',water_offset+40,'d',-1.0),('oversized_N',water_offset+40,'d',1e300)]:
    data=bytearray(restart.read_bytes()[:-4]);data[offset:offset+struct.calcsize(fmt)]=struct.pack(fmt,value);negatives[label]=bytes(data)+struct.pack('I',zlib.crc32(data)&0xffffffff)
   for label,data in negatives.items():
    f=build/(label+'.bin');f.write_bytes(data);o=cmd([exe,'reject',f,fresh],build,'physical_native');assert 'REACTIVE_INVALID_DISK=PASS'in o
   outputs.update(physical_stdout=output,fresh_stdout=resumed,fresh_endpoint_sha256=sha(fresh),physical_provider_count=len(ordered),corruption_negatives=list(negatives))
  print(opt,output,flush=True)
 results['runs'][opt]=outputs
for p in (ROOT/'tests/nut-reactive').glob('*.inc'):inputs[str(p.relative_to(ROOT))]=sha(p)
inputs[str(pathlib.Path(__file__).relative_to(ROOT))]=sha(pathlib.Path(__file__))
inputs['tests/nut-reactive/test_organic_reference.f90']=sha(ROOT/'tests/nut-reactive/test_organic_reference.f90')
inputs['tests/modularity/low_air_consistent_grid_stubs.f90']=sha(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90')
results['input_sha256']=inputs;results['cost_seconds']={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})}
results['o0_o2_endpoint_identity']=True if '--direct'in sys.argv else (OUT/'O0/expected.bin').read_bytes()==(OUT/'O2/expected.bin').read_bytes()
assert results['o0_o2_endpoint_identity'];results['status']='DIRECT_PASS'if '--direct'in sys.argv else'SCOPED_REACTIVE_QUALIFICATION_PASS_NOT_ADMITTED'
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n');print(results['status'])
