"""Verify preserved failed bounded candidates without rebuilding or running models."""
import hashlib
import io
import json
from pathlib import Path
import zipfile

ROOT=Path(__file__).resolve().parents[2]


def digest(raw):return hashlib.sha256(raw).hexdigest()


def main():
    folder=ROOT/'research/hybrid-water01'
    r=json.loads((folder/'CONSISTENT_MACRO_REJECTED_20261112.json').read_text())
    archive=folder/'consistent-macro-rejected-evidence.zip'
    assert digest(archive.read_bytes())==r['archive_sha256']
    assert archive.stat().st_size==r['archive_bytes']
    with zipfile.ZipFile(archive) as z:
        hashes=json.loads(z.read('MEMBER_SHA256.json'))
        assert set(z.namelist())==set(hashes)|{'MEMBER_SHA256.json'}
        for name,sha in hashes.items():assert digest(z.read(name))==sha
        for case in r['attempts']:
            prefix=case['attempt']+'/O2/'
            run=json.loads(z.read(prefix+'fresh/RESULT.json'))
            build=json.loads(z.read(prefix+'build/BUILD.json'))
            assert build==run['build']
            assert run['status']==case['status']=='MODEL_CAP_REACHED'
            assert run['cap_seconds']==20 and 20<=run['elapsed_seconds']<21
            assert run['elapsed_seconds']==case['elapsed_seconds']
            assert run['requested_day']==case['requested_day']
            assert [x['day'] for x in run['rows']]==case['accepted_days']
            assert max(abs(x['independent_residual_cm']) for x in run['rows'])==case['maximum_daily_residual_cm']<1e-6
            assert sum(x['budget_step_retries'] for x in run['rows'])==case['mass_retries']
            assert build['identity']['consistent_macro_policy']['generator_sha256']==digest(z.read(case['attempt']+'/executed_generator.py'))
            for role,name in [('donor','day_donor.exe'),('kernel','day_kernel.exe')]:
                assert digest(z.read(prefix+'build/'+name))==build['executable_sha256'][role]
            for name,sha in build['identity']['donor_generated'].items():assert digest(z.read(prefix+'build/'+name))==sha
            for row in run['rows']:
                raw=z.read(prefix+f"fresh/accepted-column-1-day-{row['day']}.zip")
                with zipfile.ZipFile(io.BytesIO(raw)) as package:
                    manifest=json.loads(package.read('checkpoint.json'))
                    assert manifest['binding']==build['binding'] and manifest['receipt']==row
                    for name,sha in manifest['files'].items():assert digest(package.read(name))==sha
    print(json.dumps({'status':'FAILED_CANDIDATE_EVIDENCE_VERIFIED_NOT_QUALIFIED',
        'actual_model_seconds':r['model_seconds'],'new_models':0,'variants_rejected':2,
        'O0':'NOT_RUN','Linux_day438':'NOT_RUN','whole_runs':0}))


if __name__=='__main__':main()
