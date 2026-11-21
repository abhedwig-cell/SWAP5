"""Read-only exact dispatch projection for eight admitted unselected contexts."""
import ast
from contextlib import ExitStack
import json
from pathlib import Path
from types import SimpleNamespace
import builtins
import sys
from model7_search_science import Store,SHA
from analytical_inherited_owner import PARENT,ROOT,blob,complete_inverse


def read(proof):
    sys.path.insert(0,str(ROOT/'app/hybrid_water'))
    complete_inverse();results=[]
    def module(path,original,capacity=None):
        namespace={'__file__':str(ROOT/path),'__name__':'bound_dispatch'}
        imports=dict(vars(builtins));normal=__import__
        def imported(name,*args,**kwargs):
            if name=='model7_capacity':return capacity
            return normal(name,*args,**kwargs)
        imports['__import__']=imported;namespace['__builtins__']=imports
        nodes=ast.parse(blob(PARENT,path) if original else (ROOT/path).read_bytes())
        # Execute imports/constants and literal functions, without any model.
        exec(compile(nodes,path,'exec'),namespace);namespace['Path']=lambda value:value
        return SimpleNamespace(**namespace)
    capacities={old:module('app/hybrid_water/model7_capacity.py',old) for old in (True,False)}
    terminals={old:module('app/hybrid_water/model7_terminal_water.py',old,capacities[old]) for old in (True,False)}
    with ExitStack() as stack:
        store=Store(proof,'HYDRAULIC_MODEL7_UNSELECTED_WINDOWS_RAW_V1',stack)
        inputs=json.loads(store.get('INPUT_PROJECTION_V1.json'))
        for opt in ('O0','O2'):
            q=json.loads(store.get(f'profiles/model7-unselected-postimages-{opt}-v4/RESULT.json'))
            for name,item in q['profiles'].items():
                inventory=inputs[item['input_root']];directory=store.view(inventory['archive_prefix'])
                for path,digest in inventory['files'].items():assert SHA((directory/path).read_bytes())==digest
                project=SimpleNamespace(input_directory=directory,macro=False,age=False,original_output=True,time_step_policy=item['time_policy'])
                for old in (True,False):
                    assert capacities[old].enabled(project) is False
                    assert terminals[old].enabled(project) is False
                results.append(dict(context=name,optimization=opt,input_inventory=inventory['files'],capacity_and_trial_guard_unselected_before_and_after=True))
    assert len(results)==8
    return dict(status='ACTUAL_EIGHT_ADMITTED_INPUT_DISPATCHES_UNSELECTED_BEFORE_AND_AFTER_COMPLETE_SOURCE_INVERSE',contexts=results,
        unchanged_compiler_source_surface=True,inherited_actual_compiled_postimages_reused=True,new_model_periods=0,compiler_executions=0,public_admission=False)
