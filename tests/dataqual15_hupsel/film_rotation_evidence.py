"""Seal/re-read actual full-rotation data with exact inherited native closure."""
import argparse,copy,io,json,tarfile,tempfile,zipfile
from pathlib import Path,PurePosixPath,PureWindowsPath
import film_rotation_audit as audit
from film_runtime_profiles import profile4

BASE=audit.BASE;ROOT=audit.ROOT;sha=audit.sha;STEM='FILM_ROTATION_WINDOWS_20261104'


def qualification_dependencies():
    names=['film_rotation.py','film_rotation_audit.py','film_rotation_evidence.py','test_film_rotation.py',
           'film_runtime.py','film_runtime_audit.py','film_runtime_profiles.py','film_runtime_counter.py',
           'film_runtime_evidence.py','film_refinement_candidate.py','audit_corrected_rotation.py',
           'scientific_followup.py','production_diagnostic_native.py','production_diagnostic_guards.py',
           'qualify_rotation_restart_guards.py','inspect_profiles.py']
    paths=['tests/dataqual15_hupsel/'+n for n in names]+['integration/dataqual15_hupsel/'+audit.runner.REG,'.github/workflows/hupsel-film-rotation.yml',
        'app/support/restart_publish.c','tests/dataqual15_hupsel/build_and_run.py','tests/dataqual15/original_sources.py',
        'tests/dataqual15/verify_current_native_admission.py','tests/dataqual15_hupsel/production_diagnostic_admission.py']
    return {p:sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))for p in paths}


def controls(folder,opt):
    case=folder/'unobserved1096';native=json.loads((folder/'native/build/BUILD.json').read_text());original=(case/'checkpoint.bin').read_bytes()
    owner=json.loads((folder/'owner-controls/RESULT.json').read_text());app=json.loads((folder/'app-refusals/RESULT.json').read_text())
    assert len({e['case']for e in owner['events']})==37 and (folder/'owner-controls/valid-original.bin').read_bytes()==original
    assert owner['executable_sha256']==native['executable_sha256']and owner['checkpoint_sha256']==sha(original)and owner['clock']==1096
    for event in owner['events']:
        place=folder/'owner-controls'/event['case'];stdout=(place/'stdout').read_bytes();stderr=(place/'stderr').read_bytes()
        assert sha((place/'restart-input.bin').read_bytes())==event['checkpoint_sha256']
        valid=event['case']=='valid_nonadvancing';assert event['reached_post_read_boundary']==valid and (b'no requested windows remain'in stdout+stderr)==valid
        if not valid:assert b'source rotation envelope rejected before publication'in stdout or b'restart rejected'in stdout
        assert event['returncode']==1 and event['status']=='PASS'and not any((place/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin','restart.bin','germination.csv'))
    assert {e['case']for e in app['events']}=={'legacy3','missing','extra','crc','changed_input',*[f'{field}_{kind}'for field in (0,1)for kind in ('nan','posinf','neginf')]}
    for event in app['events']:
        place=folder/'app-refusals'/event['case'];assert event['returncode']==1 and b'source rotation envelope rejected before publication'in(place/'stdout').read_bytes()
        assert not any((place/n).exists()for n in ('budget.csv','crop.csv','checkpoint.bin'))
    return dict(owner_controls=37,app_refusals=11)


def data_controls(folder):
    case=folder/'unobserved1096';_,daily,_=audit.daily_data(case);crops=audit.rows(case/'crop.csv')
    days=json.loads((BASE/audit.runner.REG).read_text())['profile_days'];points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in days if d>=495};trials=[]
    for name in ('water_export','solute_export','continuity','canopy_bound','crop_gap','duplicate_cut_export','primitive_stock'):
        d,c,p=copy.deepcopy((daily,crops,points))
        if name=='water_export':d[100]['water_out_cm']+=1e-6
        elif name=='solute_export':d[100]['solute_out_mg_cm2']+=1e-6
        elif name=='continuity':d[100]['water_start_cm']+=1e-6;d[100]['water_end_cm']+=1e-6
        elif name=='canopy_bound':c[-1]['accepted_canopy_stock_cm']=str(float(c[-1]['post_management_capacity_cm'])+1e-6)
        elif name=='crop_gap':c.pop(100)
        elif name=='duplicate_cut_export':d[930]['water_in_cm']+=1e-6;d[930]['water_out_cm']+=1e-6;d[930]['canopy_capacity_export_cm']=1e-6
        else:p[1096]['water_stock_cm']+=1e-6
        try:audit.ledger(d,c,p,1096)
        except(AssertionError,KeyError):trials.append(name)
        else:raise AssertionError('read-only full ledger accepted '+name)
    raw=bytearray((case/'checkpoint-120.bin').read_bytes());raw[30]^=1
    try:profile4(raw)
    except AssertionError:trials.append('actual_profile_crc')
    else:raise AssertionError('accepted corrupt typed profile')
    registration=json.loads((BASE/audit.runner.REG).read_text());points={d:profile4((case/f'checkpoint-{d}.bin').read_bytes())for d in set(registration['profile_days']+registration['additional_capture_days'])};state=audit.rows(case/'state.csv')
    for name in ('missing_profile','misbound_clock','profile_geometry','profile_water_stock','profile_solute_stock'):
        altered=copy.deepcopy(points)
        if name=='missing_profile':del altered[120]
        elif name=='misbound_clock':altered[120]['day']=121
        elif name=='profile_geometry':altered[120]['dz_cm'][0]+=1e-6
        elif name=='profile_water_stock':altered[120]['water_stock_cm']+=1e-6
        else:altered[120]['solute_stock_mg_cm2']+=1e-6
        try:audit.profile_checks(altered,daily,state)
        except AssertionError:trials.append(name)
        else:raise AssertionError('accepted defective selected profile '+name)
    return trials


def verify(folder,platform,opts=('O0','O2')):
    result={}
    for opt in opts:
        place=folder/opt;marker=json.loads((place/'EXECUTED.json').read_text());assert marker['production_admission']is False and marker['whole_scientific_admission']is False
        proof=audit.audit(place,opt,platform);proof['native_controls']=controls(place,opt);proof['data_refusals']=data_controls(place);result[opt]=proof
    return dict(status='ACTUAL_PRIVATE_FULL1096_MASS_WET_CUT_RESTART_PROFILE_OBSERVATION_AND_UNCHANGED_SCIENCE_ASSESSMENT_COMPLETE',platform=platform,builds=result,qualification_dependencies=qualification_dependencies(),production_admission=False,whole_scientific_admission=False)


def safe(name):
    return not PurePosixPath(name).is_absolute()and not PureWindowsPath(name).drive and not PureWindowsPath(name).root and '..'not in PurePosixPath(name).parts and '..'not in PureWindowsPath(name).parts


def extract_verify(files,platform,opts=('O0','O2')):
    assert all(safe(n)for n in files)
    with tempfile.TemporaryDirectory(prefix='film-rotation-audit-')as name:
        folder=Path(name).resolve();assert folder.parent==Path(tempfile.gettempdir()).resolve()and folder.name.startswith('film-rotation-audit-')
        for n,raw in files.items():dest=folder/n;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(raw)
        return verify(folder,platform,opts)


def posix(paths):
    files={};artifacts={}
    for opt,path in zip(('O0','O2'),paths):
        raw=path.read_bytes();artifacts[opt]=dict(archive=path.name,archive_sha256=sha(raw))
        with zipfile.ZipFile(io.BytesIO(raw))as z:
            names=[n for n in z.namelist()if not n.endswith('/')];assert len(names)==len(set(names))and all(safe(n)for n in names)
            preserve=json.loads(z.read('film-rotation-preservation/RESULT.json'));assert preserve['status']=='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS'
            for n in names:
                if n.startswith('film-rotation/'+opt+'/'):files[n.removeprefix('film-rotation/')]=z.read(n)
    return dict(extract_verify(files,'posix'),original_artifacts=artifacts,files_sha256={n:sha(raw)for n,raw in files.items()})


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--capture',type=Path);parser.add_argument('--posix-zips',nargs=2,type=Path);parser.add_argument('--posix',action='store_true');parser.add_argument('--native-mode',action='store_true');args=parser.parse_args()
    if args.native_mode:
        path=BASE/'FILM_ROTATION_POSIX_20261104.json'
        if not path.exists():print('reused=false');return
        record=json.loads(path.read_text());assert record['qualification_dependencies']==qualification_dependencies()
        paths=[BASE/record['original_artifacts'][o]['archive']for o in ('O0','O2')]
        assert all(sha(p.read_bytes())==record['original_artifacts'][o]['archive_sha256']for o,p in zip(('O0','O2'),paths))
        assert posix(paths)==record;print('reused=true');return
    if args.posix_zips:
        result=posix(args.posix_zips);(BASE/'FILM_ROTATION_POSIX_20261104.json').write_text(json.dumps(result,indent=2)+'\n')
    elif args.posix:
        record=json.loads((BASE/'FILM_ROTATION_POSIX_20261104.json').read_text());paths=[BASE/record['original_artifacts'][o]['archive']for o in ('O0','O2')]
        assert all(sha(p.read_bytes())==record['original_artifacts'][o]['archive_sha256']for o,p in zip(('O0','O2'),paths));result=posix(paths);assert result==record
    elif args.capture:
        folder=args.capture.resolve();result=verify(folder,'windows');files={}
        keep={'.json','.csv','.bin','.dat','.f90','.c','.exe','.nml','.swp','.crp','.met','.dra'}
        for path in folder.rglob('*'):
            if path.is_file()and(path.suffix in keep or path.name in ('stdout','stderr','swap5_hupsel_germination')):
                name=path.relative_to(folder).as_posix()
                if name.startswith(('O0/','O2/')):files[name]=path.read_bytes()
        archive=BASE/(STEM+'.tar.xz')
        with tarfile.open(archive,'w:xz',preset=3)as t:
            for n,raw in sorted(files.items()):item=tarfile.TarInfo(n);item.size=len(raw);t.addfile(item,io.BytesIO(raw))
        (BASE/(STEM+'.json')).write_text(json.dumps(dict(result,archive=archive.name,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(raw)for n,raw in files.items()}),indent=2)+'\n')
    else:
        record=json.loads((BASE/(STEM+'.json')).read_text());assert record['production_admission']is False and record['whole_scientific_admission']is False
        raw=(BASE/record['archive']).read_bytes();assert sha(raw)==record['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:
            members=t.getmembers();assert all(m.isfile()and safe(m.name)for m in members);files={m.name:t.extractfile(m).read()for m in members}
        assert len(files)==len(members)and set(files)==set(record['files_sha256'])and all(sha(raw)==record['files_sha256'][n]for n,raw in files.items())
        result=extract_verify(files,'windows');assert result=={k:v for k,v in record.items()if k not in ('archive','archive_sha256','files_sha256')}
    print(result['status'])

if __name__=='__main__':main()
