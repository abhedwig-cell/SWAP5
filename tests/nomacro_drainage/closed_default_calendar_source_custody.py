"""Real HEAD/index/working custody and literal complete closed/Gardner source inverses."""
import json,re
from pathlib import Path
from closed_default_calendar_feedback import R as ROOT,P as PREFIX,PARENT as BASE,SHA,git
from closed_default_calendar_source_contract import source as complete_inverse
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
from ci_checkout_scope07_inherited_custody import original_git_payload
SCIENTIFIC='0a43d8a48cfc5ed98164b1873a3e6a6aa93fb744'
SELF='tests/nomacro_drainage/closed_default_calendar_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'


def tree(ref):
    result={}
    for row in git('ls-tree','-r','-z',ref).split(b'\0'):
        if row:
            meta,path=row.split(b'\t',1);result[path.decode()]=tuple(meta.decode().split())
    return result


def actual_eol_inventory(paths):
    """Batch actual Git metadata for the same nonexact working text files."""
    result={};batch=[];size=0;commands=0
    def read(names):
        for row in git('ls-files','--eol','-z','--',*names).split(b'\0'):
            if not row:continue
            meta,name=row.split(b'\t',1);name=name.decode();assert name not in result
            result[name]=meta.decode().split()
    for path in paths:
        length=len(path.encode('utf-16-le'))//2+3
        assert length<16000
        if batch and size+length>16000:
            read(batch);commands+=1;batch=[];size=0
        batch.append(path);size+=length
    if batch:read(batch);commands+=1
    assert set(result)==set(paths)
    return result,commands


def source(anchor):
    head=git('rev-parse','HEAD');assert re.fullmatch('[0-9a-f]{40}',anchor)
    assert not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('status','--porcelain=v1','--untracked-files=all')
    assert not git('diff',SCIENTIFIC,'HEAD','--','app','src','tools','reference')
    old,current,frozen=tree(BASE),tree('HEAD'),tree(anchor)
    assert old.keys()<=current.keys() and current.keys()==frozen.keys()
    metadata={PREFIX+'STATUS.json',PREFIX+'GAP_MATRIX.json'};tracked=tracked_working_files()
    for path,(mode,kind,digest) in current.items():
        assert mode!='120000' and kind=='blob' and tracked[path][1:]==(mode,digest),'Changed actual index: '+path
        if path not in metadata|{SELF}:assert current[path]==frozen[path],'Changed frozen actual source: '+path
    pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
    left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show','HEAD:'+SELF));right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+SELF))
    assert a==b==1 and left==right
    literal=complete_inverse();contract=json.loads(git('show','HEAD:'+PREFIX+'CLOSED_DEFAULT_CALENDAR_STATE14_SOURCE_PROPOSAL_V3.json'))
    expected={p for p,item in contract['files'].items() if not item['new_file']}|{JOINT,'.github/workflows/fci-canonical.yml','tests/nomacro_drainage/ci_checkout_scope07.py'}|metadata
    assert {p for p in old if old[p]!=current[p]}==expected
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ['guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged']:
        args='text' if name=='strip_current_evidence' else ''
        before=' import closed_implicit_state_verify as closed_owner\n return closed_owner.'+name+'('+args+')\n'
        after=' import closed_default_calendar_verify as closed_owner\n return closed_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',BASE+':'+JOINT)
    workflow='.github/workflows/fci-canonical.yml'
    raw=(ROOT/workflow).read_bytes().replace(b'\r\n',b'\n')
    full=b'            /*\n            !/integration/**/*.zip\n            !/integration/**/*.zip.part*\n'
    assert raw.count(full)==2
    assert raw.replace(full,b'            /*\n',2)==git('show',BASE+':'+workflow)
    guard_path='tests/nomacro_drainage/ci_checkout_scope07.py'
    hook=("    if path=='.github/workflows/fci-canonical.yml' and SHA(text.encode())=='2b64bdc8dad6c021f5dc46ce3d3ba4ea427e4005f76f912edc9b099485938863':\n"
          "        import importlib.util\n"
          "        spec=importlib.util.spec_from_file_location('actual_closed_default_checkout',Path(__file__).with_name('closed_default_calendar_checkout.py'))\n"
          "        current=importlib.util.module_from_spec(spec);spec.loader.exec_module(current)\n"
          "        text=current.historical_parent(path,text)\n")
    raw=(ROOT/guard_path).read_bytes().replace(b'\r\n',b'\n');assert raw.count(hook.encode())==1
    assert raw.replace(hook.encode(),b'',1)==git('show',BASE+':'+guard_path)
    assert git('show','HEAD:tests/hupsel51/test_successor.py')==git('show',BASE+':tests/hupsel51/test_successor.py')
    import hashlib
    blob=lambda raw:hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()
    observed=[];pending=[]
    for path,(mode,kind,digest) in current.items():
        if not materialized(path,tracked):continue
        raw=(ROOT/path).read_bytes()
        if path==SELF:
            left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",raw.replace(b'\r\n',b'\n'));right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+path));assert a==b==1 and left==right
        elif blob(raw)==digest:original_git_payload(raw,path,digest,{})
        else:pending.append((path,digest,SHA(raw)))
        if path.startswith(('app/','src/','tools/','tests/','.github/')):observed.append(dict(path=path,actual_raw_sha256=SHA(raw)))
    eols,eol_commands=actual_eol_inventory([path for path,_,_ in pending])
    for path,digest,first_sha in pending:
        raw=(ROOT/path).read_bytes();assert SHA(raw)==first_sha
        original_git_payload(raw,path,digest,eols)
    assert git('rev-parse','HEAD')==head and tracked_working_files()==tracked
    return dict(status='REAL_CLOSED_DEFAULT_CALENDAR_CURRENT_HEAD_INDEX_WORKING_AND_COMPLETE_LITERAL_SOURCE_INVERSES_PASS',actual_head=head.decode().strip(),source_anchor=anchor,
                actual_local_scientific_source=SCIENTIFIC,parent=BASE,files=observed,modified_inherited_files=sorted(expected),literal_source_proof=literal,
                source_or_filesystem_identity_projected=False,actual_nonexact_working_files=len(pending),actual_Git_eol_batch_commands=eol_commands,
                original_per_file_Git_payload_checks_unchanged=True,compiler_executions=0,model_executions=0)
