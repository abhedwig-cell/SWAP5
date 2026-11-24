"""Real HEAD/index/working source and actual e252 evidence; no projected views."""
import hashlib,json,re,subprocess
from pathlib import Path
from ria12_water_polish_source import R as ROOT,BASE,ADMITTED,complete_inverse,git
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized,SOURCE_DOMAINS
from ria12_corrected_source_custody import original_git_payload
from analytical_hydraulic_archives import SHA
SELF='tests/nomacro_drainage/ria12_water_polish_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
PREFIX='integration/f-ci/nomacro-complete01/'
DOMAINS=(*SOURCE_DOMAINS,'.gitattributes','docs/publication','docs/publications','docs/verification','docs/performance/evidence','docs/science/NOMACRO_RIA_WATER_POLISH_20261124.md')
COMPILER='30630088a860df295b2c79cfb144c520b1a796ca'

def source(anchor):
    complete_inverse();head=git('rev-parse','HEAD')
    assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*DOMAINS)
    tree=lambda ref:{line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl',ref,'--',*DOMAINS).decode().splitlines()}
    parent,current,frozen=tree(ADMITTED),tree('HEAD'),tree(anchor);assert parent.keys()<=current.keys() and current.keys()==frozen.keys()
    contract=json.loads((ROOT/(PREFIX+'RIA12_WATER_POLISH_DOMAIN_CONTRACT_V1.json')).read_text())
    changed={path for path in parent if parent[path]!=current[path]};assert changed==set(contract['files'])|{JOINT},changed
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ('guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged'):
        args='text' if name=='strip_current_evidence' else ''
        before=' import ria12_corrected_verify as corrected_owner\n return corrected_owner.'+name+'('+args+')\n'
        after=' import ria12_water_polish_verify as polish_owner\n return polish_owner.'+name+'('+args+')\n'
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
    return dict(status='REAL_RIA_WATER_POLISH_SOURCE_INDEX_WORKING_LITERALS_DEFAULT_OWNER_AND_FROZEN_PROOF_PASS',actual_head=head.decode().strip(),source_anchor=anchor,parent=ADMITTED,files=observed,new_proof=new_proof,modified_inherited_files=sorted(changed),projected_views=False,compiler_executions=0,model_executions=0)

def inherited_evidence():
    head=git('rev-parse','HEAD');tracked=tracked_working_files();current={line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl','HEAD','--',PREFIX).decode().splitlines()};rows=[]
    for line in git('ls-tree','-rl',ADMITTED,'--',PREFIX).decode().splitlines():
        meta,path=line.split('\t',1)
        if Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
        mode,kind,digest,size=meta.split();assert current.get(path)==meta and kind=='blob' and tracked[path][1:]==(mode,digest)
        rows.append(dict(path=path,git_blob=digest,bytes=int(size)))
    process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE);observed=[]
    try:
        for item in rows:
            sha=hashlib.sha256();obj=hashlib.sha1(b'blob '+str(item['bytes']).encode()+b'\0');total=0
            if materialized(item['path'],tracked):
                raw=(ROOT/item['path']).read_bytes();raw_sha=SHA(raw);proven,storage=original_git_payload(raw,item['path'],item['git_blob']);total=len(proven);sha.update(proven);obj.update(proven)
            else:
                process.stdin.write((item['git_blob']+'\n').encode());process.stdin.flush();assert process.stdout.readline().decode().split()==[item['git_blob'],'blob',str(item['bytes'])];remaining=item['bytes']
                while remaining:
                    block=process.stdout.read(min(remaining,8*1024*1024));assert block;remaining-=len(block);total+=len(block);sha.update(block);obj.update(block)
                assert process.stdout.read(1)==b'\n';storage='ACTUAL_IMMUTABLE_GIT_BLOB_WITH_REAL_SKIP_WORKTREE';raw_sha=sha.hexdigest()
            assert total==item['bytes'] and obj.hexdigest()==item['git_blob']
            observed.append(dict(**item,actual_raw_sha256=raw_sha,actual_git_bytes_sha256=sha.hexdigest(),storage=storage))
    finally:process.stdin.close();assert process.wait(timeout=30)==0
    assert git('rev-parse','HEAD')==head
    return dict(status='ALL_ACTUAL_CANONICAL416_INHERITED_EVIDENCE_BLOBS_INDEX_AND_WORKING_BYTES_FRESH_EXACT',actual_parent=ADMITTED,files=observed,total_bytes=sum(x['bytes'] for x in rows),model_executions=0,compiler_executions=0)
