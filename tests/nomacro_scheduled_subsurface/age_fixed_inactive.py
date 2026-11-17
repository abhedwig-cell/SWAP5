"""Fresh inactive fixed-age renderer closure and active-pond/native preservation."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import age_fixed as f
from age_reference import fixture

m=f.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);a=p.parse_args();a.output.mkdir()
    proof=f.ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((proof/'AGE_COMPOSITION_PARENT_RAW_ARCHIVE.json').read_text());archive=proof/record['archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    prior=a.output/'prior'
    with zipfile.ZipFile(archive) as z:
        for name,digest in record['members'].items():
            assert hashlib.sha256(z.read(name)).hexdigest()==digest
            if name.startswith(a.platform+'/'):
                dest=prior/Path(name.split('/',1)[1]);dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(z.read(name))
    inputs=a.output/'inputs';inputs.mkdir();result=dict(status='RUNNING',profiles={},whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    for initial in (0.,100.):
        path=inputs/str(int(initial));fixture(path,initial)
        project=m.e.load(path)
        for opt in ('O0','O2'):
            name=str(int(initial))+'-'+opt;build=a.output/(name+'-build');old=prior/(name+'-build')
            cmd=[sys.executable,'-B',str(f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',str(path),'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
            r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
            assert {p.name:m.sha(p) for p in build.glob('*.f90')}=={p.name:m.sha(p) for p in old.glob('*.f90')}
            meta,_=m.validate_bundle(build,a.reference_work,project);previous=json.loads((old/'BUILD.json').read_text())
            assert 'original_age_fixed_irrigation' not in meta['identity'] and meta['inputs']==previous['inputs']
            for field in ('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age'):assert meta['identity'][field]==previous['identity'][field],field
            full=a.output/(name+'-prefix368');report,data=m.trajectory(build,a.reference_work,project,full,368,{2,4,365,367},30)
            parent=prior/(name+'-full');assert m.physical(data)==m.physical(m.rows(parent)[:368])
            for p in (full/'original').glob('*.csv'):assert m.csvlines(p)==m.csvlines(parent/'original'/p.name)[:len(m.csvlines(p))]
            for day in (2,4,365,367):
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(parent/f'accepted-column-1-day-{day}.zip') as oldzip:assert all(new.read(p)==oldzip.read(p) for p in ('result.end','macro.bin'))
            report['own']=[f.age.own(build,a.reference_work,project,full,data,s,e,a.output/(name+'-own'+str(s))) for s,e in ((2,4),(365,367))]
            result['profiles'][name]=dict(generated_provider_inputs_exact=True,physical_all_csv_four_native_payloads_exact=True,coverage=report);save();print(name,'INACTIVE_FIXED_AGE_CLOSURE_NATIVE_EXACT',flush=True)
    result['status']='FOUR_INACTIVE_FIXED_AGE_SOURCE_AND_ACTIVE_POND_NATIVE_EXACT';save()


if __name__=='__main__':main()
