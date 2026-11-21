"""Source-bound public owner for the bounded original explicit analytical family."""
import ast
from functools import lru_cache
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
from ordinary_pond_evidence import require,read
import analytical_inherited_owner as inherited
import analytical_hydraulic_science as windows_cde
import analytical_water_science as windows_water
import analytical_ubuntu_science as ubuntu
import analytical_postimage_science as postimages
import analytical_unselected_dispatch as unselected

PARENT=inherited.PARENT
RUNTIME=inherited.RUNTIME
READERS='8d9d36e02a91bdba2b8d1b24b03d60bda0f173e7'
SEALED='1ee606995491e94f3139ba574c66e99bc385ba0f'
PORTABLE=inherited.PORTABLE
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_QUALIFICATION.json'
OLD=inherited.OLD
PATTERN='            /integration/f-ci/nomacro-complete01/*ANALYTICAL*\n'
GUARD_HOOK='    import analytical_verify as analytical\n    return analytical.guard_previous_source()\n'
VERIFY_HOOK='    import analytical_verify as analytical\n    return analytical.verify()\n'
PROJECTION_HOOK='    import analytical_verify as analytical\n    text=analytical.strip_current_evidence(text)\n'
PARSERS=('analytical_inherited_owner.py','analytical_parent_bridge.json','analytical_frontend_guard_bridge.json',
 'analytical_hydraulic_archives.py','analytical_hydraulic_forensics.py','analytical_hydraulic_science.py',
 'analytical_water_science.py','analytical_ubuntu_science.py','analytical_postimage_science.py',
 'analytical_unselected_dispatch.py','analytical_interface_reuse.py','hydraulic_mixed_analytical_read.py')


def strip_current_evidence(text):
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous analytical proof checkout');text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    inherited.complete_inverse()
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen independent analytical observer changed: '+name)
    actual=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(actual.count(hook)==1,'Ambiguous analytical scientific delegation');actual=actual.replace(hook,'',1)
    require(actual.encode()==blob(PARENT,OLD),'Earlier model7 scientific owner changed')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD,inherited.COMPONENT},'Earlier observer changed beyond exact analytical delegation and component inverse')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),'Registered CI changed beyond analytical proof checkout')
    inherited.guard_inherited()
    return True


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral analytical qualification changed');q=json.loads(raw)
    require((q['runtime'],q['predecessor'],q['independent_readers'],q['portable'])==(RUNTIME,PARENT,READERS,PORTABLE),'Foreign analytical qualification source')
    require(q['status']=='NEUTRAL_ANALYTICAL_FAMILY_RAW_SCIENCE_PASS_PENDING_ADMISSION','Analytical neutral role promoted')
    for key in ('analytical_family_admitted','AGE_admitted','implicit_nondefault_conductivity_admitted','broader_boundaries_admitted','RC3_changed','new_physical_state','native_interface_changed','tolerance_changed','physical_equations_changed','whole_historical_family_closed'):
        require(q[key] is False,'Unqualified analytical authority promoted: '+key)
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_gap_counts'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN'),'Whole historical family promoted')
    for key in ('daily_water_guard_cm','daily_CDE_guard_mg_cm2','every_prefix_CDE_guard_mg_cm2'):require(q[key]==1e-10,'Scientific analytical mass bound changed')
    from contextlib import ExitStack
    from analytical_hydraulic_archives import Archive
    from model7_search_science import Store
    with ExitStack() as stack:
        for item in q['archives'].values():
            path=PROOF/item['record'];require(norm(path.read_bytes())==blob(SEALED,path.relative_to(ROOT).as_posix()),'Neutral analytical raw inventory changed')
            record=read(path)
            require(all(record[k]==item[k] for k in ('archive','bytes','sha256')),'Foreign neutral analytical raw identity')
            # Authenticate every original ZIP before inherited scientific work.
            (Archive if 'parts' in record else Store)(PROOF,path.stem,stack)
    return q


def inherited_admission():
    from model7_search_science import Store
    from contextlib import ExitStack
    with ExitStack() as stack:
        archive=Store(PROOF,'HYDRAULIC_MODEL7_ADMISSION_RAW_V1',stack)
        require(read(PROOF/'HYDRAULIC_MODEL7_ADMISSION_RAW_V1.json')['canonical']==PARENT,'Inherited actual canonical model7 receipt changed')
        require(read(PROOF/'HYDRAULIC_MODEL7_ADMISSION_RAW_V1.json')['sha256']=='dbd18b19cc8ef08044f5f9b48d1db0e20e9f6ca7bd82cf2da69168325f13ca79','Inherited actual model7 admission changed')
        for name in archive.names:archive.get(name)
    return inherited.inherited_science()


def verify():
    guard_previous_source();q=qualification();prior=inherited_admission()
    cde=windows_cde.windows_cde(PROOF);water=windows_water.read(PROOF);portable=ubuntu.read(PROOF);post=postimages.read(PROOF);dispatch=unselected.read(PROOF)
    require(cde['full1096_contexts']==water['full1096_contexts']==20 and portable['full1096_contexts']==40,'Actual analytical full period denominator changed')
    require(cde['exact_cold_windows']==water['exact_cold_windows']==200 and portable['exact_cold_windows']==400,'Actual analytical cold denominator changed')
    require(post['short35_contexts']==4 and post['exact_cold_windows']==12 and len(dispatch['contexts'])==8,'Actual unchanged dependency projection changed')
    require(q['actual_full1096_contexts']==80 and q['actual_short35_contexts']==80 and q['actual_exact_cold_windows']==800,'Neutral analytical denominator changed')
    return dict(status='BOUNDED_ORIGINAL_EXPLICIT_ANALYTICAL_FAMILY_SOURCE_RAW_NATIVE_PASS',runtime=RUNTIME,windows_CDE=cde,windows_water=water,Ubuntu=portable,model7_postimages=post,unselected_dispatch=dispatch,
        inherited_actual_model7_and_earlier_science=prior,compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',analytical_family_admitted=False,
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False,AGE_admitted=False,implicit_nondefault_conductivity_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
