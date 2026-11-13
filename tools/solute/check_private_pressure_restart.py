"""Own source-bound research checkpoint test on the real SWAP5 daily host.
The private donor identity never becomes a supported BUILD or foreign restart.
"""
import argparse,contextlib,json,shutil,sys,threading,time,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
p=argparse.ArgumentParser(description=__doc__)
for n in ('probe','reference','bundle','output'):p.add_argument('--'+n,type=Path,required=True)
p.add_argument('--cut',type=int,default=365);p.add_argument('--last',type=int,default=637)
a=p.parse_args();a.output=a.output.resolve();a.output.mkdir();donor=h.executable(a.probe/'observer','diagnostic');kernel=h.executable(a.bundle,'day_kernel');meta=json.loads((a.bundle/'BUILD.json').read_text());publisher=meta['identity']['restart_publisher']
library='restart_publish.dll' if sys.platform=='win32' else 'restart_publish.so';shutil.copyfile(a.bundle/library,donor.parent/library)
binding={'research_only':'DAILY_NOMINAL_OWN_RESTART_NOT_PRODUCTION','donor_sha256':h.sha(donor),'kernel_sha256':h.sha(kernel),'timecontrol_sha256':h.sha(donor.parent/'timecontrol.f90'),'build':{'restart_publisher':publisher}}
(a.output/'BINDING.json').write_text(json.dumps(binding,indent=2)+'\n');case=h.project_case(a.reference,h.HUPSEL)
expected=json.loads((a.probe/'FRAMES.json').read_text());results={};physical=lambda x:{k:v for k,v in x.items() if k not in ('column','revision')}
for label,first in [('full',0),('resumed',a.cut)]:
    directory=a.output/label;directory.mkdir();origin=None;receipt=None
    if first:origin=a.output/'verified-origin';receipt=h.verify_checkpoint(a.output/'full'/f'accepted-column-1-day-{first}.zip',first,binding,origin)
    rows=[];workers=[];real_start=h.start_process
    def start(*args,**kw):
        pair=real_start(*args,**kw);workers.append(pair[0]);return pair
    h.start_process=start;timer=threading.Timer(60,lambda:[q.kill() for q in workers if q.poll() is None]);beg=time.perf_counter();timer.start()
    try:
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,donor,kernel,case,directory,[h.ColumnStart(day=first,origin=origin,receipt=receipt)],checkpoint_enabled=True,runtime=True,binding=binding,project=h.HUPSEL)
            with (directory/'daily.jsonl').open('w') as f:
                for day in range(first+1,a.last+1):
                    row=host.step(1,checkpoint=day in (a.cut,a.last));rows.append(row);f.write(json.dumps(row)+'\n');f.flush()
                    assert row['committed'] and abs(row['independent_residual_cm'])<=1e-10 and abs(row['kernel_residual_cm'])<=1e-10 and abs(row['solute_independent_residual_mg_cm2'])<=1e-10,day
                    assert row['pressure_head_cm']==expected['PS_HEAD'][day],('private_native_vs_daily_host',day)
            host.close()
    finally:timer.cancel();h.start_process=real_start
    results[label]={'rows':rows,'model_and_host_seconds':time.perf_counter()-beg}
assert list(map(physical,results['resumed']['rows']))==list(map(physical,results['full']['rows'][a.cut:]))
with zipfile.ZipFile(a.output/'full'/f'accepted-column-1-day-{a.last}.zip') as x,zipfile.ZipFile(a.output/'resumed'/f'accepted-column-1-day-{a.last}.zip') as y:
    assert all(x.read(n)==y.read(n) for n in h.CHECKPOINT_FILES)
result={'status':'PRIVATE_REAL_DAILY_HOST_OWN_RESTART_EXACT','cut':a.cut,'end':a.last,'exact_all_physical_suffix':True,'exact_terminal_native_auxiliary':True,'binding':binding,'times':{k:v['model_and_host_seconds'] for k,v in results.items()},'production_qualification':False}
(a.output/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result),flush=True)
