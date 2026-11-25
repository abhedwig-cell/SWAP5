"""Real calendar HEAD/index/working source and exact admitted472 evidence custody."""
import hashlib,json,re,subprocess
from pathlib import Path
from frost_history_state_archives import R as ROOT
BASE='8dbe3db7c7832dd6a1f86c4275cd43f054552df3'
from frost_calendar_state_batch import source as complete_inverse
ADMITTED=BASE
def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized,SOURCE_DOMAINS
from ria12_corrected_source_custody import original_git_payload
from analytical_hydraulic_archives import SHA
SELF='tests/nomacro_drainage/frost_calendar_state_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
PREFIX='integration/f-ci/nomacro-complete01/'
DOMAINS=(*SOURCE_DOMAINS,'.gitattributes','docs/publication','docs/publications','docs/verification','docs/performance/evidence','docs/science/NOMACRO_RIA_WATER_POLISH_20261124.md','docs/science/NOMACRO_FROST_HISTORY_STATE01.md','docs/science/NOMACRO_FROST_CALENDAR_STATE02.md')
COMPILER='a6823044669a113bfb3b5329c36377ed5941155b'

def source(anchor):
    complete_inverse();head=git('rev-parse','HEAD')
    assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*DOMAINS)
    tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',*DOMAINS).decode().splitlines()}
    parent,current,frozen=tree(ADMITTED),tree('HEAD'),tree(anchor);assert parent.keys()<=current.keys() and current.keys()==frozen.keys()
    contract=json.loads((ROOT/(PREFIX+'FROST_CALENDAR_STATE02_CONTRACT_V1.json')).read_text())
    ci=contract.get('ci_dependency_materialization',{})
    changed={path for path in parent if parent[path]!=current[path]}
    inherited_edits={path for path,item in contract['files'].items() if not item['added']}
    assert changed==inherited_edits|{JOINT}|set(ci),changed
    for path,item in ci.items():
        before=git('show',ADMITTED+':'+path);after=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(before)==item['before_lf_sha256'] and SHA(after)==item['proposed_lf_sha256']
        assert before.count(item['before_literal'].encode())==1
        assert before.replace(item['before_literal'].encode(),item['after_literal'].encode(),1)==after==git('show','HEAD:'+path)
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
        args='text' if name=='strip_current_evidence' else ''
        before=' import frost_history_state_verify as frost_owner\n return frost_owner.'+name+'('+args+')\n'
        after=' import frost_calendar_state_verify as calendar_owner\n return calendar_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',ADMITTED+':'+JOINT)
    tracked=tracked_working_files();observed=[]
    for path,meta in frozen.items():
        mode,kind,digest,size=meta.split();assert mode!='120000' and kind=='blob' and path in tracked and tracked[path][1]==mode
        if path!=SELF:assert current[path]==meta and tracked[path][2]==digest,'Changed frozen source/index '+path
        if not materialized(path,tracked):continue
        raw=(ROOT/path).read_bytes();normalized=raw.replace(b'\r\n',b'\n')
        if path==SELF:
            pattern=br"(?m)^SEALED='[0-9a-f]{40}'$";left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",normalized);right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+path));assert a==b==1 and left==right
        else:
            blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
            assert digest in (blob(raw),blob(normalized)),'Changed actual source bytes '+path
        observed.append(dict(path=path,actual_raw_sha256=SHA(raw)))
    proof_tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',PREFIX).decode().splitlines()}
    old,new,anchor_proof=proof_tree(ADMITTED),proof_tree('HEAD'),proof_tree(anchor);new_proof=[]
    for path,meta in anchor_proof.items():
        if path in old or Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
        mode,kind,digest,size=meta.split();assert new.get(path)==meta and tracked[path][1:]==(mode,digest)
        raw=(ROOT/path).read_bytes() if materialized(path,tracked) else git('cat-file','blob',digest)
        proven,storage=original_git_payload(raw,path,digest);new_proof.append(dict(path=path,actual_raw_sha256=SHA(raw),actual_git_bytes_sha256=SHA(proven),storage=storage))
    assert git('rev-parse','HEAD')==head
    return dict(status='REAL_FROST_CALENDAR_SOURCE_INDEX_WORKING_LITERALS_DAILY_OWNER_AND_FROZEN_PROOF_PASS',actual_head=head.decode().strip(),source_anchor=anchor,parent=ADMITTED,files=observed,new_proof=new_proof,modified_inherited_files=sorted(changed),projected_views=False,compiler_executions=0,model_executions=0)

def inherited_evidence():
    from frost_calendar_state_inherited_custody import inherited_evidence as fresh_parent_bytes
    return fresh_parent_bytes()
