"""Changed descriptor dispatch preserves young fixed inputs and named routes."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import age_fixed as fixed

m=fixed.m
ROOT=fixed.ROOT


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','evidence-root','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();specs=[];e=a.evidence_root
    for opt in ('O0','O2'):
        for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
            prior=e/'age-fixed';specs.append((kind+'-'+opt,m.e.load(prior/'inputs'/kind),prior/(kind+'-'+opt+'-build'),prior/(kind+'-'+opt+'-short'),8,opt))
    for name,project in [('grass',m.h.GRASSGROWTH),('hupsel',m.h.HUPSEL),('salt',m.h.SALTFARM)]:
        prior=e/'age-canonical-preservation';specs.append((name,project,prior/(name+'-build'),prior/(name+'-prefix'),4,'O2'))
    q=dict(status='RUNNING',profiles={},functional_completion='PARTIAL',whole_scientific_equivalence='NOT_QUALIFIED')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    try:
        for name,project,old,previous,days,opt in specs:
            assert project.age_irrigation_source is False;out=a.output/name;out.mkdir();build=out/'build';command=[sys.executable,'-B',str(ROOT/'tools/solute/run_water.py'),'--model',project.model,'--reference-work',a.reference_work,'--build-only','--donor-opt',opt,'--kernel-opt',opt,'--output',build]
            if project.input_directory:command+=['--experimental-project',project.input_directory]
            else:command+=['--no-macro-release']
            r=subprocess.run(list(map(str,command)),cwd=ROOT,capture_output=True,text=True,timeout=180);(out/'build.stdout').write_text(r.stdout);(out/'build.stderr').write_text(r.stderr);assert r.returncode==0,r.stderr
            meta,_=m.validate_bundle(build,a.reference_work,project);prior=json.loads((old/'BUILD.json').read_text())
            assert meta['project']==prior['project'] and meta['inputs']==prior['inputs']
            for key in ('donor_generated','donor_flags','kernel_flags','donor_objects','donor_modules','ttutil_modules','ttutil_library','kernel_sources','conserved_original_age','original_age_fixed_irrigation'):
                assert meta['identity'].get(key)==prior['identity'].get(key),(name,key)
            full=out/'trajectory';report,data=m.trajectory(build,a.reference_work,project,full,days,{2,4,days},45);assert m.physical(data)==m.physical(m.rows(previous)[:days])
            for p in (full/'original').glob('*.csv'):
                rows=m.csvlines(p);assert rows==m.csvlines(previous/'original'/p.name)[:len(rows)],(name,p.name)
            endpoints=[]
            for day in (2,4,days):
                oldzip=previous/f'accepted-column-1-day-{day}.zip'
                if not oldzip.exists():continue
                with zipfile.ZipFile(full/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(oldzip) as y:
                    for member in ('result.end','macro.bin'):assert x.read(member)==y.read(member),(name,day,member)
                endpoints.append(day)
            own=[m.own(build,a.reference_work,project,full,data,2,4,out/'own')]
            q['profiles'][name]=dict(actual_build=meta,prior_build_sha256=m.sha(old/'BUILD.json'),original_route_exact=True,generated_provider_inputs_exact=True,physical_user_output_exact=True,complete_native_endpoints_exact=endpoints,trajectory=report,own=own);save();print(name,'SOURCE_FLAG_FALSE_YOUNG_NAMED_PRESERVED',flush=True)
        q['status']='EIGHT_YOUNG_FIXED_AND_THREE_NAMED_FLAG_FALSE_CONTEXTS_PRESERVED'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
