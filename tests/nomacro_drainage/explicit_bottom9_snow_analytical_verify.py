"""Bounded actual analytical Snow source/native owner inheriting canonical336."""
import json
import zipfile
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_analytical_source import ROOT,CORE,git
from explicit_bottom9_snow_analytical_source_custody import source,inherited_evidence
from explicit_bottom9_snow_analytical_central_science import audit
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='725d36dd5987b087196f19aefa48d582ab0b03a3'
PARENT_ADMISSION_SHA='17dcad37654df46729760492a4943b4fce04dd6632b3def511cde59eab430831'
RAW_NAMES=('EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_SHORT_NATIVE_DISCOVERY_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_FIRST4D_WINDOWS_NATIVE_AND_STOCK_REFUSAL_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_FIRST4D_UBUNTU_O0_ORIGINAL_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_FIRST4D_UBUNTU_O2_ORIGINAL_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_TTUTIL_REFERENCE_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_WINDOWS_POSITIVE505_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_UBUNTU_O0_ORIGINAL_V2','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_UBUNTU_O2_ORIGINAL_V2','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_NO_VAPOR_PROTOTYPES535_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_GUARD_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_GUARD_UBUNTU_O0_ORIGINAL_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_GUARD_UBUNTU_O2_ORIGINAL_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_INPUTS_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_PREFLIGHT_INPUTS_V1')


def frozen(name):
 path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show',SEALED+':'+path),'Changed scientific declaration '+name;return json.loads(raw)


def parent_admission():
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_SNOW_HISTORY_ADMISSION_RAW_V1',stack);assert store.record['sha256']==PARENT_ADMISSION_SHA and store.record['canonical_admission']
  for member in store.names:store.get(member)
  label='EXPLICIT_BOTTOM9_SNOW_HISTORY_TEXT_FIX_ACTUAL_CANONICAL_PUBLIC_V1';receipt=json.loads(store.get(label+'.json'));old=json.loads(store.get(label+'.stdout.txt'))
  assert receipt['before']==receipt['after'] and receipt['before']['head']==CORE and receipt['returncode']==0 and not store.get(label+'.stderr.txt') and len(receipt['before']['sparse'])==14 and len(receipt['before']['original_project_files'])==56
  label='EXPLICIT_BOTTOM9_SNOW_HISTORY_TEXT_FIX_ACTUAL_CANONICAL_PUBLICATION_V1';scope=json.loads(store.get(label+'.json'));assert scope['before']==scope['after'] and scope['before']['head']==CORE and scope['returncode']==0 and b'PUBLICATION_REPLAY_SELECTED=false' in store.get(label+'.stdout.txt')
  stats=old['coadmission'];assert stats['contexts']==336 and stats['native_calendar_samples']==2358 and stats['exact_cold_windows']==1012 and stats['compiled_initialization_postimages']==279
 receipt=frozen('EXPLICIT_BOTTOM9_SNOW_HISTORY_MERGE_RECEIPT_V1');assert receipt['actual_merge']==CORE and receipt['canonical_admission'] and receipt['admission_archive_sha256']==PARENT_ADMISSION_SHA
 assert git('rev-parse',CORE+'^{tree}').decode().strip()==receipt['whole_qualified_tree'] and git('show','-s','--format=%P',CORE).decode().split()==receipt['ordered_parents']
 return receipt,old


def raw_custody():
 rows=[]
 with ExitStack() as stack:
  for name in RAW_NAMES:
   declaration=frozen(name)
   if 'parts' in declaration:
    store=Archive(PROOF,name,stack);assert store.record==declaration
    for member in store.names:store.get(member)
    count=len(store.names)
   else:
    # Original discovery/input declarations are single ZIP inventories.
    # Read that recorded schema directly; never rewrite their metadata.
    assert name in ('EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_SHORT_NATIVE_DISCOVERY_RAW_V1','EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_INPUTS_V1')
    assert declaration['archive']==name+'.zip'
    path=PROOF/declaration['archive'];assert path.stat().st_size==declaration['bytes'] and SHA(path.read_bytes())==declaration['sha256']
    z=stack.enter_context(zipfile.ZipFile(path));members=declaration['members'];assert len(z.namelist())==len(set(z.namelist()))==len(members) and set(z.namelist())==set(members)
    for member,item in members.items():
     raw=z.read(member);assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
    count=len(members)
   rows.append(dict(archive=name,bytes=declaration['bytes'],sha256=declaration['sha256'],members=count))
 return rows


def guard_previous_source():
 source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):
 from explicit_bottom9_snow_history_verify import strip_current_evidence as inherited
 return inherited(text)


def publication_dependencies_unchanged():
 guard_previous_source();return True


def verify():
 current=source(SEALED);inherited=inherited_evidence();parent,previous=parent_admission();raw=raw_custody();science={};guards={};legacy={}
 for platform in ('Windows','Ubuntu'):
  for opt in ('O0','O2'):
   label='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_'+platform.upper()+'_'+opt+'_CENTRAL_WITH_NATIVE_CONTROLS_V2';declared=frozen(label);actual=audit(platform,opt);assert actual==declared;science[label]=actual
   label='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_GUARD_'+platform.upper()+'_'+opt+'_CENTRAL_INDEPENDENT_V1';declared=frozen(label);actual=audit(platform,opt,guard_mode=True);assert actual==declared;guards[label]=actual
 for opt in ('O0','O2'):
  label='EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_MODEL1_'+opt+'_CENTRAL_INDEPENDENT_V1';declared=frozen(label);actual=audit('Windows',opt,legacy_mode=True);assert actual==declared;legacy[label]=actual
 hard=frozen('EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CURRENT_HARD_DOMAINS_V1');assert len(hard['checks'])==16 and sum(item['frontend_accepted'] for item in hard['checks'])==6 and hard['compiler_executions']==hard['model_executions']==0
 contexts=[item for record in science.values() for item in record['contexts']];current_guard=[item for record in guards.values() for item in record['contexts']]
 assert len(contexts)==len(current_guard)==24 and all(item['actual_days']==35 and item['actual_native_checkpoints']==7 and item['actual_exact_cold_windows']==3 and item['absolute_water_limit_cm']=='1e-10' for item in contexts)
 assert sum(item['compiled_model_native_controls']['actual_compiled_refusals'] for item in contexts)==408 and sum(item['compiled_root_native_controls']['actual_compiled_refusals'] for item in contexts if item['compiled_root_native_controls'])==200
 assert sum(item['actual_external_transactions'] is not None for item in contexts)==8 and sum(item['foreign_active_vapor_refusal'] is not None for item in current_guard)==8 and sum(len(record['contexts']) for record in legacy.values())==8
 return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_SNOW_PARENT336_NEW24_NATIVE_NO_VAPOR_CURRENT_COMPILED_COLD_AND_ORIGINAL_CONSTITUTIVE_PASS',actual_current_source=current,fresh_parent336_evidence=inherited,parent_actual_admission=parent,inherited336_original_science=previous,new24_original_science=science,actual_current_native_precondition_bridges=guards,unchanged_model1_source_compiled_preservation=legacy,actual_new_raw_custody=raw,actual_hard_domain_controls=hard,scientific_reuse='ORIGINAL_FULL35_PRODUCERS_6A_4D_505_RETAINED_CURRENT_535_134_GUARD_CODE_REAL_FRESH_NATIVE_ORIGINS_ALL_UNAFFECTED_KERNEL_OBJECTS_EXACT_NO_CHECKPOINT_REBIND_OR_FULL_PERIOD_REPLAY',coadmission=dict(contexts=360,short35_contexts=358,year367_contexts=2,new_analytical_snow_contexts=24,native_calendar_samples=2526,exact_cold_windows=1084,compiled_initialization_postimages=303,new_current_native_guard_warm_days=96,new_current_native_guard_cold_windows=24,new_current_native_guard_cold_accepted_days=72,new_current_model1_compiled_preservation_postimages=8,previous_canonical=CORE),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
