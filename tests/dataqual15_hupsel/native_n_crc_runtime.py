"""Complete actual mineral/reactive-N modules; bounded private CRC candidates."""
import argparse,base64,hashlib,io,json,os,re,struct,subprocess,sys,tarfile,time,zlib
from pathlib import Path
import crc_family_runtime as primitive
ROOT=Path(__file__).resolve().parents[2]
BASE='fa4867340a4b1bde88e943f94df4658fdbaecc52'
REGISTER='integration/dataqual15_hupsel/NATIVE_N_CRC_PREREGISTRATION_20261105.json'
SOURCES={n:'src/adapter/mod_'+n+'_joint_restart_file.f90' for n in ('mineral','reactive_n')}
DRIVERS={'mineral':'tests/nut-mineral/test_mineral_joint.f90','reactive_n':'tests/nut-reactive/test_reactive_joint.f90'}
sha=lambda b:hashlib.sha256(b).hexdigest()

def guard():
 r=json.loads((ROOT/REGISTER).read_text());assert r['baseline']==BASE and r['production_delta']==[]
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
 for n,h in r['source_sha256'].items():assert sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))==h,n
 return r

def candidate(text):
 old=primitive.procedure(text,'function','crc32')
 shared=primitive.procedure((ROOT/'src/adapter/mod_age_joint_restart_file.f90').read_text(),'function','crc32')
 assert text.count(old)==1
 result=text.replace(old,shared);assert result.replace(shared,old)==text
 return result

def projected_driver():
 original=(ROOT/DRIVERS['reactive_n']).read_text()
 old='   pbad=p;pbad%organic_reference%ratecon_bio=0d0;pbad%organic_reference%ratecon_hum=0d0'
 donor=(ROOT/'tests/nut-crop/test_b112_retained_joint.f90').read_text()
 witness=next(s.strip() for s in donor.splitlines() if s.strip().startswith('bad_sp=sp;bad_sp%mineral%inventory%nfrac_biomass=1d0;'))
 replacement='   '+witness.replace('bad_sp','pbad').replace('=sp;','=p;')
 assert original.count(old)==1
 changed=original.replace(old,replacement);assert changed.replace(replacement,old)==original
 return changed

def run(args,out,events,label,check=True):
 start=time.monotonic();p=subprocess.run(list(map(str,args)),cwd=out,capture_output=True,timeout=300)
 stem='%04d-%s'%(len(events),label)
 for n in ('stdout','stderr'):(out/(stem+'.'+n)).write_bytes(getattr(p,n))
 events.append(dict(label=label,command=list(map(str,args)),returncode=p.returncode,seconds=time.monotonic()-start,stdout=stem+'.stdout',stderr=stem+'.stderr'))
 (out/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
 if check:assert p.returncode==0,(label,p.stdout,p.stderr)
 return p

def prepare(out):
 out.mkdir(parents=True);fixture=out/'fixture';fixture.mkdir()
 text=(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text()
 text=text.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 grid=fixture/'grid.f90';grid.write_text(text[:text.index('subroutine swap_error(origin, message)')])
 oracle_fixture=fixture/'oracle_fixture.f90';oracle_fixture.write_text('module MOD_texture_orgmat\n use iso_fortran_env,only:real64\n real(real64)::bdens(1)\nend module\nsubroutine swap_error(a,b)\n character(*),intent(in)::a,b\n print *,a,b\n error stop 1\nend subroutine\n')
 # Exact immutable source pins and accepted MC-NUT01-R1 repair from original runner.
 runner=(ROOT/'tests/nut-reactive/run_reactive.py').read_text()
 prefix=runner[runner.index("archive=ROOT/"):runner.index("results={'execution_commit'")]
 namespace=dict(ROOT=ROOT,OUT=fixture,json=json,hashlib=hashlib,base64=base64,io=io,tarfile=tarfile)
 exec(prefix,namespace)
 for name,raw in namespace['raws'].items():(fixture/name).write_bytes(namespace['corrected'] if name=='wofost_soil_orgmatn.f90' else raw)
 raw=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text()
 start=raw.index('  subroutine initialize_application_config');end=raw.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 (fixture/'matrix_fixture.inc').write_text(raw[start:end]+'\n')
 private=fixture/'reactive_driver.f90';private.write_text(projected_driver())
 drivers={n:ROOT/p for n,p in DRIVERS.items()};drivers['reactive_original']=drivers['reactive_n'];drivers['reactive_n']=private
 decl=fixture/'wofost_soil_declarations.f90';mapping={}
 for p in [*sorted((ROOT/'src').rglob('*.f90')),grid,oracle_fixture,decl]:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  assert p not in active,'module cycle';active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   if name.lower() in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
   assert name.lower() in mapping,(name,p)
   if mapping[name.lower()]!=p:visit(mapping[name.lower()])
  active.remove(p);seen.add(p);ordered.append(p)
 for p in [*drivers.values(),oracle_fixture,decl]:visit(p)
 ordered=[p for p in ordered if p not in drivers.values()]
 ordered += [fixture/n for n in ('wofost_soil_orgmatn.f90','wofost_soil_rateconstants.f90','wofost_soil_watern.f90')]+[ROOT/'src/legacy/b1_10_port/headcalc.f90']
 assert len(set(ordered))==len(ordered)
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n')) for p in ordered if p.is_relative_to(ROOT)}
 for n in guard()['source_sha256']:inputs[n]=sha((ROOT/n).read_bytes().replace(b'\r\n',b'\n'))
 (out/'INPUTS.json').write_text(json.dumps(inputs,indent=2)+'\n')
 return fixture,ordered,drivers

def build(out,compiler,opt,fixture,ordered,drivers,incumbent=None):
 out.mkdir();events=[];objects=[];sources={};flags=['-'+opt,'-std=f2008','-ffree-line-length-none','-fopenmp','-fcheck=all','-fbacktrace','-ffpe-trap=invalid,zero,overflow','-I'+str(out),'-J'+str(out),'-I'+str(fixture),'-I'+str(ROOT/'tests/nut-reactive')]
 if incumbent:flags+=['-I'+str(incumbent)]
 for i,p in enumerate(ordered):
  obj=out/('%03d.o'%i);source=p
  if incumbent and p not in [ROOT/n for n in SOURCES.values()]:obj=incumbent/obj.name
  else:
   if incumbent:
    source=out/p.name;source.write_text(candidate(p.read_text()))
   run([compiler,*flags,'-c',source,'-o',obj],out,events,'provider')
  assert obj.is_file();objects.append(obj);sources[str(source)]=sha(source.read_bytes())
 exes={}
 for name,p in drivers.items():
  if incumbent and name=='reactive_original':continue
  obj=out/(name+'.o');run([compiler,*flags,'-c',p,'-o',obj],out,events,'driver')
  exe=out/(name+('.exe'if os.name=='nt'else''));args=[*flags]+(['-Wl,--stack,16777216']if os.name=='nt'else[])+[str(obj),*map(str,objects),'-o',str(exe)]
  response=out/(name+'.args');response.write_text('\n'.join('"'+x.replace('\\','/')+'"'for x in args)+'\n')
  run([compiler,'@'+str(response)],out,events,'link');exes[name]=exe
 (out/'BUILD.json').write_text(json.dumps(dict(flags=flags,provider_count=len(ordered),candidate=bool(incumbent),sources_sha256=sources,objects_sha256={str(p):sha(p.read_bytes())for p in objects},drivers_sha256={n:sha(p.read_bytes())for n,p in drivers.items()},executables_sha256={n:sha(p.read_bytes())for n,p in exes.items()}),indent=2)+'\n')
 return exes,events

def execute(exes,out,events,is_candidate):
 reports={}
 if 'reactive_original'in exes:
  case=out/'original';case.mkdir();p=run([exes['reactive_original'],'write','restart.bin','end.bin'],out,events,'original-reactive',False)
  # Original failure retained; only the accepted-domain obsolete rejection witness may differ.
  assert p.returncode!=0 and b'organic-process rejection rolls water back'in p.stdout,p.stdout+p.stderr
 for name in ('mineral','reactive_n'):
  case=out/name;case.mkdir();exe=exes[name];restart=case/'restart.bin';end=case/'end.bin';fresh=case/'fresh.bin'
  p=run([exe,'write',restart,end],out,events,name+'-write');assert b'=PASS'in p.stdout
  run([exe,'resume',restart,fresh],out,events,name+'-resume');assert end.read_bytes()==fresh.read_bytes()==Path(str(end)+'.opaque').read_bytes()
  raw=restart.read_bytes();payload=raw[:-4];expected=zlib.crc32(payload);stored=struct.unpack('<I',raw[-4:])[0]
  if is_candidate:assert stored==expected
  repaired=payload+struct.pack('<I',expected);path=case/'correct-crc.bin';path.write_bytes(repaired)
  proper=run([exe,'resume',path,case/'correct-fresh.bin'],out,events,name+'-proper-crc',False)
  if is_candidate:assert proper.returncode==0 and (case/'correct-fresh.bin').read_bytes()==end.read_bytes()
  count=struct.unpack_from('<i',raw,296)[0];water=300+8*count
  mutants={'truncated':raw[:-12],'crc_corrupt':raw[:-1]+bytes([raw[-1]^1]),'zero_crc':payload+b'\0'*4}
  for label,offset,fmt,value in [('water_clock',136,'d',5.),('node_count',152,'i',100000),('revision',280,'q',-1),('chemical_clock',288,'d',5.),('parameter_nan',300,'d',float('nan')),('water_nan',water,'d',float('nan')),('negative_N',water+40,'d',-1.),('oversized_N',water+40,'d',1e300)]:
   bad=bytearray(payload);struct.pack_into('<'+fmt,bad,offset,value);mutants[label]=bytes(bad)+struct.pack('<I',zlib.crc32(bad))
  refusals=[]
  for label,bad in mutants.items():
   path=case/(label+'.bin');path.write_bytes(bad);p=run([exe,'reject',path,case/'unused.bin'],out,events,name+'-'+label,False)
   if is_candidate:assert p.returncode==0 and b'INVALID_DISK=PASS'in p.stdout,(name,label,p.stdout,p.stderr)
   refusals.append(dict(case=label,returncode=p.returncode,refused=p.returncode==0 and b'INVALID_DISK=PASS'in p.stdout))
  reports[name]=dict(stored_crc=stored,expected_crc=expected,independent_crc_pass=stored==expected,correctly_resealed_valid_returncode=proper.returncode,refusals=refusals,opaque_and_fresh_equal=True)
 return reports

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();guard();os.environ['OMP_NUM_THREADS']='1'
 out=a.output.resolve();compiler=a.compiler.resolve();fixture,ordered,drivers=prepare(out);results={}
 for role in ('incumbent','candidate'):
  builddir=out/role;exes,events=build(builddir,compiler,a.optimization,fixture,ordered,drivers,out/'incumbent'if role=='candidate'else None)
  results[role]=execute(exes,builddir,events,role=='candidate')
 # Body equality and old valid-O0 bytes are checked independently when sealing.
 guard();r=dict(status='FULL_NATIVE_N_CRC_PRIVATE_RUNTIME_COMPLETE',optimization=a.optimization,compiler=subprocess.check_output([compiler,'--version'],text=True).splitlines()[0],results=results,production_source_changed=False,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))

if __name__=='__main__':main()
