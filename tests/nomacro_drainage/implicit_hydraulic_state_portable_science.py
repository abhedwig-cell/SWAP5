"""Independently inspect the original portable artifacts without rerunning models."""
import argparse,json,subprocess
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from frost_boundary_git_archive import GitArchiveSource
from explicit_bottom9_archive_science import ReadView
from implicit_hydraulic_state_current_science import observe
from implicit_hydraulic_state_local_archive_science import BASE,Original,original_inputs
from implicit_hydraulic_state_portable_source import source,sdk
R=Path(__file__).resolve().parents[2]
PRODUCER='c40ca084d8e5eb638e0b4ac5c471463d9aad01c3'

def audit(data,platform,opt):
 assert platform in ['Ubuntu','Windows'] and opt in ['O0','O2']
 name='IMPLICIT_HYDRAULIC_STATE11_FIRST_'+platform.upper()+'_'+opt+'_ORIGINAL_V1'
 with ExitStack() as stack:
  store=Archive(data,name,stack);root=ReadView(store,'current');cohort=json.loads((root/'RESULT.json').read_text());assert cohort['status']=='FOURTEEN_PORTABLE_ORIGINAL_IMPLICIT_HYDRAULIC_STATE_CONTEXTS_PASS_NOT_ADMITTED' and cohort['actual_producer_source']==PRODUCER and cohort['platform']==platform and cohort['optimization']==opt
  source=GitArchiveSource(R,BASE);originals={n:Original(source,n,stack) for n in ['ORDINARY_IMPLICIT_POND_UBUNTU_FOLLOWUP_O0_RAW_ARCHIVE','FROST_UNDRAINED_STATE08_WINDOWS_O0_ORIGINAL_V1','FROST_ANALYTICAL_BOUNDARY10_SEARCH_WINDOWS_O0_ORIGINAL_V1']}
  actual_source=source(store,platform)
  projection=json.loads(store.get('COMPILED_PROJECTION_V1.json'));contexts=[];controls=[]
  for entry in cohort['contexts']:
   assert entry['returncode']==0 and entry['actual_source']==PRODUCER
   folder=root/entry['name'];q=json.loads((folder/'RESULT.json').read_text());build=projection[q['build_root']];assert build['actual_BUILD_sha256']==q['actual_BUILD_sha256']
   def locate(path):
    if path==q['build_root']:return ReadView(store,build['archive_prefix'])
    assert path==q['input_root'];return folder/'inputs'
   observed=observe(folder,locate);assert observed['actual_producer_source']==PRODUCER;observed['original_input_proof']=original_inputs(folder,locate,observed,originals);observed['actual_original_sdk']=sdk(store,json.loads((locate(q['build_root'])/'BUILD.json').read_text())['identity']);contexts.append(observed)
  for entry in cohort['native_controls']:
   assert entry['returncode']==0
   folder=root/(entry['name']+'-native-controls');q=json.loads((folder/'RESULT.json').read_text());assert q['status']=='ACTUAL_COMPILED_AND_PYTHON_IMPLICIT_HYDRAULIC_NATIVE_REFUSALS_BEFORE_READY_PASS' and q['actual_producer_source']==PRODUCER and q['model_period_replays']==0 and len(q['checks'])==20
   for check in q['checks']:
    assert check['python_refused'] and check['compiled_consumer_refused_before_ready']
    mutant=(folder/check['attack']/'origin/macro.bin').read_bytes();assert SHA(mutant)==check['actual_mutant_sha256']
    stdout=(folder/check['attack']/'original/donor.stdout').read_bytes();stderr=(folder/check['attack']/'original/donor.stderr').read_bytes();assert b'READY' not in stdout and b'ERROR STOP' in stderr
   controls.append(dict(name=entry['name'],actual_BUILD_sha256=q['actual_BUILD_sha256'],checks=20,actual_RESULT_sha256=SHA((folder/'RESULT.json').read_bytes())))
  assert len(contexts)==14 and len(controls)==4 and sum(v['days'] for v in contexts)==490 and sum(len(v['native_samples']) for v in contexts)==98 and sum(len(v['exact_cold_windows']) for v in contexts)==44
  return dict(status='FOURTEEN_ORIGINAL_PORTABLE_HYDRAULIC_CONTEXTS_ORIGINAL_INPUTS_1E10_NATIVE_COLD_TRANSACTIONS_AND80_COMPILED_REFUSALS_INDEPENDENT_PASS',platform=platform,optimization=opt,actual_original_scientific_producer=PRODUCER,actual_source=actual_source,original_artifact_sha256=store.record['sha256'],contexts=contexts,native_controls=controls,primary_days=490,native_samples=98,exact_cold_windows=44,compiled_native_refusals=80,external_transaction_contexts=14,model_executions=0,compiler_executions=0,original_producer_or_path_identity_rewritten=False)

if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--platform',choices=['Ubuntu','Windows'],required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip();q=dict(status='RUNNING',actual_observer_source=head,compiler_executions=0,model_executions=0)
 try:q.update(status='INDEPENDENT_ORIGINAL_PORTABLE_HYDRAULIC_SCIENCE_PASS',audit=audit(GitArchiveSource(R,head),a.platform,a.optimization))
 except Exception as error:q.update(status='FAILED_INDEPENDENT_ORIGINAL_PORTABLE_HYDRAULIC_SCIENCE',error=repr(error));raise
 finally:a.output.write_text(json.dumps(q,indent=2)+'\n')
 print(q['status'],a.platform,a.optimization,flush=True)
