"""Reuse literal native5 mutations against actual new CDE calendar native6."""
import ast,json,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface'),str(ROOT/'app/hybrid_water')]
import vapor_boundary_controls as original
from analytical_cde_calendar import calendar_context
BASE='5c0cba9fbbd93ffb482199016f392e53e371e095'
PATH='tests/nomacro_drainage/vapor_boundary_controls.py'


def main():
 raw=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT);assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='main'];assert len(nodes)==1;function=nodes[0]
 boundary=[n for n in function.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='boundary' for t in n.targets)];assert len(boundary)==1 and ast.unparse(boundary[0].value)=="vapor['boundary_composition']";boundary[0].value=ast.parse('calendar_context(project)',mode='eval').body
 values=[n for n in function.body if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='values' for t in n.targets)];assert len(values)==1 and values[0].value.left.left.elts[0].value==5;values[0].value.left.left.elts[0].value=6
 loops=[n for n in function.body if isinstance(n,ast.For) and isinstance(n.target,ast.Name) and n.target.id=='magic'];assert len(loops)==1 and len(loops[0].iter.elts)==9
 loops[0].iter.elts += [ast.Constant(v) for v in (b'S5HBC005',b'S5CIC001',b'S5CCC001')]
 counts=[n for n in ast.walk(function) if isinstance(n,ast.Assert) and ast.unparse(n.test)=="len(q['refusals']) == 49"];assert len(counts)==1;counts[0].test.comparators[0].value=52
 statuses=[n for n in ast.walk(function) if isinstance(n,ast.Constant) and n.value=='ACTUAL_VAPOR_BOUNDARY_NATIVE5_49_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'];assert len(statuses)==1;statuses[0].value='ACTUAL_CDE_CALENDAR_VAPOR_NATIVE6_52_TYPED_REFUSALS_AND_EXTERNAL_DISCARD_REPLAY_RECOVERY_PASS'
 namespace=dict(vars(original),calendar_context=calendar_context);exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),PATH,'exec'),namespace);namespace['main']()


if __name__=='__main__':main()
