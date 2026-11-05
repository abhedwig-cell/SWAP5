"""Remeasure extracted CRC results against independent byte/file oracles."""
import argparse,io,json,struct,tarfile,zipfile,zlib
from pathlib import Path
import crc_family_runtime as policy
ROOT=policy.ROOT;BASE=ROOT/'integration/dataqual15_hupsel';sha=policy.sha

def audit(get,windows):
    r=json.loads(get('RESULT.json'));assert r['status']=='EXACT_EXTRACTED_CRC_FAMILY_COMPONENT_MEASUREMENT_COMPLETE'
    assert r['production_source_changed']is False and r['full_adapter_qualified']is False and r['whole_scientific_admission']is False
    registry=json.loads((ROOT/policy.REGISTER).read_text());names=list(registry['source_sha256'])[:-1];assert len(r['reports'])==10
    shared=(ROOT/'src/adapter/mod_age_joint_restart_file.f90').read_text();failed=[]
    for report,(name,role)in zip(r['reports'],[(n,v)for n in names for v in ('incumbent','candidate')]):
        assert report['source']==name and report['role']==role
        prefix=Path(name).stem+'-'+role+'/';read=lambda n:get(prefix+n);text=(ROOT/name).read_text();has_io='subroutine append_crc('in text
        assert report['has_io']==has_io
        assert read('probe.f90')==policy.wrapper(text,shared if role=='candidate'else None,has_io).encode()
        assert sha(read('probe.f90'))==report['wrapper_sha256']and sha(read('probe.exe'if windows else'probe'))==report['executable_sha256']
        assert '-'+r['optimization']in report['flags']
        events=json.loads(read('EVENTS.json'));assert len(events)==(35 if has_io else 11)and all(e['returncode']==0 for e in events)
        assert list(v['case']for v in report['values'])==list(policy.corpus())
        for v in report['values']:
            raw=read(v['case']+'.payload');assert raw==policy.corpus()[v['case']]and sha(raw)==v['payload_sha256']
            assert zlib.crc32(raw)==v['expected']and v['oracle_pass']==(v['actual']==v['expected'])
            event=next(e for e in events if e['label']=='value-'+v['case']);assert(int(read(event['stdout']))&0xffffffff)==v['actual']
        for row in report['native']:
            raw=read(row['case']+'.payload');disk=read(row['case']+'.native');assert disk[:-4]==raw and sha(disk)==row['native_sha256']
            assert row['expected']==zlib.crc32(raw)and row['stored']==struct.unpack_from('<I',disk,len(disk)-4)[0]
            assert row['own_status']==0 and int(read(next(e for e in events if e['label']=='own-'+row['case'])['stdout']))==0
            for kind,c in row['controls'].items():
                bad=read(row['case']+'-'+kind+'.native');expected=kind=='resealed';assert c['expected_accept']==expected
                correct=len(bad)>=12 and zlib.crc32(bad[:-4])==struct.unpack_from('<I',bad,len(bad)-4)[0]
                assert correct==expected
                event=next(e for e in events if e['label']==kind+'-'+row['case']);assert int(read(event['stdout']))==c['status']
                assert c['oracle_pass']==((c['status']==0)==expected)
        assert len(report['native'])==(4 if has_io else 0)
        actual=all(v['oracle_pass']for v in report['values'])and all(n['stored']==n['expected']and all(c['oracle_pass']for c in n['controls'].values())for n in report['native'])
        assert actual==report['oracle_pass']
        if role=='candidate':assert actual
        elif not actual:failed.append(name)
    return dict(status='EXACT_EXTRACTED_CRC_COMPONENT_AND_NATIVE_IO_ORACLES_REMEASURED',optimization=r['optimization'],incumbent_failed_sources=failed,candidate_all_oracles_pass=True,production_admission=False,full_adapter_qualified=False)

def controls(get,windows):
    prefix='mod_matrix_joint_restart_file-candidate/';refused=[]
    for label,name in (('binary',prefix+('probe.exe'if windows else'probe')),('projection',prefix+'probe.f90'),('native',prefix+'standard.native'),('payload',prefix+'standard.payload'),('promotion','RESULT.json')):
        raw=get(name)
        if label=='promotion':r=json.loads(raw);r['full_adapter_qualified']=True;bad=json.dumps(r).encode()
        else:bad=raw+b'changed'
        try:audit(lambda n:bad if n==name else get(n),windows)
        except(AssertionError,ValueError,KeyError):refused.append(label)
        else:raise AssertionError('accepted evidence mutation '+label)
    return refused

def verify_windows():
    reports={}
    for opt in ('O0','O2'):
        stem='CRC_FAMILY_WINDOWS_20261105_'+opt;r=json.loads((BASE/(stem+'.json')).read_text());raw=(BASE/(stem+'.tar.xz')).read_bytes();assert sha(raw)==r['archive_sha256']
        with tarfile.open(fileobj=io.BytesIO(raw))as t:
            assert len(t.getnames())==len(set(t.getnames()));files={m.name:t.extractfile(m).read()for m in t.getmembers()if m.isfile()}
        assert {n:sha(b)for n,b in files.items()}==r['files_sha256'];get=lambda n:files[n]
        report=dict(audit=audit(get,True),data_refusals=controls(get,True));assert report==r['report'];reports[opt]=report
    return reports

def verify_posix():
    r=json.loads((BASE/'CRC_FAMILY_POSIX_20261105.json').read_text());raw=(BASE/'CRC_FAMILY_POSIX_20261105.zip').read_bytes();assert sha(raw)==r['artifact_zip_sha256'];reports={}
    with zipfile.ZipFile(io.BytesIO(raw))as z:
        assert len(z.namelist())==len(set(z.namelist()))
        for opt in ('O0','O2'):
            get=lambda n:z.read('crc-family-'+opt+'/'+n);reports[opt]=dict(audit=audit(get,False),data_refusals=controls(get,False))
    assert reports==r['report'];return reports

def main():
    p=argparse.ArgumentParser();p.add_argument('--seal',type=Path);p.add_argument('--posix',action='store_true');a=p.parse_args();policy.guard()
    if a.seal:
        for opt in ('O0','O2'):
            root=a.seal/opt;files={p.relative_to(root).as_posix():p.read_bytes()for p in root.rglob('*')if p.is_file()};get=lambda n:files[n];report=dict(audit=audit(get,True),data_refusals=controls(get,True));stem='CRC_FAMILY_WINDOWS_20261105_'+opt;path=BASE/(stem+'.tar.xz')
            with tarfile.open(path,'w:xz')as t:
                for name,b in sorted(files.items()):info=tarfile.TarInfo(name);info.size=len(b);t.addfile(info,io.BytesIO(b))
            (BASE/(stem+'.json')).write_text(json.dumps(dict(archive_sha256=sha(path.read_bytes()),files_sha256={n:sha(b)for n,b in files.items()},report=report),indent=2)+'\n')
    print(verify_windows())
    if a.posix:print(verify_posix())

if __name__=='__main__':main()
