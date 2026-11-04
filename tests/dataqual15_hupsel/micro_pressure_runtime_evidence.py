"""Seal and remeasure actual copied-runtime research, without production admission."""
import argparse, collections, copy, csv, hashlib, io, json, math, subprocess, sys, tarfile
from pathlib import Path
from full_profile_evidence import unpack, DAYS
from micro_pressure_probe import OLD, NEW, PROCESS
from native_refinement_evidence import measure
from inspect_profiles import profile
from audit_corrected_rotation import ledger

ROOT=Path(__file__).resolve().parents[2];BASE=ROOT/'integration/dataqual15_hupsel'
STEM='MICRO_PRESSURE_RUNTIME_EVIDENCE_20261104'
sha=lambda raw:hashlib.sha256(raw).hexdigest()
norm=lambda p:sha(p.read_bytes().replace(b'\r\n',b'\n'))
records=lambda b:list(csv.DictReader(io.StringIO(b.decode())))

def relative(name):
    value=name.replace('\\','/')
    if '/SWAP5-AUTONOMOUS/' in value:
        return value.split('/SWAP5-AUTONOMOUS/',1)[1]
    assert value.endswith('/legacy_swp_original.f90'),name
    return 'external-source/legacy_swp_original.f90'

def source_binding(files,opt):
    prefix='build-'+opt+'/'
    b=json.loads(files[prefix+'BUILD.json']);old=b['baseline']
    assert b['complete_module_closure_rebuilt'] and b['only_intervention']==PROCESS
    assert len(b['source_sha256'])==len(old['source_sha256'])==len(b['compiled_objects_sha256'])==236
    before=files['incumbent-source/'+PROCESS].decode().replace('\r\n','\n')
    after=files[prefix+Path(PROCESS).name].decode()
    assert before.count(OLD)==1 and after==before.replace(OLD,NEW)
    assert sha(files['incumbent-source/'+PROCESS])==b['source_original_sha256']
    assert sha(files[prefix+Path(PROCESS).name])==b['source_copy_sha256']
    assert sha(files[prefix+'pressure-runtime.exe'])==b['executable_sha256']
    events=b['events'];assert len(events)==237 and all(e['returncode']==0 for e in events)
    assert events==json.loads(files[prefix+'EVENTS.json'])
    expected_flags=[x for x in old['flags'] if not x.startswith(('-I','-J'))]
    assert ('-'+opt) in expected_flags
    assert all(x in expected_flags for x in ('-fcheck=all','-ffpe-trap=invalid,zero,overflow'))
    sources=list(b['source_sha256'].items())
    for index,(name,pin) in enumerate(old['source_sha256'].items()):
        path=relative(name);raw=files['compiled-source/'+path]
        if path==PROCESS:
            assert raw==files[prefix+Path(PROCESS).name]
            assert pin==b['source_original_sha256']
        else:assert sha(raw)==pin
        assert sha(raw)==sources[index][1]
        cmd=events[index]['command'];assert cmd[0]==events[0]['command'][0]
        flags=cmd[1:cmd.index('-c')]
        assert [x for x in flags if not x.startswith(('-I','-J'))]==expected_flags
        assert len([x for x in flags if x.startswith('-I')])==len([x for x in flags if x.startswith('-J')])==1
        assert cmd[cmd.index('-c')+1]==sources[index][0]
        assert cmd[-2]=='-o' and cmd[-1].replace('\\','/').endswith('/'+str(index)+'.o')
        assert sha(files[prefix+str(index)+'.o'])==b['compiled_objects_sha256'][str(index)+'.o']
        assert files[prefix+str(index)+'.stderr']==b'' or b'Error:' not in files[prefix+str(index)+'.stderr']
    pub=old['publication_provider']
    assert sha(files[prefix+'restart_publish.o'])==pub['object_sha256']
    assert sha(files['publication-source.c'])==pub['source_sha256']
    assert sha(files['ttutil.a'])==old['archive_sha256']
    assert events[-1]['command'][1].startswith('@')
    args=files[prefix+'link.args'].decode().splitlines()
    assert len(args)==242 and args[0]=='"-fopenmp"' and args[1]=='"-Wl,--stack,16777216"'
    assert all(args[i+2].strip('"').endswith('/'+str(i)+'.o') for i in range(236))
    return b

def audit(files,prior,reference,incumbent_builds):
    reg=json.loads(files['REGISTRATION.json'])
    assert reg==json.loads((BASE/'MICRO_PRESSURE_RUNTIME_PREREGISTRATION_20261104.json').read_text())
    assert reg['production_admission'] is reg['whole_scientific_admission'] is False
    builds={opt:source_binding(files,opt) for opt in ('O0','O2')}
    assert all(builds[opt]['baseline']==incumbent_builds[opt] for opt in builds)
    result=measure(files,.01,prior,reference,builds)
    # Reuse the unchanged original37 limits and independent complete ledger
    # validator, including its six defect controls. No assertion requires the
    # original science to turn green in this research stage.
    windows=[{k:float(v) for k,v in r.items()} for r in records(files['full-O2/budget.csv'])]
    grouped=collections.defaultdict(list)
    for r in windows:grouped[int(math.ceil(r['t1_day']-1e-9))].append(r)
    daily=[]
    for day,parts in sorted(grouped.items()):
        row={k:math.fsum(x[k] for x in parts) for k in parts[0]};row['t0_day']=day-1;row['t1_day']=day
        for p,u in [('water','cm'),('solute','mg_cm2')]:
            row[p+'_start_'+u]=parts[0][p+'_start_'+u];row[p+'_end_'+u]=parts[-1][p+'_end_'+u]
        daily.append(row)
    crops=records(files['full-O2/crop.csv'])
    selected={d:profile(files[f'full-O2/checkpoint-{d}.bin']) for d in reg['checkpoints']}
    assert all(p['day']==d for d,p in selected.items())
    state=records(files['full-O2/state.csv']);assert len(state)==34
    for key in ('z_cm','dz_cm','head_cm','theta','concentration_mg_cm3','dissolved_mg_cm2','sorbed_mg_cm2'):
        assert selected[1096][key]==[float(r[key]) for r in state],key
    for phase in ('full-O2','strict-O2-1088','compatible-O0-1077','strict-O0-1088'):
        start=json.loads(files[phase+'/START.json']);end=json.loads(files[phase+'/RESULT.json'])
        assert all(start[k]==end[k] for k in start)
    # The independent wet-cut owner needs crop observations (available day495+).
    physical=ledger(daily,crops,{d:p for d,p in selected.items() if d>=495},1096)
    for d in (120,365,494):
        assert abs(selected[d]['water_stock_cm']-daily[d-1]['water_end_cm'])<=1e-10
        assert abs(selected[d]['solute_stock_mg_cm2']-daily[d-1]['solute_end_mg_cm2'])<=1e-10
    controls=[]
    def refuse(label,fn):
        try:fn()
        except (AssertionError,KeyError):controls.append(label)
        else:raise AssertionError('accepted runtime defect '+label)
    for opt in ('O0','O2'):
        altered=dict(files);altered['build-'+opt+'/'+Path(PROCESS).name]=files['incumbent-source/'+PROCESS]
        refuse(opt+'_incumbent_substitution',lambda:source_binding(altered,opt))
        altered=dict(files);b=json.loads(altered['build-'+opt+'/BUILD.json']);b['events'][0]['returncode']=1
        altered['build-'+opt+'/BUILD.json']=json.dumps(b).encode()
        refuse(opt+'_failed_compile',lambda:source_binding(altered,opt))
    for phase in ('strict-O2-1088','compatible-O0-1077','strict-O0-1088'):
        altered=dict(files);r=json.loads(altered[phase+'/RESULT.json']);r['restart_sha256']='0'*64
        altered[phase+'/RESULT.json']=json.dumps(r).encode()
        from native_refinement_evidence import inputs
        refuse(phase+'_foreign_seed',lambda:inputs(altered,.01,prior))
    changed=bytearray(files['full-O2/checkpoint-930.bin']);changed[100]^=1
    refuse('CRC_corruption',lambda:profile(bytes(changed)))
    altered=copy.deepcopy(daily);altered[930]['canopy_capacity_export_cm']=1e-5
    refuse('repeated_next_day_export',lambda:ledger(altered,crops,{930:selected[930]},1096))
    baseline=json.loads(prior['MEASURED.json'])
    comparison={k:dict(incumbent_error=baseline['assessment'][k]['error'],runtime_error=v['error'],
                      unchanged_limit=v['limit'],inside_frozen_bound=v['inside_frozen_bound']) for k,v in result['assessment'].items()}
    return dict(status='ACTUAL_FULL_PRESSURE_RUNTIME_RESEARCH_AUDIT_PASS_NOT_PRODUCTION',
                actual_O2_full_days=1096,O0_scope='Prior-build same-variant codec control1077 then strict own1088, not a full O0 trajectory',
                source_bound_complete_builds=True,full_audit=result,wet_cut_and_extra_primitive_proof=physical,
                added_refusal_controls=controls,original37_comparison=comparison,
                retained_failures=result['retained_failures'],production_admission=False,whole_scientific_admission=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
    # Pin and validate the admitted unchanged full input/reference dataset.
    prior_record=json.loads((BASE/'FULL_PROFILE_EVIDENCE_20261104.json').read_text())
    prior_path=BASE/'FULL_PROFILE_EVIDENCE_20261104.tar.xz'
    assert sha(prior_path.read_bytes())==prior_record['archive_sha256']
    prior=unpack(prior_path,prior_record['files_sha256'])
    incumbent_record=json.loads((BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.json').read_text())
    incumbent_path=BASE/'CORRECTED_ROTATION_EVIDENCE_20261103.tar.xz'
    assert sha(incumbent_path.read_bytes())==incumbent_record['archive_sha256']
    incumbent=unpack(incumbent_path,incumbent_record['files_sha256'])
    incumbent_builds={opt:json.loads(incumbent[('build-O0' if opt=='O0' else 'build')+'/BUILD.json']) for opt in ('O0','O2')}
    manifest=json.loads((BASE/'SPRINT03_SCIENCE_MANIFEST.json').read_text());ref_path=BASE/manifest['archive']
    assert sha(ref_path.read_bytes())==manifest['archive_sha256']
    with tarfile.open(ref_path) as t:
        reference={n:t.extractfile(n).read() for n in ('original/dtmax-0.0003125/result_output.csv','original/dtmax-0.0003125/hupsel_profiles.csv','science/FROZEN_BOUNDS_BEFORE_HOLDOUT.json')}
    assert all(sha(b)==manifest['members'][n] for n,b in reference.items())
    if a.capture:
        root=a.capture.resolve();assert (root/'EXECUTED.json').exists() and not (root/'FAILED.json').exists()
        files={f.relative_to(root).as_posix():f.read_bytes() for f in root.rglob('*') if f.is_file() and f.suffix not in ('.mod','.smod')}
        for opt in ('O0','O2'):
            b=json.loads(files['build-'+opt+'/BUILD.json'])
            for name in b['baseline']['source_sha256']:
                rel=relative(name)
                raw=(root/('build-'+opt)/Path(PROCESS).name).read_bytes() if rel==PROCESS else Path(name).read_bytes()
                key='compiled-source/'+rel
                if key in files:assert files[key]==raw
                files[key]=raw
            provider=b['baseline']['publication_provider']
            files['build-'+opt+'/restart_publish.o']=Path(provider['object']).read_bytes()
            files['publication-source.c']=Path(provider['source']).read_bytes()
            files['ttutil.a']=Path(b['baseline']['ttutil_archive']).read_bytes()
        files['incumbent-source/'+PROCESS]=(ROOT/PROCESS).read_bytes()
    else:
        record=json.loads((BASE/(STEM+'.json')).read_text())
        for n,h in record['normalized_repository_dependency_sha256'].items():assert norm(ROOT/n)==h,n
        path=BASE/(STEM+'.tar.xz');assert sha(path.read_bytes())==record['archive_sha256']
        files=unpack(path,record['files_sha256'])
    result=audit(files,prior,reference,incumbent_builds)
    if a.capture:
        files['AUDIT.json']=(json.dumps(result,indent=2)+'\n').encode()
        path=BASE/(STEM+'.tar.xz')
        with tarfile.open(path,'w:xz') as t:
            for n,b in sorted(files.items()):
                member=tarfile.TarInfo(n);member.size=len(b);member.mtime=0;t.addfile(member,io.BytesIO(b))
        deps=dict(prior_record['normalized_repository_dependency_sha256'])
        for name in files:
            if name.startswith('compiled-source/'):
                rel=name.removeprefix('compiled-source/')
                if not rel.startswith('external-source/'):deps[rel]=norm(ROOT/rel)
        for n in ('tests/dataqual15_hupsel/micro_pressure_runtime.py','tests/dataqual15_hupsel/micro_pressure_runtime_evidence.py',
                  'tests/dataqual15_hupsel/micro_pressure_probe.py','tests/dataqual15_hupsel/native_refinement_evidence.py',
                  'tests/dataqual15_hupsel/run_canopy_observation.py','tests/dataqual15_hupsel/audit_corrected_rotation.py',
                  '.github/workflows/hupsel-micro-pressure-runtime.yml','integration/dataqual15_hupsel/MICRO_PRESSURE_RUNTIME_PREREGISTRATION_20261104.json',
                  'integration/dataqual15_hupsel/FULL_PROFILE_EVIDENCE_20261104.json','integration/dataqual15_hupsel/SPRINT03_SCIENCE_MANIFEST.json'):
            deps[n]=norm(ROOT/n)
        record=dict(status=result['status'],archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b) for n,b in files.items()},
                    normalized_repository_dependency_sha256=deps,retained_failures=result['retained_failures'],production_admission=False,whole_scientific_admission=False)
        (BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n',encoding='utf-8')
    else:assert result==json.loads(files['AUDIT.json'])
    print(result['status']);print(json.dumps(result['retained_failures']))

if __name__=='__main__':main()
