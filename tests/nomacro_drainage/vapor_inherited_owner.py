"""Execute literal admitted analytical science after the complete vapor inverse."""
import ast
from contextlib import contextmanager
from pathlib import Path
import os
from ordinary_pond_verify import ROOT,git,blob,norm,SURFACES
from vapor_source_inverse import complete_inverse,PARENT,RUNTIME,MODIFIED

OLD='tests/nomacro_drainage/analytical_verify.py'
MODEL7='tests/nomacro_drainage/model7_verify.py'
PORTABLE='afac661b04e0224f89b6d54060fdc9993f413eec'
PATTERN='            /integration/f-ci/nomacro-complete01/*VAPOR*\n'
GUARD_HOOK='    import vapor_verify as vapor\n    return vapor.guard_previous_source()\n'
VERIFY_HOOK='    import vapor_verify as vapor\n    return vapor.verify()\n'
PROJECTION_HOOK='    import vapor_verify as vapor\n    text=vapor.strip_current_evidence(text)\n'
PUBLICATION_HOOK='    import vapor_verify as vapor\n    return vapor.publication_dependencies_unchanged()\n'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')


def hook_inverse(path,hooks):
    current=norm((ROOT/path).read_bytes()).decode()
    for hook in hooks:
        if hook in current:
            assert current.count(hook)==1;current=current.replace(hook,'',1)
    assert current.encode()==blob(PARENT,path),'Earlier scientific owner changed beyond exact vapor delegation'


class FrozenFile:
    def __init__(self,path):self.path=path
    def read_bytes(self):return blob(PARENT,self.path)
    def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
    def __str__(self):return str(ROOT/self.path)
    def __fspath__(self):return str(self)


class CheckedParent:
    def __truediv__(self,path):
        if str(path) in MODIFIED|{OLD,MODEL7,WORKFLOW,*CI}:return FrozenFile(str(path))
        return ROOT/path
    def __fspath__(self):return os.fspath(ROOT)
    def __str__(self):return str(ROOT)


@contextmanager
def projection():
    complete_inverse()
    hook_inverse(OLD,(GUARD_HOOK,VERIFY_HOOK,PROJECTION_HOOK))
    hook_inverse(MODEL7,(PUBLICATION_HOOK,))
    for path in CI:
        actual=norm((ROOT/path).read_bytes()).decode()
        if PATTERN in actual:
            assert actual.count(PATTERN)==1;actual=actual.replace(PATTERN,'',1)
        assert actual.encode()==blob(PARENT,path)
    assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW)
    import analytical_inherited_owner as previous
    import model7_verify as model7
    old_root,old_git,model_root=previous.ROOT,previous.git,model7.ROOT
    def projected_git(*args):
        if args==('diff',previous.RUNTIME,'--',*SURFACES):
            assert not git('diff',previous.RUNTIME,PARENT,'--',*SURFACES)
            return b''
        return git(*args)
    previous.ROOT=CheckedParent();previous.git=projected_git;model7.ROOT=CheckedParent()
    try:yield previous,projected_git
    finally:previous.ROOT=old_root;previous.git=old_git;model7.ROOT=model_root


def literal(name,namespace):
    functions=[node for node in ast.parse(blob(PARENT,OLD)).body if isinstance(node,ast.FunctionDef) and node.name==name]
    assert len(functions)==1
    exec(compile(ast.Module(body=functions,type_ignores=[]),OLD,'exec'),namespace)
    return namespace[name]


def guard_inherited():
    import analytical_verify as previous
    with projection() as (inherited,projected_git):
        namespace=dict(vars(previous),ROOT=CheckedParent(),git=projected_git,inherited=inherited)
        return literal('guard_previous_source',namespace)()


def inherited_science():
    from contextlib import ExitStack
    from model7_search_science import Store
    with ExitStack() as stack:
        admission=Store(ROOT/'integration/f-ci/nomacro-complete01','HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1',stack)
        import json
        record=json.loads((ROOT/'integration/f-ci/nomacro-complete01/HYDRAULIC_ANALYTICAL_ADMISSION_RAW_V1.json').read_text())
        assert record['canonical']==PARENT and record['sha256']=='de2809557fc94f68df90ce7c7b3f3b3868540b13fa79794b8f625bbe4a493c9d'
        for name in admission.names:admission.get(name)
    import analytical_verify as previous
    with projection() as (inherited,projected_git):
        namespace=dict(vars(previous),ROOT=CheckedParent(),git=projected_git,inherited=inherited,guard_previous_source=guard_inherited)
        result=literal('verify',namespace)()
    assert result['status']=='BOUNDED_ORIGINAL_EXPLICIT_ANALYTICAL_FAMILY_SOURCE_RAW_NATIVE_PASS'
    return dict(status='LITERAL_ACTUAL_ADMITTED_ANALYTICAL_AND_EARLIER_SCIENCE_REUSED',actual_canonical=PARENT,
        literal_original_verify_body_executed=True,observations=result,fresh_unaffected_full_periods=0)
