"""Freeze the actual FCI93 closure; retain its whole immutable native oracle body."""
import hashlib,io,json,re,runpy,subprocess,sys
from contextlib import redirect_stdout
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CONTRACT='integration/f-ci/nomacro-complete01/CANONICAL_LEGACY_FSI35_SOURCE_CONTRACT_V1.json'
CONTRACT_SHA='931ed4f98d05aff668d7c4ff6ddcc2a4179b6a2fdcb30e3d0c3af5fc1da06399'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()

def verify_source():
 def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
 raw=(ROOT/CONTRACT).read_bytes().replace(b'\r\n',b'\n');assert SHA(raw)==CONTRACT_SHA;q=json.loads(raw)
 assert q['status']=='BOUNDED_FSI35_CURRENT_SOURCE_SUCCESSOR_REQUIRES_UNCHANGED_IMMUTABLE_NATIVE_ORACLES' and q['physical_source_changes'] is False and q['global_DATAQUAL12_waiver'] is False
 paths=list(q['source_inventory']);assert len(paths)==29 and not git('status','--porcelain','--',*paths),'Dirty current FSI35 dependency'
 for path,item in q['source_inventory'].items():
  assert git('rev-parse','HEAD:'+path).decode().strip()==item['git_blob']==git('rev-parse',q['baseline']+':'+path).decode().strip(),'Unregistered FSI35 committed source: '+path
  actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(actual)==item['LF_sha256'] and actual==git('show',q['baseline']+':'+path),'Changed actual FSI35 compilation source: '+path
 runner=q['runner'];old=git('show',q['baseline']+':'+runner['path']);current=(ROOT/runner['path']).read_bytes().replace(b'\r\n',b'\n');assert SHA(old)==runner['old_sha256'] and SHA(current)==runner['new_sha256'];restored=current
 for edit in runner['literal_source_edits']:
  before,after=edit['old'].encode(),edit['new'].encode();assert restored.count(after)==1;restored=restored.replace(after,before,1)
 assert restored==old and current.split(b'POSTIMAGE=',1)[1]==old.split(b'POSTIMAGE=',1)[1],'Changed original lineage, typed seams, flags, immutable oracles or numerical assertions'
 fixture=q['stub_fixture'];stub=(ROOT/fixture['path']).read_bytes().replace(b'\r\n',b'\n');assert SHA(stub)==fixture['sha256'];original=q['original_immutable_inputs'][0];raw=git('show',original['ref']+':'+original['path']);assert len(raw)==original['original_bytes'] and SHA(raw)==original['original_sha256'];needle=b'module MOD_MvG\n  use MOD_grid, only: numnod\n  implicit none\n';assert raw.count(needle)==1 and stub==raw.replace(needle,needle+b'  integer :: swsophy = 0\n',1),'Foreign historical stub beyond original accepted interface addition'
 for item in q['original_immutable_inputs'][1:]:
  raw=git('show',item['ref']+':'+item['path']);assert len(raw)==item['original_bytes'] and SHA(raw)==item['original_sha256']
 deps=q['historical_dependencies'];raw=(ROOT/deps['path']).read_bytes().replace(b'\r\n',b'\n');assert SHA(raw)==deps['sha256'] and raw==git('show',q['baseline']+':'+deps['path'])
 helper=q['compile_helper'];code=git('show',helper['ref']+':'+helper['path']);assert SHA(code)==helper['sha256'];saved=sys.argv;messages=io.StringIO()
 try:
  sys.argv=[helper['path'],'--all',*q['original_immutable_roots']]
  with redirect_stdout(messages):exec(compile(code,helper['path'],'exec'),dict(__file__=str(ROOT/helper['path']),__name__='__main__'))
 finally:sys.argv=saved
 closure=[Path(value).as_posix() for value in messages.getvalue().splitlines()];assert closure==q['actual_transitive_closure'] and len(closure)==28,'Foreign actual immutable-algorithm FSI35 compilation dependency closure'
 transaction=q['unchanged_transaction'];tx=git('show',transaction['actual_qualified_historical_ref']+':'+transaction['path']);assert tx==(ROOT/transaction['path']).read_bytes().replace(b'\r\n',b'\n');uses=re.findall(rb'(?mi)^\s*use[^\n]*',tx);assert len(uses)==2 and all(b'use, intrinsic :: ' in value for value in uses)
 for item in transaction['historical_proof']:
  raw=(ROOT/'integration/f-ci/nomacro-complete01'/item['file']).read_bytes();assert len(raw)==item['bytes'] and SHA(raw)==item['sha256']
  if item['file'].endswith('.json'):
   receipt=json.loads(raw);assert receipt['status']=='ACTUAL_HISTORICAL_D12_UNCHANGED_LITERAL_SOURCE_AND_ALL_ARCHIVED_SCIENCE_ASSERTIONS_PASS' and receipt['actual_head']==transaction['actual_qualified_historical_ref'] and receipt['returncode']==0 and receipt['historical_evidence_promoted_to_current_backend'] is False
 return dict(status='FSI35_ACTUAL_TRANSITIVE_SOURCE_AND_WHOLE_ORIGINAL_NATIVE_RECIPE_PRESERVED_PENDING_NATIVE_ORACLES',actual_current_compilation_source_files=28,actual_native_closure_with_stub=28,unchanged_inherited_standalone_transaction_sources=1,original_native_compilation_and_assertions_unchanged=True,whole_global_DATAQUAL12_qualification_claimed=False,compiler_executions=0,model_executions=0)

def fsi35_successors():
 verify_source();return json.loads((ROOT/CONTRACT).read_text())['registered_successors']

def original_runner_source():
 verify_source();q=json.loads((ROOT/CONTRACT).read_text());return q['runner']['path'],subprocess.check_output(['git','show',q['baseline']+':'+q['runner']['path']],cwd=ROOT)

if __name__=='__main__':print(json.dumps(verify_source(),indent=2))
