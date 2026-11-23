"""Literal whole-file Source inverses, never a Git/HEAD or data projection."""
import ast,json
from pathlib import Path
from analytical_hydraulic_archives import SHA
from explicit_bottom9_source_inverse import git,blob,norm

ROOT=Path(__file__).resolve().parents[2]
BASE='46eef99fbd6e5343c1cf7661ae5188549d555990'
CORE='cc33a863437ca3cf34cade7d6f2aba9c32729f22'
MANIFEST='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_HISTORY_SOURCE_EDITS_V1.json'
MANIFEST_SHA='82c460ba2fe3cc3297ead526652a97cfdbc7885ba671b32bcb8ed4b66e850e1b'
SURFACES=('app','src','tools','reference')


def inverse_sources():
 raw=norm((ROOT/MANIFEST).read_bytes());assert SHA(raw)==MANIFEST_SHA;q=json.loads(raw);assert q['parent']==BASE and q['core']==CORE
 assert not git('diff',CORE,'--',*SURFACES),'Foreign actual history execution surface'
 assert not git('status','--porcelain=v1','--untracked-files=all','--',*SURFACES),'Dirty actual history execution surface'
 rows={line.split('\t')[1]:line.split('\t')[0] for line in git('diff','--name-status',BASE,CORE,'--',*SURFACES).decode().splitlines()}
 assert rows=={**{path:'M' for path in q['files']},**{path:'A' for path in q['added_source']}}
 restored={}
 for path,item in q['files'].items():
  actual=norm((ROOT/path).read_bytes());assert actual==blob(CORE,path) and SHA(actual)==item['core_sha256'];lines=actual.decode().splitlines(keepends=True)
  for edit in reversed(item['positioned_literal_edits']):
   assert ''.join(lines[edit['new_start']:edit['new_end']])==edit['new'];lines[edit['new_start']:edit['new_end']]=edit['old'].splitlines(keepends=True)
  old=''.join(lines).encode();assert old==blob(BASE,path) and SHA(old)==item['parent_sha256'];restored[path]=old
  functions=lambda value:{n.name:ast.dump(n,include_attributes=False) for n in ast.parse(value).body if isinstance(n,ast.FunctionDef)}
  a,b=functions(old),functions(actual);assert a.keys()==b.keys() and sorted(name for name in a if a[name]!=b[name])==item['changed_functions']
 for path,digest in q['added_source'].items():
  assert not git('ls-tree','--name-only',BASE,'--',path);actual=norm((ROOT/path).read_bytes());assert actual==blob(CORE,path) and SHA(actual)==digest
 return restored


def complete_inverse():
 restored=inverse_sources()
 return dict(status='DECLARED_HISTORY9_WHOLE_RENDERER_SOURCE_FILES_LITERAL_INVERSES_AND_FROZEN_NEW_OWNER_PASS',actual_head=git('rev-parse','HEAD').decode().strip(),parent=BASE,core=CORE,restored_whole_files={path:SHA(raw) for path,raw in restored.items()},Git_or_filesystem_views_projected=False,scientific_data_rewritten=False,compiler_executions=0,model_executions=0)


if __name__=='__main__':print(json.dumps(complete_inverse(),indent=2))
