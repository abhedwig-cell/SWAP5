"""Explicit current-canonical age/wetting composition selection."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tools/solute'),str(ROOT/'app/hybrid_water'),str(ROOT/'tests/local_wetting')]
import user_prepare
from verify_review import package


def extract_wetting(target,platform):
    read=package(ROOT/'integration/local-wetting-time01/admission')
    index=json.loads((ROOT/'integration/local-wetting-time01/admission/FILES.json').read_text())
    prefix=platform+'/'
    for name in index['files']:
        if name.startswith(prefix):
            tail=Path(name[len(prefix):]);assert not tail.is_absolute() and '..' not in tail.parts
            dest=target/tail;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(read(name))


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--reference-work',type=Path,required=True)
    p.add_argument('--platform',choices=('Windows','Ubuntu'),default='Ubuntu');p.add_argument('--wetting-only',action='store_true');a=p.parse_args();a.output.mkdir()
    if not (a.reference_work/'PREPARED.json').exists():user_prepare.prepare(a.reference_work)
    user_prepare.validate(a.reference_work)
    def run(path,*args):subprocess.run([sys.executable,'-B',str(ROOT/path),*map(str,args)],cwd=ROOT,check=True)
    if not a.wetting_only:
        proof=ROOT/'integration/f-ci/nomacro-complete01';record=json.loads((proof/'AGE_COMPOSITION_PARENT_RAW_ARCHIVE.json').read_text());archive=proof/record['archive']
        assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
        with zipfile.ZipFile(archive) as z:
            assert set(z.namelist())==set(record['members'])
            for name,digest in record['members'].items():assert hashlib.sha256(z.read(name)).hexdigest()==digest
            z.extractall(a.output/'prior-age')
        inputs=a.output/'inputs';inputs.mkdir()
        from age_reference import fixture
        for age in (0.,100.):fixture(inputs/str(int(age)),age)
        run('tests/nomacro_scheduled_subsurface/age_composition.py','--input-root',inputs,'--reference-work',a.reference_work,
            '--prior',a.output/'prior-age'/a.platform,'--output',a.output/'age')
        run('tests/nomacro_scheduled_subsurface/age_controls.py','--input-root',inputs,'--reference-work',a.reference_work,
            '--evidence',a.output/'age','--output',a.output/'age-controls')
    prior=a.output/'prior-wetting';extract_wetting(prior,a.platform.lower())
    run('tests/local_wetting/admit.py','--reference-work',a.reference_work,'--prior',prior,'--output',a.output/'wetting')


if __name__=='__main__':main()
