from pathlib import Path

p = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
s = p.read_text()

if 'F-PM14 drainage response runtime composition' not in s:
    raise SystemExit('F-PM14 refine transform requires the base checked transform')


def admission_block(text: str) -> str:
    start = text.index('logical function fmr_serialized_execution_admitted')
    end = text.index('end function fmr_serialized_execution_admitted')
    return text[start:end]


def already_refined(text: str) -> bool:
    admission = admission_block(text)
    return (
        'self%drainage_response_levels' not in admission
        and 'self%drainage_response_active' not in admission
        and 'fmr_drainage_response_configuration_status' in text
        and 'drainage_preflight_status = fmr_drainage_response_configuration_status' in text
        and 'self%last_observation%drainage_response = self%drainage_response_diagnostics' in text
    )


if already_refined(s):
    print('FPM14_BACKEND_REFINE_ALREADY_APPLIED=PASS')
    raise SystemExit(0)


def replace_once(old: str, new: str) -> None:
    global s
    count = s.count(old)
    if count != 1:
        raise SystemExit(
            f'F-PM14 refine transform failed: expected exactly one occurrence, got {count}:\n{old[:240]}'
        )
    s = s.replace(old, new, 1)

# kernel_advance_interval calls execution_admitted before configure_parameters.
# Admission therefore validates only the supplied immutable capability payload;
# it must never depend on scratch left in a reused backend worker.
replace_once(
"""      if (parameters%drainage_response_active) then
        ok = ok .and. self%drainage_response_active .and. allocated(parameters%drainage_response_levels) .and. &
             allocated(self%drainage_response_levels) .and. .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0 .and. &
             size(parameters%drainage_response_levels) == size(self%drainage_response_levels)
      else
        ok = ok .and. .not. self%drainage_response_active .and. &
             .not. allocated(parameters%drainage_response_levels) .and. &
             .not. allocated(self%drainage_response_levels)
      end if
""",
"""      if (parameters%drainage_response_active) then
        ok = ok .and. allocated(parameters%drainage_response_levels) .and. &
             .not. self%fixed_weir_surface_water_active
        if (ok) ok = size(parameters%drainage_response_levels) > 0
      else
        ok = ok .and. .not. allocated(parameters%drainage_response_levels)
      end if
""",
)

# Preserve the explicit fail-closed preflight reason in worker-local diagnostics.
replace_once(
"""  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, fmr_drainage_response_configuration_valid, &
       FMR_DRAIN_BIND_OK
""",
"""  use mod_fmr_drainage_response_binding, only: fmr_drainage_response_level_parameters_t, &
       fmr_drainage_response_level_control_t, fmr_drainage_response_diagnostics_t, &
       evaluate_fmr_drainage_response_bottom_lumped, fmr_drainage_response_configuration_status, &
       FMR_DRAIN_BIND_OK
""",
)

replace_once(
"""    integer :: n
    self%forcing_admitted = .false.
""",
"""    integer :: n, drainage_preflight_status
    self%forcing_admitted = .false.
""",
)

replace_once(
"""        if (allocated(forcing%drainage_flux_by_level) .or. .not. allocated(self%drainage_response_levels) .or. &
            .not. allocated(forcing%drainage_response_controls)) return
        if (.not. fmr_drainage_response_configuration_valid(self%drainage_response_levels, &
             forcing%drainage_response_controls, n)) return
""",
"""        if (allocated(forcing%drainage_flux_by_level) .or. .not. allocated(self%drainage_response_levels) .or. &
            .not. allocated(forcing%drainage_response_controls)) return
        drainage_preflight_status = fmr_drainage_response_configuration_status(self%drainage_response_levels, &
             forcing%drainage_response_controls, n)
        self%drainage_response_diagnostics%status = drainage_preflight_status
        self%last_observation%drainage_response = self%drainage_response_diagnostics
        if (drainage_preflight_status /= FMR_DRAIN_BIND_OK) return
""",
)

# Static guard: execution admission may not consult the previous worker-local
# response configuration. That scratch is configured only after admission.
admission = admission_block(s)
if 'self%drainage_response_levels' in admission or 'self%drainage_response_active' in admission:
    raise SystemExit('F-PM14 refine transform failed: admission still depends on drainage worker scratch')
if 'fmr_drainage_response_configuration_status' not in s:
    raise SystemExit('F-PM14 refine transform failed: explicit preflight status missing')
if not already_refined(s):
    raise SystemExit('F-PM14 refine transform failed: postcondition not satisfied')

p.write_text(s)
print('FPM14_BACKEND_REFINE_APPLIED=PASS')
