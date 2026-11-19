"""Actual current source/native equivalence to retained complete calendar periods."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import calendar_forensics as scientific
import extended_runtime as prior

m=prior.m;ROOT=prior.ROOT


def differences(before,after,prefix=''):
    if isinstance(before,dict) and isinstance(after,dict):
        assert set(before)==set(after),'Actual build identity keys changed'
        return [item for key in before for item in differences(before[key],after[key],prefix+'.'+key if prefix else key)]
    return [] if before==after else [prefix]


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','prior-profile','prior-build','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--label',choices=('water','cde'),required=True);p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();old=json.loads((a.prior_profile/'RESULT.json').read_text())
    assert old['status']=='ACTUAL_EXTENDED_DRAINAGE_ORIGINAL_OUTPUT_NATIVE_PASS' and old['parameters']['days']==1096
    previous=scientific.audit_root(a.prior_profile,a.prior_build)
    case,mode,fmt=('water','monthly',2) if a.label=='water' else ('automatic','daily',3)
    command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/calendar_runtime.py'),'--case',case,'--mode',mode,'--format',str(fmt),
             '--days','35','--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root),'--output',str(a.output)]
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
    (a.output/'preservation.stdout').write_text(r.stdout);(a.output/'preservation.stderr').write_text(r.stderr);r.check_returncode()
    q=json.loads((a.output/'RESULT.json').read_text());build=Path(q['build_root'])
    current=json.loads((build/'BUILD.json').read_text());before=json.loads((a.prior_build/'BUILD.json').read_text())
    assert {path.name:path.read_bytes() for path in build.glob('*.f90')}=={path.name:path.read_bytes() for path in a.prior_build.glob('*.f90')},'Actual current generated Fortran changed'
    assert current['inputs']==before['inputs'] and current['project']==before['project']
    changed=differences(before['identity'],current['identity'])
    assert set(changed)<= {'host','extended_drainage.source_sha256'},changed
    rows=m.rows(a.output/'trajectory');old_rows=m.rows(a.prior_profile/'trajectory')
    assert m.physical(rows)==m.physical(old_rows[:35]),'Actual current35day physical prefix changed'
    for day in (2,4,14,17,30,35):
        with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as now,zipfile.ZipFile(a.prior_profile/f'trajectory/accepted-column-1-day-{day}.zip') as gold:
            assert all(now.read(name)==gold.read(name) for name in ('result.end','macro.bin')),'Actual current complete native prefix changed'
    current_science=scientific.audit_root(a.output)
    (a.output/'FORENSICS.json').write_text(json.dumps(current_science,indent=2)+'\n')
    result=dict(status='ACTUAL_CURRENT_CALENDAR_INPUT_FORTRAN_COMPILER_KERNEL_PHYSICAL_NATIVE_EQUIVALENCE_PASS',
                label=a.label,optimization=a.optimization,current_source=q['source'],prior_source=old['source'],
                prior_profile=str(a.prior_profile),prior_build=str(a.prior_build),actual_days=35,fresh_unaffected_full_periods=0,
                exact_inputs=True,exact_generated_fortran=True,exact_compiler_kernel_provider_identity_except_recorded_source_roles=True,
                changed_identity_source_roles=changed,exact_physical_prefix=True,exact_prior_native_days=[2,4,14,17,30,35],
                prior_full_independent_science=previous,current_independent_science=current_science)
    (a.output/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],a.label,a.optimization)


if __name__=='__main__':main()
