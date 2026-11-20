"""Finish only missing checks from immutable original run44732748938.

Original failed jobs and producers stay failed. No full/short models or compiler
executions are selected. Existing ELF/source bytes are restored without rebinding.
"""
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
ORIGINAL='03a8bcc4798726ca2e7980e95679c30f156f89c5'


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','original-root','scratch','output'):p.add_argument('--'+key,type=Path,required=True)
    p.add_argument('--optimization',choices=('O0','O2'),required=True)
    a=p.parse_args();a.output.mkdir();logs=a.output/'commands';logs.mkdir()
    assert not subprocess.check_output(['git','diff','--name-only',ORIGINAL,'HEAD','--','app','src','reference','tools'],cwd=ROOT)
    original=a.original_root/'implicit-snow';record=original/'RESULT.json';raw=record.read_bytes();prior=json.loads(raw)
    assert prior['source']==ORIGINAL and prior['optimization']==a.optimization and prior['status']=='FAILED_OR_CENSORED'
    assert prior['steps'][-1]['label']=='source-controls-water-head'
    assert all(step['status']=='PASS' for step in prior['steps'][:-1])
    error=(original/'commands/source-controls-water-head.stderr').read_text()
    assert 'FileNotFoundError' in error and 'source-refusals/water-head' in error
    temp=Path(os.environ['RUNNER_TEMP']).resolve();projection=json.loads((a.original_root/'COMPILED_PROJECTION_V1.json').read_text())
    assert len(projection)==9
    for actual,entry in projection.items():
        target=Path(actual);assert target.resolve().is_relative_to(temp/'builds')
        source=a.original_root/entry['archive_prefix'];assert hashlib.sha256((source/'BUILD.json').read_bytes()).hexdigest()==entry['actual_BUILD_sha256']
        shutil.copytree(source,target)
    q=dict(status='RUNNING',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
        original_run=44732748938,original_source=ORIGINAL,original_failed_producer_sha256=hashlib.sha256(raw).hexdigest(),
        original_failure_preserved=True,fresh_compilations=0,fresh_full_model_periods=0,fresh_short_model_periods=0,steps=[])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    def run(label,script,args,cap):
        cmd=[sys.executable,'-B',str(HERE/script),*map(str,args)];item=dict(label=label,command=cmd,status='RUNNING');q['steps'].append(item);save();start=time.monotonic()
        try:
            with (logs/(label+'.stdout')).open('x') as out,(logs/(label+'.stderr')).open('x') as err:
                r=subprocess.run(cmd,cwd=ROOT,stdout=out,stderr=err,timeout=cap)
            item['returncode']=r.returncode;r.check_returncode();item['status']='PASS'
        except Exception as e:item.update(status='FAILED',error=repr(e));raise
        finally:item['seconds']=time.monotonic()-start;save()
    try:
        for label in ('cde-groundwater-clock','cde-head-step'):
            run('missing-audit-full-'+label,'implicit_snow_forensics.py',[original/('full-'+label),'--output',a.output/('INDEPENDENT_FULL_'+label+'.json')],180)
        common=['--reference-work',a.reference_work]
        for label in ('water-head','cde-groundwater-clock','cde-head-step','cde-groundwater-interval'):
            profile=original/'short'/label
            run('source-controls-'+label,'implicit_snow_source_controls.py',[*common,'--profile',profile,
                '--scratch',a.scratch/label,'--output',a.output/('source-controls-'+label)],240)
            run('transactions-'+label,'implicit_snow_transactions.py',[*common,'--profile',profile,
                '--output',a.output/('transactions-'+label)],180)
        for label in ('water-head','cde-head-step'):
            run('native-controls-'+label,'implicit_snow_root_controls.py',[*common,'--profile',original/'short'/label,
                '--output',a.output/('native-controls-'+label)],300)
        assert record.read_bytes()==raw
        q['status']='ACTUAL_MISSING_IMPLICIT_SNOW_CONTROLS_ONLY_PASS'
    except Exception as error:q.update(status='FAILED',error=repr(error));raise
    finally:save()
    print(q['status'])


if __name__=='__main__':main()
