"""Independent source/object/native raw-byte audit for private matrix reader."""
import argparse,functools,io,json,lzma,struct,tarfile,tempfile,zlib
from pathlib import Path,PureWindowsPath,PurePosixPath
import matrix_logical_runtime as g
sha=g.sha
@functools.lru_cache(maxsize=1)
def expected():
 with tempfile.TemporaryDirectory(prefix='s5-matrix-logical-audit-')as t:
  fixture,ordered,drivers=g.original.prepare(Path(t)/'fixture-view')
  sources=[]
  for p in ordered:
   if p.is_relative_to(g.ROOT):sources.append((p.relative_to(g.ROOT).as_posix(),p.read_bytes()))
   else:sources.append((p.name,p.read_bytes()))
  return sources,{n:(p.relative_to(g.ROOT).as_posix(),p.read_bytes())for n,p in drivers.items()}
def audit(files):
 r=json.loads(files['RESULT.json']);assert r['baseline']==g.guard()['baseline']and r['production_admission']is False and r['whole_scientific_admission']is False
 sources,drivers=expected();assert r['provider_count']==len(sources);q=PureWindowsPath if r['platform']=='WINDOWS'else PurePosixPath
 for role in ('incumbent','candidate'):
  b=json.loads(files[role+'/BUILD.json']);assert b['provider_count']==len(sources)and len(b['bindings'])==len(sources)
  events=json.loads(files[role+'/EVENTS.json']);assert all(e['stdout']and e['stderr']and role+'/'+e['stdout']in files and role+'/'+e['stderr']in files for e in events)
  assert all(e['returncode']==0 for e in events if e['label']!='logical')
  assert len([e for e in events if e['label']=='provider'])==(len(sources)if role=='incumbent'else 1)
  assert len([e for e in events if e['label']=='driver'])==2 and len([e for e in events if e['label']=='link'])==2
  root=q(b['bindings'][0]['object']).parent.parent
  for binding,(name,raw)in zip(b['bindings'],sources):
   expected_raw=g.postimage(g.raw(r['baseline'],g.SOURCE))if role=='candidate'and name==g.SOURCE else raw
   actual=files[role+'/'+binding['snapshot']];assert actual.replace(b'\r\n',b'\n')==expected_raw.replace(b'\r\n',b'\n')and sha(actual)==binding['source_sha256']
   if name.startswith(('src/','tests/')):assert raw.replace(b'\r\n',b'\n')==g.raw(r['baseline'],name)
   obj=q(binding['object']);rel=obj.relative_to(root).as_posix();assert sha(files[rel])==binding['object_sha256'];assert binding['reused']==(role=='candidate'and name!=g.SOURCE)
  for name,(path,raw)in drivers.items():
   d=b['drivers'][name];assert raw.replace(b'\r\n',b'\n')==g.raw(r['baseline'],path);assert files[role+'/'+d['source']]==raw and sha(raw)==d['source_sha256'];assert sha(files[role+'/'+d['executable']])==d['executable_sha256']
  assert files[role+'/publisher.c'].replace(b'\r\n',b'\n')==g.raw(r['baseline'],'app/support/restart_publish.c')
  assert len(r['results'][role]['logical'])==72
  logical_events=[e for e in events if e['label']=='logical'];assert len(logical_events)==72
  for row,event in zip(r['results'][role]['logical'],logical_events):
   data=files[role+'/'+row['file']];assert zlib.crc32(data[:-4])==struct.unpack('<I',data[-4:])[0];assert struct.unpack_from('<i',data,row['offset'])[0]==row['value'];assert row['field']in ('time_bound','has_history')and row['offset']==dict(time_bound=148,has_history=156)[row['field']]
   refused=event['returncode']==0 and b'MATRIX_JOINT_INVALID_FILE=PASS'in files[role+'/'+event['stdout']];assert refused==row['refused']and row['returncode']==event['returncode'];assert refused or role=='incumbent'
  for exponent,old in r['results'][role]['original'].items():
   assert old['exact_own_fresh_endpoint']and old['independent_crc_pass']and old['base_crc_pass']and old['correct_valid_returncode']==0 and all(x['refused']for x in old['refusals'])
   prefix=role+'/n'+exponent+'/';assert files[prefix+'end.bin']==files[prefix+'fresh.bin']==files[prefix+'correct-end.bin']
   for name in ('restart.bin','restart.bin.base'):
    data=files[prefix+name];assert zlib.crc32(data[:-4])==struct.unpack('<I',data[-4:])[0]
 assert files['candidate/mod_matrix_joint_restart_file.mod']==files['incumbent/mod_matrix_joint_restart_file.mod']
 for exponent in g.original.EXPONENTS:
  for name in ('restart.bin','restart.bin.base','end.bin','fresh.bin'):assert files['incumbent/n'+exponent+'/'+name]==files['candidate/n'+exponent+'/'+name]
 return dict(provider_count=len(sources),fresh_provider_compiles=len(sources),private_reader_compiles=1,complete_original_driver_compiles=4,original_exponents=6,malformed_logical_controls_per_role=72,baseline_logical_refusals=sum(x['refused']for x in r['results']['incumbent']['logical']),private_logical_refusals=72,production_admission=False,whole_scientific_admission=False)
def pack(out,stem):
 files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};m=audit(files);b=json.loads(files['candidate/BUILD.json']);first=b['bindings'][0];r=json.loads(files['RESULT.json']);paths=['candidate/'+first['snapshot'],'incumbent/000.o','candidate/'+b['drivers']['joint']['source'],'candidate/'+b['drivers']['joint']['executable'],'candidate/n1/restart.bin','candidate/EVENTS.json'];count=0
 for path in paths:
  bad=dict(files);bad[path]=b''
  try:audit(bad)
  except(AssertionError,KeyError,ValueError,struct.error):count+=1
  else:raise AssertionError('corrupt evidence admitted '+path)
 assert count==6;m['evidence_corruption_refusals']=count;buf=io.BytesIO()
 with tarfile.open(fileobj=buf,mode='w')as t:
  for name,raw in files.items():p=tarfile.TarInfo(name);p.size=len(raw);t.addfile(p,io.BytesIO(raw))
 raw=lzma.compress(buf.getvalue());stem.with_suffix('.tar.xz').write_bytes(raw);stem.with_suffix('.json').write_text(json.dumps(dict(archive=stem.name+'.tar.xz',sha256=sha(raw),members={n:sha(b)for n,b in files.items()},measurement=m),indent=2)+'\n');print(json.dumps(m))
def verify(stem):
 m=json.loads(stem.with_suffix('.json').read_text());raw=stem.with_suffix('.tar.xz').read_bytes();assert sha(raw)==m['sha256']
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(raw)),mode='r:')as t:
  members=t.getmembers();assert all(x.isfile()for x in members)and len(set(x.name for x in members))==len(members);files={x.name:t.extractfile(x).read()for x in members}
 assert {n:sha(b)for n,b in files.items()}==m['members'];a=audit(files);assert {k:v for k,v in m['measurement'].items()if k!='evidence_corruption_refusals'}==a and m['measurement']['evidence_corruption_refusals']==6;print(json.dumps(a))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path);p.add_argument('--stem',type=Path,required=True);a=p.parse_args()
 if a.output:pack(a.output.resolve(),a.stem.resolve())
 else:verify(a.stem.resolve())
