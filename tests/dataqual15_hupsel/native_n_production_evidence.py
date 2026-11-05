"""Current actual native N proof; static full source/build/native auditor."""
import argparse,ast,base64,hashlib,io,json,struct,tarfile,zipfile,zlib
from pathlib import Path
import native_n_crc_runtime as policy
import native_n_production as successor
from native_n_crc_evidence import local_name
ROOT=successor.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()
normal=lambda b:b.replace(b'\r\n',b'\n')
def audit(files):
 get=lambda n:files[n];r=json.loads(get('RESULT.json'));meta=json.loads(get('PROVENANCE.json'))
 assert r['status']=='CURRENT_NATIVE_N_PRODUCTION_RUNTIME_COMPLETE'
 assert r['production_source_changed']is True and r['production_admission']is False and r['whole_scientific_admission']is False
 for name,h in meta['logs_sha256'].items():assert sha(get(name))==h
 for name,h in json.loads(get('INPUTS.json')).items():assert sha(normal((ROOT/name).read_bytes()))==h,name
 fixture=(ROOT/'tests/physics/test_ppa_wu05d2_mixed_application.f90').read_text();start=fixture.index('  subroutine initialize_application_config');end=fixture.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 assert normal(get('fixture/matrix_fixture.inc')).decode()==fixture[start:end]+'\n'
 grid=(ROOT/'tests/modularity/low_air_consistent_grid_stubs.f90').read_text();grid=grid.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 assert normal(get('fixture/grid.f90')).decode()==grid[:grid.index('subroutine swap_error(origin, message)')]
 tree=ast.parse((ROOT/'tests/nut-reactive/run_reactive.py').read_text());pins=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='pins'for t in n.targets))
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode((ROOT/'integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64').read_bytes())),mode='r:gz')as t:
  for name,h in pins.items():
   raw=t.extractfile('SWAP/'+name).read();assert sha(raw)==h
   if name=='wofost_soil_orgmatn.f90':
    old=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio';new=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum';assert raw.count(old)==1;raw=raw.replace(old,new)
   assert get('fixture/'+name)==raw
 # Every input snapshot is bound to the actual compiler source hash; compare
 # complete production and generated source bytes, never only imported names.
 for name,row in meta['sources'].items():
  raw=get(row['snapshot']);assert sha(raw)==row['sha256']
  if name.replace('\\','/').startswith(meta['root'].replace('\\','/').rstrip('/')+'/'):assert raw==get(local_name(name,meta['root']))
  if row['kind']=='repository':assert normal(raw)==normal((ROOT/row['path']).read_bytes())
  elif row['kind']=='candidate':assert normal(raw).decode()==policy.candidate((ROOT/row['path']).read_text())
  elif row['kind']=='reactive_projection':assert normal(raw).decode()==policy.projected_driver()
  else:assert raw==get(row['path'])
 summary={};body_identity={}
 for role in ('current',):
  b=json.loads(get(role+'/BUILD.json'));events=json.loads(get(role+'/EVENTS.json'))
  assert b['candidate']==(role=='candidate') and '-'+r['optimization']in b['flags']
  assert all(f in b['flags']for f in ('-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fopenmp'))
  assert b['provider_count']>100
  for path,h in b['sources_sha256'].items():assert meta['sources'][path]['sha256']==h
  for path,h in b['objects_sha256'].items():assert sha(get(local_name(path,meta['root'])))==h
  for n,h in b['executables_sha256'].items():
   path=role+'/'+n+('.exe'if meta['windows']else'-driver');assert sha(get(path))==h
  for e in events:
   assert role+'/'+e['stdout']in files and role+'/'+e['stderr']in files
   if e['label']in ('provider','driver','link'):assert e['returncode']==0
  bylabel={e['label']:e for e in events};assert len([e for e in events if e['label']=='provider'])==(2 if role=='candidate'else b['provider_count'])
  if role=='current':
   e=bylabel['original-reactive'];assert e['returncode']!=0 and b'organic-process rejection rolls water back'in get(role+'/'+e['stdout'])
  summary[role]={}
  for name in policy.DRIVERS:
   prefix=role+'/'+name+'/';raw=get(prefix+'restart.bin');end=get(prefix+'end.bin');fresh=get(prefix+'fresh.bin');opaque=get(prefix+'end.bin.opaque')
   assert end==fresh==opaque
   payload=raw[:-4];expected=zlib.crc32(payload);stored=struct.unpack('<I',raw[-4:])[0]
   assert get(prefix+'correct-crc.bin')==payload+struct.pack('<I',expected)
   e=bylabel[name+'-proper-crc'];row=r['results'][role][name]
   assert row['expected_crc']==expected and row['stored_crc']==stored and row['independent_crc_pass']==(stored==expected)
   assert row['correctly_resealed_valid_returncode']==e['returncode']
   for step in ('write','resume'):
    e2=bylabel[name+'-'+step];assert e2['returncode']==0 and b'=PASS'in get(role+'/'+e2['stdout'])
   if role=='current':
    assert stored==expected and e['returncode']==0 and get(prefix+'correct-fresh.bin')==end
    for positive in ('end.bin','fresh.bin','end.bin.opaque','correct-fresh.bin'):
     data=get(prefix+positive);assert zlib.crc32(data[:-4])==struct.unpack('<I',data[-4:])[0]
   # Reconstruct every original negative byte-for-byte, including valid CRC
   # semantic controls. A failed baseline refusal remains a failed observation.
   count=struct.unpack_from('<i',raw,296)[0];water=300+8*count
   bads={'truncated':raw[:-12],'crc_corrupt':raw[:-1]+bytes([raw[-1]^1]),'zero_crc':payload+b'\0'*4}
   for label,offset,fmt,value in [('water_clock',136,'d',5.),('node_count',152,'i',100000),('revision',280,'q',-1),('chemical_clock',288,'d',5.),('parameter_nan',300,'d',float('nan')),('water_nan',water,'d',float('nan')),('negative_N',water+40,'d',-1.),('oversized_N',water+40,'d',1e300)]:
    data=bytearray(payload);struct.pack_into('<'+fmt,data,offset,value);bads[label]=bytes(data)+struct.pack('<I',zlib.crc32(data))
   assert [x['case']for x in row['refusals']]==list(bads)
   for refusal in row['refusals']:
    label=refusal['case'];assert get(prefix+label+'.bin')==bads[label]
    event=bylabel[name+'-'+label];refused=event['returncode']==0 and b'INVALID_DISK=PASS'in get(role+'/'+event['stdout'])
    assert refusal['returncode']==event['returncode'] and refusal['refused']==refused
    if role=='current':assert refused
   summary[role][name]=dict(independent_crc_pass=stored==expected,correct_valid_resume=e['returncode']==0,refused=sum(x['refused']for x in row['refusals']))
   if role=='incumbent':body_identity[name]=[raw,end]
   elif role=='candidate':
    assert raw[:-4]==body_identity[name][0][:-4] and end[:-4]==body_identity[name][1][:-4]
    if r['optimization']=='O0':assert raw==body_identity[name][0] and end==body_identity[name][1]
 return dict(status='COMPLETE_NATIVE_N_MODULE_SOURCE_BUILD_AND_DATA_REMEASURED',optimization=r['optimization'],results=summary,production_admission=False,whole_scientific_admission=False)

def snapshot(out):
 # Seal source bytes only after verifying the recorded raw compiler hashes.
 root=str(out.resolve());meta=dict(root=root,windows=(out/'current/mineral.exe').is_file(),sources={});snap=out/'source-snapshots';snap.mkdir(exist_ok=True)
 for role in ('current',):
  b=json.loads((out/role/'BUILD.json').read_text())
  sources=dict(b['sources_sha256'])
  events=json.loads((out/role/'EVENTS.json').read_text())
  for e in events:
   if e['label']=='driver':
    path=e['command'][e['command'].index('-c')+1];sources[path]=sha(Path(path).read_bytes())
  for path,h in sources.items():
   raw=Path(path).read_bytes();assert sha(raw)==h
   if path in meta['sources']:continue
   dest='source-snapshots/%04d.f90'%len(meta['sources']);(out/dest).write_bytes(raw);p=Path(path).resolve()
   if p.is_relative_to(ROOT):kind='repository';name=p.relative_to(ROOT).as_posix()
   elif role=='candidate'and p.name in [Path(n).name for n in policy.SOURCES.values()]:kind='candidate';name=next(n for n in policy.SOURCES.values()if Path(n).name==p.name)
   elif p.name=='reactive_driver.f90':kind='reactive_projection';name=''
   else:kind='generated';name=p.relative_to(out).as_posix()
   meta['sources'][path]=dict(sha256=h,snapshot=dest,kind=kind,path=name)
 meta['logs_sha256']={p.relative_to(out).as_posix():sha(p.read_bytes())for p in out.rglob('*')if p.suffix in ('.stdout','.stderr')}
 (out/'PROVENANCE.json').write_text(json.dumps(meta,indent=2)+'\n')

def controls(files):
 refused=[];meta=json.loads(files['PROVENANCE.json']);source=next(v['snapshot']for k,v in meta['sources'].items()if k.replace('\\','/').endswith('/src/adapter/mod_mineral_joint_restart_file.f90'))
 targets=[('binary','current/mineral.exe'if'current/mineral.exe'in files else'current/mineral-driver'),('source',source),('native','current/mineral/restart.bin'),('negative','current/mineral/negative_N.bin'),('raw','current/'+next(e['stdout']for e in json.loads(files['current/EVENTS.json'])if e['label']=='mineral-resume'))]
 for label,name in targets:
  bad=dict(files);bad[name]=bad[name]+b'changed'
  try:audit(bad)
  except(AssertionError,KeyError,ValueError):refused.append(label)
  else:raise AssertionError('accepted current evidence mutation '+label)
 return refused

def compare_private(files,opt,windows):
 """Immutable admitted private comparator bytes; no science result fabricated."""
 if windows:
  stem='NATIVE_N_CRC_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   for name in policy.DRIVERS:
    for end in ('restart.bin','end.bin'):
     assert files['current/'+name+'/'+end]==t.extractfile('candidate/'+name+'/'+end).read()
 else:
  r=json.loads((BASE/'NATIVE_N_CRC_POSIX_20261105.json').read_text());parts=[]
  for p in r['artifact_parts']:
   data=(BASE/p['path']).read_bytes();assert sha(data)==p['sha256'];parts.append(data)
  raw=b''.join(parts);assert sha(raw)==r['artifact_zip_sha256']
  with zipfile.ZipFile(io.BytesIO(raw))as z:
   for name in policy.DRIVERS:
    for end in ('restart.bin','end.bin'):assert files['current/'+name+'/'+end]==z.read('native-n-'+opt+'/candidate/'+name+'/'+end)
 return True

def report(files):
 r=json.loads(files['RESULT.json']);a=audit(files);return dict(audit=a,controls=controls(files),exact_admitted_private_native_bytes=compare_private(files,r['optimization'],json.loads(files['PROVENANCE.json'])['windows']))

def cross(cohorts):
 for name in policy.DRIVERS:
  for end in ('restart.bin','end.bin'):assert cohorts['O0']['current/'+name+'/'+end]==cohorts['O2']['current/'+name+'/'+end]

def seal(out):
 reports={};cohorts={}
 for opt in ('O0','O2'):
  case=out/opt;snapshot(case);files={p.relative_to(case).as_posix():p.read_bytes()for p in case.rglob('*')if p.is_file()};r=report(files);cohorts[opt]=files
  stem='NATIVE_N_PRODUCTION_WINDOWS_20261105_'+opt;archive=BASE/(stem+'.tar.xz')
  with tarfile.open(archive,'w:xz')as t:
   for n,b in sorted(files.items()):i=tarfile.TarInfo(n);i.size=len(b);t.addfile(i,io.BytesIO(b))
  (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},report=r),indent=2)+'\n');reports[opt]=r
 cross(cohorts);return reports

def windows():
 reports={};cohorts={}
 for opt in ('O0','O2'):
  stem='NATIVE_N_PRODUCTION_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
  assert {n:sha(b)for n,b in files.items()}==r['files_sha256'];reports[opt]=report(files);assert reports[opt]==r['report'];cohorts[opt]=files
 cross(cohorts);return reports

def posix():
 r=json.loads((BASE/'NATIVE_N_PRODUCTION_POSIX_20261105.json').read_text());chunks=[];reports={};cohorts={}
 for p in r['artifact_parts']:
  data=(BASE/p['path']).read_bytes();assert sha(data)==p['sha256']and len(data)==p['bytes'];chunks.append(data)
 raw=b''.join(chunks);assert sha(raw)==r['artifact_zip_sha256']
 with zipfile.ZipFile(io.BytesIO(raw))as z:
  assert len(z.namelist())==len(set(z.namelist()))
  for opt in ('O0','O2'):
   prefix='native-n-current-'+opt+'/';files={n[len(prefix):]:z.read(n)for n in z.namelist()if n.startswith(prefix)and not n.endswith('/')};reports[opt]=report(files);cohorts[opt]=files
 cross(cohorts);assert reports==r['report'];return reports

def main():
 p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);p.add_argument('--audit-directory',type=Path);p.add_argument('--posix',action='store_true');a=p.parse_args();successor.guard(development=True)
 if a.audit_directory:
  out=a.audit_directory.resolve();snapshot(out);print(report({p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()}))
 else:print(seal(a.seal.resolve())if a.seal else windows());print(posix()if a.posix else '')
if __name__=='__main__':main()
