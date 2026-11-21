"""Bound original model7 derivative/search science and unchanged admitted owners."""
import ast
from functools import lru_cache
import json
from pathlib import Path
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
from ordinary_pond_evidence import read,digest,require
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
import model7_search_science as science
import model7_unselected_science as postimages

PARENT='085c95c3202380bb01987fdb5741b437d2acbf12'
RUNTIME='46c2c1c74a4ee9941612863d805120be4dcb87d5'
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
SEALED='d820ca47fb2ba6f9e509ef4bce3a503eb8daa0fe'
PORTABLE='9b63dabe8c25bdd9d86a9818864c093dc7451eb0'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
QUAL='integration/f-ci/nomacro-complete01/HYDRAULIC_MODEL7_QUALIFICATION.json'
OLD='tests/nomacro_drainage/implicit_frost_verify.py'
GUARD_HOOK='    import model7_verify as model7\n    return model7.guard_previous_source()\n'
VERIFY_HOOK='    import model7_verify as model7\n    return model7.verify()\n'
PROJECTION_HOOK='    import model7_verify as model7\n    text=model7.strip_current_evidence(text)\n'
PUBLICATION_HOOK='    import model7_verify as model7\n    return model7.publication_dependencies_unchanged()\n'
PATTERN='            /integration/f-ci/nomacro-complete01/*MODEL7*\n'
PARSERS=('model7_capacity_forensics.py','model7_search_science.py','model7_unselected_science.py','hydraulic_saturation_read.py','model7_parent_bridge.json')


def strip_current_evidence(text):
    import analytical_verify as analytical
    text=analytical.strip_current_evidence(text)
    if PATTERN in text:
        require(text.count(PATTERN)==1,'Ambiguous model7 proof checkout');text=text.replace(PATTERN,'',1)
    return text


@lru_cache(maxsize=1)
def guard_previous_source():
    import analytical_verify as analytical
    return analytical.guard_previous_source()
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual model7 compiler source differs from qualified runtime')
    bridge=read(Path(__file__).with_name('model7_parent_bridge.json'))
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign model7 complete parent bridge')
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    expected={line.split('\t')[1]:line.split('\t')[0] for line in changes}
    require(set(expected)==set(bridge['changes'])|set(bridge['added']) and all(expected[p]=='M' for p in bridge['changes']) and all(expected[p]=='A' for p in bridge['added']), 'Incomplete whole model7 source bridge')
    for path,items in bridge['changes'].items():
        lines=blob(RUNTIME,path).decode().splitlines(keepends=True)
        for item in reversed(items):
            at=item['runtime_line']-1;after=item['after'].splitlines(keepends=True)
            require(lines[at:at+len(after)]==after,'Changed actual model7 source bridge');lines[at:at+len(after)]=item['before'].splitlines(keepends=True)
        require(''.join(lines).encode()==blob(PARENT,path),'Admitted implicit Frost complete parent changed')
    for path,value in bridge['added'].items():require(sha(blob(RUNTIME,path))==value,'Added model7 source changed')
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        require(norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen independent model7 observer changed: '+name)
    old=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK):
        require(old.count(hook)==1,'Ambiguous model7 scientific delegation');old=old.replace(hook,'',1)
    require(old.encode()==blob(PARENT,OLD),'Earlier implicit Frost scientific owner changed')
    path='tests/nomacro_drainage/frost_publication_scope.py';actual=norm((ROOT/path).read_bytes()).decode()
    require(actual.count(PUBLICATION_HOOK)==1 and actual.replace(PUBLICATION_HOOK,'',1).encode()==blob(PARENT,path),'Publication selector changed beyond exact model7 dependency delegation')
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    require(changed=={OLD,path},'Earlier observer changed beyond model7 delegation')
    for name in ('mc-sol01-column-input.yml','mc-sol01-swp-reader.yml'):
        path='.github/workflows/'+name;actual=norm((ROOT/path).read_bytes()).decode()
        require(actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path),'Registered CI changed beyond model7 proof checkout')
    for name in ('pub-me-d1-transition-authority.yml','pub-me-d3-origin-authority.yml','pub-p2e06-reference-local-balance-scaling.yml','pub-p2e07-reference-cancellation-floor.yml','pub-p2e08-reference-valid-calibration-domain.yml','pub-p2e09-reference-threshold-freeze.yml','pub-p2e10-e0-broad-paired-matrix.yml','vq-reference.yml'):
        path='.github/workflows/'+name;require(norm((ROOT/path).read_bytes())==blob(PARENT,path),'Publication dependency workflow changed')
    path='.github/workflows/nomacro-water-snow-groundwater.yml'
    require(norm((ROOT/path).read_bytes())==blob(PORTABLE,path),'Actual portable model7 campaign changed')
    return True


def publication_dependencies_unchanged():
    guard_previous_source()
    if git('diff',PARENT,'HEAD','--','src','app/solute_project','tests/publication','docs/publication','docs/publications','docs/verification','docs/performance/evidence','tools/vq','tools/solute','tests/fsi/fsi04_real_headcalc_stubs.f90'):return False
    bridge=read(Path(__file__).with_name('model7_parent_bridge.json'))
    expected={p for p in bridge['added'] if p.startswith('reference/')}
    paths=git('diff','--no-renames','--name-status',PARENT,'HEAD','--','reference').decode().splitlines()
    return set(paths)=={'A\t'+p for p in expected} and all(blob('HEAD',p)==blob(RUNTIME,p) for p in expected)


def qualification():
    raw=(ROOT/QUAL).read_bytes();require(norm(raw)==blob(SEALED,QUAL),'Neutral model7 qualification changed');q=json.loads(raw)
    require((q['runtime'],q['predecessor'],q['independent_readers'])==(RUNTIME,PARENT,READERS),'Foreign model7 qualification source')
    require(q['status']=='NEUTRAL_MODEL7_CAPACITY_SATURATED_SEARCH_RAW_SCIENCE_PASS_PENDING_ADMISSION','Model7 neutral role promoted')
    for key in ('model7_admitted','implicit_nondefault_conductivity_admitted','AGE_admitted','other_hydraulic_models_admitted','broader_boundaries_admitted','RC3_changed','new_physical_state','native_interface_changed','tolerance_changed','physical_water_or_conductivity_changed','extra_fixed_absolute_global_water_prefix_is_owning_gate'):
        require(q[key] is False,'Unqualified model7 authority promoted: '+key)
    require((q['functional_completion'],q['whole_scientific_equivalence'],q['global_family_and_gap_counts'])==('PARTIAL','NOT_QUALIFIED','UNKNOWN'),'Whole historical family promoted')
    for key in ('daily_water_guard_cm','daily_CDE_guard_mg_cm2','every_prefix_CDE_guard_mg_cm2'):require(q[key]==1e-10,'Scientific model7 mass bound changed')
    for item in q['archives'].values():
        record=PROOF/item['record'];require(norm(record.read_bytes())==blob(SEALED,record.relative_to(ROOT).as_posix()),'Neutral model7 raw inventory changed')
        require((PROOF/item['archive']).stat().st_size==item['bytes'] and digest(PROOF/item['archive'])==item['sha256'],'Actual model7 original raw archive changed')
    return q


def inherited():
    path=PROOF/'FROST_IMPLICIT_ADMISSION_RAW_V1.zip';record=read(path.with_suffix('.json'))
    require(path.stat().st_size==record['bytes'] and digest(path)==record['sha256']=='00a9bd3c272593656ee9392c8fb309123226965ec8635e970da1586401c3dfd3','Inherited actual implicit Frost admission changed')
    with zipfile.ZipFile(path) as z:
        require(set(z.namelist())==set(record['members']),'Inherited implicit Frost raw inventory changed')
        for name,item in record['members'].items():
            raw=z.read(name);require(len(raw)==item['bytes'] and sha(raw)==item['sha256'],'Inherited actual implicit Frost raw changed')
    import implicit_frost_verify as previous
    functions=[node for node in ast.parse(blob(PARENT,OLD).decode()).body if isinstance(node,ast.FunctionDef) and node.name=='verify']
    require(len(functions)==1,'Missing actual admitted implicit Frost scientific body')
    namespace=dict(previous.__dict__);exec(compile(ast.Module(body=functions,type_ignores=[]),OLD,'exec'),namespace)
    result=namespace['verify']();require(result['status']=='BOUNDED_IMPLICIT_FROST_NATIVE2_SOURCE_RAW_ADMISSION_PASS','Inherited literal implicit Frost science failed')
    return dict(status='UNCHANGED_ACTUAL_IMPLICIT_FROST_AND_EARLIER_SCIENCE_REUSED',actual_canonical=PARENT,literal_original_verify_body_executed=True,observations=result,fresh_unaffected_full_periods=0)


def verify():
    import analytical_verify as analytical
    return analytical.verify()
    guard_previous_source();q=qualification();retained=inherited();actual=science.read(PROOF);unselected=postimages.read(PROOF)
    require(actual['full1096_contexts']==q['actual_full1096_contexts']==8 and actual['short35_contexts']==q['actual_short35_contexts']==8,'Actual model7 period denominator changed')
    require(actual['exact_cold_windows']==q['actual_exact_cold_windows']==80 and actual['compiled_native_refusals']==q['actual_compiled_native_refusals']==212 and actual['active_transaction_contexts']==q['actual_active_transaction_contexts']==8,'Actual model7 interface denominator changed')
    require(len(unselected['contexts'])==q['actual_unselected35_contexts']==q['actual_unselected_cold_windows']==8,'Actual unselected model7 denominator changed')
    return dict(status='BOUNDED_MODEL7_CAPACITY_SATURATED_SEARCH_SOURCE_RAW_ADMISSION_PASS',runtime=RUNTIME,actual=actual,unselected=unselected,inherited_unchanged_owners=retained,
        compiler_executions=0,model_executions=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',
        RC3_changed=False,model7_admitted=False,AGE_admitted=False,other_hydraulic_models_admitted=False,implicit_nondefault_conductivity_admitted=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
