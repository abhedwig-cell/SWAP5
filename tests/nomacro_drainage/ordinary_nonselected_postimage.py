"""Bounded actual postimages for unchanged explicit and extended owners."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import zipfile

from calendar_evidence import differences
from calendar_publisher import publisher_equivalence
import calendar_runtime as runtime
import implicit_forensics
import history_forensics
import calendar_forensics

ROOT = Path(__file__).resolve().parents[2]
PARENT = 'd785e2c3c415122b8e391d3979f1fbceb81ce5b5'


def main():
    p = argparse.ArgumentParser(description=__doc__)
    for key in ('evidence','reference-work','build-root','output'):
        p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir()
    source=(ROOT/'app/hybrid_water/daily_host.py').read_bytes().replace(b'\r\n',b'\n')
    parent=subprocess.check_output(['git','show',PARENT+':app/hybrid_water/daily_host.py'],cwd=ROOT)
    for addition in (
        b'    from ordinary_implicit_pond_switch import apply_build as ordinary_pond_build\n    patched=ordinary_pond_build(output,project,patched)\n',
        b'    from ordinary_implicit_pond_switch import metadata as ordinary_pond_metadata\n    ordinary_pond=ordinary_pond_metadata(project)\n    if ordinary_pond is not None:build_identity[\'ordinary_implicit_pond_switch\']=ordinary_pond\n'):
        assert source.count(addition)==1
        source=source.replace(addition,b'',1)
    assert source==parent
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
           exact_host_parent=PARENT,exact_host_addition_lines=5,cases={},fresh_full_periods=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    names=[f'secondary-primary-postimage-cde-{a.optimization}-v1',f'secondary-pond-full-water-{a.optimization}-v1',
           'secondary-explicit-off-'+('water-O0' if a.optimization=='O0' else 'automatic-O2')+'-v1']
    save()
    try:
        for index,name in enumerate(names):
            prior=a.evidence/name;before=json.loads((prior/'RESULT.json').read_text());params=before['parameters']
            days=min(6,params['days']);out=a.output/str(index)
            command=[sys.executable,'-B',str(ROOT/'tests/nomacro_drainage/calendar_runtime.py'),
                '--case',params['case'],'--mode',params['mode'],'--format',str(params['format']),
                '--hysteresis',str(params['hysteresis']),'--days',str(days),'--optimization',a.optimization,
                '--reference-work',str(a.reference_work),'--build-root',str(a.build_root/str(index)),
                '--output',str(out)]
            for field,flag in [('implicit','--implicit'),('water_only','--water-only')]:
                if params.get(field):command.append(flag)
            run=subprocess.run(command,cwd=ROOT,capture_output=True,text=True,timeout=240)
            (a.output/(str(index)+'.stdout')).write_text(run.stdout)
            (a.output/(str(index)+'.stderr')).write_text(run.stderr)
            run.check_returncode()
            now=json.loads((out/'RESULT.json').read_text());oldbuild=Path(before['build_root']);newbuild=Path(now['build_root'])
            old=json.loads((oldbuild/'BUILD.json').read_text());new=json.loads((newbuild/'BUILD.json').read_text())
            assert 'ordinary_implicit_pond_switch' not in new['identity']
            assert {v.name:v.read_bytes() for v in oldbuild.glob('*.f90')}=={v.name:v.read_bytes() for v in newbuild.glob('*.f90')}
            assert old['inputs']==new['inputs'] and old['project']==new['project']
            delta=differences(old['identity'],new['identity'])
            assert set(delta)<={'host','restart_publisher.library_sha256'},delta
            assert new['identity']['host']==runtime.m.sha(ROOT/'app/hybrid_water/daily_host.py')
            oldhost=subprocess.check_output(['git','show',before['source']+':app/hybrid_water/daily_host.py'],cwd=ROOT)
            assert oldhost==parent and old['identity']['host'] in {hashlib.sha256(v).hexdigest() for v in (oldhost,oldhost.replace(b'\n',b'\r\n'))}
            publisher=None
            if 'restart_publisher.library_sha256' in delta:
                for build,meta in ((oldbuild,old),(newbuild,new)):
                    assert runtime.m.sha(build/'restart_publish.dll')==meta['identity']['restart_publisher']['library_sha256']
                publisher=publisher_equivalence(oldbuild/'restart_publish.dll',newbuild/'restart_publish.dll')
            assert runtime.m.physical(runtime.m.rows(out/'trajectory'))==runtime.m.physical(runtime.m.rows(prior/'trajectory')[:days])
            for day in (2,4):
                with zipfile.ZipFile(prior/f'trajectory/accepted-column-1-day-{day}.zip') as left,zipfile.ZipFile(out/f'trajectory/accepted-column-1-day-{day}.zip') as right:
                    assert all(left.read(n)==right.read(n) for n in ('result.end','macro.bin'))
            science=implicit_forensics if params['implicit'] else history_forensics if params['hysteresis'] else calendar_forensics
            independent=science.audit_root(out)
            q['cases'][name]=dict(status='ACTUAL_NONSELECTED_INPUT_FORTRAN_KERNEL_PHYSICAL_NATIVE_PASS',
                current_profile=str(out),prior_profile=str(prior),actual_days=days,exact_native_days=[2,4],
                changed_identity_roles=delta,publisher=publisher,independent=independent,
                original_BUILD_sha256=runtime.m.sha(oldbuild/'BUILD.json'),current_BUILD_sha256=runtime.m.sha(newbuild/'BUILD.json'))
            save()
        q['status']='ACTUAL_THREE_NONSELECTED_OWNERS_POSTIMAGE_PASS'
    except Exception as error:
        q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
