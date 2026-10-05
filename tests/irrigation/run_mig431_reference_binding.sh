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
print('\n'.join(ordered))
PY
)
flags=(-std=f2008 -ffree-line-length-none -Wall -Wextra -fcheck=all -fbacktrace -ffpe-trap=invalid,zero,overflow)
for opt in 0 2; do
  out="$BUILD/o$opt"; mkdir -p "$out"; objects=()
  for source in "${sources[@]}" \
      src/process/mod_irrigation_process.f90 \
      src/runtime/mod_fmr_irrigation_source_binding.f90 \
      src/runtime/mod_fmr_irrigation_reference_binding.f90 \
      src/process/mod_crop_calendar_management_process.f90 \
      src/runtime/mod_fmr_crop_calendar_observation_binding.f90 \
      src/runtime/mod_fmr_crop_calendar_reference_observation.f90; do
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
done
cmp "$BUILD/o0/output" "$BUILD/o2/output"
cmp "$BUILD/o0/crop-output" "$BUILD/o2/crop-output"
cat "$BUILD/o0/output"
cat "$BUILD/o0/crop-output"

# Materialize an additive event in the established real Reference dispatcher,
# whose continuous/restarted endpoint and hard mass receipts are independently checked.
python3 - "$BUILD/fmr19-managed.f90" <<'PY'
from pathlib import Path
import sys
s=Path('tests/fmr/test_fmr19_process_restart.f90').read_text()
anchor='  use mod_transaction_reference, only: transaction_state_t'
assert s.count(anchor)==1
s=s.replace(anchor,'''  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, &
       irrigation_diagnostics_t, IRRIGATION_APPLICATION_SSDI
  use mod_fmr_irrigation_reference_binding, only: fmr_bind_ssdi_reference_candidate, &
       fmr_publish_accepted_irrigation_state, FMR_IRR_REFERENCE_OK
'''+anchor)
anchor='    logical :: exported, restored\n    integer :: status, i'
assert s.count(anchor)==1
s=s.replace(anchor,'''    logical :: exported, restored, management_published
    type(irrigation_state_t) :: base_management, restart_management, proposed_management
    integer :: status, i''')
anchor="    call require_all_committed(base_first, 'continuous first committed')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
    proposed_management%next_fixed_event_index = 2
    call fmr_publish_accepted_irrigation_state(base_management,proposed_management,base_first(1), &
         base_columns(1)%column_id,tm,management_published)
    call require(management_published .and. base_management%next_fixed_event_index == 2, &
         'actual accepted Reference result publishes management state')''')
anchor="    call require_all_committed(restart_first, 'restart first committed')"
assert s.count(anchor)==1
s=s.replace(anchor,anchor+'''
    call fmr_publish_accepted_irrigation_state(restart_management,proposed_management,restart_first(1), &
         restart_columns(1)%column_id,tm,management_published)
    call require(management_published .and. &
         restart_management%next_fixed_event_index == base_management%next_fixed_event_index, &
         'replayed accepted Reference result publishes same management state')''')
anchor='    integer :: i\n\n    forcing%top_flux = -conductivity0'
assert s.count(anchor)==1
s=s.replace(anchor,'''    integer :: i, bind_status
    type(irrigation_flux_result_t) :: irrigation_flux
    type(irrigation_diagnostics_t) :: irrigation_diagnostics
    type(fmr_b110_physical_forcing_t) :: managed_forcing

    forcing%top_flux = -conductivity0''')
anchor='    end do\n  end subroutine configure_forcing'
assert s.count(anchor)==1
s=s.replace(anchor,'''    end do
    irrigation_flux%applied = .true.
    irrigation_flux%application_type = IRRIGATION_APPLICATION_SSDI
    irrigation_flux%subsurface_source = [0.0_real64,1.0e-10_real64,0.0_real64,0.0_real64]
    irrigation_flux%active_duration = tm-t0
    irrigation_flux%external_inflow_amount = 1.0e-10_real64*(tm-t0)
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
PY
for opt in 0 2; do
  out="$BUILD/o$opt"; objects=()
  for source in "${sources[@]}" src/process/mod_irrigation_process.f90 \
      src/runtime/mod_fmr_irrigation_source_binding.f90 src/runtime/mod_fmr_irrigation_reference_binding.f90 \
      src/process/mod_crop_calendar_management_process.f90 \
      src/runtime/mod_fmr_crop_calendar_observation_binding.f90 \
      src/runtime/mod_fmr_crop_calendar_reference_observation.f90; do
    objects+=("$out/$(basename "${source%.*}").o")
  done
  gfortran "${flags[@]}" -O"$opt" -J "$out" -I "$out" -c "$BUILD/fmr19-managed.f90" -o "$out/managed.o"
  gfortran -O"$opt" "${objects[@]}" "$out/managed.o" -o "$out/managed"
  "$out/managed" > "$out/managed-output" 2>&1 || { cat "$out/managed-output" >&2; exit 1; }
  grep -Fq 'FMR19_CONTINUOUS_VS_RESTARTED_ENDPOINT_IDENTITY=PASS' "$out/managed-output"
  grep -Fq 'FMR19_EXACT_INTERVAL_MASS_CONTINUATION=PASS' "$out/managed-output"
done
cmp "$BUILD/o0/managed-output" "$BUILD/o2/managed-output"
echo 'F_MIG431_MANAGED_SSDI_REAL_REFERENCE_RESTART_O0_O2=PASS'
