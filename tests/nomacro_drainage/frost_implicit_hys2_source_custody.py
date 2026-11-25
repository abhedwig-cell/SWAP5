"""Real current source/index/working bytes and complete canonical568 inverses."""
import hashlib,json,re,subprocess
from pathlib import Path
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
from frost_implicit_plate_source_custody import DOMAINS as PARENT_DOMAINS
from frost_implicit_hys2_input_contract import source as complete_inverse
from ria12_corrected_source_custody import original_git_payload
ROOT=Path(__file__).resolve().parents[2]
BASE='47124f4de18a752fc466d50e2752e843548e5fea'
COMPILER='23850bf112e4312745b056e5517b95e13e2af53b'
SELF='tests/nomacro_drainage/frost_implicit_hys2_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
PREFIX='integration/f-ci/nomacro-complete01/'
DOMAINS=(*PARENT_DOMAINS,'docs/science/NOMACRO_FROST_IMPLICIT_HYS2_YEAR06.md')
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
SHA=lambda b:hashlib.sha256(b).hexdigest()


def source(anchor):
    complete_inverse();head=git('rev-parse','HEAD')
    assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*DOMAINS)
    tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',*DOMAINS).decode().splitlines()}
    old,current,frozen=tree(BASE),tree('HEAD'),tree(anchor)
    assert old.keys()<=current.keys() and current.keys()==frozen.keys()
    from frost_implicit_hys2_metadata import read
    contract=read('FROST_IMPLICIT_HYS2_YEAR06_CONTRACT_V1.json');adapters=contract.get('read_only_runtime_witnesses',{})
    modified={p for p in old if old[p]!=current[p]}
    assert modified=={p for p,i in contract['files'].items() if not i.get('added')}|{JOINT}|set(adapters),modified
    for p,item in adapters.items():
        before=git('show',BASE+':'+p);after=(ROOT/p).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(before)==item['before_lf_sha256'] and SHA(after)==item['proposed_lf_sha256']
        text=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert text[edit['base_start']:edit['base_end']]==edit['before'];parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==after==git('show','HEAD:'+p)
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ['guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged']:
        args='text' if name=='strip_current_evidence' else ''
        before=' import frost_implicit_plate_verify as plate_owner\n return plate_owner.'+name+'('+args+')\n'
        after=' import frost_implicit_hys2_verify as hys2_owner\n return hys2_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',BASE+':'+JOINT)
    tracked=tracked_working_files();observed=[]
    for p,meta in frozen.items():
        mode,kind,digest,size=meta.split();assert mode!='120000' and kind=='blob' and tracked[p][1]==mode
        if p!=SELF:assert current[p]==meta and tracked[p][2]==digest,'Changed frozen actual source/index: '+p
        if not materialized(p,tracked):continue
        raw=(ROOT/p).read_bytes();normal=raw.replace(b'\r\n',b'\n')
        if p==SELF:
            pattern=br"(?m)^SEALED='[0-9a-f]{40}'$";left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",normal);right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+p));assert a==b==1 and left==right
        else:
            blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest();assert digest in (blob(raw),blob(normal)),'Changed actual working source: '+p
        observed.append(dict(path=p,actual_raw_sha256=SHA(raw)))
    proof_tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',PREFIX).decode().splitlines()}
    parent_proof,actual_proof,sealed_proof=proof_tree(BASE),proof_tree('HEAD'),proof_tree(anchor);new_proof=[]
    for p,meta in sealed_proof.items():
        if p in parent_proof or Path(p).name in ('STATUS.json','GAP_MATRIX.json'):continue
        mode,kind,digest,size=meta.split();assert actual_proof.get(p)==meta and tracked[p][1:]==(mode,digest)
        raw=(ROOT/p).read_bytes() if materialized(p,tracked) else git('cat-file','blob',digest);original,storage=original_git_payload(raw,p,digest)
        new_proof.append(dict(path=p,actual_raw_sha256=SHA(raw),actual_git_bytes_sha256=SHA(original),storage=storage))
    assert git('rev-parse','HEAD')==head
    return dict(status='REAL_IMPLICIT_HYS2_BOUNDARY_HEAD_INDEX_WORKING_COMPLETE_SOURCE_AND_HISTORICAL_DATA_INTERFACE_CUSTODY_PASS',actual_head=head.decode().strip(),source_anchor=anchor,parent=BASE,files=observed,new_proof=new_proof,modified_inherited_files=sorted(modified),source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)
