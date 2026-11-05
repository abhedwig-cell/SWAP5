"""Coherent two-operator source/object and actual-data evidence, not admission."""
import argparse,copy,io,json,tarfile,tempfile,zipfile
from pathlib import Path
import pressure_film_audit as audit
import film_rotation_evidence as prior
from film_runtime_profiles import profile4

ROOT=audit.ROOT;BASE=audit.BASE;sha=audit.sha


def dependencies():
    inherited=prior.qualification_dependencies()
    for name in ('pressure_film.py','pressure_film_audit.py','pressure_film_evidence.py','test_pressure_film.py','micro_pressure_probe.py'):
        path='tests/dataqual15_hupsel/'+name;inherited[path]=sha((ROOT/path).read_bytes().replace(b'\r\n',b'\n'))
    for path in ('integration/dataqual15_hupsel/'+audit.runner.REG,'.github/workflows/hupsel-pressure-film.yml'):
        inherited[path]=sha((ROOT/path).read_bytes().replace(b'\r\n',b'\n'))
    return inherited


def collect(folder,opt):
    files={};keep={'.json','.csv','.bin','.dat','.f90','.c','.o','.a','.exe','.stdout','.stderr','.args','.nml','.swp','.crp','.met','.dra'}
    for path in folder.rglob('*'):
        if path.is_file()and(path.suffix in keep or path.name in ('stdout','stderr','swap5_hupsel_germination','writer-probe')):
            if path.name not in ('CAPSULE.json',):files[opt+'/'+path.relative_to(folder).as_posix()]=path.read_bytes()
    build=json.loads((folder/'build/BUILD.json').read_text());context=audit.paths(build,opt);old=build['baseline']
    for name,pin in old['source_sha256'].items():
        raw=Path(name).read_bytes();assert sha(raw)==pin;files[audit.key(name,context,opt)]=raw
    pub=old['publication_provider']
    for name in (pub['source'],pub['object'],old['ttutil_archive']):files[audit.key(name,context,opt)]=Path(name).read_bytes()
    baseline=Path(old['ttutil_archive']).parent
    for name in ('BUILD.json','EVENTS.json','ORIGINAL_EVENTS.json'):
        if(baseline/name).exists():files['baseline-'+opt+'/'+name]=(baseline/name).read_bytes()
    return files


def real_controls(folder):
    case=folder/'full1096';raw=(case/'checkpoint.bin').read_bytes();owner=json.loads((folder/'owner-controls/RESULT.json').read_text());app=json.loads((folder/'app-refusals/RESULT.json').read_text())
    assert len({e['case']for e in owner['events']})==37 and(folder/'owner-controls/valid-original.bin').read_bytes()==raw
    for event in owner['events']:
        place=folder/'owner-controls'/event['case'];stdout=(place/'stdout').read_bytes();stderr=(place/'stderr').read_bytes();valid=event['case']=='valid_nonadvancing'
        assert sha((place/'restart-input.bin').read_bytes())==event['checkpoint_sha256']and event['reached_post_read_boundary']==valid and(b'no requested windows remain'in stdout+stderr)==valid
        if not valid:assert b'source rotation envelope rejected before publication'in stdout or b'restart rejected'in stdout
        assert event['returncode']==1 and not any((place/n).exists()for n in ('budget.csv','checkpoint.bin','crop.csv','restart.bin','germination.csv'))
    assert {e['case']for e in app['events']}=={'legacy3','missing','extra','crc','changed_input',*[f'{i}_{kind}'for i in (0,1)for kind in ('nan','posinf','neginf')]}
    for event in app['events']:
        place=folder/'app-refusals'/event['case'];assert event['returncode']==1 and b'source rotation envelope rejected before publication'in(place/'stdout').read_bytes()
        assert not any((place/n).exists()for n in ('budget.csv','checkpoint.bin','crop.csv'))
    from production_diagnostic_native import instrument
    build=json.loads((folder/'writer-build/BUILD.json').read_text());source=folder/'writer-build/main_writer_probe.f90'
    assert source.read_text()==instrument((ROOT/'app/solute_project/main.f90').read_text())and sha(source.read_bytes())==build['instrumented_main_sha256']and sha((folder/'build/BUILD.json').read_bytes())==build['parent_build_sha256']
    exe=next(p for p in (folder/'writer-build/writer-probe.exe',folder/'writer-build/writer-probe')if p.exists());assert sha(exe.read_bytes())==build['executable_sha256']
    result=json.loads((folder/'writer-qualification/RESULT.json').read_text());assert result['probe_executable_sha256']==sha(exe.read_bytes())
    where=folder/'writer-qualification';assert(where/'continuous2/checkpoint.bin').read_bytes()==(where/'restart2/checkpoint.bin').read_bytes()==(where/'writer2/checkpoint.bin').read_bytes()
    for name in ('budget.csv','crop.csv'):assert(where/'continuous2'/name).read_bytes()==(where/'writer2'/name).read_bytes()
    assert [' '.join(line.split())for line in(where/'writer2/writer_probe.dat').read_text().splitlines()]==['1 1 1','1 2 1','1 3 1','2 1 1','2 2 1','2 3 1']and not list((where/'writer2').glob('checkpoint.bin.*'))


def data_controls(folder):
    case=folder/'full1096';_,daily,_=audit.rotation.daily_data(case);crop=audit.rotation.rows(case/'crop.csv');registration=json.loads((BASE/audit.runner.REG).read_text())
    points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in registration['capture_days']};state=audit.rotation.rows(case/'state.csv');trials=[]
    for name in ('water_export','solute_export','continuity','canopy_bound','crop_gap','duplicate_cut_export','primitive_stock'):
        d,c,p=copy.deepcopy((daily,crop,{n:p for n,p in points.items()if n>=495}))
        if name=='water_export':d[100]['water_out_cm']+=1e-6
        elif name=='solute_export':d[100]['solute_out_mg_cm2']+=1e-6
        elif name=='continuity':d[100]['water_start_cm']+=1e-6;d[100]['water_end_cm']+=1e-6
        elif name=='canopy_bound':c[-1]['accepted_canopy_stock_cm']=str(float(c[-1]['post_management_capacity_cm'])+1e-6)
        elif name=='crop_gap':c.pop(100)
        elif name=='duplicate_cut_export':d[930]['water_in_cm']+=1e-6;d[930]['water_out_cm']+=1e-6;d[930]['canopy_capacity_export_cm']=1e-6
        else:p[1096]['water_stock_cm']+=1e-6
        try:audit.rotation.ledger(d,c,p,1096)
        except(AssertionError,KeyError):trials.append(name)
        else:raise AssertionError('accepted ledger defect '+name)
    for name in ('missing_profile','misbound_clock','geometry','water_stock','solute_stock'):
        p=copy.deepcopy(points)
        if name=='missing_profile':del p[120]
        elif name=='misbound_clock':p[120]['day']=121
        elif name=='geometry':p[120]['dz_cm'][0]+=1e-6
        elif name=='water_stock':p[120]['water_stock_cm']+=1e-6
        else:p[120]['solute_stock_mg_cm2']+=1e-6
        try:audit.rotation.profile_checks(p,daily,state)
        except AssertionError:trials.append(name)
        else:raise AssertionError('accepted profile defect '+name)
    raw=bytearray((case/'checkpoint-120.bin').read_bytes());raw[30]^=1
    try:profile4(raw)
    except AssertionError:trials.append('profile_crc')
    else:raise AssertionError('accepted typed CRC defect')
    return trials


def verify(folder,files,opt):
    audit.source_binding(files,opt);marker=json.loads((folder/'EXECUTED.json').read_text());assert marker['production_admission']is False and marker['whole_scientific_admission']is False
    result=audit.audit(folder,opt);real_controls(folder);result['data_refusals']=data_controls(folder);return result


def extract_verify(files,opt):
    assert all(prior.safe(n)for n in files)
    with tempfile.TemporaryDirectory(prefix='pressure-film-audit-')as name:
        root=Path(name).resolve();assert root.parent==Path(tempfile.gettempdir()).resolve()and root.name.startswith('pressure-film-audit-')
        for n,raw in files.items():target=root/n;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(raw)
        return verify(root/opt,files,opt)


def read_capsule(raw,record,opt):
    assert sha(raw)==record['archive_sha256']and record['qualification_dependencies']==dependencies()and record['production_admission']is False and record['whole_scientific_admission']is False
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        members=t.getmembers();assert all(m.isfile()and prior.safe(m.name)for m in members);files={m.name:t.extractfile(m).read()for m in members}
    assert len(files)==len(members)and set(files)==set(record['files_sha256'])and all(sha(raw)==record['files_sha256'][n]for n,raw in files.items())
    result=extract_verify(files,opt);assert result==record['result'];return result


def posix(paths):
    result={};artifacts={}
    for opt,path in zip(('O0','O2'),paths):
        raw=path.read_bytes();artifacts[opt]=dict(archive=path.name,archive_sha256=sha(raw))
        with zipfile.ZipFile(io.BytesIO(raw))as z:
            names=[n for n in z.namelist()if not n.endswith('/')];assert len(names)==len(set(names))and all(prior.safe(n)for n in names)
            prefix='pressure-film/'+opt+'/';record=json.loads(z.read(prefix+'CAPSULE.json'));result[opt]=read_capsule(z.read(prefix+'CAPSULE.tar.xz'),record,opt)
            preserve=json.loads(z.read('pressure-film-preservation/RESULT.json'));assert preserve['status']=='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS'
    return dict(status='ACTUAL_COHERENT_PRESSURE_FILM_FULL_RUNTIME_AND_UNCHANGED_SCIENCE_ASSESSMENT_COMPLETE',builds=result,original_artifacts=artifacts,qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False,migration_complete=False)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture-opt',type=Path);p.add_argument('--optimization',choices=['O0','O2']);p.add_argument('--windows',action='store_true');p.add_argument('--posix-zips',type=Path,nargs=2);p.add_argument('--native-mode',action='store_true');a=p.parse_args()
    if a.capture_opt:
        assert a.optimization;folder=a.capture_opt.resolve();files=collect(folder,a.optimization);result=verify(folder,files,a.optimization)
        archive=folder/'CAPSULE.tar.xz'
        with tarfile.open(archive,'w:xz',preset=3)as t:
            for n,raw in sorted(files.items()):item=tarfile.TarInfo(n);item.size=len(raw);t.addfile(item,io.BytesIO(raw))
        record=dict(status=result['status'],result=result,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(raw)for n,raw in files.items()},qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False)
        (folder/'CAPSULE.json').write_text(json.dumps(record,indent=2)+'\n');print(result['status']);return
    if a.windows:
        for opt in ('O0','O2'):
            record=json.loads((BASE/f'PRESSURE_FILM_WINDOWS_{opt}_20261105.json').read_text());read_capsule((BASE/f'PRESSURE_FILM_WINDOWS_{opt}_20261105.tar.xz').read_bytes(),record,opt)
        print('BOTH_WINDOWS_COHERENT_COMPOSITION_CAPSULES_PASS');return
    target=BASE/'PRESSURE_FILM_POSIX_20261105.json'
    if a.native_mode and not target.exists():print('reused=false');return
    if a.posix_zips:
        result=posix(a.posix_zips);target.write_text(json.dumps(result,indent=2)+'\n');print(result['status']);return
    record=json.loads(target.read_text());assert record['qualification_dependencies']==dependencies();paths=[BASE/record['original_artifacts'][opt]['archive']for opt in ('O0','O2')]
    assert all(sha(path.read_bytes())==record['original_artifacts'][opt]['archive_sha256']for opt,path in zip(('O0','O2'),paths));assert posix(paths)==record
    print('reused=true'if a.native_mode else record['status'])

if __name__=='__main__':main()
