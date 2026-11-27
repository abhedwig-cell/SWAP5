"""Independent original SAVE-field coverage and literal native-byte evidence."""
from pathlib import Path
from contextlib import ExitStack
import argparse,hashlib,json,re,struct,subprocess
from analytical_hydraulic_archives import Archive
from frost_boundary_git_archive import GitArchiveSource
R=Path(__file__).resolve().parents[2]
M='bd9b3b2e74e93fccb8bbcc8b06822efcd740f349'
SHA=lambda b:hashlib.sha256(b).hexdigest()


def audit(revision):
 with ExitStack() as stack:
  store=Archive(GitArchiveSource(R,revision),'ORIGINAL_TILLAGE_POST_EVENT_PRIVATE_STATE_RAW_V2',stack)
  assert store.record['sha256']=='47564e8081cd5afc396416ac4241e16c583376b4ed5876a72b313a66b5f08db7'
  sdk=Archive(GitArchiveSource(R,M),'CLOSED_DEFAULT_CALENDAR_STATE14_ORIGINAL_MIXED_J_SDK_RAW_V5',stack)
  original=sdk.get('original-provider-build/swap-selected/tillage.f90');assert SHA(original)=='731a873e0aa5ac25626a6d392c1668e66e57ee3fdc1d94b3eab127b8e343a486'
  # Read the original declarations independently, rather than trusting the
  # generator's own field lists to prove that it did not omit saved state.
  saved=set()
  for line in original.decode('cp1252').split('   contains')[0].splitlines():
   line=line.split('!')[0]
   if '::' in line and re.search(r'\bsave\b',line,re.I):
    for name in line.split('::',1)[1].split(','):saved.add(name.strip().lower())
  q=json.loads(store.get('observations/closure17-tillage-private-v2/RESULT.json'))
  assert q['status']=='TWO_REAL_ORIGINAL_PRIVATE_TILLAGE_POST_EVENT_COMPONENTS_PASS_PHYSICAL_QUALIFICATION_PENDING'
  assert q['model_executions']==q['model_days']==0 and q['compiler_executions']==4 and q['link_executions']==2 and len(q['contexts'])==2
  producer=q['actual_compiler_source'];gen='app/hybrid_water/original_tillage_checkpoint.py'
  assert subprocess.check_output(['git','show',revision+':'+gen],cwd=R)==subprocess.check_output(['git','show',producer+':'+gen],cwd=R)
  assert subprocess.check_output(['git','diff','--name-status',M,revision,'--','app'],cwd=R).decode().strip()=='A\t'+gen
  results=[]
  for item in q['contexts']:
   opt=item['optimization'];prefix='builds/closure17-tillage-private-'+opt+'-v2/'
   actual=store.get(prefix+'tillage.f90');assert SHA(actual)==item['generated_source_sha256']
   lo=actual.index(b'   ! Explicit post-event checkpoint;');hi=actual.index(b'   public :: hybrid_tillage_write_post_event, hybrid_tillage_read_post_event\r\n')+len(b'   public :: hybrid_tillage_write_post_event, hybrid_tillage_read_post_event\r\n')
   decl=actual[lo:hi];remaining=actual[:lo]+actual[hi:]
   lo=remaining.index(b'   logical function hybrid_tillage_valid');end=b'   end subroutine hybrid_tillage_read_post_event\r\n\r\n';hi=remaining.index(end)+len(end)
   assert remaining[:lo]+remaining[hi:]==original
   state=decl.decode().split('type, public :: hybrid_tillage_post_event_state',1)[1].split('end type',1)[0]
   captured=set()
   for line in state.splitlines():
    if '::' not in line:continue
    for name in line.split('::',1)[1].split(','):captured.add(name.split('=')[0].split('(')[0].strip().lower())
   excluded={'rho_last','sumdwc','sumavail1','sumavail2'}
   assert captured-{'schema'}==saved-excluded and not (captured & excluded)
   for name,digest in item['unchanged_original_objects'].items():assert SHA(sdk.get('original-provider-build/swap-obj/'+name))==digest
   assert len(item['unchanged_original_objects'])==61
   assert SHA(store.get(prefix+'technical-state.exe'))==item['executable_sha256']
   native=store.get(prefix+'state.bin');assert SHA(native)==item['actual_original_native_sha256'] and len(native)==440
   header=struct.unpack_from('<8s64s64s8id',native)
   assert header[:3]==(b'SW5TIL01',SHA(original).encode(),b'a'*64) and header[3:11]==(1,2,2,2,3,2,2,2) and header[11]==2.0
   assert struct.unpack_from('<8i',native,176)==(1,2)*4
   expected=(1.,2.,3.)+(1.,2.)*13;assert struct.unpack_from('<29d',native,208)==expected
   commands=item['commands'];assert len(commands)==13 and all(v['returncode']==0 for v in commands)
   assert sum(v['kind']=='compiler' for v in commands)==2 and sum(v['kind']=='link' for v in commands)==1
   assert sum(v['kind']=='technical_negative_process' for v in commands)==8
   for i,v in enumerate(commands):
    stdout=store.get(prefix+str(i)+'.stdout')
    if v['kind']=='technical_cold_process':assert b'ORIGINAL_PRIVATE_TILLAGE_COLD_STATE_EXACT' in stdout
    elif v['kind']=='technical_negative_process':assert b'ORIGINAL_PRIVATE_TILLAGE_COLD_CORRUPTION_REFUSED_NO_MUTATION' in stdout
    if v['kind']=='link':assert not any(Path(n).name=='swap_main.o' for n in v['command'])
   for name,digest in item['actual_cold_corruption_refusals'].items():assert SHA(store.get(prefix+name+'.bin'))==digest and store.get(prefix+name+'.bin')!=native
   assert not re.search(rb'call\s+DoTillage\s*\(',store.get(prefix+'technical_driver.f90'),re.I)
   results.append(dict(output_optimization=opt,private_fields_captured=len(captured)-1,original_saved_fields=len(saved),source_literal_inverse=True,unchanged_original_SDK_objects=61,genuine_cold_state_bytes=len(native),genuine_cold_corruptions_refused=8,model_days=0))
  return dict(status='ORIGINAL_PRIVATE_TILLAGE_POST_EVENT_SOURCE_AND_NATIVE_COMPONENT_INDEPENDENT_ARCHIVE_PASS',actual_reader=revision,actual_compiler_source=producer,raw_sha256=store.record['sha256'],contexts=results,original_physics_and_existing_APP_unchanged=True,new_component_unselected_by_existing_runtime=True,whole_original_tillage_function_qualified=False,pre_event_state_composition='OPEN',trusted_host_physical_and_input_integrity_binding='OPEN',active_original_scientific_input='MISSING',scientific_input_parameters_invented=False,new_scientific_contexts_admitted=0,model_executions=0,compiler_executions=0,global_functional_completion='PARTIAL',global_scientific_equivalence='NOT_QUALIFIED',global_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--revision',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=audit(a.revision)
 with a.output.open('x',encoding='utf8') as f:json.dump(q,f,indent=2);f.write('\n')
 print(q['status'],len(q['contexts']),flush=True)
