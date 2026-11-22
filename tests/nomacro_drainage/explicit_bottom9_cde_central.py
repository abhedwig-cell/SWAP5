"""Replay actual CDE9 archive state through unchanged independent scientific readers."""
import argparse,hashlib,io,json,tarfile,types,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView,Reference,source
from explicit_bottom9_last_node_central import built
from explicit_bottom9_cde_calendar_science import audit
from explicit_bottom9_source_inverse import ROOT,CDE_CORE,CDE_POLICY_CORE,complete_inverse,git


MONTHLY_PRODUCER='fc9732bd6fc02b505d6439d660cadc5cb7c126d7'
MONTHLY_SPECS={'O0':(14741696269,11596326,'0c0589cf434b903cfd6d4ecde40345e872cd13f6de83d6e12b33cc25811892ee'),
 'O2':(14741069671,11637272,'a04e96b0e7367d51ba7a4f68d3205cb52ed51ea202cf4c13fb85b3b844996c33')}


def seal_monthly(proof,opt):
 artifact,size,digest=MONTHLY_SPECS[opt];name='EXPLICIT_BOTTOM9_CDE_UBUNTU_MONTHLY_'+opt+'_RAW_V1';path=proof/(name+'.zip')
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest
 with zipfile.ZipFile(path) as z:
  assert len(z.namelist())==len(set(z.namelist()))==885
  members={n:dict(bytes=len(z.read(n)),sha256=SHA(z.read(n))) for n in z.namelist()}
 record=dict(status='ACTUAL_COMPLETE_CDE9_MONTHLY_MODEL_AND_COMPILED_COUNTERPART_RAW_PRESERVED_WITH_FAILED_SYNTHETIC_ZERO_PROFILE_OBSERVER',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,actual_artifact=artifact,actual_run=44990472976,actual_producer=MONTHLY_PRODUCER,optimization=opt,actual_CI_conclusion='failure',actual_failure='New independent observer incorrectly required interior pressure exactly zero; raw actual pressure roundoff1.64e-15. Model35/native7/cold3/wholecompiled completed.',new_short35_contexts=1,new_native_checkpoints=7,new_exact_cold_windows=3,model_replay_for_observer_repair=False,canonical_admission=False)
 p=proof/(name+'.json')
 if p.exists():assert json.loads(p.read_text())==record
 else:p.write_text(json.dumps(record,indent=2)+'\n')


def monthly(proof,opt):
 complete_inverse()
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_CDE_UBUNTU_MONTHLY_'+opt+'_RAW_V1',stack)
  assert (store.record['actual_artifact'],store.record['bytes'],store.record['sha256'])==MONTHLY_SPECS[opt]
  original,provenance=source(store,stack,MONTHLY_PRODUCER,CDE_POLICY_CORE);reference=Reference(store,original)
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));label='explicit-bottom9-cde-monthly-'+opt+'-short';profile=ReadView(store,label);post=ReadView(store,label+'-initial2-postimage')
  q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());assert q['source']==p['source']==MONTHLY_PRODUCER
  assert q['input_root']=='/home/runner/work/_temp/proof/inputs/cde-monthly-initial1' and p['input_root']=='/home/runner/work/_temp/proof/inputs/cde-monthly-initial2' and p['initial1_profile']=='/home/runner/work/_temp/proof/'+label
  loc=dict(inputs=ReadView(store,'inputs/cde-monthly-initial1'),counter_inputs=ReadView(store,'inputs/cde-monthly-initial2'),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=p['initial1_profile'])
  result=audit(profile,reference,post,loc)
 return dict(status='ACTUAL_COMPLETED_UBUNTU_CDE9_MONTHLY_ARCHIVE_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_PASS_WITHOUT_MODEL_REPLAY',optimization=opt,source=provenance,science=result,original_CI_failure_preserved=True,incorrect_observer_zero_profile_replaced_by_original_all_node_Darcy_mass_guard=True,mass_or_convergence_limits_changed=False,compiler_executions=0,model_executions=0,canonical_admission=False)


DRAIN_PRODUCER='27d68c0efa06512e02a4548fa7869419a6f0ae89'
DRAIN_SPECS={'O0':(14742116012,11705234,'bbbb31afa6cb600a78be89175f34738bc37f8d2993b42ffbdff6adee10af59d1'),
 'O2':(14741797576,11743495,'cf06bf8238d3ed729320f2fc5d8a1ef7dfcbf045014d7a54c03d50a628324fca')}


def seal_drain(proof,opt):
 artifact,size,digest=DRAIN_SPECS[opt];name='EXPLICIT_BOTTOM9_CDE_UBUNTU_DRAIN_'+opt+'_RAW_V1';path=proof/(name+'.zip')
 assert path.stat().st_size==size and SHA(path.read_bytes())==digest
 with zipfile.ZipFile(path) as z:
  assert len(z.namelist())==len(set(z.namelist()))
  members={n:dict(bytes=len(z.read(n)),sha256=SHA(z.read(n))) for n in z.namelist()}
 record=dict(status='ACTUAL_NEW_CDE9_DISTRIBUTED_SUBDAILY_UBUNTU_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_RAW_PRESERVED_NOT_ADMITTED',archive=path.name,bytes=size,sha256=digest,parts=[dict(file=path.name,bytes=size,sha256=digest)],members=members,actual_artifact=artifact,actual_run=44990955100,actual_producer=DRAIN_PRODUCER,optimization=opt,new_short35_contexts=1,new_native_checkpoints=7,new_exact_cold_windows=3,new_compiled_counterparts=1,completed_monthly_model_periods_replayed=False,canonical_admission=False)
 p=proof/(name+'.json')
 if p.exists():assert json.loads(p.read_text())==record
 else:p.write_text(json.dumps(record,indent=2)+'\n')


def drain(proof,opt):
 complete_inverse()
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_CDE_UBUNTU_DRAIN_'+opt+'_RAW_V1',stack)
  assert (store.record['actual_artifact'],store.record['bytes'],store.record['sha256'])==DRAIN_SPECS[opt]
  original,provenance=source(store,stack,DRAIN_PRODUCER,CDE_POLICY_CORE);reference=Reference(store,original)
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));label='explicit-bottom9-cde-distributed-subdaily-'+opt+'-short';profile=ReadView(store,label);post=ReadView(store,label+'-initial1-counterpart')
  q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text());assert q['source']==p['source']==DRAIN_PRODUCER
  assert q['input_root']=='/home/runner/work/_temp/proof/inputs/cde-distributed-subdaily-initial2' and p['input_root']=='/home/runner/work/_temp/proof/inputs/cde-distributed-subdaily-initial1' and p['reference_profile']=='/home/runner/work/_temp/proof/'+label
  loc=dict(inputs=ReadView(store,'inputs/cde-distributed-subdaily-initial2'),counter_inputs=ReadView(store,'inputs/cde-distributed-subdaily-initial1'),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=p['reference_profile'])
  result=audit(profile,reference,post,loc);assert result==json.loads(store.get(label+'-INDEPENDENT.json'))
 return dict(status='ACTUAL_NEW_UBUNTU_CDE9_DISTRIBUTED_SUBDAILY_CENTRAL_ARCHIVE_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_PASS_NOT_ADMITTED',optimization=opt,source=provenance,science=result,actual_CI_and_central_scientific_observations_equal=True,compiler_executions=0,model_executions=0,canonical_admission=False)


def capsule(store,prefix,head,stack,controller):
 q=json.loads(store.get(prefix+'/RESULT.json'));raw=store.get(prefix+'/actual-producer-source.zip')
 assert q['producer_head']==head and len(raw)==q['bytes'] and SHA(raw)==q['sha256'] and not git('diff',CDE_CORE,head,'--','app','src','tools/solute','tools/vq','reference')
 expected={l.split('\t',1)[1]:l.split('\t',1)[0].split()[2] for l in git('ls-tree','-r',head).decode().splitlines()}
 def check(name,value,item):
  assert len(value)==item['bytes'] and SHA(value)==item['sha256'] and item['git_blob']==expected[name]
  obj=lambda v:hashlib.sha1(b'blob '+str(len(v)).encode()+b'\0'+v).hexdigest()
  assert expected[name] in (obj(value),obj(value.replace(b'\r\n',b'\n')))
 z=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)));absent={n for n,i in q['members'].items() if i.get('checkout')=='ABSENT'}
 assert all(n.startswith('reference/swap-4.3.1/') for n in absent) and set(z.namelist())==set(q['members'])-absent
 for name,item in q['members'].items():
  if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
  else:check(name,z.read(name),item)
 c=json.loads(store.get('observations/'+controller+'.json'));raw=store.get('observations/'+controller+'.tar')
 assert c['producer_head']==head and len(raw)==c['bytes'] and SHA(raw)==c['sha256']
 tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)));assert {m.name for m in tar.getmembers()}==set(c['members'])
 for name,item in c['members'].items():check(name,tar.extractfile(name).read(),item)
 return z


def frontend(store):
 import prescribed_head_flux_boundary as boundary
 from original_output_baseline import assignment
 select=types.FunctionType(boundary.selection.__code__,dict(vars(boundary),Path=lambda value:value))
 record=json.loads(store.get('observations/EXPLICIT_BOTTOM9_CDE_CALENDAR_FRONTEND_CONTROLS_V1.json'));assert len(record['controls'])==9 and record['model_executions']==record['compiler_executions']==0
 root='profiles/explicit-bottom9-cde-calendar-frontend-controls-v1/';results=[]
 for item in record['controls']:
  key,value=item['key'],item['value'];assert item['accepted'] is False and item['refusal']
  inputs=ReadView(store,root+key+'-'+str(value));assert select(inputs,True) is None
  results.append(dict(key=key,value=value,actual_frozen_bounded_selection=None,actual_public_refusal=item['refusal'],input_sha256=SHA((inputs/'swap.swp').read_bytes())))
 assert {i['key'] for i in results}=={'SWMACRO','SWKIMPL','SWINCO','SWSOPHY','SWHYST','SWSNOW','SWFROST','SWKMEAN','SWDRA'}
 return results


def windows(proof):
 complete_inverse()
 with ExitStack() as stack:
  store=Archive(proof,'EXPLICIT_BOTTOM9_CDE_WINDOWS_RAW_V1',stack);provider=Archive(proof,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
  originals=[]
  for suffix,head in [('3e0f','3e0f10165ed67422ecfa7a0245d2c2b45a0af793'),('ec409','ec40937ed483b6948eca15f29a6752df638342a1')]:
   cap=capsule(store,'profiles/explicit-bottom9-cde-calendar-actual-source-'+suffix+'-v1',head,stack,'explicit-bottom9-cde-calendar-controller-'+suffix+'-v1');originals.append(cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP'))
  assert originals[0]==originals[1] and SHA(originals[0])=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
  reference=Reference(provider,originals[0]);projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));links=json.loads(store.get('PARENT_CENTRAL_RAW_LINKS_V1.json'))
  for name,item in links.items():
   q=json.loads((proof/(name+'.json')).read_text());assert item==dict(bytes=q['bytes'],sha256=q['sha256'],members=len(q['members']))
  assert len(store.record['roles'])==10 and len(projection)==20;observations=[]
  for role in store.record['roles']:
   profile=ReadView(store,role['profile']);post=ReadView(store,role['postimage']);q=json.loads((profile/'RESULT.json').read_text());p=json.loads((post/'RESULT.json').read_text())
   assert q['source']==role['producer'] and q['case']==role['case'] and q['optimization']==role['optimization']
   loc=dict(inputs=ReadView(store,role['inputs']),counter_inputs=ReadView(store,role['counter_inputs']),build=built(store,projection,q['build_root']),counter=built(store,projection,p['build_root']),original_profile_path=role['original_profile_path'])
   actual=audit(profile,reference,post,loc);assert actual==json.loads(store.get(role['independent']))
   observations.append(actual);print('ACTUAL_CDE9_WINDOWS_CENTRAL_SCIENCE_NATIVE_COLD_WHOLE_COMPILED_PASS',q['case'],q['optimization'],flush=True)
  controls=frontend(store)
 return dict(status='ACTUAL_TEN_NEW_CDE9_WINDOWS_CENTRAL_ARCHIVE_SCIENCE_NATIVE_EOF_COLD_WHOLE_COMPILED_AND_FRONTEND_PASS_NOT_ADMITTED',contexts=observations,frontend=controls,compiler_executions=0,model_executions=0,canonical_admission=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--output',type=Path,required=True);p.add_argument('--monthly',choices=('O0','O2'));p.add_argument('--seal-monthly',action='store_true');p.add_argument('--drain',choices=('O0','O2'));p.add_argument('--seal-drain',action='store_true');a=p.parse_args();assert not (a.drain and a.monthly)
 if a.seal_monthly:assert a.monthly;seal_monthly(a.proof,a.monthly)
 if a.seal_drain:assert a.drain;seal_drain(a.proof,a.drain)
 result=drain(a.proof,a.drain) if a.drain else monthly(a.proof,a.monthly) if a.monthly else windows(a.proof)
 with a.output.open('x') as out:json.dump(result,out,indent=2);out.write('\n')
 print(result['status'],flush=True)
