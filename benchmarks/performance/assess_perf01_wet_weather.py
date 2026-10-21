"""Use the incumbent flux assessment for the rain-only wet scenario."""
import csv
import hashlib
import json
from pathlib import Path
import runpy
import statistics
import sys

ROOT=Path(__file__).resolve().parents[2]
BASE=Path(sys.argv[1]).resolve()
owner=runpy.run_path(str(ROOT/'benchmarks/performance/assess_perf01_weather.py'))
read=owner['read'];differences=owner['differences'];same=owner['same_physics']


def checked_failure(folder):
    r=json.loads((folder/'RESULT.json').read_text())
    assert r['status']=='FAILED_OR_CENSORED' and r['returncode']!=0 and not r['timed_out']
    for p,h in r['raw_sha256'].items():assert hashlib.sha256((folder/p).read_bytes()).hexdigest()==h
    assert r['completed_days']<97
    return r


if __name__=='__main__':
    ref,reference=read(BASE/'wet2-ref-2.5e-07')
    assert abs(ref['totals']['rain_mm']-454)<1e-10
    curves=[]
    for tol in [1e-6,.001,.01,.1,1.]:
        cases=[read(BASE/f'wet2-{tol:g}-r{rep}') for rep in range(3)]
        for _,r in cases[1:]:same(cases[0][1],r)
        r,rows=cases[0]
        curves.append(dict(head_budget_cm=tol,median_user_seconds=statistics.median(x['user_seconds'] for x,_ in cases),
            user_seconds=[x['user_seconds'] for x,_ in cases],
            median_core_cpu_seconds=statistics.median(x['core_cpu_seconds'] for x,_ in cases),
            metrics=r,differences_vs_fine=differences(rows,reference),
            maximum_reported_head_cm=max(x[f'head{i}_cm'] for x in rows for i in range(1,5)),
            days_top_head_above_minus_1cm=sum(x['head1_cm']>-1 for x in rows)))
    refinements=[]
    for tol in [1e-5,2.5e-6]:
        r,rows=read(BASE/f'wet2-ref-{tol:g}')
        refinements.append(dict(budget_cm=tol,metrics=r,differences_vs_fine=differences(rows,reference)))
    for tol in [.001,1.]:
        _,original=read(BASE/f'wet2-{tol:g}-r0');_,restored=read(BASE/f'wet2-restart-{tol:g}')
        same(original,restored)
    failures=[checked_failure(BASE/f'wet4-{tol:g}') for tol in [1e-6,1.]]
    summary=dict(status='COMPLETE_RAIN2X_CURVE_RAIN4X_FAILURES_RETAINED',
        baseline='a737c60596f7d77cf2415cb09c4181d35a8a25b5',
        scenario='Only daily precipitation doubled; same97days,30cm/four-cell geometry, live crop/heat, free drainage and64coupling intervals/day',
        curve=curves,reference=ref,refinements=refinements,wet4_failed_controls=failures,
        restart='All daily physical values, fluxes and deterministic work exact after same-process midpoint close/reconstruct at1e-3 and1cm',
        claim_ceiling='Modified meteorology is synthetic wet forcing, not observations. Certificate head-budget curve, not full-half equivalence. Completed2x arm remains inside existing flux-only boundary domain.')
    (BASE/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n')
    for r in curves:
        d=r['differences_vs_fine']
        print(r['head_budget_cm'],r['median_user_seconds'],d['storage_mm']['max_daily_abs'],d['bottom_mm']['total_difference'],d['transpiration_mm']['total_difference'],r['maximum_reported_head_cm'])
    print('PASS wet2x closure, exact repeats/reconstruction and rain input identity; wet4x failures retained')
