"""Independent current336-provider source/object/native archive remeasurement."""
import argparse,ast,base64,hashlib,io,json,lzma,re,struct,subprocess,tarfile,zlib
from pathlib import Path
import joint_current as p
STORE=p.ROOT/'integration/dataqual15_hupsel'
sha=p.sha
BLOBS={}
def original(name):
 if name not in BLOBS:BLOBS[name]=subprocess.check_output(['git','show',p.BASE+':'+name],cwd=p.ROOT)
 return BLOBS[name]
def local(path,root):
 path=path.replace('\\','/');root=root.replace('\\','/').rstrip('/')+'/'
 assert path.startswith(root),path
 return path[len(root):]

def snapshot(folder):
 meta=dict(root=str(folder),sources={});dest=folder/'source-snapshots';dest.mkdir(exist_ok=True)
 paths=set()
 for role in ('baseline','candidate'):
  build=json.loads((folder/role/'BUILD.json').read_text());paths.update(build['sources_sha256'])
  for e in json.loads((folder/role/'EVENTS.json').read_text()):
   if e['label']=='driver':paths.add(e['command'][e['command'].index('-c')+1])
 for name in sorted(paths):
  path=Path(name);raw=path.read_bytes();key='source-snapshots/'+str(len(meta['sources']))+'.f90';(folder/key).write_bytes(raw)
  if path.is_relative_to(p.ROOT):kind='repository';relative=path.relative_to(p.ROOT).as_posix()
  elif path.parent.name=='candidate' and path.name in [Path(n).name for n in p.SOURCES.values()]:kind='candidate';relative=next(n for n,v in p.SOURCES.items() if Path(v).name==path.name)
  else:kind='fixture';relative='fixture/'+path.name;assert (folder/relative).read_bytes()==raw
  meta['sources'][name]=dict(snapshot=key,sha256=sha(raw),kind=kind,path=relative)
 (folder/'PROVENANCE.json').write_text(json.dumps(meta,indent=2)+'\n')

def audit(files):
 r=json.loads(files['RESULT.json']);meta=json.loads(files['PROVENANCE.json']);root=meta['root']
 assert r['status']=='COMPLETE_PRIVATE_JOINT_CURRENT_READER_CLUSTER_PASS' and r['baseline']==p.BASE
 assert r['production_admission'] is False and r['whole_scientific_admission'] is False
 for name,digest in json.loads(files['INPUTS.json']).items():assert sha(p.normal(original(name)))==digest
 for name,row in meta['sources'].items():
  raw=files[row['snapshot']];assert sha(raw)==row['sha256']
  if name.replace('\\','/').startswith(root.replace('\\','/').rstrip('/')+'/'):assert raw==files[local(name,root)]
  if row['kind']=='repository':assert p.normal(raw)==original(row['path'])
  elif row['kind']=='candidate':assert raw==p.candidate(row['path'])
  else:assert raw==files[row['path']]
 assert files['fixture/age_literal.f90']==p.age_literal().encode()
 grid=original('tests/modularity/low_air_consistent_grid_stubs.f90').decode()
 grid=grid.replace('[-0.25d0, -0.75d0, -1.50d0, -2.50d0]','[-2.5d0, -7.5d0, -15d0, -25d0]').replace('[0.50d0, 0.50d0, 1.00d0, 1.00d0]','[5d0, 5d0, 10d0, 10d0]').replace('[0.25d0, 0.50d0, 0.75d0, 1.0d0, 0.50d0]','[2.5d0, 5d0, 7.5d0, 10d0, 5d0]')
 assert p.normal(files['fixture/grid.f90']).decode()==grid[:grid.index('subroutine swap_error(origin, message)')]
 fixture=original('tests/physics/test_ppa_wu05d2_mixed_application.f90').decode();start=fixture.index('  subroutine initialize_application_config');end=fixture.index('  end subroutine initialize_state_and_forcing')+len('  end subroutine initialize_state_and_forcing')
 assert p.normal(files['fixture/matrix_fixture.inc']).decode()==fixture[start:end]+'\n'
 tree=ast.parse(original('tests/nut-reactive/run_reactive.py').decode());pins=next(ast.literal_eval(n.value) for n in tree.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='pins' for t in n.targets))
 with tarfile.open(fileobj=io.BytesIO(base64.b64decode(original('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'))),mode='r:gz') as archive:
  for name,digest in pins.items():
   raw=archive.extractfile('SWAP/'+name).read();assert sha(raw)==digest
   if name=='wofost_soil_orgmatn.f90':
    before=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Bio(fn) * NFracBio';after=b'NFracFOM(fn) - AsfaFOM_Bio(fn) * NFracBio - AsfaFOM_Hum(fn) * NFracHum';assert raw.count(before)==1;raw=raw.replace(before,after)
   assert files['fixture/'+name]==raw
 assert p.normal(files['fixture/reactive_driver.f90']).decode()==p.prior.projected_driver()
 source=original('tests/nut-sol/test_age_joint.f90')
 projected=p.normal(files['fixture/age_driver.f90'])
 anchor=b"  if(trim(mode)=='reject')then";start=projected.index(b"  if(trim(mode)=='plain-read'");end=projected.index(anchor,start)
 assert projected[:start]+projected[end:]==source
 assert b'proper own base-family reconstruction' in projected and b'invalid base-family atomic refusal' in projected
 summary=dict(provider_objects=0,new_candidate_modules=0,proper_files=0,candidate_refusals=0,baseline_failed_refusals=0,whole_scientific_admission=False,production_admission=False)
 for role in ('baseline','candidate'):
  b=json.loads(files[role+'/BUILD.json']);events=json.loads(files[role+'/EVENTS.json']);result=r['roles'][role]
  assert b['role']==role and b['provider_count']==336
  assert all(f in b['flags'] for f in ('-'+r['optimization'],'-std=f2008','-fcheck=all','-fopenmp','-ffpe-trap=invalid,zero,overflow'))
  for name,digest in b['sources_sha256'].items():assert meta['sources'][name]['sha256']==digest
  for name,digest in b['objects_sha256'].items():assert sha(files[local(name,root)])==digest;summary['provider_objects']+=1
  compiled=[e for e in events if e['label']=='provider']
  reused=files.get(role+'/REUSED_PROVIDERS.json')
  if reused:
   old=json.loads(reused);assert role=='baseline' and not compiled and len(old['events'])==b['provider_count']
   assert old['build']['compiler']==b['compiler']
   assert [f for f in old['build']['flags'] if not f.startswith(('-I','-J'))]==[f for f in b['flags'] if not f.startswith(('-I','-J'))]
   for oldpath,digest in old['build']['objects_sha256'].items():assert sha(files[role+'/'+Path(oldpath.replace('\\','/')).name])==digest
   for e in old['events']:
    assert e['returncode']==0
    for stream in ('stdout','stderr'):assert role+'/reused-'+e[stream] in files
    command=e['command'];name=command[command.index('-c')+1];assert name in b['sources_sha256'] and meta['sources'][name]['sha256']==old['build']['sources_sha256'][name]
  else:assert len(compiled)==(3 if role=='candidate' else b['provider_count'])
  if role=='candidate':summary['new_candidate_modules']+=len(compiled)
  for e in events:
   assert role+'/'+e['stdout'] in files and role+'/'+e['stderr'] in files
   if e['label'] in ('provider','driver','link'):assert e['returncode']==0
   if e['label'] in ('provider','driver'):
    command=e['command'];source=command[command.index('-c')+1]
    assert source in meta['sources'] and '-'+r['optimization'] in command
    assert all(flag in command for flag in ('-fcheck=all','-fopenmp','-ffpe-trap=invalid,zero,overflow'))
    if e['label']=='driver':
     name=Path(command[command.index('-o')+1].replace('\\','/')).stem
     assert meta['sources'][source]['sha256']==b['drivers_sha256'][name]
  for name,digest in b['executables_sha256'].items():
   exe=next(k for k in files if k in (role+'/'+name+'.exe',role+'/'+name+'-driver'));assert sha(files[exe])==digest
   rsp=files[role+'/'+name+'.args'].decode();args=re.findall(r'^"(.*)"$',rsp.replace('\r\n','\n'),re.M)
   objects=[arg for arg in args if arg.endswith('.o')];assert len(objects)==b['provider_count']+1
   assert objects[1:]==[s.replace('\\','/') for s in b['objects_sha256']]
   assert sha(files[local(objects[0],root)])
   assert files[exe][:2]==b'MZ' if exe.endswith('.exe') else files[exe][:4]==b'\x7fELF'
  original_run=next(e for e in events if e['label']=='original-reactive')
  assert original_run['returncode']!=0 and b'organic-process rejection rolls water back' in files[role+'/'+original_run['stdout']]
  for name in ('mineral','reactive_n'):
   stem=role+'/'+name+'/';blob=files[stem+'restart.bin'];assert files[stem+'end.bin']==files[stem+'fresh.bin']==files[stem+'end.bin.opaque']
   row=result['unchanged_native_n'][name];assert row['independent_crc_pass'] is True and row['correctly_resealed_valid_returncode']==0
   assert len(row['refusals'])==11 and all(x['refused'] is True for x in row['refusals'])
   for rec in row['refusals']:
    e=next(e for e in events if e['label']==name+'-'+rec['case']);assert e['returncode']==0 and b'INVALID_DISK=PASS' in files[role+'/'+e['stdout']]
  assert files[role+'/age/end.bin']==files[role+'/age/fresh.bin']
  assert files[role+'/age/restart.bin.base']==files[role+'/age/proper-base-reexport.bin']
  positives={}
  for row in result['proper']:
   name=local(row['path'],root);blob=files[name];assert sha(blob)==row['sha256']
   assert zlib.crc32(blob[:-4])==struct.unpack('<I',blob[-4:])[0]
   assert row['mode']==struct.unpack_from('<i',blob,148)[0] and row['history']==struct.unpack_from('<i',blob,156)[0]
   positives[Path(name).name if '/age/' in name else name.split('/')[-2]+'/'+Path(name).name]=blob;summary['proper_files']+=1
  assert len(positives)==4 and len(result['logical'])==24
  for row in result['logical']:
   parent=files[role+'/'+row['codec']+'/'+row['proper']];payload=bytearray(parent[:-4]);offset={'time_bound':144,'history':156}[row['field']]
   assert row['word'] in (2,-1,2147483647);struct.pack_into('<i',payload,offset,row['word'])
   bad=bytes(payload)+struct.pack('<I',zlib.crc32(payload));path=local(row['path'],root);assert files[path]==bad
   event=next(e for e in events if len(e['command'])>2 and e['command'][2]==row['path'] and e['label'].startswith('logical-'))
   refused=event['returncode']==0 and b'INVALID_DISK=PASS' in files[role+'/'+event['stdout']]
   assert row['returncode']==event['returncode'] and row['refused']==refused
   assert event['command'][1]==('plain-reject' if row['proper'].endswith('.base')else'reject')
   if role=='candidate':assert refused;summary['candidate_refusals']+=1
   elif not refused:summary['baseline_failed_refusals']+=1
 for name in p.NAMES:
  for leaf in ('restart.bin','end.bin','fresh.bin'):
   assert files['baseline/'+name+'/'+leaf]==files['candidate/'+name+'/'+leaf]
 assert summary['proper_files']==8 and summary['candidate_refusals']==24 and summary['new_candidate_modules']==3
 return summary

def pack(folder,stem):
 snapshot(folder);files={x.relative_to(folder).as_posix():x.read_bytes()for x in sorted(folder.rglob('*'))if x.is_file()};measured=audit(files)
 m=dict(status='COMPLETE_PRIVATE_JOINT_CURRENT_READER_QUALIFIED',measurement=measured,members={n:sha(b)for n,b in files.items()},parts=[]);buf=io.BytesIO();seen={}
 with tarfile.open(fileobj=buf,mode='w:xz')as t:
  for name,blob in files.items():
   info=tarfile.TarInfo(name);digest=sha(blob)
   if digest in seen:info.type=tarfile.LNKTYPE;info.linkname=seen[digest];t.addfile(info)
   else:info.size=len(blob);t.addfile(info,io.BytesIO(blob));seen[digest]=name
 raw=buf.getvalue()
 for offset in range(0,len(raw),40*1024*1024):
  b=raw[offset:offset+40*1024*1024];name=stem+f'.tar.xz.part{len(m["parts"]):02d}';(STORE/name).write_bytes(b);m['parts'].append(dict(path=name,sha256=sha(b),size=len(b)))
 (STORE/(stem+'.json')).write_text(json.dumps(m,indent=2)+'\n')

def verify(stem,controls=False):
 m=json.loads((STORE/(stem+'.json')).read_text());chunks=[]
 for item in m['parts']:
  raw=(STORE/item['path']).read_bytes();assert sha(raw)==item['sha256'] and len(raw)==item['size'];chunks.append(raw)
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(b''.join(chunks))),mode='r:')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {n:sha(b)for n,b in files.items()}==m['members'];assert audit(files)==m['measurement']
 if controls:
  paths=['candidate/mod_age_joint_restart_file.f90','baseline/000.o','candidate/age/restart.bin.history.2.bin','candidate/mineral/restart.bin','fixture/age_driver.f90']
  for name in paths:
   old=files[name];files[name]=b''
   try:audit(files)
   except (AssertionError,KeyError,ValueError,struct.error):pass
   else:raise AssertionError('joint reader evidence mutation accepted: '+name)
   finally:files[name]=old
 return m['measurement']

def cross(platform):
 a,b=[json.loads((STORE/('JOINT_CURRENT_'+platform+'_'+opt+'_20261106.json')).read_text())['members'] for opt in ('O0','O2')]
 paths=[role+'/'+name+'/'+leaf for role in ('baseline','candidate') for name in p.NAMES for leaf in ('restart.bin','end.bin','fresh.bin')]
 paths += [role+'/age/'+leaf for role in ('baseline','candidate') for leaf in ('restart.bin.base','proper-base-reexport.bin')]
 assert all(a[path]==b[path] for path in paths)
 return dict(same_platform=platform,exact_cross_optimization_files=len(paths),production_admission=False)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--stem');parser.add_argument('--pack',type=Path);parser.add_argument('--self-test',action='store_true');parser.add_argument('--cross',choices=('WINDOWS','POSIX'));a=parser.parse_args()
 if a.cross:print(json.dumps(cross(a.cross),sort_keys=True));raise SystemExit
 assert a.stem
 if a.pack:pack(a.pack.resolve(),a.stem)
 print(json.dumps(verify(a.stem,a.self_test),sort_keys=True))
