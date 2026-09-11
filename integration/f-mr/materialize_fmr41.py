#!/usr/bin/env python3
from pathlib import Path


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"FMR41 materializer {label}: expected one anchor, found {count}")
    return text.replace(old, new, 1)


core = Path("src/runtime/mod_fmr_runtime_core.f90")
s = core.read_text()
s = replace_once(
    s,
    """  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_NONE = 0_int64\n  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY = 1_int64\n""",
    """  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_NONE = 0_int64\n  integer(int64), parameter, public :: FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY = 1_int64\n\n  ! Qualified optional physical-state topology identities.  The layout ID is a\n  ! template capability identity; it does not imply that every column using the\n  ! template currently allocates the corresponding optional state.\n  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_BASE = 0_int64\n  integer(int64), parameter, public :: FMR_OPTIONAL_STATE_LAYOUT_SNOW = 60605_int64\n  integer(int64), parameter, public :: &\n       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE = 390501_int64\n""",
    "layout constants",
)
s = replace_once(
    s,
    """  public :: fmr_metadata_bytes_per_column\n\ncontains\n""",
    """  public :: fmr_metadata_bytes_per_column\n  public :: fmr_optional_state_layout_known\n\ncontains\n\n  pure logical function fmr_optional_state_layout_known(layout_id) result(known)\n    integer(int64), intent(in) :: layout_id\n\n    select case (layout_id)\n    case (FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_SNOW, &\n          FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE)\n      known = .true.\n    case default\n      known = .false.\n    end select\n  end function fmr_optional_state_layout_known\n""",
    "known-layout helper",
)
core.write_text(s)


backend = Path("src/runtime/mod_fmr_serialized_reference_backend.f90")
s = backend.read_text()
s = replace_once(
    s,
    """  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n""",
    """  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &\n       FMR_OPTIONAL_STATE_LAYOUT_SNOW, FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, &\n       fmr_optional_state_layout_known\n""",
    "backend typed-layout import",
)
s = replace_once(
    s,
    """    if (parameters%soil_temperature_active) then\n      if (template%optional_state_layout_id <= 0_int64 .or. parameters%snow_active) then\n        result = kernel_result_t()\n        result%status = KERNEL_STATUS_NOT_ADMITTED\n        candidate = kernel_candidate_state_t()\n        diagnostics = kernel_diagnostics_t()\n        diagnostics%admission_rejections = 1\n        return\n      end if\n    end if\n""",
    """    if (.not. fmr_optional_state_layout_known(template%optional_state_layout_id)) then\n      result = kernel_result_t()\n      result%status = KERNEL_STATUS_NOT_ADMITTED\n      candidate = kernel_candidate_state_t()\n      diagnostics = kernel_diagnostics_t()\n      diagnostics%admission_rejections = 1\n      return\n    end if\n    if (parameters%soil_temperature_active) then\n      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE .or. &\n          parameters%snow_active) then\n        result = kernel_result_t()\n        result%status = KERNEL_STATUS_NOT_ADMITTED\n        candidate = kernel_candidate_state_t()\n        diagnostics = kernel_diagnostics_t()\n        diagnostics%admission_rejections = 1\n        return\n      end if\n    else if (parameters%snow_active) then\n      if (template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_SNOW) then\n        result = kernel_result_t()\n        result%status = KERNEL_STATUS_NOT_ADMITTED\n        candidate = kernel_candidate_state_t()\n        diagnostics = kernel_diagnostics_t()\n        diagnostics%admission_rejections = 1\n        return\n      end if\n    end if\n""",
    "backend fail-closed typed admission",
)
backend.write_text(s)


restart = Path("src/runtime/mod_fmr_restart_state_contract.f90")
s = restart.read_text()
s = replace_once(
    s,
    """  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY\n""",
    """  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &\n       FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &\n       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_SNOW, &\n       FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE, fmr_optional_state_layout_known\n""",
    "restart typed-layout import",
)
s = replace_once(
    s,
    """  logical function thermal_optional_state_matches(state, template) result(matches)\n    class(fmr_b110_physical_state_t), intent(in) :: state\n    type(fmr_template_t), intent(in) :: template\n\n    matches = .true.\n    if (.not. allocated(state%soil_temperature)) return\n    matches = template%optional_state_layout_id > 0 .and. .not. allocated(state%snow) .and. &\n         state%soil_temperature%ready() .and. state%soil_temperature%node_count() == state%active_nodes\n  end function thermal_optional_state_matches\n""",
    """  logical function thermal_optional_state_matches(state, template) result(matches)\n    class(fmr_b110_physical_state_t), intent(in) :: state\n    type(fmr_template_t), intent(in) :: template\n\n    matches = .false.\n    if (.not. fmr_optional_state_layout_known(template%optional_state_layout_id)) return\n    if (allocated(state%snow) .and. allocated(state%soil_temperature)) return\n\n    select case (template%optional_state_layout_id)\n    case (FMR_OPTIONAL_STATE_LAYOUT_BASE)\n      matches = .not. allocated(state%snow) .and. .not. allocated(state%soil_temperature)\n    case (FMR_OPTIONAL_STATE_LAYOUT_SNOW)\n      matches = .not. allocated(state%soil_temperature)\n    case (FMR_OPTIONAL_STATE_LAYOUT_RESTRICTED_SOIL_TEMPERATURE)\n      if (allocated(state%snow)) return\n      if (.not. allocated(state%soil_temperature)) then\n        matches = .true.\n      else\n        matches = state%soil_temperature%ready() .and. &\n             state%soil_temperature%node_count() == state%active_nodes\n      end if\n    case default\n      matches = .false.\n    end select\n  end function thermal_optional_state_matches\n""",
    "restart typed-layout matching",
)
restart.write_text(s)

print("FMR41_TYPED_OPTIONAL_STATE_LAYOUT_MATERIALIZATION=PASS")
