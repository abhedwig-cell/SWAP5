"""Actual complete Source and admitted280 evidence custody; no projected views."""
import hashlib,json,re,subprocess
from pathlib import Path
from explicit_bottom9_snow_history_source_v2 import ROOT,CORE,complete_inverse,git
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized,SOURCE_DOMAINS
from analytical_hydraulic_archives import SHA
SELF='tests/nomacro_drainage/explicit_bottom9_snow_history_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
DOMAINS=(*SOURCE_DOMAINS,'docs/publication','docs/publications','docs/verification','docs/performance/evidence')
PREFIX='integration/f-ci/nomacro-complete01/'


def source(anchor):
 complete_inverse();head=git('rev-parse','HEAD');assert not git('for-each-ref','--format=%(refname)','refs/replace')
 assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('status','--porcelain=v1','--untracked-files=all','--',*DOMAINS),'Dirty scientific Source'
 def tree(ref):
  return {line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',*DOMAINS).decode().splitlines()}
 parent,current,frozen=tree(CORE),tree('HEAD'),tree(anchor);assert current.keys()==frozen.keys() and parent.keys()<=current.keys()
 modified={path for path in parent if parent[path]!=current[path]}
 contract=json.loads((ROOT/(PREFIX+'EXPLICIT_BOTTOM9_SNOW_HISTORY_CONTRACT_V2.json')).read_text())
 assert modified==set(contract['files'])|{JOINT},modified
 actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
 for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
  old=' import explicit_bottom9_combined_verify as combined_owner\n return combined_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n'
  new=' import explicit_bottom9_snow_history_verify as snow_history_owner\n return snow_history_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n'
  assert actual.count(new.encode())==1;actual=actual.replace(new.encode(),old.encode(),1)
 assert actual==git('show',CORE+':'+JOINT),'Incomplete public owner literal inverse'
 tracked=tracked_working_files();observed=[]
 for path,meta in frozen.items():
  mode,kind,digest,size=meta.split();assert mode!='120000' and kind=='blob' and path in tracked and tracked[path][1]==mode
  if path!=SELF:assert current[path]==meta and tracked[path][2]==digest,'Changed frozen source tree/index: '+path
  if not materialized(path,tracked):continue
  raw=(ROOT/path).read_bytes();normalized=raw.replace(b'\r\n',b'\n')
  if path==SELF:
   before=git('show',anchor+':'+path);pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
   left,a=re.subn(pattern,b"SEALED='IMMUTABLE_SOURCE_ANCHOR'",normalized);right,b=re.subn(pattern,b"SEALED='IMMUTABLE_SOURCE_ANCHOR'",before);assert a==b==1 and left==right,'Changed frozen owner beyond immutable anchor'
  else:
   blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
   assert digest in (blob(raw),blob(normalized)),'Changed actual source bytes: '+path
  observed.append(dict(path=path,actual_raw_sha256=SHA(raw),explicit_parent_inverse=path in modified))
 new_proof=[]
 parent_proof={line.split('\t',1)[1] for line in git('ls-tree','-r',CORE,'--',PREFIX).decode().splitlines()}
 for line in git('ls-tree','-rl',anchor,'--',PREFIX).decode().splitlines():
  meta,path=line.split('\t',1);mode,kind,digest,size=meta.split()
  if path in parent_proof or Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
  assert kind=='blob' and path in tracked and tracked[path][1:]==(mode,digest),'Changed new scientific proof tree/index: '+path
  raw=(ROOT/path).read_bytes() if materialized(path,tracked) else git('cat-file','blob',digest)
  blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
  variants=(raw,raw.replace(b'\r\n',b'\n')) if Path(path).suffix.lower() in ('.json','.md','.txt','.csv','.py') else (raw,)
  assert digest in tuple(blob(value) for value in variants),'Changed actual new scientific proof bytes: '+path
  new_proof.append(dict(path=path,actual_raw_sha256=SHA(raw)))
 assert git('rev-parse','HEAD')==head
 return dict(status='COMPLETE_280_PARENT_AND_CURRENT_SOURCE_TREE_INDEX_WORKING_BYTES_LITERAL_TWO_GUARDS_AND_PUBLIC_OWNER_INVERSE_PASS',actual_head=head.decode().strip(),source_anchor=anchor,parent=CORE,files=observed,new_proof_custody=new_proof,modified_inherited_files=sorted(modified),compiler_executions=0,model_executions=0,Git_or_working_views_projected=False)


def inherited_evidence():
 head=git('rev-parse','HEAD');tracked=tracked_working_files();rows=[]
 for line in git('ls-tree','-rl',CORE,'--',PREFIX).decode().splitlines():
  meta,path=line.split('\t',1);mode,kind,digest,size=meta.split()
  if Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
  assert kind=='blob' and path in tracked and tracked[path][1:]==(mode,digest),'Changed inherited evidence tree/index: '+path
  rows.append(dict(path=path,git_blob=digest,bytes=int(size)))
 process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE);observed=[]
 try:
  for item in rows:
   path=ROOT/item['path'];total=0;sha=hashlib.sha256();obj=hashlib.sha1(b'blob '+str(item['bytes']).encode()+b'\0')
   if materialized(item['path'],tracked):
    raw=path.read_bytes()
    if path.suffix.lower() in ('.json','.md','.txt','.csv','.tsv','.yml','.yaml','.b64','.sha256','.log','.stdout','.stderr','.rst','.tex','.bib','.py','.f90','.f','.c','.h','.cpp','.sh','.toml','.html','.css','.js','.svg'):raw=raw.replace(b'\r\n',b'\n')
    total=len(raw);sha.update(raw);obj.update(raw);storage='ACTUAL_WORKING_BYTES'
   else:
    process.stdin.write((item['git_blob']+'\n').encode());process.stdin.flush();assert process.stdout.readline().decode().split()==[item['git_blob'],'blob',str(item['bytes'])];remaining=item['bytes']
    while remaining:
     block=process.stdout.read(min(remaining,8*1024*1024));assert block;remaining-=len(block);total+=len(block);sha.update(block);obj.update(block)
    assert process.stdout.read(1)==b'\n';storage='ACTUAL_IMMUTABLE_GIT_BLOB_WITH_REAL_SKIP_WORKTREE'
   assert total==item['bytes'] and obj.hexdigest()==item['git_blob'],'Changed inherited scientific evidence bytes: '+item['path']
   observed.append(dict(**item,actual_sha256=sha.hexdigest(),storage=storage))
 finally:process.stdin.close();assert process.wait(timeout=30)==0
 assert git('rev-parse','HEAD')==head
 return dict(status='ALL_CANONICAL280_EVIDENCE_BLOBS_AND_DECLARATIONS_FRESH_EXACT_NO_CACHED_OR_PROJECTED_BYTES',actual_parent=CORE,files=observed,total_bytes=sum(x['bytes'] for x in rows),compiler_executions=0,model_executions=0)
