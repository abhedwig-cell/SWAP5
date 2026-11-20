"""Run selected actual Snow periods and immediately read their raw balances."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import time

HERE=Path(__file__).resolve().parent


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for name in ('reference-work','source-probe','output'):p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--days',type=int,choices=(35,1096),default=35)
    p.add_argument('--only-labels',nargs='+')
    a=p.parse_args();a.output.mkdir()
    source=json.loads(a.source_probe.read_text());labels=a.only_labels or list(source['cases'])
    assert not set(labels)-set(source['cases'])
    q=dict(status='RUNNING',original_source_probe=str(a.source_probe),days=a.days,cases={})
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n',encoding='utf-8')
    save()
    try:
        for label in labels:
            profile=a.output/label;cap=180 if a.days==35 else 1200
            command=[sys.executable,'-B',str(HERE/'snow_undrained_period.py'),
                '--reference-work',str(a.reference_work),'--source-probe',str(a.source_probe),
                '--label',label,'--output',str(profile),'--days',str(a.days),'--cap',str(cap)]
            start=time.monotonic()
            item=q['cases'][label]=dict(command=command,status='RUNNING');save()
            with (a.output/(label+'.stdout')).open('x') as stdout,(a.output/(label+'.stderr')).open('x') as stderr:
                result=subprocess.run(command,cwd=HERE.parents[1],stdout=stdout,stderr=stderr,timeout=cap+720)
            item.update(returncode=result.returncode,seconds=time.monotonic()-start);save();result.check_returncode()
            from snow_undrained_forensics import audit
            item['independent']=audit(profile);item['status']='INDEPENDENT_PASS';save()
            print(label,a.days,item['status'],flush=True)
        q['status']='ACTUAL_SELECTED_SNOW_UNDRAINED_PERIODS_AND_INDEPENDENT_BALANCES_PASS'
    except Exception as error:q.update(status='FAILED_OR_INCOMPLETE',error=repr(error));raise
    finally:save()


if __name__=='__main__':main()
