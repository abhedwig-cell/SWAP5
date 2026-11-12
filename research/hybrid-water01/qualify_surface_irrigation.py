"""Real existing surface-event consumer on current no-macro native bundles.

Fresh bounded origins, original-table controls and changed-history transactions;
no rebinding of old native packages and no repeated complete historical campaign.
"""
import argparse
import contextlib
from dataclasses import replace
from datetime import date, timedelta
import json
from pathlib import Path
import re
import subprocess
import sys
import threading
import time
import traceback
import shutil
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn, IRRIGATION_FORCING, SURFACE_IRRIGATION_FORCING
from irrigation_forcing import build_bundle

p=argparse.ArgumentParser(description=__doc__)
for name in ['reference','bundle','controls','output']:p.add_argument('--'+name,type=Path,required=True)
p.add_argument('--project',choices=['hupsel','saltfarm'],required=True)
p.add_argument('--resume',action='store_true',help='Reuse exact built producer, original prefix and already passed scenarios; retain failed report')
a=p.parse_args();a.output.mkdir(exist_ok=a.resume);project={'hupsel':h.HUPSEL,'saltfarm':h.SALTFARM}[a.project]
workers=[];start=h.start_process;events=[]
def track(*args):
    process,log=start(*args);workers.append(process);return process,log
h.start_process=track

@contextlib.contextmanager
def bounded(label):
    begin=time.monotonic();expired=[]
    def stop():
        expired.append(True)
        for process in workers:
            if process.poll() is None:process.kill()
    timer=threading.Timer(60,stop);timer.daemon=True;timer.start()
    try:
        yield
        assert not expired,'Selected60second model cap exceeded'
    finally:
        timer.cancel();events.append(dict(label=label,seconds=time.monotonic()-begin,censored=bool(expired)))

def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision','coupling','committed','candidate_only')}
def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn):
    try:fn()
    except (ValueError,TypeError):return
    raise AssertionError('Invalid surface-event request accepted')

report=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True,cwd=ROOT).strip(),
    project=a.project,sources={n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py',
        'app/hybrid_water/irrigation_forcing.py','research/hybrid-water01/qualify_surface_irrigation.py']},cases=[])

try:
    if a.resume:
        prior=json.loads((a.output/'RESULT.json').read_text())
        (a.output/('FAILED-'+prior['source_commit']+'.json')).write_text(json.dumps(prior,indent=2)+'\n')
        report['cases']=prior['cases'];report['inherited_bounded_controls_source']=prior['source_commit']
        from daily_coupling import validate_bundle
        validate_bundle(a.output/'build',a.reference,project)
    begin=time.monotonic();bundle=a.output/'build' if a.resume else build_bundle(a.bundle,a.reference,a.output/'build',project=project)
    events.append(dict(label='incremental-compile-link',seconds=time.monotonic()-begin,censored=False))
    meta=json.loads((bundle/'BUILD.json').read_text());case=a.reference/'distribution/SWAP_4.3.1/cases'/project.case
    for name in ['day_donor','day_kernel']:
        if sys.platform!='win32':h.executable(bundle,name).chmod(0o755)
    def direct(source,out,last,checkpoints):
        out.mkdir();rows=[]
        with bounded(out.name),contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),source,out,
                [h.ColumnStart(name='original')],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
            for day in range(1,last+1):rows.append(host.step(1,checkpoint=day in checkpoints))
            host.close()
        (out/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
        return rows
    last=733 if project==h.SALTFARM else 7
    cuts=[107,731] if project==h.SALTFARM else [4]
    baseline=([json.loads(l) for l in (a.output/'no-file-original/daily.jsonl').read_text().splitlines()] if a.resume else
        direct(case,a.output/'no-file-original',last,{*cuts,*(c+1 for c in cuts),last}))
    original=[json.loads(l) for l in (a.controls/'daily.jsonl').read_text().splitlines()]
    assert list(map(physical,baseline))==list(map(physical,original[:last]))
    if project==h.SALTFARM:
        native=a.bundle/'own-731-733/accepted-column-1-day-733.zip';saved=733
    else:native=a.bundle/'gift-seven/accepted-column-1-day-5.zip';saved=5
    assert payload(a.output/'no-file-original'/f'accepted-column-1-day-{saved}.zip')==payload(native)
    report['no_file_original_preservation']=dict(days=last,all_physical_records_exact=True,native_exact_at_day=saved)
    windows=[(cuts[0],s,SURFACE_IRRIGATION_FORCING) for s in ['identity','modified','disabled']]
    if project==h.SALTFARM:windows += [(731,s,SURFACE_IRRIGATION_FORCING) for s in ['identity','modified']]
    else:windows += [(4,s,IRRIGATION_FORCING) for s in ['identity','modified','disabled']]
    for cut,scenario,mode in windows:
        if any((c['cut'],c['scenario'],c['mode'])==(cut,scenario,mode) for c in report['cases']):continue
        name=f'{cut}-{scenario}-'+('legacy' if mode==IRRIGATION_FORCING else 'shared');out=a.output/name
        if out.exists():out=a.output/(name+'-retry-'+report['source_commit'][:9])
        out.mkdir()
        origin=a.output/'no-file-original'/f'accepted-column-1-day-{cut}.zip';origin_hash=h.sha(origin)
        cid='surface-'+a.project+'-'+name
        def column(target,coupling=cid,origin=origin,day=cut,adopt=True):
            return CoupledDailyColumn(bundle,a.reference,target,project,coupling,origin=origin,day=day,adopt_native=adopt,forcing_mode=mode)
        c=column(out/'external');other=column(out/'independent',cid+'-other')
        winter=cut==731
        base=(0.,0.,0.) if winter else ((14.4,.401,14.4/24) if project==h.SALTFARM else (24.,20.,12.))
        values=base if scenario=='identity' else ((0.,0.,0.) if scenario=='disabled' else
             ((.02,1.,.02/24) if winter else ((14.401,.402,14.401/24) if project==h.SALTFARM else (24.001,20.001,12.))))
        f=c.irrigation_forcing(*values,'caller-first',enabled=values[0]>0)
        before=(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
        for bad in [replace(f,coupling_id='foreign'),replace(f,origin_sha256='0'*64),replace(f,t0_day1900=f.t0_day1900+1),
                    replace(f,depth_mm=float('nan')),replace(f,rate_mm_h=0.,enabled=True),replace(f,depth_mm=True),
                    replace(f,enabled=1),replace(f,provenance=''),replace(f,concentration_mg_cm3=1001.)]:
            reject(lambda:c.prepare(irrigation=bad));assert before==(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
        reject(lambda:c.prepare());reject(lambda:c.prepare(groundwater=f))
        with bounded(name+'-transactions'):
            first=c.prepare(irrigation=f);row=first.budget;state=payload(c._candidate[3]);c.discard(first)
            assert before[:3]==(c.day,c.revision,h.sha(c.checkpoint))
            q=other.prepare(irrigation=other.irrigation_forcing(*values,'other',enabled=values[0]>0))
            assert physical(q.budget)==physical(row) and payload(other._candidate[3])==state
            retry=c.prepare(irrigation=f);assert retry.budget==row and payload(c._candidate[3])==state
            reject(lambda:c.accept(first));accepted=c.accept(retry);other.accept(q)
            recovered=column(out/'recovered',origin=accepted,day=cut+1,adopt=False)
            if scenario=='identity':second=base if not winter else (0.,0.,0.)
            else:second=(.02,1.,.02/24 if project==h.SALTFARM else 1.)
            # Original Hupsel has no event on day6.
            if project==h.HUPSEL and scenario=='identity':second=(0.,0.,0.)
            req=c.irrigation_forcing(*second,'caller-second',enabled=second[0]>0)
            stable=(c.day,c.revision,h.sha(c.checkpoint))
            try:live=c.prepare(irrigation=req)
            except ValueError as error:
                if not (winter and scenario=='modified' and 'unchanged1e-10 mass guard' in str(error)):raise
                assert stable==(c.day,c.revision,h.sha(c.checkpoint)) and c._pending is None
                try:recovered.prepare(irrigation=req)
                except ValueError as disk_error:
                    assert 'unchanged1e-10 mass guard' in str(disk_error)
                else:raise AssertionError('Disk recovery changed original mass refusal')
                assert not (out/'external'/f'accepted-column-1-day-{cut+2}.zip').exists()
                report.setdefault('refusals',[]).append(dict(cut=cut,scenario=scenario,mode=mode,
                    status='REFUSED_UNCHANGED_ORIGINAL_MASS_GUARD',live_and_disk_refusal_exact=True,
                    accepted_origin_unchanged=True,first=f.document(),second=req.document(),
                    qualified_changed_winter_history=False))
                print(a.project,name,'REFUSED_ORIGINAL_MASS_GUARD',flush=True)
                continue
            disk=recovered.prepare(irrigation=req)
            assert live.budget==disk.budget and payload(c._candidate[3])==payload(recovered._candidate[3])
            final=c.accept(live);recovered.accept(disk)
        if scenario=='identity':
            assert physical(row)==physical(baseline[cut]) and physical(live.budget)==physical(baseline[cut+1])
        else:
            # Independent original fixed-event table, from initial input/state;
            # no request file or caller-consumer branch is exercised here.
            manual=out/'manual-original-input';shutil.copytree(case,manual)
            swp=manual/'swap.swp';source=swp.read_text(encoding='cp1252')
            header=next(l for l in source.splitlines() if l.strip().startswith('IRDATE '));rate_column='IRRATE' in header.upper()
            lines=source.splitlines(keepends=True);start_index=next(i for i,l in enumerate(lines) if l.strip().startswith('IRDATE '))+1
            end_index=start_index
            while end_index<len(lines) and re.match(r'\s*\d{4}-\d{2}-\d{2}\s',lines[end_index]):end_index+=1
            table=''.join(lines[start_index:end_index])
            for offset,vals in [(cut,values),(cut+1,second)]:
                stamp=str(date.fromisoformat(project.start_date)+timedelta(days=offset))
                entry='' if vals[0]==0 else ' '+stamp+' '+repr(vals[0])+' '+repr(vals[1])+' 1'+(' '+repr(vals[2]) if rate_column else '')+'\n'
                pattern=rf'(?m)^[ \t]*{stamp}[ \t]+[^\r\n]*\r?\n'
                table,count=re.subn(pattern,entry,table);assert count<=1
                if not count and entry:table+=entry
            lines[start_index:end_index]=sorted(table.splitlines(keepends=True),key=lambda l:l.split()[0])
            swp.write_text(''.join(lines),encoding='cp1252')
            independent=direct(manual,out/'independent-original-control',cut+2,{cut+2})
            assert physical(row)==physical(independent[cut]),'First original-input control differs'
            assert physical(live.budget)==physical(independent[cut+1]),'Second original-input control differs'
            assert physical(row)!=physical(baseline[cut]),'Caller did not affect physical state'
        assert h.sha(origin)==origin_hash
        for r in [row,live.budget]:
            assert abs(r['independent_residual_cm'])<=1e-10 and abs(r['solute_independent_residual_mg_cm2'])<=1e-10
        report['cases'].append(dict(cut=cut,scenario=scenario,mode=mode,first=f.document(),second=req.document(),
            discard_retry_native_exact=True,durable_changed_history_native_exact=True,interleaved_independent_native_exact=True,
            original_input_physical_control_exact=True,first_physical=physical(row),second_physical=physical(live.budget),final_sha256=h.sha(final)))
        print(a.project,name,'PASS',flush=True)
    report['status']='SURFACE_IRRIGATION_NO_MACRO_TRANSACTION_AND_ORIGINAL_CONTROLS_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    for worker in workers:
        if worker.poll() is None:worker.kill()
        worker.wait(timeout=5)
    report['events']=events
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n')
