"""Real typed native refusals and original Snow/Frost calendar transactions."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_calendar_state_native import native,m
from frost_undrained_state_extra_native import extra
from daily_coupling import CoupledDailyColumn
from age_calendar_controls import physical


def transaction(build,reference,project,full,data,out,start,require_snow):
    out.mkdir();source=full/f'accepted-column-1-day-{start}.zip';before=m.sha(source)
    column=CoupledDailyColumn(build,reference,out/'external',project,'original-output',origin=source,day=start,adopt_native=True)
    trial=column.prepare();assert physical(trial)==m.physical([data[start]])
    if require_snow:assert max(trial.budget['stock_start_cm'][2],trial.budget['stock_end_cm'][2])>0
    column.discard(trial);assert column.day==start
    replay=column.prepare();assert replay.budget==trial.budget;column.accept(replay)
    recovered=CoupledDailyColumn(build,reference,out/'recovered',project,'original-output',origin=column.checkpoint,day=start+1)
    endpoint=recovered.prepare();assert physical(endpoint)==m.physical([data[start+1]]);recovered.discard(endpoint)
    assert m.sha(source)==before
    return dict(start_day=start,actual_snow_required=require_snow,discard_no_day_advance=True,replay_exact=True,accept_exact=True,recovered_next_day_exact=True,origin_unchanged=True)


def main():
    p=argparse.ArgumentParser()
    for key in ('reference-work','profile','output'):p.add_argument('--'+key,type=Path,required=True)
    a=p.parse_args();a.output.mkdir();report=json.loads((a.profile/'RESULT.json').read_text());build=Path(report['build_root']);full=a.profile/'trajectory'
    project=m.e.load(report['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1');meta,_=m.validate_bundle(build,a.reference_work,project)
    selected=m.e.switches((Path(project.input_directory)/'swap.swp').read_text(encoding='cp1252'));assert selected['SWDRA']==0
    q=dict(status='RUNNING_ACTUAL_FROST_CALENDAR_NATIVE_AND_TRANSACTIONS_NOT_ADMITTED',actual_controller_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R).decode().strip(),actual_compiler_source=report['source'],actual_BUILD_sha256=m.sha(build/'BUILD.json'),implicit=selected['SWKIMPL'],hysteresis=selected['SWHYST'],kind=report['kind'],accepted_mutant_model_days=0)
    def save():(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        q['existing_calendar_thermal_refusals']=native(build,a.reference_work,project,full,a.output/'native');assert len(q['existing_calendar_thermal_refusals'])==(44 if project.solute else 39);save()
        q['new_snow_private_and_codec_refusals']=extra(m,build,a.reference_work,project,full,a.output/'extra-native');save()
        if selected['SWKIMPL']:
            command=[sys.executable,'-B','tests/nomacro_drainage/frost_undrained_state_root_controls.py','--reference-work',str(a.reference_work),'--profile',str(a.profile),'--output',str(a.output/'root')]
            with (a.output/'root.stdout').open('xb') as stdout,(a.output/'root.stderr').open('xb') as stderr:r=subprocess.run(command,cwd=R,stdout=stdout,stderr=stderr,timeout=240)
            r.check_returncode();q['root']=json.loads((a.output/'root/RESULT.json').read_text());assert len(q['root']['refusals'])==25;save()
        data=m.rows(full);q['snow_transaction']=transaction(build,a.reference_work,project,full,data,a.output/'snow-transactions',4,True);save()
        start=30 if project.start_date[5:7]=='12' else 4
        q['frost_calendar_transaction']=transaction(build,a.reference_work,project,full,data,a.output/'frost-calendar-transactions',start,False)
        assert m.validate_bundle(build,a.reference_work,project)[0]==meta
        q['status']='ACTUAL_UNDRAINED_FROST_COMPILED_NATIVE_SNOW_CDE_ROOT_AND_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_FROST_CALENDAR_CONTROLS_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],q['kind'],q['implicit'],flush=True)


if __name__=='__main__':main()
