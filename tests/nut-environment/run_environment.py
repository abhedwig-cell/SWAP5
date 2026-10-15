#!/usr/bin/env python3
"""Measured real production closures, original literal soil uptake and WOFOST81."""
from pathlib import Path
import base64,hashlib,io,json,os,re,shlex,subprocess,sys,tarfile,time,struct,zlib,shutil
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nut-crop'))
from prepare_oracle import prepare
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(os.environ.get('N_ENV_RESULT_DIR',str(ROOT.parent/'nut-environment-evidence'))).resolve();OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={};DIRECT='--direct'in sys.argv
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def cmd(args,cwd,category):
 args=list(map(str,args));t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(category=category,command=args,returncode=r.returncode,seconds=time.perf_counter()-t,stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode(errors='replace'));print(r.stderr.decode(errors='replace'));raise RuntimeError('retained failed event '+str(i))
 return r.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'
pins={'wofost_soil_declarations.f90':'0f24a437b1374fcb92dfdb760ca960a602c8e97ce03baa934093065af85c527d','wofost_soil_orgmatn.f90':'85146e95249b41ed9b5202b507cb1647784592a313e36e75010da9bbf9a733f6','wofost_soil_rateconstants.f90':'0d869c9acbf290b731c2e7344a0a9df7413eba4da44dcd48d124da994f4adcc6','wofost_soil_watern.f90':'b343fa9e485e60d76e2bd49067a20cd5ec328264af5d99d7cf1e4ddf07278722','management_soil.f90':'0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'}
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as a:raws={n:a.extractfile('SWAP/'+n).read()for n in pins}
assert all(hashlib.sha256(b).hexdigest()==pins[n]for n,b in raws.items())
old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio';new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
assert raws['wofost_soil_orgmatn.f90'].count(old)==1
results=dict(execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],direct_only=DIRECT,authority=pins,runs={})
for opt in ['O0','O2']:
 build=OUT/opt;build.mkdir(exist_ok=True)
 for n,b in raws.items():(build/n).write_bytes(b)
 (build/'wofost_soil_orgmatn.f90').write_bytes(raws['wofost_soil_orgmatn.f90'].replace(old,new))
 results['literal_uptake_extraction']=prepare(ROOT,build,raws['management_soil.f90'])
 fixture=build/'oracle_fixture.f90';fixture.write_text('module MOD_texture_orgmat\n use iso_fortran_env,only:real64\n real(real64)::bdens(1)\nend module\nsubroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
 decl=build/'wofost_soil_declarations.f90'
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-g','-ffpe-trap=invalid,zero,overflow','-J'+str(build),'-I'+str(build),'-I'+str(ROOT/'tests/nut-environment'),'-I'+str(ROOT/'tests/nut-crop'),'-I'+str(ROOT/'tests/nut-reactive'),'-I'+str(ROOT/'tests/nut-sol')]
 providers={}
 for p in list((ROOT/'src').rglob('*.f90'))+[decl,fixture]:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
 if not DIRECT:
  text=(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text().replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
  stub=build/'reactive_grid_stubs.f90';stub.write_text(text[:text.index('subroutine swap_error(origin, message)')])
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',stub.read_text(),re.M|re.I):providers[name.lower()]=stub
  source=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';text=source.read_text();a=text.index('  subroutine initialize_application_config');b=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing');(build/'matrix_fixture.inc').write_text(text[a:b]+'\n');inputs[str(source.relative_to(ROOT))]=sha(source)
 drivers=[ROOT/'tests/nut-crop/test_crop_soil_day.f90',ROOT/'tests/nut-environment/test_environment_day.f90']
 if not DIRECT:drivers += [ROOT/'tests/nut-environment/test_environment_joint.f90',ROOT/'tests/nut-crop/test_crop_soil_joint.f90',ROOT/'tests/nut-reactive/test_reactive_joint.f90',ROOT/'tests/nut-mineral/test_mineral_joint.f90']
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  if p in active:raise RuntimeError('cycle '+str(p))
  active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   name=name.lower()
   if name in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
   if name not in providers:raise RuntimeError('unresolved '+name)
   if providers[name]!=p:visit(providers[name])
  active.remove(p);seen.add(p);ordered.append(p)
 for d in drivers:visit(d)
 ordered=[p for p in ordered if p not in drivers]
 for p in [decl,fixture]:
  if p not in ordered:ordered.append(p)
 ordered += [build/'wofost_soil_orgmatn.f90',build/'wofost_soil_rateconstants.f90',build/'wofost_soil_watern.f90',build/'literal_crop_exchange.f90']
 if not DIRECT:ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
 objects=[]
 for i,p in enumerate(ordered):
  obj=build/f'provider-{i}.o';objects.append(obj)
  cmd(FC+flags+['-c',p,'-o',obj],build,'compile')
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
 row=dict(production_providers=len([p for p in ordered if p.is_relative_to(ROOT/'src')]),drivers={})
 for d in drivers:
  obj=build/(d.stem+'.o');exe=build/d.stem
  cmd(FC+flags+['-c',d,'-o',obj],build,'driver_compile');cmd(FC+flags+objects+[obj,'-o',exe],build,'link');inputs[str(d.relative_to(ROOT))]=sha(d)
  if d.stem in ['test_crop_soil_day','test_environment_day']:
   output=cmd([exe],build,'native');assert ('DAILY_ENVIRONMENT_LITERAL_SUPPLY_ROLLBACK_IDENTITY=PASS'if d.stem=='test_environment_day'else'CROP_SOIL_REAL_WOFOST81_LITERAL_SUPPLY_FIXATION_LOSS_ROLLBACK_REPLAY=PASS')in output;row['drivers'][d.stem]=dict(stdout=output)
  else:
   restart=build/(d.stem+'-restart.bin');endpoint=build/(d.stem+'-expected.bin');fresh=build/(d.stem+'-fresh.bin')
   output=cmd([exe,'write',restart,endpoint],build,'native')
   continuation=cmd([exe,'resume',restart,fresh],build,'native')
   assert endpoint.read_bytes()==fresh.read_bytes()==Path(str(endpoint)+'.opaque').read_bytes()
   row['drivers'][d.stem]=dict(stdout=output,fresh_stdout=continuation,endpoint_sha256=sha(endpoint),restart_sha256=sha(restart))
   if d.stem in ['test_reactive_joint','test_mineral_joint']:
    capsule='MC_NUT01_REACTIVE_DAY_20261015.tar.xz.b64'if d.stem=='test_reactive_joint'else'MC_NUT01_MINERAL_TRANSPORT_20261015.tar.xz.b64'
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence'/capsule).read_bytes())))as archive:
     assert endpoint.read_bytes()==archive.extractfile(opt+'/expected.bin').read()
    row['drivers'][d.stem]['admitted_endpoint_identity']=True
   if d.stem=='test_crop_soil_joint':
    with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/MC_NUT01_CROP_SUPPLY_20261015.tar.xz.b64').read_bytes())))as archive:
     assert endpoint.read_bytes()==archive.extractfile(opt+'/'+d.stem+'-expected.bin').read()
    row['drivers'][d.stem]['admitted_endpoint_identity']=True
   raw=bytearray(restart.read_bytes());mutants={}
   mutants['truncated']=raw[:len(raw)//2]
   damaged=raw.copy();damaged[140]^=1;mutants['crc_corrupt']=damaged
   def changed(label,offset,fmt,value):
    b=raw.copy();struct.pack_into(fmt,b,offset,value);struct.pack_into('<I',b,len(b)-4,zlib.crc32(b[:-4]));mutants[label]=b
   # Existing bounded native header, exact scalar and physical payload offsets.
   mode,n=struct.unpack_from('<ii',raw,148);has_history=struct.unpack_from('<i',raw,156)[0]
   assert mode in [0,1] and n==4 and has_history in [0,1]
   changed('water_clock',136,'d',123.)
   changed('node_count',152,'i',999999)
   changed('water_nan',160+8*n,'d',float('nan'))
   chemical=160+16*n+16+(8*n if has_history else 0)
   changed('chemical_revision',chemical+8,'q',-1)
   changed('chemical_clock',chemical+16,'d',999.)
   pcount=struct.unpack_from('<i',raw,chemical+24)[0]
   changed('parameter_nan',chemical+28,'d',float('nan'))
   if d.stem in ['test_crop_soil_joint','test_environment_joint']:
    n_fom=2;crop_offset=chemical+28+8*pcount+8+8*n_fom+32
    crop_id,crop_count=struct.unpack_from('<qi',raw,crop_offset)
    changed('crop_identity',crop_offset,'q',999999)
    changed('crop_configuration',crop_offset+12,'d',float('nan'))
    changed('crop_efficiency_knot',crop_offset+12+8*(crop_count-5),'d',.123)
    owner_count_offset=crop_offset+12+8*crop_count
    owner_count=struct.unpack_from('<i',raw,owner_count_offset)[0];owner_offset=owner_count_offset+4
    changed('crop_payload_count',owner_count_offset,'i',999999)
    changed('crop_N_nan',owner_offset+17*8,'d',float('nan'))
    changed('crop_N_unbalanced',owner_offset+17*8,'d',999.)
    changed('crop_cohort_count',owner_offset+25*8,'d',999999.)
    changed('crop_history_count',owner_offset+7*8,'d',999.)
    changed('crop_anthesis_flag',owner_offset+6*8,'d',2.)
    changed('crop_negative_mass',owner_offset+1*8,'d',-1.)
    assert owner_count>=29 and crop_id==9101
   else:
    changed('negative_N',len(raw)-20,'d',-1.)
    changed('oversized_N',len(raw)-12,'d',1e6)
   for label,b in mutants.items():
    path=build/(d.stem+'-invalid-'+label+'.bin');path.write_bytes(b)
    rejection=cmd([exe,'reject',path],build,'native');assert 'INVALID_DISK=PASS'in rejection
   row['drivers'][d.stem]['decoder_negatives']=list(mutants)
 results['runs'][opt]=row
for path in [ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90',Path(__file__),ROOT/'tests/nut-crop/prepare_oracle.py',ROOT/'tests/nut-crop/crop_fixture.inc',ROOT/'tests/nut-reactive/reactive_oracle.inc',ROOT/'tests/nut-reactive/reactive_parameters.inc']:inputs[str(path.relative_to(ROOT))]=sha(path)
if not DIRECT:
 for d in drivers[2:]:assert results['runs']['O0']['drivers'][d.stem]['endpoint_sha256']==results['runs']['O2']['drivers'][d.stem]['endpoint_sha256']
results.update(status='DIRECT_PASS'if DIRECT else'PHYSICAL_PASS_NOT_ADMITTED',input_sha256=inputs,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
