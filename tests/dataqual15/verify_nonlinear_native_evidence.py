"""Verify native nonlinear/thermal research without running archived binaries."""
import hashlib
import json
from pathlib import Path,PurePosixPath,PureWindowsPath
import struct
import subprocess
import tarfile
import zlib

from analyze_native_thermal_receipts import analyze

ROOT=Path(__file__).resolve().parents[2]


def verify():
    sha=lambda b:hashlib.sha256(b).hexdigest()
    record=json.loads((ROOT/'integration/dataqual15/NONLINEAR_NATIVE_EVIDENCE_20261103.json').read_text(encoding='utf-8'))
    assert record['status']=='WINDOWS_O0_O2_ACTUAL_NONLINEAR_PAIR_AND_FIRST_DAY_THERMAL_PASS'
    assert not record['production_contact_repair'] and not record['full_energy_balance_complete']
    archive=ROOT/record['archive'];assert sha(archive.read_bytes())==record['archive_sha256']
    with tarfile.open(archive) as t:
        members=t.getmembers();assert len({m.name for m in members})==len(members)
        assert all(m.isfile() and not PurePosixPath(m.name).is_absolute() and not PureWindowsPath(m.name).drive
                   and '..' not in PurePosixPath(m.name).parts and '\\' not in m.name for m in members)
        files={m.name:t.extractfile(m).read() for m in members}
    assert json.loads(files.pop('MANIFEST.json'))=={n:sha(b) for n,b in files.items()}
    for path,blob in {**record['source_git_blob'],**record['auxiliary_git_blob']}.items():
        successor=record.get('uncompiled_orchestrator_successor',{})
        current=blob
        if path==successor.get('path'):
            assert path=='tests/dataqual15/qualify_nonlinear_native_contact.py' and successor['before']==blob
            current=successor['after']
        assert subprocess.check_output(['git','rev-parse','HEAD:'+path],cwd=ROOT,text=True).strip()==current,path
        raw=files['sources/'+path].replace(b'\r\n',b'\n')
        assert hashlib.sha1(b'blob '+str(len(raw)).encode()+b'\0'+raw).hexdigest()==blob,path
        assert not subprocess.check_output(['git','diff','HEAD','--',path],cwd=ROOT),path
    for opt in ('O0','O2'):
        r=json.loads(files[opt+'/RESULT.json']);assert r['status']=='NONLINEAR_LOCAL_CONTACT_AND_ACTUAL_NATIVE_THERMAL_RECEIPTS_PASS'
        assert not r['full_energy_balance_complete'] and not r['full_original_andelst_complete']
        assert r['source_git_blob']==record['source_git_blob']
        assert sha(files[opt+'/build/native.exe'])==r['executable_sha256']==record['windows'][opt]['executable_sha256']
        for name,digest in r['rendered_overlay_sha256'].items():assert sha(files[opt+'/overlay/'+name])==digest
        u=json.loads(files[opt+'/utility/BUILD.json'])
        assert sha(files[opt+'/utility/libttutil.a'])==u['input_archive_sha256']
        for name,digest in {**u['authority_sha256'],**u['manifest_sha256']}.items():
            assert sha(files['sources/'+name.replace('\\','/')])==digest,name
        for kind in ('contact-0','contact-1','actual-prefix'):
            prefix=opt+'/'+kind+'/'
            binding=sha(files[prefix+'input.nml']+files[prefix+'input.swp']+files[prefix+'macro.nml']+r['executable_sha256'].encode())
            for name in ('origin.bin','diagnostic-rejected.bin') if kind!='actual-prefix' else ('restart.bin',):
                raw=files[prefix+name]
                assert raw[:8]==b'S5WM0001' and raw[8:72].decode()==binding
                assert zlib.crc32(raw[:-4])==struct.unpack('=I',raw[-4:])[0]
        assert files[opt+'/contact-0/origin.bin']==files[opt+'/contact-0/diagnostic-rejected.bin']==files[opt+'/contact-1/diagnostic-rejected.bin']
        lines=files[opt+'/contact-1/nonlinear-contact.csv'].decode().splitlines()
        trials=[row.split(',') for row in lines if row.startswith('TRIAL,')]
        assert trials==record['windows'][opt]['contact_trials'] and [row[2] for row in trials]==['T','T','T','F','F']
        assert max(abs(float(x)) for row in trials[:3] for x in row[-2:])<=1e-10
        assert all(0<float(row[6])<1 for row in trials[:3])
        donors=[row.split(',') for row in lines if row.startswith('DONOR,')]
        assert len(donors)==15
        for row in donors:
            net,before,after,residual,remaining=map(float,row[3:])
            assert abs(after-before+net-residual)<1e-30 and remaining<=1e-18
            assert abs(residual)<=128*2.220446049250313e-16*max(1,abs(before))
        assert 'NATIVE_STATE_UNCHANGED_NONLINEAR_PAIR_ONLY_FULL_STEP_OPEN' in lines
        observation=analyze(files[opt+'/actual-prefix/actual-thermal.csv'])
        assert observation==json.loads(files[opt+'/THERMAL_ANALYSIS.json'])==record['windows'][opt]['analysis']
        assert not observation['full_energy_balance_complete']
        for name in record['exact_O0_O2']:assert files[opt+'/'+name]==files['O0/'+name]
    assert files['O0/actual-prefix/restart.bin'][72:-4]==files['O2/actual-prefix/restart.bin'][72:-4]
    print('ACTUAL NONLINEAR PAIR, DONOR BUDGET, EXACT ROLLBACK AND ORIGINAL-INPUT THERMAL OBSERVATIONS VERIFIED; FULL STEP/ENERGY OPEN')


if __name__=='__main__':verify()
