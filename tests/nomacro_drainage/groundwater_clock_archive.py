"""Read original groundwater clock artifact bytes with explicit safe projection."""
import hashlib
import os
from pathlib import Path,PurePosixPath
import stat
import zipfile
from ordinary_pond_evidence import digest,require


def unpack(archive,record,root):
    archive,root=Path(archive),Path(root)
    require(archive.stat().st_size==record['size_in_bytes'] and 'sha256:'+digest(archive)==record['digest'],'Original GitHub artifact differs')
    if os.name=='nt':root=Path('\\\\?\\'+str(root.resolve()))
    root.mkdir(exist_ok=True);members={}
    with zipfile.ZipFile(archive) as z:
        require(z.testzip() is None,'Actual original artifact CRC failure')
        for item in z.infolist():
            path=PurePosixPath(item.filename)
            require(path.parts and not path.is_absolute() and '..' not in path.parts and '\\' not in item.filename and ':' not in item.filename and
                    not stat.S_ISLNK(item.external_attr>>16) and item.filename not in members,'Unsafe or repeated actual member')
            raw=z.read(item);sha=hashlib.sha256(raw).hexdigest();members[item.filename]=dict(bytes=len(raw),sha256=sha)
            target=root.joinpath(*path.parts);target.parent.mkdir(parents=True,exist_ok=True)
            if item.is_dir():target.mkdir(exist_ok=True)
            elif target.exists():require(digest(target)==sha,'Existing artifact extraction differs')
            else:
                with target.open('xb') as f:f.write(raw)
    return root,members
