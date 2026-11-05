"""Remeasure retained actual cold POSIX artifacts, no production promotion."""
import hashlib,json,zipfile
from pathlib import Path
import native_crop_bool as policy
ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
sha=lambda b:hashlib.sha256(b).hexdigest()

def main():
    record=json.loads((BASE/'NATIVE_CROP_BOOL_POSIX_20261105.json').read_text())
    archive=BASE/'NATIVE_CROP_BOOL_POSIX_20261105.zip';assert sha(archive.read_bytes())==record['artifact_zip_sha256']
    with zipfile.ZipFile(archive)as z:
        assert len(z.namelist())==len(set(z.namelist()))
        for opt in ('O0','O2'):
            get=lambda name:z.read('bool-candidate-'+opt+'/'+name)
            r=json.loads(get('RESULT.json'));assert r['production_admission']is False and r['opaque_derived_logicals_qualified']is False
            b=json.loads(get('build/BUILD.json'));assert b['provider_count']==236 and b['interventions']==[policy.SOURCE]
            assert '-'+opt in b['flags'] and b['complete_module_closure_rebuilt']
            assert sha(get('build/swap5_hupsel_germination'))==b['executable_sha256']
            assert get('build/private_mod_wofost_crop_native_codec.f90').decode()==policy.candidate((ROOT/policy.SOURCE).read_text(encoding='utf-8'))
            for name,digest in b['object_sha256'].items():assert sha(get('build/'+Path(name).name))==digest
            checked=0
            for name,digest in b['source_sha256'].items():
                relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app')if '/'+area+'/'in name),None)
                if relative:
                    assert sha((ROOT/relative).read_bytes().replace(b'\r\n',b'\n'))==digest,relative;checked+=1
            assert checked==234
            for name in ('checkpoint.bin','budget.csv','crop.csv'):assert get('unmodified-control/'+name)==get('own-runtime/continuous2/'+name)
            assert get('own-runtime/restart2/checkpoint.bin')==get('own-runtime/continuous2/checkpoint.bin')
            w=json.loads(get('own-runtime/RESULT.json'));assert w['finite_writer_refusals']==6 and w['each_failed_write_preserves_prior_target_bytes']
            events=json.loads(get('logical-refusals/RESULT.json'))['events'];assert len(events)==12 and all(e['refused_before_publication']and e['returncode']!=0 for e in events)
    print('RETAINED_ACTUAL_COLD_POSIX_O0_O2_PRIVATE_SCALAR_CODEC_EVIDENCE_PASS')

if __name__=='__main__':main()
