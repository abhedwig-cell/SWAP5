"""Independent retained cold POSIX opaque/native/publication remeasurement."""
import json,zipfile
import native_crop_opaque_evidence as evidence
BASE=evidence.BASE

def main():
    r=json.loads((BASE/'NATIVE_CROP_OPAQUE_POSIX_20261105.json').read_text())
    archive=BASE/'NATIVE_CROP_OPAQUE_POSIX_20261105.zip'
    assert evidence.sha(archive.read_bytes())==r['artifact_zip_sha256']
    with zipfile.ZipFile(archive)as z:
        assert len(z.namelist())==len(set(z.namelist()))
        report={}
        for opt in ('O0','O2'):
            get=lambda n:z.read('opaque-candidate-'+opt+'/'+n)
            report[opt]=dict(audit=evidence.audit(get,'',False),data_refusals=evidence.controls(get,'',False))
    assert report==r['report']
    print('RETAINED_ACTUAL_COLD_POSIX_OPAQUE_O0_O2_ALL_FOCUSED_GATES_PASS')

if __name__=='__main__':main()
