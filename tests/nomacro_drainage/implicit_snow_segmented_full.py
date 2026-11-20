"""Complete a censored original period from its real last selected checkpoint.

The censored producer remains unchanged and censored. A separate observation
binds its prefix, an actual cold continuation, exact overlap and nine cold seams.
"""
import argparse
import contextlib
import json
from pathlib import Path
import subprocess
import sys

sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
import implicit_conductivity_runtime as original

m=original.m


def main():
    p=argparse.ArgumentParser(description=__doc__)
    for key in ('reference-work','censored','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();receipt=a.censored/'RESULT.json';before=m.sha(receipt)
    parent=json.loads(receipt.read_text());assert parent['status']=='FAILED_OR_CENSORED'
    assert parent['error']=="TimeoutError('Model wall cap 600s')"
    start=635;full=a.censored/'trajectory';prior=m.rows(full);assert start<len(prior)<1096
    build=Path(parent['build_root']);project=m.e.load(parent['input_root'],original_output=True)
    meta,case=m.validate_bundle(build,a.reference_work,project);build_sha=m.sha(build/'BUILD.json')
    source=full/f'accepted-column-1-day-{start}.zip';source_sha=m.sha(source);origin=a.output/'origin'
    accepted=m.h.verify_checkpoint(source,start,meta['binding'],origin)
    q=dict(status='RUNNING',source_commit=subprocess.check_output(['git','rev-parse','HEAD'],cwd=original.ROOT,text=True).strip(),
        parameters=parent['parameters'],build_root=str(build),input_root=parent['input_root'],actual_censored_producer=str(receipt),
        actual_censored_producer_sha256=before,actual_origin_checkpoint_sha256=source_sha,
        source_prefix_days=start,censored_accepted_days=len(prior),cold_continuation_start=start,
        fresh_compilations=0,fresh_start_to_635_models=0,continuation_resource_cap_seconds=600,
        actual_BUILD_sha256=build_sha,cold=[],whole_scientific_equivalence='NOT_QUALIFIED',functional_completion='PARTIAL')
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        out=a.output/'continuation';out.mkdir()
        def run():
            with contextlib.ExitStack() as stack:
                host=m.h.DailyHost(stack,m.h.executable(build,'day_donor'),m.h.executable(build,'day_kernel'),case,out,
                    [m.h.ColumnStart('original',start,origin,accepted)],checkpoint_enabled=True,runtime=True,
                    binding=meta['binding'],model=project.model,project=project)
                with (out/'daily.jsonl').open('x') as journal:
                    for day in range(start+1,1097):
                        row=host.step(1,checkpoint=day in (1094,1096))
                        journal.write(json.dumps(row)+'\n');journal.flush()
                        if not row['committed']:raise ValueError('Rejected actual continuation day '+str(day))
                host.close()
        _,seconds=m.bounded(600,run);data=m.rows(out);m.check(data)
        assert len(data)==1096-start and data[0]['day']==start+1 and data[-1]['day']==1096
        overlap=len(prior)-start;assert m.physical(data[:overlap])==m.physical(prior[start:])
        whole=prior[:start]+data;m.check(whole)
        q['continuation']=dict(status='ACTUAL_COLD_CONTINUATION_PASS',days=len(data),model_seconds=seconds,
            exact_physical_overlap_days=overlap,build_sha256=build_sha)
        save()
        windows=[(2,4),(7,9),(30,34),(163,165),(199,201),(364,367),(530,532),(633,635),(1094,1096)]
        for low,high in windows:
            source_full=full if high<=start else out
            q['cold'].append(original.previous.own(build,a.reference_work,project,source_full,whole,low,high,a.output/f'own-{low}'));save()
        assert m.sha(receipt)==before and m.sha(source)==source_sha and m.sha(build/'BUILD.json')==build_sha
        q['status']='ACTUAL_IMPLICIT_SNOW_SEGMENTED_FULL_EXACT_OVERLAP_NATIVE_OUTPUT_PASS'
    except Exception as error:q.update(status='FAILED_OR_CENSORED',error=repr(error));raise
    finally:save()
    print(q['status'],q['continuation']['exact_physical_overlap_days'])


if __name__=='__main__':main()
