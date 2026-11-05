"""Original native composed accepted-state evidence sealed and remeasured."""
import argparse,io,json,tarfile,tempfile,zipfile
from pathlib import Path
import composed_oxygen as run
import composed_oxygen_audit as check
ROOT=run.ROOT;BASE=run.BASE;sha=run.sha

def dependencies():
    d=run.parent.dependencies()
    for n in ('composed_oxygen.py','composed_oxygen_audit.py','composed_oxygen_evidence.py','test_composed_oxygen.py','pressure_oxygen_observer.py','root_oxygen_observer.py','root_oxygen_evidence.py','matched_oxygen_observer.py','matched_micro_observer.py','matched_oxygen_evidence.py','pressure_oxygen_evidence.py','matched_micro_replay.py','matched_oxygen_owners.f90','matched_oxygen_driver.f90','pressure_oxygen_partition_driver.f90'):
        p='tests/dataqual15_hupsel/'+n;d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    for p in ('tests/physics/run_ppa_micro02_source_oracle.py','integration/audits/PPA_WU05C3A_B111_OXYGEN_SOURCE.json','integration/dataqual15_hupsel/'+run.REG,'.github/workflows/hupsel-composed-oxygen.yml'):
        d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    return d

def collect(folder):
    keep={'.json','.bin','.csv','.dat','.nml','.swp','.crp','.met','.dra','.exe','.f90','.o','.a','.args','.stdout','.stderr'}
    return {p.relative_to(folder).as_posix():p.read_bytes()for p in folder.rglob('*')if p.is_file()and(p.suffix in keep or p.name in ('model','observed','stdout','stderr'))and p.name!='CAPSULE.json'}

def verify(files,origin):
    native,pin=run.inherited(origin['optimization'],origin['platform'],verify=False);assert origin==pin
    assert all(run.parent.prior.safe(n)for n in files)
    with tempfile.TemporaryDirectory(prefix='composed-oxygen-audit-')as name:
        out=Path(name).resolve();assert out.parent==Path(tempfile.gettempdir()).resolve()and out.name.startswith('composed-oxygen-audit-')
        for n,b in files.items():p=out/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        result,_,_=check.audit(out,native,origin);assert result==json.loads(files['RESULT.json']);return result

def read(raw,record):
    assert sha(raw)==record['archive_sha256']and record['qualification_dependencies']==dependencies()and record['production_admission']is False and record['whole_scientific_admission']is False
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        members=t.getmembers();assert all(m.isfile()and run.parent.prior.safe(m.name)for m in members);files={m.name:t.extractfile(m).read()for m in members}
    assert len(files)==len(members)and set(files)==set(record['files_sha256'])and all(sha(b)==record['files_sha256'][n]for n,b in files.items())
    result=verify(files,json.loads(files['ORIGIN.json']));assert result==record['result'];return result

def windows():
    result={}
    for opt in ('O0','O2'):
        stem='COMPOSED_OXYGEN_WINDOWS_'+opt+'_20261105';record=json.loads((BASE/(stem+'.json')).read_text());result[opt]=read((BASE/(stem+'.tar.xz')).read_bytes(),record);assert result[opt]['optimization']==opt and result[opt]['platform']=='windows'
    return result

def posix(paths):
    result={};original={}
    for opt,path in zip(('O0','O2'),paths):
        raw=path.read_bytes();original[opt]=dict(archive=path.name,archive_sha256=sha(raw))
        with zipfile.ZipFile(io.BytesIO(raw))as z:
            names=[n for n in z.namelist()if not n.endswith('/')];assert len(names)==len(set(names))and all(run.parent.prior.safe(n)for n in names)
            prefix='composed-oxygen/'+opt+'/';record=json.loads(z.read(prefix+'CAPSULE.json'));result[opt]=read(z.read(prefix+'CAPSULE.tar.xz'),record);assert result[opt]['optimization']==opt and result[opt]['platform']=='posix'
            preservation=json.loads(z.read('composed-oxygen-preservation/RESULT.json'));assert preservation['status']=='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS'
    return dict(status='ACTUAL_COMPOSED_ACCEPTED_STATE_O0_O2_ORIGINAL_OPERATOR_QUALIFICATION_COMPLETE',builds=result,original_artifacts=original,qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False,migration_complete=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--audit-existing',type=Path);p.add_argument('--windows',action='store_true');p.add_argument('--posix-zips',type=Path,nargs=2);p.add_argument('--native-mode',action='store_true');a=p.parse_args()
    if a.audit_existing:
        folder=a.audit_existing.resolve();origin=json.loads((folder/'ORIGIN.json').read_text());native,pin=run.inherited(origin['optimization'],origin['platform']);assert origin==pin
        result,_,_=check.audit(folder,native,origin);(folder/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status']);return
    if a.capture:
        folder=a.capture.resolve();files=collect(folder);origin=json.loads(files['ORIGIN.json']);result=verify(files,origin);archive=folder/'CAPSULE.tar.xz'
        with tarfile.open(archive,'w:xz',preset=3)as t:
            for n,b in sorted(files.items()):item=tarfile.TarInfo(n);item.size=len(b);t.addfile(item,io.BytesIO(b))
        record=dict(result=result,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False)
        (folder/'CAPSULE.json').write_text(json.dumps(record,indent=2)+'\n');print(result['status']);return
    if a.windows:windows();print('BOTH_WINDOWS_ACTUAL_COMPOSED_ACCEPTED_STATE_CAPSULES_PASS');return
    target=BASE/'COMPOSED_OXYGEN_POSIX_20261105.json'
    if a.native_mode and not target.exists():print('reused=false');return
    if a.posix_zips:target.write_text(json.dumps(posix(a.posix_zips),indent=2)+'\n');print('ACTUAL_COLD_POSIX_COMPOSED_ACCEPTED_STATE_PAIR_PASS');return
    record=json.loads(target.read_text());assert record['qualification_dependencies']==dependencies();paths=[BASE/record['original_artifacts'][opt]['archive']for opt in ('O0','O2')];assert posix(paths)==record
    print('reused=true'if a.native_mode else record['status'])

if __name__=='__main__':main()
