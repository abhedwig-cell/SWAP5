"""Genuine current HEAD/index/working custody and exact undrained source inverses."""
import hashlib,json,re,subprocess
from pathlib import Path
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized
from ci_checkout_scope07_inherited_custody import original_git_payload
from frost_analytical_boundary_input_contract import source as complete_inverse
ROOT=Path(__file__).resolve().parents[2]
BASE='9af88c3de6198ddec40c2674dd1542a89fa9c0d7'
COMPILER='45bb6146f5800f4050e95feb5d1912ddfdd23d4d'
SELF='tests/nomacro_drainage/frost_analytical_boundary_verify.py'
JOINT='tests/nomacro_drainage/initial_profile_age_groundwater_verify.py'
PREFIX='integration/f-ci/nomacro-complete01/'
git=lambda *a:subprocess.check_output(['git',*a],cwd=ROOT)
SHA=lambda b:hashlib.sha256(b).hexdigest()

def tree(ref):
    result={}
    for row in git('ls-tree','-r','-z',ref).split(b'\0'):
        if row:
            meta,path=row.split(b'\t',1);result[path.decode()]=tuple(meta.decode().split())
    return result

def source(anchor):
    head=git('rev-parse','HEAD')
    assert re.fullmatch('[0-9a-f]{40}',anchor) and not git('for-each-ref','--format=%(refname)','refs/replace')
    assert not git('status','--porcelain=v1','--untracked-files=all')
    assert not git('diff',COMPILER,'HEAD','--','app','src','tools','reference')
    old,current,frozen=tree(BASE),tree('HEAD'),tree(anchor)
    assert old.keys()<=current.keys() and current.keys()==frozen.keys()
    # Refuse any committed/index mutation before reading large working archives.
    metadata={PREFIX+'STATUS.json',PREFIX+'GAP_MATRIX.json'}
    tracked=tracked_working_files()
    for path,(mode,kind,digest) in current.items():
        assert mode!='120000' and kind=='blob' and tracked[path][1:]==(mode,digest),'Changed actual source index: '+path
        if path not in metadata|{SELF}:assert current[path]==frozen[path],'Changed frozen actual repository source: '+path
    pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
    left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show','HEAD:'+SELF))
    right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+SELF))
    assert a==b==1 and left==right
    complete_inverse()
    contract=json.loads(git('show','HEAD:'+PREFIX+'FROST_ANALYTICAL_BOUNDARY10_SOURCE_PROPOSAL_V4.json'))
    adapters=json.loads(git('show','HEAD:'+PREFIX+'FROST_ANALYTICAL_BOUNDARY10_PARENT_METADATA_WITNESSES_V1.json'))
    assert adapters['actual_parent']==BASE
    metadata={PREFIX+'STATUS.json',PREFIX+'GAP_MATRIX.json'}
    expected={p for p,item in contract['files'].items() if not item.get('added')}|{JOINT}|set(adapters['files'])|metadata
    assert {p for p in old if old[p]!=current[p]}==expected
    for p,item in adapters['files'].items():
        before=git('show',BASE+':'+p);actual=(ROOT/p).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(before)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256']
        text=before.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            assert cursor<=edit['base_start']<=edit['base_end'] and text[edit['base_start']:edit['base_end']]==edit['before']
            parts.extend((text[cursor:edit['base_start']],edit['after']));cursor=edit['base_end']
        parts.append(text[cursor:]);assert ''.join(parts).encode()==actual==git('show','HEAD:'+p)
    actual=(ROOT/JOINT).read_bytes().replace(b'\r\n',b'\n')
    for name in ['guard_previous_source','verify','strip_current_evidence','publication_dependencies_unchanged']:
        args='text' if name=='strip_current_evidence' else ''
        before=' import frost_analytical_verify as analytical_owner\n return analytical_owner.'+name+'('+args+')\n'
        after=' import frost_analytical_boundary_verify as boundary_owner\n return boundary_owner.'+name+'('+args+')\n'
        assert actual.count(after.encode())==1;actual=actual.replace(after.encode(),before.encode(),1)
    assert actual==git('show',BASE+':'+JOINT)
    eols={}
    text_patterns=[':(glob)**/*.'+ext for ext in ['py','json','md','yml','yaml','f90','F90','f','F','txt','toml','ini','cfg','cmake','xml','sh','ps1','cpp','c','h']]
    for row in git('ls-files','--eol','-z','--',*text_patterns).split(b'\0'):
        if row:
            meta,path=row.split(b'\t',1);eols[path.decode()]=meta.decode().split()
    observed=[]
    for p,(mode,kind,digest) in current.items():
        assert mode!='120000' and kind=='blob' and tracked[p][1:]==(mode,digest),'Changed actual source index: '+p
        if p not in metadata|{SELF}:assert current[p]==frozen[p],'Changed frozen actual repository source: '+p
        if not materialized(p,tracked):continue
        raw=(ROOT/p).read_bytes()
        if p==SELF:
            normal=raw.replace(b'\r\n',b'\n');pattern=br"(?m)^SEALED='[0-9a-f]{40}'$"
            left,a=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",normal);right,b=re.subn(pattern,b"SEALED='SOURCE_ANCHOR'",git('show',anchor+':'+p));assert a==b==1 and left==right
        else:original_git_payload(raw,p,digest,eols)
        if p.startswith(('app/','src/','tools/','tests/','.github/')):observed.append(dict(path=p,actual_raw_sha256=SHA(raw)))
    assert git('rev-parse','HEAD')==head and tracked_working_files()==tracked
    return dict(status='REAL_ANALYTICAL_BOUNDARY_FROST_HEAD_INDEX_WORKING_COMPLETE_SOURCE_AND_LITERAL_INVERSES_PASS',actual_head=head.decode().strip(),source_anchor=anchor,original_compiled_source=COMPILER,parent=BASE,files=observed,modified_inherited_files=sorted(expected),source_or_filesystem_identity_projected=False,compiler_executions=0,model_executions=0)
