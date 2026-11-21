"""Source and raw owner for the bounded original per-layer vapor composition."""
from contextlib import ExitStack
from functools import lru_cache
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_verify import git,blob,norm,SURFACES
from ordinary_pond_evidence import require
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
import vapor_inherited_owner as inherited
from vapor_source_inverse import PARENT,RUNTIME,ADDED,complete_inverse
import vapor_windows_science as windows
import vapor_ubuntu_science as ubuntu
import vapor_unselected_science as unselected
import vapor_research_science as research

READERS='d3372561fa830687906739bd62b3c812d6f8f73d'
SEALED='ed97b4526accc1f64120bbcefb69289c5e3c9151'
QUAL='integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_QUALIFICATION.json'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
PARSERS=('vapor_source_inverse.py','vapor_parent_bridge.json','vapor_inherited_owner.py','vapor_portable_storage_bridge.json',
    'vapor_hydraulic_forensics.py','vapor_hydraulic_resume.py','vapor_mixed_component_forensics.py','vapor_cde_native_forensics.py',
    'vapor_receipt_bridge.py','vapor_cold_continuation.py','vapor_windows_science.py','vapor_ubuntu_science.py',
    'vapor_unselected_science.py','vapor_research_science.py','vapor_frontend_controls.py',
    'vapor_unselected_model7_postimages.py','vapor_hydraulic_runtime.py','vapor_hydraulic_portable.py')


def strip_current_evidence(text):
    if inherited.PATTERN in text:
        require(text.count(inherited.PATTERN)==1,'Ambiguous vapor proof checkout');text=text.replace(inherited.PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    complete_inverse()
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen vapor scientific observer changed: '+name)
    actual=norm((ROOT/inherited.OLD).read_bytes()).decode()
    for hook in (inherited.GUARD_HOOK,inherited.VERIFY_HOOK,inherited.PROJECTION_HOOK):
        require(actual.count(hook)==1,'Missing/ambiguous vapor analytical delegation');actual=actual.replace(hook,'',1)
    require(actual.encode()==blob(PARENT,inherited.OLD),'Admitted analytical scientific body changed')
    actual=norm((ROOT/inherited.MODEL7).read_bytes()).decode()
    require(actual.count(inherited.PUBLICATION_HOOK)==1,'Missing/ambiguous vapor publication delegation')
    require(actual.replace(inherited.PUBLICATION_HOOK,'',1).encode()==blob(PARENT,inherited.MODEL7),'Admitted model7 owner changed beyond publication delegation')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={inherited.OLD,inherited.MODEL7},'Earlier observer modified outside exact delegation')
    for path in inherited.CI:
        actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(inherited.PATTERN)==1 and actual.replace(inherited.PATTERN,'',1).encode()==blob(PARENT,path),'Registered public proof source changed')
    inherited.portable_storage_inverse()
    inherited.guard_inherited()
    return True


def publication_dependencies_unchanged():
    guard_previous_source()
    scopes=('src','app/solute_project','tests/publication','docs/publication','docs/publications','docs/verification','docs/performance/evidence','tools/vq','tools/solute','tests/fsi/fsi04_real_headcalc_stubs.f90')
    if git('diff',PARENT,'HEAD','--',*scopes):return False
    expected={path for path in ADDED if path.startswith('reference/')}
    paths=git('diff','--no-renames','--name-status',PARENT,'HEAD','--','reference').decode().splitlines()
    return set(paths)=={'A\t'+path for path in expected} and all(blob('HEAD',path)==blob(RUNTIME,path) for path in expected)


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral vapor qualification changed');q=json.loads(raw)
    require(q['status']=='NEUTRAL_ORIGINAL_VAPOR_SOURCE_RAW_SCIENCE_PASS_PENDING_ADMISSION','Neutral vapor role promoted')
    require((q['predecessor'],q['runtime'],q['independent_readers'])==(PARENT,git('rev-parse',RUNTIME).decode().strip(),git('rev-parse',READERS).decode().strip()),'Foreign vapor source identity')
    for key in ('vapor_family_admitted','whole_historical_family_closed','AGE_admitted','implicit_vapor_admitted','broader_boundaries_admitted','active_macropores_admitted','RC3_changed','new_physical_water_store','tolerance_changed'):
        require(q[key] is False,'Unqualified vapor scope promoted: '+key)
    require(q['native_interface_changed'] is True and q['Kelvin_reference_sign_corrected'] is True and q['existing_microscopic_dry_endpoint_correction_composed'] is True,'Actual vapor reference/state composition hidden')
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_gap_counts'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN'),'Whole historical scope promoted')
    for key in ('daily_water_guard_cm','daily_CDE_guard_mg_cm2','every_prefix_CDE_guard_mg_cm2'):require(q[key]==1e-10,'Vapor mass bound changed')
    # Authenticate every new raw archive before the expensive inherited replay.
    with ExitStack() as stack:
        for item in q['archives'].values():
            path=PROOF/item['record'];require(norm(path.read_bytes())==blob(SEALED,path.relative_to(ROOT).as_posix()),'Neutral vapor raw inventory changed')
            record=json.loads(path.read_text());require(all(record[key]==item[key] for key in ('archive','bytes','sha256')),'Foreign vapor original raw identity')
            Archive(PROOF,path.stem,stack)
        admission=Store(PROOF,'HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1',stack)
        previous=json.loads((PROOF/'HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1.json').read_text())
        require(previous['canonical']==PARENT and previous['sha256']=='de2809557fc94f68df90ce7c7b3f3b3868540b13fa79794b8f625bbe4a493c9d','Actual inherited analytical admission changed')
        for name in admission.names:admission.get(name)
    return q


def frontend_records():
    with ExitStack() as stack:
        research_raw=Archive(PROOF,'HYDRAULIC_VAPOR_WINDOWS_RESEARCH_RAW_V1',stack)
        cohorts={kind:Archive(PROOF,'HYDRAULIC_VAPOR_WINDOWS_'+kind.upper()+'_RAW_V1',stack) for kind in ('water','cde')}
        inputs={}
        for store in cohorts.values():
            for role in store.record['roles']:
                profile=store.view(role['profile']);q=json.loads((profile/'RESULT.json').read_text())
                inputs[role['profile'].split('/')[-1]]=windows.mapped(store,q['input_root'])
        q=json.loads(research_raw.get('profiles/vapor-frontend-controls-v2/RESULT.json'))
        require(q['status']=='ACTUAL_VAPOR_FRONTEND_SUPPORTED_COHORT_BOUNDS_AND_HISTORICAL_INACTIVE_FLAGS_PASS' and len(q['checks'])==56,'Actual vapor frontend controls changed')
        windows.source_epoch(q['source'])
        counts={}
        for index,check in enumerate(q['checks']):
            counts[check['status']]=counts.get(check['status'],0)+1
            if index<32:
                require(check['status']=='SUPPORTED_EXACT_INPUT_SCOPE','Actual qualified input scope changed');directory=inputs[check['role']]
            elif index<52:
                require(check['status']=='REFUSED_BEFORE_BUILD','Unsupported vapor configuration admitted');directory=research_raw.view('profiles/vapor-frontend-controls-v2/input-refused-'+str(index-32))
            elif index<55:
                require(check['status']=='HISTORICAL_INACTIVE_FLAGS_REMAIN_INACTIVE_HASH_BOUND','Historically ignored vapor switch activated');directory=research_raw.view('profiles/vapor-frontend-controls-v2/input-'+check['role'])
            else:
                require(check['role']=='compatibility-output-active-vapor' and check['status']=='REFUSED_BEFORE_BUILD','Unqualified compatibility vapor admitted');continue
            for name,digest in check['input_inventory']:require(windows.SHA((directory/name).read_bytes())==digest,'Actual frontend input changed')
        return dict(status=q['status'],checks=len(q['checks']),counts=counts,compiler_executions=0,model_executions=0)


def verify():
    guard_previous_source();q=qualification();prior=inherited.inherited_science()
    actual_windows=windows.read(PROOF);actual_ubuntu=ubuntu.read(PROOF);unchanged=unselected.read(PROOF);retained=research.read(PROOF);frontend=frontend_records()
    require(actual_windows['full1096_contexts']==actual_ubuntu['full1096_contexts']==32,'Actual vapor full denominator changed')
    require(actual_windows['exact_cold_windows']==actual_ubuntu['exact_cold_windows']==224,'Actual vapor exact cold denominator changed')
    require(actual_windows['compiled_native_refusals']==668 and actual_windows['active_transaction_contexts']==8,'Actual Windows vapor native/transaction denominator changed')
    require(sum(item['compiled_refusals'] for item in actual_ubuntu['new_descriptor_native_controls'])==334 and len(actual_ubuntu['new_descriptor_native_controls'])==4,'Actual Ubuntu vapor native/transaction denominator changed')
    require(unchanged['short35_contexts']==4 and unchanged['exact_cold_windows']==12,'Unchanged compiled/native postimages changed')
    require((q['actual_full1096_contexts'],q['actual_exact_cold_windows'],q['actual_compiled_native_refusals'],q['actual_active_transaction_contexts'])==(64,448,1002,12),'Neutral vapor denominator changed')
    return dict(status='BOUNDED_ORIGINAL_PER_LAYER_VAPOR_KELVIN_LOOKUP_SOURCE_RAW_NATIVE_PASS',runtime=git('rev-parse',RUNTIME).decode().strip(),
        Windows=actual_windows,Ubuntu=actual_ubuntu,unselected=unchanged,retained_reference_and_failed_roles=retained,frontend=frontend,
        inherited_actual_analytical_and_earlier_science=prior,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',vapor_family_admitted=False,whole_historical_family_closed=False,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
