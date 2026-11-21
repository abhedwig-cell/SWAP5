"""Own default-model spellings with exact source inversion and literal prior science."""
import ast
from contextlib import ExitStack
import json
from pathlib import Path
import re
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive,SHA
from model7_search_science import Store
from default_model_grammar_source_inverse import complete_inverse,prior_source_projection,CheckedParent,PARENT,RUNTIME,CI,PATTERN
from default_model_grammar_science import read
import signed_hydraulic_verify as previous

SEALED='2792f2f8fd58e5d4b9e4059dc6b9e47b290c5f52'
ADMISSION='dad8dd91016ff4d59d266174ec92dae99ffceefe'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/signed_hydraulic_verify.py'
GUARD_HOOK='    import default_model_grammar_verify as grammar\n    return grammar.guard_previous_source()\n'
VERIFY_HOOK='    import default_model_grammar_verify as grammar\n    return grammar.verify()\n'
STRIP_HOOK='    import default_model_grammar_verify as grammar\n    return grammar.strip_current_evidence(text)\n'
PUBLICATION_HOOK='    import default_model_grammar_verify as grammar\n    return grammar.publication_dependencies_unchanged()\n'
PARSERS=('default_model_grammar_source_inverse.py','default_model_grammar_science.py','default_model_grammar_postimages.py','default_model_grammar_frontend_controls.py','default_model_grammar_preserve.py')


def literal(name,namespace):
    body=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert len(body)==1;exec(compile(ast.Module(body=body,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
    namespace=dict(vars(previous),ROOT=CheckedParent())
    literal('guard_previous_source',namespace)
    return namespace


def guard_previous_source():
    complete_inverse()
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Frozen default-model scientific observer changed'
    raw=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
    assert raw.encode()==blob(PARENT,OLD),'Earlier signed scientific body changed beyond exact delegation'
    existing=set(git('ls-tree','-r','--name-only',PARENT,'--','tests').decode().splitlines())
    changed=set(git('diff','--name-only',PARENT,'--','tests').decode().splitlines())&existing
    assert changed=={OLD},changed
    for path in CI:
        current=norm((ROOT/path).read_bytes()).decode()
        assert current.count(PATTERN)==1 and current.replace(PATTERN,'',1).encode()==blob(PARENT,path)
    with prior_source_projection():assert prior_namespace()['guard_previous_source']()
    return True


def strip_current_evidence(text):
    if PATTERN in text:assert text.count(PATTERN)==1;text=text.replace(PATTERN,'',1)
    return literal('strip_current_evidence',dict(vars(previous)))(text)


def publication_dependencies_unchanged():
    guard_previous_source()
    with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def frontend_records(store):
    root='profiles/default-model-grammar-frontend-controls-v1/'
    q=json.loads(store.get(root+'RESULT.json'))
    assert q['status']=='SIX_ACTUAL_DEFAULT_MODEL_DOMAINS_42_SPELLING_EQUIVALENCES_48_NONDEFAULT_REFUSALS_OR_UNSELECTED_PASS' and len(q['checks'])==90
    assert not git('diff',RUNTIME,q['source'],'--',*SURFACES)
    counts={}
    for item in q['checks']:
        folder=store.view('profiles/'+item['input_root'].replace('\\','/').split('/evidence/',1)[1])
        for name,digest in item['input_inventory']:assert SHA((folder/name).read_bytes())==digest
        text=(folder/'swap.swp').read_text(encoding='cp1252')
        active='\n'.join(line.split('!',1)[0] for line in text.splitlines() if not line.lstrip().startswith('*'))
        models=re.findall(r'(?mi)^[ \t]*IHWCKMODEL[ \t]*=[ \t]*([^\r\n]+)',active)
        selected=len(models)<=1 and (not models or re.fullmatch(r'\+?0*1(?:[ \t]+\+?0*1)*[ \t]*',models[0].strip()) is not None)
        positive=item['role']=='EXACT_EXISTING_UNSIGNED_SELECTION';assert selected==positive
        assert bool(item['selected'])==positive
        counts[item['role']]=counts.get(item['role'],0)+1
    assert counts=={'EXACT_EXISTING_UNSIGNED_SELECTION':42,'OUTSIDE_DEFAULT_MODEL1_REMAINS_UNSELECTED_OR_REFUSED':48}
    original=json.loads(store.get('profiles/original-signed-default-reader-v1/RESULT.json'))
    assert original['status']=='ORIGINAL_DEFAULT_MODEL1_SIGN_AND_LEADING_ZERO_READER_SPELLINGS_ACCEPTED_ZERO_MODEL_DAYS'
    assert len(original['compiled_reader_startups'])==5 and original['accepted_model_days']==original['compiler_executions']==0
    assert all(item['actual_original_reader_accepted'] for item in original['compiled_reader_startups'])
    return dict(status=q['status'],checks=90,counts=counts,original_reader_startups=5,original_reader_accepted_model_days=0)


def verify():
    guard_previous_source()
    for name in ('HYDRAULIC_DEFAULT_MODEL_GRAMMAR_QUALIFICATION.json','HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1.json'):
        path='integration/f-ci/nomacro-complete01/'+name;assert norm((ROOT/path).read_bytes())==blob(SEALED,path)
    qual=json.loads((PROOF/'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_QUALIFICATION.json').read_text())
    for key in ('canonical_admission','physical_equations_changed','new_physical_state','native_interface_changed','mass_or_convergence_limits_changed','whole_historical_family_closed','RC3_changed'):assert qual[key] is False
    with ExitStack() as stack:
        current=Archive(PROOF,'HYDRAULIC_DEFAULT_MODEL_GRAMMAR_WINDOWS_RAW_V1',stack)
        assert current.record['sha256']==qual['raw_sha256']=='37547bbeb5696de11dba78915e47e05a02428e0f1975ee76ff06d9be045f861e'
        actual=read(current.view('profiles'),store=current);controls=frontend_records(current)
        admission=Store(PROOF,'HYDRAULIC_SIGNED_SELECTORS_ADMISSION_RAW_V1',stack)
        path='integration/f-ci/nomacro-complete01/HYDRAULIC_SIGNED_SELECTORS_ADMISSION_RAW_V1.json'
        assert norm((ROOT/path).read_bytes())==blob(ADMISSION,path)
        record=json.loads((ROOT/path).read_text());assert record['canonical']=='0c3d905102672354e7f8df4212e8075d7c133e31' and record['sha256']=='6bfa0cef9a729b874d4f84f4992897fd06ab2225c0d388dd00b8c7a5fc1916cd'
        for name in admission.names:admission.get(name)
    with prior_source_projection():prior=literal('verify',prior_namespace())()
    assert prior['status']=='BOUNDED_ORIGINAL_SIGNED_HYDRAULIC_CONFIGURATION_SOURCE_RAW_NATIVE_PASS'
    return dict(status='BOUNDED_ORIGINAL_DEFAULT_MODEL_INTEGER_GRAMMAR_SOURCE_RAW_NATIVE_PASS',runtime=RUNTIME,targeted=actual,frontend=controls,
        inherited_actual_signed_vapor_and_earlier_science=prior,new_full_periods=0,compiler_executions=0,model_executions=0,
        canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
