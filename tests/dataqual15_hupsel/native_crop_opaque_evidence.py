"""Sealed actual opaque codec, component, mature owner and atomic writer proof."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
import native_crop_opaque as policy
import native_crop_opaque_writer as writer
ROOT=writer.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';STEM='NATIVE_CROP_OPAQUE_WINDOWS_20261105'
sha=lambda b:hashlib.sha256(b).hexdigest()

def audit(get,exe_suffix,windows):
    b=json.loads(get('build/BUILD.json'));assert b['provider_count']==236 and b['complete_module_closure_rebuilt']
    assert b['interventions']==[policy.SOURCE] and b['production_admission']is False
    assert sha(get('build/swap5_hupsel_germination'+exe_suffix))==b['executable_sha256']
    assert get('build/private_mod_wofost_crop_native_codec.f90').decode()==policy.candidate((ROOT/policy.SOURCE).read_text(encoding='utf-8'))
    for name,digest in b['object_sha256'].items():assert sha(get('build/'+Path(name.replace('\\','/')).name))==digest
    checked=0
    for name,digest in b['source_sha256'].items():
        name=name.replace('\\','/')
        relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app')if '/'+area+'/'in name),None)
        if relative:
            raw=(ROOT/relative).read_bytes().replace(b'\r\n',b'\n')
            assert digest in ((sha(raw),sha(raw.replace(b'\n',b'\r\n')))if windows else(sha(raw),)),relative
            checked+=1
    assert checked==234
    for name in ('checkpoint.bin','budget.csv','crop.csv'):
        assert get('unmodified-control/'+name)==get('own-runtime/continuous2/'+name)
    assert get('own-runtime/restart2/checkpoint.bin')==get('own-runtime/continuous2/checkpoint.bin')
    for name,count in (('app-refusals',11),('logical-refusals',12)):
        events=json.loads(get(name+'/RESULT.json'))['events']
        assert len(events)==count and all(e['returncode']!=0 for e in events)
    final=json.loads(get('OPAQUE_RESULT.json'));assert final['status']=='OPAQUE_COMPONENT_MATURE37_AND_PUBLIC_WRITER32_DTO_FAULT_CONTROLS_PASS'
    assert final['source_sites']==34 and final['production_admission']is False
    fixture=json.loads(get('opaque-fixture/RESULT.json'));assert len(fixture['events'])==11 and all(e['returncode']==0 for e in fixture['events'])
    raw=get('opaque-fixture/SOURCE.f90');assert sha(raw)==fixture['source_sha256']
    assert raw.replace(b'\r\n',b'\n')==(ROOT/'tests/dataqual15_hupsel/native_crop_opaque_fixture.f90').read_bytes().replace(b'\r\n',b'\n')
    for name,digest in fixture['executables_sha256'].items():assert sha(get('opaque-fixture/'+name.replace('\\','/')))==digest
    for name in ('owner0.bin','owner1.bin','view0.bin','view1.bin'):
        assert get('opaque-fixture/incumbent/'+name)==get('opaque-fixture/candidate/'+name)
    mature=json.loads(get('mature-owner-controls/S5HR4_RESULT.json'))
    assert len(mature['events'])==37 and all(e['status']=='PASS' and e['returncode']==1 for e in mature['events'])
    assert mature['legacy_schema_coercion']is False
    faults=json.loads(get('fault-writer/RESULT.json'));assert faults['status']=='ACTUAL_PUBLIC_WRITER_32_PRIVATE_DTO_FAULT_REFUSALS_PRESERVE_PRIOR_TARGET_PASS'
    f=json.loads(get('fault-writer/build/BUILD.json'))
    assert f['parent_build_sha256']==sha(get('build/BUILD.json'))
    for name,key,body in (('hupsel_rotation_restart.f90','app_sha256',writer.instrument_app((ROOT/writer.APP).read_text())),('main.f90','main_sha256',writer.instrument_main((ROOT/'app/solute_project/main.f90').read_text()))):
        raw=get('fault-writer/build/'+name);assert raw.decode()==body and sha(raw)==f[key]
    assert sha(get('fault-writer/build/writer-probe'+exe_suffix))==f['executable_sha256']
    rows=[s.split()for s in get('fault-writer/publication/writer2/logical_writer_probe.dat').decode().splitlines()]
    assert rows==[[str(i),str(j),'1']for i in range(1,9)for j in range(1,5)]
    for prefix in ('own-runtime/','fault-writer/publication/'):
        r=json.loads(get(prefix+'RESULT.json'));assert r['finite_writer_refusals']==6 and r['strict_restart_exact'] and r['each_failed_write_preserves_prior_target_bytes']
        assert get(prefix+'writer2/checkpoint.bin')==get(prefix+'continuous2/checkpoint.bin')
    return dict(status='ACTUAL_OPAQUE_BYTES_OWN_RESTART_COMPONENT24_MATURE37_PUBLIC_WRITER32_PASS',source_sites=34,production_admission=False,whole_scientific_admission=False)

def controls(get,exe_suffix,windows):
    refused=[]
    for label,name in (('binary','build/swap5_hupsel_germination'+exe_suffix),('object','build/0.o'),('ordinary_bytes','unmodified-control/checkpoint.bin'),('component_bytes','opaque-fixture/incumbent/owner1.bin'),('fault_source','fault-writer/build/main.f90'),('fault_log','fault-writer/publication/writer2/logical_writer_probe.dat'),('owner_result','mature-owner-controls/S5HR4_RESULT.json'),('promoted','build/BUILD.json')):
        raw=get(name)
        if label in ('owner_result','promoted'):
            r=json.loads(raw)
            if label=='owner_result':r['events'][0]['status']='FAIL'
            else:r['production_admission']=True
            bad=json.dumps(r).encode()
        else:bad=raw+b'changed'
        try:audit(lambda n:bad if n==name else get(n),exe_suffix,windows)
        except(AssertionError,ValueError,KeyError):refused.append(label)
        else:raise AssertionError('accepted opaque evidence defect '+label)
    return refused

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);a=p.parse_args();archive=BASE/(STEM+'.tar.xz');manifest=BASE/(STEM+'.json')
    if a.seal:
        files={p.relative_to(a.seal).as_posix():p.read_bytes()for p in a.seal.rglob('*')if p.is_file()and p.relative_to(a.seal).parts[0]in ('O0','O2')}
        report={opt:dict(audit=audit(lambda n:files[opt+'/'+n],'.exe',True),data_refusals=controls(lambda n:files[opt+'/'+n],'.exe',True))for opt in ('O0','O2')}
        with tarfile.open(archive,'w:xz')as t:
            for name,body in sorted(files.items()):
                info=tarfile.TarInfo(name);info.size=len(body);t.addfile(info,io.BytesIO(body))
        manifest.write_text(json.dumps(dict(archive_sha256=sha(archive.read_bytes()),report=report,files_sha256={n:sha(b)for n,b in files.items()}),indent=2)+'\n')
    r=json.loads(manifest.read_text());assert sha(archive.read_bytes())==r['archive_sha256']
    with tarfile.open(archive)as t:
        assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
    assert {n:sha(b)for n,b in files.items()}==r['files_sha256']
    assert {opt:dict(audit=audit(lambda n:files[opt+'/'+n],'.exe',True),data_refusals=controls(lambda n:files[opt+'/'+n],'.exe',True))for opt in ('O0','O2')}==r['report']
    print('SEALED_ACTUAL_WINDOWS_OPAQUE_O0_O2_ALL_FOCUSED_GATES_PASS')

if __name__=='__main__':main()
