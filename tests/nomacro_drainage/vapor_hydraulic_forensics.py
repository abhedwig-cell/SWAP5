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


VAPOR_TARGET='9ad54cbf7887b0a6dc6555fa56ddd5486a5d96829af1bd437e0e8f341ca66fa8'
JOINT_TARGET='ddaf8cd9d1effe893fca68d92fbd242285bce6de50ba84fb864f22978df49861'
CAPACITY_PARENT='7910cd29c045037778bfffdc7e40a77802d70fb477e0afa78be426776bd26e27'


def vapor_liquid_source(source,policy):
    assert policy['policy']=='original-per-layer-isothermal-vapor-kelvin-sign-v1'
    assert policy['physical_equation_changed'] is True and policy['new_physical_water_store'] is False and policy['native_interface_changed'] is False and policy['tolerance_changed'] is False
    joint=policy['existing_model7_capacity_composed'];expected=JOINT_TARGET if joint else VAPOR_TARGET
    assert SHA(source.encode('cp1252'))==policy['corrected_lf_sha256']==expected
    before='Hr        = dexp(h/100.0d0*MgRT)';after='Hr        = dexp(-h/100.0d0*MgRT)'
    assert source.count(after)==1
    liquid=source.replace(after,before,1)
    assert SHA(liquid.encode('cp1252'))==(CAPACITY_PARENT if joint else inherited.BASE)
    return liquid


def audit(profile,reference,allow_refusal=False,allow_censored=False,locations=None):
    raw=subprocess.check_output(['git','show',READERS+':'+PATH],cwd=ROOT)
    assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
    functions=[node for node in ast.parse(raw.decode()).body if isinstance(node,ast.FunctionDef) and node.name=='audit'];assert len(functions)==1
    function=functions[0]
    def assigns(node,name):return isinstance(node,ast.Assign) and any(isinstance(target,ast.Name) and target.id==name for target in node.targets)
    first=next(i for i,node in enumerate(function.body) if assigns(node,'policy'))
    end=next(i for i,node in enumerate(function.body) if assigns(node,'terminal'));assert end-first==7
    original=ast.parse("assert not identity['hydraulic_vapor']['existing_model7_capacity_composed']\nassert 'WC_K_models_04_11.f90' in identity['donor_generated']\nassert 'WC_K_models_04_11.o' not in identity['donor_objects']\nassert SHA(vapor_liquid_source((build/'WC_K_models_04_11.f90').read_text(encoding='cp1252'),identity['hydraulic_vapor']).encode('cp1252'))==BASE\n").body
    source_changes=0
    for node in function.body[first:end]:
        if assigns(node,'source'):
            node.value=ast.Call(func=ast.Name(id='vapor_liquid_source',ctx=ast.Load()),args=[node.value,ast.parse("identity['hydraulic_vapor']",mode='eval').body],keywords=[]);source_changes+=1
    assert source_changes==1
    function.body[first:end]=[ast.If(test=ast.parse("bool(identity.get('model7_capacity'))",mode='eval').body,body=function.body[first:end],orelse=original)]
    class ControllerRole(ast.NodeTransformer):
        changes=0
        phase_fields=0
        phase_signs=0
        def visit_Constant(self,node):
            if node.value=='CANDIDATE_ACTUAL_MODEL7_CAPACITY_':self.changes+=1;return ast.copy_location(ast.Constant('CANDIDATE_ACTUAL_VAPOR_FAMILY_'),node)
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
    namespace=dict(vars(inherited));namespace['vapor_liquid_source']=vapor_liquid_source;exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),PATH,'exec'),namespace)
    result=namespace['audit'](profile,reference,allow_refusal,allow_censored,locations)
    q=json.loads((profile/'RESULT.json').read_text());build=locations['build'] if locations else Path(q['build_root']);identity=json.loads((build/'BUILD.json').read_text())['identity'];policy=identity['hydraulic_vapor'];assert policy['SWVAPOR']==q['vapor_flags'] and policy['active_layers'];assert policy['existing_model7_capacity_composed']==bool(identity.get('model7_capacity'));model=q['hydraulic_model'];models=q.get('layer_models',[model]);result.update(hydraulic_model=model,layer_models=models,frozen_scientific_reader=READERS,
        full_capacity_source_inverse=7 in models,original_capacity_equations_retained_through_complete_Kelvin_inverse=7 not in models,scientific_ledger_native_body_unchanged=True,
        phase_correspondence_exact_original_double_subtraction_addition=True,public_mass_bounds_unchanged=True)
    if q['status']!='FAILED':result['status']='INDEPENDENT_ORIGINAL_VAPOR_SOURCE_BUDGET_NATIVE_USER_OUTPUT_PASS'
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('profile','reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--allow-refusal',action='store_true');p.add_argument('--allow-censored',action='store_true');a=p.parse_args();assert not a.output.exists()
    result=audit(a.profile,a.reference_work,a.allow_refusal,a.allow_censored);a.output.write_text(json.dumps(result,indent=2)+'\n');print(result['status'],result['hydraulic_model'],result['optimization'],result['days'])
