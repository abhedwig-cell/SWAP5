"""Exact executed deployed writer successor, current codecs and frozen history."""
import argparse,functools,io,json,lzma,subprocess,sys,tempfile
from pathlib import Path
import joint_production as old
ROOT=old.ROOT
BASE='fd31802ced32db6625dc329f0e4ecdea8618cb9b'
HISTORY='5264f3e0335b40df5aa5223cca84e028f5ae617d'
NAMES=old.NAMES
SOURCES=old.SOURCES
DIRECTORY=ROOT/'src/adapter'
ENTRY=old.ENTRY
STATUS=old.STATUS
KEY='joint_native_writer_successor_20261106'
SCOPE='integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_SCOPE_20261106.json'
GATES={ENTRY,'tests/dataqual15_hupsel/joint_writer_production.py','tests/dataqual15_hupsel/joint_writer_production_runtime.py','tests/dataqual15_hupsel/joint_writer_production_evidence.py','tests/dataqual15_hupsel/test_joint_writer_production.py','.github/workflows/joint-writer-production.yml'}
RUNNERS={'tests/nut-sol/run_age.py','tests/nut-mineral/run_mineral.py','tests/nut-reactive/run_reactive.py'}
GATES|=RUNNERS
git=old.git
raw=old.raw
blob=old.blob
normal=old.normal
sha=old.sha

def postimage(name):return raw(BASE,'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(SOURCES[name]).name)
candidate=postimage

def runner_postimage(path):
 text=raw(BASE,path).decode()
 if path=='tests/nut-sol/run_age.py':
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
 return text.replace(anchor,block+anchor,1).encode()

def successor_entry():
 text=raw(BASE,ENTRY).decode();anchor=" if json.loads((ROOT/NATIVE_STATUS).read_text()).get('joint_native_logical_successor_20261106'):"
 assert text.count(anchor)==1
 branch=" if '"+KEY+"' in json.loads((ROOT/NATIVE_STATUS).read_text()):\n  subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/joint_writer_production.py'),'--output',str(out)],cwd=ROOT,check=True)\n  return\n"
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
 return {'integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_'+platform+'_'+opt+'_20261106'+suffix for platform in('WINDOWS','POSIX')for opt in('O0','O2')for suffix in('.json','.tar.xz')}

def frozen():
 predecessors={old.SCOPE,'integration/dataqual15_hupsel/JOINT_PRODUCTION_EXACT_BEFORE_20261106.zip'}|{'integration/dataqual15_hupsel/JOINT_PRODUCTION_'+p+'_'+o+'_20261106'+s for p in('WINDOWS','POSIX')for o in('O0','O2')for s in('.json','.tar.xz')}
 return (old.frozen()|old.GATES|predecessors|reference_paths()|{'tests/dataqual15_hupsel/'+n+'.py'for n in('joint_limiter_writer','joint_limiter_writer_runtime','joint_limiter_writer_evidence','joint_writer','joint_writer_probe','joint_writer_runtime','joint_writer_evidence','joint_production_runtime')}|{'tests/dataqual15_hupsel/joint_writer_candidates/'+Path(p).name for p in SOURCES.values()}|{'integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_RECONCILIATION_20261106'+s for s in('.json','.zip')})-{ENTRY}

def execution_paths():return {'integration/dataqual15_hupsel/JOINT_WRITER_PRODUCTION_'+p+'_'+o+'_20261106'+s for p in('WINDOWS','POSIX')for o in('O0','O2')for s in('.json','.tar.xz')}

def expected_status():return dict(scope=SCOPE,current_baseline=BASE,native_history=HISTORY,whole_scientific_admission=False)

def make_record(phase):
 return dict(schema=1,phase=phase,current_baseline=BASE,native_history=HISTORY,scope='EXACT_CURRENT_NATIVE_WRITER_PUBLICATION_ONLY',whole_scientific_admission=False,peer_source_change=False,binary_abi='SAME_PLATFORM_ONLY',windows_path_scope='ASCII_ONLY',predecessor_scope='IMMUTABLE_HISTORY_NOT_CURRENT_PEER_PHYSICS',baseline_production_trees={a:blob(BASE,a)for a in('src','app','reference')},production_delta={p:dict(before=blob(BASE,p),after=blob('HEAD',p))for p in SOURCES.values()},postimage_sha256={n:sha(postimage(n))for n in NAMES},gate_sha256={p:sha(normal((ROOT/p).read_bytes()))for p in GATES},frozen_blobs={p:blob(BASE,p)for p in frozen()},execution_sha256={p:sha(normal((ROOT/p).read_bytes())if p.endswith('.json')else(ROOT/p).read_bytes())for p in execution_paths()if(ROOT/p).is_file()})

def record_guard(r):
 fields={'schema','phase','current_baseline','native_history','scope','whole_scientific_admission','peer_source_change','binary_abi','windows_path_scope','predecessor_scope','baseline_production_trees','production_delta','postimage_sha256','gate_sha256','frozen_blobs','execution_sha256'}
 assert set(r)==fields and type(r['schema'])is int and r['schema']==1
 assert r['phase']=='DEPLOYED_WINDOWS_POSIX_QUALIFIED','complete deployed execution required'
 assert r['current_baseline']==BASE and r['native_history']==HISTORY and r['scope']=='EXACT_CURRENT_NATIVE_WRITER_PUBLICATION_ONLY'
 assert r['whole_scientific_admission']is False and r['peer_source_change']is False
 assert r['binary_abi']=='SAME_PLATFORM_ONLY'and r['windows_path_scope']=='ASCII_ONLY'and r['predecessor_scope']=='IMMUTABLE_HISTORY_NOT_CURRENT_PEER_PHYSICS'
 assert r['baseline_production_trees']=={a:blob(BASE,a)for a in('src','app','reference')}
 assert r['production_delta']=={p:dict(before=blob(BASE,p),after=blob('HEAD',p))for p in SOURCES.values()}
 assert r['postimage_sha256']=={n:sha(postimage(n))for n in NAMES}
 assert set(r['gate_sha256'])==GATES and set(r['frozen_blobs'])==frozen()and set(r['execution_sha256'])==execution_paths()

def validate_record(r):
 guard_source();record_guard(r)
 assert normal((ROOT/ENTRY).read_bytes())==raw('HEAD',ENTRY)==successor_entry(),'exact additive successor entry'
 for p in RUNNERS:assert normal((ROOT/p).read_bytes())==raw('HEAD',p)==runner_postimage(p),'original runner plus publisher linkage only '+p
 for p,digest in r['gate_sha256'].items():assert sha(normal((ROOT/p).read_bytes()))==digest and normal((ROOT/p).read_bytes())==raw('HEAD',p),'gate identity '+p
 for p,pin in r['frozen_blobs'].items():
  assert blob(BASE,p)==pin==blob('HEAD',p),'frozen origin '+p
  content=(ROOT/p).read_bytes()
  if p.endswith(('.py','.f90','.json','.yml')):content=normal(content)
  assert content==raw(BASE,p),'dirty frozen '+p
 for p,digest in r['execution_sha256'].items():
  content=(ROOT/p).read_bytes()
  if p.endswith('.json'):content=normal(content)
  assert sha(content)==digest and content==raw('HEAD',p),'deployed execution identity '+p
 current=json.loads((ROOT/STATUS).read_text());addition=current.pop(KEY)
 assert old.canonical(addition)==old.canonical(expected_status())
 assert old.canonical(current)==old.canonical(json.loads(raw(BASE,STATUS))),'previous status and types preserved'
 assert normal((ROOT/STATUS).read_bytes())==raw('HEAD',STATUS),'dirty status'
 return r

def guard():
 content=normal((ROOT/SCOPE).read_bytes());assert content==raw('HEAD',SCOPE),'dirty scope'
 return validate_record(json.loads(content))

@functools.lru_cache(maxsize=1)
def reference(platform,opt):
 stem='integration/dataqual15_hupsel/JOINT_LIMITER_WRITER_'+platform+'_'+opt+'_20261106'
 manifest=raw(BASE,stem+'.json');assert normal((ROOT/(stem+'.json')).read_bytes())==manifest
 m=json.loads(manifest);archive=(ROOT/(stem+'.tar.xz')).read_bytes();assert archive==raw(BASE,stem+'.tar.xz')and sha(archive)==m['sha256']
 with io.BytesIO(lzma.decompress(archive))as stream:
  import tarfile
  with tarfile.open(fileobj=stream,mode='r:')as t:files={v.name:t.extractfile(v).read()for v in t.getmembers()}
 assert {p:sha(b)for p,b in files.items()}==m['members']
 return m,files

def main(out):
 guard();out.mkdir(parents=True,exist_ok=False)
 import joint_writer_production_evidence as evidence
 measured={}
 for p in('WINDOWS','POSIX'):
  for o in('O0','O2'):measured[p+'_'+o]=evidence.verify('JOINT_WRITER_PRODUCTION_'+p+'_'+o+'_20261106',True)
 parent=Path(tempfile.mkdtemp(prefix='s5jwp-views-')).resolve();views=[];events=[]
 try:
  reference_view=old.immutable_view(parent,'qualified-current',BASE);views.append(reference_view)
  events.append(old.run(out,'exact-current-private-source-guard',['-c',"import sys;sys.path.insert(0,'tests/dataqual15_hupsel');import joint_limiter_writer;joint_limiter_writer.guard()"],reference_view))
  for p in('WINDOWS','POSIX'):
   for o in('O0','O2'):events.append(old.run(out,'current-private-'+p+'-'+o,['tests/dataqual15_hupsel/joint_limiter_writer_evidence.py','--stem','JOINT_LIMITER_WRITER_'+p+'_'+o+'_20261106','--self-test'],reference_view))
  history=old.immutable_view(parent,'entire-native-history',HISTORY);views.append(history)
  events.append(old.run(out,'entire-unmodified-admitted-native-history',[ENTRY,'--output',out/'native-history'],history,6000))
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='EXACT_DEPLOYED_WRITERS_AND_CURRENT_CODECS_WITH_IMMUTABLE_HISTORY_PASS',head=git('rev-parse','HEAD'),production_trees=guard_source(),current=measured,events=events,current_reference=BASE,native_history=HISTORY,history_qualifies_current_peer_physics=False,whole_scientific_admission=False),indent=2)+'\n')
 finally:
  for view in reversed(views):subprocess.run(['git','worktree','remove','--force',str(view)],cwd=ROOT,check=True,capture_output=True)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();main(a.output.resolve())
