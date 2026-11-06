"""Exact deployed joint readers, current execution and immutable native history."""
import argparse,hashlib,json,os,subprocess,sys,tempfile,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='dafb351da2279cfa9a2a261481f06518329ba175'
HISTORY='6bcacb0af5890db0d54fa9b24a7f322f36de76c2'
NAMES=('age','mineral','reactive_n')
SOURCES={n:'src/adapter/mod_'+n+'_joint_restart_file.f90'for n in NAMES}
ENTRY='tests/dataqual15/verify_current_native_admission.py'
STATUS='integration/dataqual15/STATUS.json'
KEY='joint_native_logical_successor_20261106'
SCOPE='integration/dataqual15_hupsel/JOINT_PRODUCTION_SCOPE_20261106.json'
GATES={'tests/dataqual15_hupsel/joint_production_before.py',ENTRY,'tests/dataqual15_hupsel/joint_production.py','tests/dataqual15_hupsel/joint_production_runtime.py','tests/dataqual15_hupsel/joint_production_evidence.py','tests/dataqual15_hupsel/test_joint_production.py','.github/workflows/joint-production.yml'}
normal=lambda b:b.replace(b'\r\n',b'\n')
sha=lambda b:hashlib.sha256(b).hexdigest()
canonical=lambda v:json.dumps(v,sort_keys=True,separators=(',',':'))
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT,text=True).strip()
def raw(ref,name):return subprocess.check_output(['git','show',ref+':'+name],cwd=ROOT)
def blob(ref,name):return git('rev-parse',ref+':'+name)
def reference_name(platform,opt):return 'JOINT_CURRENT_'+platform+'_'+opt+'_20261106'
def postimage(name):return raw(BASE,'tests/dataqual15_hupsel/joint_logical_candidates/'+Path(SOURCES[name]).name)
def source_guard():
 assert subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,capture_output=True).returncode==0
 assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())==set(SOURCES.values()),'exact three-reader production footprint'
 assert not git('diff','HEAD','--','src','app','reference'),'dirty production source'
 assert not git('ls-files','--others','--exclude-standard','--','src','app','reference'),'unknown production source'
 for name,path in SOURCES.items():assert normal((ROOT/path).read_bytes())==postimage(name)==raw('HEAD',path),'deployed full postimage: '+name
 for area in ('app','reference'):assert blob('HEAD',area)==blob(BASE,area)
 return {area:blob('HEAD',area)for area in ('src','app','reference')}
def references():
 result=set()
 for platform in ('WINDOWS','POSIX'):
  for opt in ('O0','O2'):
   for prefix in ('JOINT_CURRENT_','JOINT_CURRENT_OWNER_'):
    stem=prefix+platform+'_'+opt+'_20261106';path='integration/dataqual15_hupsel/'+stem+'.json';result.add(path);m=json.loads(raw(BASE,path))
    if 'parts'in m:result.update('integration/dataqual15_hupsel/'+x['path']for x in m['parts'])
    else:result.add('integration/dataqual15_hupsel/'+m['archive'])
 return result
def frozen():
 return references()|{'tests/dataqual15_hupsel/'+n+'.py'for n in ('joint_current','joint_current_evidence','joint_current_owner','joint_logical','native_n_crc_runtime','crc_family_runtime','rotation_native_baseline','joint_owner','joint_logical_evidence')}|{'tests/dataqual15_hupsel/joint_logical_candidates/'+Path(p).name for p in SOURCES.values()}
def record_guard(r):
 assert set(r)=={'schema','phase','current_baseline','native_history','scope','whole_scientific_admission','writer_publication_change','peer_source_change','binary_abi','windows_path_scope','predecessor_scope','baseline_production_trees','historical_production_trees','production_delta','postimage_sha256','gate_sha256','frozen_blobs','execution_sha256','before_sha256'}
 assert type(r['schema'])is int and r['schema']==1 and r['phase']=='DEPLOYED_WINDOWS_POSIX_QUALIFIED','complete deployed execution required'
 assert r['current_baseline']==BASE and r['native_history']==HISTORY
 assert r['scope']=='SAME_PLATFORM_NATIVE_RAW_LOGICAL_READERS_ONLY'
 assert r['whole_scientific_admission']is False and r['writer_publication_change']is False and r['peer_source_change']is False
 assert r['binary_abi']=='SAME_PLATFORM_ONLY'and r['windows_path_scope']=='ASCII_ONLY'
 assert r['predecessor_scope']=='IMMUTABLE_PRE_PEER_NATIVE_AUTHORITY_NOT_CURRENT_PEER_PHYSICS'
 assert set(r['gate_sha256'])==GATES and set(r['frozen_blobs'])==frozen()
 assert r['baseline_production_trees']=={a:blob(BASE,a)for a in ('src','app','reference')}
 assert r['historical_production_trees']=={a:blob(HISTORY,a)for a in ('src','app','reference')}
 assert r['production_delta']=={p:dict(before=blob(BASE,p),after=blob('HEAD',p))for p in SOURCES.values()}
 assert r['postimage_sha256']=={n:sha(postimage(n))for n in NAMES}
 records={'integration/dataqual15_hupsel/JOINT_PRODUCTION_'+platform+'_'+opt+'_20261106'+suffix for platform in ('WINDOWS','POSIX')for opt in ('O0','O2')for suffix in ('.json','.tar.xz')}
 assert set(r['execution_sha256'])==records
 assert set(r['before_sha256'])=={'integration/dataqual15_hupsel/JOINT_PRODUCTION_EXACT_BEFORE_20261106.zip'}
 return True
def validate_record(r):
 source_guard();record_guard(r)
 for name,digest in r['gate_sha256'].items():assert sha(normal((ROOT/name).read_bytes()))==digest and normal((ROOT/name).read_bytes())==raw('HEAD',name),'gate identity: '+name
 for name,pin in r['frozen_blobs'].items():
  assert blob(BASE,name)==pin==blob('HEAD',name),'frozen authority: '+name
  content=(ROOT/name).read_bytes()
  if name.endswith(('.py','.f90','.json')):content=normal(content)
  assert content==raw(BASE,name),'dirty frozen authority: '+name
 for name,digest in {**r['execution_sha256'],**r['before_sha256']}.items():
  content=(ROOT/name).read_bytes()
  if name.endswith('.json'):content=normal(content)
  assert sha(content)==digest and content==raw('HEAD',name),'deployed execution identity: '+name
 old=json.loads(raw(BASE,STATUS));current=json.loads((ROOT/STATUS).read_text());addition=current.pop(KEY)
 assert canonical(addition)==canonical(dict(scope=SCOPE,current_baseline=BASE,native_history=HISTORY,whole_scientific_admission=False))
 assert canonical(current)==canonical(old),'previous status and type authority'
 assert normal((ROOT/STATUS).read_bytes())==raw('HEAD',STATUS),'dirty status'
 return r
def guard():
 data=normal((ROOT/SCOPE).read_bytes());assert data==raw('HEAD',SCOPE),'dirty scope'
 return validate_record(json.loads(data))
def immutable_view(parent,name,ref):
 view=parent/name;assert not view.exists()and view.parent==parent
 subprocess.run(['git','-c','core.autocrlf=false','worktree','add','--detach',str(view),ref],cwd=ROOT,capture_output=True,check=True)
 assert subprocess.check_output(['git','rev-parse','HEAD'],cwd=view,text=True).strip()==ref
 return view
def run(out,label,args,cwd,timeout=3000):
 start=time.monotonic();command=[sys.executable,'-B',*map(str,args)];cp=subprocess.run(command,cwd=cwd,capture_output=True,timeout=timeout,env=dict(os.environ,PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1'))
 for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
 event=dict(label=label,command=command,returncode=cp.returncode,seconds=time.monotonic()-start)
 with(out/'EVENTS.jsonl').open('a')as f:f.write(json.dumps(event)+'\n')
 assert cp.returncode==0,cp.stderr[-4000:];print(label,'PASS',flush=True);return event
def frozen_source_refusal(out,label,module):
 command=[sys.executable,'-B','-c',"import sys;sys.path.insert(0,'tests/dataqual15_hupsel');import "+module+';'+module+'.guard()']
 cp=subprocess.run(command,cwd=ROOT,capture_output=True,env=dict(os.environ,PYTHONUTF8='1',PYTHONDONTWRITEBYTECODE='1'))
 for stream in ('stdout','stderr'):(out/(label+'.'+stream)).write_bytes(getattr(cp,stream))
 assert cp.returncode!=0 and b'AssertionError'in cp.stderr and b'rev-parse'in cp.stderr,'frozen source guard refusal must stay explicit'
 event=dict(label=label,command=command,returncode=cp.returncode,old_gate_pass_claim=False,scope='FROZEN_SOURCE_GUARD_REFUSES_DEPLOYED_POSTIMAGES')
 with(out/'EVENTS.jsonl').open('a')as f:f.write(json.dumps(event)+'\n')
 return event

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--output',type=Path,required=True);a=parser.parse_args();guard();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 import joint_production_evidence as evidence
 import joint_production_before
 before=joint_production_before.verify()
 measured={};events=[frozen_source_refusal(out,'unchanged-current-source-refusal','joint_current'),frozen_source_refusal(out,'unchanged-frozen-owner-source-refusal','joint_owner')]
 for platform in ('WINDOWS','POSIX'):
  for opt in ('O0','O2'):measured[platform+'_'+opt]=evidence.verify('JOINT_PRODUCTION_'+platform+'_'+opt+'_20261106',True)
 parent=Path(tempfile.mkdtemp(prefix='s5jp-views-')).resolve();views=[]
 try:
  reference=immutable_view(parent,'reference',BASE);views.append(reference)
  for module in ('joint_current','joint_owner'):
   events.append(run(out,'reference-source-guard-'+module,['-c',"import sys;sys.path.insert(0,'tests/dataqual15_hupsel');import "+module+';'+module+'.guard()'],reference))
  for platform in ('WINDOWS','POSIX'):
   for opt in ('O0','O2'):
    events.append(run(out,'reference-'+platform+'-'+opt,['tests/dataqual15_hupsel/joint_current_evidence.py','--stem',reference_name(platform,opt),'--self-test'],reference))
    events.append(run(out,'reference-owner-'+platform+'-'+opt,['tests/dataqual15_hupsel/joint_current_owner.py','--verify','JOINT_CURRENT_OWNER_'+platform+'_'+opt+'_20261106','--self-test'],reference))
  history=immutable_view(parent,'native-history',HISTORY);views.append(history)
  events.append(run(out,'entire-unmodified-native-history',[ENTRY,'--output',out/'native-history'],history))
  guard();(out/'RESULT.json').write_text(json.dumps(dict(status='DEPLOYED_THREE_NATIVE_READERS_CURRENT_EXECUTION_AND_IMMUTABLE_HISTORY_PASS',head=git('rev-parse','HEAD'),production_trees=source_guard(),current=measured,exact_before_diagnostics=before,history=HISTORY,history_scope='EXACT_PRE_PEER_NATIVE_AUTHORITY_NOT_CURRENT_PEER_PHYSICS',events=events,whole_scientific_admission=False),indent=2)+'\n')
 finally:
  for view in reversed(views):subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,capture_output=True,check=True)
if __name__=='__main__':main()
