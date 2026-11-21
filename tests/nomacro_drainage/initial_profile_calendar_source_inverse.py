"""Bind the complete original initialization guard and calendar admission inverse."""
import ast,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='71db24532f006bc78ac570d1fccdd04b22482e0e'
CORE='929764dcdb7dd66da1dccf2a29d5a3b7022c0d8b'
SURFACES=('app','src','tools/solute','tools/vq','reference')
ADAPTER='app/hybrid_water/experimental_project.py'
CALENDAR='app/hybrid_water/analytical_cde_calendar.py'
SELECTOR='app/hybrid_water/initial_profile_calendar.py'
CHANGED={ADAPTER,CALENDAR,SELECTOR}
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
blob=lambda sha,path:git('show',sha+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')
BLOCK="        from initial_profile_calendar import selection as initial_calendar_selection\n        initial_calendar=initial_calendar_selection(directory,original_output)\n"


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original initial-profile calendar source delta'
 assert set(git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines())=={'M\t'+ADAPTER,'M\t'+CALENDAR,'A\t'+SELECTOR}
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
 # All original numerical code, state providers and constitutive/calendaring
 # generators are outside these three exact admission-only source changes.
 return True
