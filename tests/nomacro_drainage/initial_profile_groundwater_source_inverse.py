"""Prove whole groundwater admission changes back to the frozen AGE source."""
import ast,json,hashlib,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='9694eb2c4cc69f71c2ef90bc64b500fd35cb9924'
CORE='4a4053c210ce5bdd8cb2506b79dcf9ad8b42a43f'
ADAPTER='app/hybrid_water/experimental_project.py'
SELECTOR='app/hybrid_water/initial_profile_groundwater.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
BLOCK='        from initial_profile_groundwater import selection as initial_groundwater_selection\n        initial_groundwater=initial_groundwater_selection(directory,original_output)\n'
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
blob=lambda ref,path:git('show',ref+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed pressure groundwater physical source delta'
 assert git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines()==['M\t'+ADAPTER,'A\t'+SELECTOR]
 for path in (ADAPTER,SELECTOR):assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 text=blob(CORE,ADAPTER).decode();assert text.count(BLOCK)==1;text=text.replace(BLOCK,'',1)
 for old in ('and initial_frost is None and initial_age is None:','and initial_calendar is None and initial_frost is None:','and initial_calendar is None and initial_age is None:'):
  new=old[:-1]+' and initial_groundwater is None:';assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==blob(BASE,ADAPTER),'Incomplete whole groundwater-to-AGE source inverse'
 functions=lambda raw:{node.name:ast.dump(node,include_attributes=False) for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef)}
 before,after=functions(blob(BASE,ADAPTER)),functions(blob(CORE,ADAPTER));assert {key for key in before if before[key]!=after[key]}=={'inspect'}
 contract=json.loads((ROOT/'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_GROUNDWATER_CONTRACT_V1.json').read_text())
 for path,digest in contract['process_owner_pins'].items():assert hashlib.sha256(norm((ROOT/path).read_bytes())).hexdigest()==digest
 return True
