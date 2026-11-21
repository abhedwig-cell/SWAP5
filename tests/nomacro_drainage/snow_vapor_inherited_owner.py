"""Extend four legacy source predicates; retain every native/ledger assertion."""
import ast
from ordinary_pond_verify import ROOT,blob,norm
from snow_vapor_source_inverse import PARENT,initial_source_inverse
import vapor_hydraulic_resume as original

OLD='tests/nomacro_drainage/vapor_hydraulic_resume.py'
DECODER='app/hybrid_water/cde_native_receipt.py'


def legacy_native3_decoder_inverse():
 before=blob(PARENT,DECODER).decode();after=norm((ROOT/DECODER).read_bytes()).decode()
 def function(raw):
  found=[node for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef) and node.name=='decode'];assert len(found)==1
  assert isinstance(found[0].args.defaults[-1],ast.Constant) and found[0].args.defaults[-1].value is None
  return ast.get_source_segment(raw,found[0])
 old,new=function(before),function(after)
 edits=[("if aux[:8] in (b'S5HVC003',b'S5HSC004'):","if aux[:8]==b'S5HVC003':"),
        ("        snow=aux[:8]==b'S5HSC004'\n",''),
        ('domain!=(4 if snow else 3,nodes,layers,0,1,0,0,int(snow),0,0,1,2,1,6)','domain!=(3,nodes,layers,0,1,0,0,0,0,0,1,2,1,6)'),
        ("            from snow_vapor_composition import snow_selected\n            if snow_selected(project)!=snow:raise ValueError('CDE vapor native differs from project Snow process')\n",'')]
 for current,prior in edits:assert new.count(current)==1;new=new.replace(current,prior,1)
 assert new==old,'Incomplete old-native3 private-stock decoder inverse'
 # For old S5HVC003 bytes, snow is exactlyFalse, the tuple is the exact old
 # tuple, and the new project/Snow check is unreachable for project=None.
 return True


def checked_initial_reader():
 initial_source_inverse();legacy_native3_decoder_inverse()
 raw=blob(PARENT,OLD);assert norm((ROOT/OLD).read_bytes())==raw
 functions=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='read_initial'];assert len(functions)==1
 function=functions[0]
 expected=ast.parse("changed=subprocess.check_output(['git','diff','--name-only',INITIAL,'HEAD','--','app','src','tools/solute','tools/vq','reference/swap-4.3.1'],cwd=ROOT,text=True).splitlines()\nassert changed==['app/hybrid_water/cde_native_receipt.py'],changed\nexpected=subprocess.check_output(['git','show','daba94800:app/hybrid_water/cde_native_receipt.py'],cwd=ROOT)\nassert (ROOT/'app/hybrid_water/cde_native_receipt.py').read_bytes().replace(b'\\r\\n',b'\\n')==expected\n").body
 assert [ast.dump(n,include_attributes=False) for n in function.body[2:6]]==[ast.dump(n,include_attributes=False) for n in expected]
 calls=[n for n in ast.walk(function) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='decode']
 assert len(calls)==1 and len(calls[0].args)==2 and not calls[0].keywords
 function.body[2:6]=ast.parse('initial_source_inverse()\nlegacy_native3_decoder_inverse()').body
 namespace=dict(vars(original),initial_source_inverse=initial_source_inverse,legacy_native3_decoder_inverse=legacy_native3_decoder_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=[function],type_ignores=[])),OLD,'exec'),namespace)
 return namespace['read_initial']
