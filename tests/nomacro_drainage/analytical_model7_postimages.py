"""Four short actual model7 postimages prove reuse of unchanged full/native evidence."""
import argparse
from contextlib import ExitStack
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(ROOT/'tests/nomacro_scheduled_subsurface')]
import original_output_matrix as thermal
from model7_search_science import Store,SHA
from model7_capacity_forensics import audit
from model7_unselected_science import physical,rows
from frost_cde_drainage_portable_forensics import binary
from calendar_evidence import differences


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','build-root','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();items=[]
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),optimization=a.optimization,contexts=items,fresh_full_periods=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        with ExitStack() as stack:
            old=Store(ROOT/'integration/f-ci/nomacro-complete01','HYDRAULIC_MODEL7_SEARCH_WINDOWS_RAW_V1',stack)
            projection=json.loads(old.get('COMPILED_PROJECTION_V1.json'))
            for kind in ('water','cde'):
                out=a.output/kind;build=a.build_root/kind
                cmd=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/model7_capacity_runtime.py'),'--reference-work',str(a.reference_work),'--build-root',str(build),'--output',str(out),'--kind',kind,'--optimization',a.optimization]
                with (a.output/(kind+'.stdout')).open('x') as stdout,(a.output/(kind+'.stderr')).open('x') as stderr:subprocess.run(cmd,cwd=ROOT,stdout=stdout,stderr=stderr,check=True)
                current=json.loads((out/'RESULT.json').read_text());actualbuild=Path(current['build_root']);meta=json.loads((actualbuild/'BUILD.json').read_text())
                prefix=f'profiles/model7-search-daily-{kind}-short-{a.optimization}-v1';prior=json.loads(old.get(prefix+'/RESULT.json'));oldbuild=old.view(projection[prior['build_root']]['archive_prefix'])
                before={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in oldbuild.glob('*.f90')};after={p.name:p.read_bytes().replace(b'\r\n',b'\n') for p in actualbuild.glob('*.f90')}
                assert before==after
                oldmeta=json.loads((oldbuild/'BUILD.json').read_text());assert oldmeta['identity']['donor_objects']==meta['identity']['donor_objects']
                assert oldmeta['identity']['donor_flags']==meta['identity']['donor_flags'] and oldmeta['identity']['kernel_flags']==meta['identity']['kernel_flags']
                changed=differences(oldmeta['identity'],meta['identity'])
                allowed={'host','model7_capacity.source_sha256','model7_terminal_water.source_sha256','model7_terminal_water.policy'}
                assert set(changed)<=allowed,changed
                warm=out/'trajectory';oldwarm=old.view(prefix+'/trajectory')
                assert physical(rows(warm))==physical(rows(oldwarm))
                for day in (2,4,19,23,30,34,35):
                    with zipfile.ZipFile(warm/f'accepted-column-1-day-{day}.zip') as x,zipfile.ZipFile(io.BytesIO((oldwarm/f'accepted-column-1-day-{day}.zip').read_bytes())) as y:
                        assert all(x.read(key)==y.read(key) for key in ('macro.bin','result.end'))
                assert binary((warm/'original/result_output.bin').read_bytes())==binary((oldwarm/'original/result_output.bin').read_bytes())
                result=audit(out,a.reference_work)
                items.append(dict(kind=kind,actual_BUILD_sha256=SHA((actualbuild/'BUILD.json').read_bytes()),complete_Fortran={name:SHA(raw) for name,raw in after.items()},identity_changes=changed,independent=result,physical_native_REAL4_postimage_exact=True));save()
        q['status']='ACTUAL_MODEL7_COMPLETE_COMPILED_NATIVE_SHORT_POSTIMAGES_EXACT_OLD_FULL_CONTROLS_REUSABLE';print(q['status'],flush=True)
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
