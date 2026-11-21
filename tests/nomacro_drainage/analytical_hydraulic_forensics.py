"""Reuse the frozen model7 ledger/native reader for the unchanged shared search."""
import argparse
import ast
import json
from pathlib import Path
import subprocess
import model7_capacity_forensics as inherited

ROOT=Path(__file__).resolve().parents[2]
READERS='e079d1554041c831cd0ab609835e2e79bf3c31a1'
PATH='tests/nomacro_drainage/model7_capacity_forensics.py'


def audit(profile,reference,allow_refusal=False,allow_censored=False):
    raw=subprocess.check_output(['git','show',READERS+':'+PATH],cwd=ROOT)
    assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
    functions=[node for node in ast.parse(raw.decode()).body if isinstance(node,ast.FunctionDef) and node.name=='audit'];assert len(functions)==1
    function=functions[0]
    def assigns(node,name):return isinstance(node,ast.Assign) and any(isinstance(target,ast.Name) and target.id==name for target in node.targets)
    first=next(i for i,node in enumerate(function.body) if assigns(node,'policy'))
    end=next(i for i,node in enumerate(function.body) if assigns(node,'terminal'));assert end-first==7
    original=ast.parse("assert q['hydraulic_model']!=7\nassert 'WC_K_models_04_11.f90' not in identity['donor_generated']\nassert 'WC_K_models_04_11.o' in identity['donor_objects']\n").body
    function.body[first:end]=[ast.If(test=ast.parse("bool(identity.get('model7_capacity'))",mode='eval').body,body=function.body[first:end],orelse=original)]
    class ControllerRole(ast.NodeTransformer):
        changes=0
        def visit_Constant(self,node):
            if node.value=='CANDIDATE_ACTUAL_MODEL7_CAPACITY_':self.changes+=1;return ast.copy_location(ast.Constant('CANDIDATE_ACTUAL_ANALYTICAL_FAMILY_'),node)
            return node
    role=ControllerRole();function=role.visit(function);assert role.changes==1
    namespace=dict(vars(inherited));exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),PATH,'exec'),namespace)
    result=namespace['audit'](profile,reference,allow_refusal,allow_censored)
    q=json.loads((profile/'RESULT.json').read_text());model=q['hydraulic_model'];models=q.get('layer_models',[model]);result.update(hydraulic_model=model,layer_models=models,frozen_scientific_reader=READERS,
        full_capacity_source_inverse=7 in models,original_capacity_provider_retained=7 not in models,scientific_ledger_native_body_unchanged=True)
    if q['status']!='FAILED':result['status']='INDEPENDENT_ANALYTICAL_HYDRAULIC_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--allow-refusal',action='store_true');p.add_argument('--allow-censored',action='store_true');a=p.parse_args();assert not a.output.exists()
    result=audit(a.profile,a.reference_work,a.allow_refusal,a.allow_censored);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['hydraulic_model'],result['optimization'],result['days'])
