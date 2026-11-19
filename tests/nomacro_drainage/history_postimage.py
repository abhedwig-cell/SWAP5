"""Actual short postimage of the input-only early scope guard."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
import history_forensics as science
import calendar_runtime as runtime

m=runtime.m;ROOT=runtime.ROOT


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','prior-profile','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    old=json.loads((a.prior_profile/'RESULT.json').read_text());parameters=old['parameters'];case=parameters['case']
    assert parameters['days']==1096 and old['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS'
    before_root=Path(old['build_root']);before=json.loads((before_root/'BUILD.json').read_text())
    command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/calendar_runtime.py'),'--case',case,'--mode',parameters['mode'],'--format',str(parameters['format']),'--days','6','--hysteresis',str(parameters['hysteresis']),'--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root),'--output',str(a.output)]
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
    (a.output/'postimage.stdout').write_text(r.stdout);(a.output/'postimage.stderr').write_text(r.stderr);r.check_returncode()
    q=json.loads((a.output/'RESULT.json').read_text());root=Path(q['build_root']);now=json.loads((root/'BUILD.json').read_text())
    assert {p.name:p.read_bytes() for p in root.glob('*.f90')}=={p.name:p.read_bytes() for p in before_root.glob('*.f90')}
    assert now['inputs']==before['inputs'] and now['project']==before['project']
    changed=differences(before['identity'],now['identity']);assert set(changed)<={'experimental_input_adapter','restart_publisher.library_sha256'},changed
    pe=None
    if 'restart_publisher.library_sha256' in changed:
        for directory,build in ((root,now),(before_root,before)):assert m.sha(directory/'restart_publish.dll')==build['identity']['restart_publisher']['library_sha256']
        pe=publisher_equivalence(before_root/'restart_publish.dll',root/'restart_publish.dll')
    assert m.physical(m.rows(a.output/'trajectory'))==m.physical(m.rows(a.prior_profile/'trajectory')[:6])
    for day in (2,4):
        with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as current,zipfile.ZipFile(a.prior_profile/f'trajectory/accepted-column-1-day-{day}.zip') as prior:
            assert all(current.read(name)==prior.read(name) for name in ('result.end','macro.bin'))
    result=dict(status='ACTUAL_EARLY_SCOPE_GUARD_CURRENT_FORTRAN_INPUT_COMPILER_KERNEL_PHYSICAL_NATIVE_POSTIMAGE_PASS',actual_days=6,exact_prior_native_days=[2,4],changed_source_roles=changed,publisher=pe,prior_source=old['source'],current_source=q['source'],prior_build_root=str(before_root),fresh_unaffected_full_periods=0,independent_science=science.audit_root(a.output))
    (a.output/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],case,a.optimization)


if __name__=='__main__':main()
