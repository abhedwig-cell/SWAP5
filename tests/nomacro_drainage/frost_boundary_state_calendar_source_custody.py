"""Actual source/index/working bytes and literal canonical524 dependency closure."""
import hashlib,json,re,subprocess
from pathlib import Path
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
from frost_calendar_state_source_custody import DOMAINS as PARENT_DOMAINS
from frost_boundary_state_calendar_input_contract import source as complete_inverse
from ria12_corrected_source_custody import original_git_payload

ROOT=Path(__file__).resolve().parents[2]
BASE='9936bcda75eb920d67aa74e47018baf39ab18f78'
COMPILER='dfb4337cb5fffcf70b1fa20a672683c6ea034690'
SELF='tests/nomacro_drainage/frost_boundary_state_calendar_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
PREFIX='integration/f-ci/nomacro-complete01/'
DOMAINS=(*PARENT_DOMAINS,'docs/science/NOMACRO_FROST_BOUNDARY03.md','docs/science/NOMACRO_FROST_BOUNDARY_STATE_CALENDAR04.md')
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def source(anchor):
    complete_inverse();head=git('rev-parse','HEAD')
    assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*DOMAINS)
    tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',*DOMAINS).decode().splitlines()}
    parent,current,frozen=tree(BASE),tree('HEAD'),tree(anchor)
    assert parent.keys()<=current.keys() and current.keys()==frozen.keys()
    contract=json.loads((ROOT/(PREFIX+'FROST_BOUNDARY_STATE_CALENDAR04_CONTRACT_V1.json')).read_text())
    changed={path for path in parent if parent[path]!=current[path]}
    inherited={path for path,item in contract['files'].items() if not item['added']}
    adapters=contract['read_only_runtime_witnesses']
    assert changed==inherited|{JOINT}|set(adapters),changed
    for path,item in adapters.items():
        before=git('show',BASE+':'+path);after=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(before)==item['before_lf_sha256'] and SHA(after)==item['proposed_lf_sha256']
        text=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert text[edit['base_start']:edit['base_end']]==edit['before']
            parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==after==git('show','HEAD:'+path)
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
        args='text' if name=='strip_current_evidence' else ''
        before=' import frost_boundary_verify as boundary_owner\n return boundary_owner.'+name+'('+args+')\n'
        after=' import frost_boundary_state_calendar_verify as state_calendar_owner\n return state_calendar_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',BASE+':'+JOINT)
    tracked=tracked_working_files();observed=[]
    for path,meta in frozen.items():
        mode,kind,digest,size=meta.split();assert mode!='120000' and kind=='blob' and path in tracked and tracked[path][1]==mode
        if path!=SELF:assert current[path]==meta and tracked[path][2]==digest,'Changed frozen source/index '+path
        if not materialized(path,tracked):continue
        raw=(ROOT/path).read_bytes();normalized=raw.replace(b'\r\n',b'\n')
        if path==SELF:
            pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
            left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",normalized);right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+path))
            assert a==b==1 and left==right
        else:
            blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
            assert digest in (blob(raw),blob(normalized)),'Changed actual working source '+path
        observed.append(dict(path=path,actual_raw_sha256=SHA(raw)))
    proof_tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',PREFIX).decode().splitlines()}
    old,new,anchor_proof=proof_tree(BASE),proof_tree('HEAD'),proof_tree(anchor);new_proof=[]
    for path,meta in anchor_proof.items():
        if path in old or Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
        mode,kind,digest,size=meta.split();assert new.get(path)==meta and tracked[path][1:]==(mode,digest)
        raw=(ROOT/path).read_bytes() if materialized(path,tracked) else git('cat-file','blob',digest)
        original,storage=original_git_payload(raw,path,digest)
        new_proof.append(dict(path=path,actual_raw_sha256=SHA(raw),actual_git_bytes_sha256=SHA(original),storage=storage))
    assert git('rev-parse','HEAD')==head
    return dict(status='REAL_FROST_BOUNDARY_CALENDAR_SOURCE_INDEX_WORKING_LITERALS_AND_ACTUAL_TRIAL_FLUX_SOURCE_PASS',
                actual_head=head.decode().strip(),source_anchor=anchor,parent=BASE,files=observed,new_proof=new_proof,
                modified_inherited_files=sorted(changed),source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)
