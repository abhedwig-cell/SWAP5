"""Replay actual CDE9 archive state through unchanged independent scientific readers."""
import argparse,hashlib,io,json,tarfile,types,zipfile
from pathlib import Path
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_archive_science import ReadView,Reference,source
from explicit_bottom9_last_node_central import built
from explicit_bottom9_cde_calendar_science import audit
from explicit_bottom9_source_inverse import ROOT,CDE_CORE,complete_inverse,git


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
 p=argparse.ArgumentParser();p.add_argument('--proof',type=Path,default=ROOT/'integration/f-ci/nomacro-complete01');p.add_argument('--output',type=Path,required=True);a=p.parse_args();result=windows(a.proof)
 with a.output.open('x') as out:json.dump(result,out,indent=2);out.write('\n')
 print(result['status'],flush=True)
