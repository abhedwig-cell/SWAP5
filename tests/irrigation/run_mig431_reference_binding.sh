#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
BUILD="$(mktemp -d "${TMPDIR:-/tmp}/mig431-reference.XXXXXX")"
trap 'rm -rf "$BUILD"' EXIT
mapfile -t sources < <(python3 - <<'PY'
from pathlib import Path
s=Path('tests/fci/run_fci98_fgc31_active_drainage_tangent_admission.sh').read_text()
block=s.split('MODULE_SRC=(\n',1)[1].split('\n)',1)[0]
print('\n'.join(line.strip() for line in block.splitlines() if line.strip()))
PY
)
mapfile -t sources < <(python3 - "${sources[@]}" <<'PY'
from pathlib import Path
import re,sys
paths=sorted(Path('src').rglob('*.f90'))+[Path('tests/fsi/fsi04_real_headcalc_stubs.f90'),Path('tests/fmr/mod_fmr04_fixed_top_provider.f90')]
modules={}
for p in paths:
 for name in re.findall(r'^\s*module\s+(\w+)\s*$',p.read_text(),re.I|re.M): modules[name.lower()]=str(p)
ordered=[]; seen=set(); visiting=set()
def visit(path):
 if path in seen:return
 if path in visiting:raise RuntimeError('module cycle '+path)
 visiting.add(path)
 for name in re.findall(r'^\s*use\s+(?:,\s*non_intrinsic\s*::\s*)?(\w+)',Path(path).read_text(),re.I|re.M):
  dep=modules.get(name.lower())
  if dep and dep!=path:visit(dep)
 visiting.remove(path);seen.add(path);ordered.append(path)
for p in sys.argv[1:]:visit(p)
visit('src/runtime/mod_fmr_serialized_multiswap_runtime.f90')
visit('src/runtime/mod_fmr_committed_restart.f90')
visit('tests/fmr/mod_fmr04_fixed_top_provider.f90')
visit('src/runtime/mod_fmr_tillage_reference_material_candidate.f90')
visit('src/runtime/mod_fmr_irrigation_reference_binding.f90')
visit('src/runtime/mod_fmr_irrigation_joint_restart.f90')
visit('src/runtime/mod_fmr_crop_calendar_reference_observation.f90')
print('\n'.join(ordered))
PY
)
flags=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"; objects=(); declare -A compiled_sources=()
  for source in "${sources[@]}"; do
    source_key="$(realpath "$source")"
    [[ -z "${compiled_sources[$source_key]+x}" ]] || continue
    compiled_sources[$source_key]=1
    obj="$out/$(basename "${source%.*}").o"
    gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$source" -o "$obj" 2>"$out/compile.log" || {
      tail -35 "$out/compile.log" >&2; echo "compile failed: $source" >&2; exit 1;
    }
    objects+=("$obj")
  done
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c tests/irrigation/test_mig431_reference_binding.f90 -o "$out/test.o"
  gfortran -O"$opt" "${objects[@]}" "$out/test.o" -o "$out/test"
  "$out/test" > "$out/output"
  grep -Fq 'F_MIG431_REFERENCE_SOURCE_AND_ACCEPTANCE_BINDING=PASS' "$out/output"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c \
    tests/management/test_mig431_crop_reference_observation.f90 -o "$out/crop.o"
  gfortran -O"$opt" "${objects[@]}" "$out/crop.o" -o "$out/crop"
  "$out/crop" > "$out/crop-output"
  grep -Fq 'F_MIG431_CROP_REFERENCE_STATE_OBSERVATION=PASS' "$out/crop-output"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c \
    tests/tillage/test_mig431_tillage_reference_material.f90 -o "$out/tillage.o"
  gfortran -O"$opt" "${objects[@]}" "$out/tillage.o" -o "$out/tillage"
  "$out/tillage" > "$out/tillage-output"
  grep -Fq 'F_MIG431_TILLAGE_REFERENCE_MATERIAL_CANDIDATE=PASS' "$out/tillage-output"
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
cmp "$BUILD/o0/crop-output" "$BUILD/o2/crop-output"
cmp "$BUILD/o0/tillage-output" "$BUILD/o2/tillage-output"
cat "$BUILD/o0/output"
cat "$BUILD/o0/crop-output"
cat "$BUILD/o0/tillage-output"

# Materialize an additive event in the established real Reference dispatcher,
# whose continuous/restarted endpoint and hard mass receipts are independently checked.
python3 - "$BUILD/fmr19-managed.f90" "$BUILD/fmr19-tcs7.f90" <<'PY'
from pathlib import Path
import sys
s=Path('tests/fmr/test_fmr19_process_restart.f90').read_text()
anchor='  use mod_transaction_reference, only: transaction_state_t'
assert s.count(anchor)==1
s=s.replace(anchor,'''  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, &
       irrigation_diagnostics_t, irrigation_parameters_t, irrigation_management_request_t, &
       evaluate_fixed_irrigation_interval, IRRIGATION_APPLICATION_SSDI, IRRIGATION_OK
  use mod_fmr_irrigation_reference_binding, only: fmr_bind_ssdi_reference_candidate, &
       fmr_publish_accepted_irrigation_state, FMR_IRR_REFERENCE_OK
  use mod_fmr_irrigation_restart, only: irrigation_restart_record_t, export_irrigation_restart, &
       restore_irrigation_restart, IRRIGATION_RESTART_OK
  use mod_fmr_irrigation_joint_restart, only: irrigation_joint_restart_t, &
       export_irrigation_joint_restart, restore_irrigation_joint_restart, IRRIGATION_JOINT_RESTART_OK
'''+anchor)
anchor='    logical :: exported, restored\n    integer :: status, i'
assert s.count(anchor)==1
s=s.replace(anchor,'''    logical :: exported, restored, management_published
    type(irrigation_state_t) :: base_management, restart_management, proposed_management
    type(irrigation_restart_record_t) :: management_restart_record
    type(irrigation_joint_restart_t) :: joint_bundle, corrupt_joint
    type(irrigation_state_t), allocatable :: joint_management(:)
    type(irrigation_flux_result_t) :: event_flux
    type(irrigation_diagnostics_t) :: event_diagnostics
    integer :: status, i''')
anchor="    call require_all_committed(base_first, 'continuous first committed')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
    call managed_irrigation_event(base_management,proposed_management,event_flux,event_diagnostics)
    call require(event_diagnostics%status == IRRIGATION_OK .and. event_flux%event_finished .and. &
         proposed_management%next_fixed_event_index == 2, 'actual fixed SSDI event candidate')
    call fmr_publish_accepted_irrigation_state(base_management,proposed_management,base_first(1), &
         base_columns(1)%column_id,tm,management_published)
    call require(management_published .and. base_management%next_fixed_event_index == 2, &
         'actual accepted Reference result publishes management state')''')
anchor='    call reset_legacy_globals()\n    call fmr_run_serialized_physical_multiswap(base_columns, base_templates, base_parameters, base_forcings, base_states, &\n         config, top_provider, tm, t1, n, base_second, diagnostics, base_second_aggregate, status)'
assert s.count(anchor)==1
s=s.replace(anchor,'''    do i=1,n
      base_forcings(i)%subsurface_irrigation_source(2) = &
           base_forcings(i)%subsurface_irrigation_source(2)-1.0e-10_real64
      base_forcings(i)%drainage_flux_by_level(1,2) = &
           base_forcings(i)%drainage_flux_by_level(1,2)-1.0e-10_real64
    end do
'''+anchor)
anchor="    call require_all_committed(restart_first, 'restart first committed')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
    call fmr_publish_accepted_irrigation_state(restart_management,proposed_management,restart_first(1), &
         restart_columns(1)%column_id,tm,management_published)
    call require(management_published .and. &
         restart_management%next_fixed_event_index == base_management%next_fixed_event_index, &
         'replayed accepted Reference result publishes same management state')
    call export_irrigation_restart(restart_management,management_restart_record,status)
    call require(status == IRRIGATION_RESTART_OK, 'accepted management restart export')''')
anchor="    call require(exported .and. status == FMR_RESTART_OK, 'restart export')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
    allocate(joint_management(n))
    joint_management = restart_management
    call export_irrigation_joint_restart(restart_columns,restart_templates,restart_states, &
         joint_management,parameter_set_identity,joint_bundle,status)
    call require(status == IRRIGATION_JOINT_RESTART_OK, 'atomic irrigation and FMR export')''')
anchor="""    call fmr_restore_committed_restart(bundle, parameter_set_identity, restart_columns, restart_templates, restart_states, &
         restored, status)
    call require(restored .and. status == FMR_RESTART_OK, 'correct restart restore')"""
assert s.count(anchor)==1
s=s.replace(anchor,'''    corrupt_joint = joint_bundle
    corrupt_joint%management(1)%management%schema = -1
    joint_management = irrigation_state_t()
    call restore_irrigation_joint_restart(corrupt_joint,parameter_set_identity,restart_columns, &
         restart_templates,restart_states,joint_management,restored,status)
    call require(.not. restored .and. all_states_unready(restart_states) .and. &
         all(joint_management%next_fixed_event_index == 1), 'joint corruption atomic rollback')
    call restore_irrigation_joint_restart(joint_bundle,parameter_set_identity,restart_columns, &
         restart_templates,restart_states,joint_management,restored,status)
    call require(restored .and. status == IRRIGATION_JOINT_RESTART_OK, 'joint restart restore')
    call require(all(joint_management%next_fixed_event_index == 2), &
         'all management pointers restored with physical columns')
'''+'''
    restart_management = irrigation_state_t()
    call restore_irrigation_restart(management_restart_record,restart_management,status)
    call require(status == IRRIGATION_RESTART_OK .and. &
         restart_management%next_fixed_event_index == base_management%next_fixed_event_index, &
         'accepted management state restored with Reference column')''')
anchor='    call reset_legacy_globals()\n    call fmr_run_serialized_physical_multiswap(restart_columns, restart_templates, restart_parameters, restart_forcings, &\n         restart_states, config, top_provider, tm, t1, n, restart_second, diagnostics, restart_second_aggregate, status)'
assert s.count(anchor)==1
s=s.replace(anchor,'''    do i=1,n
      restart_forcings(i)%subsurface_irrigation_source(2) = &
           restart_forcings(i)%subsurface_irrigation_source(2)-1.0e-10_real64
      restart_forcings(i)%drainage_flux_by_level(1,2) = &
           restart_forcings(i)%drainage_flux_by_level(1,2)-1.0e-10_real64
    end do
'''+anchor)
anchor='  subroutine configure_forcing(forcing, conductivity0, scale)'
assert s.count(anchor)==1
s=s.replace(anchor,'''  subroutine managed_irrigation_event(committed,candidate,flux,diagnostics)
    type(irrigation_state_t), intent(in) :: committed
    type(irrigation_state_t), intent(out) :: candidate
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(irrigation_parameters_t) :: parameters
    type(irrigation_management_request_t) :: request
    parameters%fixed_irrigation_enabled = .true.
    parameters%active_nodes = numnod
    parameters%ssdi_first_node = 2
    parameters%ssdi_last_node = 2
    allocate(parameters%fixed_events(1))
    parameters%fixed_events(1)%event_time = t0
    parameters%fixed_events(1)%application_type = IRRIGATION_APPLICATION_SSDI
    parameters%fixed_events(1)%depth = 1.0e-10_real64*(tm-t0)
    parameters%fixed_events(1)%rate = 1.0e-10_real64
    request%t0 = t0
    request%t1 = tm
    call evaluate_fixed_irrigation_interval(parameters,committed,request,candidate,flux,diagnostics)
  end subroutine managed_irrigation_event

'''+anchor)
anchor='    integer :: i\n\n    forcing%top_flux = -conductivity0'
assert s.count(anchor)==1
s=s.replace(anchor,'''    integer :: i, bind_status
    type(irrigation_flux_result_t) :: irrigation_flux
    type(irrigation_diagnostics_t) :: irrigation_diagnostics
    type(irrigation_state_t) :: prior_irrigation, proposed_irrigation
    type(fmr_b110_physical_forcing_t) :: managed_forcing

    forcing%top_flux = -conductivity0''')
anchor='    end do\n  end subroutine configure_forcing'
assert s.count(anchor)==1
s=s.replace(anchor,'''    end do
    call managed_irrigation_event(prior_irrigation,proposed_irrigation,irrigation_flux,irrigation_diagnostics)
    call require(irrigation_diagnostics%status == IRRIGATION_OK .and. irrigation_flux%event_finished, &
         'fixed SSDI process supplies real Reference forcing')
    call fmr_bind_ssdi_reference_candidate(forcing,irrigation_flux,irrigation_diagnostics,managed_forcing,bind_status)
    call require(bind_status == FMR_IRR_REFERENCE_OK, 'managed SSDI bound to Reference forcing')
    forcing = managed_forcing
    ! Preserve the fixture's analytically stationary net source/sink balance.
    forcing%drainage_flux_by_level(1,2) = forcing%drainage_flux_by_level(1,2) + 1.0e-10_real64
  end subroutine configure_forcing''')
anchor="      call require(results(i)%completed .and. results(i)%committed .and. results(i)%mass%complete, label)"
assert s.count(anchor)==1
s=s.replace(anchor,"""      if (.not. results(i)%committed) print *, 'MANAGED_DIAGNOSTIC', label, &
           results(i)%admission_status, results(i)%kernel_status, results(i)%commit_status, &
           results(i)%solver_route, results(i)%solver_iterations, results(i)%mass%residual
"""+anchor)
Path(sys.argv[1]).write_text(s)

# A scheduled TCS7/DCS2 event spans both accepted intervals. Its active
# event rate, deadline and pointer cross the joint physical restart boundary.
t=s.replace('IRRIGATION_APPLICATION_SSDI, IRRIGATION_OK',
'''IRRIGATION_APPLICATION_SSDI, IRRIGATION_OK, scheduled_irrigation_parameters_t, &
       scheduled_irrigation_request_t, evaluate_scheduled_irrigation_interval''')
t=t.replace('  use mod_fmr_irrigation_reference_binding,',
'''  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_irrigation_reference_binding,''',1)
t=t.replace('    type(irrigation_joint_restart_t) :: joint_bundle, corrupt_joint',
'''    type(process_hydraulic_view_t) :: live_sensor_view
    logical :: sensor_available
    type(irrigation_joint_restart_t) :: joint_bundle, corrupt_joint''',1)
anchor='    call build_runtime(n, .true., base_columns, base_templates, base_parameters, base_forcings, base_states)'
assert t.count(anchor)==1
t=t.replace(anchor,anchor+'''
    call fmr_build_committed_process_hydraulic_view(base_states(1),live_sensor_view,sensor_available)
    call require(sensor_available .and. live_sensor_view%pressure_head(1) == head0, &
         'TCS7 sensor equals committed Reference pressure head')''')
start=t.index('  subroutine managed_irrigation_event(')
end=t.index('  end subroutine managed_irrigation_event',start)+len('  end subroutine managed_irrigation_event')
t=t[:start]+'''  subroutine managed_irrigation_event(committed,candidate,flux,diagnostics)
    type(irrigation_state_t), intent(in) :: committed
    type(irrigation_state_t), intent(out) :: candidate
    type(irrigation_flux_result_t), intent(out) :: flux
    type(irrigation_diagnostics_t), intent(out) :: diagnostics
    type(scheduled_irrigation_parameters_t) :: parameters
    type(scheduled_irrigation_request_t) :: request
    type(process_hydraulic_view_t) :: hydraulic
    parameters%scheduled_irrigation_enabled = .true.
    parameters%timing_criterion = 7
    parameters%depth_criterion = 2
    parameters%active_nodes = numnod
    parameters%sensor_node = 1
    parameters%single_ssdi_node = 2
    parameters%application_type = IRRIGATION_APPLICATION_SSDI
    parameters%irr_rate_cm_per_day = 1.0e-10_real64
    parameters%tcs7_knot_count = 2
    parameters%tcs7_dvs(1:2) = [0.0_real64,2.0_real64]
    parameters%tcs7_pressure_head(1:2) = [-70.0_real64,-70.0_real64]
    parameters%dcs2_knot_count = 2
    parameters%dcs2_dvs(1:2) = [0.0_real64,2.0_real64]
    parameters%dcs2_depth_cm(1:2) = [5.0e-11_real64,5.0e-11_real64]
    hydraulic%active_nodes = numnod
    hydraulic%pressure_head = spread(head0,1,numnod)
    hydraulic%water_content = spread(0.25_real64,1,numnod)
    request%t0 = t0
    request%t1 = tm
    request%dvs = 1.0_real64
    request%selection_opportunity = .true.
    request%irrigation_enabled = .true.
    request%schedule_enabled = .true.
    request%crop_emerged = .true.
    request%irrigation_window_open = .true.
    if (committed%active_event) then
      request%t0 = tm
      request%t1 = t1
      request%selection_opportunity = .false.
    end if
    call evaluate_scheduled_irrigation_interval(parameters,committed,request,hydraulic,candidate,flux,diagnostics)
  end subroutine managed_irrigation_event'''+t[end:]
t=t.replace('event_flux%event_finished .and. &\n         proposed_management%next_fixed_event_index == 2',
            'event_flux%event_remains_active .and. proposed_management%active_event')
t=t.replace('base_management%next_fixed_event_index == 2', 'base_management%active_event')
t=t.replace('all(joint_management%next_fixed_event_index == 2)', 'all(joint_management%active_event)')
t=t.replace('restart_management%next_fixed_event_index == base_management%next_fixed_event_index',
            'restart_management%active_event .eqv. base_management%active_event')
t=t.replace('irrigation_flux%event_finished', 'irrigation_flux%event_remains_active')
import re
for prefix in ('base','restart'):
 pattern=r'    do i=1,n\n      '+prefix+r'_forcings\(i\)%subsurface_irrigation_source\(2\) = &\n.*?    end do\n'
 t,count=re.subn(pattern,'',t,count=1,flags=re.S)
 assert count==1,(prefix,count)
anchor="    call require(result_sets_identical(base_second, restart_second), 'second interval result identity')"
assert t.count(anchor)==1
t=t.replace(anchor,anchor+'''
    call managed_irrigation_event(base_management,proposed_management,event_flux,event_diagnostics)
    call require(event_diagnostics%status == IRRIGATION_OK .and. event_flux%event_finished .and. &
         .not. proposed_management%active_event, 'TCS7 event ends at second accepted endpoint')
    call fmr_publish_accepted_irrigation_state(base_management,proposed_management,base_second(1), &
         base_columns(1)%column_id,t1,management_published)
    call require(management_published .and. .not. base_management%active_event, 'TCS7 finish committed')
    call managed_irrigation_event(restart_management,proposed_management,event_flux,event_diagnostics)
    call require(event_diagnostics%status == IRRIGATION_OK .and. event_flux%event_finished, &
         'TCS7 restarted active event finishes')
    call fmr_publish_accepted_irrigation_state(restart_management,proposed_management,restart_second(1), &
         restart_columns(1)%column_id,t1,management_published)
    call require(management_published .and. .not. restart_management%active_event, &
         'TCS7 restart finish committed')''')
Path(sys.argv[2]).write_text(t)
PY
for opt in 0 2; do
  out="$BUILD/o$opt"; objects=()
  for source in "${sources[@]}"; do
    objects+=("$out/$(basename "${source%.*}").o")
  done
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fmr19-managed.f90" -o "$out/managed.o"
  gfortran -O"$opt" "${objects[@]}" "$out/managed.o" -o "$out/managed"
  "$out/managed" > "$out/managed-output" 2>&1 || { cat "$out/managed-output" >&2; exit 1; }
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$out/managed-output"
  grep -Fq 'FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS' "$out/managed-output"
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fmr19-tcs7.f90" -o "$out/tcs7.o"
  gfortran -O"$opt" "${objects[@]}" "$out/tcs7.o" -o "$out/tcs7"
  "$out/tcs7" > "$out/tcs7-output" 2>&1 || { cat "$out/tcs7-output" >&2; exit 1; }
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$out/tcs7-output"
done
cmp "$BUILD/o0/managed-output" "$BUILD/o2/managed-output"
cmp "$BUILD/o0/tcs7-output" "$BUILD/o2/tcs7-output"
echo 'F_MIG431_MANAGED_SSDI_REAL_REFERENCE_RESTART_O0_O2=PASS'
echo 'F_MIG431_TCS7_SSDI_REAL_REFERENCE_RESTART_O0_O2=PASS'
