"""Recompute original Windows Snow-history science from preserved central raw."""
import argparse,hashlib,json,types
from contextlib import ExitStack
from pathlib import Path,PureWindowsPath
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_history_source_v2 import ROOT,git
from explicit_bottom9_snow_history_science_v2 import audit as calendar_audit,native_controls
from explicit_bottom9_snow_history_science import audit as daily_audit
from explicit_bottom9_compiled_postimage import compare
from explicit_bottom9_combined_postimages import generated
from explicit_bottom9_analytical_parent_postimages import role as prior_role
from explicit_bottom9_archive_science import ReadView
from explicit_bottom9_analytical_central import capsule


def read(scratch):
 scratch=Path(scratch);assert scratch.is_dir() and not any(scratch.iterdir());proof=ROOT/'integration/f-ci/nomacro-complete01';results=[];native=[];prior_results=[]
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_SNOW_HISTORY_WINDOWS_RAW_V1',stack);record=store.record;assert record['contexts']==28 and record['prior_compiler_preservation_postimages']==12
  for name in store.names:
   path=scratch/name;assert path.resolve().is_relative_to(scratch.resolve());path.parent.mkdir(parents=True,exist_ok=True)
   with path.open('xb') as f:f.write(store.get(name))
  index=json.loads(store.get('COMMITTED_SOURCE_INDEX_V1.json'));assert index['working_source_capture_claimed'] is False
  for head,entries in index['epochs'].items():
   expected={line.split('\t')[1]:dict(mode=line.split('\t')[0].split()[0],git_blob=line.split('\t')[0].split()[2]) for line in git('ls-tree','-r',head,'--',*index['scope']).decode().splitlines()};assert entries==expected
   for item in entries.values():
    raw=store.get('committed-source/blobs/'+item['git_blob']);assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==item['git_blob']
  producer='6154891091824c9f0f64c9fff299ad320ccd9479'
  check=types.FunctionType(capsule.__code__,dict(capsule.__globals__,ANALYTICAL_CORE=producer))
  actual_source=check(store,'profiles/explicit-bottom9-snow-history-actual-source-615-v1',producer,stack,'observations/explicit-bottom9-snow-history-controller-615-v1')
  assert SHA(actual_source.read('reference/swap-4.3.1/source-archives/SWAP.ZIP'))=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
  prepared=json.loads(store.get('provider-PREPARED.json'))
  for name,digest in prepared['provider_files'].items():
   if name.startswith('build/'):assert SHA(store.get('original-provider-build/'+name[len('build/'):]))==digest
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'))
  def built(value):
   item=projection[value];path=scratch/item['archive_prefix'];assert SHA((path/'BUILD.json').read_bytes())==item['actual_BUILD_sha256'];return path
  def locate(value):
   path=PureWindowsPath(value);prefix=PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600/evidence');relative=path.relative_to(prefix);return scratch/'profiles'/Path(*relative.parts)
  def science(value):return scratch/'observations'/PureWindowsPath(value).name if PureWindowsPath(value).parent==PureWindowsPath('C:/Users/Veldh012/SWAP5-work/01a1e8b4-228b-75f1-8ac4-b07ca1e15713-a9ded600/evidence') else locate(value)
  for entry in record['batches']:
   batch=json.loads(store.get(entry['path']));assert len(batch['contexts'])==14 and batch['status']=='ALL14_SNOW_HISTORY_CALENDAR_CONTEXTS_INDEPENDENT_NATIVE_COLD_AND_INITIAL2_PASS_NOT_ADMITTED' and batch['source']==batch['actual_completion_head']=='6154891091824c9f0f64c9fff299ad320ccd9479'
   for role in batch['contexts']:
    profile=locate(role['profile']);post=locate(role['current_initial2_postimage']);q=json.loads((profile/'RESULT.json').read_text());c=json.loads((post/'RESULT.json').read_text());first,second=built(q['build_root']),built(c['build_root']);inputs=locate(q['input_root']);counter=locate(c['input_root'])
    assert c['source']==c['actual_compiler_start_HEAD']==c['actual_compiler_end_HEAD']==batch['source'] and c['initial1_source']==q['source']==role['profile_producer']
    assert c['profile']==role['profile'] and c['profile_RESULT_sha256']==SHA((profile/'RESULT.json').read_bytes()) and c['model_executions']==0
    assert SHA((first/'BUILD.json').read_bytes())==c['actual_initial1_BUILD_sha256'] and SHA((second/'BUILD.json').read_bytes())==c['actual_initial2_BUILD_sha256']
    assert {x.relative_to(counter).as_posix():SHA(x.read_bytes()) for x in counter.rglob('*') if x.is_file()}==c['input_inventory']
    for row in c['generated_sources']:
     left=(first/row['file']).read_bytes();right=(second/row['file']).read_bytes();assert SHA(left)==row['actual_initial1_sha256'] and SHA(right)==row['actual_initial2_sha256'] and left.replace(b'\r\n',b'\n')==right.replace(b'\r\n',b'\n')
    assert compare(first,second)==c['compiled'];function=daily_audit if q['status']=='ACTUAL_EXPLICIT9_SNOW_HISTORY_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS_NOT_ADMITTED' else calendar_audit
    actual=function(profile,dict(inputs=inputs,build=first));assert actual==json.loads(science(role['independent']).read_text()) and SHA(science(role['independent']).read_bytes())==role['independent_sha256']
    if role['native_controls']:
     observed=native_controls(locate(role['native_controls']),profile,dict(inputs=inputs,build=first));expected=locate(role['current_initial2_postimage']).parent/(role['label']+'-'+batch['optimization']+'-NATIVE-INDEPENDENT.json');assert observed==json.loads(expected.read_text());native.append(observed)
    if role['transactions']:
     t=json.loads((locate(role['transactions'])/'RESULT.json').read_text());assert t['status']=='ACTUAL_SNOW_HISTORY_CALENDAR_EXTERNAL_DISCARD_REPLAY_ACCEPT_RECOVER_PASS' and t['actual_compiler_producer']==q['source'] and t['actual_control_source']==batch['source'] and t['actual_BUILD_sha256']==SHA((first/'BUILD.json').read_bytes()) and t['transactions']==dict.fromkeys(('discard_no_day_advance','replay_exact','accept_exact','recovered_next_day_exact','origin_unchanged'),True)
    results.append(actual);print('CENTRAL_WINDOWS_ORIGINAL_SNOW_HISTORY_ALL_NODE_NATIVE_COLD_AND_CURRENT_COMPILED_PASS',role['label'],batch['optimization'],flush=True)
  parents={}
  for entry in record['prior']:
   cohort=json.loads(store.get(entry['path']));assert len(cohort['contexts'])==6 and cohort['compiler_executions']==6 and cohort['model_executions']==0;opt=entry['optimization']
   for role in cohort['contexts']:
    rel=PureWindowsPath(role['output']).name;q=json.loads(store.get(str(Path(entry['path']).parent/rel/'RESULT.json').replace('\\','/')));build=built(q['build_root']);family=q['family'];old_role=q['role']
    if family=='PRIOR':
     case=next(x for x in ('age-pressure-step','water-last-node-drainage') if x in PureWindowsPath(q['input_root']).parent.name);_,_,_,_,old=prior_role(proof,case,opt,stack)
    else:
     if family not in parents:parents[family]=Archive(proof,'EXPLICIT_BOTTOM9_'+family+'_WINDOWS_RAW_V1',stack)
     old_store=parents[family];original=json.loads(old_store.get(old_role['profile']+'/RESULT.json'));item=json.loads(old_store.get('COMPILED_PROJECTION_V1.json'))[original['build_root']];old=ReadView(old_store,item['archive_prefix']);assert q['original_source']==original['source']
    assert generated(old,build)==q['complete_generated_sources'] and compare(old,build)==q['all_compiled'];prior_results.append(dict(label=role['label'],optimization=opt,actual_compiler_producer=q['actual_compiler_start_HEAD'],actual_BUILD_sha256=SHA((build/'BUILD.json').read_bytes())))
 assert len(results)==28 and len(native)==8 and len(prior_results)==12
 return dict(status='ALL28_ORIGINAL_WINDOWS_SNOW_HISTORY_SCIENCE_NATIVE_COLD_CURRENT_INITIAL2_AND12_PRIOR_WHOLE_COMPILED_POSTIMAGES_CENTRAL_PASS_NOT_ADMITTED',contexts=results,native_controls=native,prior_compiler_preservation=prior_results,raw_sha256=record['sha256'],compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--scratch',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.scratch)
 with a.output.open('x') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'])
