"""Fresh named canonical SaltFarm policy under the inactive Snow dispatch."""
import argparse,json,subprocess,sys,zipfile,io,hashlib,time
from pathlib import Path
import thermal_clock_runtime as current

m=current.m;ROOT=current.ROOT

def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),default='Windows')
    a=p.parse_args();a.output.mkdir();project=m.h.SALTFARM
    authority=ROOT/'integration/f-ci/saltfarm-newton-work01/PORTABLE.json'
    q=json.loads(authority.read_text(encoding='utf8'));record=q['archives'][a.platform]
    raw=(authority.parent/record['file']).read_bytes()
    assert hashlib.sha256(raw).hexdigest()==record['sha256'] and len(raw)==record['bytes']
    z=zipfile.ZipFile(io.BytesIO(raw));prefix='accept-'+a.optimization
    old=json.loads(z.read('qualified-'+a.optimization+'/BUILD.json'))
    report=dict(status='RUNNING',profiles={},platform=a.platform,optimization=a.optimization,
        authority_sha256=m.sha(authority),actual_prior_raw_sha256=record['sha256'])
    def save():(a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf8')
    save()
    try:
        out=a.output/'saltfarm';out.mkdir();build=out/'build'
        command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--no-macro-release',
            '--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
        start=time.perf_counter();r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/'build.stdout').write_text(r.stdout,encoding='utf8');(out/'build.stderr').write_text(r.stderr,encoding='utf8');r.check_returncode()
        meta,_=m.validate_bundle(build,a.reference_work,project)
        assert meta['project']==old['project'] and meta['inputs']==old['inputs']
        assert meta['identity']['water_polish_policy']==old['identity']['water_polish_policy']==m.h.INTERIOR_WATER_POLISH
        for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources'):
            assert meta['identity'].get(field)==old['identity'].get(field),field
        build_seconds=time.perf_counter()-start
        command=[sys.executable,'-B',str(ROOT/'tests/saltfarm_newton/qualify.py'),'--bundle',build,'--reference',a.reference_work,'--output',out/'accept']
        r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180)
        (out/'qualify.stdout').write_text(r.stdout,encoding='utf8');(out/'qualify.stderr').write_text(r.stderr,encoding='utf8');r.check_returncode()
        result=json.loads((out/'accept/RESULT.json').read_text())
        previous=[json.loads(line) for line in z.read(prefix+'/full/daily.jsonl').splitlines()]
        actual=m.rows(out/'accept/full');m.check(actual)
        assert result['status']=='FULL_PASS' and result['days']==1461 and m.physical(actual)==m.physical(previous)
        from original_output_files import records
        actual_csv=records(out/'accept/full/original/result_output.csv')
        old_csv=[line.strip() for line in z.read(prefix+'/full/original/result_output.csv').decode('cp1252').splitlines() if line[:4].isdigit()]
        assert actual_csv==old_csv
        for day in (109,111,365,367,453,455,1460,1461):
            with zipfile.ZipFile(io.BytesIO(z.read(prefix+f'/full/accepted-column-1-day-{day}.zip'))) as oldzip,zipfile.ZipFile(out/f'accept/full/accepted-column-1-day-{day}.zip') as newzip:
                for member in ('result.end','macro.bin'):assert oldzip.read(member)==newzip.read(member),(day,member)
        assert len(result['restarts'])==5 and all(x['exact_native'] and x['exact_physical'] and x['exact_csv'] for x in result['restarts'])
        report['profiles']['saltfarm']=dict(actual_build=meta,prior_build_sha256=hashlib.sha256(z.read('qualified-'+a.optimization+'/BUILD.json')).hexdigest(),
            all1461_physical_days_exact=True,all_original_user_records_exact=True,eight_complete_native_payloads_exact=True,
            all_physical_generated_sources_exact=True,named_interior_policy_unchanged=True,five_own_cold_windows_exact=True,
            build_seconds=build_seconds,trajectory=result)
        report['status']='ACTUAL_CANONICAL_SALTFARM_POLICY_FULL_SOURCE_NATIVE_USER_EXACT_PASS'
        print(a.platform,a.optimization,report['status'],flush=True)
    except Exception as error:report.update(status='FAILED',error=repr(error));raise
    finally:save()

if __name__=='__main__':main()
