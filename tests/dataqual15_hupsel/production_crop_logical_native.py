"""Actual current production builds, native rejection and old-encoder controls."""
import argparse,json,os,shutil,subprocess,sys,tarfile,types,zipfile
from pathlib import Path
import production_crop_logical_admission as authority
import native_crop_adapter_runtime as weather
import native_crop_weather_runtime as actual_weather
import production_diagnostic_native as native
from production_diagnostic_guards import qualify as owner_controls
from native_crop_bool_runtime import mutations
from native_crop_opaque_writer import qualify as writer_faults
ROOT=authority.ROOT;BASE=ROOT/'integration/dataqual15_hupsel'

def mature(bundle,inputs,out,opt):
    out.mkdir();current=json.loads((bundle/'BUILD.json').read_text())
    if os.name=='nt':
        r=json.loads((BASE/'NATIVE_CROP_OPAQUE_WINDOWS_20261105.json').read_text());archive=BASE/'NATIVE_CROP_OPAQUE_WINDOWS_20261105.tar.xz'
        assert native.sha(archive)==r['archive_sha256']
        with tarfile.open(archive)as t:
            name=opt+'/mature-owner-controls/valid-original.bin';raw=t.extractfile(name).read();assert authority.sha(raw)==r['files_sha256'][name]
            (out/'checkpoint.bin').write_bytes(raw)
            for leaf in ('input.nml','swap.swp','maize.crp','potato.crp','grass.crp','283.met','swap.dra'):
                name=opt+'/mature-owner-controls/black_age_nan/'+leaf;raw=t.extractfile(name).read();assert authority.sha(raw)==r['files_sha256'][name]
                (out/leaf).write_bytes(raw)
    else:
        r=json.loads((BASE/'DEFAULT_DIAGNOSTIC_POSIX_20261104.json').read_text());archive=BASE/'DEFAULT_DIAGNOSTIC_POSIX_20261104.zip'
        assert native.sha(archive)==r['artifact_zip_sha256']
        with zipfile.ZipFile(archive)as z:
            old=json.loads(z.read('build-'+opt+'/BUILD.json'));assert old['compiler']==current['compiler']
            clean=lambda flags:[x for x in flags if not x.startswith(('-I','-J'))]
            assert clean(old['flags'])==clean(current['flags'])
            for name,digest in old['source_sha256'].items():
                relative=next((area+'/'+name.split('/'+area+'/',1)[1]for area in ('src','app')if '/'+area+'/'in name),None)
                if relative:assert authority.sha(subprocess.check_output(['git','show',authority.BASELINE+':'+relative],cwd=ROOT))==digest,relative
            prefix='measurement-'+opt+'/uninterrupted525/'
            for name in z.namelist():
                if name.startswith(prefix)and not name.endswith('/'):
                    leaf=name[len(prefix):];assert Path(leaf).name==leaf
                    (out/leaf).write_bytes(z.read(name))
    (out/'COMPATIBILITY_SCOPE.json').write_text(json.dumps(dict(scope='NONADVANCING_SAME_PLATFORM_PRIOR_BUILD_OWNER_CONTROLS_ONLY',archive_sha256=native.sha(archive),numeric_state_advanced=False),indent=2)+'\n')
    return out

def project(out,compiler,opt):
    out.mkdir();bundle=out/'build'
    subprocess.run([sys.executable,'-B',str(ROOT/'tests/dataqual15_hupsel/build_and_run.py'),'--compiler',str(compiler),'--optimization',opt,'--output',str(bundle),'--end','2'],cwd=ROOT,check=True)
    from film_runtime import inputs as materialize
    inputs=materialize(out/'inputs');exe=bundle/('swap5_hupsel_germination.exe'if os.name=='nt'else'swap5_hupsel_germination')
    probe=native.writer_build(bundle,out/'writer-build',compiler,windows=False)
    native.measure(exe,probe,inputs,out/'own-runtime');case=out/'own-runtime/continuous2'
    native.app_refusals(exe,case,out/'app-refusals');mutations(exe,case,out/'logical-refusals')
    prior=mature(bundle,inputs,out/'mature',opt);owner_controls(bundle,prior,prior/'checkpoint.bin',out/'owner-controls')
    writer_faults(bundle,inputs,out/'fault-writer',compiler)
    (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_CURRENT_PRODUCTION_HUPSEL_OWN_NATIVE_37_OWNER_12_SCALAR_32_WRITER_FAULTS_PASS',optimization=opt,whole_scientific_admission=False),indent=2)+'\n')

def shared(out,compiler,opt):
    providers,external,drivers,inputs=weather.prepare(out);drivers={n:p for n,p in drivers.items()if n in ('w','m')}
    original=weather.policy;old=authority.old_source()
    try:
        weather.policy=types.SimpleNamespace(SOURCE=authority.SOURCE,candidate=lambda current:old)
        weather.build(out/'old-control',compiler,opt,providers,external,drivers,out/'fixture',True)
    finally:weather.policy=original
    weather.build(out/'current',compiler,opt,providers,external,drivers,out/'fixture',False)
    suffix='.exe'if os.name=='nt'else''
    for role in ('old-control','current'):
        folder=out/role;actual_weather.verify_build(folder)
        actual_weather.execute({n:folder/(n+suffix)for n in ('w','m')},out/'fixture',folder,opt)
        actual_weather.verify_build(folder)
    names=[f'schema-{mode}-{j}.bin'for mode in range(4)for j in range(2)]+['w'+suffix+'.'+phase+'.'+kind for phase in ('morning','dayend')for kind in ('full','opaque','resumed','active.resumed')]
    assert all((out/'old-control'/n).read_bytes()==(out/'current'/n).read_bytes()for n in names)
    assert all(weather.sha(ROOT/p)==digest for p,digest in inputs.items())
    (out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_CURRENT_PRODUCTION_WEATHER_AND_EXACT_OLD_ENCODER_BYTE_CONTROLS_PASS',optimization=opt,byte_exact_files={n:weather.sha(out/'current'/n)for n in names},rotation_qualified=False,whole_scientific_admission=False),indent=2)+'\n')

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--compiler',type=Path,required=True);p.add_argument('--optimization',choices=['O0','O2'],required=True);a=p.parse_args()
    r=json.loads((ROOT/authority.SCOPE).read_text());authority.guard(r)
    out=a.output.resolve();out.mkdir();os.environ['OMP_NUM_THREADS']='1';os.environ.pop('SWAP5_DIAG_PREDECESSOR',None)
    project(out/'hupsel',a.compiler.resolve(),a.optimization);shared(out/'weather',a.compiler.resolve(),a.optimization)
    authority.guard(r);(out/'RESULT.json').write_text(json.dumps(dict(status='ACTUAL_CURRENT_PRODUCTION_CROP_LOGICAL_HUPSEL_WEATHER_PASS',optimization=a.optimization,postimage_sha256=r['postimage_sha256'],whole_scientific_admission=False),indent=2)+'\n')
    print('ACTUAL_CURRENT_PRODUCTION_CROP_LOGICAL_NATIVE_PASS',a.optimization)

if __name__=='__main__':main()
