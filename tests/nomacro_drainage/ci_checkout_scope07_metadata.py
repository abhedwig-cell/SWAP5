"""Read current06 metadata with genuine HEAD/index/working or skip-worktree custody."""
import hashlib,json,subprocess
from pathlib import Path

R=Path(__file__).resolve().parents[2]
PREFIX='integration/f-ci/nomacro-complete01/'


def raw(name):
    assert Path(name).name==name and name.startswith('CI_CHECKOUT_SCOPE07_') and name.endswith('.json')
    git=lambda *a:subprocess.check_output(['git',*a],cwd=R)
    head=git('rev-parse','HEAD').decode().strip();path=PREFIX+name
    entries=[row for row in git('ls-files','-v','-s','-z','--',path).split(b'\0') if row]
    assert len(entries)==1,'Missing tracked current06 metadata: '+path
    meta,actual_path=entries[0].split(b'\t',1);flag,mode,digest,stage=meta.decode().split()
    assert actual_path.decode()==path and mode=='100644' and stage=='0'
    original=git('cat-file','blob',head+':'+path)
    blob=lambda b:hashlib.sha1(b'blob '+str(len(b)).encode()+b'\0'+b).hexdigest()
    assert blob(original)==digest,'Current06 metadata HEAD/index differ: '+path
    physical=R/path;assert not physical.is_symlink()
    if physical.is_file():
        actual=physical.read_bytes()
        if blob(actual)!=digest:
            assert b'\0' not in actual
            eols=[row for row in git('ls-files','--eol','-z','--',path).split(b'\0') if row]
            assert len(eols)==1
            spelling,spelled_path=eols[0].split(b'\t',1)
            assert spelled_path.decode()==path and 'i/lf' in spelling.decode().split() and 'attr/-text' not in spelling.decode().split()
            assert actual.replace(b'\r\n',b'\n')==original,'Changed actual current06 working metadata: '+path
    else:assert not physical.exists() and flag=='S','Missing materialized current06 metadata: '+path
    assert git('rev-parse','HEAD').decode().strip()==head
    return original


def read(name):return json.loads(raw(name))
