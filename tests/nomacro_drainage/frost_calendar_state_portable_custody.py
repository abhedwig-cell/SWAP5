"""Original Frost calendar Ubuntu producer capsule, controller and workflow byte custody."""
import hashlib,io,json,subprocess,tarfile,zipfile
from frost_history_state_archives import R,SHA

def git(*args):return subprocess.check_output(['git',*args],cwd=R)


def source(store,stack,expected_producer='ed7042f02214b492eb23c1e7a9fda393865e8dc4',expected_physical='ed7042f02214b492eb23c1e7a9fda393865e8dc4',expected_workflow='.github/workflows/nomacro-frost-calendar-state02.yml'):
    captured=json.loads(store.get('source/RESULT.json'));raw=store.get('source/actual-producer-source.zip')
    assert captured['producer_head']==expected_producer and len(raw)==captured['bytes'] and SHA(raw)==captured['sha256']
    assert not git('diff',expected_physical,expected_producer,'--','app','src','tools/solute','tools/vq','reference')
    cap=stack.enter_context(zipfile.ZipFile(io.BytesIO(raw)))
    expected={line.split('\t',1)[1]:line.split('\t',1)[0].split()[2] for line in git('ls-tree','-r',expected_producer).decode().splitlines()}
    def check(name,value,item):
        assert len(value)==item['bytes'] and SHA(value)==item['sha256']
        blob=lambda v:hashlib.sha1(b'blob '+str(len(v)).encode()+b'\0'+v).hexdigest()
        assert item['git_blob']==expected[name] and expected[name] in (blob(value),blob(value.replace(b'\r\n',b'\n')))
    absent={name for name,item in captured['members'].items() if item.get('checkout')=='ABSENT'}
    assert all(name.startswith('reference/swap-4.3.1/') for name in absent)
    assert set(cap.namelist())==set(captured['members'])-absent
    for name,item in captured['members'].items():
        if name in absent:assert item==dict(git_blob=expected[name],checkout='ABSENT')
        else:check(name,cap.read(name),item)
    ctl=json.loads(store.get('controller-source.json'));raw=store.get('controller-source.tar')
    assert ctl['producer_head']==expected_producer and len(raw)==ctl['bytes'] and SHA(raw)==ctl['sha256']
    tar=stack.enter_context(tarfile.open(fileobj=io.BytesIO(raw)))
    assert {m.name for m in tar.getmembers()}==set(ctl['members'])
    for name,item in ctl['members'].items():check(name,tar.extractfile(name).read(),item)
    workflow=git('show',expected_producer+':'+expected_workflow)
    assert store.get('actual-workflow.yml')==workflow
    assert store.get('actual-workflow-git-blob.txt').decode().strip()==hashlib.sha1(b'blob '+str(len(workflow)).encode()+b'\0'+workflow).hexdigest()
    original=cap.read('reference/swap-4.3.1/source-archives/SWAP.ZIP')
    prepared=json.loads(store.get('provider-PREPARED.json'))
    assert SHA(original)==prepared['source_archives']['SWAP.ZIP']=='1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151'
    for name,digest in prepared['provider_files'].items():
        if name.startswith('build/'):assert SHA(store.get('original-provider-build/'+name[len('build/'):]))==digest
    return original,dict(producer=expected_producer,source_sha256=captured['sha256'],controller_sha256=ctl['sha256'],source_members=len(captured['members']),controller_members=len(ctl['members']),toolchain=prepared['toolchain'],original_SWAP_ZIP_sha256=SHA(original))

