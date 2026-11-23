"""Fail-closed bounded Snow/history/calendar owner inheriting actual canonical280."""
import json,re
from contextlib import ExitStack
from pathlib import Path
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_snow_history_source_v2 import ROOT,CORE,git
from explicit_bottom9_snow_history_source_custody import source,inherited_evidence
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SEALED='2d9de5b70c5b4e96d2f7a11db3460c008f71bf88'
ADMISSION_SHA='8aba9e5e92421e2370d3fc069e74fd906f6bd317d53cb75f130f21ae30055e8a'
NAMES=('EXPLICIT_BOTTOM9_SNOW_HISTORY_WINDOWS_RAW_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_UBUNTU_O0_ORIGINAL_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_UBUNTU_O2_ORIGINAL_V1')


def frozen(name):
 path='integration/f-ci/nomacro-complete01/'+name+'.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show',SEALED+':'+path),'Changed bounded scientific declaration: '+name;return json.loads(raw)


def parent_admission():
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_COMBINED_ADMISSION_RAW_V1',stack);assert store.record['sha256']==ADMISSION_SHA and store.record['canonical_admission'] is True
  for member in store.names:store.get(member)
  q=json.loads(store.get('EXPLICIT_BOTTOM9_COMBINED_ACTUAL_CANONICAL_PUBLIC_V1.stdout.txt'));receipt=json.loads(store.get('EXPLICIT_BOTTOM9_COMBINED_ACTUAL_CANONICAL_PUBLIC_V1.json'))
  assert receipt['before']==receipt['after'] and receipt['before']['head']==CORE and receipt['returncode']==0 and not store.get('EXPLICIT_BOTTOM9_COMBINED_ACTUAL_CANONICAL_PUBLIC_V1.stderr.txt')
 assert q['status']=='BOUNDED_ORIGINAL_ANALYTICAL_SNOW_HISTORY_PAIRED9_SOURCE_RAW_NATIVE_AND_WHOLE_COMPILED_POSTIMAGES_PASS' and q['coadmission']['contexts']==280 and q['coadmission']['native_calendar_samples']==1966 and q['coadmission']['exact_cold_windows']==844
 receipt=frozen('EXPLICIT_BOTTOM9_COMBINED_MERGE_RECEIPT_V1');assert receipt['actual_merge']==CORE and receipt['contexts']==280 and receipt['admission_archive_sha256']==ADMISSION_SHA and receipt['canonical_admission'] is True
 # The admitted canonical has its actual, ordered merge parents and exact tree.
 assert git('rev-parse',CORE+'^{tree}').decode().strip()==receipt['whole_qualified_tree']
 assert git('show','-s','--format=%P',CORE).decode().strip().split()==receipt['ordered_parents']
 return receipt,q


def raw_custody():
 rows=[]
 with ExitStack() as stack:
  for name in NAMES:
   declaration=frozen(name);store=Archive(PROOF,name,stack);assert store.record==declaration
   for member in store.names:store.get(member)
   rows.append(dict(archive=name,bytes=declaration['bytes'],sha256=declaration['sha256'],members=len(store.names)))
 return rows


def guard_previous_source():
 source(SEALED);inherited_evidence();parent_admission();raw_custody();return True


def strip_current_evidence(text):
 from explicit_bottom9_combined_verify import strip_current_evidence as original
 return original(text)


def publication_dependencies_unchanged():
 guard_previous_source();return True


def verify():
 actual_source=source(SEALED);inherited=inherited_evidence();admission,prior=parent_admission();raw=raw_custody();science={}
 names=('EXPLICIT_BOTTOM9_SNOW_HISTORY_WINDOWS_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_UBUNTU_O0_CENTRAL_INDEPENDENT_V1','EXPLICIT_BOTTOM9_SNOW_HISTORY_UBUNTU_O2_CENTRAL_INDEPENDENT_V1')
 for name in names:
  q=frozen(name);assert 'PASS_NOT_ADMITTED' in q['status'] and q['model_executions']==q['compiler_executions']==0 and q['canonical_admission'] is False;science[name]=q
 windows=science[names[0]];assert len(windows['contexts'])==28 and len(windows['native_controls'])==8 and len(windows['prior_compiler_preservation'])==12
 for opt,name in zip(('O0','O2'),names[1:]):
  q=science[name];assert len(q['contexts'])==14 and len(q['native_controls'])==4 and q['optimization']==opt and q['actual_producer']=='6154891091824c9f0f64c9fff299ad320ccd9479'
 contexts=[item for q in science.values() for item in q['contexts']];assert len(contexts)==56 and all(x['actual_days']==35 and x['actual_native_checkpoints']==7 and x['actual_exact_cold_windows']==3 and x['absolute_water_limit_cm']=='1e-10' for x in contexts)
 guards=frozen('EXPLICIT_BOTTOM9_SNOW_HISTORY_HARD_GUARDS_V2');assert len(guards['checks'])==13 and sum(x['frontend_accepted'] for x in guards['checks'])==1 and guards['compiler_executions']==guards['model_executions']==0
 return dict(status='BOUNDED_ORIGINAL_SNOW_HISTORY_CALENDARS_PAIRED9_PARENT280_AND_NEW56_SOURCE_RAW_NATIVE_COLD_WHOLE_COMPILED_POSTIMAGES_PASS',actual_current_source=actual_source,fresh_parent280_evidence=inherited,parent_actual_admission=admission,inherited280_original_science=prior,new56_original_science=science,actual_new_raw_custody=raw,actual_hard_domain_controls=guards,scientific_reuse='COMPLETE_LITERAL_TWO_GUARD_AND_OWNER_INVERSES_FRESH_ALL_PARENT280_BYTES_CURRENT_INITIAL2_AND12_PRIOR_WHOLE_COMPILED_POSTIMAGES_NO_MODEL_REPLAY_OR_BINDING_REWRITE',coadmission=dict(contexts=336,short35_contexts=334,year367_contexts=2,new_snow_history_calendar_contexts=56,native_calendar_samples=2358,exact_cold_windows=1012,compiled_initialization_postimages=279,prior_current_compiler_preservation_postimages=12,previous_canonical=CORE),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
