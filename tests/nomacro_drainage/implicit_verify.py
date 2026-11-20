"""Bounded primary implicit source/raw admission retaining preceding science."""
from functools import lru_cache
import ast,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tests/nomacro_drainage'));sys.path.insert(0,str(ROOT/'tests/nomacro_scheduled_subsurface'))
import implicit_evidence as evidence
import history_verify as previous
from extended_forensics import require
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
BASE='ff1db48993ab801dc38202540d68686baa4fd2a2'
RUNTIME='9f472848850af09ecfd8221bb59e66357f7b7f7c'
FULL='5c78ec11c'
READERS='6e0b044fb838650b84c4af6bf5912eb5a5735651'
SEALED='075e2e28fd3451b28799b6b1f6584c0dc5c1974a'
QUAL='integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_IMPLICIT_QUALIFICATION.json'
OLD='tests/nomacro_drainage/history_verify.py'
SURFACES=('app','src','tools/solute','tools/vq','reference/swap-4.3.1')
SOURCE_LINE="    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual hydraulic-history compiler source differs from qualified runtime')\n"
SOURCE_HOOK="    import implicit_verify as implicit\n    implicit.guard_previous_source()\n"
VERIFY_HOOK="    import implicit_verify as implicit\n    return implicit.verify()\n"
PARSERS=('implicit_evidence.py','implicit_forensics.py','implicit_zero_boundary_forensics.py','implicit_failure_forensics.py','implicit_saturation_forensics.py','implicit_primary_postimage.py')

def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
def blob(ref,path):return git('show',ref+':'+path)
def norm(raw):return raw.replace(b'\r\n',b'\n')
def functions(raw):return {v.name:ast.dump(v) for v in ast.parse(raw).body if isinstance(v,ast.FunctionDef)}


def qualification():
 raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral implicit qualification changed');q=json.loads(raw)
 require((q['status'],q['runtime'],q['corrected_full_numeric_runtime'],q['predecessor'],q['independent_readers'])==('NEUTRAL_EXTENDED_IMPLICIT_PRIMARY_SOURCE_RAW_QUALIFICATION_PENDING_ADMISSION',RUNTIME,git('rev-parse',FULL).decode().strip(),BASE,READERS),'Foreign bounded implicit source authority')
 counts=dict(actual_primary_full_periods=8,actual_days_per_full_period=1096,actual_primary_complete_native_cold_windows=48,actual_corrected_same_context_CDE_h0_regression_full_periods=2,actual_regression_complete_native_cold_windows=12,actual_current_primary_short_contexts=18,actual_current_short_complete_native_cold_windows=54,actual_current_Windows_CDE35_postimages=4,actual_current_Ubuntu_CDE35_postimages=2,actual_current_public_native_refusals=578,actual_compiled_native_refusals=540,actual_current_primary_and_regression_CLI_contexts=14,actual_current_primary_and_regression_transaction_contexts=14,actual_new_policy_and_constitutive_source_refusals=14,actual_public_scope_refusals=5,actual_ordinary_zero_boundary_short_contexts=4,actual_ordinary_zero_boundary_complete_native_cold_windows=12,actual_ordinary_current_public_native_contexts=4,actual_pond_component_cases_per_optimization=40,actual_saturation_component_cases_per_optimization=32,actual_retained_censored_full_attempts=10)
 require(all(q[k]==v for k,v in counts.items()),'Bounded implicit actual denominators changed')
 require(all(q[k]==1e-10 for k in ('daily_soil_water_guard_cm','daily_secondary_water_guard_cm','daily_combined_water_guard_cm','daily_CDE_guard_mg_cm2','integrated_CDE_guard_mg_cm2')) and q['integrated_water_1e10_claim'] is False,'Implicit scientific guards changed')
 require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_remaining_gap_counts'],q['RC3_changed'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN',False),'Whole historical/scientific/release scope promoted')
 require(all(q[k] is False for k in ('primary_extended_implicit_admitted','secondary_only_extended_implicit_admitted','AGE_extended_admitted','original_examined_Ksat_branch_admitted')) and q['fresh_unaffected_full_periods']==0 and len(q['archives'])==16,'Unqualified scope or old full repeats promoted')
 return q


@lru_cache(maxsize=1)
def guard_previous_source():
 qualification();require(not git('diff',RUNTIME,'--',*SURFACES),'Actual implicit compiler source differs from qualified runtime')
 expected=['app/hybrid_water/'+v for v in ('daily_coupling.py','extended_drainage.py','extended_implicit_pond.py','extended_implicit_saturation.py','implicit_conductivity.py')]
 require(git('diff','--name-only',BASE,RUNTIME,'--',*SURFACES).decode().splitlines()==expected,'Unexpected implicit scientific compiler dependency changed')
 path='app/hybrid_water/extended_drainage.py';anchor=b"    swsrf, swsec, levels, division = map(integer,('SWSRF','SWSEC','NRSRF','SWDIVD'))\n";added=b"    if selected.get('SWKIMPL')==1 and swsrf!=3:\n        raise ValueError('Implicit secondary-only extended drainage is not qualified: original Newton clock-resolution failure')\n"
 before=blob(FULL,path);require(before.count(anchor)==1 and before.replace(anchor,anchor+added,1)==blob(RUNTIME,path),'Final input-only guard changed beyond exact inert primary/explicit predicate')
 require(git('diff','--name-only',FULL,RUNTIME,'--',*SURFACES).decode().splitlines()==[path],'Final guard changed numerical dependency')
 old=functions(blob(BASE,path));new=functions(blob(RUNTIME,path));mutable={'strict_trial_build','describe','magic','metadata','apply_build'}
 require(set(old)==set(new) and all(old[k]==new[k] for k in old if k not in mutable),'Earlier physical drainage/counter/native scientific function changed')
 path='app/hybrid_water/implicit_conductivity.py';old=b"            or selectors.get('SWBR', 0) != 0 or boundary['SWBOTB'] not in (1, 5, 8)):\n";new=b"            or selectors.get('SWBR', 0) != 0 or not (boundary['SWBOTB'] in (1,5,8)\n                or boundary['SWBOTB']==6 and selectors.get('SWDRA') in (1,2))):\n"
 before=blob(BASE,path);require(before.count(old)==1 and before.replace(old,new,1)==blob(RUNTIME,path),'Old implicit provider changed beyond bounded bottom6 input predicate')
 path='app/hybrid_water/daily_coupling.py';old=b"        if (bundle/'MOD_MvG_functions.f90').read_text(encoding='cp1252')!=implicit_saturation_source(original):\n";new=b"        expected_saturation=implicit_saturation_source(original)\n        from extended_implicit_saturation import enabled as continuous_saturation_enabled,source as continuous_saturation_source\n        if continuous_saturation_enabled(project):expected_saturation=continuous_saturation_source(expected_saturation)\n        if (bundle/'MOD_MvG_functions.f90').read_text(encoding='cp1252')!=expected_saturation:\n"
 before=blob(BASE,path);require(before.count(old)==1 and before.replace(old,new,1)==blob(RUNTIME,path),'Old daily transaction or physical body changed beyond selected actual-source validator')
 for path,ref,function in [('app/hybrid_water/extended_implicit_pond.py','dfee82354','render'),('app/hybrid_water/extended_implicit_saturation.py','9a6134d01','source')]:require(functions(blob(ref,path))[function]==functions(blob(RUNTIME,path))[function],'Actual integrated provider differs from its real component source function')
 return True


@lru_cache(maxsize=1)
def source():
 guard_previous_source();q=qualification();text=norm((ROOT/OLD).read_bytes()).decode();require(text.count(SOURCE_HOOK)==text.count(VERIFY_HOOK)==1,'Missing/ambiguous implicit owner delegation')
 require(text.replace(SOURCE_HOOK,SOURCE_LINE,1).replace(VERIFY_HOOK,'',1).encode()==blob(BASE,OLD),'Preceding history scientific/source body changed')
 for name in PARSERS:
  path='tests/nomacro_drainage/'+name;require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen independent implicit reader changed')
 for item in q['archives'].values():
  path='integration/f-ci/nomacro-complete01/'+item['record'];raw=(ROOT/path).read_bytes();require(norm(raw)==blob(SEALED,path) and evidence.prior.digest(norm(raw))==item['record_lf_sha256'],'Neutral implicit actual raw provenance changed')
 previous.source()
 return True


@lru_cache(maxsize=1)
def scientific():
 q=qualification();metrics={}
 for stage,calls,prefix in [('precorrection',(evidence.precorrection_windows,evidence.precorrection_ubuntu),'PRECORRECTION_'),('corrected',(evidence.corrected_windows,evidence.corrected_ubuntu),'CORRECTED_'),('final',(evidence.windows,evidence.ubuntu),'')]:
  for platform,call in zip(('Windows','Ubuntu'),calls):
   for opt in ('O0','O2'):metrics[stage+'-'+platform+'-'+opt]=call(PROOF/f'EXTENDED_DRAINAGE_IMPLICIT_{prefix}{platform.upper()}_{opt}_RAW_ARCHIVE.zip',opt)
 public=compiled=cli=transactions=0
 for opt in ('O0','O2'):
  samples=[metrics['corrected-Windows-'+opt][k]['controls'] for k in ('full-cde-h0','full-cde-h2')]+[metrics['corrected-Ubuntu-'+opt]['cde']['controls'],metrics['final-Windows-'+opt]['full-water']['controls'],metrics['final-Ubuntu-'+opt]['water']['controls'],metrics['final-Windows-'+opt]['short-automatic-cde-h2']['positive-controls'],metrics['final-Ubuntu-'+opt]['cde']['positive-controls']]
  for v in samples:public+=v['actual_public_refusals'];compiled+=v['actual_compiled_refusals'];cli+=v['actual_cli_contexts'];transactions+=v['actual_transaction_contexts']
 require((public,compiled,cli,transactions)==(578,540,14,14),'Actual recomputed primary/regression/control observations differ')
 for name,item in q['archives'].items():
  if 'SOURCE_RAW_ARCHIVE' in name or 'DIAGNOSTICS' in name:
   path=PROOF/item['archive']
   with evidence.prior.archive(path,json.loads(path.with_suffix('.json').read_text())):pass
 return dict(metrics=metrics,actual_primary_full_periods=8,actual_same_context_regression_full_periods=2,actual_primary_complete_native_cold_windows=48,actual_regression_cold_windows=12,actual_current_short_contexts=18,actual_current_short_cold_windows=54,actual_public_native_refusals=public,actual_compiled_native_refusals=compiled,actual_CLI_contexts=cli,actual_transaction_contexts=transactions,actual_before_worker_new_policy_refusals=14,actual_before_compiler_scope_refusals=5)


def verify():
 source();current=scientific();history=previous.scientific();calendar=previous.previous.scientific();drainage=previous.previous.preceding.scientific()
 import weather_surface_verify as weather
 q=json.loads((PROOF/'WEATHER_TERMINAL_QUALIFICATION.json').read_bytes());weather.validate(q);inherited_weather=weather.scientific(q);inherited=weather.inherited()
 return dict(status='BOUNDED_PRIMARY_EXTENDED_IMPLICIT_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,**current,inherited_history=history,inherited_calendar=calendar,inherited_drainage=drainage,inherited_weather=inherited_weather,inherited_groundwater=inherited,secondary_only_implicit_admitted=False,AGE_extended_admitted=False,functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
