"""Exact CRC successor; all prior admission bodies execute unmodified."""
import argparse,json,os,shutil,subprocess,sys,tempfile
from pathlib import Path
import production_crop_logical_admission as previous
ROOT=previous.ROOT;git=previous.git;blob=previous.blob;sha=previous.sha
BASE='5921f7dc89871e68e394302a2c62958b691699ac'
SOURCE='src/adapter/mod_crop_soil_n_joint_restart_file.f90'
ENTRY=previous.ENTRY;STATUS=previous.STATUS;KEY='native_rotation_crc_successor_20261105'
SCOPE='integration/dataqual15_hupsel/ROTATION_NATIVE_SCOPE_20261105.json'
BRIDGE=('.github/workflows/hupsel-production-diagnostic.yml','.github/workflows/hupsel-production-crop-logical.yml','tools/vq/select_grass_sprint.py','tests/dataqual15_hupsel/test_grass_sprint_selection.py')
GATES=('integration/dataqual15_hupsel/ROTATION_NATIVE_CRC_FAILED_OBSERVATIONS_20261105.json','integration/dataqual15_hupsel/ROTATION_NATIVE_CRC_PREREGISTRATION_20261105.json','tests/dataqual15_hupsel/native_crop_adapter_runtime.py','tests/dataqual15_hupsel/native_crop_adapter_fixture.py','tests/dataqual15_hupsel/native_crop_weather_runtime.py','tests/mc-irr01/tcs6_native_controls.py','tests/support/augment_bartholomeus_backend_sources.py',ENTRY,'tests/dataqual15_hupsel/rotation_native_admission.py','tests/dataqual15_hupsel/rotation_native_runtime.py','tests/dataqual15_hupsel/rotation_native_evidence.py','tests/dataqual15_hupsel/test_rotation_native.py','.github/workflows/hupsel-rotation-native.yml',*BRIDGE)

def postimage():
    old=subprocess.check_output(['git','show',BASE+':'+SOURCE],cwd=ROOT).decode()
    start=old.index('  function crc32(bytes) result(crc)');end=old.index('  end function',start)+len('  end function\n')
    assert old[start:end].count('function crc32')==1
    body=old[:start]+old[end:]
    marker='  use iso_fortran_env,only:real64,int64,int32,int8,iostat_end\n'
    assert body.count(marker)==1
    return body.replace(marker,marker+'  use mod_age_joint_restart_file,only:crc32\n',1)

def owned(raw):
    r=json.loads(raw)
    return {k:r.get(k)for k in ('native_disk_restart_20261102','project_diagnostic_restart_successor_20261104','native_crop_logical_successor_20261105',KEY)}

def guard(r):
    assert r['predecessor']==BASE and r['whole_scientific_admission']is False
    assert r['scope']=='CURRENT_NATIVE_ROTATION_AND_WEATHER_CRC32_ISO_HDLC_ONLY'
    assert set(r['production_delta'])=={SOURCE}and set(r['bridge_restore'])=={SOURCE,ENTRY,STATUS,*BRIDGE}
    assert set(r['gate_source_sha256'])==set(GATES)
    subprocess.run(['git','merge-base','--is-ancestor',BASE,'HEAD'],cwd=ROOT,check=True,capture_output=True)
    assert set(git('diff','--name-only','--no-renames',BASE,'HEAD','--','src','app','reference').splitlines())=={SOURCE}
    assert not git('diff','HEAD','--','src','app','reference')and not git('ls-files','--others','--exclude-standard','--','src','app','reference')
    assert {a:blob(BASE,a)for a in ('src','app','reference')}==r['predecessor_production_trees']
    assert {a:blob('HEAD',a)for a in ('app','reference')}==r['unchanged_trees']
    for path,pins in r['bridge_restore'].items():
        assert blob(BASE,path)==pins['before']
        if path==STATUS:
            before=owned(subprocess.check_output(['git','show',BASE+':'+STATUS],cwd=ROOT));after=owned(subprocess.check_output(['git','show',pins['after']],cwd=ROOT))
            assert {k:v for k,v in after.items()if k!=KEY}=={k:v for k,v in before.items()if k!=KEY}
            assert after[KEY]=={'scope':SCOPE}
            assert owned((ROOT/STATUS).read_bytes())==owned(subprocess.check_output(['git','show','HEAD:'+STATUS],cwd=ROOT))==after
        else:
            assert blob('HEAD',path)==pins['after']
            assert(ROOT/path).read_bytes().replace(b'\r\n',b'\n')==subprocess.check_output(['git','show','HEAD:'+path],cwd=ROOT)
    assert r['production_delta'][SOURCE]==r['bridge_restore'][SOURCE]
    assert(ROOT/SOURCE).read_bytes().replace(b'\r\n',b'\n')==postimage().encode()
    assert sha(postimage().encode())==r['postimage_sha256']
    assert all(sha((ROOT/p).read_bytes().replace(b'\r\n',b'\n'))==h for p,h in r['gate_source_sha256'].items())

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--prepare-only',action='store_true');a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True)
    r=json.loads((ROOT/SCOPE).read_text());guard(r)
    if a.prepare_only:
        view,proof=previous.prepare(r,out);(out/'PREPARED.json').write_text(json.dumps(proof,indent=2)+'\n');print(view);return
    import rotation_native_evidence as evidence
    current=dict(windows=evidence.verify_windows())
    if r['phase']=='QUALIFIED_CURRENT_WINDOWS_AND_POSIX':current['posix']=evidence.verify_posix()
    else:assert r['phase']=='QUALIFIED_CURRENT_WINDOWS_POSIX_PENDING'
    work=Path(tempfile.mkdtemp(prefix='s5rc-')).resolve()if os.name=='nt'else out
    view,projection=previous.prepare(r,work)
    try:
        run=subprocess.run([sys.executable,'-B',ENTRY,'--output',str(work/'old-admission')],cwd=view,env=previous.predecessor.process_env(dict(os.environ,PYTHONUTF8='1')),capture_output=True)
        (out/'old-admission.stdout').write_bytes(run.stdout);(out/'old-admission.stderr').write_bytes(run.stderr)
        assert run.returncode==0,run.stderr[-3000:]
        guard(r)
        (out/'RESULT.json').write_text(json.dumps(dict(status='CURRENT_CRC_LIFECYCLE_WEATHER_AND_UNMODIFIED_PREDECESSOR_PASS',current=current,projection=projection,old_admission_returncode=run.returncode,whole_scientific_admission=False),indent=2)+'\n')
        print('CURRENT_CRC_LIFECYCLE_WEATHER_AND_UNMODIFIED_PREDECESSOR_PASS')
    finally:
        subprocess.run(['git','worktree','remove',str(view)],cwd=ROOT,env=previous.predecessor.process_env(),check=True,capture_output=True)
        if work!=out:
            assert work.parent==Path(tempfile.gettempdir()).resolve()and work.name.startswith('s5rc-');shutil.rmtree(work)

if __name__=='__main__':main()
