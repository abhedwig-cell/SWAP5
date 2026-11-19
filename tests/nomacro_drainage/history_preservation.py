"""Five-day actual history-off postimage against admitted calendar raw bytes."""
import argparse
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile
import calendar_runtime as runtime
from calendar_evidence import differences
from calendar_publisher import publisher_equivalence

m=runtime.m;ROOT=runtime.ROOT


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--case',choices=('water','automatic'),required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args()
    label,mode,fmt=('water','monthly',2) if a.case=='water' else ('cde','daily',3)
    command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/calendar_runtime.py'),'--case',a.case,'--mode',mode,'--format',str(fmt),'--days','5','--optimization',a.optimization,'--reference-work',str(a.reference_work),'--build-root',str(a.build_root),'--output',str(a.output)]
    r=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=180)
    (a.output/'preservation.stdout').write_text(r.stdout);(a.output/'preservation.stderr').write_text(r.stderr);r.check_returncode()
    q=json.loads((a.output/'RESULT.json').read_text());build=Path(q['build_root']);current=json.loads((build/'BUILD.json').read_text())
    archive=ROOT/f'integration/f-ci/nomacro-complete01/EXTENDED_DRAINAGE_CALENDAR_WINDOWS_{a.optimization}_RAW_ARCHIVE.zip'
    with zipfile.ZipFile(archive) as old:
        prefix='current-'+label;before=json.loads(old.read(prefix+'-build/BUILD.json'));directory=prefix+'-build/'
        expected={name[len(directory):]:old.read(name) for name in old.namelist() if name.startswith(directory) and name.endswith('.f90') and '/' not in name[len(directory):]}
        assert expected=={path.name:path.read_bytes() for path in build.glob('*.f90')},'Actual history-off generated Fortran changed'
        assert current['inputs']==before['inputs'] and current['project']==before['project']
        changed=differences(before['identity'],current['identity'])
        allowed={'extended_drainage.source_sha256','extended_drainage.output_receipt_renderer_sha256','original_output.source_sha256','restart_publisher.library_sha256'}
        assert set(changed)<=allowed,changed
        pe=None
        if 'restart_publisher.library_sha256' in changed:
            prior=build/'prior-admitted-publisher.dll';prior.write_bytes(old.read(directory+'restart_publish.dll'))
            assert m.sha(prior)==before['identity']['restart_publisher']['library_sha256'] and m.sha(build/'restart_publish.dll')==current['identity']['restart_publisher']['library_sha256']
            pe=publisher_equivalence(prior,build/'restart_publish.dll')
        rows=m.rows(a.output/'trajectory');prior=[json.loads(line) for line in old.read(prefix+'/trajectory/daily.jsonl').splitlines()]
        assert len(rows)==5 and m.physical(rows)==m.physical(prior[:5])
        for day in (2,4):
            with zipfile.ZipFile(a.output/f'trajectory/accepted-column-1-day-{day}.zip') as now,zipfile.ZipFile(io.BytesIO(old.read(prefix+f'/trajectory/accepted-column-1-day-{day}.zip'))) as gold:
                assert all(now.read(name)==gold.read(name) for name in ('result.end','macro.bin'))
    result=dict(status='ACTUAL_HISTORY_OFF_INPUT_FORTRAN_COMPILER_KERNEL_PHYSICAL_NATIVE_PRESERVATION_PASS',source=q['source'],actual_days=5,actual_exact_native_days=[2,4],optimization=a.optimization,case=a.case,old_archive=archive.name,old_archive_sha256=m.sha(archive),changed_source_roles=changed,publisher=pe,fresh_unaffected_full_periods=0)
    (a.output/'PRESERVATION.json').write_text(json.dumps(result,indent=2)+'\n');print(result['status'],a.case,a.optimization)


if __name__=='__main__':main()
