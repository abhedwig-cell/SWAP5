"""Selected portable original-age qualification and existing owner preservation."""
import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import user_prepare
spec=importlib.util.spec_from_file_location('age_inputs',Path(__file__).with_name('age_reference.py'))
f=importlib.util.module_from_spec(spec);spec.loader.exec_module(f)


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True)
    p.add_argument('--reference-work',type=Path,required=True);a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    inputs=a.output/'inputs';inputs.mkdir()
    for initial in (0.,100.):f.fixture(inputs/str(int(initial)),initial)
    def run(script,*args,env=None):subprocess.run([sys.executable,'-B',str(script),*map(str,args)],cwd=ROOT,env=env,check=True)
    proof=ROOT/'integration/f-ci/nomacro-complete01'
    core=json.loads((proof/'AGE_CORE_QUALIFICATION.json').read_text())
    assert core['runtime']=='4c6b52b4e09dec9906d41115990942ee7b40a14a' and core['ubuntu']=='ca0356cfdec82853bd3c3f8f0eb611ea70e258dc'
    previous=core['existing_age_owner'];assert previous['status']=='PHYSICAL_PASS_NOT_ADMITTED'
    for path,digest in previous['input_sha256'].items():
        assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==digest,('changed prior age physical input',path)
    compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0]
    assert compiler==previous['compiler'],'Prior owner compiler changed; select fresh owner qualification'
    (a.output/'EXISTING_OWNER_INHERITANCE.json').write_text(json.dumps(dict(status='EXACT_INPUT_AND_COMPILER_EXISTING_OWNER_INHERITED',
        previous_runtime=core['runtime'],previous_ubuntu=core['ubuntu'],input_sha256=previous['input_sha256'],compiler=compiler,
        fresh_execution=False,reason='Independent new observer and output/native additions; every existing age owner physical input is literal to its supported Linux O0/O2 native qualification.'),indent=2)+'\n')
    for name,folder in [('AGE_CORE_TRAJECTORIES','prior-core'),('AGE_CORE_REFERENCE','prior-reference')]:
        record=json.loads((proof/(name+'_RAW_ARCHIVE.json')).read_text());archive=proof/record['archive']
        assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
        target=a.output/folder;target.mkdir()
        with zipfile.ZipFile(archive) as z:
            assert set(z.namelist())==set(record['members'])
            for member,digest in record['members'].items():
                assert not member.startswith('/') and '..' not in Path(member).parts
                assert hashlib.sha256(z.read(member)).hexdigest()==digest
            z.extractall(target)
    run(ROOT/'tests/modularity/run_modular_tests.py','--case','age_effluent_observer','--output',a.output/'component')
    run(ROOT/'reference/swap-4.3.1/patches/NOMACRO-AGE-SOURCE-01/run.py','--reference-work',a.reference_work,'--output',a.output/'reference',
        '--effluent','--prior-core-reference-root',a.output/'prior-reference/Ubuntu')
    run(Path(__file__).with_name('age_runtime.py'),'--input-root',inputs,'--reference-work',a.reference_work,'--output',a.output/'runtime',
        '--prior-core-root',a.output/'prior-core/Ubuntu')
    run(Path(__file__).with_name('age_controls.py'),'--input-root',inputs,'--reference-work',a.reference_work,
        '--evidence',a.output/'runtime','--output',a.output/'controls')


if __name__=='__main__':main()
