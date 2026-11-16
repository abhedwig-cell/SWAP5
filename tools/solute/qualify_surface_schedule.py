"""Own native continuations spanning the explicit original surface input events."""
import contextlib,json,zipfile
import daily_host as h
from daily_coupling import validate_bundle


def physical(row):return {k:v for k,v in row.items() if k not in ('column','revision')}


def windows(bundle,reference,project,out,full_rows,opt,*,cuts=(199,529),fixed_irrigation=False):
    selected=set(cuts)|{d+2 for d in cuts};out.mkdir();warm=out/'warm';warm.mkdir();expected={}
    meta,case=validate_bundle(bundle,reference,project)
    with contextlib.ExitStack() as stack:
        host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,warm,[h.ColumnStart()],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
        with (out/'warm.jsonl').open('w') as log:
            for day in range(1,max(selected)+1):
                row=host.step(1,checkpoint=day in selected);assert row['committed']
                if opt=='O2':assert physical(row)==physical(full_rows[day-1])
                expected[day]=row;log.write(json.dumps(row)+'\n')
        host.close()
    for cut in cuts:
        origin=warm/f'accepted-column-1-day-{cut}.zip';digest=h.sha(origin)
        restored=out/('origin-'+str(cut));receipt=h.verify_checkpoint(origin,cut,meta['binding'],restored);cold=out/('cold-'+str(cut));cold.mkdir()
        with contextlib.ExitStack() as stack:
            host=h.DailyHost(stack,h.executable(bundle,'day_donor'),h.executable(bundle,'day_kernel'),case,cold,[h.ColumnStart(day=cut,origin=restored,receipt=receipt)],runtime=True,checkpoint_enabled=True,binding=meta['binding'],project=project)
            with (cold/'daily.jsonl').open('w') as log:
                for day in range(cut+1,cut+3):
                    row=host.step(1,checkpoint=day==cut+2);log.write(json.dumps(row)+'\n');assert row['committed'] and physical(row)==physical(expected[day]),(opt,cut,day)
            host.close()
        with zipfile.ZipFile(cold/f'accepted-column-1-day-{cut+2}.zip') as a,zipfile.ZipFile(warm/f'accepted-column-1-day-{cut+2}.zip') as b:
            assert all(a.read(n)==b.read(n) for n in ('result.end','macro.bin'))
        assert h.sha(origin)==digest
    result=dict(optimization=opt,windows=[[cut,cut+2] for cut in cuts],physical_exact=True,native_exact=True,origins_unchanged=True,
        event_scope='199to201 crosses changing pond threshold and day200 runon;529to531 crosses day530 runon after all DATEPMX knots',
        actual_runon_cm={day:expected[day]['external_flux_cm'][4] for day in (cut+1 for cut in cuts)})
    if fixed_irrigation:
        result['event_scope']='Original fixed irrigation day5, followed by exhausted-table native continuations'
        result['actual_fixed_irrigation_cm']={day:dict(gross_surface=expected[day]['external_flux_cm'][3],subsurface=expected[day]['external_flux_cm'][5]) for day in (cut+1 for cut in cuts)}
    (out/'RESULT.json').write_text(json.dumps(result,indent=2)+'\n');return result
