"""Exact emitted/provider/physical/native preservation of daily S5AGE002 gifts."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import age_fixed as f

m=f.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);a=p.parse_args();a.output.mkdir()
    proof=f.ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((proof/('AGE_FIXED_'+a.platform.upper()+'_RAW_ARCHIVE.json')).read_text())
    archive=proof/record['archive'];assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    prefix='age-fixed/' if a.platform=='Windows' else 'runtime/';prior=a.output/'prior';selected={}
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for name,digest in record['members'].items():
            if not name.startswith(prefix):continue
            data=z.read(name);assert hashlib.sha256(data).hexdigest()==digest
            tail=Path(name[len(prefix):]);assert not tail.is_absolute() and '..' not in tail.parts
            dest=prior/tail;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);selected[name]=digest
    result=dict(status='RUNNING',profiles={},archive_sha256=record['sha256'],selected_parent_members=selected)
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    try:
        for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
            project=m.e.load(prior/'inputs'/kind)
            for opt in ('O0','O2'):
                name=kind+'-'+opt;build=a.output/(name+'-build');old=prior/(name+'-build')
                cmd=[sys.executable,'-B',str(f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
                assert {p.name:m.sha(p) for p in build.glob('*.f90')}=={p.name:m.sha(p) for p in old.glob('*.f90')},name
                meta,_=m.validate_bundle(build,a.reference_work,project);previous=json.loads((old/'BUILD.json').read_text())
                assert meta['identity']['conserved_original_age']['native_codec']=='S5AGE002'
                assert meta['inputs']==previous['inputs']
                for key in ('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_age_fixed_irrigation'):
                    assert meta['identity'][key]==previous['identity'][key],(name,key)
                full=a.output/(name+'-prefix');report,data=m.trajectory(build,a.reference_work,project,full,8,{2,4,6,8},30)
                parent=prior/(name+'-short');assert m.physical(data)==m.physical(m.rows(parent))
                for path in (full/'original').glob('*.csv'):assert m.csvlines(path)==m.csvlines(parent/'original'/path.name)
                for day in (2,4,6,8):
                    with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(parent/f'accepted-column-1-day-{day}.zip') as oldzip:
                        assert all(new.read(member)==oldzip.read(member) for member in ('result.end','macro.bin'))
                report['own']=f.age.own(build,a.reference_work,project,full,data,4,6,a.output/(name+'-own'))
                result['profiles'][name]=dict(generated_provider_inputs_exact=True,physical_all_csv_four_native_payloads_exact=True,coverage=report);save();print(name,'DAILY_AGE002_FIXED_SOURCE_NATIVE_EXACT',flush=True)
        result['status']='EIGHT_DAILY_FIXED_AGE002_RENDERER_PROVIDER_PHYSICAL_CSV_NATIVE_PRESERVED'
    except Exception as error:result.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
