"""Sealed actual cap-specific histories; no numerical evidence from metadata alone."""
import argparse,copy,io,json,tarfile,tempfile,zipfile
from pathlib import Path
import composed_temporal_audit as check
import composed_temporal as run
BASE=run.BASE;ROOT=run.ROOT;sha=run.sha

def dependencies():
    d=run.parent.dependencies()
    for name in ('composed_temporal.py','composed_temporal_audit.py','composed_temporal_evidence.py','test_composed_temporal.py'):
        p='tests/dataqual15_hupsel/'+name;d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    for p in ('integration/dataqual15_hupsel/'+run.REG,'.github/workflows/hupsel-composed-temporal.yml'):
        d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    return d

def defects(folder):
    case=folder/'prefix584';windows=[{k:float(v)for k,v in row.items()}for row in check.rows(case/'budget.csv')];crops=check.rows(case/'crop.csv');point=check.profile4((case/'checkpoint.bin').read_bytes());state=check.rows(case/'state.csv');results=[]
    for name in ('water_export','solute_export','continuity','nonfinite','canopy_bound','missing_crop','primitive_stock','state_mismatch'):
        w,c,p,s=copy.deepcopy((windows,crops,point,state))
        if name=='water_export':w[100]['water_out_cm']+=1e-6
        elif name=='solute_export':w[100]['solute_out_mg_cm2']+=1e-6
        elif name=='continuity':w[100]['water_start_cm']+=1e-6;w[100]['water_end_cm']+=1e-6
        elif name=='nonfinite':w[100]['oxygen_reduction_cm']=float('nan')
        elif name=='canopy_bound':c[-1]['accepted_canopy_stock_cm']=str(float(c[-1]['post_management_capacity_cm'])+1e-6)
        elif name=='missing_crop':c.pop(5)
        elif name=='primitive_stock':p['water_stock_cm']+=1e-6
        else:s[0]['theta']=str(float(s[0]['theta'])+1e-6)
        try:check.ledger(w,c,p,s)
        except(AssertionError,ValueError,KeyError):results.append(name)
        else:raise AssertionError('accepted actual-data defect '+name)
    raw=bytearray((case/'checkpoint.bin').read_bytes());raw[30]^=1
    try:check.profile4(raw)
    except AssertionError:results.append('CRC')
    else:raise AssertionError('accepted corrupt CRC')
    return results

def collect(folder):
    keep={'.json','.bin','.csv','.dat','.nml','.swp','.crp','.met','.dra','.exe'}
    return {p.relative_to(folder).as_posix():p.read_bytes()for p in folder.rglob('*')if p.is_file()and(p.suffix in keep or p.name in ('model','stdout','stderr'))and p.name not in ('CAPSULE.json',)}

def verify(files,platform):
    native,origin=run.inherited(platform,verify=False)
    assert all(run.parent.prior.safe(n)for n in files)
    with tempfile.TemporaryDirectory(prefix='composed-temporal-audit-')as name:
        root=Path(name).resolve();assert root.parent==Path(tempfile.gettempdir()).resolve()and root.name.startswith('composed-temporal-audit-')
        for n,b in files.items():p=root/n;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
        result=check.audit(root,native,origin);result['actual_data_refusals']=defects(root)
        assert json.loads(files['RESULT.json'])=={k:v for k,v in result.items()if k!='actual_data_refusals'}
        return result

def read(raw,record,platform):
    assert sha(raw)==record['archive_sha256']and record['qualification_dependencies']==dependencies()
    assert record['production_admission']is False and record['whole_scientific_admission']is False
    with tarfile.open(fileobj=io.BytesIO(raw))as t:
        m=t.getmembers();assert all(x.isfile()and run.parent.prior.safe(x.name)for x in m)
        files={x.name:t.extractfile(x).read()for x in m}
    assert len(files)==len(m)and set(files)==set(record['files_sha256'])and all(sha(b)==record['files_sha256'][n]for n,b in files.items())
    result=verify(files,platform);assert result==record['result'];return result

def windows():
    result={}
    for cap in run.CAPS:
        stem='COMPOSED_TEMPORAL_WINDOWS_'+str(cap)+'_20261105';record=json.loads((BASE/(stem+'.json')).read_text());result[str(cap)]=read((BASE/(stem+'.tar.xz')).read_bytes(),record,'windows')
    return result

def posix(paths):
    result={};original={}
    for cap,path in zip(run.CAPS,paths):
        raw=path.read_bytes();original[str(cap)]=dict(archive=path.name,archive_sha256=sha(raw))
        with zipfile.ZipFile(io.BytesIO(raw))as z:
            names=[n for n in z.namelist()if not n.endswith('/')];assert len(names)==len(set(names))and all(run.parent.prior.safe(n)for n in names)
            prefix='composed-temporal/'+str(cap)+'/'
            record=json.loads(z.read(prefix+'CAPSULE.json'));result[str(cap)]=read(z.read(prefix+'CAPSULE.tar.xz'),record,'posix')
            preserve=json.loads(z.read('composed-temporal-preservation/RESULT.json'));assert preserve['status']=='EXACT_CURRENT_S5HR4_NATIVE_BOUNDARY_AND_UNMODIFIED_PREDECESSOR_AUTHORITY_PASS'
    return dict(status='ACTUAL_COMPOSED_TEMPORAL_O2_PREFIX_DIAGNOSIS_COMPLETE',builds=result,original_artifacts=original,qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False,migration_complete=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);p.add_argument('--windows',action='store_true');p.add_argument('--posix-zips',type=Path,nargs=2);p.add_argument('--native-mode',action='store_true');a=p.parse_args()
    if a.capture:
        folder=a.capture.resolve();files=collect(folder);platform=json.loads(files['ORIGIN.json'])['platform'];result=verify(files,platform)
        archive=folder/'CAPSULE.tar.xz'
        with tarfile.open(archive,'w:xz',preset=3)as t:
            for n,b in sorted(files.items()):item=tarfile.TarInfo(n);item.size=len(b);t.addfile(item,io.BytesIO(b))
        record=dict(result=result,archive_sha256=sha(archive.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False)
        (folder/'CAPSULE.json').write_text(json.dumps(record,indent=2)+'\n');print(result['status']);return
    if a.windows:windows();print('BOTH_WINDOWS_CAP_SPECIFIC_RAW_CAPSULES_PASS');return
    target=BASE/'COMPOSED_TEMPORAL_POSIX_20261105.json'
    if a.native_mode and not target.exists():print('reused=false');return
    if a.posix_zips:target.write_text(json.dumps(posix(a.posix_zips),indent=2)+'\n');print('ACTUAL_POSIX_PAIR_AUDITED');return
    record=json.loads(target.read_text());assert record['qualification_dependencies']==dependencies()
    paths=[BASE/record['original_artifacts'][str(cap)]['archive']for cap in run.CAPS];assert posix(paths)==record
    print('reused=true'if a.native_mode else record['status'])

if __name__=='__main__':main()
