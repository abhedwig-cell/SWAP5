"""Remeasure complete actual current production build and original native assertions."""
import argparse,io,json,re,struct,tarfile,tempfile,zipfile
from pathlib import Path
import generation_publication_admission as owner
from generation_crc_posix_evidence import valid_generation,STEPS
ROOT=owner.ROOT;DEST=ROOT/'integration/dataqual15_hupsel';STEM='GENERATION_PUBLICATION_BUILD_POSIX_20261106';sha=owner.sha

def audit(folder):
 folder=folder.resolve();r=json.loads((folder/'RESULT.json').read_text());assert r['status']=='ACTUAL_CURRENT_PRODUCTION_BUILD_AND_FIVE_NATIVE_RECIPES_O0_O2_PASS'
 assert r['whole_scientific_admission'] is False
 assert r['production_sha256']=={n:sha(owner.normal((ROOT/n).read_bytes())) for n in owner.SOURCES}
 events=json.loads((folder/'EVENTS.json').read_text());assert events==r['events'] and len(events)==5 and all(e['returncode']==0 for e in events)
 original=events[0]['command'][events[0]['command'].index('--output')+1].removesuffix('/accepted')
 def local(n):
  assert n.startswith(original+'/');return folder/n[len(original)+1:]
 positives={};pinned={};c_compiles=0;links=0
 for step,status in STEPS.items():
  path=folder/step;q=json.loads((path/'result.json').read_text());assert q==r['results'][step] and q['status']==status and q['results']['O0']==q['results']['O2']
  assert sha((path/'driver.f90').read_bytes())==q['generated_driver_sha256']
  for key in ('input_sha256','physical_input_sha256','cold_input_sha256'):
   for n,h in q.get(key,{}).items():assert sha(owner.normal((ROOT/n).read_bytes()))==h,(step,n)
  for key in ('pinned_object_sha256','pinned_artifacts'):
   for n,h in q.get(key,{}).items():assert sha(local(n).read_bytes())==h,(step,n);pinned[n]=h
  ledger=json.loads((path/'events.json').read_text());assert ledger and all(e['returncode']==0 for e in ledger)
  for e in ledger:
   cmd=e['command']
   for stream in ('stdout','stderr'):(path/e[stream]).read_bytes()
   if e['category']=='publication_compile':
    c_compiles+=1;assert '-std=c11' in cmd and any(n.endswith('/app/support/restart_publish.c') for n in cmd)
   if e['category']=='link':
    links+=1;assert '-fcheck=all' in cmd and '-ffpe-trap=invalid,zero,overflow' in cmd
    objects=[n for n in cmd if n.endswith('.o')];assert len([n for n in objects if n.endswith('/restart_publish.o')])==1,'publisher absent or duplicated'
  if step in ('joint','saved'):
   for opt in ('O0','O2'):
    crashes=q['results'][opt]['crashes'];assert set(crashes)=={'before','after'} and all(v['returncode']==-9 and v['complete'] for v in crashes.values())
    for p in (path/opt).iterdir():
     if not p.is_file():continue
     selected=(step=='joint' and p.name in ('model.restart.generation','model.endpoint.generation')) or (step=='saved' and re.fullmatch(r'endpoint(?:\.stages)?\.(?:saved|deferred)\.(?:phase-[123]|day-[34])',p.name))
     if selected:raw=p.read_bytes();valid_generation(raw);positives[p.relative_to(folder).as_posix()]=sha(raw)
 assert len(positives)==24 and len(pinned)>2000 and c_compiles==4 and links==14
 private=json.loads((DEST/'GENERATION_PUBLICATION_POSIX_20261106.json').read_text())
 expected={n.split('/publication-models/',1)[1]:h for n,h in private['model_report']['positive_generation_sha256'].items()};assert positives==expected,'current build changed native authority bytes'
 return dict(positive_generation_sha256=positives,pinned_objects=len(pinned),c_compiles=c_compiles,actual_links=links,original_process_assertions=True,whole_scientific_admission=False)

def run(archive=None):
 record_path=DEST/(STEM+'.json')
 if archive:
  raw=archive.read_bytes();record=dict(archive_sha256=sha(raw),archive_bytes=len(raw),parts=[])
  for i,start in enumerate(range(0,len(raw),45000000),1):
   chunk=raw[start:start+45000000];p=DEST/(STEM+'.zip.part'+str(i));p.write_bytes(chunk);record['parts'].append(dict(path=p.name,bytes=len(chunk),sha256=sha(chunk)))
 else:
  record=json.loads(record_path.read_text());chunks=[]
  for part in record['parts']:
   chunk=(DEST/part['path']).read_bytes();assert sha(chunk)==part['sha256'] and len(chunk)==part['bytes'];chunks.append(chunk)
  raw=b''.join(chunks);assert sha(raw)==record['archive_sha256'] and len(raw)==record['archive_bytes']
 with tempfile.TemporaryDirectory(prefix='s5pub-build-') as tmp:
  folder=Path(tmp);members={}
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   for n in z.namelist():
    if n.endswith('/'):continue
    assert n not in members and not Path(n).is_absolute() and '..' not in Path(n).parts
    content=z.read(n);members[n]=sha(content);p=folder/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(content)
  result=audit(folder)
  # A valid manifest cannot substitute edited native/model data.
  target=folder/next(iter(result['positive_generation_sha256']));original=target.read_bytes();target.write_bytes(original+b'!corrupt')
  try:audit(folder)
  except (AssertionError,ValueError,struct.error):pass
  else:raise AssertionError('corrupted current native authority admitted')
  target.write_bytes(original)
  if archive:record.update(members=members,report=result);record_path.write_text(json.dumps(record,indent=2)+'\n')
  else:assert members==record['members'] and result==record['report']
 print('ACTUAL_CURRENT_BUILD_FULL_NATIVE_POSTIMAGES_AND_DATA_REFUSAL_PASS')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);a=p.parse_args();owner.guard();run(a.seal)
