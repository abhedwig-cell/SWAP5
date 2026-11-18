"""Fresh inactive-thermal source/native preservation against actual aquifer archives."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile
import output_aquifer_runtime as previous
from output_aquifer_ci import CONTROLS
from output_aquifer_controls import transactions,fabricated_receipts

m=previous.m;ROOT=previous.ROOT


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','evidence-root','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true');a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    authority=ROOT/'integration/f-ci/nomacro-complete01/OUTPUT_AQUIFER_QUALIFICATION.json';old=json.loads(authority.read_text());e=a.evidence_root
    main=e/('output-aquifer-windows-'+a.optimization+'-v2');run=json.loads((main/'RESULT.json').read_text());members={name:digest for key,record in old['archives'].items() if key in ('OUTPUT_AQUIFER_WINDOWS_'+a.optimization+'_RAW_ARCHIVE.json','OUTPUT_AQUIFER_WINDOWS_PRESERVATION_RAW_ARCHIVE.json') for name,digest in record['members'].items()}
    def qualified(path):
        require=path.relative_to(e).as_posix();assert hashlib.sha256(path.read_bytes()).hexdigest()==members[require],require
    qualified(main/'RESULT.json');contexts=[]
    for key in CONTROLS:
        item=run['cases'][key];contexts.append(('output-'+key,Path(item['input_root']),Path(item['build_root']),Path(item['short_root'])/'trajectory',True))
    for kind in previous.PHYSICS:
        if kind=='loss-limit-active':continue
        root=e/('output-aquifer-compatibility-'+a.optimization+'-v2')/kind;contexts.append(('default-'+kind,root/'input',root/'current-build',root/'current/trajectory',False))
    q=dict(status='RUNNING',optimization=a.optimization,authority_sha256=m.sha(authority),profiles={})
    if a.resume:q['retained_previous_report']=json.loads((a.output/'RESULT.json').read_text())
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for key,inputs,oldbuild,oldfull,original in contexts:
            qualified(oldbuild/'BUILD.json');qualified(oldfull/'daily.jsonl')
            project=m.e.load(inputs,original_output=original);out=a.output/key;out.mkdir(exist_ok=a.resume);build=out/'build'
            command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
            if original:command+=['--original-output']
            if not (a.resume and (build/'BUILD.json').exists()):
                p=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(p.stdout);(out/'build.stderr').write_text(p.stderr);assert p.returncode==0,p.stderr
            actual,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((oldbuild/'BUILD.json').read_text());assert actual['project']==prior['project'] and actual['inputs']==prior['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_aquifer_solute','aquifer_native_receipt','original_output'):assert actual['identity'].get(field)==prior['identity'].get(field),(key,field)
            full=out/'trajectory';report,data=m.trajectory(build,a.reference_work,project,full,10,{2,4,8,10},60);assert m.physical(data)==m.physical(m.rows(oldfull))
            for day in (2,4,8,10):
                path=oldfull/f'accepted-column-1-day-{day}.zip';qualified(path)
                with zipfile.ZipFile(path) as x,zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as y:
                    for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),(key,day,member)
            def stable(raw):return re.sub(rb'(\* Generated at:  )\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}',rb'\g<1>0000-00-00 00:00:00',raw)
            files={}
            for path in (full/'original').iterdir():
                if path.is_file() and (path.suffix.lower()=='.csv' or path.name.endswith('_output.bin')):
                    previous_file=oldfull/'original'/path.name;qualified(previous_file);assert stable(path.read_bytes())==stable(previous_file.read_bytes());files[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
            own=[(previous.own if original else m.own)(build,a.reference_work,project,full,data,s,t,out/('own-'+str(s))) for s,t in ((2,4),(4,8),(8,10))]
            q['profiles'][key]=dict(actual_build=actual,prior_build_sha256=m.sha(oldbuild/'BUILD.json'),source_provider_inputs_exact=True,all_physical_exact=True,four_complete_native_endpoints_exact=True,user_files_exact=files,actual_immutable_prior_member_hashes=True,own=own,trajectory=report,transactions=transactions(build,a.reference_work,project,full,out/'external'),fabricated_receipt_refusals=fabricated_receipts(build,a.reference_work,project,full,out/'fabricated'));save();print(key,a.optimization,'ACTUAL_PREVIOUS_AQUIFER_SOURCE_NATIVE_EXACT_PASS',flush=True)
        assert len(q['profiles'])==12;q['status']='TWELVE_CURRENT_AQUIFER_OUTPUT_DEFAULT_NATIVE_CONTEXTS_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
