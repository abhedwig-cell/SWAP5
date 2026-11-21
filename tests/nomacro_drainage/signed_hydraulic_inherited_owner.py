"""Extend only the initial Ubuntu source predicate by the checked parser inverse."""
import ast
from contextlib import contextmanager
from ordinary_pond_verify import ROOT,git,blob,norm,SURFACES
from signed_hydraulic_source_inverse import complete_inverse,PARENT,PATH
import vapor_hydraulic_resume as original
import vapor_ubuntu_science as ubuntu

OLD='tests/nomacro_drainage/vapor_hydraulic_resume.py'
DECODER='app/hybrid_water/cde_native_receipt.py'


def initial_source_inverse():
    complete_inverse()
    # Observe the actual current HEAD. No producer, checkout identity or Git
    # response is substituted. The extra Python parser delta is fully inverted.
    actual=git('diff','--name-only',original.INITIAL,'HEAD','--',*SURFACES).decode().splitlines()
    assert actual==[DECODER,PATH],actual
    assert git('diff','--name-only',original.INITIAL,PARENT,'--',*SURFACES).decode().splitlines()==[DECODER]
    assert blob(original.INITIAL,PATH)==blob(PARENT,PATH)
    assert norm((ROOT/DECODER).read_bytes())==blob('daba94800',DECODER)
    return True


def checked_initial_reader():
    raw=blob(PARENT,OLD);assert norm((ROOT/OLD).read_bytes())==raw
    functions=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='read_initial']
    assert len(functions)==1;function=functions[0]
    expected=ast.parse("changed=subprocess.check_output(['git','diff','--name-only',INITIAL,'HEAD','--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()\nassert changed==['app/hybrid_water/cde_native_receipt.py'],changed\n").body
    assert [ast.dump(n,include_attributes=False) for n in function.body[2:4]]==[ast.dump(n,include_attributes=False) for n in expected]
    # Every ledger, native, source, decoder and scientific assertion after
    # these two source-predicate statements stays literally unchanged.
    function.body[2:4]=ast.parse('initial_source_inverse()').body
    namespace=dict(vars(original),initial_source_inverse=initial_source_inverse)
    exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),OLD,'exec'),namespace)
    return namespace['read_initial']


@contextmanager
def projection():
    initial_source_inverse();saved=ubuntu.read_initial
    ubuntu.read_initial=checked_initial_reader()
    try:yield
    finally:ubuntu.read_initial=saved
