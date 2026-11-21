"""Bind exact state-selector composition and one old root-carry parent extension."""
import ast,subprocess,os
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='e4dfd5fd0274c51e56ac30baf247cea51a304321'
PHYSICAL_CORE='23e8f8c228d6b2d3667a45932f02011e02cc0c80'
PREVIOUS_GUARD='8ada573a86cdabf2699fbb7a4c63d150552b88cc'
CORE='e36585da4cde1c4044bad0f833c7a8f10f368849'
GUARD='app/hybrid_water/ordinary_pond_source_guard.py'
PARENT='a8aa149a22b67a7f5bbf7c2e4243002f89d7242c'
PORTABLE='31c32def70aa66861ca03f518bc0bb3d8d8973c4'
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
CI=('.github/workflows/mc-sol01-column-input.yml','.github/workflows/mc-sol01-swp-reader.yml')
PATTERN='            /integration/f-ci/nomacro-complete01/INITIAL_STATE_COMPOSITION*\n'
ADAPTER='app/hybrid_water/experimental_project.py'
ROOT_CARRY='app/hybrid_water/implicit_snow_cde_root_carry.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
STATE_BLOCK="""        history,snow,implicit=selected['SWHYST'],selected['SWSNOW'],selected['SWKIMPL']
        boundary_pair=(selected['SWDRA'],selected['SWBOTB'])
        if history:state_supported=not snow and not implicit and boundary_pair==(1,6)
        elif snow:state_supported=boundary_pair==((1,5) if implicit else (1,6))
        elif implicit:state_supported=boundary_pair==(1,5)
        else:state_supported=True
        if not state_supported:
            raise ValueError('Unqualified original pressure-profile state-owner cross composition')
"""

DENSE_BLOCK="    if project.solute and identity['original_output'].get('native_codec') == 'S5IOC001':\n        # The original dense daily CDE route adds private solute output state,\n        # but its HeadCalc has the ordinary water trial body, not a subdaily\n        # CDE output-clock trial. Bind that choice to actual original inputs.\n        from original_output import selection as dense_original_selection\n        dense=dense_original_selection(project)\n        if (dense['nprintday'] != 1 or dense['flprintdt'] or\n                dense['requested_period'] != 1):\n            raise ValueError('Foreign actual ordinary dense CDE source form')\n        form='water'\n"
GUARD_BLOCK="    if report['boundary']['SWBOTB'] == 5:\n        # Invert only the literal admitted prescribed-head receipt projection.\n        # The whole numerical body must still equal the qualified air-boundary\n        # parent below; no generated/candidate hash authorizes a provider.\n        from groundwater_snow_retry import inverse\n        from lower_boundary_receipt import render_headcalc\n        template=('logical                          :: flboth, flok\\n'\n                  '         budget_step=projected_water_residual()\\n'\n                  '            budget_step = projected_water_residual()\\n')\n        source=render_headcalc(inverse(source.decode('cp1252'),\n            lambda text:render_headcalc(text,5),template),8).encode('cp1252')\n"

def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original initial-state composition source delta'
 assert git('diff','--name-only',BASE,CORE,'--',*SURFACES).decode().splitlines()==[ADAPTER,ROOT_CARRY,GUARD]
 current=(ROOT/ADAPTER).read_bytes().replace(b'\r\n',b'\n');assert current==git('show',CORE+':'+ADAPTER);text=current.decode();assert text.count(STATE_BLOCK)==1;text=text.replace(STATE_BLOCK,'',1)
 edits=[("'SWHYST':{0,1,2},'SWSNOW':{0,1}","'SWHYST':{0},'SWSNOW':{0}"),("'SWCALT':{2},'SWKIMPL':{0,1},","'SWCALT':{2},'SWKIMPL':{0},"),('Original pressure-profile initialization requires bounded daily water/CDE without Frost/aquifer','Original pressure-profile initialization requires bounded explicit daily water/CDE without snow/frost/hysteresis/aquifer')]
 for new,old in edits:assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==git('show',BASE+':'+ADAPTER),'Incomplete old initialization adapter inverse'
 current=(ROOT/ROOT_CARRY).read_bytes().replace(b'\r\n',b'\n');assert current==git('show',CORE+':'+ROOT_CARRY);entry=b",'S5ITC001':'S5IRC003'";assert current.count(entry)==1 and current.replace(entry,b'',1)==git('show',BASE+':'+ROOT_CARRY)
 before=ast.parse(git('show',BASE+':'+ROOT_CARRY));after=ast.parse(current)
 functions=lambda tree:{n.name:ast.dump(n,include_attributes=False) for n in tree.body if isinstance(n,ast.FunctionDef)}
 assert functions(before)==functions(after)
 assert (ROOT/'app/hybrid_water/implicit_snow_root_state.f90').read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':app/hybrid_water/implicit_snow_root_state.f90')
 current=(ROOT/GUARD).read_bytes().replace(b'\r\n',b'\n');assert current==git('show',CORE+':'+GUARD)
 for block in (DENSE_BLOCK,GUARD_BLOCK):
  assert current.count(block.encode())==1;current=current.replace(block.encode(),b'',1)
 assert current==git('show',BASE+':'+GUARD),'Incomplete literal dense/boundary receipt guard inverse'
 assert not git('diff',BASE,PARENT,'--',*SURFACES),'Parent canonical physical tree moved'
 assert (ROOT/WORKFLOW).read_bytes().replace(b'\r\n',b'\n')==git('show',PORTABLE+':'+WORKFLOW)
 for path in CI:
  raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n').decode();assert raw.count(PATTERN)==1 and raw.replace(PATTERN,'',1).encode()==git('show',PARENT+':'+path),'Unreviewed state proof checkout delta'
 return True


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return git('show',PARENT+':'+self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)
 def __fspath__(self):return os.fspath(ROOT/self.path)
 def __str__(self):return str(ROOT/self.path)


class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in (ADAPTER,ROOT_CARRY,GUARD,WORKFLOW,*CI) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def initial_parent_complete_inverse():
 import initial_pressure_profile_source_inverse as initial
 path='tests/nomacro_drainage/initial_pressure_profile_source_inverse.py';raw=git('show',PARENT+':'+path);nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)";function.body[0]=ast.parse('state_complete_inverse()').body[0]
 namespace=dict(vars(initial),ROOT=CheckedParentRoot(),state_complete_inverse=complete_inverse);exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace);return namespace['complete_inverse']()


def initial_parent_source_union():
 import initial_pressure_profile_source_inverse as initial
 import vapor_boundary_source_inverse as boundary
 path='tests/nomacro_drainage/vapor_boundary_source_inverse.py';raw=git('show',initial.BASE+':'+path);nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='initial_source_inverse'];assert len(nodes)==1
 found=[n for n in nodes[0].body if isinstance(n,ast.Assert) and ast.unparse(n.test)=='actual == previous | set(CHANGED)'];assert len(found)==1
 found[0].test=ast.parse('actual == previous | set(CHANGED) | STATE_PATHS',mode='eval').body
 namespace=dict(vars(boundary),ROOT=initial.CheckedRoot(),complete_inverse=initial.boundary_complete_inverse,STATE_PATHS={ADAPTER,ROOT_CARRY,GUARD})
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace);return namespace['initial_source_inverse']()


@contextmanager
def prior_source_projection():
 complete_inverse()
 import initial_pressure_profile_source_inverse as initial
 saved=(initial.ROOT,initial.complete_inverse,initial.initial_source_inverse)
 # Fully inverted source reads only. Actual Git/HEAD/producer identities,
 # native payloads, scientific inputs and every old numerical assertion stay
 # literal and current; no scientific data path is projected.
 initial.ROOT=CheckedParentRoot();initial.complete_inverse=initial_parent_complete_inverse;initial.initial_source_inverse=initial_parent_source_union
 try:yield
 finally:initial.ROOT,initial.complete_inverse,initial.initial_source_inverse=saved
