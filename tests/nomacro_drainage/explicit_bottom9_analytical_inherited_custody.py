"""Fresh complete parent evidence custody for strictly unchanged science reuse."""
import hashlib,json,subprocess
from pathlib import Path
from explicit_bottom9_analytical_source_inverse import ROOT,PARENT_PUBLIC,git,norm

PREFIX='integration/f-ci/nomacro-complete01/'
PLAN='EXPLICIT_BOTTOM9_ANALYTICAL_PARENT_COMPLETE_BLOB_CUSTODY_V2.json'


def inventory():
 rows=[]
 for line in git('ls-tree','-rl',PARENT_PUBLIC,'--',PREFIX.rstrip('/')).decode().splitlines():
  meta,name=line.split('\t');mode,kind,blob,size=meta.split();assert kind=='blob'
  rows.append(dict(path=name,git_blob=blob,bytes=int(size)))
 return rows


def fresh(proof):
 """No data cache, rewritten identity, numerical replay or archive extraction."""
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
 return dict(status='COMPLETE_PARENT_ARCHIVE_BLOBS_PRESENT_WORKING_BYTES_AND_ALL_SCIENTIFIC_DECLARATIONS_FRESH_EXACT',parent=PARENT_PUBLIC,archives_and_parts=observed,declarations=declarations,total_bytes=sum(x['bytes'] for x in observed),compiler_executions=0,model_executions=0,scientific_bytes_cached_or_projected=False)
