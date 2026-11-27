"""Actual current source/index/worktree and complete literal M14 inverses."""
import json,re
from closed_initialization_calendar_feedback import R as ROOT,P as PREFIX,PARENT as BASE,SHA,git
from closed_initialization_calendar_science import source_contract
from closed_default_calendar_source_custody import tree,actual_eol_inventory
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
from ci_checkout_scope07_inherited_custody import original_git_payload
SCIENTIFIC='c23ae582a249b4167dad0d59823e33d87e108475'
SELF='tests/nomacro_drainage/closed_initialization_calendar_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'


def source(anchor):
    head=git('rev-parse','HEAD');assert re.fullmatch('[0-9a-f]{40}',anchor)
    assert not git('for-each-ref','--format=%(refname)','refs/replace') and not git('status','--porcelain=v1','--untracked-files=all')
    assert not git('diff',SCIENTIFIC,'HEAD','--','app','src','tools','reference')
    old,current,frozen=tree(BASE),tree('HEAD'),tree(anchor);assert old.keys()<=current.keys() and current.keys()==frozen.keys()
    metadata={PREFIX+'STATUS.json',PREFIX+'GAP_MATRIX.json'};tracked=tracked_working_files()
    for path,(mode,kind,digest) in current.items():
        assert mode!='120000' and kind=='blob' and tracked[path][1:]==(mode,digest),'Changed actual index: '+path
        if path not in metadata|{SELF}:assert current[path]==frozen[path],'Changed actual frozen source: '+path
    pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
    a,n=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show','HEAD:'+SELF));b,m=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+SELF));assert n==m==1 and a==b
    literal=source_contract(head.decode().strip());expected={'app/hybrid_water/closed_default_calendar.py',JOINT}|metadata
    assert {p for p in old if old[p]!=current[p]}==expected
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ['guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged']:
        args='text' if name=='strip_current_evidence' else ''
        before=' import closed_default_calendar_verify as closed_owner\n return closed_owner.'+name+'('+args+')\n'
        after=' import closed_initialization_calendar_verify as closed_owner\n return closed_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',BASE+':'+JOINT)
    for path in ['.github/workflows/fci-canonical.yml','tests/hupsel51/test_successor.py','tests/nomacro_drainage/ci_checkout_scope07.py']:
        assert git('show','HEAD:'+path)==git('show',BASE+':'+path)
    import hashlib
    blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    observed=[];pending=[]
    for path,(mode,kind,digest) in current.items():
        if not materialized(path,tracked):continue
        raw=(ROOT/path).read_bytes()
        if path==SELF:
            a,n=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",raw.replace(b'\r\n',b'\n'));b,m=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+path));assert n==m==1 and a==b
        elif blob(raw)==digest:original_git_payload(raw,path,digest,{})
        else:pending.append((path,digest,SHA(raw)))
        if path.startswith(('app/','src/','tools/','tests/','.github/')):observed.append(dict(path=path,actual_raw_sha256=SHA(raw)))
    eols,commands=actual_eol_inventory([p for p,_,_ in pending])
    for path,digest,first in pending:
        raw=(ROOT/path).read_bytes();assert SHA(raw)==first;original_git_payload(raw,path,digest,eols)
    assert git('rev-parse','HEAD')==head and tracked_working_files()==tracked
    return dict(status='REAL_CURRENT_INITIAL1_2_SOURCE_INDEX_WORKING_AND_COMPLETE_M14_LITERAL_INVERSES_PASS',actual_head=head.decode().strip(),source_anchor=anchor,actual_local_scientific_source=SCIENTIFIC,parent=BASE,files=observed,modified_inherited_files=sorted(expected),literal_source_proof=literal,source_or_filesystem_identity_projected=False,actual_nonexact_working_files=len(pending),actual_Git_eol_batch_commands=commands,original_per_file_Git_payload_checks_unchanged=True,compiler_executions=0,model_executions=0)
