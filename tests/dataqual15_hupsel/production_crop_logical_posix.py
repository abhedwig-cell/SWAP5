"""Replay complete original current-production POSIX native artifact bytes."""
import io,json,zipfile
import production_crop_logical_evidence as evidence

def verify(scope):
    record=json.loads((evidence.BASE/'PRODUCTION_CROP_LOGICAL_POSIX_20261105.json').read_text())
    parts=record['archive_parts']
    assert parts and list(parts)==['PRODUCTION_CROP_LOGICAL_POSIX_20261105.zip.part%02d'%i for i in range(len(parts))]
    chunks=[]
    for name,digest in parts.items():
        raw=(evidence.BASE/name).read_bytes()
        assert evidence.sha(raw)==digest
        chunks.append(raw)
    raw=b''.join(chunks)
    assert evidence.sha(raw)==record['artifact_zip_sha256']
    assert record['production_source_sha256']==scope['postimage_sha256']
    with zipfile.ZipFile(io.BytesIO(raw)) as z:
        assert len(z.namelist())==len(set(z.namelist()))
        reports={}
        for opt in ('O0','O2'):
            get=lambda name:z.read('current-crop-logical-'+opt+'/'+name)
            reports[opt]=dict(audit=evidence.audit(get,scope,False),data_refusals=evidence.controls(get,scope,False))
    assert reports==record['report']
    return reports

if __name__=='__main__':
    scope=json.loads((evidence.ROOT/evidence.admission.SCOPE).read_text())
    print(verify(scope))
