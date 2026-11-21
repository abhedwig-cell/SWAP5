"""Own signed input dispatch while executing literal previously admitted science."""
import ast
from contextlib import ExitStack
import json
from pathlib import Path
import sys
import types

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_verify import blob,norm,git,SURFACES
from analytical_hydraulic_archives import Archive
from model7_search_science import Store
from signed_hydraulic_source_inverse import complete_inverse,prior_source_projection,CheckedParent,PARENT,RUNTIME,CI,PATTERN
from signed_hydraulic_postimages import read
from signed_hydraulic_inherited_owner import projection as initial_ubuntu_projection
import vapor_verify as previous

SEALED='011c0eef0'
READERS='9f977863a5297776c68c0011e0726e989d66aaa5'
ADMISSION='c7c14b359820f9ebb96c73dbddd2bc8031ed1569'
PROOF=ROOT/'integration/f-ci/nomacro-complete01'
OLD='tests/nomacro_drainage/vapor_verify.py'
GUARD_HOOK='    import signed_hydraulic_verify as signed\n    return signed.guard_previous_source()\n'
VERIFY_HOOK='    import signed_hydraulic_verify as signed\n    return signed.verify()\n'
STRIP_HOOK='    import signed_hydraulic_verify as signed\n    return signed.strip_current_evidence(text)\n'
PUBLICATION_HOOK='    import signed_hydraulic_verify as signed\n    return signed.publication_dependencies_unchanged()\n'
PARSERS=('signed_hydraulic_source_inverse.py','signed_hydraulic_postimages.py','signed_hydraulic_parser_controls.py','signed_hydraulic_preserve.py','signed_hydraulic_inherited_owner.py')


def literal(name,namespace):
    body=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==name]
    assert len(body)==1;exec(compile(ast.Module(body=body,type_ignores=[]),OLD,'exec'),namespace);return namespace[name]


def prior_namespace():
    namespace=dict(vars(previous),ROOT=CheckedParent())
    literal('guard_previous_source',namespace)
    return namespace


def guard_previous_source():
    import default_model_grammar_verify as grammar
    return grammar.guard_previous_source()
    complete_inverse()
    for name in PARSERS:
        path='tests/nomacro_drainage/'+name
        assert norm((ROOT/path).read_bytes())==blob(READERS,path),'Frozen signed-selector observer changed'
    raw=norm((ROOT/OLD).read_bytes()).decode()
    for hook in (GUARD_HOOK,VERIFY_HOOK,STRIP_HOOK,PUBLICATION_HOOK):
        assert raw.count(hook)==1;raw=raw.replace(hook,'',1)
    assert raw.encode()==blob(PARENT,OLD),'Prior vapor owner changed beyond exact delegation'
    for path in CI:
        actual=norm((ROOT/path).read_bytes()).decode()
        assert actual.count(PATTERN)==1 and actual.replace(PATTERN,'',1).encode()==blob(PARENT,path)
    with prior_source_projection():assert prior_namespace()['guard_previous_source']()
    return True


def strip_current_evidence(text):
    import default_model_grammar_verify as grammar
    return grammar.strip_current_evidence(text)
    if PATTERN in text:assert text.count(PATTERN)==1;text=text.replace(PATTERN,'',1)
    return literal('strip_current_evidence',dict(vars(previous)))(text)


def publication_dependencies_unchanged():
    import default_model_grammar_verify as grammar
    return grammar.publication_dependencies_unchanged()
    guard_previous_source()
    with prior_source_projection():return literal('publication_dependencies_unchanged',prior_namespace())()


def parser_controls(store):
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    import model7_capacity as capacity
    import model7_terminal_water as terminal
    q=json.loads(store.get('profiles/signed-hydraulic-parser-controls-v1/RESULT.json'))
    assert q['status']=='ACTUAL_SIGNED_HYDRAULIC_PARSER_AND_UNCHANGED_UNSIGNED_DOMAIN_PASS' and q['cases']==len(q['checks'])==38
    parser=types.FunctionType(capacity.analytical_models.__code__,dict(capacity.analytical_models.__globals__,Path=lambda value:value))
    enabled=types.FunctionType(capacity.enabled.__code__,dict(capacity.enabled.__globals__,analytical_models=parser))
    trial=types.FunctionType(terminal.enabled.__code__,dict(terminal.enabled.__globals__,Path=lambda value:value))
    saved=capacity.analytical_models;capacity.analytical_models=parser
    try:
        for index,item in enumerate(q['checks']):
            project=types.SimpleNamespace(input_directory=store.view(f'profiles/signed-hydraulic-parser-controls-v1/{index}'),macro=False,age=False,original_output=True,time_step_policy='original-adaptive-day-seed-v1')
            actual=parser(project);assert (list(actual) if actual is not None else None)==item['parsed']
            assert enabled(project)==item['capacity'] and trial(project)==item['terminal']
    finally:capacity.analytical_models=saved
    return dict(status=q['status'],cases=38,actual_parser_bytecode_executed_on_original_archive_input=True)


def verify():
    import default_model_grammar_verify as grammar
    return grammar.verify()
    guard_previous_source()
    for name in ('HYDRAULIC_SIGNED_SELECTORS_QUALIFICATION.json','HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1.json'):
        path='integration/f-ci/nomacro-complete01/'+name
        assert norm((ROOT/path).read_bytes())==blob(SEALED,path),'Neutral signed-selector evidence changed'
    q=json.loads((PROOF/'HYDRAULIC_SIGNED_SELECTORS_QUALIFICATION.json').read_text())
    assert not q['canonical_admission'] and not q['physical_equations_changed'] and not q['native_interface_changed'] and not q['mass_limits_changed']
    with ExitStack() as stack:
        current=Archive(PROOF,'HYDRAULIC_SIGNED_SELECTORS_WINDOWS_RAW_V1',stack)
        assert current.record['sha256']==q['raw_sha256']=='f01d7e78e83829eaba166fb13e25730f1c0a0efa7a84b4d43e4fec496e50c0c9'
        provider=Archive(PROOF,'HYDRAULIC_VAPOR_WINDOWS_WATER_RAW_V1',stack)
        class Reference:
            def __truediv__(self,path):
                assert path.startswith('build/');return provider.view('original-provider-build/'+path[6:])
        actual=read(current.view('profiles'),Reference(),store=current);controls=parser_controls(current)
        admission=Store(PROOF,'HYDRAULIC_VAPOR_ADMISSION_RAW_V1',stack)
        path='integration/f-ci/nomacro-complete01/HYDRAULIC_VAPOR_ADMISSION_RAW_V1.json'
        assert norm((ROOT/path).read_bytes())==blob(ADMISSION,path)
        assert json.loads((ROOT/path).read_text())['canonical']=='277c6135ff4250a04ee3e3330530dc0895e0fc7d'
        for name in admission.names:admission.get(name)
    with prior_source_projection(),initial_ubuntu_projection():prior=literal('verify',prior_namespace())()
    assert prior['status']=='BOUNDED_ORIGINAL_PER_LAYER_VAPOR_KELVIN_LOOKUP_SOURCE_RAW_NATIVE_PASS'
    return dict(status='BOUNDED_ORIGINAL_SIGNED_HYDRAULIC_CONFIGURATION_SOURCE_RAW_NATIVE_PASS',runtime=git('rev-parse',RUNTIME).decode().strip(),
        targeted=actual,parser_controls=controls,inherited_actual_vapor_and_earlier_science=prior,
        inherited_initial_Ubuntu_source_guard='Actual current HEAD decoder+parser diff checked; complete parser inverse; literal scientific body unchanged',
        compiler_executions=0,model_executions=0,new_full_periods=0,canonical_admission='OWNED_BY_ACTUAL_MERGE_RECEIPT',
        functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED',global_family_and_gap_counts='UNKNOWN',RC3_changed=False)


if __name__=='__main__':print(json.dumps(verify(),indent=2))
