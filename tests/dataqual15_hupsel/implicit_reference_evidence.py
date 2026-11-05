"""Real implicit-reference histories and unchanged-bound screen, no promotion."""
import argparse,copy,io,json,tarfile,tempfile
from pathlib import Path
import implicit_reference as run
ROOT=run.ROOT;BASE=run.BASE;sha=run.sha;STEM='IMPLICIT_REFERENCE_EVIDENCE_20261105'

def dependencies():
    d=run.inherited.dependencies()
    for n in ('implicit_reference.py','implicit_reference_evidence.py','test_implicit_reference.py','original_oxygen_k_jacobian.py','original_reference_balance_control.py','original_k_jacobian_check.py'):
        p='tests/dataqual15_hupsel/'+n;d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    for p in ('integration/dataqual15_hupsel/'+run.REG,'.github/workflows/hupsel-implicit-reference.yml'):d[p]=sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))
    return d

def controls(files,parent,cap,binding):
    results=[]
    def edit(f,name,fn):
        d=json.loads(f[name]);fn(d);f[name]=(json.dumps(d)+'\n').encode()
    def reseal(f,name):edit(f,'RESULT.json',lambda d:d['outputs_sha256'].__setitem__(name,sha(f['case/'+name])))
    for label in ('foreign_seed','executable','unselected_cap','changed_physical_input','censored','missing_day','nonfinite_oxygen','profile_geometry','profile_stock','promoted_registration'):
        f=dict(files)
        if label=='foreign_seed':edit(f,'START.json',lambda d:d.__setitem__('checkpoint_seed','foreign.bin'))
        elif label=='executable':edit(f,'START.json',lambda d:d.__setitem__('reference_executable_sha256','0'*64))
        elif label=='unselected_cap':edit(f,'START.json',lambda d:d.__setitem__('cap',next(x for x in run.CAPS if x!=cap)))
        elif label=='changed_physical_input':
            f['case/potato.crp']+=b'\n';edit(f,'START.json',lambda d:d['inputs_sha256'].__setitem__('potato.crp',sha(f['case/potato.crp'])))
        elif label=='censored':edit(f,'RESULT.json',lambda d:d.__setitem__('status','CENSORED'))
        elif label=='missing_day':f['case/result_output.csv']=b'\n'.join(f['case/result_output.csv'].splitlines()[:-1])+b'\n';reseal(f,'result_output.csv')
        elif label=='nonfinite_oxygen':
            rows=run.csv_rows(f['case/result_output.csv']);headers=list(rows[0]);lines=f['case/result_output.csv'].splitlines();idx=next(i for i,l in enumerate(lines)if l.startswith(b'2003-08-07,'));parts=lines[idx].split(b',');parts[headers.index('TREDWET')]=b'NaN';lines[idx]=b','.join(parts);f['case/result_output.csv']=b'\n'.join(lines)+b'\n';reseal(f,'result_output.csv')
        elif label in ('profile_geometry','profile_stock'):
            lines=f['case/hupsel_profiles.csv'].splitlines();parts=lines[-1].split(b',');parts[3 if label=='profile_geometry'else 5]=b'0.9';lines[-1]=b','.join(parts);f['case/hupsel_profiles.csv']=b'\n'.join(lines)+b'\n';reseal(f,'hupsel_profiles.csv')
        else:edit(f,'START.json',lambda d:d['registration'].__setitem__('production_admission',True))
        try:run.audit(f,parent,cap,binding)
        except(AssertionError,ValueError,KeyError):results.append(label)
        else:raise AssertionError('accepted implicit reference defect '+label)
    return results

def qualify(files):
    parent,_=run.inherited.original();initial,exe,binding=run.source_control(parent);reports={};levels=[run.csv_rows(parent['reference-implicit-balanced/case/result_output.csv'])]
    for cap,name in zip(run.CAPS,('half','quarter')):
        f={n.removeprefix(name+'/'):b for n,b in files.items()if n.startswith(name+'/')};report,daily=run.audit(f,parent,cap,binding);assert report==json.loads(f['AUDIT.json']);report['rejected_actual_data_controls']=controls(f,parent,cap,binding);reports[name]=report;levels.append(daily)
    return dict(status='ACTUAL_STRICT_IMPLICIT_REFERENCE_FAMILY_SCREEN_QUALIFIED_NOT_ORACLE_ADMISSION',source_binding=binding,cases=reports,screen=run.screen(levels),production_admission=False,whole_scientific_admission=False,original_oracle_replaced=False,migration_complete=False)

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--capture',type=Path);a=p.parse_args()
    if a.capture:
        root=a.capture.resolve();files={name+'/'+p.relative_to(root/name).as_posix():p.read_bytes()for name in ('half','quarter')for p in(root/name).rglob('*')if p.is_file()};result=qualify(files);path=BASE/(STEM+'.tar.xz')
        with tarfile.open(path,'w:xz',preset=3)as t:
            for n,b in sorted(files.items()):m=tarfile.TarInfo(n);m.size=len(b);t.addfile(m,io.BytesIO(b))
        record=dict(result=result,archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},qualification_dependencies=dependencies(),production_admission=False,whole_scientific_admission=False,original_oracle_replaced=False);(BASE/(STEM+'.json')).write_text(json.dumps(record,indent=2)+'\n')
    else:
        record=json.loads((BASE/(STEM+'.json')).read_text());assert record['qualification_dependencies']==dependencies()and all(record[k]is False for k in ('production_admission','whole_scientific_admission','original_oracle_replaced'))
        raw=(BASE/(STEM+'.tar.xz')).read_bytes();assert sha(raw)==record['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:
            members=t.getmembers();assert all(m.isfile()and run.inherited.current.run.parent.prior.safe(m.name)for m in members);files={m.name:t.extractfile(m).read()for m in members}
        assert len(files)==len(members)and set(files)==set(record['files_sha256'])and all(sha(b)==record['files_sha256'][n]for n,b in files.items());result=qualify(files);assert result==record['result']
    print(result['status']);print(json.dumps(result['screen']))

if __name__=='__main__':main()
