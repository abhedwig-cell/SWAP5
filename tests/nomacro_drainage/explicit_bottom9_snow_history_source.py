"""Exact two-guard configuration delta from the actual canonical280 owner."""
import hashlib,json,subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
CORE='2a14f2094bfbfb29c169eb6331da1d7829faa70a'
git=lambda *args:subprocess.check_output(['git',*args],cwd=ROOT)
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def complete_inverse():
    path='integration/f-ci/nomacro-complete01/EXPLICIT_BOTTOM9_SNOW_HISTORY_CONTRACT_V1.json'
    raw=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
    assert raw==git('show','HEAD:'+path),'Dirty actual configuration contract'
    q=json.loads(raw)
    assert q['actual_canonical']==CORE and q['physical_equations_changed'] is False
    assert q['native_format_changed'] is False and q['new_physical_state'] is False
    domains=('app','src','tools','reference')
    expected=set(q['files'])
    assert set(git('diff','--name-only',CORE,'HEAD','--',*domains).decode().splitlines())==expected
    assert not git('status','--porcelain=v1','--untracked-files=all','--',*domains,'tests','.github'),'Dirty actual execution source'
    assert set(git('diff','--name-only',CORE,'--',*domains).decode().splitlines())==expected
    for path,item in q['files'].items():
        original=git('show',CORE+':'+path)
        actual=(ROOT/path).read_bytes().replace(b'\r\n',b'\n')
        assert SHA(original)==item['before_lf_sha256'] and SHA(actual)==item['proposed_lf_sha256']
        old,new=item['literal_old'].encode(),item['literal_new'].encode()
        assert actual.count(new)==1 and actual.replace(new,old,1)==original,'Incomplete literal guard inverse: '+path
        assert git('show','HEAD:'+path)==actual,'Actual guard bytes differ from committed source'
    return dict(status='TWO_COMPLETE_LITERAL_GUARD_INVERSES_ALL_OTHER_PHYSICAL_SOURCE_UNCHANGED',
                actual_head=git('rev-parse','HEAD').decode().strip(),actual_canonical=CORE,
                physical_equations_changed=False,native_format_changed=False,compiler_executions=0,model_executions=0)
