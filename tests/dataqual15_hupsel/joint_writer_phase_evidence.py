"""Independent complete source/object/command audit of the PR1605 cold graph."""
import argparse,hashlib,io,json,lzma,struct,subprocess,tarfile,zlib
from pathlib import Path,PureWindowsPath,PurePosixPath
import joint_writer_phase_cold as producer
ROOT=producer.ROOT
def sha(b):return hashlib.sha256(b).hexdigest()
def audit(files):
 r=json.loads(files['RESULT.json']);assert r['status']=='EXACT_PR1605_COLD335_NATIVE_PASS_NOT_ADMITTED'
 assert r['source_head']==producer.SOURCE and r['provider_count']==335 and r['provider_objects_reused']==0
 assert r['production_admission']is False and r['whole_scientific_admission']is False
 assert r['production_trees']=={p:producer.git(ROOT,'rev-parse',producer.SOURCE+':'+p)for p in('src','app','reference')}
 path='tests/dataqual15_hupsel/joint_writer_phase_cold.py'
 assert r['producer_sha256']==sha(subprocess.check_output(['git','show',r['producer_head']+':'+path],cwd=ROOT))
 b=json.loads(files['baseline/BUILD.json']);events=json.loads(files['baseline/EVENTS.json']);q=PureWindowsPath if r['platform']=='WINDOWS'else PurePosixPath
 assert r['platform']in('WINDOWS','POSIX')and r['optimization']in('O0','O2')and b['provider_count']==335
 assert '-'+r['optimization']in b['flags']and'-ffpe-trap=invalid,zero,overflow'in b['flags']and'-fcheck=all'in b['flags']
 rows={x['source']:x for x in r['sources']};source_keys=list(b['sources_sha256']);objects=list(b['objects_sha256']);assert len(source_keys)==len(objects)==335
 provider_events=[e for e in events if e['label']=='provider'];assert len(provider_events)==335
 buildroot=q(objects[0]).parent
 def local(path):
  p=q(path)
  return 'baseline/'+(p.relative_to(buildroot).as_posix()if p.is_absolute()else p.as_posix())
 for i,(source,obj)in enumerate(zip(source_keys,objects)):
  row=rows[source];raw=files[row['snapshot']];assert sha(raw)==row['sha256']==b['sources_sha256'][source]
  if row['repository']:assert raw.replace(b'\r\n',b'\n')==subprocess.check_output(['git','show',producer.SOURCE+':'+row['path']],cwd=ROOT)
  else:assert raw==files[row['path']]
  assert sha(files[local(obj)])==b['objects_sha256'][obj]
  event=provider_events[i];assert event['returncode']==0 and event['command'][1:]==[*b['flags'],'-c',source,'-o',obj]
 for name,digest in b['drivers_sha256'].items():
  matches=[e for e in events if e['label']=='driver'and q(e['command'][-1]).stem==name];assert len(matches)==1
  e=matches[0];source=e['command'][e['command'].index('-c')+1];assert sha(files[rows[source]['snapshot']])==digest
  exe=name+('.exe'if r['platform']=='WINDOWS'else'-driver');assert sha(files['baseline/'+exe])==b['executables_sha256'][name]
  obj=e['command'][-1];args=b['flags']+(['-Wl,--stack,16777216']if r['platform']=='WINDOWS'else[])+[obj,*objects,'-o',str(q(obj).with_name(exe))]
  assert files['baseline/'+name+'.args'].decode().replace('\r\n','\n')=='\n'.join('"'+a.replace('\\','/')+'"'for a in args)+'\n'
  assert len([e for e in events if e['label']=='link'and e['command'][1:]==['@'+str(q(obj).with_name(name+'.args'))]and e['returncode']==0])==1
 for e in events:
  for stream in('stdout','stderr'):assert local(e[stream])in files
  assert e['returncode']!=0 if e['label']=='original-reactive'else e['returncode']==0
 assert len(r['native']['logical'])==24 and all(x['refused']is True for x in r['native']['logical'])
 import joint_production_runtime as reference
 _,frozen=reference.reference(r['platform'],r['optimization'])
 for name in ('age','mineral','reactive_n'):
  expected={k.removeprefix('candidate/'):v for k,v in frozen.items()if k.startswith('candidate/'+name+'/')}
  actual={k.removeprefix('baseline/'):v for k,v in files.items()if k.startswith('baseline/'+name+'/')}
  assert expected==actual,'independent exact native payload '+name
 for row in r['native']['logical']:
  good=files['baseline/'+row['codec']+'/'+row['proper']];payload=bytearray(good[:-4]);assert row['word']in(2,-1,2147483647)
  struct.pack_into('<i',payload,{'time_bound':144,'history':156}[row['field']],row['word'])
  assert files[local(row['path'])]==bytes(payload)+struct.pack('<I',zlib.crc32(payload))and row['returncode']==0
 return dict(cold_provider_compiles=335,reused_objects=0,complete_original_drivers=4,logical_refusals=24,production_admission=False,whole_scientific_admission=False)
def pack(out):
 files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};measurement=audit(files)
 buffer=io.BytesIO()
 with tarfile.open(fileobj=buffer,mode='w')as t:
  for name,raw in files.items():info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
 raw=lzma.compress(buffer.getvalue());stem=out.parent/(out.name+'-evidence');stem.with_suffix('.tar.xz').write_bytes(raw)
 stem.with_suffix('.json').write_text(json.dumps(dict(sha256=sha(raw),members={p:sha(b)for p,b in files.items()},measurement=measurement),indent=2)+'\n');print(json.dumps(measurement))
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();pack(a.output.resolve())
