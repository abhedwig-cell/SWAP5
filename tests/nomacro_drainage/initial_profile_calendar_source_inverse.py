"""Bind the complete original initialization guard and calendar admission inverse."""
import ast,subprocess,os
from contextlib import contextmanager
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='cb7ce3774ce263d05bd7ec79a66c3cbf4009b383'
FIRST_CORE='929764dcdb7dd66da1dccf2a29d5a3b7022c0d8b'
INTERVAL_CORE='f929bc88793953710774b593ce9364615734c804'
CORE='ef66025c9517bc7d3b80672a8577c709391e81d8'
SURFACES=('app','src','tools/solute','tools/vq','reference')
ADAPTER='app/hybrid_water/experimental_project.py'
CALENDAR='app/hybrid_water/analytical_cde_calendar.py'
SELECTOR='app/hybrid_water/initial_profile_calendar.py'
GUARD='app/hybrid_water/ordinary_pond_source_guard.py'
CHANGED={ADAPTER,CALENDAR,SELECTOR,GUARD}
WORKFLOW='.github/workflows/nomacro-water-snow-groundwater.yml'
PORTABLE='f4f868daf99f81c0e22a754901576935adb869ef'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
blob=lambda sha,path:git('show',sha+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')
BLOCK="        from initial_profile_calendar import selection as initial_calendar_selection\n        initial_calendar=initial_calendar_selection(directory,original_output)\n"


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original initial-profile calendar source delta'
 assert set(git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines())=={'M\t'+ADAPTER,'M\t'+CALENDAR,'A\t'+SELECTOR,'M\t'+GUARD}
 for path in CHANGED:assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 text=blob(CORE,ADAPTER).decode();assert text.count(BLOCK)==1;text=text.replace(BLOCK,'',1)
 edits=[('if not state_supported and initial_calendar is None:','if not state_supported:'),("or len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F')) and initial_calendar is None:","or len(flags)>1 or flags and flags[0].strip().upper() not in ('.FALSE.','FALSE','.F.','F')):")]
 for new,old in edits:assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==blob(BASE,ADAPTER),'Incomplete whole original pressure initialization adapter inverse'
 text=blob(CORE,CALENDAR);new=b"selected.get('SWINCO') not in (1,2,3)";old=b"selected.get('SWINCO') not in (2,3)"
 assert text.count(new)==1 and text.replace(new,old,1)==blob(BASE,CALENDAR),'Incomplete existing analytical calendar context inverse'
 functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
 before,after=functions(blob(BASE,ADAPTER)),functions(blob(CORE,ADAPTER));assert {name for name in before if before[name]!=after[name]}=={'inspect'}
 before,after=functions(blob(BASE,CALENDAR)),functions(blob(CORE,CALENDAR));assert {name for name in before if before[name]!=after[name]}=={'input_context'}
 text=blob(CORE,GUARD)
 for block in (GUARD_BLOCK.encode(),PERSTEP_GUARD_BLOCK.encode()):
  assert text.count(block)==1;text=text.replace(block,b'',1)
 assert text==blob(BASE,GUARD),'Incomplete original interval/per-step water-trial source guard inverse'
 assert norm((ROOT/WORKFLOW).read_bytes())==blob(PORTABLE,WORKFLOW),'Unreviewed targeted implicit calendar workflow'
 # All original numerical code, state providers and constitutive/calendaring
 # generators are outside these three exact admission-only source changes.
 return True


class SourceFile:
 def __init__(self,path):self.path=path
 def read_bytes(self):return blob(BASE,self.path)
 def read_text(self,encoding='utf8'):return self.read_bytes().decode(encoding)


class CheckedParentRoot:
 def __truediv__(self,path):return SourceFile(str(path)) if str(path) in ({ADAPTER,CALENDAR,GUARD,WORKFLOW}) else ROOT/path
 def __fspath__(self):return os.fspath(ROOT)
 def __str__(self):return str(ROOT)


def calendar_parent_complete_inverse():
 import analytical_cde_calendar_source_inverse as calendar
 path='tests/nomacro_drainage/analytical_cde_calendar_source_inverse.py';raw=blob(BASE,path)
 assert norm((ROOT/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='complete_inverse'];assert len(nodes)==1
 function=nodes[0];assert isinstance(function.body[0],ast.Assert) and ast.unparse(function.body[0].test)=="not git('diff', CORE, '--', *SURFACES)"
 function.body[0]=ast.parse('profile_complete_inverse()').body[0]
 namespace=dict(vars(calendar),ROOT=CheckedParentRoot(),profile_complete_inverse=complete_inverse)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['complete_inverse']()


def calendar_parent_source_union():
 import analytical_cde_calendar_source_inverse as calendar
 path='tests/nomacro_drainage/analytical_cde_calendar_source_inverse.py';raw=blob(BASE,path)
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='state_parent_source_union'];assert len(nodes)==1
 additions=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.AugAssign) and isinstance(n.value,ast.Constant) and n.value.value==' | CALENDAR_PATHS'];assert len(additions)==1
 additions[0].value.value+=' | PROFILE_PATHS'
 assignments=[n for n in ast.walk(nodes[0]) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='namespaces' for t in n.targets)];assert len(assignments)==1
 # That function compiles the unchanged state union one level down. Add only
 # the completely checked new paths to its actual source-set equality.
 insertion=ast.parse("namespaces[0].value.keywords.append(ast.keyword(arg='PROFILE_PATHS',value=ast.Name(id='PROFILE_PATHS',ctx=ast.Load())))").body[0]
 index=next(i for i,n in enumerate(nodes[0].body) if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='namespace' for t in n.targets))
 nodes[0].body.insert(index,insertion)
 namespace_assignment=nodes[0].body[index+1];namespace_assignment.value.keywords.append(ast.keyword(arg='PROFILE_PATHS',value=ast.Name(id='PROFILE_PATHS',ctx=ast.Load())))
 namespace=dict(vars(calendar),PROFILE_PATHS=CHANGED)
 exec(compile(ast.fix_missing_locations(ast.Module(body=nodes,type_ignores=[])),path,'exec'),namespace)
 return namespace['state_parent_source_union']()


def prior_calendar_frontend(store):
 import analytical_cde_calendar as selected
 import analytical_cde_calendar_control_forensics as records
 path='tests/nomacro_drainage/analytical_cde_calendar_control_forensics.py';raw=blob(BASE,path)
 assert norm((ROOT/path).read_bytes())==raw
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='frontend'];assert len(nodes)==1
 namespace=dict(vars(records),ROOT=CheckedParentRoot());exec(compile(ast.Module(body=nodes,type_ignores=[]),path,'exec'),namespace)
 old=[n for n in ast.parse(blob(BASE,CALENDAR)).body if isinstance(n,ast.FunctionDef) and n.name=='input_context'];assert len(old)==1
 context=dict(vars(selected));exec(compile(ast.Module(body=old,type_ignores=[]),CALENDAR,'exec'),context)
 saved=selected.input_context;selected.input_context=context['input_context']
 try:return namespace['frontend'](store)
 finally:selected.input_context=saved


def guard_parent_source():
 import analytical_cde_calendar_verify as previous
 path='tests/nomacro_drainage/analytical_cde_calendar_verify.py';raw=blob(BASE,path)
 nodes=[n for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef) and n.name=='guard_previous_source'];assert len(nodes)==1
 namespace=dict(vars(previous),complete_inverse=calendar_parent_complete_inverse)
 exec(compile(ast.Module(body=nodes,type_ignores=[]),path,'exec'),namespace)
 with prior_source_projection():return namespace['guard_previous_source']()


@contextmanager
def prior_source_projection():
 complete_inverse()
 import analytical_cde_calendar_source_inverse as calendar
 import analytical_cde_calendar_control_forensics as records
 import analytical_cde_calendar_central_science as central
 saved=(calendar.ROOT,calendar.complete_inverse,calendar.CheckedSourceRoot,calendar.state_parent_source_union)
 saved_frontends=(records.frontend,central.frontend)
 class ParentRoot(saved[2]):
  def __truediv__(self,path):return SourceFile(str(path)) if str(path) in {ADAPTER,CALENDAR,GUARD} else super().__truediv__(path)
 calendar.ROOT=CheckedParentRoot();calendar.complete_inverse=calendar_parent_complete_inverse;calendar.CheckedSourceRoot=ParentRoot;calendar.state_parent_source_union=calendar_parent_source_union
 records.frontend=central.frontend=prior_calendar_frontend
 try:
  with calendar.prior_source_projection():yield
 finally:
  calendar.ROOT,calendar.complete_inverse,calendar.CheckedSourceRoot,calendar.state_parent_source_union=saved
  records.frontend,central.frontend=saved_frontends

GUARD_BLOCK="    if project.solute:\n        # Ordinary interval output carries private CDE state without adding\n        # the distinct subdaily hydraulic trial. Select the existing complete\n        # water-trial parent from actual inputs, never a mutable source hash.\n        from cde_interval_output import active_selection as interval_selection\n        from cde_clock_output import active_selection as clock_selection\n        interval=interval_selection(project)\n        if interval is not None and clock_selection(project) is None:\n            if identity['original_output'].get('cde_interval_output') is not True:\n                raise ValueError('Foreign actual ordinary CDE interval source form')\n            form='water'\n"

PERSTEP_GUARD_BLOCK="    if not project.solute:\n        from perstep_output_domain import active_selection as perstep_selection\n        perstep=perstep_selection(project)\n        if perstep is not None and not perstep['swsnow']:\n            if identity['original_output'].get('perstep_domain') is not True:\n                raise ValueError('Foreign actual ordinary per-step source form')\n            from initial_profile_calendar import perstep_water_parent_inverse\n            source=perstep_water_parent_inverse(source.decode('cp1252')).encode('cp1252')\n            form='water'\n"
