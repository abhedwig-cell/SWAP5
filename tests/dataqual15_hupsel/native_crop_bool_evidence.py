"""Seal/recheck actual private codec evidence without admitting production."""
import argparse,hashlib,json,tarfile
from pathlib import Path
import native_crop_bool as policy
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel';STEM='NATIVE_CROP_BOOL_WINDOWS_20261105'
sha=lambda b:hashlib.sha256(b).hexdigest()

def audit(files):
    initial=json.loads(files['INITIAL_PROBE.json'])
    assert len(initial['events'])==4
    assert all(e['reached_post_read_boundary'] and not e['decoder_refused'] and not e['outputs'] for e in initial['events'])
    assert {e['value']for e in initial['events']}=={1,2,-1,256}
    for opt in ('O0','O2'):
        get=lambda name:files[opt+'/'+name]
        result=json.loads(get('RESULT.json'));assert result['production_admission'] is False
        assert result['opaque_derived_logicals_qualified'] is False and result['scalar_sites']==32
        build=json.loads(get('build/BUILD.json'));assert build['provider_count']==236 and build['complete_module_closure_rebuilt'] is True
        assert build['interventions']==[policy.SOURCE] and '-'+opt in build['flags']
        for name,digest in build['object_sha256'].items():assert sha(get('build/'+Path(name.replace('\\','/')).name))==digest
        assert sha(get('build/swap5_hupsel_germination.exe'))==build['executable_sha256']
        assert get('build/private_mod_wofost_crop_native_codec.f90').decode()==policy.candidate((ROOT/policy.SOURCE).read_text(encoding='utf-8'))
        for name in ('checkpoint.bin','budget.csv','crop.csv'):
            assert get('unmodified-control/'+name)==get('own-runtime/continuous2/'+name)
        assert get('own-runtime/restart2/checkpoint.bin')==get('own-runtime/continuous2/checkpoint.bin')
        writer=json.loads(get('own-runtime/RESULT.json'));assert writer['finite_writer_refusals']==6 and writer['each_failed_write_preserves_prior_target_bytes']
        defects=json.loads(get('logical-refusals/RESULT.json'))['events'];assert len(defects)==12
        assert all(e['returncode']!=0 and e['refused_before_publication']for e in defects)
    return dict(status='ACTUAL_PRIVATE_WINDOWS_O0_O2_BYTE_EXACT_AND_NATIVE_REFUSAL_EVIDENCE_PASS',production_admission=False,opaque_derived_logicals_qualified=False)

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);a=p.parse_args();archive=BASE/(STEM+'.tar.xz');manifest=BASE/(STEM+'.json')
    if a.seal:
        files={p.relative_to(a.seal).as_posix():p.read_bytes()for p in a.seal.rglob('*')if p.is_file()and (p.relative_to(a.seal).parts[0]in ('O0','O2')or p.name=='INITIAL_PROBE.json')}
        report=audit(files)
        with tarfile.open(archive,'w:xz')as t:
            import io
            for name,body in sorted(files.items()):
                info=tarfile.TarInfo(name);info.size=len(body);t.addfile(info,io.BytesIO(body))
        manifest.write_text(json.dumps(dict(report=report,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()}),indent=2)+'\n')
    record=json.loads(manifest.read_text());assert sha(archive.read_bytes())==record['archive_sha256']
    with tarfile.open(archive)as t:
        assert len(t.getnames())==len(set(t.getnames()))
        files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
    assert {n:sha(b)for n,b in files.items()}==record['files_sha256'];assert audit(files)==record['report']
    print(record['report']['status'])

if __name__=='__main__':main()
