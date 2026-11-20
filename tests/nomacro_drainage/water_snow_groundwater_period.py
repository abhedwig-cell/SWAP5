"""Observe actual water Snow groundwater periods using original compiled bundles."""
import argparse
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','source-probe','label','output'):p.add_argument('--'+key,required=True)
    p.add_argument('--days',type=int,choices=(35,1096),default=35)
    p.add_argument('--cap',type=int,choices=(180,600,1200),default=180)
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
        q['trajectory'],data=original.m.trajectory(build,Path(a.reference_work),project,out/'trajectory',a.days,
            {a.days,*(d for pair in windows for d in pair)},a.cap)
        q['cold']=[];save()
        for low,high in windows:
            q['cold'].append(original.previous.own(build,Path(a.reference_work),project,out/'trajectory',data,low,high,out/f'own-{low}'));save()
        assert max(r['stock_end_cm'][2] for r in data)>0
        assert original.m.sha(build/'BUILD.json')==buildsha and original.m.sha(record)==before
        q['status']='ACTUAL_WATER_SNOW_GROUNDWATER_PHYSICAL_NATIVE_OUTPUT_PERIOD_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'],a.label,a.days,flush=True)


if __name__=='__main__':main()
