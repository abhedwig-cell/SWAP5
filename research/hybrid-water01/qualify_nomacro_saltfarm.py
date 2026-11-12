"""Real SaltFarm original-workbook trajectory and bound own continuation proof.

Donor physics is O2; optimization selects the actual SWAP5 transaction kernel.
Each model call has a60s cap. This does not qualify scientific equivalence or
full conservative energy. Generated input provenance is part of BUILD.json.
"""
import argparse
import contextlib
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import threading
import time
import zipfile

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import validate_bundle


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--optimization',choices=['O0','O2'],required=True)
    p.add_argument('--resume-proof',action='store_true',help='Validate and audit existing exact build/full/own results; no repeated model calls')
    a=p.parse_args();a.output=a.output.resolve();a.reference=a.reference.resolve()
    profile=dict(budget_retry=True,shared_pond_transfer=False,refresh_macro_final=False)
    started=time.perf_counter()
    if a.resume_proof:
        meta,case=validate_bundle(a.output,a.reference,h.SALTFARM)
        identity=meta['identity'];inputs=meta['inputs']
        assert identity['kernel_flags'][0]=='-'+a.optimization
        donor=h.executable(a.output,'day_donor');kernel=h.executable(a.output,'day_kernel')
    else:
        a.output.mkdir()
        donor,kernel,case,inputs,identity=h.build(a.reference,a.output,runtime_checkpoint=True,
            kernel_opt=a.optimization,project=h.SALTFARM,**profile)
    prior_report=json.loads((a.output/'RESULT.json').read_text()) if a.resume_proof and (a.output/'RESULT.json').exists() else {}
    compile_seconds=prior_report.get('compile_seconds') if a.resume_proof else time.perf_counter()-started
    binding=h.checkpoint_identity(inputs,identity,project=h.SALTFARM,**profile)
    project={k:getattr(h.SALTFARM,k) for k in ['case','model','start_date','nodes','water_tolerance']}
    (a.output/'BUILD.json').write_text(json.dumps(dict(project=project,inputs=inputs,identity=identity,binding=binding,
        executable_sha256=dict(donor=h.sha(donor),kernel=h.sha(kernel))),indent=2)+'\n')
    validate_bundle(a.output,a.reference,h.SALTFARM)
    events=json.loads((a.output/'EVENTS.json').read_text()) if a.resume_proof else []
    workers=[];actual=h.start_process
    def track(*args,**kwargs):
        process,log=actual(*args,**kwargs);workers.append(process);return process,log
    h.start_process=track
    @contextlib.contextmanager
    def bounded(label):
        expired=threading.Event();started=time.perf_counter()
        def stop():
            expired.set()
            for process in workers:
                if process.poll() is None:process.kill()
        timer=threading.Timer(60,stop);timer.start()
        try:
            yield
            assert not expired.is_set(),'Model wall cap reached'
            events.append(dict(case=label,status='PASS',seconds=time.perf_counter()-started))
        except Exception as error:
            events.append(dict(case=label,status='FAILED',error=repr(error),censored=expired.is_set(),seconds=time.perf_counter()-started))
            raise
        finally:
            timer.cancel()
            (a.output/'EVENTS.json').write_text(json.dumps(events,indent=2)+'\n')
    physical=lambda r:{k:v for k,v in r.items() if k not in ('column','revision')}
    windows=[(2,4),(107,110),(365,367),(731,733),(1459,1461)]
    full=a.output/'full';rows=[]
    try:
        if a.resume_proof:
            assert any(e['case']=='full1461' and e['status']=='PASS' for e in events)
            rows=[json.loads(line) for line in (full/'daily.jsonl').read_text().splitlines()]
        else:
            full.mkdir()
            with bounded('full1461'),contextlib.ExitStack() as stack:
                host=h.DailyHost(stack,donor,kernel,case,full,[h.ColumnStart()],checkpoint_enabled=True,
                    runtime=True,binding=binding,project=h.SALTFARM)
                with (full/'daily.jsonl').open('w') as journal:
                    for day in range(1,1462):
                        row=host.step(1,checkpoint=day in {d for w in windows for d in w})
                        journal.write(json.dumps(row)+'\n');journal.flush();rows.append(row)
                        assert row['committed'],row
                host.close()
        assert [r['day'] for r in rows]==list(range(1,1462))
        for r in rows:
            assert len(r['pressure_head_cm'])==195 and all(map(math.isfinite,r['pressure_head_cm']))
            assert max(abs(r['kernel_residual_cm']),abs(r['independent_residual_cm']))<=1e-10
            assert abs(r['solute_independent_residual_mg_cm2'])<=1e-10
        restart=[]
        for cut,end in windows:
            out=a.output/f'own-{cut}-{end}';origin=out/'origin'
            if not a.resume_proof:
                out.mkdir()
                receipt=h.verify_checkpoint(full/f'accepted-column-1-day-{cut}.zip',cut,binding,origin)
                with bounded(out.name):
                    result=h.run(donor,kernel,case,out,end,checkpoint_day=cut,origin=origin,origin_receipt=receipt,
                        runtime=True,publish_day=end,checkpoint_binding=binding,project=h.SALTFARM)
                assert result['first_refusal'] is None
            else:
                assert any(e['case']==out.name and e['status']=='PASS' for e in events)
            actual_rows=[json.loads(line) for line in (out/'daily.jsonl').read_text().splitlines()]
            assert [r['day'] for r in actual_rows]==list(range(cut+1,end+1)) and all(r['committed'] for r in actual_rows)
            exact=list(map(physical,actual_rows))==list(map(physical,rows[cut:end]))
            with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as reference:
                payloads={name:reference.read(name)==(out/'original'/name).read_bytes() for name in h.CHECKPOINT_FILES}
            restart.append(dict(cut=cut,end=end,physical_receipts_exact=exact,payloads_exact=payloads,
                maximum_pressure_delta_cm=max(abs(x-y) for r,s in zip(actual_rows,rows[cut:end]) for x,y in zip(r['pressure_head_cm'],s['pressure_head_cm']))))
        if a.resume_proof:
            log=(a.output/'isolation-refusal/kernel.stdout').read_text()
            assert prior_report['interleaved_instances_and_refused_accepted_state']=='PASS'
            assert any(e['case']=='isolation-refusal' and e['status']=='PASS' for e in events)
            assert 'DAILY_REFUSED 1 3 2 ' in log and 'DAILY_ACCEPTED 2 3 3 ' in log
        else:
            out=a.output/'isolation-refusal';out.mkdir()
            with bounded(out.name),contextlib.ExitStack() as stack:
                host=h.DailyHost(stack,donor,kernel,case,out,[h.ColumnStart(name='one'),h.ColumnStart(name='two')],runtime=True,project=h.SALTFARM)
                for day in (1,2):
                    for col in (2,1):assert physical(host.step(col))==physical(rows[day-1])
                prior={k:copy.deepcopy(getattr(host.columns[0],k)) for k in ('day','revision','stocks','pressure','solute_stock')};send=h.send
                def corrupt(process,text):
                    values=text.split()
                    if process is host.host and len(values)==12+195:
                        values[2]=str(float(values[2])+0.01);text=' '.join(values)
                    send(process,text)
                h.send=corrupt
                try:assert not host.step(1)['committed']
                finally:h.send=send
                for key in ('day','revision','stocks','pressure','solute_stock'):assert getattr(host.columns[0],key)==prior[key]
                assert physical(host.step(2))==physical(rows[2]);host.close()
        report=dict(status='PASS' if all(r['physical_receipts_exact'] and all(r['payloads_exact'].values()) for r in restart) else 'FAIL_EXACT_OWN_RESTART',scope='Original-workbook SaltFarm1461; donorO2/kernel'+a.optimization,
            compile_seconds=compile_seconds,days=1461,source_commit=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
            maximum_water_residual_cm=max(abs(r['independent_residual_cm']) for r in rows),
            cumulative_water_residual_cm=math.fsum(r['independent_residual_cm'] for r in rows),
            maximum_solute_residual_mg_cm2=max(abs(r['solute_independent_residual_mg_cm2']) for r in rows),
            cumulative_solute_residual_mg_cm2=math.fsum(r['solute_independent_residual_mg_cm2'] for r in rows),
            budget_step_retries=sum(r['budget_step_retries'] for r in rows),restart=restart,
            interleaved_instances_and_refused_accepted_state='PASS',
            full_ledger_sha256=h.sha(full/'daily.jsonl'),build_sha256=h.sha(a.output/'BUILD.json'),
            scientific_equivalence='NOT_QUALIFIED',full_conservative_energy='NOT_QUALIFIED',R_byte_equivalence='NOT_CLAIMED')
        (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report))
        return int(report['status']!='PASS')
    finally:
        h.start_process=actual
        for process in workers:
            if process.poll() is None:process.kill()
            process.wait(timeout=5)


if __name__=='__main__':raise SystemExit(main())
