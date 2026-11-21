"""Bind exact state-selector composition and one old root-carry parent extension."""
import ast,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='e4dfd5fd0274c51e56ac30baf247cea51a304321'
CORE='23e8f8c228d6b2d3667a45932f02011e02cc0c80'
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


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original initial-state composition source delta'
 assert git('diff','--name-only',BASE,CORE,'--',*SURFACES).decode().splitlines()==[ADAPTER,ROOT_CARRY]
 current=(ROOT/ADAPTER).read_bytes().replace(b'\r\n',b'\n');assert current==git('show',CORE+':'+ADAPTER);text=current.decode();assert text.count(STATE_BLOCK)==1;text=text.replace(STATE_BLOCK,'',1)
 edits=[("'SWHYST':{0,1,2},'SWSNOW':{0,1}","'SWHYST':{0},'SWSNOW':{0}"),("'SWCALT':{2},'SWKIMPL':{0,1},","'SWCALT':{2},'SWKIMPL':{0},"),('Original pressure-profile initialization requires bounded daily water/CDE without Frost/aquifer','Original pressure-profile initialization requires bounded explicit daily water/CDE without snow/frost/hysteresis/aquifer')]
 for new,old in edits:assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==git('show',BASE+':'+ADAPTER),'Incomplete old initialization adapter inverse'
 current=(ROOT/ROOT_CARRY).read_bytes().replace(b'\r\n',b'\n');assert current==git('show',CORE+':'+ROOT_CARRY);entry=b",'S5ITC001':'S5IRC003'";assert current.count(entry)==1 and current.replace(entry,b'',1)==git('show',BASE+':'+ROOT_CARRY)
 before=ast.parse(git('show',BASE+':'+ROOT_CARRY));after=ast.parse(current)
 functions=lambda tree:{n.name:ast.dump(n,include_attributes=False) for n in tree.body if isinstance(n,ast.FunctionDef)}
 assert functions(before)==functions(after)
 assert (ROOT/'app/hybrid_water/implicit_snow_root_state.f90').read_bytes().replace(b'\r\n',b'\n')==git('show',BASE+':app/hybrid_water/implicit_snow_root_state.f90')
 return True
