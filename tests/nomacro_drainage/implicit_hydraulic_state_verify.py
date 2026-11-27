"""Own actual hydraulic source, scientific evidence and inherited824 custody."""
import io,json,zipfile
from pathlib import Path
from analytical_hydraulic_archives import SHA
from frost_boundary_git_archive import GitArchiveSource
from implicit_hydraulic_state_source_custody import ROOT,source,git,BASE,PREFIX
from implicit_hydraulic_state_inherited_custody import inherited_evidence
from implicit_hydraulic_state_parent_admission import parent_admission
from implicit_hydraulic_state_portable_science import audit as portable
from implicit_hydraulic_state_local_archive_science import local
from implicit_hydraulic_state_components_archive_science import components
from implicit_hydraulic_state_postimages_archive_science import audit as object_postimages
import frost_analytical_boundary_verify as previous
SEALED='36c8e0c19afd6e2b4543b332e86f9f8ea0f97288'

def data_source():return GitArchiveSource(ROOT,git('rev-parse','HEAD').decode().strip())
def frozen(name):
 raw=(data_source()/(name+'.json')).read_bytes();assert raw==git('show',SEALED+':'+PREFIX+name+'.json');return json.loads(raw)

def raw_custody():
 data=data_source();observed=[]
 for path in git('ls-tree','-r','--name-only',SEALED,'--',PREFIX).decode().splitlines():
  name=Path(path).name
  if not name.startswith('IMPLICIT_HYDRAULIC_STATE11_') or not name.endswith('.json'):continue
  q=frozen(name[:-5])
  if not isinstance(q,dict) or not {'archive','bytes','sha256'}<=q.keys():continue
  pieces=[]
  for part in q.get('parts',[dict(file=q['archive'],bytes=q['bytes'],sha256=q['sha256'])]):
   raw=(data/part['file']).read_bytes();assert len(raw)==part['bytes'] and SHA(raw)==part['sha256'];pieces.append(raw)
  raw=b''.join(pieces);assert len(raw)==q['bytes'] and SHA(raw)==q['sha256']
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   assert len(z.namelist())==len(set(z.namelist())) and z.testzip() is None
   if isinstance(q.get('members'),dict):
    assert set(z.namelist())==set(q['members'])
    for n,item in q['members'].items():
     value=z.read(n);assert len(value)==item['bytes'] and SHA(value)==item['sha256']
   count=len(z.namelist())
  observed.append(dict(archive=q['archive'],bytes=q['bytes'],sha256=q['sha256'],members=count))
 assert len(observed)>=11
 return observed

def inherited_science(data):
 for platform in ['UBUNTU','WINDOWS']:
  for opt in ['O0','O2']:
   name=f'FROST_ANALYTICAL_BOUNDARY10_COMPOSITE_INDEPENDENT_{platform}_{opt}_V1.json';raw=(data/name).read_bytes();assert raw==git('show',BASE+':'+PREFIX+name);q=json.loads(raw);assert q['actual_observer']=='597033a2109c8377a28e42ac5f947ca5cff78793' and len(q['audit']['contexts'])==16
 receipt=json.loads((data/'FROST_ANALYTICAL_BOUNDARY10_MERGE_RECEIPT_V1.json').read_text());assert receipt['actual_merge']==BASE and receipt['coadmission']['contexts']==824
 return dict(status='ORIGINAL_CANONICAL824_ACCEPTED_SCIENTIFIC_AUTHORITY_AND_CURRENT_NONSELECTED_SOURCE_PRESERVED',actual_qualified_canonical=BASE,scientific_producers_rebound=False,model_periods_replayed=0)

def guard_previous_source():
 source(SEALED);inherited_evidence();parent_admission();inherited_science(data_source());raw_custody();return True
def strip_current_evidence(text):return previous.strip_current_evidence(text)
def publication_dependencies_unchanged():
 guard_previous_source();return True

def verify():
 current=source(SEALED);inherited=inherited_evidence();parent=parent_admission();data=data_source();authority=inherited_science(data);raw=raw_custody();results=[]
 for platform in ['Ubuntu','Windows']:
  for opt in ['O0','O2']:
   actual=portable(data,platform,opt);expected=frozen(f'IMPLICIT_HYDRAULIC_STATE11_INDEPENDENT_{platform.upper()}_{opt}_V3');assert expected['actual_observer_source']=='51b7970d63b4b7549481ce4cbd0e45b5a01380bf' and actual==expected['audit'];results.append(actual)
 actual_local=local(data);expected=frozen('IMPLICIT_HYDRAULIC_STATE11_LOCAL_ARCHIVE_INDEPENDENT_SCIENCE_V3');assert expected['actual_observer_source']=='51b7970d63b4b7549481ce4cbd0e45b5a01380bf' and actual_local==expected['audit']
 assert (sum(v['primary_days'] for v in results),sum(v['native_samples'] for v in results),sum(v['exact_cold_windows'] for v in results),sum(v['compiled_native_refusals'] for v in results),sum(v['external_transaction_contexts'] for v in results))==(1960,392,176,320,56)
 actual_components=components(data);expected_components=frozen('IMPLICIT_HYDRAULIC_STATE11_COMPONENTS_ARCHIVE_INDEPENDENT_V1');assert actual_components==expected_components['audit']
 actual_objects=object_postimages(data);expected_objects=frozen('IMPLICIT_HYDRAULIC_STATE11_POSTIMAGES_ARCHIVE_INDEPENDENT_V1');assert actual_objects==expected_objects['audit']
 post=frozen('IMPLICIT_HYDRAULIC_STATE11_CURRENT_NONSELECTED_POSTIMAGES_V1');assert set(post)=={'O0','O2'} and sum(len(c['whole_objects']) for q in post.values() for c in q['contexts'])==648 and all(q['model_days']==q['model_executions']==0 and len(q['contexts'])==12 for q in post.values())
 parent_post=frozen('IMPLICIT_HYDRAULIC_STATE11_PARENT824_POSTIMAGES_V1');assert set(parent_post)=={'O0','O2'} and all(q['model_days']==q['model_executions']==0 and len(q['contexts'])==8 for q in parent_post.values())
 linux=frozen('IMPLICIT_HYDRAULIC_STATE11_UBUNTU_OBSERVER_INDEPENDENT_IDENTITY_EQUALITY_V1');assert len(linux['observations'])==2 and all(q['actual_science_equal_to_fresh_local_V3'] and q['model_or_compiler_executions']==0 for q in linux['observations'].values())
 coadmission=dict(parent['receipt']['coadmission']);assert coadmission['contexts']==824
 coadmission.update(contexts=880,short35_contexts=coadmission['short35_contexts']+56,native_calendar_samples=coadmission['native_calendar_samples']+392,exact_cold_windows=coadmission['exact_cold_windows']+176,new_implicit_analytical_hydraulic_state_contexts=56,new_implicit_analytical_hydraulic_state_primary_days=1960,new_implicit_analytical_hydraulic_state_compiled_refusals=320,new_implicit_analytical_hydraulic_state_external_transactions=56,new_implicit_analytical_hydraulic_state_unaffected_objects=648,new_implicit_analytical_hydraulic_state_original_parent_postimages=16,previous_canonical=BASE)
 return dict(status='BOUNDED_ORIGINAL_IMPLICIT_ANALYTICAL_ORDINARY_SNOW_FROST_HYDRAULIC_STATE_NATIVE_COLD_SOURCE_INPUT_SDK_AND_SCIENCE_PASS',actual_current_source=current,fresh_inherited_evidence=inherited,parent_historical_admission=parent,inherited_original_scientific_authority=authority,actual_raw_custody=raw,new_original_portable_science=results,additional_actual_local_science=actual_local,actual_original_mathematical_component_evidence=actual_components,actual_whole_object_postimages=actual_objects,coadmission=coadmission,scientific_change_class='EXISTING_PHYSICAL_PROCESS_COMPOSITION_WITH_SOURCE_PROVED_NUMERICAL_JACOBIAN_CORRECTIONS',additional_local_contexts_counted_again=False,unchanged_periods_replayed=False,original_scientific_producers_rebound=False,original_scientific_water_limit_cm='1e-10',original_scientific_cde_limit_mg_cm2='1e-10',new_physical_state=False,physical_equations_changed=False,inventory_or_flux_correction=False,original_dates_or_native_counters_normalized=False,automatic_fallback=False,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)
if __name__=='__main__':print(json.dumps(verify(),indent=2))
