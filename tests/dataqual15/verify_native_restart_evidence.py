"""Read the sealed native-platform dossier without executing archived binaries."""
import hashlib,json,tarfile,tempfile
from pathlib import Path,PurePosixPath,PureWindowsPath
from verify_native_disk_run import verify

ROOT=Path(__file__).resolve().parents[2]

def main():
    record=json.loads((ROOT/'integration/dataqual15/STATUS.json').read_text())['native_disk_restart_20261102']['evidence']
    archive=ROOT/record['path'];assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    with tarfile.open(archive)as tar:
        members=tar.getmembers();assert len({m.name for m in members})==len(members)
        assert all(m.isfile()and not PurePosixPath(m.name).is_absolute()and not PureWindowsPath(m.name).drive
                   and '..'not in PurePosixPath(m.name).parts and '\\'not in m.name for m in members)
        files={m.name:tar.extractfile(m).read()for m in members}
    manifest=json.loads(files.pop('MANIFEST.json'))
    assert manifest=={n:hashlib.sha256(b).hexdigest()for n,b in files.items()}
    summary=json.loads(files['SUMMARY.json'])
    for opt in ['O0','O2']:
        build=json.loads(files['build/'+opt+'/BUILD.json'])
        assert hashlib.sha256(files['build/'+opt+'/'+build['executable']]).hexdigest()==build['executable_sha256']
        for name,digest in build['source_sha256'].items():
            assert hashlib.sha256(files[summary['source_members'][name]]).hexdigest()==digest,name
        for name,digest in build['object_sha256'].items():
            assert hashlib.sha256(files[summary['artifact_members'][name]]).hexdigest()==digest,name
        assert hashlib.sha256(files['ttutil/'+opt+'.a']).hexdigest()==build['original_input_archive_sha256']
        for name,digest in build['original_inputs_sha256'].items():
            assert hashlib.sha256(files['inputs/'+name]).hexdigest()==digest
        controls=json.loads(files['runs/invalid/'+opt+'/RESULT.json'])
        assert controls['source_sha256']==build['source_sha256']
        assert controls['executable_sha256']==build['executable_sha256']
        assert len(controls['events'])==11 and all(e['returncode']!=0 for e in controls['events'])
        for event in controls['events']:
            prefix='runs/invalid/'+opt+'/'+event['case']+'/'
            assert b'bound grass prefix restart rejected'in files[prefix+'stdout']
            assert prefix+'checkpoint.bin'not in files and prefix+'budget.csv'not in files
    native=json.loads(files['publication/RESULT.json'])
    assert native['status']=='NATIVE_RESTART_PUBLICATION_PASS'
    assert all(e['status']=='PASS'and e['crc_vectors']==17 for e in native['events'])
    with tempfile.TemporaryDirectory(prefix='swap-native-proof-')as folder:
        root=Path(folder)
        # Only validated regular files are materialized; no tar extraction API.
        for name,data in files.items():
            if not name.startswith('runs/'):continue
            path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
        for opt in ['O0','O2']:
            result=verify(root/'runs/year'/opt,root/'runs/year-resume'/opt,
                          root/'runs/year/O2'if opt=='O0'else None,root/'runs/prefix'/opt)
            assert result['days']==367 and result['source_contiguous_prefix']
            verify(root/'runs/prefix'/opt,root/'runs/mowing-resume'/opt)
    print(json.dumps(dict(status='SEALED_NATIVE_RESTART_EVIDENCE_PASS',original_days=367,
                         optimization_modes=['O0','O2'],invalid_streams_per_build=11,
                         native_disk_restart=True,whole_scientific_equivalence=False),indent=2))
if __name__=='__main__':main()
