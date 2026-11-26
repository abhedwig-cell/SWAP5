"""Fresh admitted600 Git/index/working byte custody with one real EOL inventory."""
import hashlib,json,subprocess
from pathlib import Path
from explicit_bottom9_analytical_inherited_custody import tracked_working_files,materialized

ROOT=Path(__file__).resolve().parents[2]
BASE='47124f4de18a752fc466d50e2752e843548e5fea'
PREFIX='integration/f-ci/nomacro-complete01/'
SHA=lambda raw:hashlib.sha256(raw).hexdigest()


def git(*args):return subprocess.check_output(['git',*args],cwd=ROOT)


def fresh_eol_inventory():
    result={}
    for row in git('ls-files','--eol','-z','--',PREFIX+'*.json').split(b'\0'):
        if not row:continue
        meta,name=row.split(b'\t',1);name=name.decode();assert name not in result
        result[name]=meta.decode().split()
    return result


def original_git_payload(raw,path,digest,eols):
    blob=lambda value:hashlib.sha1(b'blob '+str(len(value)).encode()+b'\0'+value).hexdigest()
    if blob(raw)==digest:return raw,'ACTUAL_WORKING_BYTES_EXACT'
    assert b'\0' not in raw,'Changed opaque scientific evidence bytes: '+path
    if path in eols:spelling=eols[path]
    else:
        rows=[row for row in git('ls-files','--eol','-z','--',path).split(b'\0') if row]
        assert len(rows)==1,'Ambiguous original Git text path: '+path
        meta,name=rows[0].split(b'\t',1);assert name.decode()==path;spelling=meta.decode().split()
    assert 'i/lf' in spelling and 'attr/-text' not in spelling and b'\0' not in raw,'Changed opaque scientific evidence bytes: '+path
    normalized=raw.replace(b'\r\n',b'\n')
    assert blob(normalized)==digest,'Changed original Git text content: '+path
    return normalized,'ACTUAL_GIT_TEXT_CRLF_LF_SPELLING_WITH_EXACT_ORIGINAL_GIT_BLOB_AND_SEPARATE_RAW_HASH'


def inherited_evidence():
    head=git('rev-parse','HEAD');tracked=tracked_working_files();eols=fresh_eol_inventory()
    current={line.split('\t',1)[1]:line.split('\t',1)[0] for line in git('ls-tree','-rl','HEAD','--',PREFIX).decode().splitlines()};rows=[]
    for line in git('ls-tree','-rl',BASE,'--',PREFIX).decode().splitlines():
        meta,path=line.split('\t',1)
        if Path(path).name in ('STATUS.json','GAP_MATRIX.json'):continue
        mode,kind,digest,size=meta.split();assert current.get(path)==meta and kind=='blob' and tracked[path][1:]==(mode,digest)
        rows.append(dict(path=path,git_blob=digest,bytes=int(size)))
    process=subprocess.Popen(['git','cat-file','--batch'],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE);observed=[]
    try:
        for item in rows:
            sha=hashlib.sha256();obj=hashlib.sha1(b'blob '+str(item['bytes']).encode()+b'\0');total=0
            if materialized(item['path'],tracked):
                raw=(ROOT/item['path']).read_bytes();raw_sha=SHA(raw);proven,storage=original_git_payload(raw,item['path'],item['git_blob'],eols);total=len(proven);sha.update(proven);obj.update(proven)
            else:
                process.stdin.write((item['git_blob']+'\n').encode());process.stdin.flush();assert process.stdout.readline().decode().split()==[item['git_blob'],'blob',str(item['bytes'])];remaining=item['bytes']
                while remaining:
                    block=process.stdout.read(min(remaining,8*1024*1024));assert block;remaining-=len(block);total+=len(block);sha.update(block);obj.update(block)
                assert process.stdout.read(1)==b'\n';storage='ACTUAL_IMMUTABLE_GIT_BLOB_WITH_REAL_SKIP_WORKTREE';raw_sha=sha.hexdigest()
            assert total==item['bytes'] and obj.hexdigest()==item['git_blob']
            observed.append(dict(**item,actual_raw_sha256=raw_sha,actual_git_bytes_sha256=sha.hexdigest(),storage=storage))
    finally:process.stdin.close();assert process.wait(timeout=30)==0
    assert git('rev-parse','HEAD')==head and tracked_working_files()==tracked
    return dict(status='ALL_ACTUAL_CANONICAL600_INHERITED_EVIDENCE_BLOBS_INDEX_AND_WORKING_BYTES_FRESH_EXACT',actual_parent=BASE,files=observed,total_bytes=sum(x['bytes'] for x in rows),fresh_eol_inventory_executions=1,model_executions=0,compiler_executions=0)


if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();assert not a.output.exists();q=inherited_evidence();a.output.write_text(json.dumps(q,indent=2)+'\n');print(q['status'],len(q['files']),q['total_bytes'])
