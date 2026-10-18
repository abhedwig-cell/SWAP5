#!/usr/bin/env python3
"""Resume native SWAP431 cell execution with explicit status and balance audits."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import csv
import datetime as dt
import hashlib
import json
import math
from pathlib import Path
import subprocess
import time

from collect_european_baseline import sha


def validate(case, contract):
    with (case/'result_output.csv').open() as handle:
        rows = list(csv.DictReader(line for line in handle if not line.startswith('*')))
    assert len(rows) == 1006
    assert all(r['DATE'] == (dt.date(2023,12,31)+dt.timedelta(days=i)).isoformat() for i,r in enumerate(rows))
    inactive = {'RUNON','DRN'}
    if contract['vegetation']['nhi_index'] is None:
        inactive.update(('TACT','EIC','IC_VOL'))
    incoming, outgoing = ('RAIN','IRRIG','SSDI','BOT','RUNON'), ('RUNOFF','EACT','EPD','TACT','EIC','DRN')
    def value(row,key):
        if key not in row:
            assert key in inactive, 'Missing active component '+key
            return 0.
        v = float(row[key]); assert math.isfinite(v), key
        return v
    def storage(row):
        return sum(value(row,key) for key in ('WTOT','PD_VOL','IC_VOL'))
    lower = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][0] for h in contract['layers'])
    upper = sum((h['bottom_cm']-h['top_cm'])*h['swap_mvg'][1] for h in contract['layers'])
    residuals, boundary_flags = [], []
    for previous, row in zip(rows,rows[1:]):
        assert lower-1e-4 <= value(row,'WTOT') <= upper+1e-4
        assert value(row,'PD_VOL') >= 0 and value(row,'IC_VOL') >= 0
        if 'TPOT' in row:
            assert value(row,'TACT') <= value(row,'TPOT')+1e-5
        residual = sum(value(row,k) for k in incoming)-sum(value(row,k) for k in outgoing)-storage(row)+storage(previous)
        # Eleven fluxes and six printed reservoir values, at half 1e-5cm precision.
        if abs(residual) > abs(value(row,'BALDEV'))+17*.0000051:
            # Do not label a native annual canopy/output accounting discontinuity
            # as a clean daily PASS. Retain a distinct flagged completed status,
            # only when the adjacent two-day ledger closes to printed precision.
            assert row['DATE'].endswith('01-01') and previous['DATE'].endswith('12-31'), (row['DATE'],residual)
            assert residuals and abs(residual+residuals[-1]) <= abs(value(row,'BALDEV'))+abs(value(previous,'BALDEV'))+34*.0000051
            boundary_flags.append(dict(date=row['DATE'],daily_printed_residual_mm=10*residual,
                                       previous_day_printed_residual_mm=10*residuals[-1],
                                       interpretation='Annual canopy/output accounting discontinuity; two-day closure checked; not a clean daily-balance PASS.'))
        residuals.append(residual)
    totals = {key+'_mm':10*math.fsum(value(r,key) for r in rows[1:]) for key in incoming+outgoing}
    assert abs(totals['RAIN_mm']-2216.6) < .001
    return dict(days=1005, **totals, storage_change_mm=10*(storage(rows[-1])-storage(rows[0])),
                period_printed_closure_mm=10*math.fsum(residuals),
                max_native_daily_baldev_mm=10*max(abs(value(r,'BALDEV')) for r in rows[1:]),
                max_printed_daily_closure_mm=10*max(map(abs,residuals)),
                year_boundary_accounting_flags=boundary_flags,
                eic_contract='Native EIC includes annual canopy capacity loss; not pure evaporation.')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('executable',type=Path)
    parser.add_argument('--workers',type=int,default=2)
    parser.add_argument('--smoke',action='store_true',help='Select one cell per land-cover/boundary class')
    parser.add_argument('--limit',type=int)
    parser.add_argument('--sample',type=int,help='Deterministic hash-selected spatial sample, plus one cell per present land-cover/boundary class')
    args=parser.parse_args();root=args.root.resolve();exe=args.executable.resolve()
    exe_hash=sha(exe)
    cells=list(csv.DictReader((root/'cell_register.csv').open()))
    active=[r for r in cells if r['status']=='PREPARED_INITIAL_V01']
    if args.smoke:
        groups={}
        for r in active:groups.setdefault((r['dominant_land_class'],r['boundary']),r)
        active=list(groups.values())
    elif args.sample:
        groups={}
        for r in active:groups.setdefault((r['dominant_land_class'],r['boundary']),r)
        selected=sorted(active,key=lambda r:hashlib.sha256(r['cell_id'].encode()).hexdigest())[:args.sample]
        active=list({r['cell_id']:r for r in selected+list(groups.values())}.values())
    if args.limit:active=active[:args.limit]
    def run(cell):
        case=root/'cells'/cell['cell_id'];contract=json.loads((case/'cell_manifest.json').read_text())
        inputs={name:sha(case/name) for name in contract['input_sha256']}
        assert inputs==contract['input_sha256'], f'Changed prepared inputs {case.name}'
        receipt=case/'run_receipt.json'
        previous=json.loads(receipt.read_text()) if receipt.exists() else {}
        reused=previous.get('status') in ('SUCCESS','COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG') and previous.get('executable_sha256')==exe_hash and previous.get('input_sha256')==inputs and all(
            (case/name).exists() and sha(case/name)==digest for name,digest in previous.get('output_sha256',{}).items())
        start=time.perf_counter()
        if reused:
            result=dict(previous,reused=True)
        else:
            with (case/'stdout.log').open('w') as stdout,(case/'stderr.log').open('w') as stderr:
                try:code=subprocess.run([str(exe)],cwd=case,stdout=stdout,stderr=stderr,timeout=120).returncode
                except subprocess.TimeoutExpired:code=-124
            log=(case/'swap.log').read_text() if (case/'swap.log').exists() else ''
            result=dict(cell_id=case.name,input_sha256=inputs,executable_sha256=exe_hash,
                        returncode=code,native_wall_seconds=time.perf_counter()-start,reused=False,
                        status='NATIVE_COMPLETED_PENDING_AUDIT' if code==100 and 'Swap simulation okay!' in log else 'FAILED_OR_TIME_CENSORED')
        receipt.write_text(json.dumps(result,indent=2)+'\n')
        if result['status'] in ('NATIVE_COMPLETED_PENDING_AUDIT','SUCCESS','COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG'):
            try:
                result['water_balance']=validate(case,contract);result['status']='SUCCESS'
                if result['water_balance']['year_boundary_accounting_flags']:
                    result['status']='COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG'
            except (AssertionError,ValueError,KeyError) as error:
                result.update(status='AUDIT_FAILED',audit_error=str(error))
        result['output_sha256']={name:sha(case/name) for name in ('result_output.csv','swap.log','stdout.log','stderr.log') if (case/name).exists()}
        receipt.write_text(json.dumps(result,indent=2)+'\n')
        print(case.name,result['status'],round(result['native_wall_seconds'],3),'reused='+str(reused),flush=True)
        return result
    started=time.perf_counter()
    with ThreadPoolExecutor(max_workers=args.workers) as pool:results=list(pool.map(run,active))
    status=dict(selected=len(results),successes=sum(r['status']=='SUCCESS' for r in results),
                completed_with_accounting_flag=sum(r['status']=='COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG' for r in results),
                reused=sum(r['reused'] for r in results),total_grid_cells=len(cells),
                open_water_cells=sum(r['status']=='OPEN_WATER_NO_SOIL_COLUMN' for r in cells),
                execution_wall_seconds=time.perf_counter()-started,executable_sha256=exe_hash,
                scope='INITIAL_V01_CELL_RUNS_NOT_LOCALLY_VALIDATED',runs=results)
    name='smoke_results.json' if args.smoke else f'sample{args.sample}_results.json' if args.sample else 'batch_results.json'
    (root/name).write_text(json.dumps(status,indent=2)+'\n')
    execution=[]
    for cell in cells:
        path=root/'cells'/cell['cell_id'];receipt=path/'run_receipt.json'
        record=dict(cell_id=cell['cell_id'],landcover_class=cell['dominant_land_class'],
                    boundary=cell['boundary'],execution_status='NOT_RUN',returncode='',native_wall_seconds='')
        if receipt.exists():
            r=json.loads(receipt.read_text());m=json.loads((path/'cell_manifest.json').read_text())
            valid=r.get('input_sha256')==m['input_sha256'] and r.get('executable_sha256')==exe_hash
            record.update(execution_status=r['status'] if valid else 'STALE_RECEIPT_INPUT_CHANGED',
                          returncode=r['returncode'],native_wall_seconds=r['native_wall_seconds'])
        if cell['status']=='OPEN_WATER_NO_SOIL_COLUMN':record['execution_status']='OPEN_WATER_NO_SOIL_COLUMN'
        execution.append(record)
    with (root/'execution_register.csv').open('w',newline='') as handle:
        writer=csv.DictWriter(handle,fieldnames=list(execution[0]));writer.writeheader();writer.writerows(execution)
    totals={s:sum(r['execution_status']==s for r in execution) for s in sorted({r['execution_status'] for r in execution})}
    (root/'execution_summary.json').write_text(json.dumps(dict(total_grid_cells=len(cells),status_counts=totals,
        executable_sha256=exe_hash,full_grid_complete=all(r['execution_status'] in ('SUCCESS','COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG','OPEN_WATER_NO_SOIL_COLUMN') for r in execution)),indent=2)+'\n')
    print(json.dumps({k:v for k,v in status.items() if k!='runs'}),flush=True)
    if status['successes']+status['completed_with_accounting_flag']!=len(results):raise SystemExit(1)


if __name__=='__main__':main()
