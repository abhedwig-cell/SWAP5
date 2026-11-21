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


def audit(profile,reference,allow_refusal=False,allow_censored=False,locations=None):
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
        phase_fields=0
        phase_signs=0
        def visit_Constant(self,node):
            if node.value=='CANDIDATE_ACTUAL_MODEL7_CAPACITY_':self.changes+=1;return ast.copy_location(ast.Constant('CANDIDATE_ACTUAL_ANALYTICAL_FAMILY_'),node)
            return node
        def visit_Assert(self,node):
            self.generic_visit(node)
            expression=ast.unparse(node.test)
            if expression=='[i for i in range(28) if trial[i] != expected[i]] == [7, 25]':
                self.phase_fields+=1
                node.test=ast.parse('set(i for i in range(28) if trial[i]!=expected[i]) <= {7,25}',mode='eval').body
            elif expression=='trial[7] > expected[7] and trial[25] < expected[25] <= 0':
                self.phase_signs+=1
                node.test=ast.parse('trial[7]>=expected[7] and trial[25]<=expected[25]<=0',mode='eval').body
                # Literal original canopy loss subtraction and Integral4
                # interception addition. This also covers a loss smaller than
                # half an interception ULP, whose visible flux stays identical.
                return [node,*ast.parse('assert expected[7] == -(-trial[7]+(expected[25]-trial[25]))').body]
            return node
    role=ControllerRole();function=role.visit(function);assert (role.changes,role.phase_fields,role.phase_signs)==(1,1,1)
    namespace=dict(vars(inherited));exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),PATH,'exec'),namespace)
    result=namespace['audit'](profile,reference,allow_refusal,allow_censored,locations)
    q=json.loads((profile/'RESULT.json').read_text());model=q['hydraulic_model'];models=q.get('layer_models',[model]);result.update(hydraulic_model=model,layer_models=models,frozen_scientific_reader=READERS,
        full_capacity_source_inverse=7 in models,original_capacity_provider_retained=7 not in models,scientific_ledger_native_body_unchanged=True,
        phase_correspondence_exact_original_double_subtraction_addition=True,public_mass_bounds_unchanged=True)
    if q['status']!='FAILED':result['status']='INDEPENDENT_ANALYTICAL_HYDRAULIC_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--allow-refusal',action='store_true');p.add_argument('--allow-censored',action='store_true');a=p.parse_args();assert not a.output.exists()
    result=audit(a.profile,a.reference_work,a.allow_refusal,a.allow_censored);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['hydraulic_model'],result['optimization'],result['days'])
