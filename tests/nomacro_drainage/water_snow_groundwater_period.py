"""Observe actual water Snow groundwater periods using original compiled bundles."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original
from original_output_files import compare


def cold(build,reference,project,full,data,start,end,out):
    m=original.m;meta,case=m.validate_bundle(build,reference,project)
    source=full/f'accepted-column-1-day-{start}.zip';before=m.sha(source);reused=out.exists();seconds=None
    if not reused:
        origin=out.with_name(out.name+'-origin');receipt=m.h.verify_checkpoint(source,start,meta['binding'],origin);out.mkdir()
        result,seconds=m.bounded(60,lambda:m.h.run(m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,end,
            checkpoint_day=start,origin=origin,origin_receipt=receipt,runtime=True,publish_day=end,
            checkpoint_binding=meta['binding'],model=project.model,project=project))
        assert result['first_refusal'] is None,result
    actual=m.rows(out);m.check(actual);assert len(actual)==end-start and m.physical(actual)==m.physical(data[start:end])
    with zipfile.ZipFile(full/f'accepted-column-1-day-{end}.zip') as a,zipfile.ZipFile(out/f'accepted-column-1-day-{end}.zip') as b:
        assert a.read('macro.bin')[:8]==m.e.auxiliary_magic(project)
        for name in ('result.end','macro.bin'):assert a.read(name)==b.read(name),name
        origin=json.loads(a.read('checkpoint.json'));own=json.loads(b.read('checkpoint.json'))
        assert origin['binding']==own['binding']==meta['binding'] and m.physical([origin['receipt']])==m.physical([own['receipt']])
        from implicit_groundwater_state import validate_candidate,native_enabled
        if native_enabled(project):validate_candidate(a.read('macro.bin'),data[end-1],project)
    from groundwater_water_output import metadata
    outputs=compare(full/'original',out/'original',metadata(project),start,end,project.start_date)
    assert m.sha(source)==before
    return dict(start=start,end=end,exact_physical=True,exact_complete_native=True,exact_original_output=outputs,
        seconds=seconds,origin_unchanged=True,completed_raw_cold_reused=reused)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','source-probe','label','output'):p.add_argument('--'+key,required=True)
    p.add_argument('--days',type=int,choices=(35,1096),default=35)
    p.add_argument('--cap',type=int,choices=(180,600,1200),default=180)
    p.add_argument('--recover-existing',type=Path)
    a=p.parse_args();out=Path(a.output);out.mkdir();record=Path(a.source_probe);before=original.m.sha(record)
    producer=json.loads(record.read_text());case=producer['cases'][a.label];assert case['returncode']==0
    build=Path(case['build_root']);inputs=Path(case['input_root']);buildsha=original.m.sha(build/'BUILD.json')
    project=original.m.e.load(inputs,original_output=True);meta,_=original.m.validate_bundle(build,Path(a.reference_work),project)
    selected=meta['identity']['original_output'];assert selected['groundwater_snow_water_output'] and selected['swbotb']==1
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        original_source_producer=str(record),original_source_producer_sha256=before,
        original_source_producer_status=producer['status'],build_root=str(build),input_root=str(inputs),
        actual_BUILD_sha256=buildsha,actual_selected_domain=selected,days=a.days,full_resource_cap_seconds=a.cap,
        fresh_compilations=0,canonical_admission=False,whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(out/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        windows=[(2,4),(7,9),(30,34)]
        if a.days==1096:windows += [(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
        warm=out/'trajectory'
        if a.recover_existing:
            prior=a.recover_existing/'RESULT.json';r=json.loads(prior.read_text())
            assert r['status']=='FAILED_OR_CENSORED' and r['actual_BUILD_sha256']==buildsha and r['days']==a.days
            assert 'Original Snow clock requires lower boundary5/8' in r['error']
            q['original_failed_period']=str(prior);q['original_failed_period_sha256']=original.m.sha(prior)
            q['original_period_failure_preserved']=True;q['fresh_warm_periods']=0
            warm=a.recover_existing/'trajectory';data=original.m.rows(warm);q['trajectory']=r['trajectory']
            assert len(data)==a.days and q['trajectory']['build_sha256']==buildsha
        else:
            q['trajectory'],data=original.m.trajectory(build,Path(a.reference_work),project,warm,a.days,
                {a.days,*(d for pair in windows for d in pair)},a.cap)
        q['trajectory_root']=str(warm);q['cold']=[];q['cold_actual_roots']=[];save()
        for low,high in windows:
            actual=a.recover_existing/f'own-{low}' if a.recover_existing and (a.recover_existing/f'own-{low}').exists() else out/f'own-{low}'
            q['cold'].append(cold(build,Path(a.reference_work),project,warm,data,low,high,actual));q['cold_actual_roots'].append(str(actual));save()
        assert max(r['stock_end_cm'][2] for r in data)>0
        assert original.m.sha(build/'BUILD.json')==buildsha and original.m.sha(record)==before
        if a.recover_existing:assert original.m.sha(a.recover_existing/'RESULT.json')==q['original_failed_period_sha256']
        q['status']='ACTUAL_WATER_SNOW_GROUNDWATER_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'],a.label,a.days,flush=True)


if __name__=='__main__':main()
