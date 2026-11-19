"""Current compatibility drainage bytes against admitted full-period evidence."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import extended_runtime as prior

m=prior.m;ROOT=prior.ROOT


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--case',choices=('water','automatic'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/extended_runtime.py'),
             '--case',a.case,'--days','5','--optimization',a.optimization,'--reference-work',str(a.reference_work),
             '--build-root',str(a.build_root),'--output',str(a.output)]
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
    (a.output/'preservation.stdout').write_text(r.stdout);(a.output/'preservation.stderr').write_text(r.stderr);r.check_returncode()
    q=json.loads((a.output/'RESULT.json').read_text());build=Path(q['build_root']);meta=json.loads((build/'BUILD.json').read_text())
    archive=ROOT/f'integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_WINDOWS_{a.optimization}_RAW_ARCHIVE.zip'
    with zipfile.ZipFile(archive) as old:
        prefix=a.case+'-build/';gold=json.loads(old.read(prefix+'BUILD.json'))
        sources={name[len(prefix):]:old.read(name) for name in old.namelist() if name.startswith(prefix) and '/' not in name[len(prefix):] and name.endswith('.f90')}
        assert {path.name:path.read_bytes() for path in build.glob('*.f90')}==sources,'Current compatibility generated Fortran changed'
        assert meta['inputs']==gold['inputs'] and meta['identity']['kernel_sources']==gold['identity']['kernel_sources']
        actual=m.rows(a.output/'trajectory');before=[json.loads(line) for line in old.read(a.case+'/trajectory/daily.jsonl').splitlines()][:5]
        assert m.physical(actual)==m.physical(before),'Current compatibility physical prefix changed'
        for day in (2,4):
            with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as now,zipfile.ZipFile(io.BytesIO(old.read(a.case+f'/trajectory/accepted-column-1-day-{day}.zip'))) as original:
                assert all(now.read(name)==original.read(name) for name in ('result.end','macro.bin')),'Current compatibility native prefix changed'
    result=dict(status='ACTUAL_COMPATIBILITY_DRAINAGE_SOURCE_INPUT_KERNEL_PHYSICAL_COMPLETE_NATIVE_EXACT',
                source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,case=a.case,
                old_archive=archive.name,old_archive_sha256=m.sha(archive),actual_days=5,fresh_unaffected_full_periods=0,
                exact_inputs=True,exact_generated_fortran=True,exact_kernel_sources=True,exact_physical_prefix=True,exact_prior_native_days=[2,4])
    (a.output/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],a.case,a.optimization)


if __name__=='__main__':main()
