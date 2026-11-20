"""Preserve original ZIP bytes in Git-sized parts; never recompress an artifact."""
import hashlib
from pathlib import Path

LIMIT=90*1024*1024


def store_original(original,proof,name):
    original,proof=Path(original),Path(proof)
    if Path(name).name!=name:raise ValueError('Foreign original archive name')
    size=original.stat().st_size;parts=[];whole=hashlib.sha256()
    with original.open('rb') as source:
        remaining=size;index=0
        while remaining:
            index+=1;part_name=name if size<=LIMIT else name+f'.part{index:03d}'
            count=min(LIMIT,remaining);actual=0;digest=hashlib.sha256()
            with (proof/part_name).open('xb') as target:
                while actual<count:
                    raw=source.read(min(1024*1024,count-actual))
                    if not raw:raise ValueError('Truncated original artifact')
                    target.write(raw);whole.update(raw);digest.update(raw);actual+=len(raw)
            parts.append(dict(file=part_name,bytes=actual,sha256=digest.hexdigest()));remaining-=actual
        if source.read(1):raise ValueError('Original artifact changed during storage')
    if not size:raise ValueError('Empty original artifact')
    return dict(archive=name,bytes=size,sha256=whole.hexdigest(),
                storage='single-original-zip' if size<=LIMIT else 'exact-original-zip-byte-parts-v1',parts=parts)


def materialize(proof,record,scratch):
    proof,scratch=Path(proof),Path(scratch);name=record['archive']
    if Path(name).name!=name:raise ValueError('Foreign original archive name')
    parts=record.get('parts')
    if not parts:return proof/name
    if len(parts)==1 and parts[0]['file']==name:return proof/name
    scratch.mkdir(parents=True,exist_ok=True);target=scratch/name
    digest=hashlib.sha256();size=0
    with target.open('xb') as out:
        for index,item in enumerate(parts,1):
            if item['file']!=name+f'.part{index:03d}':raise ValueError('Foreign/reordered original artifact part')
            part_digest=hashlib.sha256();part_size=0
            with (proof/item['file']).open('rb') as source:
                while raw:=source.read(1024*1024):
                    out.write(raw);digest.update(raw);part_digest.update(raw);part_size+=len(raw)
            if part_size!=item['bytes'] or part_digest.hexdigest()!=item['sha256']:
                raise ValueError('Original artifact part differs')
            size+=part_size
    if size!=record['bytes'] or digest.hexdigest()!=record['sha256']:
        raise ValueError('Reassembled original artifact differs')
    return target
