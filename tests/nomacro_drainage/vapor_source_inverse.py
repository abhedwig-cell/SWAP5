"""Check the whole bounded vapor dependency surface against its actual parent."""
import ast
import json
from pathlib import Path
from ordinary_pond_verify import ROOT,git,blob,norm,sha,SURFACES

PARENT='5b8373d0809c25e24415f4d5dc01784a92ff481e'
RUNTIME='daba94800'
MODIFIED={'app/hybrid_water/'+name for name in ('cde_native_receipt.py','daily_coupling.py','daily_host.py','experimental_project.py','micro_lookup_state.py','model7_capacity.py','original_output.py')}
ADDED={'app/hybrid_water/hydraulic_vapor.py','app/hybrid_water/hydraulic_vapor_native.f90'}|{
    'reference/swap-4.3.1/hydraulic-corrections/VAPOR-KELVIN-SIGN01/'+name for name in ('README.md','manifest.json','WC_K_models_04_11.f90','WC_K_models_04_11.capacity7.f90')}


def complete_inverse():
    assert not git('diff',RUNTIME,'--',*SURFACES),'Unreviewed actual vapor source delta'
    bridge=json.loads(Path(__file__).with_name('vapor_parent_bridge.json').read_text())
    assert bridge['parent']==PARENT and git('rev-parse',RUNTIME).decode().strip()==bridge['runtime']
    assert set(bridge['changes'])==MODIFIED and set(bridge['added'])==ADDED
    changes=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    assert set(changes)=={'M\t'+path for path in MODIFIED}|{'A\t'+path for path in ADDED}
    for path,edits in bridge['changes'].items():
        current=norm((ROOT/path).read_bytes());assert current==blob(RUNTIME,path)
        lines=current.decode().splitlines(True)
        for item in reversed(edits):
            at=item['runtime_line']-1;after=item['after'].splitlines(True)
            assert lines[at:at+len(after)]==after
            lines[at:at+len(after)]=item['before'].splitlines(True)
        assert ''.join(lines).encode()==blob(PARENT,path),'Incomplete original analytical parent inverse'
    for path,digest in bridge['added'].items():
        assert norm((ROOT/path).read_bytes())==blob(RUNTIME,path) and sha(blob(RUNTIME,path))==digest
    # These qualified renderers are composed literally; their implementation
    # is not covered merely by an unrelated source digest.
    for path,names in (('app/hybrid_water/micro_lookup_state.py',('render',)),('app/hybrid_water/model7_capacity.py',('source',))):
        functions=lambda raw:{node.name:ast.dump(node,include_attributes=False) for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef)}
        before,after=functions(blob(PARENT,path)),functions(blob(RUNTIME,path))
        for name in names:assert before[name]==after[name]
    for path in ('app/hybrid_water/oxygen_lookup_state.py','app/hybrid_water/history_top_state.py','app/hybrid_water/model7_terminal_water.py'):
        assert blob(PARENT,path)==blob(RUNTIME,path)==norm((ROOT/path).read_bytes())
    return True
