"""Raw complete build/link/response/native evidence; no production admission."""
import argparse,io,json,struct,subprocess,tarfile,tempfile,zipfile,zlib
from functools import lru_cache
from pathlib import Path
import matrix_thermal_build as owner
p=owner.private;DEST=p.ROOT/'integration/dataqual15_hupsel'
@lru_cache(None)
def before(name):return subprocess.check_output(['git','show',owner.BASE+':'+name],cwd=p.ROOT)

def audit(root):
 answer={}
 for role in ('candidate','incumbent'):
  base=root/role;summary=json.loads((base/'RESULT.json').read_text());r=json.loads((base/'physical/result.json').read_text());windows=summary['platform']=='nt'
  assert summary['platform'] in ('nt','posix')
  pins={name.replace('\\','/'):digest for name,digest in r['inputs'].items()}
  assert summary['role']==role and summary['runner_sha256']==pins[owner.RUNNER] and summary['module_sha256']==pins[p.SOURCE]
  assert summary['baseline']==owner.BASE and summary['production_admission'] is False and summary['whole_scientific_admission'] is False
  for name,digest in r['inputs'].items():
   name=name.replace('\\','/')
   expected=(p.ROOT/owner.RUNNER).read_bytes().replace(b'\r\n',b'\n') if name==owner.RUNNER else p.candidate().encode() if name==p.SOURCE and role=='candidate' else before(name)
   assert p.sha(expected)==digest,name
  def relocate(name):return base/name.replace('\\','/').split('/'+role+'/',1)[1]
  objects={};executables={};response_files={}
  for index,event in enumerate(r['events']):
   cmd=event['command'];category=event['category']
   if category in ('compile','compile_support'):
    assert event['returncode']==0 and event['executed_command']==cmd
    opt=cmd[-1].replace('\\','/').split('/physical/',1)[1].split('/')[0];assert opt in ('O0','O2') and '-'+opt in cmd
    assert ('-O2' if opt=='O0' else '-O0') not in cmd
    if category=='compile_support':assert '-std=c11' in cmd and cmd[-3].replace('\\','/').endswith('/app/support/restart_publish.c')
    obj=relocate(cmd[-1]);assert obj.is_file() and obj.stat().st_size>0;objects[obj.relative_to(root).as_posix()]=p.sha(obj.read_bytes())
   elif category=='link':
    opt=next(x[1:] for x in cmd if x in ('-O0','-O2'));compiled={name for name in objects if '/physical/'+opt+'/' in name};linked={relocate(x).relative_to(root).as_posix() for x in cmd if x.endswith('.o')};assert r.get('provider_count',284)==284 and linked==compiled and len(compiled)==286
    if windows:
     response=base/'physical'/opt/'link.args';raw=response.read_bytes();assert p.sha(raw)==event['response_sha256']
     expected='\n'.join('"'+x.replace('\\','/')+'"' for x in cmd[1:])+'\n';assert raw.replace(b'\r\n',b'\n').decode()==expected
     assert len(event['executed_command'])==2 and event['executed_command'][1].startswith('@');assert '-Wl,--stack,67108864' in cmd
     response_files[opt]=p.sha(raw)
    else:assert event['executed_command']==cmd and event['response_sha256'] is None
    if windows and role=='incumbent':
     assert event['returncode']!=0;error=(base/'physical'/f'{index:04d}.stderr').read_text();assert 'undefined reference' in error and 'fsync' in error;assert not relocate(cmd[-1]).exists();continue
    assert event['returncode']==0;binary=relocate(cmd[-1]).read_bytes();assert p.sha(binary)==r['executables'][opt];executables[opt]=p.sha(binary)
    if windows:
     offset=struct.unpack_from('<I',binary,0x3c)[0];assert binary[offset:offset+4]==b'PE\0\0' and struct.unpack_from('<Q',binary,offset+24+72)[0]==67108864
    else:assert binary[:4]==b'\x7fELF'
  native={}
  if not(windows and role=='incumbent'):
   assert summary['status']=='ACTUAL_PORTABLE_BUILD_COMPLETE_O0_O2_NATIVE_PHYSICAL_PASS' and set(executables)=={'O0','O2'}
   stem='MATRIX_THERMAL_NATIVE_WINDOWS_20261106' if windows else 'MATRIX_THERMAL_NATIVE_POSIX_20261106'
   expected=json.loads((DEST/(stem+'.json')).read_text())['audit'];expected=expected if windows else expected[role+'-v2'];expected=expected['native']
   for opt in ('O0','O2'):
    for grid in ('2','4','8','16'):
     for name in ('restart.bin','full.bin','resumed.bin'):
      path=base/'physical'/opt/grid/name;raw=path.read_bytes();assert raw[:8]==b'S5MT0001' and struct.unpack('<I',raw[-4:])[0]==zlib.crc32(raw[:-4])
      key=('candidate-v2' if windows else role+'-v2')+'/physical/'+opt+'/'+grid+'/'+name;assert p.sha(raw)==expected[key]
      native[path.relative_to(root).as_posix()]=p.sha(raw)
  else:assert summary['status']=='ACTUAL_ORIGINAL_WINDOWS_FSYNC_LINK_FAILURE_RETAINED'
  answer[role]=dict(platform=summary['platform'],objects=objects,executables=executables,response_files=response_files,native=native,status=summary['status'])
 return answer

def seal(root,stem):
 report=audit(root);members={};parts=[]
 with tempfile.TemporaryDirectory(prefix='s5-mtb-seal-') as tmp:
  archive=Path(tmp)/'cohort.tar.xz'
  with tarfile.open(archive,'w:xz',preset=1) as tar:
   for folder in ('candidate','incumbent'):
    for file in sorted((root/folder).rglob('*')):
     if not file.is_file():continue
     name=file.relative_to(root).as_posix();raw=file.read_bytes();members[name]=p.sha(raw);entry=tarfile.TarInfo(name);entry.size=len(raw);tar.addfile(entry,io.BytesIO(raw))
  raw=archive.read_bytes()
  for i,start in enumerate(range(0,len(raw),45000000),1):
   chunk=raw[start:start+45000000];file=DEST/(stem+'.tar.xz.part'+str(i));file.write_bytes(chunk);parts.append(dict(path=file.name,bytes=len(chunk),sha256=p.sha(chunk)))
 (DEST/(stem+'.json')).write_text(json.dumps(dict(parts=parts,members=members,archive_sha256=p.sha(raw),archive_bytes=len(raw),audit=report,production_admission=False,whole_scientific_admission=False),indent=2)+'\n');print('ACTUAL_BUILD_COHORT_SEALED',len(raw),len(members))

def replay(stem):
 record=json.loads((DEST/(stem+'.json')).read_text());chunks=[]
 for part in record['parts']:
  raw=(DEST/part['path']).read_bytes();assert len(raw)==part['bytes'] and p.sha(raw)==part['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert len(raw)==record['archive_bytes'] and p.sha(raw)==record['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-mtb-replay-') as tmp:
  root=Path(tmp);members={}
  with tarfile.open(fileobj=io.BytesIO(raw)) as tar:
   for item in tar:
    assert item.isfile() and not Path(item.name).is_absolute() and '..' not in Path(item.name).parts and item.name not in members
    data=tar.extractfile(item).read();members[item.name]=p.sha(data);file=root/item.name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(data)
  assert members==record['members'] and audit(root)==record['audit']
  # Detect data drift independently of merely checking the container hash.
  target=root/'candidate/physical/O0/2/full.bin';original=target.read_bytes();mutant=bytearray(original);mutant[0]^=1;target.write_bytes(mutant)
  try:
   refused=False
   try:audit(root)
   except AssertionError:refused=True
   assert refused
  finally:target.write_bytes(original)
 print('ACTUAL_BUILD_COMPLETE_SOURCE_OBJECT_LINK_NATIVE_AND_DATA_REFUSAL_PASS')

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--seal',type=Path);parser.add_argument('--seal-zip',type=Path);parser.add_argument('--stem',default='MATRIX_THERMAL_BUILD_WINDOWS_20261106');a=parser.parse_args();owner.guard()
 if a.seal_zip:
  with tempfile.TemporaryDirectory(prefix='s5-mtb-download-') as tmp:
   root=Path(tmp)
   with zipfile.ZipFile(a.seal_zip) as zip:
    assert len(zip.namelist())==len(set(zip.namelist()))
    for name in zip.namelist():
     assert not Path(name).is_absolute() and '..' not in Path(name).parts
     if name.endswith('/'):continue
     file=root/name;file.parent.mkdir(parents=True,exist_ok=True);file.write_bytes(zip.read(name))
   seal(root,a.stem)
 elif a.seal:seal(a.seal,a.stem)
 else:replay(a.stem)
