"""Prove the whole pressure/AGE admission inverse and unchanged process owners."""
import ast,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='06e980f4bb17e43e4cc61cf4fc2d6ea17204526d'
CORE='9694eb2c4cc69f71c2ef90bc64b500fd35cb9924'
ADAPTER='app/hybrid_water/experimental_project.py'
SELECTOR='app/hybrid_water/initial_profile_age.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
BLOCK='        from initial_profile_age import selection as initial_age_selection\n        initial_age=initial_age_selection(directory,original_output)\n'
LOAD_BLOCK="    if age_irrigation_source or age_direct_soil_source:\n        from initial_profile_age import selection as initial_age_selection\n        if initial_age_selection(directory,original_output) is not None:\n            raise ValueError('Original pressure AGE qualification excludes explicit incoming-age source policies')\n"
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
blob=lambda ref,path:git('show',ref+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original pressure AGE source delta'
 assert git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines()==['M\t'+ADAPTER,'A\t'+SELECTOR]
 for path in (ADAPTER,SELECTOR):assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 text=blob(CORE,ADAPTER).decode()
 for block in (BLOCK,LOAD_BLOCK):assert text.count(block)==1;text=text.replace(block,'',1)
 edits=[('and initial_frost is None and initial_age is None:','and initial_frost is None:'),('and initial_calendar is None and initial_age is None:','and initial_calendar is None:')]
 for new,old in edits:assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==blob(BASE,ADAPTER),'Incomplete whole original AGE pressure/input-policy inverse'
 functions=lambda raw:{node.name:ast.dump(node,include_attributes=False) for node in ast.parse(raw).body if isinstance(node,ast.FunctionDef)}
 before,after=functions(blob(BASE,ADAPTER)),functions(blob(CORE,ADAPTER));assert {name for name in before if before[name]!=after[name]}=={'inspect','load'}
 contract=json.loads((ROOT/'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_AGE_CONTRACT_V2.json').read_text())
 import hashlib
 for path,digest in contract['process_owner_pins'].items():assert hashlib.sha256(norm((ROOT/path).read_bytes())).hexdigest()==digest,'Changed qualified AGE process/state/output owner'
 return True
