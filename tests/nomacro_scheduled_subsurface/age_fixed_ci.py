"""Selected portable fixed young-water age source/state/reference qualification."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water')]
import user_prepare


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    def run(script,*args):subprocess.run([sys.executable,'-B',str(ROOT/script),*map(str,args)],cwd=ROOT,check=True)
    proof=ROOT/'integration/f-ci/nomacro-complete01';q=json.loads((proof/'AGE_QUALIFICATION.json').read_text())
    compiler=subprocess.check_output(['gfortran','--version'],text=True).splitlines()[0]
    assert compiler==q['builds']['Ubuntu']['0-O0']['identity']['compiler'],'Select fresh original reference build for changed compiler'
    record=json.loads((proof/'AGE_UBUNTU_RAW_ARCHIVE.json').read_text());archive=proof/record['archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    target=a.output/'prior-reference';selected={}
    with zipfile.ZipFile(archive) as z:
        for name,digest in record['members'].items():
            if not name.startswith('reference/'):continue
            data=z.read(name);assert hashlib.sha256(data).hexdigest()==digest
            tail=Path(name[len('reference/'):]);assert not tail.is_absolute() and '..' not in tail.parts
            dest=target/tail;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);selected[name]=digest
    for opt in ('O0','O2'):
        exe=target/opt/'swap_age.exe';exe.chmod(exe.stat().st_mode|0o111)
        identity=q['original_provider_reference']['Ubuntu']['profiles'][opt]
        assert hashlib.sha256(exe.read_bytes()).hexdigest()==identity['executable_sha256']
        for name in q['provider_canonical_sha256']:
            assert hashlib.sha256((ROOT/'src/process'/(name+'.f90')).read_bytes()).hexdigest()==identity['generated_sha256'][name+'.f90']
    (a.output/'ORIGINAL_REFERENCE_INHERITANCE.json').write_text(json.dumps(dict(status='EXACT_QUALIFIED_REFERENCE_EXECUTABLE_SOURCE_COMPILER_REUSED',archive_sha256=record['sha256'],compiler=compiler,selected_members=selected,fresh_compile=False),indent=2)+'\n')
    for phase in ('short','full'):run('tests/nomacro_scheduled_subsurface/age_fixed.py','--reference-work',a.reference_work,'--output',a.output/'runtime','--phase',phase)
    run('tests/nomacro_scheduled_subsurface/age_fixed_reference.py','--prior-reference',target,'--inputs',a.output/'runtime/inputs','--platform','Ubuntu','--output',a.output/'reference')
    run('tests/nomacro_scheduled_subsurface/age_fixed_controls.py','--evidence',a.output/'runtime','--reference-work',a.reference_work,'--output',a.output/'controls')
    run('tests/nomacro_scheduled_subsurface/age_fixed_inline.py','--evidence',a.output/'runtime','--reference-work',a.reference_work,'--output',a.output/'inline')
    run('tests/nomacro_scheduled_subsurface/age_fixed_inactive.py','--platform','Ubuntu','--reference-work',a.reference_work,'--output',a.output/'inactive')


if __name__=='__main__':main()
