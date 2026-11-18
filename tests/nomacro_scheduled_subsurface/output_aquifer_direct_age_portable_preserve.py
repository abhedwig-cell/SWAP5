"""Fresh source-flag-off closures against actual prior Linux hysteresis artifact."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import direct_soil_age_matrix as previous
import re

m=previous.m
CASES=('point-daily','point-regular','interval-monthly','point-np3','point-hys1-output3','interval-hys2-output0')


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','prior-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();q=dict(status='RUNNING',profiles={},prior_workflow=44246149974)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for key in CASES:
            old=a.prior_root/('short-'+key);original=key in ('point-hys1-output3','interval-hys2-output0');project=m.e.load(old/'input',original_output=original,age_direct_soil_source=True);assert not project.age_irrigation_source;out=a.output/key;out.mkdir();build=out/'build'
            cmd=[sys.executable,'-B',str(previous.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--age-direct-soil-source','--reference-work',str(a.reference_work),'--build-only','--donor-opt','O2','--kernel-opt','O2','--output',str(build)]
            if original:cmd+=['--original-output']
            r=subprocess.run(cmd,cwd=previous.ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
            actual,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'build/BUILD.json').read_text());assert actual['project']==prior['project'] and actual['inputs']==prior['inputs']
            for field in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_output','original_age_fixed_irrigation'):assert actual['identity'].get(field)==prior['identity'].get(field),(key,field)
            days=35 if 'monthly' in key else 10;full=out/'trajectory';report,data=m.trajectory(build,a.reference_work,project,full,days,{2,4,8,days},60);assert m.physical(data)==m.physical(m.rows(old/'trajectory'))
            for day in (2,4,8,days):
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(old/f'trajectory/accepted-column-1-day-{day}.zip') as y:
                    for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),(key,day,member)
            def stable(raw):return re.sub(rb'(\* Generated at:  )\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}',rb'\g<1>0000-00-00 00:00:00',raw)
            for path in (full/'original').iterdir():
                if path.is_file() and (path.suffix.lower()=='.csv' or path.name.endswith('_output.bin')):assert stable(path.read_bytes())==stable((old/'trajectory/original'/path.name).read_bytes()),path.name
            own=[previous.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s))) for s,e in ((2,4),(4,8))]
            q['profiles'][key]=dict(actual_build=actual,prior_build_sha256=m.sha(old/'build/BUILD.json'),source_provider_inputs_exact=True,all_physical_exact=True,four_complete_native_endpoints_exact=True,own=own,trajectory=report);save();print(key,'PORTABLE_CURRENT_DIRECT_SOIL_AGE_PRESERVED',flush=True)
        q['status']='SIX_PORTABLE_CURRENT_DIRECT_SOIL_AGE_FAMILIES_EXACT_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
