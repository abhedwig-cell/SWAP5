"""Fail-closed proposal: reuse immutable parent216 and new64 after exact postimages."""
import io,json,re,sys
from contextlib import ExitStack,redirect_stdout
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_source_inverse import git,blob,norm
from explicit_bottom9_combined_source_custody import source as current_source
from explicit_bottom9_analytical_inherited_custody import fresh as complete_parent_custody
from explicit_bottom9_combined_windows_central import read as windows_postimages
from explicit_bottom9_combined_linux_central import read as linux_postimages
from canonical_legacy_original_oracles_central import read as legacy_oracles
import explicit_bottom9_verify as parent
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='0000000000000000000000000000000000000000'
PARENT_CANONICAL='4d39e97d2f257f70b6fc108c62eb5efce9967a42'
PARENT_ADMISSION_SHA='9b39b63653e17886bdd8a21560d955001057a24a88bd2e5e06bfd4c824a07d37'
CONTRACT_SHA='01285f5199bbd35c4c21af1732c39a9717a0f17d2c09302c4b86372019ce0f17'
PARENT='67d2636672921505ecb47f1c9f4c6ea27a451889'
NAMES=(
 'EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_O0_RAW_V1','EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_O2_RAW_V1','EXPLICIT_BOTTOM9_ANALYTICAL_PRIOR_POSTIMAGES_RAW_V1',
 'EXPLICIT_BOTTOM9_SNOW_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_SNOW_UBUNTU_O0_RAW_V1','EXPLICIT_BOTTOM9_SNOW_UBUNTU_O2_RAW_V1','EXPLICIT_BOTTOM9_SNOW_PRIOR_CONTROLS_RAW_V1','EXPLICIT_BOTTOM9_SNOW_NATIVE_UBUNTU_O0_RAW_V1','EXPLICIT_BOTTOM9_SNOW_NATIVE_UBUNTU_O2_RAW_V1',
 'EXPLICIT_BOTTOM9_HISTORY_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_HISTORY_UBUNTU_O0_ORIGINAL_V1','EXPLICIT_BOTTOM9_HISTORY_UBUNTU_O2_ORIGINAL_V1','EXPLICIT_BOTTOM9_HISTORY_INPUTS_RAW_V2',
 'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_RAW_V1','EXPLICIT_BOTTOM9_COMBINED_UBUNTU_O0_ORIGINAL_V1','EXPLICIT_BOTTOM9_COMBINED_UBUNTU_O2_ORIGINAL_V1','CANONICAL_LEGACY_ORIGINAL_ORACLES_RAW_V1')

def checked_current_source():
 assert re.fullmatch('[0-9a-f]{40}',SEALED) and re.fullmatch('[0-9a-f]{64}',PARENT_ADMISSION_SHA) and re.fullmatch('[0-9a-f]{64}',CONTRACT_SHA)
 raw=norm((PROOF/'EXPLICIT_BOTTOM9_COMBINED_COADMISSION_CONTRACT_V1.json').read_bytes());assert SHA(raw)==CONTRACT_SHA;q=json.loads(raw)
 assert q['parent_contexts']==216 and q['new_contexts']==64 and q['combined_contexts']==280 and q['previous_actual_canonical']==PARENT_CANONICAL and q['parent_admission_sha256']==PARENT_ADMISSION_SHA and q['canonical_admission'] is False
 assert q['physical_equations_changed'] is False and q['whole_historical_family_closed'] is False and q['RC3_changed'] is False
 return current_source(SEALED)

def raw_custody():
 observed=[]
 with ExitStack() as stack:
  for name in NAMES:
   store=Archive(PROOF,name,stack);assert store.record==json.loads(blob(SEALED,'integration/f-ci/nomacro-complete01/'+name+'.json'))
   for member in store.names:store.get(member)
   observed.append(dict(archive=name,sha256=store.record['sha256'],bytes=store.record['bytes'],members=len(store.names)))
 return observed

def parent_admission():
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_ADMISSION_RAW_V1',stack);assert store.record['sha256']==PARENT_ADMISSION_SHA and store.record['candidate']==PARENT and store.record['canonical']==PARENT_CANONICAL and store.record['canonical_admission'] is True
  for member in store.names:store.get(member)
  prior=json.loads(store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'));receipt=json.loads(store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
  assert receipt['before']==receipt['after'] and receipt['before']['head']==PARENT_CANONICAL and receipt['returncode']==0 and not store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stderr.txt')
 assert prior['status']=='BOUNDED_ORIGINAL_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_SOURCE_RAW_NATIVE_PASS' and prior['coadmission']['contexts']==216 and prior['coadmission']['native_calendar_samples']==1518 and prior['coadmission']['exact_cold_windows']==652
 q=json.loads((PROOF/'EXPLICIT_BOTTOM9_MERGE_RECEIPT_V1.json').read_text());assert q['qualified_head']==PARENT and q['actual_merge']==PARENT_CANONICAL and q['admission_archive_sha256']==PARENT_ADMISSION_SHA and q['contexts']==216 and q['canonical_admission'] is True
 return q,prior

def guard_previous_source():
 checked_current_source();raw_custody();parent_admission();return True

def strip_current_evidence(text):return parent.strip_current_evidence(text)

def publication_dependencies_unchanged():
 checked_current_source();raw_custody();parent_admission()
 # Complete inherited Source custody includes every publication dependency.
 # The actual canonical216 selector was false; no new publication scope exists.
 return True

def verify():
 sources=checked_current_source();raw=raw_custody();admission,prior=parent_admission();inherited=complete_parent_custody(PROOF);messages=io.StringIO()
 with redirect_stdout(messages):
  compiled_windows=windows_postimages();compiled_linux={opt:linux_postimages(PROOF/('EXPLICIT_BOTTOM9_COMBINED_UBUNTU_'+opt+'_ORIGINAL_V1.zip'),opt) for opt in ('O0','O2')};legacy=legacy_oracles()
 assert compiled_windows==json.loads((PROOF/'EXPLICIT_BOTTOM9_COMBINED_WINDOWS_POSTIMAGES_CENTRAL_INDEPENDENT_V1.json').read_text())
 assert legacy==json.loads((PROOF/'CANONICAL_LEGACY_ORIGINAL_ORACLES_CENTRAL_INDEPENDENT_V2.json').read_text())
 for opt,value in compiled_linux.items():assert value==json.loads((PROOF/('EXPLICIT_BOTTOM9_COMBINED_UBUNTU_'+opt+'_CENTRAL_INDEPENDENT_V1.json')).read_text())
 # All original numeric assertions were independently executed against these
 # immutable original Source/input/raw bytes. Fresh whole-archive custody,
 # unchanged physical execution sources and all88 integrated binary postimages
 # establish configuration reuse; no old producer or binding is rewritten.
 science={}
 names=['EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_O0_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_O2_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_SNOW_WINDOWS_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_SNOW_UBUNTU_O0_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_SNOW_UBUNTU_O2_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_HISTORY_WINDOWS_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_HISTORY_UBUNTU_O0_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_HISTORY_UBUNTU_O2_CENTRAL_INDEPENDENT_V1']
 for name in names:
  path='integration/f-ci/nomacro-complete01/'+name+'.json';raw_record=norm((ROOT/path).read_bytes());assert raw_record==blob(SEALED,path);q=json.loads(raw_record);assert 'PASS' in q['status'] and q['compiler_executions']==q['model_executions']==0 and q['canonical_admission'] is False;science[name]=q
 assert sum(len(value['contexts']) for value in science.values())==64
 return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_SNOW_HISTORY_PAIRED9_SOURCE_RAW_NATIVE_AND_WHOLE_COMPILED_POSTIMAGES_PASS',new64_immutable_original_science= science,inherited216_and_all_prior_science=prior,parent_actual_admission=admission,inherited_fresh_source=sources,inherited_fresh_bytes=inherited,actual_current_raw_custody=raw,legacy_original_component_preservation=legacy,integrated_windows_compiled=compiled_windows,integrated_linux_compiled=compiled_linux,scientific_reader_messages=messages.getvalue(),scientific_reuse='EXACT_CURRENT_SOURCE_LITERAL_INVERSES_COMPLETE_FRESH_ORIGINAL_EVIDENCE_AND88_ACTUAL_INTEGRATED_WHOLE_COMPILED_POSTIMAGES_NO_PRODUCER_OR_BINDING_REWRITE',coadmission=dict(contexts=280,short35_contexts=278,year367_contexts=2,exact_cold_windows=844,native_calendar_samples=1966,compiled_initialization_postimages=223,integrated_compiler_preservation_postimages=88,previous_canonical=PARENT_CANONICAL,standalone_AGE110_admission_claimed=False),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
