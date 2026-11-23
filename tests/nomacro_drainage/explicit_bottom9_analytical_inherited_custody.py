"""Fresh complete parent evidence custody for strictly unchanged science reuse."""
import hashlib,json,subprocess
from pathlib import Path
from explicit_bottom9_analytical_source_inverse import ROOT,PARENT_PUBLIC,git,norm,blob,checked_analytical_delta,ADDITION,NEW_MODEL_TEST,OLD_MODEL_TEST,MODULE,checked_workflow_extension

PREFIX='integration/f-ci/nomacro-complete01/'
PLAN='EXPLICIT_BOTTOM9_ANALYTICAL_PARENT_COMPLETE_BLOB_CUSTODY_V2.json'
SOURCE_DOMAINS=('app','src','tools','tests','reference','.github','integration/audits')
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
SELF='tests/nomacro_drainage/explicit_bottom9_analytical_verify.py'


def source(anchor):
 """Reuse the admitted source guard only after exact complete dependency proof.

 The two explicit text inverses are proof objects, not filesystem/Git views.
 Every remaining inherited tree entry and materialized source stays frozen.
 """
 import re
 import explicit_bottom9_verify as parent
 checked_analytical_delta();checked_workflow_extension()
 head=git('rev-parse','HEAD');assert not git('status','--porcelain','--untracked-files=all','--',*SOURCE_DOMAINS),'Dirty source dependency surface'
 expected=git('diff','--name-status',PARENT_PUBLIC,anchor,'--',*SOURCE_DOMAINS)
 assert git('diff','--name-status',PARENT_PUBLIC,'--',*SOURCE_DOMAINS)==expected,'Foreign source dependency addition/change'
 inverses={}
 raw=norm((ROOT/MODULE).read_bytes());inverses[MODULE]=raw.replace(ADDITION.encode(),b'',1).replace(NEW_MODEL_TEST.encode(),OLD_MODEL_TEST.encode(),1)
 raw=norm((ROOT/JOINT).read_bytes())
 if raw!=blob(PARENT_PUBLIC,JOINT):
  for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
   hook=(' import explicit_bottom9_analytical_verify as analytical_owner\n return analytical_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n').encode()
   assert raw.count(hook)==1;raw=raw.replace(hook,parent.HOOKS[name].encode(),1)
 inverses[JOINT]=raw
 for path,raw in inverses.items():assert raw==blob(PARENT_PUBLIC,path),'Incomplete literal source inverse: '+path
 # Exact Git tree postimages bind all inherited paths, including code outside
 # the numerical renderer. Fresh working bytes also bind every source consumed
 # by Python, shell, Fortran/C and their declarative compile/qualification data.
 changed={line.split('\t',1)[1]:line.split('\t',1)[0] for line in expected.decode().splitlines()}
 assert {p for p,status in changed.items() if status!='A'}<=set(inverses)
 suffixes={'.py','.f90','.f','.for','.inc','.c','.h','.cpp','.hpp','.sh','.yml','.yaml','.json','.toml','.cmake'}
 materialized=[];inherited=0
 for line in git('ls-tree','-rl',anchor,'--',*SOURCE_DOMAINS).decode().splitlines():
  meta,path=line.split('\t');mode,kind,digest,size=meta.split();assert kind=='blob'
  if path not in changed:inherited+=1
  actual=ROOT/path
  if not actual.is_file() or actual.suffix.lower() not in suffixes:continue
  assert not actual.is_symlink()
  actual_raw=actual.read_bytes();raw=norm(actual_raw)
  if path in inverses:
   raw=inverses[path];target=blob(PARENT_PUBLIC,path)
   assert raw==target,'Actual complete source inverse differs: '+path
  if path==SELF:
   target=blob(anchor,path)
   pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
   raw,a=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",raw);target,b=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",target);assert a==b==1
   assert raw==target,'Actual frozen source dependency changed: '+path
  elif path not in inverses:
   # ls-tree already supplies the immutable exact object identity. Verify
   # complete source bytes directly, without spawning git show per file.
   git_blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
   assert digest in (git_blob(actual_raw),git_blob(raw)),'Actual frozen source dependency changed: '+path
  materialized.append(dict(path=path,actual_raw_sha256=hashlib.sha256(actual_raw).hexdigest(),proven_source_sha256=hashlib.sha256(raw).hexdigest(),explicit_inverse=path in inverses))
 assert git('rev-parse','HEAD')==head,'Actual source HEAD changed during proof'
 return dict(status='COMPLETE_ADMITTED_PARENT_SOURCE_TREE_AND_ACTUAL_SOURCE_BYTES_UNCHANGED_EXCEPT_EXPLICIT_ANALYTICAL_SELECTION_AND_OWNER_HOOK_INVERSES',parent=PARENT_PUBLIC,source_anchor=anchor,actual_head=head.decode().strip(),inherited_tree_entries=inherited,materialized_source=materialized,declared_source_delta=changed,actual_Git_or_filesystem_views_projected=False,compiler_executions=0,model_executions=0)


def inventory():
 rows=[]
 for line in git('ls-tree','-rl',PARENT_PUBLIC,'--',PREFIX.rstrip('/')).decode().splitlines():
  meta,name=line.split('\t');mode,kind,blob,size=meta.split();assert kind=='blob'
  rows.append(dict(path=name,git_blob=blob,bytes=int(size)))
 return rows


def fresh(proof):
 """No data cache, rewritten identity, numerical replay or archive extraction."""
 assert not git('for-each-ref','--format=%(refname):%(objectname)','refs/replace')
 proof=Path(proof);plan=json.loads((proof/PLAN).read_text());assert plan['parent']==PARENT_PUBLIC and plan['count']==528
 rows=inventory();archives=[x for x in rows if any(s in Path(x['path']).name for s in ('.zip','.tar','.b64'))]
 expected=plan['archives_and_parts'];assert [{k:x[k] for k in ('path','git_blob','bytes')} for x in expected]==archives
 process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
 def actual_blob(item):
  process.stdin.write((item['git_blob']+'\n').encode());process.stdin.flush()
  assert process.stdout.readline().decode().split()==[item['git_blob'],'blob',str(item['bytes'])]
  remaining=item['bytes'];digest=hashlib.sha1(b'blob '+str(remaining).encode()+b'\0')
  while remaining:
   block=process.stdout.read(min(remaining,8*1024*1024));assert block;remaining-=len(block);digest.update(block);yield block
  assert process.stdout.read(1)==b'\n'
  assert digest.hexdigest()==item['git_blob'],'Actual immutable Git blob content differs'
 observed=[];declarations=0
 try:
  for item in expected:
   working=ROOT/item['path'];sha=hashlib.sha256();blob=hashlib.sha1(b'blob '+str(item['bytes']).encode()+b'\0');total=0
   if working.is_file():
    assert not working.is_symlink()
    with working.open('rb') as stream:
     while block:=stream.read(8*1024*1024):sha.update(block);blob.update(block);total+=len(block)
    storage='ACTUAL_SPARSE_WORKING_FILE'
   else:
    for block in actual_blob(item):sha.update(block);blob.update(block);total+=len(block)
    storage='ACTUAL_IMMUTABLE_GIT_BLOB_NOT_MATERIALIZED'
   assert total==item['bytes'] and blob.hexdigest()==item['git_blob'] and sha.hexdigest()==item['actual_sha256'],'Changed inherited scientific bytes: '+item['path']
   observed.append(dict(path=item['path'],git_blob=item['git_blob'],bytes=total,sha256=sha.hexdigest(),actual_storage=storage))
  # Every older proof declaration remains exact, including reader expectations,
  # qualification records and failed results. STATUS/GAP_MATRIX are descriptive.
  for item in rows:
   if not item['path'].endswith('.json') or Path(item['path']).name in ('STATUS.json','GAP_MATRIX.json'):continue
   old=b''.join(actual_blob(item));current=ROOT/item['path']
   if current.is_file():assert norm(current.read_bytes())==old,'Changed inherited scientific declaration: '+item['path']
   declarations+=1
 finally:
  process.stdin.close();assert process.wait(timeout=30)==0
 assert not git('for-each-ref','--format=%(refname):%(objectname)','refs/replace')
 return dict(status='COMPLETE_PARENT_ARCHIVE_BLOBS_PRESENT_WORKING_BYTES_AND_ALL_SCIENTIFIC_DECLARATIONS_FRESH_EXACT',parent=PARENT_PUBLIC,archives_and_parts=observed,declarations=declarations,total_bytes=sum(x['bytes'] for x in observed),compiler_executions=0,model_executions=0,scientific_bytes_cached_or_projected=False)
