"""Proposed complete current APP delta proof against genuine canonical880."""
import ast,argparse,json,re
from pathlib import Path
from closed_implicit_state_feedback import R,P,PARENT,SHA,git
PROPOSAL='CLOSED_IMPLICIT_STATE13_SOURCE_PROPOSAL_V2.json'


def source():
    before_head=git('rev-parse','HEAD').decode().strip()
    assert not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('status','--porcelain=v1','--untracked-files=all','--ignored')
    contract=json.loads(git('show','HEAD:'+P+PROPOSAL))
    assert contract['actual_canonical_parent']==PARENT and not contract['physical_equations_changed'] and not contract['new_physical_state'] and not contract['new_numerical_policy']
    expected=contract['files'];changed=set(git('diff','--name-only',PARENT,'HEAD','--','app').decode().splitlines());assert changed==set(expected)
    assert not git('diff',PARENT,'HEAD','--','src','tools','reference')
    observations=[]
    for path,item in expected.items():
        exists=not item['new_file'];before=git('show',PARENT+':'+path) if exists else b''
        if not exists:
            import subprocess
            assert subprocess.run(['git','cat-file','-e',PARENT+':'+path],cwd=R,capture_output=True).returncode!=0
        actual=git('show','HEAD:'+path)
        assert (R/path).read_bytes().replace(b'\r\n',b'\n')==actual
        assert SHA(before)==item['before_lf_sha256'] and SHA(actual)==item['after_lf_sha256']
        text=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            lo,hi=edit['base_start'],edit['base_end'];assert cursor<=lo<=hi and text[lo:hi]==edit['before']
            parts.extend([text[cursor:lo],edit['after']]);cursor=hi
        parts.append(text[cursor:]);assert ''.join(parts).encode()==actual;ast.parse(actual)
        observations.append(dict(path=path,actual_lf_sha256=SHA(actual),genuine_parent_lf_sha256=SHA(before),complete_literal_reconstruction=True))
    # Every old archived scientific member retains the actual original Git
    # blob. New local evidence never substitutes for a historical archive.
    old={}
    for row in git('ls-tree','-r',PARENT,'--',P).splitlines():
        meta,path=row.split(b'\t',1);old[path.decode()]=meta.split()[2].decode()
    now={}
    for row in git('ls-tree','-r','HEAD','--',P).splitlines():
        meta,path=row.split(b'\t',1);now[path.decode()]=meta.split()[2].decode()
    assert old.keys()<=now.keys()
    changed_evidence={path for path,digest in old.items() if digest!=now[path]}
    assert changed_evidence<={P+'STATUS.json',P+'GAP_MATRIX.json'}
    assert git('rev-parse','HEAD').decode().strip()==before_head
    return dict(status='ACTUAL_CURRENT_COMPLETE_APP_LITERAL_PARENT_INVERSES_AND_ALL_ORIGINAL_EVIDENCE_GIT_BLOBS_PRESERVED',actual_source=before_head,
                actual_canonical_parent=PARENT,APP_files=observations,original_evidence_blobs=len(old)-len(changed_evidence),
                physical_equations_changed=False,new_physical_state=False,new_numerical_policy=False,
                source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();q=source()
    with a.output.open('x',encoding='utf8') as out:json.dump(q,out,indent=2);out.write('\n')
    print(q['status'],len(q['APP_files']),flush=True)
