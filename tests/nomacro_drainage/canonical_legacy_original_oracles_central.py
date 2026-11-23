"""Fresh exact raw Source, original component stdout and O0/O2 comparisons."""
import argparse,hashlib,json
from pathlib import Path,PureWindowsPath
from contextlib import ExitStack
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_source_inverse import ROOT,git

def read():
 proof=ROOT/'integration/f-ci/nomacro-complete01';results=[]
 with ExitStack() as stack:
  store=Archive(proof,'CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1',stack);record=store.record;assert len(record['builds'])==4 and record['SWAP_model_periods']==0
  for name in store.names:store.get(name)
  epochs=json.loads(store.get('ACTUAL_SOURCE_EPOCHS_V1.json'))
  for producer,rows in epochs.items():
   for path,item in rows.items():
    actual=store.get('actual-working-source/raw/'+item['actual_raw_sha256']);blob=store.get('committed-source/blobs/'+item['git_blob']);assert SHA(actual)==item['actual_raw_sha256'] and hashlib.sha1(b'blob '+str(len(blob)).encode()+b'\0'+blob).hexdigest()==item['git_blob'] and actual.replace(b'\r\n',b'\n')==blob and git('rev-parse',producer+':'+path).decode().strip()==item['git_blob']
  def original_file(path):
   relative=PureWindowsPath(path).relative_to(PureWindowsPath(record['original_evidence_root'])).as_posix();return store.get('profiles/'+relative)
  for kind,expected_compilers in [('WOF43A',36),('FSI35',70)]:
   name='CANONICAL_LEGACY_'+kind+'_CURRENT_ORIGINAL_ORACLES_V1.json';q=json.loads(store.get('observations/'+name));events=q['events'];compiled=[e for e in events if e['command'][0]=='gfortran'];native=[e for e in events if e['command'][0]!='gfortran'];assert len(compiled)==expected_compilers and len(native)==6 and all(e['returncode']==0 for e in events)
   inventory=q.get('source_inventory',q.get('actual_source_inventory'));assert inventory==epochs[q['actual_source']]
   observed={}
   for event in events:
    stdout=original_file(event['stdout']);stderr=original_file(event['stderr']);assert event['seconds']>=0
    if event in native:
     assert not stderr and stdout;opt=PureWindowsPath(event['stdout']).parent.name;observed[(opt,event['label'])]=stdout
   for label in {key[1] for key in observed}:assert observed[('O0',label)]==observed[('O2',label)]
   if kind=='WOF43A':
    required={
     'test_fwof43a_crop_et_canopy_view_provider-execute':[b'FWO43A_CROP_ET_CANOPY_VIEW_TEST PASS'],
     'test_fvq37_crop_et_canopy_view_independent-execute':[b'FVQ37_INDEPENDENT_GRID_CASES=29000',b'FVQ37_INDEPENDENT_EDGE_CASES=13',b'FVQ37_INDEPENDENT_CROP_ET_CANOPY_QUALIFICATION PASS'],
     'co2-execute':[b'SW431_CROP_CO2_RESPONSE=PASS']}
    assert q['compiler_driver_executions']==38 # retained original nominal error
   else:
    for item in q['immutable_original_inputs']:
     expected=git('show',item['ref']+':'+item['path']);assert len(expected)==item['original_bytes'] and SHA(expected)==item['original_sha256'];actual=original_file(item['materialized'])
     if PureWindowsPath(item['materialized']).name=='fkt15_stubs.f90':
      needle=b'module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n';assert expected.count(needle)==1 and actual==expected.replace(needle,needle+b'  integer :: swsophy = 0\n',1) and SHA(actual)==q['actual_stub_interface_sha256']
     else:assert actual==expected,'Changed original immutable FSI oracle input'
    helper='tests/support/augment_bartholomeus_backend_sources.py';original_helper=git('show','d8414c1ba11bee9f061622fd2495f631a57d2383:'+helper);assert SHA(original_helper)==q['actual_original_compile_helper_sha256']
    original_input=PureWindowsPath(q['immutable_original_inputs'][0]['materialized']).parent/'original-immutable-compile-helper.py';assert original_file(str(original_input))==original_helper
    required={'task2-execute':[b'FKT15_ACCEPTED_TYPED_ROUTE=PASS',b'FKT15_ACCEPTED_SENSITIVITY=PASS',b'FKT15_EIGHT_WORKER_CAPSULE_ISOLATION=PASS',b'FKT15_RETRY_FAIL_CLOSED=PASS',b'FKT15_PRODUCTION_TASK2_GATE=PASS'],'surface-execute':[b'FKT15_PRODUCTION_SURFACE_FLUX=PASS',b'FKT15_PRODUCTION_ATMOSPHERIC_HEAD=PASS',b'FKT15_PRODUCTION_PONDED_HEAD=PASS',b'FKT15_PRODUCTION_SURFACE_HARD_MASS=PASS',b'FKT15_PRODUCTION_SURFACE_REGIMES_GATE=PASS'],'dispatch-execute':[b'FSI35_STANDALONE_WORKER_TASK2_EQUIVALENCE=PASS',b'FSI35_STANDALONE_USES_COMMON_SOLVER_SERVICE=PASS']}
   for label,markers in required.items():assert all(value in observed[('O0',label)] for value in markers)
   for role in [r for r in record['builds'] if r['kind']==kind]:
    assert role['actual_compiler_producer']==q['actual_source'];prefix=role['archive_prefix']+'/';files=[n for n in store.names if n.startswith(prefix)];assert files and any(n.endswith('.exe') for n in files) and any(n.endswith('.mod') for n in files)
   results.append(dict(kind=kind,actual_producer=q['actual_source'],actual_compiler_executions=expected_compilers,actual_native_component_executions=6,exact_O0_O2_output_pairs=3,all_original_native_markers_verified=True))
  ci=[]
  for kind,run,head,log,markers in [('WOF43A',45225306180,'ace63eadadbbe40d47c731540250927e5835498d','CANONICAL_LEGACY_WOF43A_UBUNTU_FULL_JOB137870071632_V1.log',[b'FCI51P_SUCCESSOR_O0_O2_PRESERVATION=PASS',b'FCI51P_R3_MOVING_CURRENT_CANONICAL_PRESERVATION=PASS',b'SW431_CROP_CO2_O0_O2_IDENTITY=PASS']),('FSI35',45229329739,'b62b37600da90f93551aa9b384d3d32f0e4d72f6','CANONICAL_LEGACY_FSI35_UBUNTU_SUCCESS_JOB137884265788_V1.log',[b'FCI93_FIXED_K_NATIVE_IMMUTABLE_ORACLE_O0_O2=PASS',b'FCI93_FSI35_CURRENT_SEMANTIC_REPLAY=PASS'])]:
   api=json.loads(store.get('observations/CANONICAL_LEGACY_'+kind+'_TERMINAL_API_V1.json'));matches=[x for x in api['workflow_runs'] if x['id']==run];assert len(matches)==1 and matches[0]['head_sha']==head and matches[0]['status']=='completed' and matches[0]['conclusion']=='success';raw=store.get('observations/'+log);assert head.encode() in raw and all(marker in raw for marker in markers);ci.append(dict(kind=kind,actual_run=run,actual_head=head,full_original_log_sha256=SHA(raw),conclusion='success'))
 return dict(status='ALL4_COMPILED_LEGACY_CLOSURES_SOURCE_ORIGINAL_IMMUTABLE_INPUTS_12_NATIVE_ORACLES_AND_TWO_EXACT_UBUNTU_NATIVE_WORKFLOWS_CENTRAL_INDEPENDENT_PASS',raw_sha256=record['sha256'],contexts=results,exact_original_Ubuntu_workflows=ci,actual_original_compilers=106,actual_original_native_components=12,compiler_executions=0,model_executions=0,archive_members_extracted=0,global_DATAQUAL12_qualification_claimed=False,canonical_admission=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=read()
 with a.output.open('x') as f:json.dump(q,f,indent=2)
 print(q['status'])
