from pathlib import Path
import subprocess

path = Path('src/runtime/mod_fmr_serialized_reference_backend.f90')
expected = '3506b453ba6a00111d182f29db8cbfb288001854'
actual = subprocess.check_output(['git', 'hash-object', str(path)], text=True).strip()
if actual != expected:
    raise SystemExit(f'EB-I25 bootstrap refuses backend {actual}; expected {expected}')

text = path.read_text()

def replace_once(old, new, label):
    global text
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'EB-I25 {label}: expected one match, found {count}')
    text = text.replace(old, new, 1)

replace_once(
"  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t\n",
"  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_carrier_t, fmr_bottom_thermal_candidate_t\n"
"  use mod_fmr_top_sensible_boundary_carrier, only: fmr_top_sensible_boundary_carrier_t, &\n"
"       fmr_top_sensible_boundary_candidate_t\n",
'import top carrier')

replace_once(
"  type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t\n"
"    logical :: bottom_thermal_active = .false.\n"
"    logical :: bottom_thermal_valid = .true.\n"
"    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier\n"
"  end type fmr_serialized_attempt_context_t\n",
"  type, extends(transaction_attempt_context_t) :: fmr_serialized_attempt_context_t\n"
"    logical :: bottom_thermal_active = .false.\n"
"    logical :: bottom_thermal_valid = .true.\n"
"    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier\n"
"    logical :: top_sensible_boundary_active = .false.\n"
"    logical :: top_sensible_boundary_valid = .true.\n"
"    type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier\n"
"  end type fmr_serialized_attempt_context_t\n",
'attempt context')

replace_once(
"    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier\n"
"    logical :: bottom_thermal_carrier_active = .false.\n"
"    logical :: bottom_thermal_carrier_valid = .true.\n"
"    type(fmr_serialized_physical_observation_t) :: last_observation\n",
"    type(fmr_bottom_thermal_carrier_t) :: bottom_thermal_carrier\n"
"    logical :: bottom_thermal_carrier_active = .false.\n"
"    logical :: bottom_thermal_carrier_valid = .true.\n"
"    type(fmr_top_sensible_boundary_carrier_t) :: top_sensible_boundary_carrier\n"
"    logical :: top_sensible_boundary_carrier_active = .false.\n"
"    logical :: top_sensible_boundary_carrier_valid = .true.\n"
"    type(fmr_serialized_physical_observation_t) :: last_observation\n",
'model fields')

replace_once(
"    logical :: bottom_thermal_requested = .false.\n"
"    type(fmr_bottom_thermal_candidate_t) :: bottom_thermal_candidate\n"
"  contains\n"
"    procedure, public :: initialize => fmr_serialized_backend_initialize\n"
"    procedure, public :: run_trial => fmr_serialized_backend_run_trial\n"
"    procedure, public :: observation => fmr_serialized_backend_observation\n"
"    procedure, public :: set_bottom_thermal_carrier_enabled => fmr_serialized_backend_set_bottom_thermal_carrier_enabled\n"
"    procedure, public :: bottom_thermal_snapshot => fmr_serialized_backend_bottom_thermal_snapshot\n",
"    logical :: bottom_thermal_requested = .false.\n"
"    type(fmr_bottom_thermal_candidate_t) :: bottom_thermal_candidate\n"
"    logical :: top_sensible_boundary_requested = .false.\n"
"    type(fmr_top_sensible_boundary_candidate_t) :: top_sensible_boundary_candidate\n"
"  contains\n"
"    procedure, public :: initialize => fmr_serialized_backend_initialize\n"
"    procedure, public :: run_trial => fmr_serialized_backend_run_trial\n"
"    procedure, public :: observation => fmr_serialized_backend_observation\n"
"    procedure, public :: set_bottom_thermal_carrier_enabled => fmr_serialized_backend_set_bottom_thermal_carrier_enabled\n"
"    procedure, public :: bottom_thermal_snapshot => fmr_serialized_backend_bottom_thermal_snapshot\n"
"    procedure, public :: set_top_sensible_boundary_enabled => fmr_serialized_backend_set_top_sensible_boundary_enabled\n"
"    procedure, public :: top_sensible_boundary_snapshot => fmr_serialized_backend_top_sensible_boundary_snapshot\n",
'backend fields and bindings')

replace_once(
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n"
"    self%bottom_thermal_requested = .false.\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    call self%bottom_thermal_candidate%clear()\n"
"    call self%clear_fixed_weir_surface_water()\n",
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n"
"    self%bottom_thermal_requested = .false.\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    call self%bottom_thermal_candidate%clear()\n"
"    self%model%top_sensible_boundary_carrier_active = .false.\n"
"    self%model%top_sensible_boundary_carrier_valid = .true.\n"
"    self%top_sensible_boundary_requested = .false.\n"
"    call self%model%top_sensible_boundary_carrier%clear()\n"
"    call self%top_sensible_boundary_candidate%clear()\n"
"    call self%clear_fixed_weir_surface_water()\n",
'backend initialize')

replace_once(
"  function fmr_serialized_backend_bottom_thermal_snapshot(self) result(candidate)\n"
"    class(fmr_serialized_reference_backend_t), intent(in) :: self\n"
"    type(fmr_bottom_thermal_candidate_t) :: candidate\n"
"    call self%bottom_thermal_candidate%copy_to(candidate)\n"
"  end function fmr_serialized_backend_bottom_thermal_snapshot\n\n"
"  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water",
"  function fmr_serialized_backend_bottom_thermal_snapshot(self) result(candidate)\n"
"    class(fmr_serialized_reference_backend_t), intent(in) :: self\n"
"    type(fmr_bottom_thermal_candidate_t) :: candidate\n"
"    call self%bottom_thermal_candidate%copy_to(candidate)\n"
"  end function fmr_serialized_backend_bottom_thermal_snapshot\n\n"
"  subroutine fmr_serialized_backend_set_top_sensible_boundary_enabled(self, enabled)\n"
"    class(fmr_serialized_reference_backend_t), intent(inout) :: self\n"
"    logical, intent(in) :: enabled\n"
"    self%top_sensible_boundary_requested = enabled\n"
"    call self%top_sensible_boundary_candidate%clear()\n"
"    call self%model%top_sensible_boundary_carrier%clear()\n"
"    self%model%top_sensible_boundary_carrier_active = .false.\n"
"    self%model%top_sensible_boundary_carrier_valid = .true.\n"
"  end subroutine fmr_serialized_backend_set_top_sensible_boundary_enabled\n\n"
"  function fmr_serialized_backend_top_sensible_boundary_snapshot(self) result(candidate)\n"
"    class(fmr_serialized_reference_backend_t), intent(in) :: self\n"
"    type(fmr_top_sensible_boundary_candidate_t) :: candidate\n"
"    call self%top_sensible_boundary_candidate%copy_to(candidate)\n"
"  end function fmr_serialized_backend_top_sensible_boundary_snapshot\n\n"
"  subroutine fmr_serialized_backend_configure_fixed_weir_surface_water",
'top setter and snapshot')

replace_once(
"    logical :: bottom_thermal_ok\n\n"
"    call self%bottom_thermal_candidate%clear()\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n",
"    logical :: bottom_thermal_ok, top_sensible_ok\n\n"
"    call self%bottom_thermal_candidate%clear()\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n"
"    call self%top_sensible_boundary_candidate%clear()\n"
"    call self%model%top_sensible_boundary_carrier%clear()\n"
"    self%model%top_sensible_boundary_carrier_active = .false.\n"
"    self%model%top_sensible_boundary_carrier_valid = .true.\n",
'run trial reset')

replace_once(
"    if (self%bottom_thermal_requested .and. parameters%soil_temperature_active .and. &\n"
"        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then\n"
"      call self%model%bottom_thermal_carrier%initialize(2 * config%max_committed_substeps, bottom_thermal_ok)\n"
"      self%model%bottom_thermal_carrier_active = bottom_thermal_ok\n"
"      self%model%bottom_thermal_carrier_valid = bottom_thermal_ok\n"
"    end if\n"
"    call fmr_trial_from_checkpoint",
"    if (self%bottom_thermal_requested .and. parameters%soil_temperature_active .and. &\n"
"        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then\n"
"      call self%model%bottom_thermal_carrier%initialize(2 * config%max_committed_substeps, bottom_thermal_ok)\n"
"      self%model%bottom_thermal_carrier_active = bottom_thermal_ok\n"
"      self%model%bottom_thermal_carrier_valid = bottom_thermal_ok\n"
"    end if\n"
"    if (self%top_sensible_boundary_requested .and. parameters%soil_temperature_active .and. &\n"
"        self%model%state_profile_admitted .and. config%max_committed_substeps <= ishft(huge(0), -1)) then\n"
"      call self%model%top_sensible_boundary_carrier%initialize(2 * config%max_committed_substeps, top_sensible_ok)\n"
"      self%model%top_sensible_boundary_carrier_active = top_sensible_ok\n"
"      self%model%top_sensible_boundary_carrier_valid = top_sensible_ok\n"
"    end if\n"
"    call fmr_trial_from_checkpoint",
'run trial initialize top')

replace_once(
"    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &\n"
"        result%completed) then\n"
"      if (candidate%ready()) then\n"
"        call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &\n"
"             bottom_thermal_ok)\n"
"        if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()\n"
"      end if\n"
"    end if\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n",
"    if (self%model%bottom_thermal_carrier_active .and. self%model%bottom_thermal_carrier_valid .and. &\n"
"        result%completed) then\n"
"      if (candidate%ready()) then\n"
"        call self%model%bottom_thermal_carrier%materialize_candidate(t0, t1, self%bottom_thermal_candidate, &\n"
"             bottom_thermal_ok)\n"
"        if (.not. bottom_thermal_ok) call self%bottom_thermal_candidate%clear()\n"
"      end if\n"
"    end if\n"
"    if (self%model%top_sensible_boundary_carrier_active .and. self%model%top_sensible_boundary_carrier_valid .and. &\n"
"        result%completed) then\n"
"      if (candidate%ready()) then\n"
"        call self%model%top_sensible_boundary_carrier%materialize_candidate(t0, t1, &\n"
"             self%top_sensible_boundary_candidate, top_sensible_ok)\n"
"        if (.not. top_sensible_ok) call self%top_sensible_boundary_candidate%clear()\n"
"      end if\n"
"    end if\n"
"    call self%model%bottom_thermal_carrier%clear()\n"
"    self%model%bottom_thermal_carrier_active = .false.\n"
"    self%model%bottom_thermal_carrier_valid = .true.\n"
"    call self%model%top_sensible_boundary_carrier%clear()\n"
"    self%model%top_sensible_boundary_carrier_active = .false.\n"
"    self%model%top_sensible_boundary_carrier_valid = .true.\n",
'run trial materialize top')

replace_once(
"      typed%bottom_thermal_active = self%bottom_thermal_carrier_active\n"
"      typed%bottom_thermal_valid = self%bottom_thermal_carrier_valid\n"
"      call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)\n",
"      typed%bottom_thermal_active = self%bottom_thermal_carrier_active\n"
"      typed%bottom_thermal_valid = self%bottom_thermal_carrier_valid\n"
"      call self%bottom_thermal_carrier%copy_to(typed%bottom_thermal_carrier)\n"
"      typed%top_sensible_boundary_active = self%top_sensible_boundary_carrier_active\n"
"      typed%top_sensible_boundary_valid = self%top_sensible_boundary_carrier_valid\n"
"      call self%top_sensible_boundary_carrier%copy_to(typed%top_sensible_boundary_carrier)\n",
'capture top context')

replace_once(
"      self%bottom_thermal_carrier_active = typed%bottom_thermal_active\n"
"      self%bottom_thermal_carrier_valid = typed%bottom_thermal_valid\n"
"      call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)\n"
"    class default\n"
"      self%bottom_thermal_carrier_active = .false.\n"
"      self%bottom_thermal_carrier_valid = .false.\n"
"      call self%bottom_thermal_carrier%clear()\n",
"      self%bottom_thermal_carrier_active = typed%bottom_thermal_active\n"
"      self%bottom_thermal_carrier_valid = typed%bottom_thermal_valid\n"
"      call self%bottom_thermal_carrier%restore_from(typed%bottom_thermal_carrier)\n"
"      self%top_sensible_boundary_carrier_active = typed%top_sensible_boundary_active\n"
"      self%top_sensible_boundary_carrier_valid = typed%top_sensible_boundary_valid\n"
"      call self%top_sensible_boundary_carrier%restore_from(typed%top_sensible_boundary_carrier)\n"
"    class default\n"
"      self%bottom_thermal_carrier_active = .false.\n"
"      self%bottom_thermal_carrier_valid = .false.\n"
"      call self%bottom_thermal_carrier%clear()\n"
"      self%top_sensible_boundary_carrier_active = .false.\n"
"      self%top_sensible_boundary_carrier_valid = .false.\n"
"      call self%top_sensible_boundary_carrier%clear()\n",
'restore top context')

replace_once(
"    if (self%bottom_thermal_carrier_active .and. self%bottom_thermal_carrier_valid) then\n"
"      call record_bottom_thermal_sample(self, state, t0, t1, outcome%bottom_outward_exchange_native, &\n"
"           bottom_temperature_start_c, bottom_temperature_start_available)\n"
"    end if\n"
"    outcome%solver_ok = .true.\n",
"    if (self%bottom_thermal_carrier_active .and. self%bottom_thermal_carrier_valid) then\n"
"      call record_bottom_thermal_sample(self, state, t0, t1, outcome%bottom_outward_exchange_native, &\n"
"           bottom_temperature_start_c, bottom_temperature_start_available)\n"
"    end if\n"
"    if (self%top_sensible_boundary_carrier_active .and. self%top_sensible_boundary_carrier_valid) then\n"
"      call record_top_sensible_boundary_sample(self, t0, t1, solve_result%top_flux * step_duration)\n"
"    end if\n"
"    outcome%solver_ok = .true.\n",
'top sample call')

replace_once(
"  end subroutine record_bottom_thermal_sample\n\n"
"  subroutine account_external_fluxes",
"  end subroutine record_bottom_thermal_sample\n\n"
"  subroutine record_top_sensible_boundary_sample(self, t0, t1, top_exchange_native)\n"
"    class(fmr_serialized_reference_model_t), intent(inout) :: self\n"
"    real(real64), intent(in) :: t0, t1, top_exchange_native\n"
"    logical :: appended\n\n"
"    if (.not. self%top_sensible_boundary_carrier_active .or. &\n"
"        .not. self%top_sensible_boundary_carrier_valid) return\n"
"    call self%top_sensible_boundary_carrier%append(t0, t1, top_exchange_native, &\n"
"         self%last_observation%soil_temperature_energy_accounting_complete, &\n"
"         self%last_observation%soil_temperature_boundary_energy_j_cm2, &\n"
"         self%last_observation%soil_temperature_storage_change_j_cm2, &\n"
"         self%last_observation%soil_temperature_energy_residual_j_cm2, appended)\n"
"    if (.not. appended) self%top_sensible_boundary_carrier_valid = .false.\n"
"  end subroutine record_top_sensible_boundary_sample\n\n"
"  subroutine account_external_fluxes",
'insert top sample recorder')

path.write_text(text)
print('EB_I25_BACKEND_PATCH=PASS')
