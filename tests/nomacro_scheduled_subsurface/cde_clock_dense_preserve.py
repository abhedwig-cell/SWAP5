"""One actual original dense Snow CDE v1 state at the changed dispatch seam."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
import cde_clock_runtime as current

m=current.m;ROOT=current.ROOT


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-root','evidence-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);p.add_argument('--platform',choices=('Windows','Ubuntu'),default='Windows')
    a=p.parse_args();a.output.mkdir();authority=ROOT/'integration/f-ci/nomacro-complete01/OUTPUT_THERMAL_QUALIFICATION.json';qualification=json.loads(authority.read_text(encoding='utf8'))
    if a.platform=='Windows':
        members={name:value for record in qualification['archives'].values() for name,value in record['members'].items()};source=a.prior_root;relative_root=a.evidence_root
    else:
        assert a.optimization=='O2';members=qualification['archives']['OUTPUT_THERMAL_UBUNTU_O2_RAW_ARCHIVE.json']['members'];source=a.prior_root/'short-chemical-interval-csv3';relative_root=a.prior_root
    q=dict(status='RUNNING',platform=a.platform,optimization=a.optimization,authority_sha256=m.sha(authority),profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def qualified(path):assert hashlib.sha256(path.read_bytes()).hexdigest()==members[path.relative_to(relative_root).as_posix()],path
    save()
    try:
        for name in ('RESULT.json','build/BUILD.json','trajectory/daily.jsonl'):qualified(source/name)
        kind='chemical-snow-point' if a.platform=='Windows' and a.optimization=='O0' else 'chemical-snow-interval';out=a.output/'dense-cde-snow';inputs=source/'input'
        command=[sys.executable,'-B',str(Path(__file__).with_name('output_thermal_runtime.py')),'--reference-work',a.reference_work,'--output',out,'--optimization',a.optimization,'--kind',kind,'--format',3,'--existing-input',inputs]
        subprocess.run(list(map(str,command)),cwd=ROOT,check=True,timeout=300);report=json.loads((out/'RESULT.json').read_text(encoding='utf8'));assert 'PASS' in report['status']
        project=m.e.load(inputs,original_output=True);actual,_=m.validate_bundle(out/'build',a.reference_work,project);old=json.loads((source/'build/BUILD.json').read_text(encoding='utf8'))
        assert actual['project']==old['project'] and actual['inputs']==old['inputs']
        for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','original_output','lower_boundary_receipt','frost_reference'):
            assert actual['identity'].get(field)==old['identity'].get(field),field
        assert m.physical(m.rows(out/'trajectory'))==m.physical(m.rows(source/'trajectory'))
        for day in (2,4,8,35):
            native=source/f'trajectory/accepted-column-1-day-{day}.zip';qualified(native)
            with zipfile.ZipFile(native) as x,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as y:
                for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(day,name)
        q['profiles']['dense-cde-snow']=dict(actual_build=actual,prior_build_sha256=m.sha(source/'build/BUILD.json'),prior_root=str(source),all_physical_exact=True,all_physical_generated_sources_exact=True,four_complete_native_payloads_exact=True,actual_immutable_prior_member_hashes=True,trajectory=report['trajectory'],own=report['own'])
        q['status']='ONE_ACTUAL_ADMITTED_DENSE_SNOW_CDE_SOURCE_NATIVE_CONTEXT_EXACT_PASS';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
