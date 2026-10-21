"""Recompute accepted flux, physical closure, repeat and refinement evidence."""
import csv
import hashlib
import json
from pathlib import Path
import statistics
import sys

BASE=Path(sys.argv[1]).resolve()
def read(folder):
    result=json.loads((folder/'RESULT.json').read_text())
    assert result['status']=='COMPLETE_NATIVE_OBSERVATION' and result['completed_days']==97
    assert result['returncode']==0 and not result['timed_out']
    for p,h in result['raw_sha256'].items():
        assert hashlib.sha256((folder/p).read_bytes()).hexdigest()==h,(folder,p)
    rows=[{k:float(v) for k,v in r.items()} for r in csv.DictReader((folder/'daily.csv').open())]
    assert len(rows)==97
    bottom=[0.]*97;es=[0.]*97;ep=[0.]*97;runoff=[0.]*97;pot=[0.]*97
    counts={'PERF01_BOTTOM':0,'PERF01_SURFACE':0}
    for line in (folder/'stdout').read_text().splitlines():
        p=line.split()
        if not p:continue
        if p[0]=='PERF01_INITIAL_STORAGE_CM':initial=float(p[1])*10
        if p[0] not in counts:continue
        values=list(map(float,p[1:]));t0,t1=values[:2];i=int(t0)
        assert t1>t0 and 0<=i<97
        assert abs((t1-t0)-1/64)<1e-12
        counts[p[0]]+=1
        if p[0]=='PERF01_BOTTOM':bottom[i]+=10*values[2]
        else:
            es[i]+=10*values[2];ep[i]+=10*values[3];runoff[i]+=10*values[4];pot[i]+=10*values[6]
    assert set(counts.values())=={97*64}
    previous=initial
    for i,r in enumerate(rows):
        assert r['day']==i+1 and r['accepted']>0 and r['headcalc_calls']>0
        r.update(bottom_mm=bottom[i],soil_evaporation_mm=es[i],pond_evaporation_mm=ep[i],runoff_mm=runoff[i])
        r['gross_closure_mm']=r['storage_mm']-previous-r['rain_mm']+es[i]+ep[i]+runoff[i]+bottom[i]+r['transpiration_mm']
        assert abs(r['gross_closure_mm'])<1e-8
        assert abs(pot[i]-r['potential_transpiration_mm'])<1e-10
        assert r['transpiration_mm']<=r['potential_transpiration_mm']+1e-10
        assert all(r[f'theta{j}']>=0 and r[f'theta{j}']<=1 for j in range(1,5))
        r['stress_deficit_mm']=max(0.,r['potential_transpiration_mm']-r['transpiration_mm'])
        previous=r['storage_mm']
    totals={k:sum(r[k] for r in rows) for k in ['rain_mm','soil_evaporation_mm','pond_evaporation_mm',
        'runoff_mm','bottom_mm','transpiration_mm','potential_transpiration_mm','stress_deficit_mm']}
    result.update(initial_storage_mm=initial,totals=totals,
        work={k:sum(int(r[k]) for r in rows) for k in ['accepted','headcalc_calls','temporal_rejections']},
        core_cpu_seconds=sum(r['core_cpu_s'] for r in rows),
        max_gross_daily_closure_mm=max(abs(r['gross_closure_mm']) for r in rows),
        period_gross_closure_mm=rows[-1]['storage_mm']-initial-totals['rain_mm']+
          sum(totals[k] for k in ['soil_evaporation_mm','pond_evaporation_mm','runoff_mm','bottom_mm','transpiration_mm']),
        stress_days=sum(r['stress_deficit_mm']>1e-4 for r in rows))
    return result,rows


def differences(rows,ref):
    out={}
    for key in ['storage_mm','transpiration_mm','soil_evaporation_mm','bottom_mm','runoff_mm',
                'stress_deficit_mm','biomass','lai']:
        ds=[r[key]-s[key] for r,s in zip(rows,ref)]
        out[key]={'max_daily_abs':max(map(abs,ds)),'end_difference':ds[-1]}
        if key.endswith('_mm') and key!='storage_mm':
            cumulative=0.;peak=0.
            for delta in ds:cumulative+=delta;peak=max(peak,abs(cumulative))
            out[key].update(total_difference=cumulative,max_cumulative_abs=peak)
    out['max_head_cm']=max(abs(r[f'head{i}_cm']-s[f'head{i}_cm']) for r,s in zip(rows,ref) for i in range(1,5))
    out['max_theta']=max(abs(r[f'theta{i}']-s[f'theta{i}']) for r,s in zip(rows,ref) for i in range(1,5))
    return out


def same_physics(a,b):
    assert len(a)==len(b)
    assert all({k:v for k,v in r.items() if k!='core_cpu_s'}==
               {k:v for k,v in s.items() if k!='core_cpu_s'} for r,s in zip(a,b))


if __name__=='__main__':
    fine,ref=read(BASE/'original-ref-2.5e-07')
    curve=[]
    for tol in [1e-6,.001,.01,.1,1.]:
        cases=[read(BASE/f'original-{tol:g}-r{j}') for j in range(3)]
        for _,r in cases[1:]:same_physics(cases[0][1],r)
        r,rows=cases[0]
        curve.append(dict(head_budget_cm=tol,median_user_seconds=statistics.median(x['user_seconds'] for x,_ in cases),
                          median_core_cpu_seconds=statistics.median(x['core_cpu_seconds'] for x,_ in cases),
                          user_seconds=[x['user_seconds'] for x,_ in cases],metrics=r,
                          differences_vs_fine=differences(rows,ref)))
    refinements=[]
    for tol in [1e-4,1e-5,2.5e-6]:
        r,rows=read(BASE/f'original-ref-{tol:g}');refinements.append(dict(budget=tol,metrics=r,differences=differences(rows,ref)))
    for tol in [.001,1.]:
        _,a=read(BASE/f'original-{tol:g}-r0');_,b=read(BASE/f'original-restart-{tol:g}');same_physics(a,b)
    sensitive=[]
    sensitive_fine,sref=read(BASE/'sensitive-1e-05')
    assert sensitive_fine['stress_days']>0,'stress-sensitive discriminator inactive'
    for tol in [.001,.01,.1,1.]:
        r,rows=read(BASE/f'sensitive-{tol:g}')
        sensitive.append(dict(head_budget_cm=tol,metrics=r,differences_vs_fine=differences(rows,sref)))
    summary=dict(status='COMPLETE_BOUNDED_LIVE_WEATHER_CURVE_NOT_FIELD_CALIBRATION',
        temporal_policy='Existing mode7 model certificate; calibrated local head estimate cm; not full/half equality',
        days=97,windows_per_day=64,curve=curve,refinements=refinements,fine_reference=fine,
        sensitive=sensitive,sensitive_reference=sensitive_fine,restart='Close/reconstruct in same native process at day48; exact all daily physical and work values',
        no_runoff='All actual bootstrap boundary evaluations remain in the existing zero-pond/zero-runoff accepted domain; no overflow benchmark claim',
        claim_ceiling='Time-discretization spread on a30cm/4cell parameterized live crop column with actual weather; no spatial convergence or observed field truth')
    (BASE/'SUMMARY.json').write_text(json.dumps(summary,indent=2)+'\n')
    for r in curve:
        e=r['differences_vs_fine'];print(r['head_budget_cm'],r['median_user_seconds'],e['storage_mm']['max_daily_abs'],e['bottom_mm']['total_difference'],e['transpiration_mm']['total_difference'])
    print('PASS: physical closure, actual fluxes, all finite completed horizons, exact repeats and midpoint reconstruction; active stress discriminator')
