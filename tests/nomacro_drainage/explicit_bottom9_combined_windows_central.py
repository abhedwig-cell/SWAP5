"""Recompute every integrated whole compiled comparison from central raw bytes."""
import argparse,hashlib,io,json,tarfile,zipfile
from pathlib import Path,PureWindowsPath
from contextlib import ExitStack
from explicit_bottom9_combined_postimages import ROOT,SHA,git,verify,Archive,ReadView,generated,compare,prior_role
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
PROOF=ROOT/'integration/f-ci/nomacro-complete01'

class GitArchive:
 def __init__(self,opt,stack):
  name='OUTPUT_HYSTERESIS_WINDOWS_'+opt+'_RAW_ARCHIVE';path='integration/f-ci/nomacro-complete01/'+name+'.json';original=git('show','HEAD:'+path);tracked=tracked_working_files()
  if materialized(path,tracked):assert (ROOT/path).read_bytes().replace(b'\r\n',b'\n')==original,'Changed original hysteresis archive declaration'
  self.record=json.loads(original);raw=git('show','HEAD:integration/f-ci/nomacro-complete01/'+self.record['archive']);assert len(raw)==self.record['bytes'] and SHA(raw)==self.record['sha256'];self.z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));self.names=self.record['members'];assert len(self.z.namelist())==len(set(self.z.namelist()))==len(self.names) and set(self.z.namelist())==set(self.names)
 def get(self,name):
  raw=self.z.read(name);assert isinstance(self.names[name],str) and SHA(raw)==self.names[name] and len(raw)==self.z.getinfo(name).file_size;return raw

def captures(store):
 q=json.loads(store.get('profiles/explicit-bottom9-combined-actual-source-e378-v1/RESULT.json'));head=q['producer_head'];assert not git('diff','813c40017b2c0aed2802910ed6fab61a613598e9',head,'--','app','src','tools','reference')
 def expected(paths):return {line.split('\t')[1]:line.split('\t')[0].split()[2] for line in git('ls-tree','-r',head,'--',*paths).decode().splitlines()}
 def check(path,raw,item,entries):
  assert len(raw)==item['bytes'] and SHA(raw)==item['sha256'] and item['git_blob']==entries[path]
  blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();assert entries[path] in (blob(raw),blob(raw.replace(b'\r\n',b'\n')))
 raw=store.get('profiles/explicit-bottom9-combined-actual-source-e378-v1/'+q['archive']);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256'];entries=expected(q['surfaces']);assert set(entries)==set(q['members']);absent={n for n,item in q['members'].items() if item.get('checkout')=='ABSENT'};assert all(n.startswith('reference/swap-4.3.1/') for n in absent)
 with zipfile.ZipFile(io.BytesIO(raw)) as z:
  assert len(z.namelist())==len(set(z.namelist())) and set(z.namelist())==set(entries)-absent
  for name,item in q['members'].items():
   if name in absent:assert item==dict(git_blob=entries[name],checkout='ABSENT')
   else:check(name,z.read(name),item,entries)
 c=json.loads(store.get('observations/explicit-bottom9-combined-actual-committed-controllers-e378-v1.json'));assert c['actual_head']==head;raw=store.get('observations/'+c['archive']);assert len(raw)==c['bytes'] and SHA(raw)==c['sha256'];entries=expected(('tests/nomacro_drainage','tests/nomacro_scheduled_subsurface','tests/nomacro_mixtures'));assert set(entries)==set(c['members'])
 with tarfile.open(fileobj=io.BytesIO(raw)) as t:
  ms=t.getmembers();assert len(ms)==len({m.name for m in ms}) and {m.name for m in ms}==set(entries)
  for member in ms:assert member.isfile();check(member.name,t.extractfile(member).read(),c['members'][member.name],entries)
 return dict(actual_head=head,source_archive_sha256=q['sha256'],controller_archive_sha256=c['sha256'],source_inventory=len(q['members']),controller_inventory=len(c['members']))

def read():
 verify();results=[]
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_RAW_V1',stack);record=store.record;assert record['actual_compiled_closures']==len(record['roles'])==56 and record['model_executions']==0;projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));assert len(projection)==56
  for name in store.names:store.get(name)
  actual_captures=captures(store);archives={};histories={}
  def archive(name):
   if name not in archives:archives[name]=Archive(PROOF,name,stack)
   return archives[name]
  for role in record['roles']:
   profile=ReadView(store,role['profile']);q=json.loads((profile/'RESULT.json').read_text());build=ReadView(store,role['compiled']);meta=json.loads((build/'BUILD.json').read_text());assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256'] and q['model_executions']==0
   entry=projection[q['build_root']];assert entry['archive_prefix']==role['compiled'] and entry['actual_BUILD_sha256']==q['actual_BUILD_sha256'];producer=role['producer'];assert producer==q.get('actual_source',q.get('actual_compiler_start_HEAD'))==actual_captures['actual_head'];opt=role['optimization']
   if role['kind']=='postimages':
    family=q['family'];original_role=q['role']
    if family=='PRIOR':old_store,inputs,old_role,original,old=prior_role(PROOF,next(x for x in ('water-pressure-step','age-pressure-step','cde-pressure-daily','cde-monthly','cde-distributed-subdaily','water-last-node-drainage') if x in PureWindowsPath(q['input_root']).parent.name),opt,stack)
    else:
     old_store=archive('EXPLICIT_BOTTOM9_'+family+'_WINDOWS_RAW_V1');original=json.loads(old_store.get(original_role['profile']+'/RESULT.json'));old_entry=json.loads(old_store.get('COMPILED_PROJECTION_V1.json'))[original['build_root']];old=ReadView(old_store,old_entry['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==old_entry['actual_BUILD_sha256'];assert SHA(old_store.get(original_role['profile']+'/RESULT.json'))==q['original_profile_RESULT_sha256']
    assert original['source']==q['original_source'] and q['actual_compiler_start_HEAD']==q['actual_compiler_end_HEAD']==producer
    assert generated(old,build)==q['complete_generated_sources'] and compare(old,build)==q['all_compiled']
    inventory=dict(original['input_inventory'])
   else:
    label=q['label'];assert q['actual_source']==producer
    if label.startswith('history-'):
     if opt not in histories:histories[opt]=GitArchive(opt,stack)
     old_store=histories[opt];_,kind,mode=label.split('-');prefix='output-hysteresis-matrix-'+opt+'/short-'+kind+'-hys'+mode+'-csv'+('0' if mode=='1' else '3');old=ReadView(old_store,prefix+'/build');assert json.loads(old_store.get(prefix+'/RESULT.json'))['source_commit']==q['original_source']
    else:
     old_store=archive('EXPLICIT_BOTTOM9_SNOW_PRIOR_CONTROLS_RAW_V1');prior=json.loads(old_store.get('observations/EXPLICIT_BOTTOM9_SNOW_PRIOR_ACTUAL_PARENT_POSTIMAGES_V1.json'));matches=[x for x in prior['comparisons'] if x['optimization']==opt and x['kind']==label[len('snow-'):]];assert len(matches)==1;original=matches[0]['actual_candidate'];old_entry=json.loads(old_store.get('COMPILED_PROJECTION_V1.json'))[original['build_root']];old=ReadView(old_store,old_entry['archive_prefix']);assert original['source']==q['original_source']
    assert q['original_archive_sha256']==old_store.record['sha256'];assert generated(old,build)==q['complete_generated_sources'] and compare(old,build)==q['all_compiled'];inventory=json.loads((old/'BUILD.json').read_text())['inputs']
   actual_inputs={name[len(role['profile'])+len('/input/'):]:SHA(store.get(name)) for name in store.names if name.startswith(role['profile']+'/input/')};assert actual_inputs==inventory==meta['inputs']
   results.append(dict(kind=role['kind'],optimization=opt,profile=role['profile'],actual_compiler_producer=producer,actual_BUILD_sha256=q['actual_BUILD_sha256'],whole_generated_sources=len(q['complete_generated_sources']),whole_compiled_files=len(q['all_compiled']['files'])));print('CENTRAL_INTEGRATED_WHOLE_COMPILED_POSTIMAGE_PASS',role['profile'],flush=True)
  assert len(results)==56
 return dict(status='ALL56_INTEGRATED_WINDOWS_SOURCE_INPUTS_WHOLE_GENERATED_COMPILED_AND_ACTUAL_SOURCE_CAPSULES_CENTRAL_INDEPENDENT_PASS_NO_MODEL_PERIODS',source_captures=actual_captures,contexts=results,raw_sha256=record['sha256'],compiler_executions=0,model_executions=0,archive_members_extracted=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read()
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'])
