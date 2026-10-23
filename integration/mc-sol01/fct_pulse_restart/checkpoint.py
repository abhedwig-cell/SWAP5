"""One-file research policy envelope and same-platform atomic publication."""
import hashlib,json,os,signal,struct,tempfile
from pathlib import Path
MAGIC=b'S5FCT001'
MAX_PAYLOAD=10485760
sha=lambda b:hashlib.sha256(b).hexdigest()
def encode(payload,policy,context):
    assert 0<len(payload)<=MAX_PAYLOAD
    meta=dict(schema=1,policy=policy,context=context,size=len(payload),sha256=sha(payload))
    header=json.dumps(meta,sort_keys=True,separators=(',',':')).encode()
    assert len(header)<=4096
    return MAGIC+struct.pack('<I',len(header))+header+payload
def decode(raw,policy,context):
    assert raw[:8]==MAGIC and len(raw)>=12
    count=struct.unpack('<I',raw[8:12])[0];assert 0<count<=4096 and 12+count<len(raw)
    meta=json.loads(raw[12:12+count]);payload=raw[12+count:]
    assert meta['schema']==1 and meta['policy']==policy and meta['context']==context
    assert 0<meta['size']<=MAX_PAYLOAD and len(payload)==meta['size'] and sha(payload)==meta['sha256']
    return payload
def publish(raw,path,crash=None):
    path=Path(path);fd,name=tempfile.mkstemp(prefix=path.name+'.pending-',dir=path.parent)
    try:
        with os.fdopen(fd,'wb') as f:f.write(raw);f.flush();os.fsync(f.fileno())
        if crash=='before':os.kill(os.getpid(),signal.SIGKILL)
        os.replace(name,path)
        directory=os.open(path.parent,os.O_RDONLY)
        try:os.fsync(directory)
        finally:os.close(directory)
        if crash=='after':os.kill(os.getpid(),signal.SIGKILL)
    finally:
        if os.path.exists(name):os.unlink(name)
if __name__=='__main__':
    import argparse
    p=argparse.ArgumentParser();p.add_argument('source',type=Path);p.add_argument('target',type=Path);p.add_argument('--crash',choices=['before','after']);a=p.parse_args()
    publish(a.source.read_bytes(),a.target,a.crash)
