"""Exact bounded Snow5/8 analytical source against actual qualified candidate dependency."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];CORE='0157d2995e85adce362642918095e871469e4ee1';git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT);SHA=lambda raw:hashlib.sha256(raw).hexdigest()
def complete_inverse():
 path='integration/f-ci/nomacro-complete01/SNOW58_ANALYTICAL_CONTRACT_V1.json';raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+path);q=json.loads(raw)
 assert q['source_dependency']==CORE and q['version']==1 and not q['physical_equations_changed'] and not q['new_physical_state'] and not q['native_payload_layout_changed']
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
 return dict(status='EXACT_BOUND_SNOW58_DIRECTINPUT_PRESSURE_NATIVE_SELECTION_ALL_OTHER_EXECUTION_SOURCE_DEPENDENCY_BYTES',actual_source=git('rev-parse','HEAD').decode().strip(),actual_dependency=CORE)
