"""Prove the complete actual hydraulic composition against its real parent."""
import argparse,hashlib,json,subprocess
from pathlib import Path
R=Path(__file__).resolve().parents[2]
BASE='22520105f5a3ccac2bd2ae1b726f27b7b0d67b1e'
P='integration/f-ci/nomacro-complete01/'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
git=lambda *args:subprocess.check_output(['git',*args],cwd=R)
def source():
 head=git('rev-parse','HEAD').decode().strip()
 assert not git('for-each-ref','--format=%(refname)','refs/replace')
 assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','reference','.github')
 assert not git('diff',BASE,'HEAD','--','src','tools','reference')
 raw=git('show','HEAD:'+P+'IMPLICIT_HYDRAULIC_STATE11_SOURCE_PROPOSAL_V8.json');contract=json.loads(raw)
 assert (R/P/'IMPLICIT_HYDRAULIC_STATE11_SOURCE_PROPOSAL_V8.json').read_bytes().replace(b'\r\n',b'\n')==raw
 assert contract['actual_parent']==BASE
 assert set(git('diff','--name-only',BASE,'HEAD','--','app').decode().splitlines())==set(contract['files']) and len(contract['files'])==14
 for path,item in contract['files'].items():
  actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert actual==git('show','HEAD:'+path) and SHA(actual)==item['proposed_lf_sha256']
  if item['new_file']:
   assert item['complete_lf_text'].encode()==actual
   assert subprocess.run(['git','cat-file','-e',BASE+':'+path],cwd=R,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode!=0
   continue
  before=git('show',BASE+':'+path);assert SHA(before)==item['before_lf_sha256'];text=before.decode();parts=[];cursor=0
  for edit in item['base_offset_edits']:
   assert cursor<=edit['base_start']<=edit['base_end'] and text[edit['base_start']:edit['base_end']]==edit['before']
   parts.extend([text[cursor:edit['base_start']],edit['after']]);cursor=edit['base_end']
  parts.append(text[cursor:]);assert ''.join(parts).encode()==actual
 assert git('rev-parse','HEAD').decode().strip()==head
 return dict(status='ACTUAL_COMPLETE_FOURTEEN_FILE_HYDRAULIC_COMPOSITION_GIT_INDEX_WORKING_SOURCE_AND_LITERAL_PARENT_INVERSES_PASS',actual_source=head,parent=BASE,files=14,source_or_filesystem_identity_projected=False,model_executions=0,compiler_executions=0)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=source()
 with a.output.open('x') as out:out.write(json.dumps(q,indent=2)+'\n')
 print(q['status'],flush=True)
