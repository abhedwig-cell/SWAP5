"""Fresh inactive-direct-source preservation of all existing age source families."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys
import zipfile
import age_irrigation_source_matrix as prior_probe

m=prior_probe.m;ROOT=prior_probe.ROOT
CASES=('surface-daily','surface-regular','sprinkler-monthly','surface-np3','sprinkler-annual','surface-output3','surface-hys1-output3','sprinkler-hys2-output0')


def main():
    ap=argparse.ArgumentParser()
    for key in ('reference-work','output'):ap.add_argument('--'+key,type=Path,required=True)
    ap.add_argument('--optimization',choices=('O0','O2'),required=True);ap.add_argument('--resume',action='store_true')
    a=ap.parse_args();a.output=a.output.resolve();a.output.mkdir(exist_ok=a.resume)
    authority=ROOT/'integration/f-ci/nomacro-complete01/AGE_IRRIGATION_SOURCE_QUALIFICATION.json';oldq=json.loads(authority.read_text())
    q=dict(status='RUNNING',optimization=a.optimization,authority_sha256=m.sha(authority),profiles={})
    if a.resume:
        q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        for key in CASES:
            old=oldq['platforms']['Windows'][a.optimization]['cases'][key];prior=Path(old['short_root']);oldbuild=Path(old['build_root']);inputs=Path(old['input_root'])
            original=old['short']['original_output'];project=m.e.load(inputs,original_output=original,age_irrigation_source=True)
            assert project.age_direct_soil_source is False
            out=a.output/key
            if key in q['profiles']:
                actual,_=m.validate_bundle(out/'build',a.reference_work,project);assert actual==q['profiles'][key]['actual_build'];continue
            out.mkdir(exist_ok=a.resume);build=out/'build'
            cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',inputs,'--age-irrigation-source','--reference-work',a.reference_work,'--build-only','--donor-opt',a.optimization,'--kernel-opt',a.optimization,'--output',build]
            if original:cmd+=['--original-output']
            if not (a.resume and (build/'BUILD.json').exists()):
                r=subprocess.run(list(map(str,cmd)),cwd=ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
            actual,_=m.validate_bundle(build,a.reference_work,project);oldmeta=json.loads((oldbuild/'BUILD.json').read_text())
            assert actual['project']==oldmeta['project'] and actual['inputs']==oldmeta['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_output','original_age_fixed_irrigation'):
                assert actual['identity'].get(field)==oldmeta['identity'].get(field),(key,field)
            days=old['short']['trajectory']['days'];full=out/'trajectory';report,data=m.trajectory(build,a.reference_work,project,full,days,{2,4,8,days},60)
            assert m.physical(data)==m.physical(m.rows(prior/'trajectory'))
            names={p.name for p in (full/'original').glob('*') if p.is_file() and (p.suffix.lower()=='.csv' or p.name.endswith('_output.bin'))}
            assert names=={p.name for p in (prior/'trajectory/original').glob('*') if p.is_file() and (p.suffix.lower()=='.csv' or p.name.endswith('_output.bin'))}
            def stable(raw):return re.sub(rb'(\* Generated at:  )\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}',rb'\g<1>0000-00-00 00:00:00',raw)
            for name in names:assert stable((full/'original'/name).read_bytes())==stable((prior/'trajectory/original'/name).read_bytes()),name
            for day in (2,4,8,days):
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(prior/f'trajectory/accepted-column-1-day-{day}.zip') as y:
                    for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),(key,day,member)
            own=[prior_probe.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8))]
            q['profiles'][key]=dict(actual_build=actual,prior_build_sha256=m.sha(oldbuild/'BUILD.json'),prior_root=str(prior),generated_provider_inputs_exact=True,all_physical_exact=True,user_files_exact={n:hashlib.sha256((full/'original'/n).read_bytes()).hexdigest() for n in names},four_complete_native_endpoints_exact=True,metadata_projection='none: complete actual old project and input metadata exactly equal',trajectory=report,own=own)
            save();print(key,a.optimization,'ACTUAL_PRIOR_CURRENT_AGE_SOURCE_DIRECT_FLAG_FALSE_PRESERVED',flush=True)
        q['status']='EIGHT_PRIOR_CURRENT_AGE_SOURCE_FAMILIES_DIRECT_FLAG_FALSE_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
