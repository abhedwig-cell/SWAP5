"""Invert only four default-model lexical predicates on the actual source tree."""
import ast
from contextlib import contextmanager
import os
from ordinary_pond_verify import ROOT,git,blob,norm,SURFACES

PARENT='7862c1b3866a0ea2e3652a3b3d153c45714cea66'
RUNTIME='a5038b98597e9ff83364aa454b7250387c3716be'
CHANGED={
    'app/hybrid_water/implicit_conductivity.py':'selection',
    'app/hybrid_water/implicit_groundwater_state.py':'enabled',
    'app/hybrid_water/snow_undrained.py':'selection',
    'app/hybrid_water/snow_water_groundwater.py':'selection'}
OLD="r'1(?:[ \\t]+1)*[ \\t]*'"
NEW="r'\\+?0*1(?:[ \\t]+\\+?0*1)*[ \\t]*'"
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/*DEFAULT_MODEL_GRAMMAR*\n'


def complete_inverse():
    assert not git('diff',RUNTIME,'--',*SURFACES),'Unreviewed default model grammar source delta'
    assert set(git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines())=={'M\t'+p for p in CHANGED}
    for path,function in CHANGED.items():
        before=blob(PARENT,path);after=norm((ROOT/path).read_bytes())
        assert after==blob(RUNTIME,path) and before.count(OLD.encode())==after.count(NEW.encode())==1
        assert after.replace(NEW.encode(),OLD.encode(),1)==before,'Incomplete default-model lexical source inverse'
        functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
        a,b=functions(before),functions(after)
        assert set(a)==set(b) and [name for name in a if a[name]!=b[name]]==[function]
    return True


class FrozenFile:
    def __init__(self,path):self.path=path
    def read_bytes(self):return blob(PARENT,self.path)
    def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
    def __fspath__(self):return os.fspath(ROOT/self.path)
    def __str__(self):return str(ROOT/self.path)


class CheckedParent:
    def __truediv__(self,path):return FrozenFile(str(path)) if str(path) in {*CHANGED,*CI} else ROOT/path
    def __fspath__(self):return os.fspath(ROOT)
    def __str__(self):return str(ROOT)


def initial_source_inverse():
    complete_inverse()
    import signed_hydraulic_inherited_owner as previous
    initial=previous.original.INITIAL;decoder=previous.DECODER;model=previous.PATH
    actual=git('diff','--name-only',initial,'HEAD','--',*SURFACES).decode().splitlines()
    assert actual==sorted({decoder,model,*CHANGED}),actual
    assert git('diff','--name-only',initial,PARENT,'--',*SURFACES).decode().splitlines()==[decoder,model]
    assert norm((ROOT/decoder).read_bytes())==blob('daba94800',decoder)
    assert norm((ROOT/model).read_bytes())==blob(PARENT,model)
    return True


@contextmanager
def prior_source_projection():
    complete_inverse()
    import signed_hydraulic_source_inverse as previous
    import signed_hydraulic_inherited_owner as initial
    old_root,old_git,old_initial=previous.ROOT,previous.git,initial.initial_source_inverse
    for path in CI:
        raw=norm((ROOT/path).read_bytes()).decode()
        assert raw.count(PATTERN)<=1 and raw.replace(PATTERN,'').encode()==blob(PARENT,path)
    assert not git('diff',previous.RUNTIME,PARENT,'--',*SURFACES)
    def checked_git(*args):
        if args==('diff',previous.RUNTIME,'--',*SURFACES):complete_inverse();return b''
        return git(*args)
    previous.ROOT=CheckedParent();previous.git=checked_git;initial.initial_source_inverse=initial_source_inverse
    try:yield
    finally:previous.ROOT=old_root;previous.git=old_git;initial.initial_source_inverse=old_initial
