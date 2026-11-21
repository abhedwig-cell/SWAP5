"""Bind the complete original initialization guard and calendar admission inverse."""
import ast,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='e3d3c33456b330179fb5ac211a89f893d91c9152'
FIRST_CORE='929764dcdb7dd66da1dccf2a29d5a3b7022c0d8b'
INTERVAL_CORE='f929bc88793953710774b593ce9364615734c804'
CORE='ef66025c9517bc7d3b80672a8577c709391e81d8'
SURFACES=('app','src','tools/solute','tools/vq','reference')
ADAPTER='app/hybrid_water/experimental_project.py'
CALENDAR='app/hybrid_water/analytical_cde_calendar.py'
SELECTOR='app/hybrid_water/initial_profile_calendar.py'
GUARD='app/hybrid_water/ordinary_pond_source_guard.py'
CHANGED={ADAPTER,CALENDAR,SELECTOR,GUARD}
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
 # All original numerical code, state providers and constitutive/calendaring
 # generators are outside these three exact admission-only source changes.
 return True

GUARD_BLOCK="    if project.solute:\n        # Ordinary interval output carries private CDE state without adding\n        # the distinct subdaily hydraulic trial. Select the existing complete\n        # water-trial parent from actual inputs, never a mutable source hash.\n        from cde_interval_output import active_selection as interval_selection\n        from cde_clock_output import active_selection as clock_selection\n        interval=interval_selection(project)\n        if interval is not None and clock_selection(project) is None:\n            if identity['original_output'].get('cde_interval_output') is not True:\n                raise ValueError('Foreign actual ordinary CDE interval source form')\n            form='water'\n"

PERSTEP_GUARD_BLOCK="    if not project.solute:\n        from perstep_output_domain import active_selection as perstep_selection\n        perstep=perstep_selection(project)\n        if perstep is not None and not perstep['swsnow']:\n            if identity['original_output'].get('perstep_domain') is not True:\n                raise ValueError('Foreign actual ordinary per-step source form')\n            from initial_profile_calendar import perstep_water_parent_inverse\n            source=perstep_water_parent_inverse(source.decode('cp1252')).encode('cp1252')\n            form='water'\n"
