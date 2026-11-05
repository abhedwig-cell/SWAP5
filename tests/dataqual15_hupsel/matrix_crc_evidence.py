"""Independent full-source/native matrix CRC proof and actual corruption controls."""
import argparse,hashlib,io,json,struct,tarfile,zipfile,zlib
from pathlib import Path
import matrix_crc_runtime as policy
import native_n_crc_evidence as snapshots
ROOT=policy.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()
normal=lambda b:b.replace(b'\r\n',b'\n')
local_name=snapshots.local_name
def snapshot(out):
 # Reuse only the complete compiler-input snapshot construction, with explicit
 # target module identity. No predecessor guard or verdict is overridden.
 old=snapshots.policy;snapshots.policy=policy
 try:snapshots.snapshot(out)
 finally:snapshots.policy=old
 p=out/'PROVENANCE.json';r=json.loads(p.read_text());r['windows']=(out/'candidate/joint.exe').is_file();p.write_text(json.dumps(r,indent=2)+'\n')
def audit(files):
 get=lambda n:files[n];r=json.loads(get('RESULT.json'));meta=json.loads(get('PROVENANCE.json'))
 assert r['status']=='COMPLETE_MATRIX_NATIVE_FULL_POSTIMAGE_QUALIFICATION'
 assert all(r[k]is False for k in ('production_source_changed','production_admission','whole_scientific_admission'))
 for n,h in json.loads(get('INPUTS.json')).items():assert sha(normal(policy.before(n)if n==policy.SOURCE else(ROOT/n).read_bytes()))==h,n
 assert normal(get('fixture/literal.f90')).decode()==policy.oracle()
 assert normal(get('fixture/grid.f90'))==normal((ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_bytes())
 text=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text();start=text.index('  subroutine initialize_application_config');end=text.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 assert normal(get('fixture/matrix_fixture.inc')).decode()==text[start:end]+'\n'
 for n,h in meta['logs_sha256'].items():assert sha(get(n))==h
 for name,row in meta['sources'].items():
  raw=get(row['snapshot']);assert sha(raw)==row['sha256']
  if name.replace('\\','/').startswith(meta['root'].replace('\\','/').rstrip('/')+'/'):assert raw==get(local_name(name,meta['root']))
  if row['kind']=='repository':assert normal(raw)==normal(policy.before(row['path'])if row['path']==policy.SOURCE else(ROOT/row['path']).read_bytes())
  elif row['kind']=='candidate':assert normal(raw).decode()==policy.postimage()
  else:assert row['kind']=='generated'and raw==get(row['path'])
 summary={};body={}
 for role in ('incumbent','candidate'):
  b=json.loads(get(role+'/BUILD.json'));events=json.loads(get(role+'/EVENTS.json'));labels={e['label']:e for e in events}
  assert b['candidate']==(role=='candidate')and '-'+r['optimization']in b['flags']
  assert all(f in b['flags']for f in ('-fcheck=all','-fopenmp','-ffpe-trap=invalid,zero,overflow'))
  assert len([e for e in events if e['label']=='provider'])==(1 if role=='candidate'else b['provider_count'])and b['provider_count']>100
  for n,h in b['sources_sha256'].items():assert meta['sources'][n]['sha256']==h
  for n,h in b['objects_sha256'].items():assert sha(get(local_name(n,meta['root'])))==h
  for n,h in b['executables_sha256'].items():assert sha(get(role+'/'+n+('.exe'if meta['windows']else'-driver')))==h
  assert all(e['returncode']==0 for e in events if e['label']in ('provider','driver','link'))
  assert set(r['results'][role])==set(policy.EXPONENTS);summary[role]={}
  for exponent in policy.EXPONENTS:
   prefix=role+'/n'+exponent+'/';row=r['results'][role][exponent]
   for phase,marker in [('route','MATRIX_ACTUAL_RICHARDS_ORACLE_ROLLBACK_RESTART=PASS'),('write','MATRIX_JOINT_COMMIT_ROLLBACK_OPAQUE_DISK=PASS'),('resume','MATRIX_JOINT_FRESH_PROCESS=PASS')]:
    e=labels[phase+'-'+exponent];assert e['returncode']==0 and marker.encode()in get(role+'/'+e['stdout'])
   assert b'MATRIX_BASE_DISK_CONTRACT=PASS'in get(role+'/'+labels['write-'+exponent]['stdout'])
   native=get(prefix+'restart.bin');base=get(prefix+'restart.bin.base');endpoint=get(prefix+'end.bin');assert endpoint==get(prefix+'fresh.bin')
   expected=zlib.crc32(native[:-4]);stored=struct.unpack('<I',native[-4:])[0];be=zlib.crc32(base[:-4]);bs=struct.unpack('<I',base[-4:])[0]
   assert (row['expected_crc'],row['stored_crc'],row['independent_crc_pass'])==(expected,stored,expected==stored)
   assert (row['base_expected_crc'],row['base_stored_crc'],row['base_crc_pass'])==(be,bs,be==bs)
   assert get(prefix+'correct.bin')==native[:-4]+struct.pack('<I',expected)
   correct=labels['correct-'+exponent];assert row['correct_valid_returncode']==correct['returncode']
   if role=='candidate':assert stored==expected and bs==be and correct['returncode']==0 and get(prefix+'correct-end.bin')==endpoint
   n=struct.unpack_from('<i',native,152)[0];pc=struct.unpack_from('<i',native,296)[0];start=300+8*pc
   bads={'truncated':native[:-12],'crc_corrupt':native[:10]+bytes([native[10]^1])+native[11:],'zero_crc':native[:-4]+b'\0'*4}
   for label,offset,fmt,value in [('water_clock',136,'d',5.),('node_count',152,'i',100000),('chemical_revision',280,'q',-1),('negative_water',start,'d',-.1),('nonfinite_concentration',start+8*n,'d',float('nan')),('negative_dissolved',start+16*n,'d',-1.),('wrong_sorbed_equilibrium',start+24*n,'d',100.)]:
    data=bytearray(native[:-4]);struct.pack_into('<'+fmt,data,offset,value);bads[label]=bytes(data)+struct.pack('<I',zlib.crc32(data))
   assert [x['case']for x in row['refusals']]==list(bads)
   for refusal in row['refusals']:
    label=refusal['case'];assert get(prefix+label+'.bin')==bads[label];e=labels[exponent+'-'+label];refused=e['returncode']==0 and b'MATRIX_JOINT_INVALID_FILE=PASS'in get(role+'/'+e['stdout'])
    assert (refusal['returncode'],refusal['refused'])==(e['returncode'],refused)
    if role=='candidate':assert refused
   if role=='incumbent':body[exponent]=(native,base,endpoint)
   else:
    old=body[exponent];assert native[:-4]==old[0][:-4]and base[:-4]==old[1][:-4]and endpoint==old[2]
    if r['optimization']=='O0':assert native==old[0]and base==old[1]
   summary[role][exponent]=dict(independent_crc_pass=stored==expected,base_crc_pass=bs==be,correct_valid_resume=correct['returncode']==0,refused=sum(x['refused']for x in row['refusals']))
 return dict(status='COMPLETE_MATRIX_ROUTE_NATIVE_SOURCE_AND_DATA_REMEASURED',optimization=r['optimization'],results=summary,production_admission=False,whole_scientific_admission=False)
def controls(files):
 refused=[]
 targets=[('binary','candidate/joint.exe'if'candidate/joint.exe'in files else'candidate/joint-driver'),('source','candidate/mod_matrix_joint_restart_file.f90'),('native','candidate/n1/restart.bin'),('semantic','candidate/n1/negative_water.bin'),('raw','candidate/'+next(e['stdout']for e in json.loads(files['candidate/EVENTS.json'])if e['label']=='resume-1'))]
 for label,n in targets:
  bad=dict(files);bad[n]=bad[n]+b'changed'
  try:audit(bad)
  except(AssertionError,KeyError,ValueError):refused.append(label)
  else:raise AssertionError('accepted matrix evidence mutation '+label)
 return refused
def cross(cohorts):
 for exponent in policy.EXPONENTS:
  for name in ('restart.bin','restart.bin.base','end.bin'):
   path='candidate/n'+exponent+'/'+name;assert cohorts['O0'][path]==cohorts['O2'][path]
def seal(out):
 reports={};cohorts={}
 for opt in ('O0','O2'):
  case=out/opt;snapshot(case);files={p.relative_to(case).as_posix():p.read_bytes()for p in case.rglob('*')if p.is_file()};report=dict(audit=audit(files),controls=controls(files));cohorts[opt]=files;stem='MATRIX_CRC_WINDOWS_20261105_'+opt;archive=BASE/(stem+'.tar.xz')
  with tarfile.open(archive,'w:xz')as t:
   for n,b in sorted(files.items()):i=tarfile.TarInfo(n);i.size=len(b);t.addfile(i,io.BytesIO(b))
  (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},report=report),indent=2)+'\n');reports[opt]=report
 cross(cohorts);return reports
def windows():
 reports={};cohorts={}
 for opt in ('O0','O2'):
  stem='MATRIX_CRC_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
  assert {n:sha(b)for n,b in files.items()}==r['files_sha256'];reports[opt]=dict(audit=audit(files),controls=controls(files));assert reports[opt]==r['report'];cohorts[opt]=files
 cross(cohorts);return reports
def posix():
 r=json.loads((BASE/'MATRIX_CRC_POSIX_20261105.json').read_text());chunks=[];reports={};cohorts={}
 for p in r['artifact_parts']:
  data=(BASE/p['path']).read_bytes();assert sha(data)==p['sha256']and len(data)==p['bytes'];chunks.append(data)
 raw=b''.join(chunks);assert sha(raw)==r['artifact_zip_sha256']
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  assert len(z.namelist())==len(set(z.namelist()))
  for opt in ('O0','O2'):
   prefix='matrix-crc-'+opt+'/';files={n[len(prefix):]:z.read(n)for n in z.namelist()if n.startswith(prefix)and not n.endswith('/')};reports[opt]=dict(audit=audit(files),controls=controls(files));cohorts[opt]=files
 cross(cohorts);assert reports==r['report'];return reports
def main():
 p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);p.add_argument('--audit-directory',type=Path);p.add_argument('--posix',action='store_true');a=p.parse_args();policy.guard()
 if a.audit_directory:
  out=a.audit_directory.resolve();snapshot(out);files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};print(dict(audit=audit(files),controls=controls(files)))
 else:print(seal(a.seal.resolve())if a.seal else windows());print(posix()if a.posix else '')
if __name__=='__main__':main()
