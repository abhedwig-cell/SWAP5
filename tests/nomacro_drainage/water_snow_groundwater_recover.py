"""Reuse original nine binaries; rebuild only four affected day-tail forms."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[1]
ORIGINAL='53f9ede58285c77f5fe34d4120dbfab709b41488'
AFFECTED=('explicit-h0-daily','explicit-h1-interval-off','implicit-h0-interval-off','implicit-h2-daily')


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','original-root','build-root','scratch','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True);a=p.parse_args();a.output.mkdir();logs=a.output/'commands';logs.mkdir()
    original=a.original_root/'water-snow-groundwater';old=original/'RESULT.json';before=hashlib.sha256(old.read_bytes()).hexdigest();prior=json.loads(old.read_text())
    assert prior['source']==ORIGINAL and prior['status']=='FAILED_OR_CENSORED' and prior['steps'][0]['status']=='PASS'
    assert len(prior['steps'])==2 and prior['steps'][1]['label']=='short-explicit-h0-daily'
    failed=json.loads((original/'short-explicit-h0-daily/RESULT.json').read_text());assert failed['status']=='FAILED_OR_CENSORED' and 'Rejected day 25' in failed['error']
    changed=subprocess.check_output(['git','diff','--name-only',ORIGINAL,'HEAD','--','app','src','reference','tools'],cwd=ROOT,text=True).splitlines()
    assert set(changed)=={'app/hybrid_water/snow_water_groundwater_build.py','app/hybrid_water/snow_water_groundwater_source_guard.py','app/hybrid_water/daily_coupling.py'},changed
    projection=json.loads((a.original_root/'COMPILED_PROJECTION_V1.json').read_text());assert len(projection)==9
    temp=Path(os.environ['RUNNER_TEMP']).resolve()
    for actual,item in projection.items():
        target=Path(actual);assert target.resolve().is_relative_to(temp/'builds')
        source=a.original_root/item['archive_prefix'];assert hashlib.sha256((source/'BUILD.json').read_bytes()).hexdigest()==item['actual_BUILD_sha256']
        shutil.copytree(source,target)
        for name in ('day_donor','day_kernel'):
            exe=target/name;digest=hashlib.sha256(exe.read_bytes()).hexdigest();assert exe.read_bytes().startswith(b'\x7fELF')
            exe.chmod(0o755);assert hashlib.sha256(exe.read_bytes()).hexdigest()==digest
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        original_run=44749932813,original_source=ORIGINAL,original_failed_producer_sha256=before,
        original_failed_jobs_preserved=True,affected_day_tail_contexts=list(AFFECTED),steps=[],
        fresh_unaffected_compilations=0,fresh_unaffected_full_replays=0,actual_short_profiles={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(label,script,args,cap):
        command=[sys.executable,'-B',str(HERE/script),*map(str,args)];step=dict(label=label,command=command,status='RUNNING');q['steps'].append(step);save();start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:r=subprocess.run(command,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            step['returncode']=r.returncode;r.check_returncode();step['status']='PASS'
        except Exception as error:step.update(status='FAILED_OR_CENSORED',error=repr(error));raise
        finally:step['seconds']=time.monotonic()-start;save()
    common=['--reference-work',a.reference_work]
    try:
        run('changed-source','water_snow_groundwater_source_probe.py',[*common,'--build-root',a.build_root,'--output',a.output/'changed-source',
            '--optimization',a.optimization,'--only-labels',*AFFECTED],900)
        oldprobe=original/'source-forms/RESULT.json';newprobe=a.output/'changed-source/RESULT.json'
        cases=json.loads(oldprobe.read_text())['cases'];assert len(cases)==9
        for label in cases:
            probe=newprobe if label in AFFECTED else oldprobe
            profile=a.output/('short-'+label);q['actual_short_profiles'][label]=str(profile)
            run('short-'+label,'water_snow_groundwater_period.py',[*common,'--source-probe',probe,'--label',label,'--output',profile],360)
            run('audit-short-'+label,'water_snow_groundwater_forensics.py',[profile,'--output',a.output/('INDEPENDENT_SHORT_'+label+'.json')],180)
        for label,cap in (('explicit-h2-clock',600),('implicit-h1-step-reset',1200),('explicit-h0-daily',600)):
            probe=newprobe if label in AFFECTED else oldprobe;profile=a.output/('full-'+label)
            run('full-'+label,'water_snow_groundwater_period.py',[*common,'--source-probe',probe,'--label',label,'--days',1096,'--cap',cap,'--output',profile],cap+720)
            run('audit-full-'+label,'water_snow_groundwater_forensics.py',[profile,'--output',a.output/('INDEPENDENT_FULL_'+label+'.json')],180)
        for label in ('explicit-h0-daily','implicit-h1-step-reset'):
            profile=a.output/('short-'+label)
            for role,script,extra,cap in (
                ('source-controls','water_snow_groundwater_source_controls.py',['--scratch',a.scratch/label],240),
                ('native-controls','water_snow_groundwater_native_controls.py',[],300),
                ('transactions','implicit_snow_transactions.py',[],180)):
                run(role+'-'+label,script,[*common,'--profile',profile,*extra,'--output',a.output/(role+'-'+label)],cap)
        assert hashlib.sha256(old.read_bytes()).hexdigest()==before
        q['status']='ACTUAL_WATER_SNOW_GROUNDWATER_DAY_TAIL_REPAIR_PORTABLE_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
