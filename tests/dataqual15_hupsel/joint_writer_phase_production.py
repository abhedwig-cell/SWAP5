"""Exact executed deployed writer successor, current codecs and frozen history."""
import argparse,functools,io,json,lzma,subprocess,sys,tempfile
from pathlib import Path
import joint_production as old
ROOT=old.ROOT
BASE='79cceedb8c35cf0fd79761ecd011b270245a67f1'
HISTORY='0ad09280824f3cc964b738730b73e9572a71c06f'
COLD_REF='05d2df1e937f1f6257d0d47709696c8d1e321391'
NAMES=old.NAMES
SOURCES=old.SOURCES
DIRECTORY=ROOT/'src/adapter'
ENTRY=old.ENTRY
STATUS=old.STATUS
KEY='joint_native_phase_writer_successor_20261106'
SCOPE='integration/dataqual15_hupsel/JOINT_WRITER_PHASE_PRODUCTION_SCOPE_20261106.json'
GATES={ENTRY,'tests/dataqual15_hupsel/joint_writer_phase_production.py','tests/dataqual15_hupsel/joint_writer_phase_production_runtime.py','tests/dataqual15_hupsel/joint_writer_phase_production_evidence.py','tests/dataqual15_hupsel/test_joint_writer_phase_production.py','.github/workflows/joint-writer-phase-production.yml'}
RUNNERS={'tests/nut-sol/run_age.py','tests/nut-sol/run_pond_joint.py','tests/nut-mineral/run_mineral.py','tests/nut-reactive/run_reactive.py'}
GATES|=RUNNERS
GATES.add('tests/dataqual15_hupsel/joint_writer_phase_production_linkage.py')
GATES.add('tests/dataqual15_hupsel/joint_writer_phase_production_consumers.py')
GATES.add('tests/dataqual15_hupsel/joint_writer_phase_production_before.py')
GATES|={'tests/dataqual15_hupsel/joint_writer_phase_predecessor.py','tests/dataqual15_hupsel/joint_writer_phase_cold.py','tests/dataqual15_hupsel/joint_writer_phase_evidence.py'}
git=old.git
raw=old.raw
blob=old.blob
normal=old.normal
sha=old.sha

def postimage(name):return raw(BASE,'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(SOURCES[name]).name)
candidate=postimage

def runner_postimage(path):
 text=raw(BASE,path).decode()
 if path in('tests/nut-sol/run_age.py','tests/nut-sol/run_pond_joint.py'):
  anchor="    exe=build/'joint';run(FC+flags+objects+['-o',exe],build,'physical_link')"
  block="    publication=ROOT/'app/support/restart_publish.c';bind(publication)\n    cc=subprocess.check_output(FC+['-print-prog-name=gcc'],text=True).strip();publication_obj=build/'restart_publish.o'\n    run([cc,'-'+opt,'-std=c11','-c',publication,'-o',publication_obj],build,'publication_compile')\n    objects.insert(-1,publication_obj)  # Keep the original main object last for the unchanged surface link.\n"
 elif path=='tests/nut-mineral/run_mineral.py':
  anchor=" obj=build/'joint.o';exe=build/'joint'"
  block=" publication=ROOT/'app/support/restart_publish.c';inputs[str(publication.relative_to(ROOT))]=sha(publication)\n cc=subprocess.check_output(FC+['-print-prog-name=gcc'],text=True).strip();publication_obj=build/'restart_publish.o'\n cmd([cc,'-'+opt,'-std=c11','-c',publication,'-o',publication_obj],build,'publication_compile');objects.append(publication_obj)\n"
 else:
  assert path=='tests/nut-reactive/run_reactive.py'
  anchor="  obj=build/(category+'-driver.o');exe=build/driver.stem"
  block="  if any('swap5_restart_publish' in p.read_text() for p in ordered):\n   publication=ROOT/'app/support/restart_publish.c';inputs[str(publication.relative_to(ROOT))]=sha(publication)\n   cc=subprocess.check_output(FC+['-print-prog-name=gcc'],text=True).strip();publication_obj=build/'restart_publish.o'\n   cmd([cc,'-'+opt,'-std=c11','-c',publication,'-o',publication_obj],build,'publication_compile');objects.append(publication_obj)\n"
 assert text.count(anchor)==1
 result=text.replace(anchor,block+anchor,1)
 if path=='tests/nut-sol/run_pond_joint.py':
  before="[obj for source,obj in zip(ordered,objects[:-1]) if source!=joint_oracle]+original_objects+['-o',original_exe]"
  assert result.count(before)==1
  result=result.replace(before,"[obj for source,obj in zip(ordered,objects[:-1]) if source!=joint_oracle]+[publication_obj]+original_objects+['-o',original_exe]",1)
 return result.encode()

def successor_entry():
 text=raw(HISTORY,ENTRY).decode();anchor=" if 'joint_native_writer_successor_20261106' in json.loads((ROOT/NATIVE_STATUS).read_text()):"
 assert text.count(anchor)==1
 branch=" if '"+KEY+"' in json.loads((ROOT/NATIVE_STATUS).read_text()):\n  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/joint_writer_phase_production.py'),'--output',str(out)],cwd=ROOT,check=True)\n  return\n"
 return text.replace(anchor,branch+anchor,1).encode()

def guard_source():
 assert subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,capture_output=True).returncode==0
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())==set(SOURCES.values()),'exact three-writer production footprint'
 assert not git('diff','HEAD','--','src','app','reference')
 assert not git('ls-files','--others','--exclude-standard','--','src','app','reference')
 for n,p in SOURCES.items():assert normal((ROOT/p).read_bytes())==raw('HEAD',p)==postimage(n),'complete deployed writer postimage '+n
 for area in('app','reference'):assert blob('HEAD',area)==blob(BASE,area)
 return {a:blob('HEAD',a)for a in('src','app','reference')}
source_guard=guard_source

def reference_paths():
 return {'integration/dataqual15_hupsel/JOINT_WRITER_PR1605_'+platform+'_'+opt+'_20261106'+suffix for platform in('WINDOWS','POSIX')for opt in('O0','O2')for suffix in('.json','.tar.xz')}

def frozen_ref(path):return COLD_REF if path in reference_paths()else BASE

def frozen():
 predecessors={old.SCOPE,'integration/dataqual15_hupsel/JOINT_PRODUCTION_EXACT_BEFORE_20261106.zip'}|{'integration/dataqual15_hupsel/JOINT_PRODUCTION_'+p+'_'+o+'_20261106'+s for p in('WINDOWS','POSIX')for o in('O0','O2')for s in('.json','.tar.xz')}
 return (old.frozen()|old.GATES|predecessors|reference_paths()|{'tests/dataqual15_hupsel/'+n+'.py'for n in('joint_limiter_writer','joint_limiter_writer_runtime','joint_limiter_writer_evidence','joint_writer','joint_writer_probe','joint_writer_runtime','joint_writer_evidence','joint_production_runtime')}|{'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(p).name for p in SOURCES.values()}|{'integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_RECONCILIATION_20261106'+s for s in('.json','.zip')})-{ENTRY}

def execution_paths():return {'integration/dataqual15_hupsel/JOINT_WRITER_PHASE_PRODUCTION_'+p+'_'+o+'_20261106'+s for p in('WINDOWS','POSIX')for o in('O0','O2')for s in('.json','.tar.xz')}
def before_paths():return {'integration/dataqual15_hupsel/JOINT_WRITER_PHASE_PRODUCTION_EXACT_BEFORE_20261106.zip'}

def consumer_paths():return {'integration/dataqual15_hupsel/JOINT_WRITER_PHASE_PRODUCTION_POSIX_CONSUMERS_20261106'+s for s in('.json','.zip')}

def preservation_paths():return {'integration/dataqual15_hupsel/JOINT_WRITER_PR1604_PRESERVATION_20261106.zip'}

def expected_status():return dict(scope=SCOPE,current_baseline=BASE,native_history=HISTORY,whole_scientific_admission=False)

def make_record(phase):
 return dict(schema=1,phase=phase,current_baseline=BASE,native_history=HISTORY,scope='EXACT_CURRENT_NATIVE_WRITER_PUBLICATION_ONLY',whole_scientific_admission=False,peer_source_change=False,binary_abi='SAME_PLATFORM_ONLY',windows_path_scope='ASCII_ONLY',predecessor_scope='IMMUTABLE_HISTORY_NOT_CURRENT_PEER_PHYSICS',baseline_production_trees={a:blob(BASE,a)for a in('src','app','reference')},production_delta={p:dict(before=blob(BASE,p),after=blob('HEAD',p))for p in SOURCES.values()},postimage_sha256={n:sha(postimage(n))for n in NAMES},gate_sha256={p:sha(normal((ROOT/p).read_bytes()))for p in GATES},frozen_blobs={p:blob(frozen_ref(p),p)for p in frozen()},execution_sha256={p:sha(normal((ROOT/p).read_bytes())if p.endswith('.json')else(ROOT/p).read_bytes())for p in execution_paths()if(ROOT/p).is_file()},consumer_sha256={p:sha(normal((ROOT/p).read_bytes())if p.endswith('.json')else(ROOT/p).read_bytes())for p in consumer_paths()if(ROOT/p).is_file()},before_sha256={p:sha((ROOT/p).read_bytes())for p in before_paths()if(ROOT/p).is_file()},preservation_sha256={p:sha((ROOT/p).read_bytes())for p in preservation_paths()if(ROOT/p).is_file()})

def record_guard(r):
 fields={'schema','phase','current_baseline','native_history','scope','whole_scientific_admission','peer_source_change','binary_abi','windows_path_scope','predecessor_scope','baseline_production_trees','production_delta','postimage_sha256','gate_sha256','frozen_blobs','execution_sha256','consumer_sha256','before_sha256','preservation_sha256'}
 assert set(r)==fields and type(r['schema'])is int and r['schema']==1
 assert r['phase']=='DEPLOYED_WINDOWS_POSIX_QUALIFIED','complete deployed execution required'
 assert r['current_baseline']==BASE and r['native_history']==HISTORY and r['scope']=='EXACT_CURRENT_NATIVE_WRITER_PUBLICATION_ONLY'
 assert r['whole_scientific_admission']is False and r['peer_source_change']is False
 assert r['binary_abi']=='SAME_PLATFORM_ONLY'and r['windows_path_scope']=='ASCII_ONLY'and r['predecessor_scope']=='IMMUTABLE_HISTORY_NOT_CURRENT_PEER_PHYSICS'
 assert r['baseline_production_trees']=={a:blob(BASE,a)for a in('src','app','reference')}
 assert r['production_delta']=={p:dict(before=blob(BASE,p),after=blob('HEAD',p))for p in SOURCES.values()}
 assert r['postimage_sha256']=={n:sha(postimage(n))for n in NAMES}
 assert set(r['gate_sha256'])==GATES and set(r['frozen_blobs'])==frozen()and set(r['execution_sha256'])==execution_paths()
 assert set(r['consumer_sha256'])==consumer_paths()and set(r['before_sha256'])==before_paths()and set(r['preservation_sha256'])==preservation_paths()

def validate_record(r):
 guard_source();record_guard(r)
 assert normal((ROOT/ENTRY).read_bytes())==raw('HEAD',ENTRY)==successor_entry(),'exact additive successor entry'
 for p in RUNNERS:assert normal((ROOT/p).read_bytes())==raw('HEAD',p)==runner_postimage(p),'original runner plus publisher linkage only '+p
 for p,digest in r['gate_sha256'].items():assert sha(normal((ROOT/p).read_bytes()))==digest and normal((ROOT/p).read_bytes())==raw('HEAD',p),'gate identity '+p
 for p,pin in r['frozen_blobs'].items():
  assert blob(frozen_ref(p),p)==pin==blob('HEAD',p),'frozen origin '+p
  content=(ROOT/p).read_bytes()
  if p.endswith(('.py','.f90','.json','.yml')):content=normal(content)
  assert content==raw(frozen_ref(p),p),'dirty frozen '+p
 for p,digest in r['execution_sha256'].items():
  content=(ROOT/p).read_bytes()
  if p.endswith('.json'):content=normal(content)
  assert sha(content)==digest and content==raw('HEAD',p),'deployed execution identity '+p
  if p.endswith('.json'):assert json.loads(content)['measurement']['production_linkage_native_launches']==56,'complete uninstrumented production linkage required'
 for p,digest in r['consumer_sha256'].items():
  content=(ROOT/p).read_bytes()
  if p.endswith('.json'):content=normal(content)
  assert sha(content)==digest and content==raw('HEAD',p),'original consumer identity '+p
 for p,digest in r['preservation_sha256'].items():assert sha((ROOT/p).read_bytes())==digest and(ROOT/p).read_bytes()==raw('HEAD',p),'entire prior admission execution identity'
 for p,digest in r['before_sha256'].items():assert sha((ROOT/p).read_bytes())==digest and(ROOT/p).read_bytes()==raw('HEAD',p),'exact before identity'
 current=json.loads((ROOT/STATUS).read_text());addition=current.pop(KEY)
 assert old.canonical(addition)==old.canonical(expected_status())
 assert old.canonical(current)==old.canonical(json.loads(raw(HISTORY,STATUS))),'previous status and types preserved'
 assert normal((ROOT/STATUS).read_bytes())==raw('HEAD',STATUS),'dirty status'
 return r

def guard():
 content=normal((ROOT/SCOPE).read_bytes());assert content==raw('HEAD',SCOPE),'dirty scope'
 return validate_record(json.loads(content))

@functools.lru_cache(maxsize=1)
def reference(platform,opt):
 stem='integration/dataqual15_hupsel/JOINT_WRITER_PR1605_'+platform+'_'+opt+'_20261106'
 manifest=raw(COLD_REF,stem+'.json');assert normal((ROOT/(stem+'.json')).read_bytes())==manifest
 m=json.loads(manifest);archive=(ROOT/(stem+'.tar.xz')).read_bytes();assert archive==raw(COLD_REF,stem+'.tar.xz')and sha(archive)==m['sha256']
 with io.BytesIO(lzma.decompress(archive))as stream:
  import tarfile
  with tarfile.open(fileobj=stream,mode='r:')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {p:sha(b)for p,b in files.items()}==m['members']
 import joint_writer_phase_evidence as cold
 measured=cold.audit(files);measured['corruption_refusals']=cold.corruption_tests(files);assert measured==m['measurement']
 r=json.loads(files['RESULT.json']);b=json.loads(files['baseline/BUILD.json'])
 q=__import__('pathlib').PureWindowsPath if platform=='WINDOWS'else __import__('pathlib').PurePosixPath
 root=str(q(next(iter(b['objects_sha256']))).parent.parent)
 files['PROVENANCE.json']=json.dumps(dict(root=root,sources={row['source']:row for row in r['sources']})).encode()
 for name in NAMES:
  mod='mod_'+name+'_joint_restart_file.mod';files['candidate/'+mod]=files['baseline/'+mod]
 return m,{'providers/'+p:b for p,b in files.items()}

def main(out):
 guard();out.mkdir(parents=True,exist_ok=False)
 import joint_writer_phase_production_evidence as evidence
 import joint_writer_phase_production_consumers as consumers
 consumer_results=consumers.verify()
 import joint_writer_phase_production_before as before
 before_results=before.verify()
 measured={}
 for p in('WINDOWS','POSIX'):
  for o in('O0','O2'):measured[p+'_'+o]=evidence.verify('JOINT_WRITER_PHASE_PRODUCTION_'+p+'_'+o+'_20261106',True)
 import joint_writer_phase_predecessor as predecessor
 previous=predecessor.verify()
 guard();(out/'RESULT.json').write_text(json.dumps(dict(status='EXACT_CURRENT_PHASE_DEPLOYED_WRITERS_AND_COMPLETE_PRIOR_ADMISSION_PASS',head=git('rev-parse','HEAD'),production_trees=guard_source(),current=measured,original_consumers=consumer_results,exact_before_diagnostics=before_results,previous=previous,current_reference=BASE,native_history=HISTORY,history_qualifies_current_peer_physics=False,whole_scientific_admission=False),indent=2)+'\n')

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();main(a.output.resolve())
