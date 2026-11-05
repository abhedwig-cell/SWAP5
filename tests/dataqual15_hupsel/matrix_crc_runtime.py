"""Complete original matrix route/native drivers and exact shared-CRC postimage."""
import argparse,base64,hashlib,io,json,os,re,struct,subprocess,sys,tarfile,zlib
from pathlib import Path
import native_n_crc_runtime as build_support
ROOT=Path(__file__).resolve().parents[2];BASE='5284091c34a44d14c2d837f7a5d2a5b217437101'
SOURCE='src/adapter/mod_matrix_joint_restart_file.f90';SOURCES={'matrix':SOURCE}
DRIVERS={'route':'tests/nut-sol/test_matrix_route.f90','joint':'tests/nut-sol/test_matrix_joint.f90'}
EXPONENTS=('1','0.5','0.8','1.0005','1.5','2')
REGISTER='integration/dataqual15_hupsel/MATRIX_CRC_PREREGISTRATION_20261105.json'
sha=lambda b:hashlib.sha256(b).hexdigest()
def before(n):return subprocess.check_output(['git','show',BASE+':'+n],cwd=ROOT)
def postimage(text=None):
 old=before(SOURCE).decode();assert text is None or text==old
 start=old.index('  function crc32(bytes) result(crc)');end=old.index('  end function',start)+len('  end function\n')
 body=old[:start]+old[end:];marker='  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end\n';assert body.count(marker)==1
 return body.replace(marker,marker+'  use mod_age_joint_restart_file,only:crc32\n',1)
def guard():
 r=json.loads((ROOT/REGISTER).read_text());assert r['baseline']==BASE and r['production_delta']==[]
 for area in ('src','app','reference'):
  assert subprocess.check_output(['git','rev-parse','HEAD:'+area],cwd=ROOT)==subprocess.check_output(['git','rev-parse',BASE+':'+area],cwd=ROOT)
  assert not subprocess.check_output(['git','diff','HEAD','--',area],cwd=ROOT)
  assert not subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',area],cwd=ROOT)
 return r
def oracle():
 runner=(ROOT/'tests/nut-sol/run_matrix_route.py').read_text();block=runner[runner.index('with tarfile.open'):runner.index('results=')]
 ns=dict(BUNDLE=ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64',base64=base64,tarfile=tarfile,io=io,hashlib=hashlib)
 exec(block,ns);return ns['pre']+ns['loop']+ns['post']
def prepare(out):
 out.mkdir(parents=True);fixture=out/'fixture';fixture.mkdir();grid=fixture/'grid.f90';grid.write_text((ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text())
 raw=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text();start=raw.index('  subroutine initialize_application_config');end=raw.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 (fixture/'matrix_fixture.inc').write_text(raw[start:end]+'\n');literal=fixture/'literal.f90';literal.write_text(oracle())
 inverse=ROOT/'tests/nut-sol/matrix_nonlinear_oracle.f90';drivers={n:ROOT/p for n,p in DRIVERS.items()};mapping={}
 for p in [*sorted((ROOT/'src').rglob('*.f90')),grid,inverse,literal]:
  for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.M|re.I):mapping[name.lower()]=p
 ordered=[];seen=set();active=set()
 def visit(p):
  if p in seen:return
  assert p not in active,'module cycle';active.add(p)
  for name in re.findall(r'^\s*use\s*(?:,\s*(?:non_)?intrinsic\s*::\s*|::\s*)?(\w+)',p.read_text(),re.M|re.I):
   if name.lower()in ('iso_fortran_env','iso_c_binding','ieee_arithmetic','ieee_exceptions','omp_lib'):continue
   assert name.lower()in mapping,(name,p)
   if mapping[name.lower()]!=p:visit(mapping[name.lower()])
  active.remove(p);seen.add(p);ordered.append(p)
 # One coherent union, including the exact candidate's shared dependency.
 visit(ROOT/'src/adapter/mod_age_joint_restart_file.f90')
 for p in drivers.values():visit(p)
 ordered=[p for p in ordered if p not in drivers.values()]+[ROOT/'src/legacy/b1_10_port/headcalc.f90'];assert len(ordered)==len(set(ordered))
 inputs={p.relative_to(ROOT).as_posix():sha(p.read_bytes().replace(b'\r\n',b'\n'))for p in [*ordered,*drivers.values(),ROOT/'tests/nut-sol/run_matrix_route.py',ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90',ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90']if p.is_relative_to(ROOT)}
 (out/'INPUTS.json').write_text(json.dumps(inputs,indent=2)+'\n');return fixture,ordered,drivers
def execute(exes,out,events,candidate):
 rows={}
 for exponent in EXPONENTS:
  case=out/('n'+exponent);case.mkdir();exe=exes['joint'];restart=case/'restart.bin';endpoint=case/'end.bin';fresh=case/'fresh.bin'
  p=build_support.run([exes['route'],exponent],out,events,'route-'+exponent);assert b'MATRIX_ACTUAL_RICHARDS_ORACLE_ROLLBACK_RESTART=PASS'in p.stdout
  p=build_support.run([exe,'write',restart,endpoint,exponent],out,events,'write-'+exponent);assert b'MATRIX_JOINT_COMMIT_ROLLBACK_OPAQUE_DISK=PASS'in p.stdout and b'MATRIX_BASE_DISK_CONTRACT=PASS'in p.stdout
  build_support.run([exe,'resume',restart,fresh,exponent],out,events,'resume-'+exponent);assert endpoint.read_bytes()==fresh.read_bytes()
  raw=restart.read_bytes();body=raw[:-4];stored=struct.unpack('<I',raw[-4:])[0];expected=zlib.crc32(body)
  base=Path(str(restart)+'.base').read_bytes();base_expected=zlib.crc32(base[:-4]);base_stored=struct.unpack('<I',base[-4:])[0]
  if candidate:assert stored==expected and base_expected==base_stored
  correct=case/'correct.bin';correct.write_bytes(body+struct.pack('<I',expected));p=build_support.run([exe,'resume',correct,case/'correct-end.bin',exponent],out,events,'correct-'+exponent,False)
  if candidate:assert p.returncode==0 and (case/'correct-end.bin').read_bytes()==endpoint.read_bytes()
  n=struct.unpack_from('<i',raw,152)[0];pc=struct.unpack_from('<i',raw,296)[0];start=300+8*pc
  bads={'truncated':raw[:-12],'crc_corrupt':raw[:10]+bytes([raw[10]^1])+raw[11:],'zero_crc':body+b'\0'*4}
  for label,offset,fmt,value in [('water_clock',136,'d',5.),('node_count',152,'i',100000),('chemical_revision',280,'q',-1),('negative_water',start,'d',-.1),('nonfinite_concentration',start+8*n,'d',float('nan')),('negative_dissolved',start+16*n,'d',-1.),('wrong_sorbed_equilibrium',start+24*n,'d',100.)]:
   data=bytearray(body);struct.pack_into('<'+fmt,data,offset,value);bads[label]=bytes(data)+struct.pack('<I',zlib.crc32(data))
  refusals=[]
  for label,data in bads.items():
   path=case/(label+'.bin');path.write_bytes(data);pbad=build_support.run([exe,'reject',path,case/'unused.bin',exponent],out,events,exponent+'-'+label,False);refused=pbad.returncode==0 and b'MATRIX_JOINT_INVALID_FILE=PASS'in pbad.stdout
   if candidate:assert refused,(exponent,label,pbad.stdout,pbad.stderr)
   refusals.append(dict(case=label,returncode=pbad.returncode,refused=refused))
  rows[exponent]=dict(stored_crc=stored,expected_crc=expected,independent_crc_pass=stored==expected,base_stored_crc=base_stored,base_expected_crc=base_expected,base_crc_pass=base_stored==base_expected,correct_valid_returncode=p.returncode,refusals=refusals,exact_own_fresh_endpoint=True)
 return rows
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();guard();os.environ['OMP_NUM_THREADS']='1'
 out=a.output.resolve();fixture,ordered,drivers=prepare(out);build_support.SOURCES=SOURCES;build_support.candidate=postimage;results={}
 for role in ('incumbent','candidate'):
  exes,events=build_support.build(out/role,a.compiler.resolve(),a.optimization,fixture,ordered,drivers,out/'incumbent'if role=='candidate'else None)
  results[role]=execute(exes,out/role,events,role=='candidate')
 guard();r=dict(status='COMPLETE_MATRIX_NATIVE_FULL_POSTIMAGE_QUALIFICATION',optimization=a.optimization,compiler=subprocess.check_output([a.compiler,'--version'],text=True).splitlines()[0],results=results,production_source_changed=False,production_admission=False,whole_scientific_admission=False)
 (out/'RESULT.json').write_text(json.dumps(r,indent=2)+'\n');print(json.dumps(r,indent=2))
if __name__=='__main__':main()
