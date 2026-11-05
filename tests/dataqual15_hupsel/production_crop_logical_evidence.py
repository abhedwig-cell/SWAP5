"""Actual production native evidence; no source-only or scientific promotion."""
import argparse,hashlib,io,json,tarfile,zipfile
from pathlib import Path
import production_crop_logical_admission as admission
ROOT=admission.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=admission.sha

def source(get,path):
    name=path.replace('\\','/')
    for marker in ('/hupsel/build/','/weather/fixture/','/weather/old-control/','/weather/current/'):
        if marker in name:return get(marker[1:]+name.split(marker,1)[1])
    if name.endswith('/weather/weather.f90'):return get('weather/weather.f90')
    relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app','tests')if '/'+area+'/'in name),None)
    assert relative,name;return (ROOT/relative).read_bytes()

def build(get,prefix,field,objects,exe,suffix):
    b=json.loads(get(prefix+'BUILD.json'))
    for name,digest in b[field].items():
        raw=source(get,name);assert digest in (sha(raw),sha(raw.replace(b'\r\n',b'\n')),sha(raw.replace(b'\r\n',b'\n').replace(b'\n',b'\r\n'))),name
    for name,digest in b[objects].items():assert sha(get(prefix+Path(name.replace('\\','/')).name))==digest
    if exe:assert sha(get(prefix+exe+suffix))==b['executable_sha256']
    return b

def audit(get,scope,windows):
    suffix='.exe'if windows else'';r=json.loads(get('RESULT.json'))
    assert r['status']=='ACTUAL_CURRENT_PRODUCTION_CROP_LOGICAL_HUPSEL_WEATHER_PASS'and r['postimage_sha256']==scope['postimage_sha256']and r['whole_scientific_admission']is False
    opt=r['optimization'];assert opt in ('O0','O2')
    b=build(get,'hupsel/build/','source_sha256','object_sha256','swap5_hupsel_germination',suffix)
    assert b['provider_count']==236 and b['build_mode']=='clean-source'and '-'+opt in b['flags']
    codec=next(d for p,d in b['source_sha256'].items()if p.replace('\\','/').endswith('/'+admission.SOURCE))
    assert codec in (scope['postimage_sha256'],sha(admission.postimage().replace('\n','\r\n').encode()))
    native=json.loads(get('hupsel/own-runtime/RESULT.json'));assert native['strict_restart_exact']and native['finite_writer_refusals']==6 and native['each_failed_write_preserves_prior_target_bytes']
    assert get('hupsel/own-runtime/restart2/checkpoint.bin')==get('hupsel/own-runtime/continuous2/checkpoint.bin')
    for name,count in (('app-refusals',11),('logical-refusals',12)):
        events=json.loads(get('hupsel/'+name+'/RESULT.json'))['events'];assert len(events)==count and all(e['returncode']!=0 for e in events)
    owner=json.loads(get('hupsel/owner-controls/S5HR4_RESULT.json'));assert len(owner['events'])==37 and all(e['status']=='PASS'and e['returncode']==1 for e in owner['events'])and owner['legacy_schema_coercion']is False
    writer=json.loads(get('hupsel/fault-writer/RESULT.json'));assert writer['status']=='ACTUAL_PUBLIC_WRITER_32_PRIVATE_DTO_FAULT_REFUSALS_PRESERVE_PRIOR_TARGET_PASS'
    rows=[line.split()for line in get('hupsel/fault-writer/publication/writer2/logical_writer_probe.dat').decode().splitlines()];assert rows==[[str(i),str(j),'1']for i in range(1,9)for j in range(1,5)]
    assert get('hupsel/fault-writer/publication/writer2/checkpoint.bin')==get('hupsel/own-runtime/continuous2/checkpoint.bin')
    from native_crop_opaque_writer import instrument_app,instrument_main,APP
    f=json.loads(get('hupsel/fault-writer/build/BUILD.json'))
    assert f['parent_build_sha256']==sha(get('hupsel/build/BUILD.json'))
    for name,key,body in (('hupsel_rotation_restart.f90','app_sha256',instrument_app((ROOT/APP).read_text())),('main.f90','main_sha256',instrument_main((ROOT/'app/solute_project/main.f90').read_text()))):
        raw=get('hupsel/fault-writer/build/'+name);assert raw.decode()==body and sha(raw)==f[key]
    assert sha(get('hupsel/fault-writer/build/writer-probe'+suffix))==f['executable_sha256']
    outputs=[];models={}
    for role in ('old-control','current'):
        prefix='weather/'+role+'/';models[role]=build(get,prefix,'sources_sha256','objects_sha256',None,suffix)
        model=models[role];assert model['providers']==324 and '-'+opt in model['flags']and model['production_admission']is False
        for name,digest in model['executables_sha256'].items():assert sha(get(prefix+name+suffix))==digest
        if role=='old-control':assert get(prefix+'private_codec.f90').decode()==admission.old_source()
        else:assert any(name.replace('\\','/').endswith('/'+admission.SOURCE)for name in model['sources_sha256'])
        data=json.loads(get(prefix+'WEATHER_EXECUTED.json'));assert len(data['events'])==46 and all(e['returncode']==0 for e in data['events'])
        for phase,rows in data['controls'].items():assert phase in ('neutral','hydraulic')and len(rows)==18 and all(e['returncode']==0 for e in rows)
        assert set(data['controls'])=={'neutral','hydraulic'}
        names=[f'schema-{mode}-{j}.bin'for mode in range(4)for j in range(2)]+['w'+suffix+'.'+phase+'.'+kind for phase in ('morning','dayend')for kind in ('full','opaque','resumed','active.resumed')]
        for phase in ('morning','dayend'):
            raw=get(prefix+'w'+suffix+'.'+phase+'.full');assert raw[:4]==b'S5WI'
            assert all(get(prefix+'w'+suffix+'.'+phase+'.'+kind)==raw for kind in ('opaque','resumed','active.resumed'))
        outputs.append({n:get(prefix+n)for n in names})
    assert outputs[0]==outputs[1]and models['old-control']['compiler']==models['current']['compiler']
    result=json.loads(get('weather/RESULT.json'));assert result['status']=='ACTUAL_CURRENT_PRODUCTION_WEATHER_AND_EXACT_OLD_ENCODER_BYTE_CONTROLS_PASS'and result['rotation_qualified']is False
    assert {n:sha(raw)for n,raw in outputs[1].items()}==result['byte_exact_files']
    return dict(status='ACTUAL_PRODUCTION_HUPSEL_WEATHER_NATIVE_BYTE_AND_REFUSAL_GATES_PASS',optimization=opt,whole_scientific_admission=False,rotation_qualified=False)

def controls(get,scope,windows):
    suffix='.exe'if windows else'';refused=[]
    for label,name in (('binary','hupsel/build/swap5_hupsel_germination'+suffix),('own_restart','hupsel/own-runtime/restart2/checkpoint.bin'),('writer_faults','hupsel/fault-writer/publication/writer2/logical_writer_probe.dat'),('owner','hupsel/owner-controls/S5HR4_RESULT.json'),('old_encoder','weather/old-control/private_codec.f90'),('schema','weather/current/schema-0-0.bin'),('weather_native','weather/current/w'+suffix+'.morning.full'),('promoted','RESULT.json')):
        raw=get(name)
        if label=='owner':r=json.loads(raw);r['events'].pop();bad=json.dumps(r).encode()
        elif label=='promoted':r=json.loads(raw);r['whole_scientific_admission']=True;bad=json.dumps(r).encode()
        else:bad=raw+b'changed'
        try:audit(lambda n:bad if n==name else get(n),scope,windows)
        except(AssertionError,ValueError,KeyError):refused.append(label)
        else:raise AssertionError('accepted production evidence defect '+label)
    return refused

def verify(scope):
    reports={}
    for opt in ('O0','O2'):
        stem='PRODUCTION_CROP_LOGICAL_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());archive=BASE/(stem+'.tar.xz')
        assert sha(archive.read_bytes())==r['archive_sha256']
        with tarfile.open(archive)as t:
            assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
        assert {n:sha(b)for n,b in files.items()}==r['files_sha256']
        report=dict(audit=audit(lambda n:files[n],scope,True),data_refusals=controls(lambda n:files[n],scope,True));assert report==r['report'];reports[opt]=report
    if scope['phase']=='QUALIFIED_CURRENT_WINDOWS_AND_POSIX':
        from production_crop_logical_posix import verify as posix
        reports['current_posix']=posix(scope)
    else:assert scope['phase']=='QUALIFIED_WINDOWS_AND_EXECUTED_EXACT_POSTIMAGE_POSIX'
    return reports

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);a=p.parse_args();scope=json.loads((ROOT/admission.SCOPE).read_text());admission.guard(scope)
    if a.seal:
        for opt in ('O0','O2'):
            root=a.seal/opt;files={p.relative_to(root).as_posix():p.read_bytes()for p in root.rglob('*')if p.is_file()}
            report=dict(audit=audit(lambda n:files[n],scope,True),data_refusals=controls(lambda n:files[n],scope,True))
            stem='PRODUCTION_CROP_LOGICAL_WINDOWS_20261105_'+opt;archive=BASE/(stem+'.tar.xz')
            with tarfile.open(archive,'w:xz')as t:
                for name,raw in sorted(files.items()):
                    info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
            (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(archive.read_bytes()),report=report,files_sha256={n:sha(b)for n,b in files.items()}),indent=2)+'\n')
    print(verify(scope))

if __name__=='__main__':main()
