"""Actual public build postimages for unchanged bottom5 physical branches.

No model is executed and no old compiler/source identity is projected. Compare
freshly emitted whole Fortran files and compiled objects to immutable original
archive member hashes, preserving both actual compiler identities separately.
"""
import argparse,hashlib,json,platform,subprocess,sys,time
from pathlib import Path
from frost_boundary_state_calendar_input_contract import source
from frost_boundary_state_calendar_inputs import prepare
R=Path(__file__).resolve().parents[2];P='integration/f-ci/nomacro-complete01/'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
def main():
 p=argparse.ArgumentParser()
 for k in ('reference-work','build-root','output'):p.add_argument('--'+k,type=Path,required=True)
 p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--case',action='append',default=[]);a=p.parse_args()
 assert platform.system()==('Windows' if a.platform=='Windows' else 'Linux')
 head,c=source();a.output.mkdir(parents=True);q=dict(status='RUNNING_ACTUAL_BOTTOM5_BUILD_POSTIMAGES_NOT_ADMITTED',source=head,platform=a.platform,optimization=a.optimization,contexts=[],model_executions=0)
 save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
 save()
 try:
  selected=[i for i in (0,1,4,5) if not a.case or c['representative_cases'][i]['name'] in a.case]
  assert selected and set(a.case)<={c['representative_cases'][i]['name'] for i in (0,1,4,5)}
  for index in selected:
   case=c['representative_cases'][index];name=case['name'];assert case['bottom']==5
   folder=a.output/name;folder.mkdir();inputs=folder/'inputs';prepare(case,inputs);bundle=a.build_root/name/'bundle'
   cmd=[sys.executable,'-B','tools/solute/run_water.py','--model','HYBRID_NOMACRO_WATER','--experimental-project',str(inputs),'--original-output','--experimental-time-step-policy','original-adaptive-event-closure-v1','--reference-work',str(a.reference_work),'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',str(bundle)]
   started=time.perf_counter()
   with (folder/'builder.stdout').open('xb') as out,(folder/'builder.stderr').open('xb') as err:r=subprocess.run(cmd,cwd=R,stdout=out,stderr=err,timeout=300)
   item=dict(case=name,actual_current_source=head,command=cmd,returncode=r.returncode,seconds=time.perf_counter()-started,model_executions=0);q['contexts'].append(item);save();r.check_returncode()
   host=a.platform.upper();version=1 if index<2 else 2
   original_manifest=f'FROST_BOUNDARY_STATE_CALENDAR04_{host}_{a.optimization}_ORIGINAL_V{version}.json'
   anchor='511d207f7ab9c0d543b5edab7aa7ad649c6896ce' if version==1 else 'bc79f1dd87ec89198a27f5a3b28c3b722d08236c'
   compiled='compiled/'+name+'/bundle/';old_inputs='current/'+name+'/inputs/'
   if a.platform=='Windows' and index==0:
    original_manifest='FROST_BOUNDARY_STATE_CALENDAR04_LOCAL_WINDOWS_O0_O2_RAW_V1.json';compiled='compiled/'+a.optimization+'/'+name+'/bundle/';old_inputs='current/'+a.optimization+'/'+name+'/inputs/'
   raw=subprocess.check_output(['git','show',anchor+':'+P+original_manifest],cwd=R);m=json.loads(raw);old_source=m.get('original_science_source',m.get('actual_compiler_source'));assert old_source
   assert not subprocess.check_output(['git','diff',old_source,head,'--','src','tools','reference','app/hybrid_water/daily_host.py','app/hybrid_water/implicit_frost_root_state.py','app/hybrid_water/donor_sources.py'],cwd=R)
   input_hashes={x.relative_to(inputs).as_posix():SHA(x.read_bytes()) for x in inputs.rglob('*') if x.is_file()}
   assert all(m['members'][old_inputs+x]['sha256']==v for x,v in input_hashes.items())
   meta=json.loads((bundle/'BUILD.json').read_text());generated=meta['identity']['donor_generated'];source_checks={};objects={}
   baseline=json.loads((R/P/'FROST_BOUNDARY_STATE_CALENDAR04_BOTTOM5_PHYSICAL_POSTIMAGE_BASELINES_V1.json').read_text())['records'][host+'/'+a.optimization+'/'+name]
   assert baseline['original_manifest_sha256']==SHA(raw) and baseline['original_archive_sha256']==m['sha256']
   assert set(generated)==set(baseline['generated'])
   for file,digest in generated.items():
    actual=SHA((bundle/file).read_bytes());expected=m['members'][compiled+file]['sha256'];assert actual==digest
    prior=baseline['generated'][file];assert prior['original_raw_sha256']==expected
    current_lf=SHA((bundle/file).read_bytes().replace(b'\r\n',b'\n'))
    source_checks[file]=dict(current_raw_sha256=actual,original_raw_sha256=expected,raw_exact=actual==expected,current_LF_sha256=current_lf,original_LF_sha256=prior['original_LF_sha256'],exact=current_lf==prior['original_LF_sha256'])
    object_file=Path(file).with_suffix('.o').as_posix();current=SHA((bundle/object_file).read_bytes());prior=m['members'][compiled+object_file]['sha256'];objects[object_file]=dict(current_sha256=current,original_sha256=prior,exact=current==prior)
   item.update(original_manifest=original_manifest,original_manifest_git_anchor=anchor,original_manifest_sha256=SHA(raw),original_archive_sha256=m['sha256'],original_source=old_source,original_inputs_exact=True,whole_current_generated_sources=source_checks,whole_current_compiled_objects=objects,actual_BUILD_sha256=SHA((bundle/'BUILD.json').read_bytes()),current_compiler=meta['identity']['compiler'],current_flags=meta['identity']['donor_flags'])
   save();assert all(x['exact'] for x in source_checks.values()),'Actual bottom5 generated source changed'
   assert {k:meta['identity'][k] for k in baseline['compiler']}==baseline['compiler'],'Different actual compiler build; compiled inheritance not established'
   assert all(x['exact'] for x in objects.values()),'Actual bottom5 compiled object changed; inspect original bytes before inheritance'
   assert source()[0]==head
   print('ACTUAL_BOTTOM5_CURRENT_PUBLIC_COMPILED_POSTIMAGE_EXACT',name,a.optimization,len(generated),flush=True)
  q['status']='ACTUAL_SELECTED_BOTTOM5_PHYSICAL_BRANCHES_PUBLIC_GENERATED_AND_COMPILED_POSTIMAGES_EXACT_NO_MODEL_REPLAY_NOT_ADMITTED'
 except Exception as error:q.update(status='FAILED_ACTUAL_BOTTOM5_POSTIMAGE_PRESERVATION_NOT_ADMITTED',error=repr(error));raise
 finally:save()
if __name__=='__main__':main()

