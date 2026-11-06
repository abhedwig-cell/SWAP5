"""Lossless complete native cohorts, independently checked against raw files."""
import argparse,io,json,re,struct,tarfile,tempfile,zlib,zipfile,shutil
from functools import lru_cache
from pathlib import Path
import matrix_thermal_native_policy as p
DEST=p.ROOT/'integration/dataqual15_hupsel'
before=lru_cache(None)(p.before)

def audit(root,role='candidate-v2'):
 model=root/role;r=json.loads((model/'physical/result.json').read_text())
 assert (model/'publication/publication.c').read_bytes()==before('app/support/restart_publish.c').encode()
 assert r['status']=='FOCUSED_PHYSICAL_PASS_REFINEMENT_ASSESSMENT_PENDING_NOT_ADMITTED'
 for name,digest in r['inputs'].items():
  name=name.replace('\\','/')
  expected=p.candidate() if name==p.SOURCE and role=='candidate-v2' else before(name)
  assert p.sha(expected.encode())==digest,name
 ledger=json.loads((model/'COMPILER.json').read_text());objects={};links=[]
 def relocate(path):
  name=str(path).replace('\\','/');suffix=name.split('/'+role+'/',1)[1]
  return model/suffix
 for event in ledger:
  assert event['returncode']==0
  cmd=event['effective']
  if '-c' in cmd:
   obj=relocate(cmd[-1]);assert obj.is_file() and obj.stat().st_size>0
   objects[obj.relative_to(root).as_posix()]=p.sha(obj.read_bytes())
  elif '-o' in cmd:
   opt=next(x[1:] for x in cmd if x in ('-O0','-O2'))
   linked={relocate(arg).relative_to(root).as_posix() for arg in cmd if arg.endswith('.o')}
   compiled={name for name in objects if '/physical/'+opt+'/' in name}
   assert linked==compiled|{role+'/publication/'+opt+'.o'}
   for arg in cmd:
    if arg.endswith('.o'):assert relocate(arg).is_file()
   binary=relocate(cmd[-1]);assert p.sha(binary.read_bytes())==r['executables'][opt];links.append(opt)
 assert sorted(links)==['O0','O2'] and len(objects)==2*(r['provider_count']+1)
 native={}
 for opt in ('O0','O2'):
  for grid in ('2','4','8','16'):
   folder=model/'physical'/opt/grid
   for name,key in (('restart.bin','restart_sha256'),('full.bin','endpoint_sha256'),('resumed.bin','endpoint_sha256')):
    raw=(folder/name).read_bytes();assert raw[:8]==b'S5MT0001'
    assert struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4])
    assert p.sha(raw)==r['results'][opt][grid][key]
    native[(folder/name).relative_to(root).as_posix()]=p.sha(raw)
 controls=root/('controls-v1' if (root/'controls-v1').exists() else 'controls')
 report=json.loads((controls/'RESULT.json').read_text());events=report['events'];index=0;refusals=0;positives=0
 counterfactual={}
 for block in report['reports']:
  if 'observations' not in block:continue
  accepted=0
  for observation in block['observations']:
   event=events[index];index+=1;cmd=event['command'];path=controls/(block['role']+'-'+block['optimization'])/Path(cmd[2].replace('\\','/')).name
   raw=path.read_bytes();assert p.sha(raw)==observation['input_sha256']
   assert struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4])
   text=(controls/event['stdout']).read_text();assert int(re.search(r'PROBE_STATUS=(\d+)',text)[1])==observation['status']
   for label,key in (('WATER_READY','water_ready'),('CHEMICAL_READY','chemical_ready')):assert re.search(label+r'=([TF])',text)[1]==observation[key]
   if observation['site']:
    offset={'time_bound':144,'history':152}[observation['site']]
    assert struct.unpack_from('<i',raw,offset)[0]==observation['token']
    if block['role']=='candidate':
     assert observation['status']!=0 and observation['water_ready']==observation['chemical_ready']=='F';refusals+=1
    elif observation['status']==0:accepted+=1
   elif block['role']=='candidate':
    assert observation['status']==0 and path.with_suffix('.reexport').read_bytes()==raw;positives+=1
  counterfactual[block['role']+'-'+block['optimization']]=accepted
 assert index==len(events) and refusals==60 and positives==6
 writer=root/'writer-windows-v3';writer_counts=None
 if writer.exists():
  wr=json.loads((writer/'RESULT.json').read_text());assert len(wr['events'])==14 and len(wr['results'])==2
  writer_counts=dict(raw_logical_refusals=0,precommit_io_refusals=0,windows_stage6_publications=0,actual_terminations=0)
  for event in wr['events']:
   opt=event['optimization'];kind=event['kind'];value=event['value'];case=writer/opt/(kind+'-'+str(value));text=(writer/event['stdout']).read_text()
   old=(model/'physical'/opt/'2/restart.bin').read_bytes();good=(model/'physical'/opt/'2/full.bin').read_bytes();success=kind=='io' and value==6
   assert ('WRITE_STATUS=0' in text)==success and (case/'authority').read_bytes()==(good if success else old) and (case/'after').read_bytes()==good
   if kind=='logical':
    bits=re.search(r'INJECT_BITS\s+(-?\d+)\s+(-?\d+)',text);assert bits and int(bits[value])==2
   writer_counts['raw_logical_refusals' if kind=='logical' else 'windows_stage6_publications' if success else 'precommit_io_refusals']+=1
  for result in wr['results']:
   opt=result['optimization']
   for event in result['terminations']:
    phase=event['phase'];case=writer/opt/('terminate-'+phase);expected=(model/'physical'/opt/('2/restart.bin' if phase=='before' else '2/full.bin')).read_bytes()
    assert event['termination_returncode']!=0 and event['fresh_reconstructed'] is True and p.sha(expected)==event['authority_sha256']
    assert (case/'authority').read_bytes()==(case/'recovered').read_bytes()==expected;writer_counts['actual_terminations']+=1
  assert writer_counts==dict(raw_logical_refusals=4,precommit_io_refusals=8,windows_stage6_publications=2,actual_terminations=4)
 original_failure=None
 if writer.exists():
  old=root/'incumbent-v2';original_failure=(old/'physical/0285.stderr').read_text();assert 'undefined reference' in original_failure and 'fsync' in original_failure
  assert not (old/'physical/O0/thermal.exe').exists()
  assert counterfactual['publication-only-O0']==24 and counterfactual['publication-only-O2']==30
 return dict(objects=objects,native=native,malformed_refusals=refusals,exact_reexports=positives,writer_counts=writer_counts,malformed_accepted=counterfactual,original_failure_sha256=p.sha(original_failure.encode()) if original_failure else None,production_admission=False)

def refusals(root,expected):
 # Mutation occurs only in this replay's disposable extraction, never an
 # authoritative generation or the immutable archive. Test semantic bindings
 # as well as the outer archive checksum.
 controls=root/('controls-v1' if (root/'controls-v1').exists() else 'controls')
 targets=[root/'candidate-v2/physical/O0/2/full.bin',root/next(iter(expected['objects'])),controls/'0.stdout']
 if (root/'writer-windows-v3').exists():targets.append(root/'writer-windows-v3/O0/io-2/authority')
 for target in targets:
  original=target.read_bytes();mutant=bytearray(original);mutant[0]^=1
  if target.name=='0.stdout':mutant=original.replace(b'PROBE_STATUS=0',b'PROBE_STATUS=1',1);assert mutant!=original
  target.write_bytes(mutant)
  try:
   refused=False
   try:assert audit(root)==expected
   except AssertionError:refused=True
   assert refused,('mutated evidence accepted',target)
  finally:target.write_bytes(original)
 print('RAW_NATIVE_OBJECT_READER_AND_AUTHORITY_EVIDENCE_REFUSALS_PASS',len(targets))

def seal(root,stem):
 report=audit(root);members={}
 with tempfile.TemporaryDirectory(prefix='s5-mt-seal-') as tmp:
  archive=Path(tmp)/'cohort.tar.xz'
  with tarfile.open(archive,'w:xz',preset=1) as tar:
   for folder in ('candidate-v2','incumbent-v2','controls-v1','writer-windows-v3'):
    for file in sorted((root/folder).rglob('*')):
     if not file.is_file():continue
     name=file.relative_to(root).as_posix();raw=file.read_bytes();members[name]=p.sha(raw);info=tarfile.TarInfo(name);info.size=len(raw);tar.addfile(info,io.BytesIO(raw))
  raw=archive.read_bytes();parts=[]
  for i,start in enumerate(range(0,len(raw),45000000),1):
   chunk=raw[start:start+45000000];file=DEST/(stem+'.tar.xz.part'+str(i));file.write_bytes(chunk);parts.append(dict(path=file.name,sha256=p.sha(chunk),bytes=len(chunk)))
 record=dict(parts=parts,members=members,archive_sha256=p.sha(raw),archive_bytes=len(raw),audit=report,production_admission=False)
 (DEST/(stem+'.json')).write_text(json.dumps(record,indent=2)+'\n');print('COMPLETE_NATIVE_COHORT_SEALED',len(members),len(raw))

def replay(stem):
 r=json.loads((DEST/(stem+'.json')).read_text());chunks=[]
 for part in r['parts']:
  raw=(DEST/part['path']).read_bytes();assert len(raw)==part['bytes'] and p.sha(raw)==part['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert len(raw)==r['archive_bytes'] and p.sha(raw)==r['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-mt-replay-') as tmp:
  root=Path(tmp);members={}
  with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
   for item in tar:
    assert item.isfile() and not Path(item.name).is_absolute() and '..' not in Path(item.name).parts and item.name not in members
    data=tar.extractfile(item).read();members[item.name]=p.sha(data);file=root/item.name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
  assert members==r['members'] and audit(root)==r['audit'];refusals(root,r['audit'])
 print('COMPLETE_NATIVE_COHORT_INDEPENDENT_REPLAY_PASS')

def posix_audit(root):
 result={role:audit(root,role) for role in ('incumbent-v2','candidate-v2')}
 for role in result:
  physical=root/role/'physical';folder=root/'qualification'/role;r=json.loads((folder/'result.json').read_text())
  assert r['physical_sha256']==p.sha((physical/'result.json').read_bytes())
  assert r['status']=='DYNAMIC_ACCEPTED_ENDPOINT_DECAY_O0_O2_RESTART_REFINEMENT_CRASH_PASS_NOT_ADMITTED'
  for name,digest in r['inputs'].items():assert p.sha(before(name.replace('\\','/')).encode())==digest
  for opt in ('O0','O2'):
   row=r['results'][opt];assert row['windows']==[2,4,8,16,32,64,128]
   for key in ('mass_delta','decay_delta'):assert all(a>b>0 for a,b in zip(row[key],row[key][1:]))
   assert row['final_relative_decay_difference']<1e-3 and row['kill_before_after_generation_exact'] is True
   # Raw termination authority and fresh recovery, rather than just verdicts.
   for phase,name in (('before','restart.bin'),('after','full.bin')):
    expected=(physical/opt/'2'/name).read_bytes();case=folder/opt/('kill-'+phase)
    assert (case/'generation.bin').read_bytes()==expected
    if phase=='before':assert (case/'fresh.bin').read_bytes()==(physical/opt/'2/full.bin').read_bytes()
  assert sum(e['category']=='crash_native' and e['returncode']==-9 for e in r['events'])==4
  result[role]['qualification_sha256']=p.sha((folder/'result.json').read_bytes())
 writer=root/'writer-posix'
 if writer.exists():
  wr=json.loads((writer/'RESULT.json').read_text());assert len(wr['events'])==14
  for event in wr['events']:
   opt=event['optimization'];kind=event['kind'];value=event['value'];case=writer/opt/(kind+'-'+str(value));text=(writer/event['stdout']).read_text()
   old=(root/'candidate-v2/physical'/opt/'2/restart.bin').read_bytes();good=(root/'candidate-v2/physical'/opt/'2/full.bin').read_bytes()
   assert 'WRITE_STATUS=1' in text and event['reported_failure'] is True
   assert event['published']==(kind=='io' and value==6)
   assert (case/'authority').read_bytes()==(good if event['published'] else old) and (case/'after').read_bytes()==good
   if kind=='logical':assert int(re.search(r'INJECT_BITS\s+(-?\d+)\s+(-?\d+)',text)[value])==2
  result['posix_writer']=dict(raw_logical_refusals=4,precommit_io_refusals=8,postcommit_dirsync_refusals=2,report_sha256=p.sha((writer/'RESULT.json').read_bytes()))
 return result

def posix(archive=None,materialize=None):
 stem='MATRIX_THERMAL_NATIVE_POSIX_20261106';path=DEST/(stem+'.json')
 if archive:raw=archive.read_bytes()
 else:
  record=json.loads(path.read_text());raw=b''.join((DEST/part['path']).read_bytes() for part in record['parts']);assert p.sha(raw)==record['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-mt-posix-') as tmp:
  root=Path(tmp);members={}
  with zipfile.ZipFile(io.BytesIO(raw)) as zip:
   for name in zip.namelist():
    assert name not in members and not Path(name).is_absolute() and '..' not in Path(name).parts
    if name.endswith('/'):continue
    data=zip.read(name);members[name]=p.sha(data);file=root/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
  report=posix_audit(root)
  refusals(root,report['candidate-v2'])
  if materialize:
   assert not materialize.exists();shutil.copytree(root,materialize)
 if archive:
  parts=[]
  for i,start in enumerate(range(0,len(raw),45000000),1):
   chunk=raw[start:start+45000000];file=DEST/(stem+'.zip.part'+str(i));file.write_bytes(chunk);parts.append(dict(path=file.name,sha256=p.sha(chunk),bytes=len(chunk)))
  path.write_text(json.dumps(dict(parts=parts,members=members,archive_sha256=p.sha(raw),archive_bytes=len(raw),audit=report,production_admission=False),indent=2)+'\n')
 else:assert members==record['members'] and report==record['audit']
 print('COMPLETE_POSIX_NATIVE_COHORT_INDEPENDENT_REPLAY_PASS')

def posix_writer(archive=None):
 stem='MATRIX_THERMAL_NATIVE_POSIX_WRITER_20261106';record_path=DEST/(stem+'.json');zip_path=DEST/(stem+'.zip')
 if archive:raw=archive.read_bytes()
 else:
  record=json.loads(record_path.read_text());raw=zip_path.read_bytes();assert p.sha(raw)==record['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-mt-writer-') as tmp:
  root=Path(tmp)/'cohort';posix(materialize=root);writer=root/'writer-posix';writer.mkdir();members={}
  with zipfile.ZipFile(io.BytesIO(raw)) as zip:
   for name in zip.namelist():
    assert name not in members and not Path(name).is_absolute() and '..' not in Path(name).parts
    if name.endswith('/'):continue
    data=zip.read(name);members[name]=p.sha(data);file=writer/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
  report=posix_audit(root)['posix_writer']
  for opt in ('O0','O2'):
   assert (writer/opt/'publication.c').read_bytes()==before('app/support/restart_publish.c').encode()
   ledger=json.loads((writer/opt/'BUILD.json').read_text());assert len(ledger)==5 and all(event['returncode']==0 for event in ledger)
  # Refuse a spurious success claim for the real postcommit directory-sync
  # failure, independently of the immutable archive's outer integrity check.
  text=writer/'6.stdout';original=text.read_bytes();text.write_bytes(original.replace(b'WRITE_STATUS=1',b'WRITE_STATUS=0',1))
  try:
   refused=False
   try:posix_audit(root)
   except AssertionError:refused=True
   assert refused
  finally:text.write_bytes(original)
 if archive:
  zip_path.write_bytes(raw);record_path.write_text(json.dumps(dict(archive_sha256=p.sha(raw),archive_bytes=len(raw),members=members,audit=report,production_admission=False,whole_scientific_admission=False),indent=2)+'\n')
 else:assert report==record['audit'] and members==record['members']
 print('COMPLETE_POSIX_NATIVE_WRITER_POSTCOMMIT_REFUSAL_AND_EVIDENCE_REFUSAL_PASS')

if __name__=='__main__':
 a=argparse.ArgumentParser();a.add_argument('--seal',type=Path);a.add_argument('--stem',default='MATRIX_THERMAL_NATIVE_WINDOWS_20261106');a.add_argument('--seal-posix',type=Path);a.add_argument('--posix',action='store_true');a.add_argument('--materialize-posix',type=Path);a.add_argument('--seal-posix-writer',type=Path);a.add_argument('--posix-writer',action='store_true');args=a.parse_args();p.guard()
 if args.seal_posix_writer or args.posix_writer:posix_writer(args.seal_posix_writer)
 elif args.seal_posix or args.posix or args.materialize_posix:posix(args.seal_posix,args.materialize_posix)
 else:seal(args.seal,args.stem) if args.seal else replay(args.stem)
