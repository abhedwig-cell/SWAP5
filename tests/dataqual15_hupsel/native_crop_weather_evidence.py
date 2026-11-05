"""Actual shared weather adapter proof; the failing rotation is never promoted."""
import argparse,hashlib,io,json,tarfile
from pathlib import Path
import native_crop_adapter_runtime as run
ROOT=run.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=lambda b:hashlib.sha256(b).hexdigest()

def audit(get,windows):
    suffix='.exe'if windows else'';result=json.loads(get('WEATHER_RESULT.json'))
    assert result['status']=='ACTUAL_WEATHER_NATIVE_AND_EIGHT_SCHEMAS_BYTE_EXACT_PASS'
    assert result['production_admission']is False and result['whole_scientific_admission']is False and result['rotation_qualified']is False
    opt=result['optimization'];assert opt in ('O0','O2')and result['providers']==324
    builds={}
    for variant in ('incumbent','candidate'):
        read=lambda n:get(variant+'/'+n);b=json.loads(read('BUILD.json'));builds[variant]=b
        assert b['providers']==324 and b['candidate']==(variant=='candidate')and b['production_admission']is False
        clean=[x for x in b['flags']if not x.startswith(('-I','-J'))];assert clean==[*run.FLAGS,'-'+opt]
        for name,digest in b['objects_sha256'].items():assert sha(read(Path(name.replace('\\','/')).name))==digest
        for name,digest in b['executables_sha256'].items():assert sha(read(name+suffix))==digest
        for name,digest in b['drivers_sha256'].items():
            name=name.replace('\\','/')
            if '/tests/'in name:
                raw=(ROOT/('tests/'+name.split('/tests/',1)[1])).read_bytes().replace(b'\r\n',b'\n')
                assert digest in (sha(raw),sha(raw.replace(b'\n',b'\r\n')))
            else:assert name.endswith('/weather.f90')and sha(get('weather.f90'))==digest
        checked=0
        for name,digest in b['sources_sha256'].items():
            name=name.replace('\\','/')
            if '/'+variant+'/'in name:
                raw=read(name.split('/'+variant+'/',1)[1]);assert sha(raw)==digest
                assert raw.decode()==run.policy.candidate((ROOT/run.policy.SOURCE).read_text()),'private postimage drift'
            elif '/fixture/'in name:assert sha(get('fixture/'+name.split('/fixture/',1)[1]))==digest
            else:
                relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','tests')if '/'+area+'/'in name),None);assert relative,name
                raw=(ROOT/relative).read_bytes().replace(b'\r\n',b'\n');assert digest in ((sha(raw),sha(raw.replace(b'\n',b'\r\n')))if windows else(sha(raw),)),relative
                checked+=1
        assert checked>=320
        r=json.loads(read('WEATHER_EXECUTED.json'));assert r['status']=='ACTUAL_WEATHER_DEFAULT_CODEC_AND_NATIVE_REFUSALS_PASS'
        assert len(r['events'])==46 and all(e['returncode']==0 for e in r['events'])
        for event in r['events']:
            label=event['label'];stdout=read(event['stdout'])
            if label=='weather-independent-continuous':assert b'TCS6_REAL_WEATHER_WEEK_ROOT_MASS_OPAQUE_RETRY=PASS'in stdout
            elif 'native-write'in label:assert b'TCS6_NATIVE_PREFIX_PROCESS_EXIT=PASS'in stdout
            elif 'native-resume'in label:assert b'TCS6_NATIVE_FRESH_PROCESS_NO_DAY_REPLAY=PASS'in stdout
            elif label.startswith('decoder-'):assert b'TCS6_NATIVE_INVALID_NO_PARTIAL_PUBLICATION=PASS'in stdout
        assert set(r['controls'])=={'neutral','hydraulic'}
        for phase,rows in r['controls'].items():
            assert len(rows)==18 and all(e['returncode']==0 for e in rows)
            tag='morning'if phase=='neutral'else'dayend';paths=['w'+suffix+'.'+tag+'.'+kind for kind in ('full','opaque','resumed','active.resumed')]
            assert all(read(n)==read(paths[0])for n in paths)and read(paths[0])[:4]==b'S5WI'
            for row in rows:
                file='w'+suffix+'.'+tag+'.checkpoint'if row['case']=='different_config'else'weather-'+tag+'-'+row['case']+'.bad'
                assert sha(read(file))==row['input_sha256']
    assert builds['incumbent']['compiler']==builds['candidate']['compiler']
    names=[f'schema-{mode}-{j}.bin'for mode in range(4)for j in range(2)]+['w'+suffix+'.'+phase+'.'+kind for phase in ('morning','dayend')for kind in ('full','opaque','resumed','active.resumed')]
    assert set(result['byte_exact_files'])==set(names)
    for name in names:assert get('incumbent/'+name)==get('candidate/'+name)and sha(get('candidate/'+name))==result['byte_exact_files'][name]
    if windows:
        rotation=json.loads(get('ROTATION_BASELINE_REFUSAL.json'));assert not rotation['candidate_executed']and not rotation['rotation_admission']
        assert rotation['status']=='UNMODIFIED_INCUMBENT_BASELINE_FAILS_BEFORE_NATIVE_PUBLICATION'
        assert 'FAIL reaction rejects after actual crop preparation'in rotation['stdout']
    return dict(status='ACTUAL_DEFAULT_WEATHER_NATIVE_EIGHT_SCHEMAS_36_REFUSALS_EACH_VARIANT_PASS',optimization=opt,rotation_qualified=False,production_admission=False,whole_scientific_admission=False)

def controls(get,windows):
    suffix='.exe'if windows else'';labels=[]
    for label,name in (('binary','candidate/w'+suffix),('object','candidate/0.o'),('schema','candidate/schema-0-0.bin'),('native','candidate/w'+suffix+'.morning.full'),('missing_own_resume','candidate/WEATHER_EXECUTED.json'),('missing_decoder','candidate/WEATHER_EXECUTED.json'),('promoted','WEATHER_RESULT.json'),('rotation_promoted','WEATHER_RESULT.json')):
        raw=get(name)
        if label.startswith('missing_'):
            r=json.loads(raw)
            if label=='missing_own_resume':r['events']=[e for e in r['events']if 'native-resume'not in e['label']]
            else:r['controls']['neutral'].pop()
            bad=json.dumps(r).encode()
        elif label in ('promoted','rotation_promoted'):
            r=json.loads(raw);r['production_admission'if label=='promoted'else'rotation_qualified']=True;bad=json.dumps(r).encode()
        else:bad=raw+b'changed'
        try:audit(lambda n:bad if n==name else get(n),windows)
        except(AssertionError,ValueError,KeyError):labels.append(label)
        else:raise AssertionError('accepted weather evidence defect '+label)
    return labels

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);a=p.parse_args()
    for opt in ('O0','O2'):
        stem='NATIVE_CROP_WEATHER_WINDOWS_20261105_'+opt;archive=BASE/(stem+'.tar.xz');manifest=BASE/(stem+'.json')
        if a.seal:
            root=a.seal/('qualified-'+opt);files={p.relative_to(root).as_posix():p.read_bytes()for p in root.rglob('*')if p.is_file()}
            report=dict(audit=audit(lambda n:files[n],True),data_refusals=controls(lambda n:files[n],True))
            with tarfile.open(archive,'w:xz')as t:
                for name,raw in sorted(files.items()):
                    info=tarfile.TarInfo(name);info.size=len(raw);t.addfile(info,io.BytesIO(raw))
            prepared=json.loads(files['PREPARED.json'])
            gates=set(name.replace('\\','/')for name in prepared['inputs_sha256'])
            gates.update(('tests/dataqual15_hupsel/native_crop_weather_runtime.py','tests/dataqual15_hupsel/native_crop_weather_evidence.py','tests/dataqual15_hupsel/native_crop_adapter_fixture.py','tests/mc-irr01/tcs6_native_controls.py','tests/nut-material/material_fixture.inc','tests/nut-reactive/reactive_oracle.inc','tests/nut-crop/prepare_oracle.py','tests/nut-senescence/run_senescence.py','tests/physics/test_ppa_wu05d2_mixed_application.f90','integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64','tests/qualification/ppa-wu05-migmac10-canonical-20261006/b111-andelst_meteo.999.gz'))
            manifest.write_text(json.dumps(dict(archive_sha256=sha(archive.read_bytes()),report=report,gate_source_sha256={name:sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))for name in sorted(gates)},files_sha256={n:sha(b)for n,b in files.items()}),indent=2)+'\n')
        r=json.loads(manifest.read_text());assert sha(archive.read_bytes())==r['archive_sha256']
        assert all(sha((ROOT/name).read_bytes().replace(b'\r\n',b'\n'))==digest for name,digest in r['gate_source_sha256'].items())
        with tarfile.open(archive)as t:
            assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
        assert {n:sha(b)for n,b in files.items()}==r['files_sha256']
        assert dict(audit=audit(lambda n:files[n],True),data_refusals=controls(lambda n:files[n],True))==r['report']
    print('SEALED_WINDOWS_ACTUAL_DEFAULT_WEATHER_NATIVE_SCHEMA_AND_REFUSAL_PROOF_PASS')

if __name__=='__main__':main()
