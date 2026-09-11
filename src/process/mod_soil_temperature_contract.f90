module mod_soil_temperature_contract
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  implicit none
  private

  integer, parameter, public :: SOIL_TEMP_OK = 0
  integer, parameter, public :: SOIL_TEMP_INVALID_PARAMETERS = 1
  integer, parameter, public :: SOIL_TEMP_INVALID_STATE = 2
  integer, parameter, public :: SOIL_TEMP_INVALID_INTERVAL = 3
  integer, parameter, public :: SOIL_TEMP_INVALID_FORCING = 4
  integer, parameter, public :: SOIL_TEMP_INVALID_HYDRAULIC_VIEW = 5
  integer, parameter, public :: SOIL_TEMP_WORKSPACE_FAILURE = 6
  integer, parameter, public :: SOIL_TEMP_LINEAR_SOLVE_FAILURE = 7
  integer, parameter, public :: SOIL_TEMP_ENERGY_CLOSURE_FAILURE = 8
  integer, parameter, public :: SOIL_TEMP_INVALID_RESTART = 9
  integer, parameter, public :: SOIL_TEMP_INVALID_NODE = 10

  type, public :: soil_temperature_parameters_t
    integer :: active_nodes = 0
    real(real64), allocatable :: dz_cm(:)
    real(real64), allocatable :: distance_above_cm(:)
    real(real64), allocatable :: theta_sat(:)
    real(real64), allocatable :: f_quartz(:)
    real(real64), allocatable :: f_clay(:)
    real(real64), allocatable :: f_organic(:)
    real(real64), allocatable :: fkk_qco_dry(:)
    real(real64), allocatable :: fk_qco_dry(:)
    real(real64), allocatable :: fkk_qco_wet(:)
    real(real64), allocatable :: fk_qco_wet(:)
    logical :: initialized = .false.
  contains
    procedure, public :: node_count => soil_temperature_parameter_node_count
    procedure, public :: ready => soil_temperature_parameters_ready
  end type soil_temperature_parameters_t

  type, public :: soil_temperature_numerical_config_t
    logical :: require_energy_closure = .true.
    real(real64) :: energy_abs_tolerance_j_cm2 = 1.0e-9_real64
  end type soil_temperature_numerical_config_t

  type, public :: soil_temperature_forcing_t
    real(real64) :: prescribed_surface_temperature_c = 0.0_real64
  end type soil_temperature_forcing_t

  type, extends(transaction_state_t), public :: soil_temperature_state_t
    private
    real(real64), allocatable :: temperature_c(:)
    logical :: initialized = .false.
  contains
    procedure :: clone => soil_temperature_state_clone
    procedure, public :: node_count => soil_temperature_state_node_count
    procedure, public :: ready => soil_temperature_state_ready
  end type soil_temperature_state_t

  type, public :: soil_temperature_restart_payload_t
    integer :: schema_version = 1
    real(real64), allocatable :: temperature_c(:)
  end type soil_temperature_restart_payload_t

  type, public :: soil_temperature_field_view_t
    integer :: active_nodes = 0
    real(real64), allocatable :: temperature_c(:)
  end type soil_temperature_field_view_t

  type, public :: soil_temperature_workspace_t
    real(real64), allocatable :: old_temperature_c(:)
    real(real64), allocatable :: average_water_content(:)
    real(real64), allocatable :: heat_capacity_j_cm3_k(:)
    real(real64), allocatable :: node_conductivity_j_cm_k_day(:)
    real(real64), allocatable :: face_conductivity_j_cm_k_day(:)
    real(real64), allocatable :: lower(:)
    real(real64), allocatable :: diagonal(:)
    real(real64), allocatable :: upper(:)
    real(real64), allocatable :: rhs(:)
    real(real64), allocatable :: solution(:)
  end type soil_temperature_workspace_t

  type, public :: soil_temperature_result_t
    integer :: status = SOIL_TEMP_INVALID_STATE
    logical :: produced = .false.
    real(real64) :: surface_temperature_c = 0.0_real64
    real(real64) :: top_heat_flux_into_soil_j_cm2_day = 0.0_real64
    real(real64) :: sensible_storage_change_j_cm2 = 0.0_real64
    real(real64) :: boundary_energy_into_soil_j_cm2 = 0.0_real64
    real(real64) :: energy_residual_j_cm2 = 0.0_real64
    real(real64) :: min_temperature_c = 0.0_real64
    real(real64) :: max_temperature_c = 0.0_real64
  end type soil_temperature_result_t

  type, public :: soil_temperature_diagnostics_t
    integer :: status = SOIL_TEMP_INVALID_STATE
    integer :: active_nodes = 0
    integer :: constitutive_evaluations = 0
    integer :: tridiagonal_solves = 0
    logical :: committed_state_mutated = .false.
    logical :: prescribed_surface_temperature_used = .false.
    logical :: zero_bottom_heat_flux_used = .false.
    logical :: frost_active = .false.
    logical :: snow_active = .false.
    logical :: energy_accounting_complete = .false.
  end type soil_temperature_diagnostics_t

  public :: initialize_soil_temperature_state
  public :: materialize_soil_temperature_trial_state
  public :: commit_soil_temperature_state
  public :: build_soil_temperature_field_view
  public :: copy_soil_temperature_profile
  public :: soil_temperature_at_node
  public :: export_soil_temperature_restart
  public :: reconstruct_soil_temperature_restart

contains

  integer function soil_temperature_parameter_node_count(self) result(n)
    class(soil_temperature_parameters_t), intent(in) :: self
    n = self%active_nodes
  end function soil_temperature_parameter_node_count

  logical function soil_temperature_parameters_ready(self) result(ready)
    class(soil_temperature_parameters_t), intent(in) :: self
    integer :: n
    n = self%active_nodes
    ready = self%initialized .and. n >= 2
    if (.not. ready) return
    ready = allocated(self%dz_cm) .and. allocated(self%distance_above_cm) .and. allocated(self%theta_sat) .and. &
            allocated(self%f_quartz) .and. allocated(self%f_clay) .and. allocated(self%f_organic) .and. &
            allocated(self%fkk_qco_dry) .and. allocated(self%fk_qco_dry) .and. &
            allocated(self%fkk_qco_wet) .and. allocated(self%fk_qco_wet)
    if (.not. ready) return
    ready = size(self%dz_cm) == n .and. size(self%distance_above_cm) == n .and. size(self%theta_sat) == n .and. &
            size(self%f_quartz) == n .and. size(self%f_clay) == n .and. size(self%f_organic) == n .and. &
            size(self%fkk_qco_dry) == n .and. size(self%fk_qco_dry) == n .and. &
            size(self%fkk_qco_wet) == n .and. size(self%fk_qco_wet) == n
  end function soil_temperature_parameters_ready

  subroutine initialize_soil_temperature_state(initial_temperature_c, state, status)
    real(real64), intent(in) :: initial_temperature_c(:)
    type(soil_temperature_state_t), intent(out) :: state
    integer, intent(out) :: status
    integer :: i
    status = SOIL_TEMP_INVALID_STATE
    if (size(initial_temperature_c) < 2) return
    do i = 1, size(initial_temperature_c)
      if (.not. ieee_is_finite(initial_temperature_c(i))) return
    end do
    allocate(state%temperature_c(size(initial_temperature_c)))
    state%temperature_c = initial_temperature_c
    state%initialized = .true.
    status = SOIL_TEMP_OK
  end subroutine initialize_soil_temperature_state

  subroutine materialize_soil_temperature_trial_state(temperature_c, state, status)
    real(real64), intent(in) :: temperature_c(:)
    type(soil_temperature_state_t), intent(out) :: state
    integer, intent(out) :: status
    call initialize_soil_temperature_state(temperature_c, state, status)
  end subroutine materialize_soil_temperature_trial_state

  subroutine soil_temperature_state_clone(self, copy)
    class(soil_temperature_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy
    allocate(soil_temperature_state_t :: copy)
    select type (typed => copy)
    type is (soil_temperature_state_t)
      typed%initialized = self%initialized
      if (allocated(self%temperature_c)) then
        allocate(typed%temperature_c(size(self%temperature_c)))
        typed%temperature_c = self%temperature_c
      end if
    end select
  end subroutine soil_temperature_state_clone

  integer function soil_temperature_state_node_count(self) result(n)
    class(soil_temperature_state_t), intent(in) :: self
    n = 0
    if (allocated(self%temperature_c)) n = size(self%temperature_c)
  end function soil_temperature_state_node_count

  logical function soil_temperature_state_ready(self) result(ready)
    class(soil_temperature_state_t), intent(in) :: self
    ready = self%initialized .and. allocated(self%temperature_c)
    if (ready) ready = size(self%temperature_c) >= 2
  end function soil_temperature_state_ready

  subroutine commit_soil_temperature_state(committed_state, trial_state, status)
    type(soil_temperature_state_t), intent(inout) :: committed_state
    type(soil_temperature_state_t), intent(in) :: trial_state
    integer, intent(out) :: status
    real(real64), allocatable :: profile(:)
    status = SOIL_TEMP_INVALID_STATE
    if (.not. trial_state%ready()) return
    if (committed_state%ready()) then
      if (committed_state%node_count() /= trial_state%node_count()) return
    end if
    call copy_soil_temperature_profile(trial_state, profile, status)
    if (status /= SOIL_TEMP_OK) return
    if (allocated(committed_state%temperature_c)) deallocate(committed_state%temperature_c)
    call move_alloc(profile, committed_state%temperature_c)
    committed_state%initialized = .true.
    status = SOIL_TEMP_OK
  end subroutine commit_soil_temperature_state

  subroutine build_soil_temperature_field_view(state, view, status)
    type(soil_temperature_state_t), intent(in) :: state
    type(soil_temperature_field_view_t), intent(out) :: view
    integer, intent(out) :: status
    status = SOIL_TEMP_INVALID_STATE
    if (.not. state%ready()) return
    view%active_nodes = state%node_count()
    allocate(view%temperature_c(view%active_nodes))
    view%temperature_c = state%temperature_c
    status = SOIL_TEMP_OK
  end subroutine build_soil_temperature_field_view

  subroutine copy_soil_temperature_profile(state, temperature_c, status)
    type(soil_temperature_state_t), intent(in) :: state
    real(real64), allocatable, intent(out) :: temperature_c(:)
    integer, intent(out) :: status
    status = SOIL_TEMP_INVALID_STATE
    if (.not. state%ready()) return
    allocate(temperature_c(state%node_count()))
    temperature_c = state%temperature_c
    status = SOIL_TEMP_OK
  end subroutine copy_soil_temperature_profile

  subroutine soil_temperature_at_node(state, node, temperature_c, status)
    type(soil_temperature_state_t), intent(in) :: state
    integer, intent(in) :: node
    real(real64), intent(out) :: temperature_c
    integer, intent(out) :: status
    temperature_c = 0.0_real64
    status = SOIL_TEMP_INVALID_STATE
    if (.not. state%ready()) return
    if (node < 1 .or. node > state%node_count()) then
      status = SOIL_TEMP_INVALID_NODE
      return
    end if
    temperature_c = state%temperature_c(node)
    status = SOIL_TEMP_OK
  end subroutine soil_temperature_at_node

  subroutine export_soil_temperature_restart(state, payload, status)
    type(soil_temperature_state_t), intent(in) :: state
    type(soil_temperature_restart_payload_t), intent(out) :: payload
    integer, intent(out) :: status
    status = SOIL_TEMP_INVALID_STATE
    if (.not. state%ready()) return
    payload%schema_version = 1
    allocate(payload%temperature_c(state%node_count()))
    payload%temperature_c = state%temperature_c
    status = SOIL_TEMP_OK
  end subroutine export_soil_temperature_restart

  subroutine reconstruct_soil_temperature_restart(payload, state, status)
    type(soil_temperature_restart_payload_t), intent(in) :: payload
    type(soil_temperature_state_t), intent(out) :: state
    integer, intent(out) :: status
    status = SOIL_TEMP_INVALID_RESTART
    if (payload%schema_version /= 1 .or. .not. allocated(payload%temperature_c)) return
    call initialize_soil_temperature_state(payload%temperature_c, state, status)
    if (status /= SOIL_TEMP_OK) status = SOIL_TEMP_INVALID_RESTART
  end subroutine reconstruct_soil_temperature_restart

end module mod_soil_temperature_contract
