"""Exact regular003 preservation under the new selected schedule adapter."""
import argparse
import contextlib
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from datetime import date,timedelta
import age_calendar as c

m=c.m


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);a=p.parse_args();a.output.mkdir()
    proof=c.f.ROOT/'integration/f-ci/nomacro-complete01';parent=json.loads((proof/'AGE_CALENDAR_QUALIFICATION.json').read_text())
    result=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},parent_runtime=parent['runtime'],whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    with contextlib.ExitStack() as stack:
        archives=[]
        for opt in ('O0','O2'):
            name='AGE_CALENDAR_'+('WINDOWS_' if a.platform=='Windows' else 'UBUNTU_')+opt+'_RAW_ARCHIVE.json'
            record=json.loads((proof/name).read_text());archive=proof/record['archive']
            assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
            archives.append((record,stack.enter_context(zipfile.ZipFile(archive))))
        try:
            for name,old_profile in parent['platforms'][a.platform]['profiles'].items():
                old=parent['builds'][a.platform][name];prior=a.output/'prior'/name
                if a.platform=='Windows':
                    original=old_profile['input_path'].replace('\\','/');prefix=original.split('/swap5-complete01-evidence/',1)[1].rsplit('/input',1)[0]+'/'
                else:prefix='age-calendar-ubuntu/matrix/'+name+'/'
                selected={};native_days={3,4,6,8,364,367}
                for record,z in archives:
                    for member,digest in record['members'].items():
                        if not member.startswith(prefix):continue
                        tail=member[len(prefix):]
                        native=tail in {f'full/accepted-column-1-day-{day}.zip' for day in native_days}
                        csv=tail.startswith('full/original/') and tail.endswith('.csv')
                        if not (tail.startswith('input/') or tail=='full/daily.jsonl' or native or csv):continue
                        assert not Path(tail).is_absolute() and '..' not in Path(tail).parts
                        data=z.read(member);assert hashlib.sha256(data).hexdigest()==digest
                        dest=prior/tail;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);selected[member]=digest
                assert selected and (prior/'input/swap.swp').exists() and (prior/'full/daily.jsonl').exists()
                project=m.e.load(prior/'input');opt=old_profile['optimization'];build=a.output/(name+'-build')
                cmd=[sys.executable,'-B',str(c.f.ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                r=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(a.output/(name+'.log')).write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
                meta,_=m.validate_bundle(build,a.reference_work,project)
                assert meta['identity']['conserved_original_age']['native_codec']=='S5AGE003'
                assert meta['identity']['donor_generated']==old['identity']['donor_generated']
                assert meta['inputs']==old['inputs']
                for key in ('donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age'):
                    assert meta['identity'][key]==old['identity'][key],(name,key)
                full=a.output/(name+'-prefix368');report,data=m.trajectory(build,a.reference_work,project,full,368,native_days,45)
                previous=prior/'full';assert m.physical(data)==m.physical(m.rows(previous)[:368])
                last=str(date.fromisoformat(project.start_date)+timedelta(days=367))
                for path in (full/'original').glob('*.csv'):
                    expected=[row for row in c.records(previous/'original'/path.name) if row[:10]<=last]
                    assert c.records(path)==expected,path.name
                for day in (4,8,367):
                    with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(previous/f'accepted-column-1-day-{day}.zip') as oldzip:
                        assert all(new.read(member)==oldzip.read(member) for member in ('result.end','macro.bin'))
                report['own']=[c.own(build,a.reference_work,project,full,data,s,e,a.output/(name+'-own'+str(s))) for s,e in ((3,6),(364,367))]
                result['profiles'][name]=dict(generated_provider_inputs_exact=True,physical_all_csv_three_native_payloads_exact=True,coverage=report,selected_parent_members=selected);save();print(name,'REGULAR_AGE003_LITERAL_SOURCE_NATIVE_PRESERVED',flush=True)
            result['status']='FOURTEEN_REGULAR_AGE003_SOURCE_PROVIDER_YEAR_NATIVE_PRESERVED'
        except Exception as error:result.update(status='FAILED',error=repr(error));raise
        finally:save()


if __name__=='__main__':main()
