"""Real compiled native, root and transaction controls for Frost boundary58."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'tests/nomacro_scheduled_subsurface'),str(R/'app/hybrid_water')]
import output_thermal_controls as inherited
from frost_history_state_native import native
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical


def main():
    p=argparse.ArgumentParser()
    for name in ('profile','reference-work','output'):p.add_argument('--'+name,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();m=inherited.m;original=(a.profile/'RESULT.json').read_bytes();profile=json.loads(original)
    project=m.e.load(profile['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1');build=Path(profile['build_root']);full=a.profile/'trajectory';meta,_=m.validate_bundle(build,a.reference_work,project)
    selected=m.e.switches((Path(profile['input_root'])/'swap.swp').read_text(encoding='cp1252'))
    q=dict(status='RUNNING_FROST_STATE_NATIVE_AND_TRANSACTIONS_NOT_ADMITTED',source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),actual_compiler=profile['source'],actual_BUILD_sha256=m.sha(build/'BUILD.json'),kind=profile['kind'],optimization=profile['optimization'],implicit=selected['SWKIMPL'],hysteresis=selected['SWHYST'])
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['native_refusals']=native(build,a.reference_work,project,full,a.output/'native');assert len(q['native_refusals'])==(44 if project.solute else 39);save()
        if selected['SWKIMPL']:
            command=[sys.executable,'-B',str(R/'tests/nomacro_drainage/frost_boundary_root_controls.py'),'--profile',str(a.profile),'--reference-work',str(a.reference_work),'--output',str(a.output/'root')]
            with (a.output/'root.stdout').open('xb') as out,(a.output/'root.stderr').open('xb') as err:r=subprocess.run(command,cwd=R,stdout=out,stderr=err,timeout=180)
            r.check_returncode();q['root_refusals']=json.loads((a.output/'root/RESULT.json').read_text());assert len(q['root_refusals']['refusals'])==25;save()
        q['snow_transactions']=inherited.transactions(build,a.reference_work,project,full,a.output/'snow-transactions');save()
        data=m.rows(full);source=full/'accepted-column-1-day-19.zip';before=m.sha(source)
        column=CoupledDailyColumn(build,a.reference_work,a.output/'frost-external',project,'original-output',origin=source,day=19,adopt_native=True)
        trial=column.prepare();assert physical(trial)==m.physical([data[19]])
        column.discard(trial);assert column.day==19
        replay=column.prepare();assert replay.budget==trial.budget
        column.accept(replay);assert column.day==20
        recovered=CoupledDailyColumn(build,a.reference_work,a.output/'frost-recovered',project,'original-output',origin=column.checkpoint,day=20)
        endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[20]]);recovered.discard(endpoint);assert m.sha(source)==before
        q['frost_transactions']=dict(discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True,start_day=19)
        assert (a.profile/'RESULT.json').read_bytes()==original and m.validate_bundle(build,a.reference_work,project)[0]==meta
        q['status']='ACTUAL_FROST_BOUNDARY_COMPILED_NATIVE_ROOT_SNOW_AND_ACTIVE_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_FROST_STATE_CONTROLS_NOT_ADMITTED',error=repr(error));raise
    finally:save()
    print(q['status'],flush=True)


if __name__=='__main__':main()
