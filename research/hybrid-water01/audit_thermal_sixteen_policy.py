"""Read-only re-audit of the actual Windows/Linux sixteen-policy evidence."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import tarfile
import tempfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--windows',type=Path,required=True)
p.add_argument('--linux',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();sha=lambda f:hashlib.sha256(Path(f).read_bytes()).hexdigest()
spec=json.loads((ROOT/'integration/f-ci/THERMAL_SIXTEEN_POLICY_ADMISSION.json').read_text())
module=ROOT/'research/hybrid-water01/audit_grass_current.py'
loader=importlib.util.spec_from_file_location('original_balance_assertions',module)
audit=importlib.util.module_from_spec(loader);loader.loader.exec_module(audit)
keys=['source_sha256','object_sha256','module_sha256','reused_artifacts_sha256',
      'original_input_sources_sha256','original_input_objects_sha256']


def unpack(archive,platform):
    assert sha(archive)==spec['archives'][platform]['sha256']
    out=Path(tempfile.mkdtemp(prefix='s5-heat16-'+platform+'-audit-'))
    with tarfile.open(archive) as t:t.extractall(out,filter='data')
    pins=json.loads((out/'MEMBER_SHA256.json').read_text())
    for name,h in pins.items():assert sha(out/name)==h,name
    return out,len(pins)


def identities(root,folders):
    index=json.loads((root/'FILE_INDEX.json').read_text());checks=0
    def bound(name):
        value=(root/index[name]).resolve()
        assert value.is_relative_to(root.resolve())
        return value
    for folder in folders:
        for file in folder.rglob('*.json'):
            try:d=json.loads(file.read_text())
            except (ValueError,UnicodeDecodeError):continue
            if not isinstance(d,dict):continue
            for key in keys:
                for name,h in d.get(key,{}).items():
                    assert sha(bound(name))==h,name;checks+=1
            if file.name=='BUILD.json':
                assert d['status']=='ORIGINAL_INTERVAL_COMPLETED'
                assert sha(file.parent/d['executable'])==d['executable_sha256']
                lib=next(e['command'] for e in d['events'] if e['label']=='link')[-3]
                assert sha(bound(lib))==d['original_input_archive_sha256'];checks+=1
                for name,h in d['original_inputs_sha256'].items():
                    assert sha(file.parent/'original-interval'/name)==h
                assert sha(file.parent/'original-interval/application.binding')==d['application_binding_sha256']
    return checks


def disk(folder):
    r=json.loads((folder/'RESULT.json').read_text())
    assert r['status']=='NATIVE_ORIGINAL_DISK_RESTART_PASS'
    assert len(r['invalid_restart_controls'])==10
    for name in r['invalid_restart_controls']:
        case=folder/name
        assert b'bound grass prefix restart rejected' in (case/'stdout').read_bytes()
        assert not(case/'budget.csv').exists() and not(case/'checkpoint.bin').exists()
    assert len(r['profile_controls'])==8
    assert {x['alternate'] for x in r['profile_controls'] if 'alternate' in x}=={
        'thermal-control-1e-5C','thermal-subcycle4-1e-5C'}
    assert all(x['returncode']!=0 for x in r['profile_controls'])
    for item in r['profile_controls']:
        name='cross-policy-checkpoint-'+item['alternate'] if 'alternate' in item else 'profile-'+item['case']
        case=folder/name
        assert not(case/'budget.csv').exists() and not(case/'checkpoint.bin').exists()
    audit.restart(folder/'continuous',folder/'resume',2,3)
    result=audit.audit(folder/'continuous',1,3)
    assert abs(result['cumulative_water_residual_cm'])<=1e-10
    return result


w,wcount=unpack(a.windows,'windows');l,lcount=unpack(a.linux,'linux')
assert module.read_text()==(w/'producer/research/hybrid-water01/audit_grass_current.py').read_text()
widentity=identities(w,[w/x for x in ['heat-body','runtime','sixteen-O0','sixteen-O2','one','four',
                                      'disk-O0','disk-O2','default-fourdays']])
lidentity=identities(l,[x for x in l.iterdir() if x.is_dir() and x.name.startswith('sixteen-')])
results={}
for platform,root,body,runtime,folders,pub in [
    ('windows',w,'heat-body','runtime',['disk-O0','disk-O2'],'public'),
    ('linux',l,'sixteen-body','sixteen-runtime',['sixteen-opt-O0-disk','sixteen-opt-disk'],'sixteen-public')]:
    b=json.loads((root/body/'RESULT.json').read_text())
    assert b['status']=='HEAT_POLICY_BODY_O0_O2_DEFAULT_FACES_AND_REFUSAL_PASS' and b['driver_counts']==[4,16]
    assert json.loads((root/runtime/'RESULT.json').read_text())['status']=='SPRINT03_CURRENT_RUNTIME_AND_THERMAL_TEMPORAL_CONTRACT_PASS'
    for folder in [root/body,root/runtime]:
        events=json.loads((folder/('events.json' if folder.name in ['heat-body','sixteen-body'] else 'EVENTS.json')).read_text())
        assert all(e['returncode']==0 for e in events)
    results[platform]={name:disk(root/name) for name in folders}
    public=json.loads((root/pub/'RESULT.json').read_text())
    assert public['model']=='NATIVE_GRASSGROWTH_WATER' and public['last_completed_day']==3
    for name in audit.OUTPUTS:
        assert (root/pub/name).read_bytes()==(root/folders[1]/'continuous'/name).read_bytes(),name
abba=json.loads((w/'abba/RESULT.json').read_text())
baseline=json.loads((w/'four/BUILD.json').read_text());candidate=json.loads((w/'sixteen-O2/BUILD.json').read_text())
assert baseline['compiler']==candidate['compiler'] and baseline['profile']==candidate['profile']=='production'
assert baseline['original_input_archive_sha256']==candidate['original_input_archive_sha256']
assert baseline['original_inputs_sha256']==candidate['original_inputs_sha256']
assert [x for x in baseline['flags'] if not x.startswith(('-I','-J'))]==[x for x in candidate['flags'] if not x.startswith(('-I','-J'))]
assert abba['status']=='SHORT_ABBA_AND_OWN_RESTART_PASS' and all(e['returncode']==0 for e in abba['events'])
assert abba['numerical_profiles']=={'baseline':'thermal-subcycle4-1e-5C','candidate':'thermal-subcycle16-1e-5C'}
for arm in ['A1','B1']:
    audit.audit(w/'abba'/arm,1,4)
for first,second in [('A1','A2'),('B1','B2')]:
    for name in audit.OUTPUTS:assert (w/'abba'/first/name).read_bytes()==(w/'abba'/second/name).read_bytes()
audit.restart(w/'abba/B1',w/'abba/resumed',3,4)
for name in audit.LEDGERS:
    assert audit.read_csv(w/'abba/B1'/name)==audit.read_csv(w/'abba/cut'/name)+audit.read_csv(w/'abba/resumed'/name)
assert json.loads((w/'physical-preservation.json').read_text())['status']=='WINDOWS_ONE_FOUR_RAW_GOLD_PRESERVATION_PASS'
assert json.loads((l/'sixteen-preservation.json').read_text())['status']=='DEFAULT_EXACT_INCUMBENT_AND_FOUR_EXACT_PRIVATE_PASS'
r=dict(status='INDEPENDENT_WINDOWS_LINUX_SOURCE_BUILD_POLICY_RESTART_BALANCE_AND_TIMING_AUDIT_PASS',
       retained_members=dict(windows=wcount,linux=lcount),identity_checks=dict(windows=widentity,linux=lidentity),
       disk_proofs=results,median_native_seconds=abba['median_native_seconds'],
       median_reduction_percent=abba['median_reduction_percent'],accepted_steps=abba['accepted_steps'],
       numerical_profiles=abba['numerical_profiles'],
       scope='Scoped O0/O2 implementations and native cuts; short Windows ambient timing only. Whole science, full16 trajectory, energy completeness and runtime parity are not granted.')
a.output.write_text(json.dumps(r,indent=2)+'\n',newline='\n');print(json.dumps({k:v for k,v in r.items() if k!='disk_proofs'}))
