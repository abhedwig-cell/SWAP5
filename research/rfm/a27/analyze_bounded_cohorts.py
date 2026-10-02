"""Preregistered sampled-trajectory screen; no production-equivalence claim."""
import csv, json, sys
from pathlib import Path
from collections import defaultdict
src, out = map(Path,sys.argv[1:3]); out.mkdir(parents=True,exist_ok=True)
rows=list(csv.DictReader(src.open()))
groups=defaultdict(list)
for r in rows:
    for k in r:r[k]=float(r[k])
    groups[(int(r['soil']),int(r['wet']),int(r['reverse_on']),r['dt_day'])].append(r)
assert len(groups)==500 and len(rows)==5000
metrics={'macro_storage_cm':.01,'exchange_cm':.01,'bottom_cm':.01,**{f'theta_{d}':.001 for d in ['top','mid','bottom']},**{f'head_{d}_cm':1. for d in ['top','mid','bottom']}}
comparison=[]; refinement=[]; memory=[]
for (soil,wet,mode,dt), rr in sorted(groups.items()):
    rr.sort(key=lambda r:r['time_day'])
    assert len(rr)==10
    memory.append(dict(soil=soil,wet=wet,mode=mode,dt_day=dt,max_cohorts=max(r['max_live_cohorts'] for r in rr),packed_bytes=max(r['nominal_cohort_bytes'] for r in rr)))
    if mode in [8,9]:
        ref=sorted(groups[(soil,wet,7,dt)],key=lambda r:r['time_day'])
        assert [r['time_day'] for r in rr]==[r['time_day'] for r in ref]
        errors={k:max(abs(a[k]-b[k]) for a,b in zip(rr,ref)) for k in metrics}
        comparison.append(dict(soil=soil,wet=wet,mode=mode,dt_day=dt,**errors,passed=all(errors[k]<=metrics[k] for k in metrics)))
    if mode>=7 and (soil,wet,mode,dt/2) in groups:
        fine=sorted(groups[(soil,wet,mode,dt/2)],key=lambda r:r['time_day'])
        refinement.append(dict(soil=soil,wet=wet,mode=mode,dt_day=dt,**{k:max(abs(a[k]-b[k]) for a,b in zip(rr,fine)) for k in metrics}))
def write(name,records):
    with (out/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(records[0]));w.writeheader();w.writerows(records)
write('bounded_comparison.csv',comparison);write('bounded_refinement.csv',refinement);write('bounded_memory.csv',memory)
summary={'cases':len(groups),'records':len(rows),'thresholds':metrics,'mass_residual_max_cm':max(abs(r['mass_residual_cm']) for r in rows), 'whole_column_ledger_max_cm':max(abs(r['storage_change_cm']-r['bottom_cm']+r['macro_storage_cm']-(4. if int(r['wet']) in [2,3] else 0.)-r['imposed_ic_input_cm']) for r in rows),'modes':{}}
for mode in [8,9]:
    cc=[r for r in comparison if r['mode']==mode]
    summary['modes'][mode]={'passed':sum(r['passed'] for r in cc),'total':len(cc),'max_errors':{k:max(r[k] for r in cc) for k in metrics},'failures':[r for r in cc if not r['passed']]}
(out/'bounded_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print(json.dumps(summary,indent=2))
