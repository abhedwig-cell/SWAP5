"""Actual diagnostic source inverse against qualified parent candidate7e."""
from pathlib import Path
import hashlib,json,subprocess
R=Path(__file__).resolve().parents[2]
BASE='7e7924a0e01ef94eef5b64aaad0b74d246e57544'
git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
SHA=lambda raw:hashlib.sha256(raw).hexdigest()
def check():
    name='integration/f-ci/nomacro-complete01/PAIRED_VAPOR_THERMAL02_DIAGNOSTIC_CONTRACT_V1.json'
    raw=(R/name).read_bytes().replace(b'\r\n',b'\n');assert raw==git('show','HEAD:'+name);q=json.loads(raw)
    assert q['source_dependency']==BASE and q['diagnostic_only'] and not q['canonical_admission']
    assert not git('status','--porcelain=v1','--untracked-files=all','--','app','src','tools','tests','.github')
    subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=R,check=True)
    assert set(git('diff','--name-only',BASE,'HEAD','--','app','src','tools','reference').decode().splitlines())==set(q['files'])|set(q['added_files'])
    for path,item in q['files'].items():
        old=git('show',BASE+':'+path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(old)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
        source=old.decode();parts=[];cursor=0
        for edit in item['ordered_literal_edits']:
            lo,hi=edit['base_start'],edit['base_end'];assert cursor<=lo<=hi and source[lo:hi]==edit['before'];parts.extend((source[cursor:lo],edit['after']));cursor=hi
        parts.append(source[cursor:]);assert ''.join(parts).encode()==actual
    for path,item in q['added_files'].items():
        assert not git('ls-tree',BASE,'--',path);actual=(R/path).read_bytes().replace(b'\r\n',b'\n');assert SHA(actual)==item['proposed_lf_sha256'] and actual==git('show','HEAD:'+path)
    return dict(status='ACTUAL_BOUNDED_DIAGNOSTIC_SOURCE_LITERAL_INVERSE_PASS_NOT_QUALIFIED',source=git('rev-parse','HEAD').decode().strip(),parent_candidate=BASE)
