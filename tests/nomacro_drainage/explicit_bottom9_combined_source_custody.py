"""Fresh complete Source custody for configuration reuse of admitted parent216."""
import base64,hashlib,json,re
from pathlib import Path
from explicit_bottom9_combined_source import verify as sibling_sources,CORE
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized,SOURCE_DOMAINS
from explicit_bottom9_source_inverse import ROOT,git,blob,norm
from analytical_hydraulic_archives import SHA
BASE='67d2636672921505ecb47f1c9f4c6ea27a451889'
MANIFEST='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_COMBINED_PARENT_SOURCE_EDITS_V1.json'
MANIFEST_SHA='838dadc8bf5f021b0cb451bd91e678a8b954fc74c5ced8d854e0fe2fe8842ae6'
SELF='tests/nomacro_drainage/explicit_bottom9_combined_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
HOOK_NAMES=('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged')

def app_inverses():
 sibling_sources();raw=norm((ROOT/MANIFEST).read_bytes());assert SHA(raw)==MANIFEST_SHA;q=json.loads(raw);assert q['parent']==BASE and q['composition_core']==CORE;restored={}
 for path,item in q['files'].items():
  current=norm((ROOT/path).read_bytes());assert current==blob(CORE,path) and SHA(current)==item['core_sha256'];lines=current.decode().splitlines(keepends=True)
  for edit in reversed(item['positioned_literal_edits']):
   assert ''.join(lines[edit['new_start']:edit['new_end']])==edit['new'];lines[edit['new_start']:edit['new_end']]=edit['old'].splitlines(keepends=True)
  old=''.join(lines).encode();assert old==blob(BASE,path) and SHA(old)==item['parent_sha256'];restored[path]=old
 assert len(restored)==8;return restored

def source(anchor,owner_installed=True):
 assert re.fullmatch('[0-9a-f]{40}',anchor);head=git('rev-parse','HEAD');assert not git('for-each-ref','--format=%(refname)','refs/replace');inverses=app_inverses()
 def tree(ref):
  entries={}
  for line in git('ls-tree','-rl',ref,'--',*SOURCE_DOMAINS).decode().splitlines():
   meta,path=line.split('\t');entries[path]=meta
  return entries
 expected,current,parent=tree(anchor),tree('HEAD'),tree(BASE);assert current.keys()==expected.keys() and not git('status','--porcelain','--untracked-files=all','--',*SOURCE_DOMAINS),'Dirty or foreign Source dependency surface'
 if owner_installed:
  import explicit_bottom9_verify as old_owner
  text=norm((ROOT/JOINT).read_bytes()).decode()
  for name in HOOK_NAMES:
   new=' import explicit_bottom9_combined_verify as combined_owner\n return combined_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n';old=old_owner.HOOKS[name];assert text.count(new)==1;text=text.replace(new,old,1)
  inverses[JOINT]=text.encode();assert inverses[JOINT]==blob(BASE,JOINT)
 modified={path for path in parent if path in current and current[path]!=parent[path]}
 assert modified==set(inverses),'Unexpected inherited Source change beyond complete literal inverses'
 assert parent.keys()<=current.keys(),'Inherited Source path removed'
 tracked=tracked_working_files();observed=[]
 for path,meta in expected.items():
  mode,kind,digest,size=meta.split();assert kind=='blob' and mode!='120000';assert path in tracked and tracked[path][1]==mode
  if path!=SELF:assert current[path]==meta and tracked[path][2]==digest,'Frozen Source tree/index entry changed: '+path
  else:assert owner_installed and current[path].split()[:2]==[mode,kind]
  if path in parent and path not in inverses:assert current[path]==parent[path],'Inherited dependency changed: '+path
  if not materialized(path,tracked):continue
  actual=(ROOT/path).read_bytes();normalized=norm(actual)
  encoded_archive=None
  if path==SELF:
   original=blob(anchor,path);pattern=br"(?m)^SEALED='[0-9a-f]{40}'$";left,a=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",normalized);right,b=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",original);assert a==b==1 and left==right,'Frozen owner changed beyond immutable anchor literal'
  elif Path(path).suffix.lower()=='.b64':
   original=blob(anchor,path)
   # Git's textual base64 wrapper may use platform CRLF. Require that exact
   # whole spelling and independently require the original decoded archive
   # bytes; neither the wrapper nor its scientific payload is rewritten.
   assert actual in (original,original.replace(b'\n',b'\r\n')),'Foreign base64 Source spelling: '+path
   decoded=base64.b64decode(actual);assert decoded==base64.b64decode(original),'Changed encoded scientific archive: '+path
   encoded_archive=SHA(decoded)
  else:
   digest_of=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();allowed=(digest_of(actual),) if Path(path).suffix.lower() in ('.zip','.tar','.gz') else (digest_of(actual),digest_of(normalized));assert digest in allowed,'Actual Source file differs: '+path
  if path in inverses:assert inverses[path]==blob(BASE,path)
  observed.append(dict(path=path,actual_raw_sha256=SHA(actual),literal_parent_inverse=path in inverses,decoded_original_archive_sha256=encoded_archive))
 assert git('rev-parse','HEAD')==head and not git('for-each-ref','--format=%(refname)','refs/replace')
 return dict(status='COMPLETE_PARENT216_INHERITED_AND_CURRENT_SOURCE_TREE_WORKING_BYTES_AND_EIGHT_LITERAL_APP_INVERSES_VERIFIED',actual_head=head.decode().strip(),source_anchor=anchor,parent=BASE,materialized_source=observed,total_source_entries=len(expected),inherited_source_entries=len(parent),literal_parent_inverses=len(inverses),actual_Git_or_filesystem_views_projected=False,compiler_executions=0,model_executions=0)
