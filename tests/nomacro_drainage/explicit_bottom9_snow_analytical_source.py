"""Exact bounded new Snow analytical guards and model-native source ownership."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];CORE='2500ed23990dff450e2da31b85c900c06e0506c3';git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT);SHA=lambda raw:hashlib.sha256(raw).hexdigest()
def complete_inverse():
 path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_ANALYTICAL_CONTRACT_V1.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+path);q=json.loads(raw)
 assert q['actual_canonical']==CORE and q['version']==2 and not q['physical_equations_changed'] and q['old_model1_native_format_unchanged'] and q['native_format_changed']
 domains=('app','src','tools','reference');assert set(git('diff','--name-only',CORE,'HEAD','--',*domains).decode().splitlines())==set(q['files'])|set(q['added_files'])
 assert not git('status','--porcelain=v1','--untracked-files=all','--',*domains,'tests','.github')
 for path,item in q['files'].items():
  before=git('show',CORE+':'+path);actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(before)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
  original=before.decode();parts=[];cursor=0
  for edit in item['ordered_literal_edits']:
   low,high=edit['base_start'],edit['base_end'];assert cursor<=low<=high<=len(original) and original[low:high]==edit['before'];parts.extend((original[cursor:low],edit['after']));cursor=high
  parts.append(original[cursor:]);assert ''.join(parts).encode()==actual
 for path,item in q['added_files'].items():
  assert not git('ls-tree',CORE,'--',path);actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
 return dict(status='EXACT_BOUNDED_ANALYTICAL_SNOW_GUARDS_AND_MODEL_NATIVE_ALL_OTHER_EXECUTION_SOURCE_CANONICAL',actual_source=git('rev-parse','HEAD').decode().strip(),actual_canonical=CORE)
