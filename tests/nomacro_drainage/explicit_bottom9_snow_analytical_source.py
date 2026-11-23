"""Two bounded guards over the actual canonical336 execution source."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];CORE='2500ed23990dff450e2da31b85c900c06e0506c3';git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT);SHA=lambda raw:hashlib.sha256(raw).hexdigest()
def complete_inverse():
 path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CONTRACT_V1.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+path);q=json.loads(raw);assert q['actual_canonical']==CORE and not q['physical_equations_changed'] and not q['native_format_changed']
 domains=('app','src','tools','reference');assert set(git('diff','--name-only',CORE,'HEAD','--',*domains).decode().splitlines())==set(q['files']) and not git('status','--porcelain=v1','--untracked-files=all','--',*domains,'tests','.github')
 for path,item in q['files'].items():
  before=git('show',CORE+':'+path);actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(before)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path);old,new=item['literal_old'].encode(),item['literal_new'].encode();assert actual.count(new)==1 and actual.replace(new,old,1)==before
 return dict(status='TWO_EXACT_SNOW_ANALYTICAL_GUARD_INVERSES_ALL_OTHER_EXECUTION_SOURCE_CANONICAL336',actual_source=git('rev-parse','HEAD').decode().strip(),actual_canonical=CORE)
