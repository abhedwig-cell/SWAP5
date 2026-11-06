"""Independent deployed source, object, command, native and owner remeasurement."""
import argparse,ast,io,json,lzma,re,struct,tarfile,zlib
from pathlib import Path,PureWindowsPath,PurePosixPath
import joint_production as g
import joint_event_writer_runtime as runtime
import joint_event_writer as writer
import joint_writer_probe as publication_probe
STORE=runtime.STORE

def publication_audit(files,r,root):
 from itertools import product
 rows=r['publication']['cases'];crashes=r['publication']['terminations']
 layouts=[('age','history'),('age','plain'),('mineral','history'),('reactive_n','history')]
 assert [(x['codec'],x['layout'],x['stage'])for x in rows]==[(n,l,s)for n,l in layouts for s in(0,2,3,4,5,6)]
 assert [(x['codec'],x['layout'],x['phase'])for x in crashes]==[(n,l,s)for n,l in layouts for s in('before','after')]
 for name,layout in layouts:
  home='publication-'+name+'-'+layout
  good=files[name+('/restart.bin.base'if layout=='plain'else'/restart.bin')]
  old=publication_probe.previous_generation(good);assert old!=good
  assert files[home+'/old-native']==files[home+'/old-reexport']==files[home+'/old-reexport-again']==old
  exe=str(root/r['executables']['publication-'+name]['executable'])
  seed=str(root/name/('restart.bin.base'if layout=='plain'else'restart.bin'))
  for row in [x for x in rows if x['codec']==name and x['layout']==layout]:
   stage=row['stage'];case=home+'/'+str(stage);event=row['event'];target=str(root/case/'authority');recovery=str(root/case/'recovered')
   assert event['command']==[exe,'probe-writer',seed,target,recovery,layout]and event['returncode']==0
   success=stage==0 or(stage==6 and r['platform']=='WINDOWS');published=stage in(0,6)
   output=files[case+'/'+event['stdout']]
   assert(b'WRITE_STATUS=0'in output)==success and(b'WRITE_STATUS=1'in output)==(not success)
   assert files[case+'/authority']==(good if published else old)and files[case+'/recovered']==good
   retained=stage in(2,3,4,5);assert(case+'/authority.pending'in files)==retained
   if retained:
    assert files[case+'/authority.pending']==good and files[case+'/retry-recovered']==good
    retry=event['retry'];assert retry['returncode']==0 and b'WRITE_STATUS=1'in files[case+'/'+retry['stdout']]
    assert retry['command']==[exe,'probe-writer',seed,target,str(root/case/'retry-recovered'),layout]
  for row in [x for x in crashes if x['codec']==name and x['layout']==layout]:
   phase=row['phase'];case=home+'/'+phase;event=row['event'];target=str(root/case/'authority')
   assert event['command']==[exe,'probe-writer',seed,target,str(root/case/'never'),layout]
   assert event['actual_process_terminated']is True and event['termination_returncode']!=0
   assert event['stop_observed']==('Windows named event'if r['platform']=='WINDOWS'else'SIGSTOP')
   assert event['termination_method']==('TerminateProcess'if r['platform']=='WINDOWS'else'SIGKILL')
   assert files[case+'/authority']==(old if phase=='before'else good)
   assert(case+'/authority.pending'in files)==(phase=='before')
   if phase=='before':assert files[case+'/authority.pending']==good
   assert files[case+'/fresh']==files[case+'/fresh-again']==files[case+'/authority']
   fresh=row['fresh'];assert fresh['returncode']==0 and fresh['command']==[exe,'probe-writer',target,str(root/case/'fresh'),str(root/case/'fresh-again'),layout]

def origin(r):
 ref=r['head'];assert re.fullmatch('[0-9a-f]{40}',ref)
 import subprocess
 if subprocess.run(['git','cat-file','-e',ref+'^{commit}'],cwd=g.ROOT,capture_output=True).returncode:subprocess.run(['git','fetch','--no-tags','origin',ref],cwd=g.ROOT,check=True,capture_output=True)
 assert subprocess.run(['git','merge-base','--is-ancestor',g.BASE,ref],cwd=g.ROOT,capture_output=True).returncode==0
 assert r['production_trees']=={a:g.blob(ref,a)for a in ('src','app','reference')}==writer.guard()
 runner='tests/dataqual15_hupsel/joint_event_writer_runtime.py'
 assert r['runner_sha256']==g.sha(g.raw(ref,runner))==g.sha(g.normal((g.ROOT/runner).read_bytes()))
 for name in ('joint_writer','joint_writer_probe','joint_event_writer_runtime'):
  path='tests/dataqual15_hupsel/'+name+'.py'
  assert g.raw(ref,path)==g.raw('HEAD',path)==g.normal((g.ROOT/path).read_bytes())
 # The helper also contains the independent archive consumer. Consumer-only
 # path handling/cache changes cannot change already executed cold recipes.
 # Bind every producer function and top-level runtime assignment literally;
 # retain full-byte binding for the actual runner and original probe modules.
 path='tests/dataqual15_hupsel/joint_event_writer.py'
 def producer(raw):
  text=g.normal(raw).decode();tree=ast.parse(text);result=[]
  for node in tree.body:
   if isinstance(node,ast.FunctionDef)and node.name in('guard','source_record','cold'):result.append(ast.get_source_segment(text,node))
   elif isinstance(node,ast.Assign):result.append(ast.get_source_segment(text,node))
   elif isinstance(node,(ast.Import,ast.ImportFrom)):
    assert all(a.name in('json','subprocess','functools','Path','PureWindowsPath','PurePosixPath','joint_production','joint_production_runtime','joint_writer','joint_logical')for a in node.names)
    aliases=[(a.name,a.asname)for a in node.names if a.name not in('functools','PureWindowsPath','PurePosixPath')]
    if aliases:result.append((getattr(node,'module',None),aliases))
  assert sum(isinstance(n,ast.FunctionDef)and n.name in('guard','source_record','cold')for n in tree.body)==3
  return result
 assert producer(g.raw(ref,path))==producer(g.raw('HEAD',path))==producer((g.ROOT/path).read_bytes())
 for name in g.NAMES:
  path='tests/dataqual15_hupsel/joint_writer_candidates/'+Path(g.SOURCES[name]).name
  assert g.raw(ref,path)==g.raw('HEAD',path)==writer.candidate(name)
def audit(files):
 r=json.loads(files['RESULT.json']);assert r['status']=='PRIVATE_THREE_WRITER_PUBLICATION_PASS'and r['baseline']==writer.BASE
 assert r['production_admission']is False and r['whole_scientific_admission']is False;origin(r)
 platform=r['platform'];assert platform in ('WINDOWS','POSIX')and r['optimization']in ('O0','O2');q=PureWindowsPath if platform=='WINDOWS'else PurePosixPath;root=q(r['root']);repo=q(r['repo_root']);old={k.removeprefix('providers/'):v for k,v in files.items()if k.startswith('providers/')};writer.audit_cold(old,platform,r['optimization']);b=json.loads(old['baseline/BUILD.json']);meta=json.loads(old['PROVENANCE.json']);before=json.loads(old['baseline/EVENTS.json']);oldroot=meta['root']
 assert r['compiler']==b['compiler'];expected_flags=[f for f in b['flags']if not f.startswith(('-I','-J'))]+['-I'+str(root/'build'),'-I'+str(root/'providers'/'baseline'),'-I'+str(root/'providers'/'fixture'),'-I'+str(repo/'tests/nut-reactive'),'-J'+str(root/'build')];assert r['flags']==expected_flags
 sources=runtime.driver_sources(old);events=json.loads(files['EVENTS.json']);bindings=r['bindings'];assert len(bindings)==335
 expected_objects=[];new_objects=[]
 for i,(source_key,object_key)in enumerate(zip(b['sources_sha256'],b['objects_sha256'])):
  relative=meta['sources'][source_key]['path'];replacement=next((n for n,p in g.SOURCES.items()if p==relative),None);oldobj=runtime.local(object_key,oldroot);obj=root/'build'/('%03d.o'%i)if replacement else root/'providers'/oldobj;row=bindings[i]
  assert row['source_key']==source_key and row['input_object']==oldobj and row['object']==str(obj)and row['replacement']==replacement
  if replacement:
   path=r['source_snapshots'][replacement]['path'];raw=files[path];assert g.normal(raw)==writer.candidate(replacement)and g.sha(raw)==r['source_snapshots'][replacement]['sha256']
   assert g.sha(files[runtime.local(str(obj),str(root))])==row['sha256'];new_objects.append(runtime.local(str(obj),str(root)))
   command=[e for e in events if e['label']=='provider'and e['command'][-1]==str(obj)];assert len(command)==1
   assert command[0]['command'][1:]==[*expected_flags,'-c',str(repo/'tests/dataqual15_hupsel/joint_writer_candidates'/Path(g.SOURCES[replacement]).name),'-o',str(obj)]
   mod='mod_'+replacement+'_joint_restart_file.mod';assert files['build/'+mod]==old['candidate/'+mod]
  else:assert row['sha256']==b['objects_sha256'][object_key]==g.sha(old[oldobj])
  expected_objects.append(str(obj))
 assert len(new_objects)==3 and len([e for e in events if e['label']=='provider'])==3
 expected_objects += [str(root/'build'/'publisher.o'),str(root/'build'/'shim.o')]
 assert g.normal(files['publisher.c'])==g.raw(writer.BASE,'app/support/restart_publish.c')
 assert g.normal(files['shim.c'])==publication_probe.publication.shim_source('nt'if platform=='WINDOWS'else'posix').encode()
 assert len([e for e in events if e['label']=='publisher'])==len([e for e in events if e['label']=='shim'])==1
 publisher=next(e for e in events if e['label']=='publisher');shim=next(e for e in events if e['label']=='shim')
 assert publisher['command'][1:]==['-'+r['optimization'],'-std=c11','-DSWAP5_RESTART_TESTING','-Dswap5_restart_publish=swap5_restart_publish_real','-c',str(root/'publisher.c'),'-o',str(root/'build'/'publisher.o')]
 assert shim['command'][1:]==['-'+r['optimization'],'-std=c11','-c',str(root/'shim.c'),'-o',str(root/'build'/'shim.o')]
 assert files['build/publisher.o']and files['build/shim.o']
 assert set(r['executables'])=={'native-'+n for n in (*g.NAMES,'reactive_original')}|{'owner-'+n for n in g.NAMES}|{'publication-'+n for n in g.NAMES}
 for key,item in r['executables'].items():
  label,name=key.split('-',1);expected=sources[name]if label=='native'else runtime.occupied_driver(sources[name],name)if label=='owner'else publication_probe.driver(sources[name],name);assert files[item['source']]==expected
  drivers=[e for e in events if e['label']==label+'-driver'and e['command'][e['command'].index('-c')+1]==str(root/item['source'])];assert len(drivers)==1
  assert drivers[0]['command'][1:]==[*expected_flags,'-c',str(root/item['source']),'-o',str(root/item['object'])]
  assert files[item['object']]
  exe=files[item['executable']];assert exe[:2]==b'MZ'if platform=='WINDOWS'else exe[:4]==b'\x7fELF'
  args=re.findall(r'^"(.*)"$',files[item['response']].decode().replace('\r\n','\n'),re.M);expected=expected_flags+(['-Wl,--stack,16777216']if platform=='WINDOWS'else[])+[str(root/item['object']),*expected_objects,'-o',str(root/item['executable'])]
  assert args==[s.replace('\\','/')for s in expected]
  links=[e for e in events if e['label']==label+'-link'and e['command'][1]=='@'+str(root/item['response'])];assert len(links)==1
 assert len([e for e in events if e['label'].endswith('-driver')])==10 and len([e for e in events if e['label'].endswith('-link')])==10
 def translated(arg):
  for name in (*g.NAMES,'reactive_original'):
   oldexe=str(q(oldroot)/'baseline'/(name+('.exe'if platform=='WINDOWS'else'-driver')))
   if arg==oldexe:return str(root/r['executables']['native-'+name]['executable'])
  prefix=str(q(oldroot)/'baseline')
  if arg.replace('\\','/').startswith(prefix.replace('\\','/')+'/'):return str(root/runtime.local(arg,prefix))
  return arg
 prior=[e for e in before if e['label']not in ('provider','driver','link')];actual=[e for e in events[:r['native_events']]if e['label']not in ('provider','native-driver','native-link','publisher','shim')];assert len(prior)==len(actual)
 for a,c in zip(prior,actual):
  assert c['label']==a['label']and c['command']==[translated(x)for x in a['command']]and c['returncode']==a['returncode']
  if c['label']=='original-reactive':assert c['returncode']!=0 and b'organic-process rejection rolls water back'in files[c['stdout']]
  else:assert c['returncode']==0 and g.normal(files[c['stdout']])==g.normal(old['baseline/'+a['stdout']])
 for name in g.NAMES:
  retained={k.removeprefix('baseline/'):v for k,v in old.items()if k.startswith('baseline/'+name+'/')}
  deployed={k:v for k,v in files.items()if k.startswith(name+'/')};assert retained==deployed,'complete original native files: '+name
 proper=r['native']['proper'];logical=r['native']['logical'];assert len(proper)==4 and len(logical)==24
 for row in proper:
  raw=files[runtime.local(row['path'],str(root))];assert g.sha(raw)==row['sha256']and zlib.crc32(raw[:-4])==struct.unpack('<I',raw[-4:])[0]
 for row in logical:
  raw=files[row['codec']+'/'+row['proper']];payload=bytearray(raw[:-4]);assert row['word']in(2,-1,2147483647);struct.pack_into('<i',payload,{'time_bound':144,'history':156}[row['field']],row['word']);bad=bytes(payload)+struct.pack('<I',zlib.crc32(payload));assert files[runtime.local(row['path'],str(root))]==bad and row['refused']is True and row['returncode']==0
 expected=[]
 native_files={'production/'+n+'/'+k.split('/')[-1]:v for n in g.NAMES for k,v in files.items()if k.startswith(n+'/')}
 for name,seed,probes in runtime.occupied_inputs(native_files,'production'):
  for probe,raw in probes.items():
   for occupancy in ('both','water','chemical'):
    key=f'occupied-{name}-{Path(seed).name}-{probe}-{occupancy}';expected.append((name,seed,probe,occupancy,key));row=r['occupied'][len(expected)-1]
    assert tuple(row[k]for k in ('codec','seed','probe','occupancy','key'))==expected[-1]
    assert files.get(key+'.input')==raw and files[key+'.before']==files[key+'.after']==native_files[seed]
    event=events[row['event']];exe=r['executables']['owner-'+name]['executable'];assert event['command']==[str(root/exe),'occupied',str(root/seed.removeprefix('production/')),str(root/(key+'.input')),str(root/(key+'.before')),str(root/(key+'.after')),occupancy,'plain'if seed.endswith('.base')else'history']
    assert event['label']=='occupied'and event['returncode']==0 and b'OCCUPIED_ATOMIC_REFUSAL=PASS'in files[event['stdout']]
 assert len(r['occupied'])==len(expected)==120 and len([e for e in events if e['label']=='occupied'])==120
 assert all(e['stdout']in files and e['stderr']in files for e in events)
 assert all(e['returncode']==0 for e in events if e['label']!='original-reactive')
 publication_audit(files,r,root)
 return dict(private_modules=3,publication_cases=24,actual_process_terminations=8,cold_provider_compiles=335,unchanged_provider_objects_from_current_cold_graph=332,complete_drivers=10,logical_refusals=24,occupied_refusals=120,original_native_events=len(prior),whole_scientific_admission=False)
def pack(out,stem):
 files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()};measured=audit(files);buffer=io.BytesIO();seen={}
 with tarfile.open(fileobj=buffer,mode='w:xz')as t:
  for name,raw in files.items():
   info=tarfile.TarInfo(name);digest=g.sha(raw)
   if digest in seen:info.type=tarfile.LNKTYPE;info.linkname=seen[digest];t.addfile(info)
   else:info.size=len(raw);t.addfile(info,io.BytesIO(raw));seen[digest]=name
 raw=buffer.getvalue();name=stem+'.tar.xz';(STORE/name).write_bytes(raw);(STORE/(stem+'.json')).write_text(json.dumps(dict(measurement=measured,archive=name,sha256=g.sha(raw),members={n:g.sha(b)for n,b in files.items()}),indent=2)+'\n');print(json.dumps(verify(stem,True),sort_keys=True))
def verify(stem,controls=False):
 m=json.loads((STORE/(stem+'.json')).read_text());raw=(STORE/m['archive']).read_bytes();assert g.sha(raw)==m['sha256']
 with tarfile.open(fileobj=io.BytesIO(lzma.decompress(raw)),mode='r:')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {n:g.sha(b)for n,b in files.items()}==m['members'];assert audit(files)==m['measurement']
 if controls:
  r=json.loads(files['RESULT.json']);obj=next(x for x in r['bindings']if x['replacement']=='age');paths=[r['source_snapshots']['age']['path'],runtime.local(obj['object'],r['root']),r['executables']['native-age']['source'],r['executables']['owner-age']['source'],'age/restart.bin.history.2.bin',r['occupied'][0]['key']+'.after','EVENTS.json',r['executables']['native-age']['executable'],'publisher.c','shim.c','publication-age-history/2/authority.pending','publication-age-history/before/fresh'];assert len(set(paths))==12
  cold=json.loads(files['providers/PROVENANCE.json']);build=json.loads(files['providers/baseline/BUILD.json'])
  changed=next((source,row)for source,row in cold['sources'].items()if row['path']=='src/runtime/mod_interception_source_window_runtime.f90')
  index=list(build['sources_sha256']).index(changed[0]);cold_object=list(build['objects_sha256'])[index]
  paths+=['providers/'+changed[1]['snapshot'],'providers/'+runtime.local(cold_object,cold['root'])]
  assert len(set(paths))==14
  for name in paths:
   old=files[name];files[name]=b''
   try:audit(files)
   except(AssertionError,KeyError,ValueError,struct.error):pass
   else:raise AssertionError('deployed evidence corruption accepted: '+name)
   finally:files[name]=old
 return m['measurement']
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--stem',required=True);p.add_argument('--self-test',action='store_true');a=p.parse_args();print(json.dumps(verify(a.stem,a.self_test),sort_keys=True))
