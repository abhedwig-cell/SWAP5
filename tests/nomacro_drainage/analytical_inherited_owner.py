"""Exact source inverse and literal inherited model7 scientific owner.

The dependency projection below applies only after the complete new source
surface and original component producer have been independently inverted.
It neither changes raw evidence nor substitutes a model result.
"""
import ast
from functools import lru_cache
import json
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
from ordinary_pond_verify import git,blob,norm,sha,SURFACES
from ordinary_pond_evidence import require

PARENT='0abcdd5eb3a00327d505cdc897e92c50030ed3e7'
RUNTIME='70589c1f69649fdb5919b109e498aec2cf6f3fa9'
PORTABLE='a7d7fba5fa1e07aeeedbc8a1042665c9a900fecc'
OLD='tests/nomacro_drainage/model7_verify.py'
COMPONENT='tests/nomacro_drainage/hydraulic_constitutive_component.py'


def complete_inverse():
    require(not git('diff',RUNTIME,'--',*SURFACES),'Actual analytical compiler source differs from exact guarded runtime')
    bridge=json.loads(Path(__file__).with_name('analytical_parent_bridge.json').read_text())
    require((bridge['parent'],bridge['runtime'])==(PARENT,RUNTIME),'Foreign complete analytical source bridge')
    changed=git('diff','--name-status',PARENT,RUNTIME,'--',*SURFACES).decode().splitlines()
    require(set(changed)=={'M\t'+p for p in bridge['changes'] if p!=COMPONENT} and not bridge['added'],'Incomplete analytical source inverse')
    require(set(bridge['changes'])=={'app/hybrid_water/experimental_project.py','app/hybrid_water/model7_capacity.py','app/hybrid_water/model7_terminal_water.py',COMPONENT},'Unexpected analytical dependency surface')
    for path,edits in bridge['changes'].items():
        require(norm((ROOT/path).read_bytes())==blob(RUNTIME,path),'Actual analytical source or component changed: '+path)
        lines=blob(RUNTIME,path).decode().splitlines(True)
        for edit in reversed(edits):
            at=edit['runtime_line']-1;after=edit['after'].splitlines(True)
            require(lines[at:at+len(after)]==after,'Changed analytical source inverse');lines[at:at+len(after)]=edit['before'].splitlines(True)
        require(''.join(lines).encode()==blob(PARENT,path),'Complete admitted model7 parent changed')
    # Literal corrected capacity and search/receipt renderers remain unchanged.
    for path,names in (('app/hybrid_water/model7_capacity.py',('source',)),('app/hybrid_water/model7_terminal_water.py',('source','renderer'))):
        def functions(raw):return {n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
        before,after=functions(blob(PARENT,path)),functions(blob(RUNTIME,path))
        require(before['source']==after['source'],'Changed qualified physical numerical renderer')
        for name in set(before)&set(after):
            if name not in ('enabled','domain','metadata','analytical_models'):require(before[name]==after[name],'Changed qualified numerical implementation: '+name)
    return True


def literal(function,namespace):
    nodes=[n for n in ast.parse(blob(PARENT,OLD)).body if isinstance(n,ast.FunctionDef) and n.name==function]
    require(len(nodes)==1,'Missing literal admitted model7 function')
    exec(compile(ast.Module(body=nodes,type_ignores=[]),OLD,'exec'),namespace)
    return namespace[function]


def guard_inherited():
    complete_inverse()
    import model7_verify as previous
    namespace=dict(vars(previous));namespace['PORTABLE']=PORTABLE
    # Only these two exact historical dependency queries project through the
    # complete source inverse above. Every other Git query remains literal.
    def projected_git(*args):
        if args==('diff',previous.RUNTIME,'--',*SURFACES):
            require(not git('diff',previous.RUNTIME,PARENT,'--',*SURFACES),'Admitted model7 parent runtime no longer exact')
            return b''
        raw=git(*args)
        if args==('diff','--name-only',previous.PARENT,'--','tests'):
            names=raw.decode().splitlines();require(COMPONENT in names,'Missing checked component projection')
            raw=('\n'.join(n for n in names if n!=COMPONENT)+'\n').encode()
        return raw
    namespace['git']=projected_git
    return literal('guard_previous_source',namespace)()


def inherited_science():
    import model7_verify as previous
    namespace=dict(vars(previous));namespace['guard_previous_source']=guard_inherited
    result=literal('verify',namespace)()
    require(result['status']=='BOUNDED_MODEL7_CAPACITY_SATURATED_SEARCH_SOURCE_RAW_ADMISSION_PASS','Literal admitted model7 science failed')
    return dict(status='LITERAL_ACTUAL_ADMITTED_MODEL7_AND_EARLIER_SCIENCE_REUSED',actual_canonical=PARENT,
        literal_original_verify_body_executed=True,observations=result,fresh_unaffected_full_periods=0)
