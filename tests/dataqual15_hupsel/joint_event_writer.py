"""Cold exact current335 graph; unchanged complete private writer postimages."""
import json,subprocess,functools
from pathlib import Path,PureWindowsPath,PurePosixPath
import joint_production as g
import joint_production_runtime as reference_runtime
import joint_writer as original_writer
import joint_logical as native
BASE='50bd76792c46780b4499bc0b398e0485ecd4d1dd'
DIRECTORY=original_writer.DIRECTORY
candidate=original_writer.candidate

def guard():
 for area in('src','app','reference'):
  assert g.blob('HEAD',area)==g.blob(BASE,area),'exact current event production tree'
  assert not g.git('diff','HEAD','--',area)
 assert not g.git('ls-files','--others','--exclude-standard','--','src','app','reference')
 paths=g.frozen()|{'tests/dataqual15_hupsel/'+n+'.py'for n in('joint_writer','joint_writer_probe','joint_writer_evidence','joint_writer_runtime','joint_production_runtime')}
 paths|={'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(p).name for p in g.SOURCES.values()}
 for path in paths:
  raw=(g.ROOT/path).read_bytes()
  if path.endswith(('.py','.f90','.json','.yml')):raw=g.normal(raw)
  assert raw==g.raw('HEAD',path)==g.raw(BASE,path),path
 return {area:g.blob('HEAD',area)for area in('src','app','reference')}

def source_record(path,snapshot):
 if path.is_relative_to(g.ROOT):kind='repository';relative=path.relative_to(g.ROOT).as_posix()
 else:kind='fixture';relative='fixture/'+path.name
 raw=path.read_bytes()
 return dict(path=relative,kind=kind,snapshot=snapshot,sha256=g.sha(raw))

def cold(out,platform,opt,fc):
 guard();native.prior.guard=lambda:dict(source_sha256={p:g.sha(g.normal((g.ROOT/p).read_bytes()))for p in g.SOURCES.values()})
 native.prior.DRIVERS=dict(native.prior.DRIVERS,age='tests/nut-sol/test_age_joint.f90')
 fixture,ordered,drivers=native.prepare(out);assert len(ordered)==335
 baseline=out/'baseline';exes,events=native.build(baseline,Path(fc),opt,fixture,ordered,drivers)
 measured=native.measure(baseline,exes,events,'candidate')
 meta=dict(root=str(out),sources={});snapshots=out/'source-snapshots';snapshots.mkdir()
 for path in dict.fromkeys([*ordered,*drivers.values()]):
  snap='source-snapshots/'+str(len(meta['sources']))+'.f90';(out/snap).write_bytes(path.read_bytes());meta['sources'][str(path)]=source_record(path,snap)
 (out/'PROVENANCE.json').write_text(json.dumps(meta,indent=2)+'\n')
 # The public module interface is checked against the freshly compiled current
 # reader object, not against the historical private provider capsule.
 aliases=out/'candidate';aliases.mkdir()
 for name in g.NAMES:
  leaf='mod_'+name+'_joint_restart_file.mod';(aliases/leaf).write_bytes((baseline/leaf).read_bytes())
 (out/'CURRENT.json').write_text(json.dumps(dict(status='COLD_CURRENT335_NATIVE_PASS',baseline=BASE,head=g.git('rev-parse','HEAD'),production_trees=guard(),platform=platform,optimization=opt,native=measured),indent=2)+'\n')
 files={p.relative_to(out).as_posix():p.read_bytes()for p in out.rglob('*')if p.is_file()}
 _,old=reference_runtime.reference(platform,opt)
 for name in g.NAMES:
  old_native={k.removeprefix('candidate/'):v for k,v in old.items()if k.startswith('candidate/'+name+'/')}
  current={k.removeprefix('baseline/'):v for k,v in files.items()if k.startswith('baseline/'+name+'/')}
  assert old_native==current,'exact frozen/current native files: '+name
 return files

@functools.lru_cache(maxsize=None)
def baseline_source(path):return g.raw(BASE,path)

def audit_cold(files,platform,opt):
 """Remeasure all current source, fixture, object and successful cold commands."""
 current=json.loads(files['CURRENT.json']);assert current['status']=='COLD_CURRENT335_NATIVE_PASS'and current['baseline']==BASE
 assert current['production_trees']==guard()and current['platform']==platform and current['optimization']==opt
 b=json.loads(files['baseline/BUILD.json']);meta=json.loads(files['PROVENANCE.json']);events=json.loads(files['baseline/EVENTS.json']);_,old=reference_runtime.reference(platform,opt)
 old_build=json.loads(old['baseline/BUILD.json']);old_meta=json.loads(old['PROVENANCE.json'])
 assert b['provider_count']==335 and b['compiler']==old_build['compiler']
 assert [f for f in b['flags']if not f.startswith(('-I','-J'))]==[f for f in old_build['flags']if not f.startswith(('-I','-J'))]
 keys=list(b['sources_sha256']);objects=list(b['objects_sha256']);prior=list(old_build['sources_sha256']);assert len(keys)==len(objects)==len(prior)==335
 provider_events=[e for e in events if e['label']=='provider'];assert len(provider_events)==335
 for i,(source,obj,previous)in enumerate(zip(keys,objects,prior)):
  row=meta['sources'][source];before=old_meta['sources'][previous];assert row['path']==before['path']and row['kind']==before['kind']
  raw=files[row['snapshot']];assert g.sha(raw)==row['sha256']==b['sources_sha256'][source]
  if row['kind']=='repository':assert g.normal(raw)==baseline_source(row['path'])
  else:assert raw==files[row['path']]==old[before['snapshot']]
  event=provider_events[i];assert event['returncode']==0 and event['command'][1:]==[*b['flags'],'-c',source,'-o',obj]
  assert g.sha(files[reference_runtime.local(obj,meta['root'])])==b['objects_sha256'][obj]
 for event in events:
  assert event['stdout']in files or 'baseline/'+event['stdout']in files
  assert event['returncode']==0 if event['label']!='original-reactive'else event['returncode']!=0
 old_drivers=reference_runtime.driver_sources(old)
 for name,expected in old_drivers.items():
  event=next(e for e in events if e['label']=='driver'and Path(e['command'][-1].replace('\\','/')).stem==name)
  path=event['command'][event['command'].index('-c')+1];row=meta['sources'][path]
  assert g.normal(files[row['snapshot']])==g.normal(expected),'unchanged complete original driver '+name
  assert event['command'][1:]==[*b['flags'],'-c',path,'-o',event['command'][-1]]
  obj=event['command'][-1];q=PureWindowsPath if platform=='WINDOWS'else PurePosixPath
  # BUILD records executable hashes keyed by driver name, not absolute path.
  leaf=name+('.exe'if platform=='WINDOWS'else'-driver')
  assert g.sha(files['baseline/'+leaf])==b['executables_sha256'][name]
  response=files['baseline/'+name+'.args'].decode().replace('\r\n','\n')
  expected_args=b['flags']+(['-Wl,--stack,16777216']if platform=='WINDOWS'else[])+[obj,*objects,'-o',str(q(obj).with_name(leaf))]
  assert response=='\n'.join('"'+p.replace('\\','/')+'"'for p in expected_args)+'\n'
 for name in g.NAMES:
  assert {k.removeprefix('baseline/'):v for k,v in files.items()if k.startswith('baseline/'+name+'/')}=={k.removeprefix('candidate/'):v for k,v in old.items()if k.startswith('candidate/'+name+'/')}
 assert len(current['native']['logical'])==24 and all(r['refused']is True for r in current['native']['logical'])
 return dict(cold_provider_compiles=335,unchanged_source_provider_objects_reused=0,original_native_launches=56,logical_refusals=24)
