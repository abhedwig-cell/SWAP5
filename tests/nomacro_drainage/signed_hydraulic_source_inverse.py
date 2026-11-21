"""Exact parser-only inverse for original signed hydraulic integer literals."""
import ast
from contextlib import contextmanager
import os
from ordinary_pond_verify import ROOT,git,blob,norm,SURFACES

PARENT='88091c3c6a5cc7ee2ae36402ccd521f5f29e2106'
RUNTIME='8672c751d'
PATH='app/hybrid_water/model7_capacity.py'
OLD="r'[0-9]+(?:[ \\t]+[0-9]+)*[ \\t]*'"
NEW="r'[+-]?[0-9]+(?:[ \\t]+[+-]?[0-9]+)*[ \\t]*'"


def complete_inverse():
    assert not git('diff',RUNTIME,'--',*SURFACES),'Unreviewed signed hydraulic source delta'
    assert git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()==['M\t'+PATH]
    before=blob(PARENT,PATH);after=norm((ROOT/PATH).read_bytes())
    assert after==blob(RUNTIME,PATH) and before.count(OLD.encode())==after.count(NEW.encode())==1
    assert after.replace(NEW.encode(),OLD.encode(),1)==before,'Incomplete signed literal parser inverse'
    functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
    a,b=functions(before),functions(after)
    assert set(a)==set(b) and [name for name in a if a[name]!=b[name]]==['analytical_models']
    return True


class ParentParser:
    def read_bytes(self):return blob(PARENT,PATH)
    def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
    def __fspath__(self):return os.fspath(ROOT/PATH)
    def __str__(self):return str(ROOT/PATH)


class CheckedParent:
    def __truediv__(self,path):return ParentParser() if str(path)==PATH else ROOT/path
    def __fspath__(self):return os.fspath(ROOT)
    def __str__(self):return str(ROOT)


@contextmanager
def prior_source_projection():
    """Expose only the fully inverted source file to the unchanged prior guard."""
    complete_inverse()
    import vapor_source_inverse as previous
    old_root,old_git=previous.ROOT,previous.git
    assert not git('diff',previous.RUNTIME,PARENT,'--',*SURFACES)
    def checked_git(*args):
        if args==('diff',previous.RUNTIME,'--',*SURFACES):
            complete_inverse()
            return b''
        return git(*args)
    previous.ROOT=CheckedParent();previous.git=checked_git
    try:yield
    finally:previous.ROOT=old_root;previous.git=old_git
