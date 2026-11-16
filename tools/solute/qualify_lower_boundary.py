"""Actual natural open/closed outlet native continuations, without model changes."""
import contextlib,json,zipfile
import daily_host as h
from daily_coupling import validate_bundle

def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision')}

def payload(path):
    with zipfile.ZipFile(path) as z:return {n:z.read(n) for n in ('result.end','macro.bin')}

def natural_windows(bundle,reference,project,out,full_rows,opt,*,signed=False):
    # These thresholds classify naturally exercised regimes, not acceptance or
    # balance tolerance. The actual model/host retains its original hard guards.
    if signed:
        open_days=[i+1 for i in range(len(full_rows)-2) if all(r['bottom_outward_cm']>1e-6 for r in full_rows[i:i+3])]
        closed_days=[i+1 for i in range(len(full_rows)-2) if all(r['bottom_outward_cm']< -1e-6 for r in full_rows[i:i+3])]
        assert open_days and closed_days,'Full prescribed-head trajectory did not exercise both flow directions'
        cuts={'outflow':max(2,open_days[0]),'inflow':max(2,closed_days[0])}
    else:
        open_days=[r['day'] for r in full_rows[:-2] if r['bottom_outward_cm']>1e-6]
        closed_days=[i+1 for i in range(10,len(full_rows)-2)
                     if all(abs(r['bottom_outward_cm'])<1e-12 for r in full_rows[i:i+3])]
        assert open_days and closed_days, 'Full trajectory did not exercise both natural outlet regimes'
        cuts={'open':max(2,open_days[0]),'closed':closed_days[0]}
    selected=set(cuts.values())|{d+2 for d in cuts.values()};out.mkdir();warmdir=out/'warm';warmdir.mkdir()
    meta,case=validate_bundle(bundle,reference,project);expected={}
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warmdir,
            [h.ColumnStart()],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        with (out/'warm.jsonl').open('w') as log:
            for day in range(1,max(selected)+1):
                row=host.step(1,checkpoint=day in selected);assert row['committed']
                if opt=='O2':assert physical(row)==physical(full_rows[day-1])
                expected[day]=row;log.write(json.dumps(row)+'\n')
        host.close()
    for regime,cut in cuts.items():
        origin=warmdir/f'accepted-column-1-day-{cut}.zip';digest=h.sha(origin)
        restored=out/('origin-'+regime);receipt=h.verify_checkpoint(origin,cut,meta['binding'],restored)
        cold=out/('cold-'+regime);cold.mkdir()
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,cold,
                [h.ColumnStart(day=cut,origin=restored,receipt=receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
            with (cold/'daily.jsonl').open('w') as log:
                for day in range(cut+1,cut+3):
                    row=host.step(1,checkpoint=day==cut+2);log.write(json.dumps(row)+'\n')
                    assert row['committed'] and physical(row)==physical(expected[day]),(regime,day,'own continuation')
            host.close()
        assert payload(cold/f'accepted-column-1-day-{cut+2}.zip')==payload(warmdir/f'accepted-column-1-day-{cut+2}.zip')
        assert h.sha(origin)==digest
    result=dict(optimization=opt,natural_open_days=len(open_days),natural_closed_days=len(closed_days),
        classification_only=dict(open_outward_gt_cm=1e-6,closed_abs_outward_lt_cm=1e-12),
        windows={k:[v,v+2] for k,v in cuts.items()},physical_exact=True,native_exact=True,origins_unchanged=True)
    if signed:
        result['natural_outflow_days']=result.pop('natural_open_days');result['natural_inflow_days']=result.pop('natural_closed_days')
        result['classification_only']={'outward_gt_cm':1e-6,'inward_lt_cm':-1e-6}
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n')
    return result
