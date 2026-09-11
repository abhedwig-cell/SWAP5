#!/usr/bin/env python3
from __future__ import annotations
import csv, json, math, subprocess, sys
from pathlib import Path

EXE=Path(sys.argv[1]); OUT=Path(sys.argv[2])
RAW=OUT/'fgc07_raw_results.csv'
LEVELS=[0.5,0.25,0.125,0.0625,0.03125]
SYS=[0.20,0.05]

def load_raw():
    with RAW.open(newline='') as f:
        rows=list(csv.DictReader(f))
    for r in rows:
        for k in ('SY','DTC','FINAL_H_CM','CUM_QSWAP_CM','MAX_HEAD_RES_CM','MAX_SWAP_MASS_CM','INTERFACE_MASS_CM','R0_CM','R1_CM'):
            r[k]=float(r[k])
        for k in ('NINT','TRIALS','NONLINEAR','LINEAR','JAC','RETRIES'):
            r[k]=int(r[k])
    return rows

def pick(rows,sy,dt,scheme,nint):
    for r in rows:
        if abs(r['SY']-sy)<1e-14 and abs(r['DTC']-dt)<1e-14 and r['SCHEME']==scheme and r['NINT']==nint:
            return r
    raise SystemExit(f'missing raw row Sy={sy} dt={dt} {scheme} n={nint}')

def run_case(sy,dt,nint):
    p=subprocess.run([str(EXE),f'{sy:.17g}',f'{dt:.17g}',str(nint),'PC1'],text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=180)
    if p.returncode:
        print(p.stdout,file=sys.stderr); raise SystemExit('fine-internal decomposition run failed')
    line=next((x for x in p.stdout.splitlines() if x.startswith('FGC07_RESULT:')),None)
    if line is None: raise SystemExit('fine-internal result marker missing')
    d={}
    for token in line[len('FGC07_RESULT:'):].split(':'):
        k,v=token.split('=',1); d[k]=v.strip()
    ints={'NINT','TRIALS','NONLINEAR','LINEAR','JAC','RETRIES'}
    d={k:(int(v) if k in ints else (v if k=='SCHEME' else float(v))) for k,v in d.items()}
    if abs(d['INTERFACE_MASS_CM'])>1e-13 or d['MAX_SWAP_MASS_CM']>1e-10:
        raise SystemExit('fine-internal mass gate failed')
    return d

rows=load_raw(); out=[]
for sy in SYS:
    ref=pick(rows,sy,1/128,'PC4',1)
    for dt in LEVELS:
        n64=max(1,round(dt/(1/64)))
        n128=max(1,round(dt/(1/128)))
        pred=pick(rows,sy,dt,'PRED',n64)
        pc=pick(rows,sy,dt,'PC1',n64)
        fine=run_case(sy,dt,n128)
        pred_err=abs(pred['FINAL_H_CM']-ref['FINAL_H_CM'])
        pc_err=abs(pc['FINAL_H_CM']-ref['FINAL_H_CM'])
        fine_err=abs(fine['FINAL_H_CM']-ref['FINAL_H_CM'])
        internal_delta=abs(pc['FINAL_H_CM']-fine['FINAL_H_CM'])
        correction=abs(pred['FINAL_H_CM']-pc['FINAL_H_CM'])
        q_internal_delta=abs(pc['CUM_QSWAP_CM']-fine['CUM_QSWAP_CM'])
        q_fine_err=abs(fine['CUM_QSWAP_CM']-ref['CUM_QSWAP_CM'])
        rho=pc['R1_CM']/pc['R0_CM'] if pc['R0_CM']>0 else None
        out.append({
          'SY':sy,'DTC':dt,'NINT_1_64':n64,'NINT_1_128':n128,
          'PRED_HEAD_ERROR_REF_CM':pred_err,'PC1_HEAD_ERROR_REF_CM':pc_err,
          'PC1_FINE_INTERNAL_HEAD_ERROR_REF_CM':fine_err,
          'INTERNAL_1_64_TO_1_128_HEAD_DELTA_CM':internal_delta,
          'FINE_TOTAL_TO_INTERNAL_DELTA_RATIO':fine_err/internal_delta if internal_delta>0 else None,
          'PRED_PC1_HEAD_CORRECTION_CM':correction,
          'PC1_ERROR_OVER_PRED_PC1_CORRECTION':pc_err/correction if correction>0 else None,
          'PRED_ERROR_OVER_PRED_PC1_CORRECTION':pred_err/correction if correction>0 else None,
          'CORRECTOR_CONTRACTION_R1_OVER_R0':rho,
          'PC1_FINE_INTERNAL_FLUX_ERROR_REF_CM':q_fine_err,
          'INTERNAL_1_64_TO_1_128_FLUX_DELTA_CM':q_internal_delta,
          'PRED_TRIALS':pred['TRIALS'],'PC1_TRIALS':pc['TRIALS'],
          'PRED_LINEAR':pred['LINEAR'],'PC1_LINEAR':pc['LINEAR'],'PC1_FINE_LINEAR':fine['LINEAR']
        })

fields=list(out[0].keys())
with (OUT/'fgc07_error_decomposition.csv').open('w',newline='') as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(out)

summary={}
for sy in SYS:
    rr=[r for r in out if r['SY']==sy]
    summary[str(sy)]={
      'predictor_observed_first_order_supported': True,
      'pc1_fixed_higher_order_supported': False,
      'corrector_contraction_range':[min(r['CORRECTOR_CONTRACTION_R1_OVER_R0'] for r in rr),max(r['CORRECTOR_CONTRACTION_R1_OVER_R0'] for r in rr)],
      'fine_total_to_internal_delta_ratio_range':[min(r['FINE_TOTAL_TO_INTERNAL_DELTA_RATIO'] for r in rr),max(r['FINE_TOTAL_TO_INTERNAL_DELTA_RATIO'] for r in rr)],
      'pc1_error_over_predictor_corrector_head_difference_range':[min(r['PC1_ERROR_OVER_PRED_PC1_CORRECTION'] for r in rr),max(r['PC1_ERROR_OVER_PRED_PC1_CORRECTION'] for r in rr)],
      'predictor_error_over_predictor_corrector_head_difference_range':[min(r['PRED_ERROR_OVER_PRED_PC1_CORRECTION'] for r in rr),max(r['PRED_ERROR_OVER_PRED_PC1_CORRECTION'] for r in rr)]
    }

payload={
 'schema_version':1,'work_unit':'F-GC07','method_note':'Internal contribution is characterized by the 1/64-day versus 1/128-day SWAP-internal refinement difference at fixed coupling window. This is a numerical difference, not an exact additive error decomposition or physical truth.',
 'estimator_note':'Predictor-corrector head difference and fixed-point residual are candidate same-window signals. No universal coefficient or application tolerance is inferred from the two synthetic test classes.',
 'rows':out,'test_class_summary':summary,
 'adaptation_logic':{
   'shrink_window_when':['predictor-corrector correction grows relative to recent accepted windows','corrector fixed-point residual fails to contract or contraction degrades materially','additional corrector iteration is required by a separately qualified residual criterion','coupling-refinement signal exceeds the separately qualified application temporal allocation'],
   'grow_window_only_when':['same-window correction and residual contract consistently over successive accepted windows','independent SWAP temporal indicator remains within its own qualified policy','step-doubling or equivalent audit evidence remains in the characterized regime','growth is capped and reversible on the next failed/concerning indicator'],
   'forbidden':['using mass mismatch as a tolerance','assuming day boundaries','using an unqualified universal head threshold']
 },
 'A_temporal_application_coefficient':None
}
(OUT/'fgc07_error_decomposition.json').write_text(json.dumps(payload,indent=2,sort_keys=True)+'\n')
print(f'FGC07_DECOMPOSITION_RUNS={len(out)}')
print('FGC07_DECOMPOSITION_NO_APPLICATION_COEFFICIENT=PASS')
print('FGC07_DECOMPOSITION PASS')
