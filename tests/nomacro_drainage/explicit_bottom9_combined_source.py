"""Whole literal sibling Source proofs; actual Git and files stay unchanged."""
import json
from pathlib import Path
from explicit_bottom9_source_inverse import git,blob,norm
from analytical_hydraulic_archives import SHA
ROOT=Path(__file__).resolve().parents[2]
CORE='813c40017b2c0aed2802910ed6fab61a613598e9'
PATH='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_COMBINED_SOURCE_EDITS_V1.json'
MANIFEST_SHA='1bcad1e7d956357c7fe3285eef2e4b42c2a590b51e215c6db514c38b2c1234dc'

def verify():
 raw=norm((ROOT/PATH).read_bytes());assert SHA(raw)==MANIFEST_SHA;q=json.loads(raw);assert q['composition_core']==CORE
 assert not git('diff',CORE,'--','app','src','tools','reference') and not git('status','--porcelain','--untracked-files=all','--','app','src','tools','reference')
 observed={}
 for label,side in q['siblings'].items():
  ref=side['qualified_core'];expected={line.split('\t')[1]:line.split('\t')[0] for line in git('diff','--name-status',ref,CORE,'--','app','src','tools','reference').decode().splitlines()}
  assert expected=={path:item['change'] for path,item in side['files'].items()}
  for path,item in side['files'].items():
   raw=norm((ROOT/path).read_bytes());assert raw==blob(CORE,path) and SHA(raw)==item['new_sha256'];lines=raw.decode().splitlines(keepends=True)
   for edit in reversed(item['literal_edits']):
    assert ''.join(lines[edit['new_start']:edit['new_end']])==edit['new'];lines[edit['new_start']:edit['new_end']]=edit['old'].splitlines(keepends=True)
   restored=''.join(lines).encode();assert SHA(restored)==item['old_sha256']
   if item['change']=='A':assert restored==b'' and not git('ls-tree','--name-only',ref,'--',path)
   else:assert restored==blob(ref,path)
  observed[label]=dict(actual_qualified_core=ref,whole_literal_file_inverses=len(side['files']))
 return dict(status='ALL_THREE_QUALIFIED_SIBLING_WHOLE_SOURCE_LITERAL_INVERSES_PASS',actual_head=git('rev-parse','HEAD').decode().strip(),composition_core=CORE,siblings=observed,Git_or_filesystem_views_projected=False,scientific_evidence_rewritten=False)

if __name__=='__main__':print(json.dumps(verify(),indent=2))
