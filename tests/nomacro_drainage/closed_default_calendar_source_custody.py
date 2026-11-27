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
    expected={p for p,item in contract['files'].items() if not item['new_file']}|{JOINT,'.github/workflows/fci-canonical.yml','tests/hupsel51/test_successor.py'}|metadata
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
    test_path='tests/hupsel51/test_successor.py'
    before="                else:new=checkout.historical_workflow(path,new)\n"
    after=("                else:\n"
           "                    spec=importlib.util.spec_from_file_location('actual_closed_default_checkout_custody',s.ROOT/'tests/nomacro_drainage/closed_default_calendar_checkout.py')\n"
           "                    custody=importlib.util.module_from_spec(spec);spec.loader.exec_module(custody)\n"
           "                    new=checkout.historical_workflow(path,custody.historical_parent(path,new))\n")
    raw=(ROOT/test_path).read_bytes().replace(b'\r\n',b'\n');assert raw.count(after.encode())==1
    assert raw.replace(after.encode(),before.encode(),1)==git('show',BASE+':'+test_path)
    eols={};patterns=[':(glob)**/*.'+ext for ext in ['py','json','md','yml','yaml','f90','F90','f','F','txt','toml','ini','cfg','cmake','xml','sh','ps1','cpp','c','h']]
    for row in git('ls-files','--eol','-z','--',*patterns).split(b'\0'):
        if row:
            meta,path=row.split(b'\t',1);eols[path.decode()]=meta.decode().split()
    observed=[]
    for path,(mode,kind,digest) in current.items():
        if not materialized(path,tracked):continue
        raw=(ROOT/path).read_bytes()
        if path==SELF:
            left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",raw.replace(b'\r\n',b'\n'));right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+path));assert a==b==1 and left==right
        else:original_git_payload(raw,path,digest,eols)
        if path.startswith(('app/','src/','tools/','tests/','.github/')):observed.append(dict(path=path,actual_raw_sha256=SHA(raw)))
    assert git('rev-parse','HEAD')==head and tracked_working_files()==tracked
    return dict(status='REAL_CLOSED_DEFAULT_CALENDAR_CURRENT_HEAD_INDEX_WORKING_AND_COMPLETE_LITERAL_SOURCE_INVERSES_PASS',actual_head=head.decode().strip(),source_anchor=anchor,
                actual_local_scientific_source=SCIENTIFIC,parent=BASE,files=observed,modified_inherited_files=sorted(expected),literal_source_proof=literal,
                source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)
