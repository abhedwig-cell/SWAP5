"""Reuse the literal qualified original-age executable for new fixed inputs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import time
import age_runtime as age

ROOT=age.ROOT
spec=importlib.util.spec_from_file_location('original_age_reference',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/run.py')
r=importlib.util.module_from_spec(spec);spec.loader.exec_module(r)


def main():
    p=argparse.ArgumentParser()
    for name in ('prior-reference','inputs','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();record=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),profiles={},whole_scientific_equivalence='NOT_QUALIFIED')
    identity=json.loads((ROOT/'integration/f-ci/nomacro-complete01/AGE_QUALIFICATION.json').read_text())['original_provider_reference']['Windows']
    sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
    def save():(a.output/'RESULT.json').write_text(json.dumps(record,indent=2)+'\n')
    try:
        for opt in ('O0','O2'):
            build=a.prior_reference/opt;exe=build/'swap_age.exe';prior=identity['profiles'][opt]
            assert sha(exe)==prior['executable_sha256']
            assert {p.name:sha(p) for p in build.glob('*.f90')}==prior['generated_sha256']
            for kind in ('sprinkler','surface','subsurface','subsurface-interval'):
                name=kind+'-'+opt;case=a.output/name;shutil.copytree(a.inputs/kind,case)
                inputs={p.relative_to(case).as_posix():sha(p) for p in case.rglob('*') if p.is_file()}
                t=time.monotonic();run=subprocess.run([str(exe),'./swap.swp'],cwd=case,capture_output=True,text=True,timeout=60)
                (case/'reference.stdout').write_text(run.stdout);(case/'reference.stderr').write_text(run.stderr)
                assert run.returncode in (0,100) and (case/'swap.ok').exists(),run.stderr
                result=r.validate(run.stdout);values=[list(map(float,line.split()[1:])) for line in run.stdout.splitlines() if line.startswith('HYBRID_AGE_EFFLUENT ')]
                assert len(values)==1096
                result['effluent_output']=age.output_values_from_directory(case,[dict(day=i+1,age_effluent=v) for i,v in enumerate(values)])
                result.update(seconds=time.monotonic()-t,returncode=run.returncode,executable_sha256=sha(exe),input_sha256=inputs,whole_scientific_equivalence='NOT_QUALIFIED')
                assert result['final'][5]==0,'nonzero age in young-water reference'
                record['profiles'][name]=result;save();print(name,'FULL_ORIGINAL_FIXED_YOUNG_AGE_LEDGER_PASS',flush=True)
        record['status']='ORIGINAL_FIXED_YOUNG_AGE_EIGHT_FULL_REFERENCE_PASS'
    except Exception as error:record.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
