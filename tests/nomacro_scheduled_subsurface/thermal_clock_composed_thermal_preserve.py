"""Fresh inactive-groundwater preservation of actual admitted thermal sources."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import output_thermal_runtime as prior

m=prior.m


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','evidence-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    args=parser.parse_args();args.output.mkdir();e=args.evidence_root
    authority=prior.ROOT/'integration/f-ci/nomacro-complete01/OUTPUT_THERMAL_QUALIFICATION.json'
    old=json.loads(authority.read_text(encoding='utf8'))
    members={path:digest for record in old['archives'].values() for path,digest in record['members'].items()}
    def qualified(path):
        name=path.relative_to(e).as_posix()
        assert hashlib.sha256(path.read_bytes()).hexdigest()==members[name],name
    cases=[('water-hys2',3,f'output-thermal-pilot-{args.optimization}-v2'),
           ('chemical-snow-point',3,'output-thermal-fixed-O0-v2' if args.optimization=='O0' else 'output-thermal-fixed-O2-v2'),
           ('water-frost-free',1,f'output-thermal-water-frost-free-{args.optimization}-v1'),
           ('water-frost-drained',1,f'output-thermal-water-frost-drained-{args.optimization}-v1')]
    if args.optimization=='O2':cases[1]=('chemical-snow-interval',3,'output-thermal-fixed-O2-v2')
    record=dict(status='RUNNING',optimization=args.optimization,authority_sha256=m.sha(authority),profiles={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for kind,fmt,stem in cases:
            source=e/stem;qualified(source/'RESULT.json');qualified(source/'build/BUILD.json');qualified(source/'trajectory/daily.jsonl')
            oldreport=json.loads((source/'RESULT.json').read_text());out=args.output/kind
            project=m.e.load(source/'input',original_output=True,time_step_policy='original-adaptive-event-closure-v1' if kind=='water-frost-drained' else 'original-adaptive-day-seed-v1')
            command=[sys.executable,'-B',str(Path(__file__).with_name('output_thermal_runtime.py')),'--reference-work',args.reference_work,
                     '--output',out,'--optimization',args.optimization,'--kind',kind,'--format',fmt,'--existing-input',source/'input']
            subprocess.run(list(map(str,command)),cwd=prior.ROOT,check=True,timeout=300)
            report=json.loads((out/'RESULT.json').read_text());assert report['status']==oldreport['status']
            actual,_=m.validate_bundle(out/'build',args.reference_work,project);previous=json.loads((source/'build/BUILD.json').read_text())
            current_project=dict(actual['project'])
            assert project.water_polish_policy==m.h.ALWAYS_WATER_POLISH
            assert 'water_polish_policy' not in previous['project'] and 'water_polish_policy' not in previous['identity']
            assert actual['identity']['water_polish_policy']==m.h.ALWAYS_WATER_POLISH
            assert current_project==previous['project'] and actual['inputs']==previous['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','original_output','lower_boundary_receipt','frost_reference'):
                assert actual['identity'].get(field)==previous['identity'].get(field),(kind,field)
            assert m.physical(m.rows(out/'trajectory'))==m.physical(m.rows(source/'trajectory'))
            for day in (2,4,8,35):
                oldzip=source/f'trajectory/accepted-column-1-day-{day}.zip';qualified(oldzip)
                with zipfile.ZipFile(oldzip) as a,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as b:
                    for native in ('result.end','macro.bin'):assert a.read(native)==b.read(native),(kind,day,native)
            record['profiles'][kind]=dict(actual_build=actual,prior_build_sha256=m.sha(source/'build/BUILD.json'),prior_root=str(source),
                all_physical_exact=True,four_complete_native_payloads_exact=True,all_physical_generated_sources_exact=True,
                original_snow_heat_frost_unchanged=True,actual_immutable_prior_member_hashes=True,trajectory=report['trajectory'],own=report['own'])
            save();print(kind,args.optimization,'ACTUAL_PRIOR_THERMAL_SOURCE_NATIVE_EXACT',flush=True)
        record['status']='FOUR_CURRENT_THERMAL_CDE_WATER_FROST_SOURCE_NATIVE_CONTEXTS_EXACT_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
