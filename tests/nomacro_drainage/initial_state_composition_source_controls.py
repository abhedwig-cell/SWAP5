"""Retain literal ordinary source attacks with the exact boundary-inverse refusal."""
import ast,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_drainage'),str(ROOT/'tests/nomacro_scheduled_subsurface')]
import ordinary_pond_controls as old
BASE='e4dfd5fd0274c51e56ac30baf247cea51a304321'
PATH='tests/nomacro_drainage/ordinary_pond_controls.py'


def main():
 raw=subprocess.check_output(['git','show',BASE+':'+PATH],cwd=ROOT)
 assert (ROOT/PATH).read_bytes().replace(b'\r\n',b'\n')==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='main'];assert len(nodes)==1
 branches=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.If) and ast.unparse(n.test)=="label == 'head-wrong-form'"];assert len(branches)==1
 assignments=[n for n in branches[0].body if isinstance(n,ast.Assign) and ast.unparse(n.targets[0])=='expected'];assert len(assignments)==1 and ast.literal_eval(assignments[0].value)=='Foreign actual ordinary implicit coupled HeadCalc provider'
 # A whole foreign explicit HeadCalc lacks the prescribed-head receipt seam;
 # the literal inverse therefore refuses before its later whole-parent hash.
 assignments[0].value=ast.Constant('Foreign actual Snow rollback/pond event source')
 namespace=dict(vars(old));exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),PATH,'exec'),namespace);namespace['main']()


if __name__=='__main__':main()
