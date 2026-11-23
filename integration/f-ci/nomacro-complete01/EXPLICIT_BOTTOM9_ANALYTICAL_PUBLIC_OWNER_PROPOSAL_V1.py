"""Own coherent analytical240 only after actual parent216 canonical admission."""
import ast,hashlib,io,json,os,re,sys
from pathlib import Path
from contextlib import ExitStack,contextmanager,redirect_stdout
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from analytical_hydraulic_archives import Archive,SHA
from explicit_bottom9_analytical_source_inverse import ANALYTICAL_CORE,PARENT_PUBLIC,parent_source_context,complete_inverse,git,blob,norm
from explicit_bottom9_parent_projection import immutable_source_reads
from explicit_bottom9_analytical_central import windows,ubuntu
from explicit_bottom9_analytical_prior60_inheritance import audit as prior_selection
from explicit_bottom9_analytical_prior_postimages_central import read as prior_compiled
from explicit_bottom9_analytical_inherited_custody import fresh as complete_parent_custody,source as complete_parent_source
import explicit_bottom9_verify as parent
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
SELF='tests/nomacro_drainage/explicit_bottom9_analytical_verify.py'
OLD='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
SEALED='PENDING_ACTUAL_SOURCE_ANCHOR'
PARENT_CANONICAL='PENDING_ACTUAL_PARENT216_CANONICAL'
PARENT_ADMISSION_SHA='PENDING_ACTUAL_PARENT216_ADMISSION_SHA'
CONTRACT_SHA='PENDING_ACTUAL_COHERENT240_CONTRACT_SHA'
HOOKS={name:' import explicit_bottom9_analytical_verify as analytical_owner\n return analytical_owner.'+name+'('+('text' if name=='strip_current_evidence' else '')+')\n' for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged')}


class OriginalHookSource:
 def read_bytes(self):return blob(PARENT_PUBLIC,OLD)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class OriginalSourceRoot:
 def __truediv__(self,name):return OriginalHookSource() if str(name)==OLD else ROOT/name
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


@contextmanager
def parent_scope():
 # This cache retains only original byte-verified full40-SHA source blobs.
 # Actual HEAD/diff/status queries and all scientific data reads stay fresh.
 saved=parent.ROOT
 with immutable_source_reads(),parent_source_context():
  parent.ROOT=OriginalSourceRoot()
  try:yield
  finally:parent.ROOT=saved


def checked_current_source():
 assert re.fullmatch('[0-9a-f]{40}',SEALED) and re.fullmatch('[0-9a-f]{40}',PARENT_CANONICAL)
 assert re.fullmatch('[0-9a-f]{64}',PARENT_ADMISSION_SHA) and re.fullmatch('[0-9a-f]{64}',CONTRACT_SHA)
 complete_inverse();contract=norm((PROOF/'EXPLICIT_BOTTOM9_ANALYTICAL_COADMISSION_CONTRACT_V1.json').read_bytes());assert SHA(contract)==CONTRACT_SHA;q=json.loads(contract)
 assert q['parent_contexts']==216 and q['new_contexts']==24 and q['combined_contexts']==240 and q['previous_actual_canonical']==PARENT_CANONICAL and q['parent_qualified_head']==PARENT_PUBLIC and q['parent_admission_sha256']==PARENT_ADMISSION_SHA
 assert q['canonical_admission'] is False and q['whole_historical_family_closed'] is False and q['RC3_changed'] is False
 raw=norm((ROOT/OLD).read_bytes()).decode()
 for hook in HOOKS.values():assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
 expected=blob(PARENT_PUBLIC,OLD).decode()
 for hook in parent.HOOKS.values():assert expected.count(hook)==1;expected=expected.replace(hook,'',1)
 assert raw==expected and raw.encode()==blob(parent.BASE,OLD),'Joint156 science body differs beyond the exact four owner delegations'
 for path in git('ls-tree','-r','--name-only',SEALED,'--','tests/nomacro_drainage').decode().splitlines():
  if Path(path).name.startswith('explicit_bottom9_analytical_') and Path(path).suffix in ('.py','.f90'):
   actual=norm((ROOT/path).read_bytes());expected=blob(SEALED,path)
   if path==SELF:
    pattern=br"(?m)^SEALED='[0-9a-f]{40}'$";actual,a=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",actual);expected,b=re.subn(pattern,b"SEALED='IMMUTABLE_DEPENDENCY_ANCHOR'",expected);assert a==b==1
   assert actual==expected,'Frozen analytical proof reader changed: '+path
 for path in git('ls-tree','-r','--name-only',SEALED,'--','integration/f-ci/nomacro-complete01').decode().splitlines():
  if Path(path).name.startswith('EXPLICIT_BOTTOM9_ANALYTICAL') and path.endswith('.json'):assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen analytical source/qualification/raw record changed: '+path
 with parent_scope():assert parent.checked_current_source() is True
 return True


def raw_custody():
 observed=[]
 with ExitStack() as stack:
  for name in ['EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_RAW_V1']+['EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_'+opt+'_RAW_V1' for opt in ('O0','O2')]:
   store=Archive(PROOF,name,stack);expected=json.loads(blob(SEALED,'integration/f-ci/nomacro-complete01/'+name+'.json'));assert store.record==expected;observed.append(dict(archive=name,sha256=expected['sha256'],bytes=expected['bytes'],members=len(expected['members'])))
 return observed


def parent_admission():
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_ADMISSION_RAW_V1',stack);assert store.record['sha256']==PARENT_ADMISSION_SHA and store.record['candidate']==PARENT_PUBLIC and store.record['canonical']==PARENT_CANONICAL and store.record['canonical_admission'] is True
  for name in store.names:store.get(name)
 q=json.loads((PROOF/'EXPLICIT_BOTTOM9_MERGE_RECEIPT_V1.json').read_text());assert q['status']=='ACTUAL_CANONICAL_216CONTEXT_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_ADMISSION_VERIFIED' and q['qualified_head']==PARENT_PUBLIC and q['actual_merge']==PARENT_CANONICAL and q['admission_archive_sha256']==PARENT_ADMISSION_SHA and q['contexts']==216 and q['canonical_admission'] is True
 return q


def guard_previous_source():
 checked_current_source();raw_custody();parent_admission()
 with immutable_source_reads():complete_parent_source(SEALED)
 return True


def strip_current_evidence(text):
 with parent_scope():return parent.strip_current_evidence(text)


def publication_dependencies_unchanged():
 checked_current_source();raw_custody();parent_admission()
 with immutable_source_reads():complete_parent_source(SEALED)
 # The actual parent publication selector was false, and its complete source
 # dependency tree is unchanged. Its original positive/negative receipts remain
 # required by the actual parent admission archive.
 return True


def verify():
 checked_current_source();raw=raw_custody();admission=parent_admission();messages=io.StringIO()
 # This is configuration reuse after actual canonical admission, the exact
 # whole source inverse, complete fresh evidence custody, and twelve actual
 # integrated compiled postimages. The original numerical assertions and their
 # full successful canonical result remain immutable in the parent raw archive.
 with immutable_source_reads():inherited_source=complete_parent_source(SEALED)
 inherited_bytes=complete_parent_custody(PROOF)
 compiled=prior_compiled(PROOF)
 assert compiled==json.loads((PROOF/'EXPLICIT_BOTTOM9_ANALYTICAL_PRIOR_POSTIMAGES_CENTRAL_INDEPENDENT_V1.json').read_text())
 with ExitStack() as stack:
  store=Archive(PROOF,'EXPLICIT_BOTTOM9_ADMISSION_RAW_V1',stack)
  assert store.record['sha256']==PARENT_ADMISSION_SHA
  prior=json.loads(store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stdout.txt'))
  receipt=json.loads(store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.json'))
  assert receipt['before']==receipt['after'] and receipt['before']['head']==PARENT_CANONICAL
  assert receipt['returncode']==0 and not store.get('EXPLICIT_BOTTOM9_ACTUAL_CANONICAL_PUBLIC_OWNER_V1.stderr.txt')
 assert prior['status']=='BOUNDED_ORIGINAL_EXPLICIT9_WATER_CDE_AGE_CALENDAR_DRAINAGE_SOURCE_RAW_NATIVE_PASS' and prior['coadmission']['contexts']==216
 assert prior['functional_completion']=='PARTIAL' and prior['whole_scientific_equivalence']=='NOT_QUALIFIED' and prior['RC3_changed'] is False
 observed={}
 for key,function,args,name in [('windows12',windows,(PROOF,),'EXPLICIT_BOTTOM9_ANALYTICAL_WINDOWS_CENTRAL_INDEPENDENT_V1.json')]+[('ubuntu6_'+opt,ubuntu,(PROOF,opt),'EXPLICIT_BOTTOM9_ANALYTICAL_UBUNTU_'+opt+'_CENTRAL_INDEPENDENT_V1.json') for opt in ('O0','O2')]+[('prior60_selection',prior_selection,(ROOT,PROOF),'EXPLICIT_BOTTOM9_ANALYTICAL_PRIOR60_SELECTION_INHERITANCE_V1.json')]:
  with redirect_stdout(messages):actual=function(*args)
  assert actual==json.loads((PROOF/name).read_text());observed[key]=actual
 return dict(status='BOUNDED_ORIGINAL_ANALYTICAL_PAIRED9_WATER_CDE_SOURCE_REFERENCE_RAW_NATIVE_PASS',physical_composition_source=ANALYTICAL_CORE,analytical=observed,inherited216_and_all_prior_science=prior,inherited_science_method='ACTUAL_CANONICAL_NUMERICAL_PROOF_REUSED_AFTER_WHOLE_SOURCE_INVERSE_COMPLETE_FRESH_EVIDENCE_CUSTODY_AND_ACTUAL_COMPILED_POSTIMAGES',inherited_fresh_source=inherited_source,inherited_fresh_bytes=inherited_bytes,inherited_current_compiled_postimages=compiled,parent_actual_admission=admission,actual_current_raw_custody=raw,scientific_reader_messages=messages.getvalue(),coadmission=dict(contexts=240,short35_contexts=238,year367_contexts=2,exact_cold_windows=724,native_calendar_samples=1686,compiled_postimages=183,previous_canonical=PARENT_CANONICAL,standalone_AGE110_admission_claimed=False),compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
