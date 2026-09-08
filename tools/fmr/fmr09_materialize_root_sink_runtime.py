#!/usr/bin/env python3
from pathlib import Path
import subprocess

PATH = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
EXPECTED_BLOB = '202ab846cbd30d149d0d450249b3d517e333994f'

current_blob = subprocess.check_output(['git', 'hash-object', str(PATH)], text=True).strip()
if current_blob != EXPECTED_BLOB:
    raise SystemExit(f'F-MR09 materializer: unexpected runtime backend blob {current_blob}, expected {EXPECTED_BLOB}')

text = PATH.read_text()

def replace_once(old: str, new: str) -> None:
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'F-MR09 materializer: expected exactly one replacement site, found {count}: {old[:90]!r}')
    text = text.replace(old, new, 1)

replace_once(
    "  use, intrinsic :: iso_fortran_env, only: int64, real64\n",
    "  use, intrinsic :: iso_fortran_env, only: int64, real64\n"
    "  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite\n"
)
replace_once(
    "  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n",
    "  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t, bind_b110_source_sink_provider\n"
    "  use mod_b110_root_sink_provider, only: b110_root_sink_provider_t, bind_b110_root_sink_provider\n"
)
replace_once(
    "    type(b110_source_sink_provider_t), pointer :: source_sink => null()\n"
    "    class(top_boundary_provider_t), pointer :: top_boundary => null()\n",
    "    type(b110_source_sink_provider_t), pointer :: source_sink => null()\n"
    "    type(b110_root_sink_provider_t), pointer :: root_sink => null()\n"
    "    class(top_boundary_provider_t), pointer :: top_boundary => null()\n"
)
replace_once(
    "    logical :: state_profile_admitted = .false.\n"
    "    logical :: snow_active = .false.\n",
    "    logical :: state_profile_admitted = .false.\n"
    "    logical :: root_extraction_active = .false.\n"
    "    logical :: snow_active = .false.\n"
)
replace_once(
    "           parameters%swkimpl == 0 .and. parameters%swsophy == 0 .and. &\n"
    "           .not. parameters%root_extraction_active .and. .not. parameters%macropore_active .and. &\n",
    "           parameters%swkimpl == 0 .and. parameters%swsophy == 0 .and. &\n"
    "           .not. parameters%macropore_active .and. &\n"
)
replace_once(
    "      if (associated(self%source_sink)) deallocate(self%source_sink)\n"
    "      allocate(self%soil_parameters, self%hydraulic_parameters, self%constitutive, self%source_sink)\n",
    "      if (associated(self%source_sink)) deallocate(self%source_sink)\n"
    "      if (associated(self%root_sink)) deallocate(self%root_sink)\n"
    "      allocate(self%soil_parameters, self%hydraulic_parameters, self%constitutive, self%source_sink, self%root_sink)\n"
)
replace_once(
    "      self%ponding_tolerance = parameters%ponding_tolerance\n"
    "      self%snow_active = parameters%snow_active\n",
    "      self%ponding_tolerance = parameters%ponding_tolerance\n"
    "      self%root_extraction_active = parameters%root_extraction_active\n"
    "      self%snow_active = parameters%snow_active\n"
)
replace_once(
    "      if (any(abs(forcing%root_extraction_sink) > 0.0_real64)) return\n",
    "      if (any(.not. ieee_is_finite(forcing%root_extraction_sink))) return\n"
    "      if (self%root_extraction_active) then\n"
    "        if (any(forcing%root_extraction_sink < 0.0_real64)) return\n"
    "      else\n"
    "        if (any(abs(forcing%root_extraction_sink) > 0.0_real64)) return\n"
    "      end if\n"
)
replace_once(
    "    type(soil_water_solve_result_t) :: solve_result\n"
    "    real(real64) :: step_duration\n",
    "    type(soil_water_solve_result_t) :: solve_result\n"
    "    real(real64), allocatable, target :: source_sink_root_zero(:)\n"
    "    real(real64) :: step_duration\n"
)
replace_once(
    "        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return\n"
    "    step_duration = t1 - t0\n",
    "        .not. associated(self%source_sink) .or. .not. associated(self%top_boundary)) return\n"
    "    if (self%root_extraction_active .and. .not. associated(self%root_sink)) return\n"
    "    step_duration = t1 - t0\n"
)
replace_once(
    "    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)\n"
    "    call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)\n\n"
    "    request%parameters => self%soil_parameters\n"
    "    request%evaluation%constitutive => self%constitutive\n"
    "    request%evaluation%source_sink => self%source_sink\n"
    "    request%evaluation%top_boundary => self%top_boundary\n",
    "    call bind_b110_default_mvg_provider(self%constitutive, self%hydraulic_parameters, step_duration)\n"
    "    if (self%root_extraction_active) then\n"
    "      allocate(source_sink_root_zero(size(self%qrot)))\n"
    "      source_sink_root_zero = 0.0_real64\n"
    "      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, source_sink_root_zero)\n"
    "      call bind_b110_root_sink_provider(self%root_sink, self%qrot)\n"
    "    else\n"
    "      call bind_b110_source_sink_provider(self%source_sink, self%qdra, self%qssdi, self%qrot)\n"
    "    end if\n\n"
    "    request%parameters => self%soil_parameters\n"
    "    request%evaluation%constitutive => self%constitutive\n"
    "    request%evaluation%source_sink => self%source_sink\n"
    "    if (self%root_extraction_active) request%evaluation%root_sink => self%root_sink\n"
    "    request%evaluation%top_boundary => self%top_boundary\n"
)
replace_once(
    "    do level = 1, size(self%qdra,1)\n"
    "      do i = 1, size(self%qdra,2)\n"
    "        value = self%qdra(level,i) * step_duration\n"
    "        if (value >= 0.0_real64) then\n"
    "          total_out = total_out + value\n"
    "        else\n"
    "          total_in = total_in - value\n"
    "        end if\n"
    "      end do\n"
    "    end do\n"
    "    if (self%snow_active .and. snow_event_applied) then\n",
    "    do level = 1, size(self%qdra,1)\n"
    "      do i = 1, size(self%qdra,2)\n"
    "        value = self%qdra(level,i) * step_duration\n"
    "        if (value >= 0.0_real64) then\n"
    "          total_out = total_out + value\n"
    "        else\n"
    "          total_in = total_in - value\n"
    "        end if\n"
    "      end do\n"
    "    end do\n"
    "    do i = 1, size(self%qrot)\n"
    "      value = self%qrot(i) * step_duration\n"
    "      if (value >= 0.0_real64) then\n"
    "        total_out = total_out + value\n"
    "      else\n"
    "        total_in = total_in - value\n"
    "      end if\n"
    "    end do\n"
    "    if (self%snow_active .and. snow_event_applied) then\n"
)

PATH.write_text(text)
print('FMR09_RUNTIME_MATERIALIZATION PASS')
