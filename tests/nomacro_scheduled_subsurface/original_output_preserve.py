"""Exact default compatibility closures across the admitted age codecs."""
import argparse
from contextlib import ExitStack
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import age_clock as clock
import age_schedule as schedule
import age_calendar as regular

m=clock.m
ROOT=clock.c.f.ROOT
SELECTION=(('CLOCK',('subdaily3-surface','annual1-plain'),clock),('SCHEDULE',('monthly-surface','explicit-plain'),schedule),('CALENDAR',('p7-plain-r1','p7-subsurface-interval-r0'),regular))


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),required=True);p.add_argument('--resume',action='store_true');a=p.parse_args();a.output=a.output.resolve()
    if not a.resume:a.output.mkdir()
    proof=ROOT/'integration/f-ci/nomacro-complete01';q=dict(status='RUNNING',platform=a.platform,profiles={},whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    if a.resume:
        q=json.loads((a.output/'RESULT.json').read_text());q.setdefault('retained_failures',[]).append(dict(status=q['status'],error=q.pop('error',None)));q['status']='RUNNING'
    try:
        for stem,names,owner in SELECTION:
            parent=json.loads((proof/('AGE_'+stem+'_QUALIFICATION.json')).read_text())
            for opt in ('O0','O2'):
                record_name='AGE_'+stem+('_FINAL_WINDOWS_' if stem=='CLOCK' and a.platform=='Windows' else '_WINDOWS_' if a.platform=='Windows' else '_UBUNTU_')+opt+'_RAW_ARCHIVE.json'
                record=json.loads((proof/record_name).read_text());archive=proof/record['archive'];assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
                with zipfile.ZipFile(archive) as z:
                    for base in names:
                        name=base+'-'+opt;out=a.output/(stem+'-'+name)
                        if a.resume and stem+'-'+name in q['profiles']:
                            m.validate_bundle(out/'build',a.reference_work,m.e.load(out/'prior/input'));continue
                        out.mkdir(exist_ok=a.resume);prior=out/'prior';selected={}
                        matches=[n for n in record['members'] if n.endswith('/'+name+'/input/swap.swp')];assert len(matches)==1,(record_name,name,matches)
                        prefix=matches[0][:-len('input/swap.swp')]
                        for member,digest in record['members'].items():
                            if not member.startswith(prefix):continue
                            tail=member[len(prefix):]
                            native=tail in {f'full/accepted-column-1-day-{day}.zip' for day in (4,8,364,367)}
                            if not(tail.startswith('input/') or tail=='full/daily.jsonl' or tail.startswith('full/original/') and tail.endswith('.csv') or native):continue
                            data=z.read(member);assert hashlib.sha256(data).hexdigest()==digest
                            target=prior/tail;assert target.resolve().is_relative_to(prior.resolve());target.parent.mkdir(parents=True,exist_ok=True)
                            if target.exists():assert target.read_bytes()==data
                            else:target.write_bytes(data)
                            selected[member]=digest
                        project=m.e.load(prior/'input');assert project.original_output is False
                        build=out/'build';cmd=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--experimental-project',project.input_directory,'--reference-work',str(a.reference_work),'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',str(build)]
                        if not (a.resume and (build/'BUILD.json').exists()):
                            result=subprocess.run(cmd,capture_output=True,text=True,timeout=180);(out/'build.log').write_text(result.stdout+result.stderr);assert result.returncode==0,result.stderr
                        actual,_=m.validate_bundle(build,a.reference_work,project);expected=parent['builds'][a.platform][name]
                        assert actual['project']==expected['project'] and actual['inputs']==expected['inputs'] and 'original_output' not in actual['identity']
                        for key in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age'):
                            assert actual['identity'][key]==expected['identity'][key],(stem,name,key)
                        full=out/'prefix368'
                        if a.resume and full.exists():
                            data=m.rows(full);assert len(data)==368;report=dict(status='RETAINED_ACTUAL_PREFIX_REVALIDATED',days=368,budgets=m.check(data),model_seconds=None,build_sha256=m.sha(build/'BUILD.json'))
                        else:report,data=m.trajectory(build,a.reference_work,project,full,368,{4,8,364,367},60)
                        assert m.physical(data)==m.physical(m.rows(prior/'full')[:368])
                        for csv in (full/'original').glob('*.csv'):
                            rows=m.csvlines(csv);assert rows==m.csvlines(prior/'full/original'/csv.name)[:len(rows)],csv.name
                        for day in (4,8,364,367):
                            with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as new,zipfile.ZipFile(prior/f'full/accepted-column-1-day-{day}.zip') as old:
                                assert all(new.read(k)==old.read(k) for k in ('result.end','macro.bin')),(name,day)
                        extra=('annual' if base.startswith('annual') else 'subdaily',) if stem=='CLOCK' else ()
                        own=[owner.own(build,a.reference_work,project,full,data,s,e,out/('own-'+str(s)),*extra) for s,e in ((4,8),(364,367))]
                        q['profiles'][stem+'-'+name]=dict(actual_build=actual,source_provider_inputs_exact=True,all368_physical_and_user_output_exact=True,four_complete_native_endpoints_exact=True,coverage=report,own=own,parent_runtime=parent['runtime'],archive_sha256=record['sha256'],selected_parent_members=selected)
                        save();print(stem,name,'DEFAULT_SOURCE_PROVIDER_NATIVE_PRESERVED',flush=True)
        q['status']='TWELVE_DEFAULT_005_004_003_SOURCE_PROVIDER_YEAR_NATIVE_CONTEXTS_PRESERVED'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
