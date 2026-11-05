"""Independent complete-module compilation and native POSIX evidence audit.

Windows compilation is deliberately never reported as a public writer proof.
"""
import argparse,hashlib,io,json,subprocess,tarfile,zipfile
from pathlib import Path
import generation_crc_runtime as policy
import native_n_crc_evidence as snapshots
ROOT=policy.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()
normal=lambda b:b.replace(b'\r\n',b'\n')
def local_audit(files):
 r=json.loads(files['RESULT.json']);m=json.loads(files['PROVENANCE.json'])
 assert r['status']=='COMPLETE_GENERATION_MODULE_COHERENT_COMPILATION_ONLY' and r['native_publication_executed']is False and r['production_admission']is False
 for name,h in m['logs_sha256'].items():assert sha(files[name])==h
 for name,row in m['sources'].items():
  raw=files[row['snapshot']];assert sha(raw)==row['sha256']
  if row['kind']=='repository':assert normal(raw)==normal(policy.before(row['path'])if row['path']in policy.SOURCES.values()else(ROOT/row['path']).read_bytes())
  elif row['kind']=='candidate':assert normal(raw).decode()==policy.postimage(policy.before(row['path']).decode())
  else:assert row['kind']=='generated'and normal(raw)==normal(files[row['path']])
 for role in ('incumbent','candidate'):
  b=json.loads(files[role+'/BUILD.json']);events=json.loads(files[role+'/EVENTS.json'])
  assert b['provider_count']==r['providers'] and b['provider_count']>300 and b['candidate']==(role=='candidate')
  assert not b['executables_sha256']and not b['drivers_sha256']
  assert all(x in b['flags']for x in ('-'+r['optimization'],'-fcheck=all','-ffpe-trap=invalid,zero,overflow','-fopenmp'))
  assert len(events)==(2 if role=='candidate'else b['provider_count']) and all(e['returncode']==0 and e['label']=='provider'for e in events)
  for p,h in b['sources_sha256'].items():assert m['sources'][p]['sha256']==h
  for p,h in b['objects_sha256'].items():assert sha(files[snapshots.local_name(p,m['root'])])==h
 return dict(complete_providers=r['providers'],optimization=r['optimization'],postimage_full_modules=2,native_publication_executed=False)
def controls(files):
 m=json.loads(files['PROVENANCE.json']);b=json.loads(files['candidate/BUILD.json']);object_name=snapshots.local_name(next(iter(b['objects_sha256'])),m['root'])
 source=next(row['snapshot']for row in m['sources'].values()if row['kind']=='candidate');log=next(iter(m['logs_sha256']));targets=[object_name,source,log]
 for n in targets:
  mutant=dict(files);mutant[n]=mutant[n]+b'!bad'
  try:local_audit(mutant)
  except (AssertionError,ValueError,KeyError):pass
  else:raise AssertionError('corrupted complete compilation evidence admitted: '+n)
 return targets
def seal_local(out):
 for opt in ('O0','O2'):
  directory=out/opt;old=snapshots.policy;snapshots.policy=policy
  try:snapshots.snapshot(directory)
  finally:snapshots.policy=old
  files={p.relative_to(directory).as_posix():p.read_bytes()for p in directory.rglob('*')if p.is_file()}
  report=dict(audit=local_audit(files),controls=controls(files));stem='GENERATION_CRC_WINDOWS_20261105_'+opt;path=BASE/(stem+'.tar.xz')
  with tarfile.open(path,'w:xz')as t:
   for n,raw in sorted(files.items()):info=tarfile.TarInfo(n);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
  (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(raw)for n,raw in files.items()},report=report,native_publication_executed=False),indent=2)+'\n')
def local():
 for opt in ('O0','O2'):
  stem='GENERATION_CRC_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
  with tarfile.open(fileobj=io.BytesIO(raw))as t:
   assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
  assert {n:sha(raw)for n,raw in files.items()}==r['files_sha256'];assert dict(audit=local_audit(files),controls=controls(files))==r['report']
 print('COMPLETE_GENERATION_WINDOWS_O0_O2_COMPILE_ONLY_AND_THREE_DATA_REFUSALS_PASS')
def main():
 p=argparse.ArgumentParser();p.add_argument('--seal-local',type=Path);a=p.parse_args();policy.guard()
 if a.seal_local:seal_local(a.seal_local.resolve())
 local()
if __name__=='__main__':main()
