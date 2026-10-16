#!/usr/bin/env python3
"""Fresh bounded material and actual owner executions; measured raw events."""
from pathlib import Path
import base64,hashlib,io,json,os,re,shlex,subprocess,sys,tarfile,time,struct,zlib,shutil
ROOT=Path(__file__).resolve().parents[2];OUT=Path(os.environ['MATERIAL_RESULT_DIR']).resolve();OUT.mkdir(parents=True,exist_ok=True)
FC=shlex.split(os.environ.get('FC','gfortran'));events=[];inputs={};mode=sys.argv[1]if len(sys.argv)>1 else'process'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def run(args,cwd,category):
 args=list(map(str,args));t=time.perf_counter();r=subprocess.run(args,cwd=cwd,capture_output=True);i=len(events)
 for stream in ['stdout','stderr']:(OUT/f'{i:04d}.{stream}').write_bytes(getattr(r,stream))
 events.append(dict(category=category,command=args,returncode=r.returncode,seconds=time.perf_counter()-t,stdout_file=f'{i:04d}.stdout',stderr_file=f'{i:04d}.stderr',stdout_sha256=hashlib.sha256(r.stdout).hexdigest(),stderr_sha256=hashlib.sha256(r.stderr).hexdigest()))
 (OUT/'events.json').write_text(json.dumps(events,indent=2)+'\n')
 if r.returncode:print(r.stdout.decode());print(r.stderr.decode());raise RuntimeError('retained failed event '+str(i))
 return r.stdout.decode()
archive=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64';names=['wofost_soil_declarations.f90','wofost_soil_amendments.f90','wofost_soil_cropresidues.f90','wofost_soil_parameters.f90','management_soil.f90','wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90']
with tarfile.open(fileobj=io.BytesIO(base64.b64decode(archive.read_bytes())))as a:raw={n:a.extractfile('SWAP/'+n).read()for n in names}
assert hashlib.sha256(raw['management_soil.f90']).hexdigest()=='0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b'
assert b'smedate(isme)-smedate(isme-1) < 0.d-3'in raw['management_soil.f90']and b'if (smedate(i-1) > smedate(i))'in raw['management_soil.f90']
result=dict(execution_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),source_tree=subprocess.check_output(['git','rev-parse','HEAD:src'],cwd=ROOT,text=True).strip(),mode=mode,compiler=subprocess.check_output(FC+['--version'],text=True).splitlines()[0],authority={n:hashlib.sha256(b).hexdigest()for n,b in raw.items()},runs={})
oracle='''subroutine literal_material(ukind,umaterial,usplit,uwant)
 use iso_fortran_env,only:real64
 use mod_b111_soil_n_addition,only:b111_soil_n_material_t,b111_soil_n_split_parameters_t
 use wofost_soil_declarations
 use MOD_texture_orgmat,only:bdens
 integer,intent(in)::ukind
 type(b111_soil_n_material_t),intent(in)::umaterial
 type(b111_soil_n_split_parameters_t),intent(in)::usplit
 real(real64),intent(out)::uwant(12)
 nf=8;isme=1;NuAmend(1)=1;iamend(1,1)=1;MatNum(1)=1
 dz_WSN=.3d0;WFrac_t0=.34d0;bdens(1)=1300d0;SorpCoef=.0002d0
 NFracFOMmin=usplit%nfrac_fom_min;NFracFOMmax=usplit%nfrac_fom_max;NFracHum=usplit%nfrac_humus
 AsfaMin=usplit%asfa_min;AsfaMax=usplit%asfa_max
 NFracFOM(1:8)=[NFracFOMmax,NFracFOMmin,NFracFOMmax,NFracFOMmin,NFracFOMmax,NFracFOMmin,NFracFOMmax,NFracFOMmin]
 FOM_t0=0d0;Hum_t0=0d0;cNH4_t0=0d0;cNO3_t0=0d0
 FOM_add=0d0;NFOM_add=0d0;Hum_add=0d0;NHum_add=0d0;NH4N_amend=0d0;NO3N_amend=0d0;NH4N_volat=0d0
 FOM_cres=0d0;NFOM_cres=0d0;Hum_cres=0d0;NHum_cres=0d0;NH4N_cres=0d0;NO3N_cres=0d0
 if(ukind==1)then
  Amend(1)=umaterial%application_kg_m2;AppAge(1)=umaterial%application_age
  OrgMatFrac(1)=umaterial%organic_matter_fraction;OrgNFrac(1)=umaterial%organic_n_fraction
  NH4NFrac(1)=umaterial%ammonium_n_fraction;NO3NFrac(1)=umaterial%nitrate_n_fraction
  VolaFrac(1)=umaterial%volatilization_fraction
  call wofost_soilamendents
 else
  call wofost_soil_cropresidues(umaterial%application_kg_m2,umaterial%application_age, &
    umaterial%organic_matter_fraction,umaterial%organic_n_fraction,umaterial%ammonium_n_fraction,umaterial%nitrate_n_fraction)
 end if
 uwant=[FOM_t0(1:8),Hum_t0,cNH4_t0*(WFrac_t0+bdens(1)*SorpCoef)*dz_WSN,cNO3_t0*WFrac_t0*dz_WSN,NH4N_volat]
end subroutine
'''
for opt in ['O0','O2']:
 b=OUT/opt;b.mkdir(exist_ok=True)
 for n,data in raw.items():(b/n).write_bytes(data)
 (b/'material_oracle.inc').write_text(oracle)
 if mode!='process':
  sys.path.insert(0,str(ROOT/'tests/nut-crop'));from prepare_oracle import prepare
  prepare(ROOT,b,raw['management_soil.f90'])
  old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio'
  new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum'
  assert raw['wofost_soil_orgmatn.f90'].count(old)==1
  (b/'wofost_soil_orgmatn.f90').write_bytes(raw['wofost_soil_orgmatn.f90'].replace(old,new))
 fixture=b/'texture_fixture.f90';fixture.write_text('module MOD_texture_orgmat\n use iso_fortran_env,only:real64\n real(real64)::bdens(1)\nend module\nsubroutine swap_error(origin,message)\n character(*),intent(in)::origin,message\n print *,origin,message\n error stop 1\nend subroutine\n')
 flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-ffpe-trap=invalid,zero,overflow','-J'+str(b),'-I'+str(b),'-I'+str(ROOT/'tests/nut-material'),'-I'+str(ROOT/'tests/nut-crop')]
 drivers=[ROOT/'tests/nut-material/test_material_addition.f90']
 if mode in ['day','joint']:drivers.append(ROOT/'tests/nut-material/test_material_day.f90')
 if mode=='joint':drivers.append(ROOT/'tests/nut-material/test_material_joint.f90')
 providers={}
 for p in list((ROOT/'src').rglob('*.f90'))+[fixture,b/'wofost_soil_declarations.f90']:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):providers[name.lower()]=p
 ordered=[];seen=set()
 def visit(p):
  if p in seen:return
  seen.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   name=name.lower()
   if name in ['iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib']:continue
   if name not in providers:raise RuntimeError('unresolved '+name)
   if providers[name]!=p:visit(providers[name])
  ordered.append(p)
 if mode=='joint':
  p=ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90';inputs[str(p.relative_to(ROOT))]=sha(p)
  text=p.read_text().replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
  stub=b/'material_grid_stubs.f90';stub.write_text(text[:text.index('subroutine swap_error(origin, message)')])
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',stub.read_text(),re.M|re.I):providers[name.lower()]=stub
  p=ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90';inputs[str(p.relative_to(ROOT))]=sha(p);text=p.read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing');(b/'matrix_fixture.inc').write_text(text[start:end])
 for d in drivers:visit(d)
 for p in [fixture,b/'wofost_soil_declarations.f90']:visit(p)
 ordered=[p for p in ordered if p not in drivers]+[b/'wofost_soil_amendments.f90',b/'wofost_soil_cropresidues.f90']
 if mode!='process':ordered += [b/'wofost_soil_orgmatn.f90',b/'wofost_soil_rateconstants.f90',b/'wofost_soil_watern.f90',b/'literal_crop_exchange.f90']
 if mode=='joint':ordered.append(ROOT/'src/legacy/b1_10_port/headcalc.f90')
 objects=[];reuse=None
 if opt=='O0'and os.environ.get('MATERIAL_REUSE_O0'):
  reuse=Path(os.environ['MATERIAL_REUSE_O0']).resolve()
  prior=[e for e in json.loads((reuse.parent/'events.json').read_text())if e['category']=='compile']
  assert len(prior)==len(ordered)and all(e['returncode']==0 for e in prior)
  artifacts={p.name:sha(p)for p in reuse.iterdir()if p.suffix=='.mod'or p.name.startswith('provider-')and p.suffix=='.o'}
  for name,h in artifacts.items():shutil.copy2(reuse/name,b/name);assert sha(b/name)==h
  result['controlled_reuse']=dict(prior_execution=subprocess.check_output(['git','rev-parse','6d5ff12e'],cwd=ROOT,text=True).strip(),prior_events_sha256=sha(reuse.parent/'events.json'),artifacts_before=artifacts,reused_input_sha256={},native_results_reused=False)
 for i,p in enumerate(ordered):
  obj=b/f'provider-{i}.o';objects.append(obj)
  if reuse:
   old_command=prior[i]['command'];old_source=Path(old_command[old_command.index('-c')+1]);assert old_source.name==p.name
   old_bytes=subprocess.check_output(['git','show',result['controlled_reuse']['prior_execution']+':'+str(p.relative_to(ROOT))],cwd=ROOT)if p.is_relative_to(ROOT)else(reuse/p.name).read_bytes()
   assert hashlib.sha256(old_bytes).hexdigest()==sha(p),'changed reused provider '+str(p)
   old_flags=old_command[1:old_command.index('-c')]
   assert [arg.replace(str(reuse),str(b))for arg in old_flags]==flags
   result['controlled_reuse']['reused_input_sha256'][str(p.relative_to(ROOT))if p.is_relative_to(ROOT)else p.name]=sha(p)
  else:run(FC+flags+['-c',p,'-o',obj],b,'compile')
  if p.is_relative_to(ROOT):inputs[str(p.relative_to(ROOT))]=sha(p)
 row=dict(production_providers=sum(p.is_relative_to(ROOT/'src')for p in ordered),drivers={})
 for d in drivers:
  obj=b/(d.stem+'.o');exe=b/d.stem;inputs[str(d.relative_to(ROOT))]=sha(d)
  run(FC+flags+['-c',d,'-o',obj],b,'driver_compile');run(FC+flags+objects+[obj,'-o',exe],b,'link')
  if d.stem!='test_material_joint':row['drivers'][d.stem]=dict(stdout=run([exe],b,'native'))
  else:
   first=b/'restart.bin';end=b/'expected.bin';fresh=b/'fresh.bin'
   out=run([exe,'write',first,end],b,'native');resume=run([exe,'resume',first,fresh],b,'native')
   assert end.read_bytes()==fresh.read_bytes()==Path(str(end)+'.opaque').read_bytes()
   row['drivers'][d.stem]=dict(stdout=out,fresh_stdout=resume,endpoint_sha256=sha(end),restart_sha256=sha(first))
   assert Path(str(first)+'.empty-original').read_bytes()==Path(str(first)+'.empty-material').read_bytes()
   row['drivers'][d.stem]['empty_batch_identity']=True
   rawdisk=bytearray(first.read_bytes());mutants={'truncated':rawdisk[:len(rawdisk)//2]}
   damaged=rawdisk.copy();damaged[140]^=1;mutants['crc_corrupt']=damaged
   def changed(label,offset,fmt,value):
    data=rawdisk.copy();struct.pack_into(fmt,data,offset,value);struct.pack_into('<I',data,len(data)-4,zlib.crc32(data[:-4]));mutants[label]=data
   wmode,n=struct.unpack_from('<ii',rawdisk,148);history=struct.unpack_from('<i',rawdisk,156)[0]
   assert n==4 and history in [0,1]
   changed('water_clock',136,'d',123.);changed('node_count',152,'i',999999);changed('water_nan',160+8*n,'d',float('nan'))
   chemical=160+16*n+16+(8*n if history else 0)
   changed('chemical_revision',chemical+8,'q',-1);changed('chemical_clock',chemical+16,'d',999.)
   pcount=struct.unpack_from('<i',rawdisk,chemical+24)[0]
   changed('parameter_nan',chemical+28,'d',float('nan'));changed('parameter_count',chemical+24,'i',999999)
   changed('negative_fom',chemical+28+8*pcount+8,'d',-1.)
   crop_offset=chemical+28+8*pcount+8+8*8+32
   crop_id,crop_count=struct.unpack_from('<qi',rawdisk,crop_offset);assert crop_id==9101
   changed('crop_identity',crop_offset,'q',999999);changed('crop_configuration',crop_offset+12,'d',float('nan'))
   owner_count_offset=crop_offset+12+8*crop_count;owner_offset=owner_count_offset+4
   changed('crop_payload_count',owner_count_offset,'i',999999)
   changed('crop_N_nan',owner_offset+17*8,'d',float('nan'));changed('crop_N_unbalanced',owner_offset+17*8,'d',999.)
   changed('crop_cohort_count',owner_offset+25*8,'d',999999.);changed('crop_history_count',owner_offset+7*8,'d',999.)
   changed('crop_anthesis_flag',owner_offset+6*8,'d',2.);changed('crop_negative_mass',owner_offset+1*8,'d',-1.)
   for label,data in mutants.items():
    path=b/('invalid-'+label+'.bin');path.write_bytes(data);out=run([exe,'reject',path],b,'native');assert 'INVALID_DISK=PASS'in out
   row['drivers'][d.stem]['decoder_negatives']=list(mutants)
 if reuse:
  after={name:sha(b/name)for name in artifacts};assert after==artifacts
  result['controlled_reuse']['artifacts_after']=after
 result['runs'][opt]=row
for p in [Path(__file__),ROOT/'tests/nut-crop/crop_fixture.inc',ROOT/'tests/nut-material/material_fixture.inc',ROOT/'tests/nut-crop/prepare_oracle.py',ROOT/'tests/nut-reactive/reactive_oracle.inc']:
 if p.exists():inputs[str(p.relative_to(ROOT))]=sha(p)
if mode=='joint':assert result['runs']['O0']['drivers']['test_material_joint']['endpoint_sha256']==result['runs']['O2']['drivers']['test_material_joint']['endpoint_sha256']
result.update(status='PASS',input_sha256=inputs,cost_seconds={c:sum(e['seconds']for e in events if e['category']==c)for c in sorted({e['category']for e in events})})
(OUT/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(dict(status=result['status'],mode=mode,cost_seconds=result['cost_seconds'],closures={o:result['runs'][o]['production_providers']for o in ['O0','O2']})))
