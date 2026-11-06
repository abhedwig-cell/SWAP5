"""Lossless native cohort retention and safe, independently remeasured replay."""
import argparse,hashlib,io,json,tarfile,tempfile,zipfile
from pathlib import Path
import generation_publication_policy as policy
from generation_publication_audit import audit,fault_audit,controls
ROOT=policy.ROOT;DEST=ROOT/'integration/dataqual15_hupsel';sha=policy.sha
STEM='GENERATION_PUBLICATION_WINDOWS_20261106'

def seal(source):
 source=source.resolve();report=audit(source/'candidate');faults=fault_audit(source/'candidate',source/'windows-faults')
 record=dict(model_report=report,fault_report=faults,production_admission=False,members={},parts=[])
 with tempfile.TemporaryDirectory(prefix='s5-pub-seal-') as tmp:
  archive=Path(tmp)/'cohort.tar.xz'
  with tarfile.open(archive,'w:xz',preset=1) as t:
   for folder in ('candidate','incumbent','windows-faults'):
    for p in sorted((source/folder).rglob('*')):
     if not p.is_file():continue
     n=p.relative_to(source).as_posix();raw=p.read_bytes();record['members'][n]=sha(raw);info=tarfile.TarInfo(n);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
  record['archive_sha256']=sha(archive.read_bytes());record['archive_bytes']=archive.stat().st_size
  with archive.open('rb') as f:
   i=0
   while raw:=f.read(45000000):
    i+=1;p=DEST/(STEM+'.tar.xz.part'+str(i));p.write_bytes(raw);record['parts'].append(dict(path=p.name,bytes=len(raw),sha256=sha(raw)))
 (DEST/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n');print('WINDOWS_NATIVE_FULL_COHORT_SEALED',len(record['members']))

def replay():
 component()
 record=json.loads((DEST/(STEM+'.json')).read_text());chunks=[]
 for part in record['parts']:
  raw=(DEST/part['path']).read_bytes();assert len(raw)==part['bytes'] and sha(raw)==part['sha256'];chunks.append(raw)
 raw=b''.join(chunks);assert len(raw)==record['archive_bytes'] and sha(raw)==record['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-pub-replay-') as tmp:
  folder=Path(tmp);observed={}
  with tarfile.open(fileobj=io.BytesIO(raw)) as t:
   for m in t:
    assert m.isfile() and m.name not in observed and not Path(m.name).is_absolute() and '..' not in Path(m.name).parts
    content=t.extractfile(m).read();observed[m.name]=sha(content);assert record['members'][m.name]==observed[m.name]
    p=folder/m.name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
  assert observed==record['members'];actual=audit(folder/'candidate');expected=record['model_report']
  # Location is not scientific data: retain and compare the complete relative
  # membership and every digest while the isolated replay directory differs.
  relative=lambda report:{n.replace('\\','/').split('/candidate/',1)[1]:h for n,h in report['positive_generation_sha256'].items()}
  assert relative(actual)==relative(expected)
  for key in ('platform','pinned_objects','actual_links','production_admission'):assert actual[key]==expected[key]
  assert fault_audit(folder/'candidate',folder/'windows-faults')==record['fault_report']
  assert len(controls(folder/'candidate',actual))==4
 print('WINDOWS_NATIVE_FULL_COHORT_INDEPENDENT_REPLAY_PASS')

def component():
 stem='GENERATION_PUBLICATION_WINDOWS_COMPONENT_20261106';r=json.loads((DEST/(stem+'.json')).read_text());raw=(DEST/(stem+'.zip')).read_bytes();assert sha(raw)==r['archive_sha256']
 with zipfile.ZipFile(io.BytesIO(raw)) as z:files={n:z.read(n) for n in z.namelist()}
 assert {n:sha(raw) for n,raw in files.items()}==r['members'];c=json.loads(files['c-probe/RESULT.json'])
 assert c['status']==r['c_api']=='REAL_NATIVE_PUBLISHER_BEFORE_AFTER_AND_PRECOMMIT_FAULT_STATES_PASS' and c['platform']=='nt'
 for opt in ('O0','O2'):
  old=c['results'][opt]['incumbent'];new=c['results'][opt]['candidate'];assert old['restart']==new['restart'] and old['crc']==new['crc']
  for role,report in (('incumbent',old),('candidate',new)):
   prefix='c-probe/'+opt+'-'+role+'/';source=files[prefix+'publication.c'];assert sha(source)==report['source_sha256']
   assert source.decode()==(policy.before(policy.C) if role=='incumbent' else policy.candidate_c())
   assert sha(files[prefix+'probe.dll'])==report['binary_sha256']
  assert [x['status'] for x in new['generation'][:6]]==[0,2,3,4,5,1]
  assert [x['published'] for x in new['generation'][:6]]==[True,False,False,False,False,False]
 crt=json.loads(files['crt/RESULT.json']);assert crt==r['crt'] and crt['reports'][0]['returncode']==0 and crt['reports'][1]['errno']==17 and crt['reports'][1]['returncode']!=0

def posix(archive=None):
 stem='GENERATION_PUBLICATION_POSIX_20261106';record_path=DEST/(stem+'.json')
 if archive:
  raw=archive.read_bytes();record=dict(archive_sha256=sha(raw),archive_bytes=len(raw),parts=[],production_admission=False)
  for i,start in enumerate(range(0,len(raw),45000000),1):
   chunk=raw[start:start+45000000];p=DEST/(stem+'.zip.part'+str(i));p.write_bytes(chunk);record['parts'].append(dict(path=p.name,bytes=len(chunk),sha256=sha(chunk)))
 else:
  record=json.loads(record_path.read_text());chunks=[]
  for part in record['parts']:
   chunk=(DEST/part['path']).read_bytes();assert len(chunk)==part['bytes'] and sha(chunk)==part['sha256'];chunks.append(chunk)
  raw=b''.join(chunks);assert len(raw)==record['archive_bytes'] and sha(raw)==record['archive_sha256']
 with tempfile.TemporaryDirectory(prefix='s5-pub-posix-') as tmp:
  folder=Path(tmp);members={}
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   for n in z.namelist():
    assert n not in members and not Path(n).is_absolute() and '..' not in Path(n).parts
    if n.endswith('/'):continue
    content=z.read(n);members[n]=sha(content);p=folder/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
  result=audit(folder/'publication-models');assert result['platform']=='posix'
  assert len(controls(folder/'publication-models',result))==4
  c=json.loads((folder/'publication-c/RESULT.json').read_text());assert c['status']=='REAL_NATIVE_PUBLISHER_BEFORE_AFTER_AND_PRECOMMIT_FAULT_STATES_PASS' and c['platform']=='posix'
  if archive:
   record.update(members=members,model_report=result,c_api=c);record_path.write_text(json.dumps(record,indent=2)+'\n')
  else:
   assert members==record['members'] and c==record['c_api']
   relative=lambda report:{n.replace('\\','/').split('/publication-models/',1)[1]:h for n,h in report['positive_generation_sha256'].items()}
   assert relative(result)==relative(record['model_report'])
   for key in ('platform','pinned_objects','actual_links','production_admission'):assert result[key]==record['model_report'][key]
 print('POSIX_NATIVE_FULL_COHORT_INDEPENDENT_REPLAY_PASS')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);p.add_argument('--seal-posix',type=Path);p.add_argument('--posix',action='store_true');a=p.parse_args();policy.guard()
 if a.posix or a.seal_posix:posix(a.seal_posix)
 else:seal(a.seal) if a.seal else replay()
