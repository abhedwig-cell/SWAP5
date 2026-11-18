"""Four actual prior Ubuntu thermal contexts at the changed CDE dispatch seam."""
import argparse,hashlib,json,subprocess,sys,zipfile
from pathlib import Path
import cde_interval_runtime as current

m=current.m;ROOT=current.ROOT


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();authority=ROOT/'integration/f-ci/nomacro-complete01/OUTPUT_THERMAL_QUALIFICATION.json'
    qualification=json.loads(authority.read_text(encoding='utf8'))
    members=qualification['archives']['OUTPUT_THERMAL_UBUNTU_O2_RAW_ARCHIVE.json']['members']
    q=dict(status='RUNNING',optimization='O2',platform='Ubuntu',authority_sha256=m.sha(authority),profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf8')
    def qualified(path):assert hashlib.sha256(path.read_bytes()).hexdigest()==members[path.relative_to(a.prior_root).as_posix()],path
    save()
    try:
        for kind,key,fmt in [('water-hys2','water-hys2-csv3',3),('chemical-snow-interval','chemical-interval-csv3',3),('water-frost-free','frost-free-csv1',1),('water-frost-drained','frost-drained-csv1',1)]:
            source=a.prior_root/('short-'+key)
            for part in ('RESULT.json','build/BUILD.json','trajectory/daily.jsonl'):qualified(source/part)
            inputs=source/'input';out=a.output/kind
            project=m.e.load(inputs,original_output=True,time_step_policy='original-adaptive-event-closure-v1' if kind=='water-frost-drained' else 'original-adaptive-day-seed-v1')
            command=[sys.executable,'-B',str(Path(__file__).with_name('output_thermal_runtime.py')),'--reference-work',a.reference_work,'--output',out,'--optimization','O2','--kind',kind,'--format',fmt,'--existing-input',inputs]
            subprocess.run(list(map(str,command)),cwd=ROOT,check=True,timeout=300)
            report=json.loads((out/'RESULT.json').read_text(encoding='utf8'));old=json.loads((source/'RESULT.json').read_text(encoding='utf8'));assert report['status']==old['status']
            actual,_=m.validate_bundle(out/'build',a.reference_work,project);previous=json.loads((source/'build/BUILD.json').read_text(encoding='utf8'))
            assert actual['project']==previous['project'] and actual['inputs']==previous['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','original_output','lower_boundary_receipt','frost_reference'):
                assert actual['identity'].get(field)==previous['identity'].get(field),(kind,field)
            assert m.physical(m.rows(out/'trajectory'))==m.physical(m.rows(source/'trajectory'))
            for day in (2,4,8,35):
                oldzip=source/f'trajectory/accepted-column-1-day-{day}.zip';qualified(oldzip)
                with zipfile.ZipFile(oldzip) as x,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as y:
                    for name in ('result.end','macro.bin'):assert x.read(name)==y.read(name),(kind,day,name)
            q['profiles'][kind]=dict(actual_build=actual,prior_build_sha256=m.sha(source/'build/BUILD.json'),prior_root=str(source),all_physical_exact=True,four_complete_native_payloads_exact=True,all_physical_generated_sources_exact=True,actual_immutable_prior_member_hashes=True,trajectory=report['trajectory'],own=report['own']);save();print(kind,'UBUNTU_PRIOR_THERMAL_SOURCE_NATIVE_EXACT',flush=True)
        q['status']='FOUR_CURRENT_THERMAL_CDE_WATER_FROST_SOURCE_NATIVE_CONTEXTS_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
