"""Portable selected schedule004 state/output and exact003/002 preservation."""
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
    proof=ROOT/'integration/f-ci/nomacro-complete01';parent=json.loads((proof/'AGE_CALENDAR_QUALIFICATION.json').read_text())
    canonical=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    assert canonical(ROOT/'app/hybrid_water/age_output_calendar.py')==parent['calendar_source_canonical_sha256']
    assert canonical(ROOT/'src/process/mod_original_output_receipt.f90')==parent['receipt_provider_canonical_sha256']
    for name,digest in parent['physical_age_providers'].items():assert canonical(ROOT/'src/process'/(name+'.f90'))==digest
    record=json.loads((proof/'AGE_CALENDAR_UBUNTU_CONTEXT_RAW_ARCHIVE.json').read_text());archive=proof/record['archive']
    assert hashlib.sha256(archive.read_bytes()).hexdigest()==record['sha256']
    prefix='age-calendar-ubuntu/reference/';selected={};target=a.output/'prior-reference'
    with zipfile.ZipFile(archive) as z:
        for name,digest in record['members'].items():
            if not name.startswith(prefix):continue
            data=z.read(name);assert hashlib.sha256(data).hexdigest()==digest
            tail=Path(name[len(prefix):]);assert not tail.is_absolute() and '..' not in tail.parts
            dest=target/tail;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data);selected[name]=digest
    (a.output/'UNCHANGED_REFERENCE_COMPONENT_INHERITANCE.json').write_text(json.dumps(dict(status='EXACT_QUALIFIED_REGULAR_RENDERER_RECEIPT_AGE_PROVIDERS_AND_REFERENCE_REUSED',parent_runtime=parent['runtime'],reference_archive_sha256=record['sha256'],selected_reference_members=selected,fresh_compile=False),indent=2)+'\n')
    def run(script,*args):subprocess.run([sys.executable,'-B',str(ROOT/script),*map(str,args)],cwd=ROOT,check=True)
    for phase in ('short','full'):run('tests/nomacro_scheduled_subsurface/age_schedule_matrix.py','--reference-work',a.reference_work,'--output',a.output/'matrix','--phase',phase)
    run('tests/nomacro_scheduled_subsurface/age_schedule_reference.py','--reference-work',a.reference_work,'--prior-reference',target,'--matrix',a.output/'matrix','--platform','Ubuntu','--output',a.output/'reference')
    run('tests/nomacro_scheduled_subsurface/age_schedule_controls.py','--reference-work',a.reference_work,'--matrix',a.output/'matrix','--output',a.output/'controls')
    run('tests/nomacro_scheduled_subsurface/age_schedule_reader_controls.py','--reference-work',a.reference_work,'--matrix',a.output/'matrix','--output',a.output/'reader-controls')
    run('tests/nomacro_scheduled_subsurface/age_schedule_preserve.py','--reference-work',a.reference_work,'--platform','Ubuntu','--output',a.output/'regular003-preserve')
    run('tests/nomacro_scheduled_subsurface/age_fixed_inactive.py','--reference-work',a.reference_work,'--platform','Ubuntu','--output',a.output/'inactive')
    run('tests/nomacro_scheduled_subsurface/age_calendar_preserve.py','--reference-work',a.reference_work,'--platform','Ubuntu','--output',a.output/'daily-fixed-preserve')


if __name__=='__main__':main()
