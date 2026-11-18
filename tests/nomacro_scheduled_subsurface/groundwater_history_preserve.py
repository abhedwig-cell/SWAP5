"""Fresh ordinary GWC source/native preservation at the new history dispatch seam."""
import argparse
import hashlib
import json
from pathlib import Path,PurePosixPath
import subprocess
import sys
import zipfile
import groundwater_chemical_runtime as previous

m=previous.m;ROOT=previous.ROOT
CASES={'within-csv3':('within',3,()),'below-csv1':('below',1,()),
       'crossing-default':('crossing',1,('--compatibility-output',)),
       'crossing-boundaries':('crossing',3,('--source-boundaries',)),
       'crossing-sorption-decay':('crossing',2,('--chemistry',))}


def main():
    parser=argparse.ArgumentParser()
    for key in ('reference-work','prior-root','evidence-root','output'):parser.add_argument('--'+key,type=Path,required=True)
    parser.add_argument('--optimization',choices=('O0','O2'),required=True)
    parser.add_argument('--platform',choices=('Windows','Ubuntu'),default='Windows')
    args=parser.parse_args();args.output.mkdir();old=json.loads((args.prior_root/'RESULT.json').read_text())
    authority=ROOT/'integration/f-ci/nomacro-complete01/GROUNDWATER_CHEMICAL_QUALIFICATION.json';qualified=json.loads(authority.read_text(encoding='utf8'))
    members={path:value for name,record in qualified['archives'].items() if name==f'GROUNDWATER_CHEMICAL_{args.platform.upper()}_{args.optimization}_RAW_ARCHIVE.json' for path,value in record['members'].items()}
    def check_source(path):
        name=path.relative_to(args.evidence_root if args.platform=='Windows' else args.prior_root).as_posix();assert hashlib.sha256(path.read_bytes()).hexdigest()==members[name],name
    def actual(path):
        if args.platform=='Windows':return Path(path)
        base=PurePosixPath(old['cases']['within-csv3']['short_root']).parent
        return args.prior_root/PurePosixPath(path).relative_to(base)
    record=dict(status='RUNNING',optimization=args.optimization,authority_sha256=m.sha(authority),profiles={})
    def save():(args.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n',encoding='utf8')
    save()
    try:
        for key,(kind,fmt,extra) in CASES.items():
            item=old['cases'][key];oldbuild=actual(item['build_root']);oldshort=actual(item['short_root']);inputs=actual(item['input_root'])
            check_source(oldbuild/'BUILD.json');check_source(oldshort/'RESULT.json');check_source(oldshort/'trajectory/daily.jsonl')
            out=args.output/key
            command=[sys.executable,'-B',str(Path(__file__).with_name('groundwater_chemical_runtime.py')),'--reference-work',args.reference_work,
                '--output',out,'--existing-input',inputs,'--kind',kind,'--format',fmt,'--optimization',args.optimization,*extra]
            subprocess.run(list(map(str,command)),cwd=ROOT,check=True,timeout=300)
            project=m.e.load(inputs,original_output='--compatibility-output' not in extra)
            actual,_=m.validate_bundle(out/'build',args.reference_work,project);prior=json.loads((oldbuild/'BUILD.json').read_text())
            assert actual['project']==prior['project'] and actual['inputs']==prior['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library',
                          'kernel_sources','original_output','lower_boundary_receipt','groundwater_native_state','cde_native_receipt'):
                assert actual['identity'].get(field)==prior['identity'].get(field),(key,field)
            data=m.rows(out/'trajectory');assert m.physical(data)==m.physical(m.rows(oldshort/'trajectory'))
            for day in (2,4,7,9,10):
                source=oldshort/f'trajectory/accepted-column-1-day-{day}.zip';check_source(source)
                with zipfile.ZipFile(source) as a,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as b:
                    for native in ('result.end','macro.bin'):assert a.read(native)==b.read(native),(key,day,native)
            report=json.loads((out/'RESULT.json').read_text());assert report['status']=='ACTUAL_PRESCRIBED_GROUNDWATER_CDE_SHORT_NATIVE_USER_FILES_PASS'
            record['profiles'][key]=dict(actual_build=actual,prior_build_sha256=m.sha(oldbuild/'BUILD.json'),
                actual_immutable_prior_member_hashes=True,all_emitted_sources_exact=True,all_physical_exact=True,
                five_complete_native_payloads_exact=True,ordinary_native_metadata_literal=True,trajectory=report['trajectory'],cold=report['cold'])
            save();print(key,args.optimization,'ORDINARY_GROUNDWATER_LITERAL_SOURCE_NATIVE_EXACT',flush=True)
        record['status']='FIVE_ADMITTED_ORDINARY_GROUNDWATER_SOURCE_NATIVE_CONTEXTS_EXACT_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
