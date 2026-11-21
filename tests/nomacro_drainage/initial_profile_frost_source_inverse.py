"""Prove the complete old pressure guard and all Frost numerical owners survive."""
import ast,hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
BASE='b6b4959fb1301cedc95ddf551c11d6699a41e3ed'
CORE='9ad885a9e5358263b27cc9fd40cfe23330c6006a'
ADAPTER='app/hybrid_water/experimental_project.py'
SELECTOR='app/hybrid_water/initial_profile_frost.py'
SURFACES=('app','src','tools/solute','tools/vq','reference')
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
blob=lambda ref,path:git('show',ref+':'+path)
norm=lambda raw:raw.replace(b'\r\n',b'\n')
BLOCK='        from initial_profile_frost import selection as initial_frost_selection\n        initial_frost=initial_frost_selection(directory,original_output)\n'


def complete_inverse():
 assert not git('diff',CORE,'--',*SURFACES),'Unreviewed original pressure Frost composition source delta'
 assert git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines()==['M\t'+ADAPTER,'A\t'+SELECTOR]
 for path in (ADAPTER,SELECTOR):assert norm((ROOT/path).read_bytes())==blob(CORE,path)
 text=blob(CORE,ADAPTER).decode();assert text.count(BLOCK)==1;text=text.replace(BLOCK,'',1)
 for new,old in [("if (original_output is False or any(selected.get(key) not in values for key,values in domain.items())) and initial_frost is None:","if original_output is False or any(selected.get(key) not in values for key,values in domain.items()):"),('if not state_supported and initial_calendar is None and initial_frost is None:','if not state_supported and initial_calendar is None:')]:
  assert text.count(new)==1;text=text.replace(new,old,1)
 assert text.encode()==blob(BASE,ADAPTER),'Incomplete whole pressure/Frost admission inverse'
 functions=lambda raw:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(raw).body if isinstance(n,ast.FunctionDef)}
 before,after=functions(blob(BASE,ADAPTER)),functions(blob(CORE,ADAPTER));assert {key for key in before if before[key]!=after[key]}=={'inspect'}
 contract=json.loads((ROOT/'integration/f-ci/nomacro-complete01/INITIAL_PROFILE_FROST_CONTRACT_V1.json').read_text())
 for path,digest in contract['qualified_frost_providers'].items():assert hashlib.sha256(norm((ROOT/path).read_bytes())).hexdigest()==digest,'Changed qualified Frost numerical/state provider'
 return True
