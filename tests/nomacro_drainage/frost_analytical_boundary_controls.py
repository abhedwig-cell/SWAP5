"""Actual analytical Frost native refusals and original external transactions."""
import argparse,json,subprocess,sys
from pathlib import Path
R=Path(__file__).resolve().parents[2]
sys.path[:0]=[str(R/'app/hybrid_water'),str(R/'tests/nomacro_scheduled_subsurface')]
from frost_calendar_state_native import m
from frost_analytical_calendar_native import native as calendar_native
from frost_analytical_boundary_extra_native import extra
from frost_analytical_boundary_native_controls import native as model_native
from frost_undrained_state_controls import transaction,active_frost_start


def main():
    p=argparse.ArgumentParser()
    for name in ['profile','reference-work','output']:p.add_argument('--'+name,type=Path,required=True)
    p.add_argument('--full-legacy-native-controls',action='store_true');p.add_argument('--active-frost-transactions',action='store_true');a=p.parse_args();a.output.mkdir();science=json.loads((a.profile/'RESULT.json').read_text())
    assert science['status']=='ACTUAL_ANALYTICAL_BOUNDARY_FROST_CALENDAR_ORIGINAL_BUDGETS_NATIVE_MODEL_HISTORY_COLD_AND_USER_OUTPUT_PASS_NOT_ADMITTED'
    build=Path(science['build_root']);full=a.profile/'trajectory'
    project=m.e.load(science['input_root'],original_output=True,time_step_policy='original-adaptive-event-closure-v1')
    meta,_=m.validate_bundle(build,a.reference_work,project)
    q=dict(status='RUNNING_ACTUAL_ANALYTICAL_BOUNDARY_FROST_CONTROLS_NOT_QUALIFIED',
        actual_controller_source=subprocess.check_output(['git','rev-parse','HEAD'],cwd=R,text=True).strip(),
        actual_compiler_source=science['source'],actual_BUILD_sha256=m.sha(build/'BUILD.json'),
        accepted_mutant_model_days=0,kind=science['kind'],selection=science['selection'])
    save=lambda:(a.output/'RESULT.json').write_text(json.dumps(q,indent=2)+'\n')
    save()
    try:
        if a.full_legacy_native_controls:
            q['calendar_thermal_refusals']=calendar_native(build,a.reference_work,project,full,a.output/'calendar-native');save()
            q['snow_private_codec_refusals']=extra(m,build,a.reference_work,project,full,a.output/'extra-native');save()
            assert len(q['calendar_thermal_refusals'])==(44 if project.solute else 39)
            assert len(q['snow_private_codec_refusals'])==(47 if project.solute else 43)
        else:
            q['legacy_controls_selection']='NOT_SELECTED_IMPACT_UNCHANGED_THERMAL_SNOW_CDE_IMPL_REPRESENTATIVES0_3'
        q['analytical_boundary_refusals']=model_native(build,a.reference_work,project,full,a.output/'boundary-native');save()
        assert len(q['analytical_boundary_refusals'])==18
        data=m.rows(full)
        q['snow_transaction']=transaction(build,a.reference_work,project,full,data,a.output/'snow-transaction',2,True);save()
        if a.active_frost_transactions:
            assert science['duration_days']==35
            q['actual_active_frost_start']=active_frost_start(full/'accepted-column-1-day-19.zip',project);save()
            q['active_frost_transaction']=transaction(build,a.reference_work,project,full,data,a.output/'active-frost-transaction',19,False)
        else:q['active_frost_transaction']='NOT_SELECTED_YEAR_WINDOW_NO_UNPROVEN_ACTIVE_FROST_CLAIM'
        assert m.validate_bundle(build,a.reference_work,project)[0]==meta
        q['status']='ACTUAL_ANALYTICAL_BOUNDARY_FROST_COMPILED_NATIVE_AND_EXTERNAL_TRANSACTIONS_PASS_NOT_ADMITTED'
    except Exception as error:q.update(status='FAILED_ACTUAL_ANALYTICAL_BOUNDARY_FROST_CONTROLS_NOT_QUALIFIED',error=repr(error));raise
    finally:save()
    print(q['status'],q['kind'],flush=True)


if __name__=='__main__':main()
