"""Independent integrated ELF/Fortran checks against original Ubuntu periods."""
import argparse,json,zipfile
from pathlib import Path
from contextlib import ExitStack
from explicit_bottom9_combined_postimages import ROOT,SHA,Archive,ReadView,generated,compare,verify
from explicit_bottom9_history_linux_central import Original,source
HEAD='18a43b7b477204addadc02fce685786640c562a9'
IDENTITIES={'O0':(14838894834,30952276,'61528c00dcddfc86ed0f06690252378655ec253eeeb2ada716d77f856eeae9cb'),'O2':(14839673147,31305090,'380e33de694fe3d2089ed39e0082419d15af23ccefa1144cfc367fdc77253987')}

def read(path,opt):
 verify();artifact,size,digest=IDENTITIES[opt];assert path.stat().st_size==size and SHA(path.read_bytes())==digest;results=[];proof=ROOT/'integration/f-ci/nomacro-complete01'
 with ExitStack() as stack:
  z=stack.enter_context(zipfile.ZipFile(path));store=Original(z)
  for name in store.names:store.get(name)
  sources=source(store,HEAD,'.github/workflows/nomacro-explicit-bottom9-combined-postimages.yml');batch=json.loads(store.get('postimages/RESULT.json'));assert batch['actual_source']==HEAD and batch['optimization']==opt and batch['status']=='ALL16_OPT_UBUNTU_INTEGRATED_ANALYTICAL_SNOW_HISTORY_WHOLE_COMPILED_POSTIMAGES_PASS_NO_MODEL_PERIODS' and batch['compiler_executions']==len(batch['contexts'])==16 and batch['model_executions']==0
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));assert len(projection)==16;old_archives={};seen=set()
  for role in batch['contexts']:
   prefix='postimages/'+Path(role['output']).name;q=json.loads(store.get(prefix+'/RESULT.json'));assert q['family']==role['family'] and q['actual_compiler_start_HEAD']==q['actual_compiler_end_HEAD']==HEAD and q['model_executions']==0
   entry=projection[q['build_root']];build=ReadView(store,entry['archive_prefix']);assert SHA((build/'BUILD.json').read_bytes())==q['actual_BUILD_sha256']==entry['actual_BUILD_sha256'];family=role['family'];name='EXPLICIT_BOTTOM9_'+family+'_UBUNTU_'+opt+('_ORIGINAL_V1' if family=='HISTORY' else '_RAW_V1')
   if name not in old_archives:old_archives[name]=Archive(proof,name,stack)
   original=old_archives[name];assert original.record['sha256']==q['original_archive_sha256'];old_role=q['role'];old_profile=old_role['profile'];absolute='/home/runner/work/_temp/proof/'
   if family!='HISTORY':assert old_profile.startswith(absolute);old_profile=old_profile[len(absolute):]
   old_q=json.loads(original.get(old_profile+'/RESULT.json'));assert q['original_source']==old_q['source'] and SHA(original.get(old_profile+'/RESULT.json'))==q['original_profile_RESULT_sha256'];key=(family,old_profile);assert key not in seen;seen.add(key)
   old_entry=json.loads(original.get('COMPILED_PROJECTION_V1.json'))[old_q['build_root']];old=ReadView(original,old_entry['archive_prefix']);assert SHA((old/'BUILD.json').read_bytes())==old_entry['actual_BUILD_sha256'];assert generated(old,build)==q['complete_generated_sources'] and compare(old,build)==q['all_compiled']
   inputs={name[len(prefix+'/input/'):]:SHA(store.get(name)) for name in store.names if name.startswith(prefix+'/input/')};assert inputs==dict(old_q['input_inventory'])==json.loads((build/'BUILD.json').read_text())['inputs']
   results.append(dict(family=family,profile=old_profile,optimization=opt,original_producer=old_q['source'],actual_integrated_compiler_producer=HEAD,whole_generated_sources=len(q['complete_generated_sources']),whole_compiled_files=len(q['all_compiled']['files']),actual_BUILD_sha256=q['actual_BUILD_sha256']));print('CENTRAL_ACTUAL_UBUNTU_INTEGRATED_WHOLE_ELF_AND_FORTRAN_POSTIMAGE_PASS',family,old_profile,opt,flush=True)
  assert len(results)==16 and {family:sum(x['family']==family for x in results) for family in ('HISTORY','SNOW','ANALYTICAL')}==dict(HISTORY=8,SNOW=2,ANALYTICAL=6)
 return dict(status='ALL16_OPT_UBUNTU_INTEGRATED_WHOLE_ELF_FORTRAN_SOURCE_INPUTS_CENTRAL_INDEPENDENT_PASS_NO_MODEL_PERIODS',artifact_id=artifact,archive_sha256=digest,archive_bytes=size,actual_source=HEAD,source_captures=sources,contexts=results,compiler_executions=0,model_executions=0,archive_members_extracted=0,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--archive',type=Path,required=True);p.add_argument('--optimization',choices=IDENTITIES,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read(a.archive,a.optimization)
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'])
