"""Actual sparse original Grass groundwater input and changed-history recovery."""
import argparse
import contextlib
from dataclasses import replace
from datetime import date,timedelta
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import time
import traceback
import zipfile

ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'app/hybrid_water'))
import daily_host as h
from daily_coupling import CoupledDailyColumn,GROUNDWATER_FORCING,CauchyDayForcing
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--workspace',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
p.add_argument('--opt',choices=['O0','O2'],action='append');p.add_argument('--probe',action='store_true')
p.add_argument('--reuse-leading',type=Path,help='Same-application successful leading probe, with original source report retained')
a=p.parse_args();a.output.mkdir();base=a.workspace;idx=json.loads((base/'PROOF_INDEX.json').read_text())
reference=base/idx['reference'];project=h.GRASSGROWTH;started=[];expired=[];real_start=h.start_process
def track(*args):
    proc,log=real_start(*args);started.append(proc);return proc,log
h.start_process=track
def stop():
    expired.append(True)
    for proc in started:
        if proc.poll() is None:proc.kill()
timer=threading.Timer(60 if a.probe else 240,stop);timer.daemon=True;timer.start();begin=time.monotonic()
report={'status':'RUNNING','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=ROOT,text=True).strip(),
 'sources':{n:h.sha(ROOT/n) for n in ['app/hybrid_water/daily_coupling.py','research/hybrid-water01/qualify_grass_groundwater.py']},'cases':[]}
def physical(r):return {k:v for k,v in r.items() if k not in ('column','revision','coupling','committed','candidate_only')}
def payload(p):
    with zipfile.ZipFile(p) as z:return {n:z.read(n) for n in h.CHECKPOINT_FILES}
def reject(fn,exceptions=(ValueError,TypeError)):
    try:fn()
    except exceptions:return
    raise AssertionError('Invalid forcing/decision accepted')

try:
    for opt in a.opt or ['O0','O2']:
        native=idx['cases']['grass-'+opt];bundle=base/native['build'];meta=json.loads((base/native['report']/'BUILD.json').read_text())
        for name in ['day_donor','day_kernel']:
            if os.name!='nt':h.executable(bundle,name).chmod(0o755)
        source_case=reference/'distribution/SWAP_4.3.1/cases'/project.case
        original=(source_case/'swap.bbc').read_text(encoding='cp1252')
        table=[(date.fromisoformat(d),float(v)) for d,v in re.findall(r'(?m)^\s*(\d{4}-\d{2}-\d{2})[ \t]+([-+0-9.]+)[ \t]*$',original)]
        def level(day):
            stamp=date.fromisoformat(project.start_date)+timedelta(days=day)
            if stamp<=table[0][0]:return table[0][1]
            for (d0,v0),(d1,v1) in zip(table,table[1:]):
                if stamp<=d1:return v0+(v1-v0)*(stamp-d0).days/(d1-d0).days
            return table[-1][1]
        optroot=a.output/opt;optroot.mkdir();day2=base/native['continuous']/'accepted-column-1-day-2.zip'
        original_hash=h.sha(day2);origins={2:day2}
        cuts=[2] if a.probe else [2,(table[0][0]-date.fromisoformat(project.start_date)).days]
        for cut in cuts:
            out=optroot/f'window-{cut}-to-{cut+2}'
            previous=a.reuse_leading/opt/out.name if a.reuse_leading is not None else None
            if cut==2 and previous is not None and previous.exists():
                inherited=json.loads((a.reuse_leading/'RESULT.json').read_text())
                assert inherited['status']=='GRASS_ORIGINAL_PRESCRIBED_GROUNDWATER_CHANGED_HISTORY_RETRY_RECOVERY_PASS'
                assert inherited['sources']['app/hybrid_water/daily_coupling.py']==report['sources']['app/hybrid_water/daily_coupling.py']
                assert json.loads((a.reuse_leading/opt/'BUILD.json').read_text())==meta
                entry=next(c for c in inherited['cases'] if c['optimization']==opt and c['cut']==2)
                assert h.sha(previous/'external/accepted-column-1-day-4.zip')==entry['terminal_sha256']
                shutil.copytree(previous,out)
                (out/'INHERITED_CASE_REPORT.json').write_text(json.dumps(inherited,indent=2)+'\n')
                report.setdefault('inherited_probes',[]).append({'optimization':opt,'cut':2,'source_commit':inherited['source_commit'],
                    'report_sha256':h.sha(a.reuse_leading/'RESULT.json'),'application_source_sha256':inherited['sources']['app/hybrid_water/daily_coupling.py']})
                report['cases'].append(entry);print(opt,'leading actual probe inherited exactly',flush=True)
                continue
            out.mkdir()
            if cut not in origins:
                prefix=out/'warm-prefix';prefix.mkdir();unpacked=prefix/'origin'
                receipt=h.verify_checkpoint(day2,2,meta['binding'],unpacked)
                with contextlib.ExitStack() as stack:
                    host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),source_case,prefix,
                        [h.ColumnStart(day=2,origin=unpacked,receipt=receipt,name='original')],runtime=True,
                        checkpoint_enabled=True,binding=meta['binding'],project=project)
                    rows=[]
                    for day in range(3,cut+1):rows.append(host.step(1,checkpoint=day==cut))
                    host.close()
                (prefix/'daily.jsonl').write_text(''.join(json.dumps(r)+'\n' for r in rows))
                origins[cut]=prefix/f'accepted-column-1-day-{cut}.zip'
            origin=origins[cut];coupling=f'grass-level-{opt}-{cut}'
            c=CoupledDailyColumn(bundle,reference,out/'external',project,coupling,origin=origin,day=cut,
                                 adopt_native=True,forcing_mode=GROUNDWATER_FORCING)
            f=c.groundwater_forcing(level(cut),level(cut+1)+.001,'caller-first-day')
            state=(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
            for bad in [replace(f,coupling_id='foreign'),replace(f,origin_sha256='0'*64),replace(f,t0_day1900=f.t0_day1900+1),
                        replace(f,head_end_cm=float('nan')),replace(f,head_end_cm=1001),replace(f,head_start_cm=True),
                        replace(f,provenance=''),CauchyDayForcing(**f.document())]:
                reject(lambda:c.prepare(groundwater=bad));assert state==(c.day,c.revision,h.sha(c.checkpoint),c._attempt)
            reject(lambda:c.prepare());reject(lambda:c.prepare(cauchy=f))
            first=c.prepare(groundwater=f);first_data=payload(c._candidate[3]);first_row=first.budget
            copy=first.forcing;copy['input']['head_end_cm']=999;assert first.forcing['input']['head_end_cm']==f.head_end_cm
            reject(lambda:c.prepare(groundwater=f));c.discard(first)
            assert state[:3]==(c.day,c.revision,h.sha(c.checkpoint))
            retry=c.prepare(groundwater=f);assert retry.budget==first_row and payload(c._candidate[3])==first_data
            reject(lambda:c.accept(first));accepted=c.accept(retry);reject(lambda:c.prepare(groundwater=f))
            recovered=CoupledDailyColumn(bundle,reference,out/'recovered',project,coupling,origin=accepted,day=cut+1,
                                        forcing_mode=GROUNDWATER_FORCING)
            second=c.groundwater_forcing(f.head_end_cm,level(cut+2)+.002,'caller-second-day-after-modified-state')
            p1=c.prepare(groundwater=second);p2=recovered.prepare(groundwater=second)
            assert p1.budget==p2.budget and payload(c._candidate[3])==payload(recovered._candidate[3])
            # Independent full-original-table insertion, not the application writer.
            for step,request,parent,parent_binding,expected in [(0,f,origin,meta['binding'],first_row),
                    (1,second,accepted,c.binding,p1.budget)]:
                manual=out/f'manual-case-{step}';shutil.copytree(source_case,manual)
                text=original;header='      DATE1 GWLEVEL'
                assert header in text
                rows={d:line for line in text.splitlines() if (m:=re.match(r'\s*(\d{4}-\d{2}-\d{2})\s+[-+0-9.]',line)) for d in [m[1]]}
                start=date.fromisoformat(project.start_date)+timedelta(days=cut+step)
                for stamp,value in [(str(start),request.head_start_cm),(str(start+timedelta(days=1)),request.head_end_cm)]:
                    rows[stamp]=f' {stamp} {float(value)!r}'
                top=text.index(header)+len(header);bottom=text.index('* End of table',top)
                text=text[:top]+'\n'+'\n'.join(rows[d] for d in sorted(rows))+'\n'+text[bottom:]
                (manual/'swap.bbc').write_text(text,encoding='cp1252')
                direct=out/f'manual-control-{step}';direct.mkdir();unpacked=direct/'origin'
                receipt=h.verify_checkpoint(parent,cut+step,parent_binding,unpacked)
                with contextlib.ExitStack() as stack:
                    host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),manual,direct,
                        [h.ColumnStart(day=cut+step,origin=unpacked,receipt=receipt,name='original')],runtime=True,
                        checkpoint_enabled=True,binding={**meta['binding'],'manual_groundwater_control':h.sha(manual/'swap.bbc')},project=project)
                    raw=host.step(1,checkpoint=True);host.close()
                assert physical(raw)==physical(expected)
                wanted=first_data if step==0 else payload(c._candidate[3])
                assert payload(direct/f'accepted-column-1-day-{cut+step+1}.zip')==wanted
                (direct/'daily.jsonl').write_text(json.dumps(raw)+'\n')
            final=c.accept(p1);recovered.accept(p2)
            assert abs(first_row['independent_residual_cm'])<=1e-10 and abs(p1.budget['independent_residual_cm'])<=1e-10
            if cut==2:
                identity=CoupledDailyColumn(bundle,reference,out/'original-level-control',project,coupling+'-identity',
                    origin=origin,day=cut,adopt_native=True,forcing_mode=GROUNDWATER_FORCING)
                expected=[json.loads(l) for l in (base/native['resumed']/'daily.jsonl').read_text().splitlines()]
                for i in range(2):
                    q=identity.prepare(groundwater=identity.groundwater_forcing(level(cut+i),level(cut+i+1),'original-clamped-level'))
                    assert physical(q.budget)==physical(expected[i]);identity.accept(q)
                assert payload(identity.checkpoint)=={n:(base/native['resumed']/'original'/n).read_bytes() for n in h.CHECKPOINT_FILES}
                assert physical(first_row)!=physical(expected[0]),'Prescribed level did not reach physics'
            assert h.sha(day2)==original_hash
            entry={'optimization':opt,'cut':cut,'end':cut+2,'origin_sha256':h.sha(origin),
                'exact_discard_retry_and_modified_history_recovery':True,'exact_independent_original_controls_both_days':True,
                'invalid_pretrial_cases':8,'first_forcing':f.document(),'second_forcing':second.document(),
                'first_bottom_outward_cm':first_row['bottom_outward_cm'],'terminal_sha256':h.sha(final)}
            report['cases'].append(entry);print(json.dumps(entry),flush=True)
        (optroot/'BUILD.json').write_text(json.dumps(meta,indent=2)+'\n')
    assert not expired
    report['status']='GRASS_ORIGINAL_PRESCRIBED_GROUNDWATER_CHANGED_HISTORY_RETRY_RECOVERY_PASS'
except BaseException:
    report.update(status='FAILED',traceback=traceback.format_exc());raise
finally:
    timer.cancel();report['censored']=bool(expired);report['elapsed_seconds']=time.monotonic()-begin
    (a.output/'RESULT.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
