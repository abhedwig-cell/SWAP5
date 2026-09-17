module mod_rossfast_d3r_model_binding
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_quiet_nan, ieee_value
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, trial_outcome_t, &
       TX_MASS_MISSING_NONE, TX_MASS_MISSING_UNSPECIFIED, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_state_t, canonical_forcing_t, &
       canonical_interval_t, canonical_numerical_config_t, canonical_physical_model_t
  use mod_rossfast_d3r_execution_policy, only: ROSSFAST_D3R_OUTER_HORIZON_DAY, &
       ROSSFAST_D3R_RETRY_SCALE, ROSSFAST_D3R_MAX_FULL_INDEX, &
       ROSSFAST_D3R_MIN_FULL_DURATION_DAY, rossfast_d3r_full_duration_for_index
  implicit none
  private

  integer, parameter, public :: ROSSFAST_D3R_N_CELLS = 16
  real(real64), parameter, public :: ROSSFAST_D3R_DZ_CM = 10.0_real64
  real(real64), parameter, public :: ROSSFAST_D3R_SIGMA = 0.5_real64
  real(real64), parameter, public :: ROSSFAST_D3R_HARD_MASS_TOL_CM = 1.0e-12_real64
  real(real64), parameter, public :: ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION = 0.02_real64
  real(real64), parameter, public :: ROSSFAST_D3R_STATE_CONSISTENCY_TOL = 2.0e-12_real64
  real(real64), parameter, public :: ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR = 1.0e-10_real64
  real(real64), parameter, public :: ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE = 1.0e-5_real64
  real(real64), parameter, public :: ROSSFAST_D3R_H_MIN_CM = -10000.0_real64
  real(real64), parameter, public :: ROSSFAST_D3R_H_MAX_CM = -1.0_real64

  type, public :: rossfast_d3r_material_t
    character(len=3) :: material_id = '---'
    real(real64) :: theta_r = 0.0_real64
    real(real64) :: theta_s = 0.0_real64
    real(real64) :: alpha_per_cm = 0.0_real64
    real(real64) :: n = 0.0_real64
    real(real64) :: ksatfit_cm_per_day = 0.0_real64
    real(real64) :: ksatexm_cm_per_day = 0.0_real64
    real(real64) :: lambda = 0.0_real64
    real(real64) :: h_enpr_cm = 0.0_real64
  end type rossfast_d3r_material_t

  type, extends(canonical_state_t), public :: rossfast_d3r_state_t
    integer :: active_nodes = 0
    real(real64), allocatable :: pressure_head_cm(:)
    real(real64), allocatable :: water_content(:)
  contains
    procedure :: clone => rossfast_d3r_clone_state
  end type rossfast_d3r_state_t

  type, extends(canonical_forcing_t), public :: rossfast_d3r_forcing_t
    ! Restricted F-ROSS02 sign convention. Positive values enter the column.
    real(real64) :: top_flux_cm_per_day = 0.0_real64
    real(real64) :: bottom_flux_upward_cm_per_day = 0.0_real64
  end type rossfast_d3r_forcing_t

  type, public :: rossfast_d3r_kernel_request_t
    type(rossfast_d3r_material_t) :: material
    type(rossfast_d3r_state_t) :: base_state
    type(rossfast_d3r_forcing_t) :: forcing
    real(real64) :: t0_day = 0.0_real64
    real(real64) :: t1_day = 0.0_real64
    integer :: equal_internal_substeps = 0
    real(real64) :: sigma = ROSSFAST_D3R_SIGMA
    real(real64) :: hard_mass_tolerance_cm = ROSSFAST_D3R_HARD_MASS_TOL_CM
    real(real64) :: boundary_envelope_fraction = ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION
    real(real64) :: state_consistency_tolerance = ROSSFAST_D3R_STATE_CONSISTENCY_TOL
    real(real64) :: temporal_resolution_floor = ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR
    real(real64) :: temporal_accuracy_tolerance = ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE
  end type rossfast_d3r_kernel_request_t

  ! The kernel owns candidate hydraulics and the already-qualified temporal
  ! certificate. It deliberately does not own the external mass ledger or the
  ! accepted bottom exchange for this prescribed-flux production binding.
  type, public :: rossfast_d3r_kernel_result_t
    logical :: request_admitted = .false.
    logical :: solver_ok = .false.
    type(rossfast_d3r_state_t) :: candidate_state
    logical :: temporal_certificate_available = .false.
    real(real64) :: temporal_indicator = huge(0.0_real64)
    logical :: local_terminal_sensitivity_available = .false.
    real(real64) :: dh_bottom_dq_bottom_day = 0.0_real64
    integer :: internal_retries = 0
    integer :: linear_solves = 0
    integer :: alternative_solver_calls = 0
  end type rossfast_d3r_kernel_result_t

  type, abstract, public :: rossfast_d3r_trial_kernel_t
  contains
    procedure(rossfast_d3r_kernel_solve_iface), deferred :: solve
  end type rossfast_d3r_trial_kernel_t

  type, extends(canonical_physical_model_t), public :: rossfast_d3r_model_t
    private
    class(rossfast_d3r_trial_kernel_t), pointer :: kernel => null()
    type(rossfast_d3r_material_t) :: material
    real(real64), allocatable :: cell_thickness_cm(:)
    type(rossfast_d3r_forcing_t) :: forcing
    integer :: equal_internal_substeps = 0
    logical :: bound = .false.
    logical :: prepared = .false.
  contains
    procedure :: prepare_interval => rossfast_d3r_prepare_interval
    procedure :: advance => rossfast_d3r_advance
    procedure :: storage => rossfast_d3r_storage
    procedure :: temporal_error => rossfast_d3r_temporal_error
    procedure :: storage_accounting_status => rossfast_d3r_storage_accounting_status
  end type rossfast_d3r_model_t

  public :: bind_rossfast_d3r_model
  public :: rossfast_d3r_material_from_id
  public :: rossfast_d3r_material_is_admitted

  abstract interface
    subroutine rossfast_d3r_kernel_solve_iface(self, request, result)
      import :: rossfast_d3r_trial_kernel_t, rossfast_d3r_kernel_request_t, &
           rossfast_d3r_kernel_result_t
      class(rossfast_d3r_trial_kernel_t), intent(in) :: self
      type(rossfast_d3r_kernel_request_t), intent(in) :: request
      type(rossfast_d3r_kernel_result_t), intent(out) :: result
    end subroutine rossfast_d3r_kernel_solve_iface
  end interface

contains

  subroutine rossfast_d3r_clone_state(self, copy)
    class(rossfast_d3r_state_t), intent(in) :: self
    class(transaction_state_t), allocatable, intent(out) :: copy

    allocate(rossfast_d3r_state_t :: copy)
    select type(copy)
    type is(rossfast_d3r_state_t)
      copy%active_nodes = self%active_nodes
      if (allocated(self%pressure_head_cm)) then
        allocate(copy%pressure_head_cm(size(self%pressure_head_cm)))
        copy%pressure_head_cm = self%pressure_head_cm
      end if
      if (allocated(self%water_content)) then
        allocate(copy%water_content(size(self%water_content)))
        copy%water_content = self%water_content
      end if
    end select
  end subroutine rossfast_d3r_clone_state

  subroutine bind_rossfast_d3r_model(model, kernel, material, cell_thickness_cm, &
                                     equal_internal_substeps, valid)
    type(rossfast_d3r_model_t), intent(inout) :: model
    class(rossfast_d3r_trial_kernel_t), target, intent(in) :: kernel
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64), intent(in) :: cell_thickness_cm(:)
    integer, intent(in) :: equal_internal_substeps
    logical, intent(out) :: valid

    valid = .false.
    model%bound = .false.
    model%prepared = .false.
    nullify(model%kernel)
    if (allocated(model%cell_thickness_cm)) deallocate(model%cell_thickness_cm)

    if (.not. rossfast_d3r_material_is_admitted(material)) return
    if (size(cell_thickness_cm) /= ROSSFAST_D3R_N_CELLS) return
    if (.not. all(ieee_is_finite(cell_thickness_cm))) return
    if (any(cell_thickness_cm /= ROSSFAST_D3R_DZ_CM)) return
    if (.not. admitted_internal_substeps(equal_internal_substeps)) return

    model%kernel => kernel
    model%material = material
    allocate(model%cell_thickness_cm(ROSSFAST_D3R_N_CELLS))
    model%cell_thickness_cm = cell_thickness_cm
    model%equal_internal_substeps = equal_internal_substeps
    model%bound = .true.
    valid = .true.
  end subroutine bind_rossfast_d3r_model

  subroutine rossfast_d3r_prepare_interval(self, forcing, interval, config)
    class(rossfast_d3r_model_t), intent(inout) :: self
    class(canonical_forcing_t), intent(in) :: forcing
    type(canonical_interval_t), intent(in) :: interval
    type(canonical_numerical_config_t), intent(in) :: config

    self%prepared = .false.
    if (.not. self%bound .or. .not. associated(self%kernel)) return
    if (.not. outer_interval_admitted(interval%t0, interval%t1)) return
    if (config%transaction%temporal_mode /= TX_TEMPORAL_MODEL_CERTIFICATE) return
    if (config%transaction%retry_scale /= ROSSFAST_D3R_RETRY_SCALE) return
    if (config%transaction%max_retries /= ROSSFAST_D3R_MAX_FULL_INDEX) return
    if (config%transaction%mass_tolerance <= 0.0_real64 .or. &
        config%transaction%mass_tolerance > ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (config%max_committed_substeps <= 0) return

    select type(forcing)
    type is(rossfast_d3r_forcing_t)
      if (.not. ieee_is_finite(forcing%top_flux_cm_per_day)) return
      if (.not. ieee_is_finite(forcing%bottom_flux_upward_cm_per_day)) return
      self%forcing = forcing
    class default
      return
    end select
    self%prepared = .true.
  end subroutine rossfast_d3r_prepare_interval

  subroutine rossfast_d3r_advance(self, state, t0, t1, outcome)
    class(rossfast_d3r_model_t), intent(inout) :: self
    class(transaction_state_t), intent(inout) :: state
    real(real64), intent(in) :: t0, t1
    type(trial_outcome_t), intent(out) :: outcome
    type(rossfast_d3r_kernel_request_t) :: request
    type(rossfast_d3r_kernel_result_t) :: result
    real(real64) :: dt, top_transfer, bottom_transfer

    outcome = trial_outcome_t()
    if (.not. self%prepared .or. .not. associated(self%kernel)) return
    if (.not. full_attempt_interval_admitted(t0, t1)) return

    select type(state)
    type is(rossfast_d3r_state_t)
      if (.not. state_is_admitted(state, self%material)) return
      if (.not. forcing_is_admitted(state, self%material, self%forcing)) return
      request%material = self%material
      request%base_state = state
      request%forcing = self%forcing
      request%t0_day = t0
      request%t1_day = t1
      request%equal_internal_substeps = self%equal_internal_substeps
      call self%kernel%solve(request, result)

      if (.not. result%request_admitted .or. .not. result%solver_ok) return
      if (.not. state_is_admitted(result%candidate_state, self%material)) return

      ! In F-ROSS02 there are no distributed source/sink terms and both
      ! boundaries are prescribed fluxes. Therefore the binding, not the
      ! numerical kernel, owns the complete external water-transfer ledger.
      dt = t1 - t0
      top_transfer = dt * self%forcing%top_flux_cm_per_day
      bottom_transfer = dt * self%forcing%bottom_flux_upward_cm_per_day
      if (.not. ieee_is_finite(top_transfer) .or. .not. ieee_is_finite(bottom_transfer)) return

      state = result%candidate_state
      outcome%solver_ok = .true.
      outcome%mass_in = max(top_transfer, 0.0_real64) + max(bottom_transfer, 0.0_real64)
      outcome%mass_out = max(-top_transfer, 0.0_real64) + max(-bottom_transfer, 0.0_real64)
      outcome%mass_accounting_complete = .true.
      outcome%missing_mass_contribution_mask = TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available = result%temporal_certificate_available
      outcome%temporal_indicator = result%temporal_indicator

      ! Canonical outward is positive out of the column. RossFast forcing uses
      ! positive upward into the column, hence the sign inversion here.
      outcome%bottom_interface_exchange_available = .true.
      outcome%bottom_outward_exchange_native = -bottom_transfer
      outcome%terminal_bottom_outward_flux_native = -self%forcing%bottom_flux_upward_cm_per_day

      outcome%internal_retries = max(0, result%internal_retries)
      outcome%linear_solves = max(0, result%linear_solves)
      outcome%alternative_solver_calls = max(0, result%alternative_solver_calls)
      if (result%local_terminal_sensitivity_available .and. &
          ieee_is_finite(result%dh_bottom_dq_bottom_day) .and. &
          result%dh_bottom_dq_bottom_day > 0.0_real64) then
        outcome%interface_sensitivity%available = .true.
        outcome%interface_sensitivity%dh_bottom_dq_bottom = result%dh_bottom_dq_bottom_day
        outcome%interface_sensitivity%method = 'rossfast-local-terminal'
      end if
    class default
      return
    end select
  end subroutine rossfast_d3r_advance

  function rossfast_d3r_storage(self, state) result(value)
    class(rossfast_d3r_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    real(real64) :: value

    value = ieee_value(0.0_real64, ieee_quiet_nan)
    if (.not. self%bound .or. .not. allocated(self%cell_thickness_cm)) return
    select type(state)
    type is(rossfast_d3r_state_t)
      if (.not. state_is_admitted(state, self%material)) return
      value = sum(self%cell_thickness_cm * state%water_content)
    class default
      return
    end select
  end function rossfast_d3r_storage

  function rossfast_d3r_temporal_error(self, full_state, half_state) result(value)
    class(rossfast_d3r_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: full_state, half_state
    real(real64) :: value

    if (.not. same_type_as(self, self) .or. .not. same_type_as(full_state, full_state) .or. &
        .not. same_type_as(half_state, half_state)) error stop 'unreachable RossFast model types'
    value = huge(0.0_real64)
  end function rossfast_d3r_temporal_error

  subroutine rossfast_d3r_storage_accounting_status(self, state, complete, missing_mask)
    class(rossfast_d3r_model_t), intent(in) :: self
    class(transaction_state_t), intent(in) :: state
    logical, intent(out) :: complete
    integer(int64), intent(out) :: missing_mask

    complete = .false.
    missing_mask = TX_MASS_MISSING_UNSPECIFIED
    if (.not. self%bound .or. .not. allocated(self%cell_thickness_cm)) return
    select type(state)
    type is(rossfast_d3r_state_t)
      if (.not. state_is_admitted(state, self%material)) return
      complete = .true.
      missing_mask = TX_MASS_MISSING_NONE
    class default
      return
    end select
  end subroutine rossfast_d3r_storage_accounting_status

  pure logical function admitted_internal_substeps(value)
    integer, intent(in) :: value
    admitted_internal_substeps = value == 2 .or. value == 4 .or. value == 8 .or. value == 16
  end function admitted_internal_substeps

  logical function state_is_admitted(state, material)
    type(rossfast_d3r_state_t), intent(in) :: state
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: expected_theta, tol
    integer :: i

    state_is_admitted = .false.
    if (state%active_nodes /= ROSSFAST_D3R_N_CELLS) return
    if (.not. allocated(state%pressure_head_cm) .or. .not. allocated(state%water_content)) return
    if (size(state%pressure_head_cm) /= ROSSFAST_D3R_N_CELLS) return
    if (size(state%water_content) /= ROSSFAST_D3R_N_CELLS) return
    if (.not. all(ieee_is_finite(state%pressure_head_cm))) return
    if (.not. all(ieee_is_finite(state%water_content))) return
    if (any(state%pressure_head_cm <= ROSSFAST_D3R_H_MIN_CM)) return
    if (any(state%pressure_head_cm >= ROSSFAST_D3R_H_MAX_CM)) return
    if (any(state%water_content <= material%theta_r)) return
    if (any(state%water_content >= material%theta_s)) return

    tol = ROSSFAST_D3R_STATE_CONSISTENCY_TOL
    do i = 1, ROSSFAST_D3R_N_CELLS
      expected_theta = water_content_from_head(state%pressure_head_cm(i), material)
      if (.not. ieee_is_finite(expected_theta)) return
      if (abs(state%water_content(i) - expected_theta) > tol) return
    end do
    state_is_admitted = .true.
  end function state_is_admitted

  logical function forcing_is_admitted(state, material, forcing)
    type(rossfast_d3r_state_t), intent(in) :: state
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_forcing_t), intent(in) :: forcing
    real(real64) :: k_top, k_bottom, q_top_ref, q_bottom_up_ref
    real(real64) :: top_scale, bottom_scale, top_limit, bottom_limit

    forcing_is_admitted = .false.
    if (.not. ieee_is_finite(forcing%top_flux_cm_per_day) .or. &
        .not. ieee_is_finite(forcing%bottom_flux_upward_cm_per_day)) return
    k_top = conductivity_from_head(state%pressure_head_cm(1), material)
    k_bottom = conductivity_from_head(state%pressure_head_cm(ROSSFAST_D3R_N_CELLS), material)
    if (.not. ieee_is_finite(k_top) .or. .not. ieee_is_finite(k_bottom)) return
    if (k_top <= 0.0_real64 .or. k_bottom <= 0.0_real64) return

    ! Exact D2/D3R state-local boundary envelope inherited from the qualified
    ! research adapter. The historical worker uses downward-positive q_bottom;
    ! this binding exposes bottom upward-positive, hence the minus sign.
    q_top_ref = 0.01_real64 * k_top
    q_bottom_up_ref = -0.004_real64 * k_bottom
    top_scale = max(abs(q_top_ref), abs(k_top), 1.0e-12_real64)
    bottom_scale = max(abs(q_bottom_up_ref), abs(k_bottom), 1.0e-12_real64)
    top_limit = ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION * top_scale
    bottom_limit = ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION * bottom_scale
    if (abs(forcing%top_flux_cm_per_day - q_top_ref) > top_limit + 1.0e-15_real64) return
    if (abs(forcing%bottom_flux_upward_cm_per_day - q_bottom_up_ref) > bottom_limit + 1.0e-15_real64) return
    forcing_is_admitted = .true.
  end function forcing_is_admitted

  pure real(real64) function effective_saturation_from_head(head_cm, material) result(s)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: m

    if (head_cm >= 0.0_real64) then
      s = 1.0_real64
      return
    end if
    m = 1.0_real64 - 1.0_real64 / material%n
    s = (1.0_real64 + abs(material%alpha_per_cm * head_cm)**material%n)**(-m)
  end function effective_saturation_from_head

  pure real(real64) function water_content_from_head(head_cm, material) result(theta)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: s

    s = effective_saturation_from_head(head_cm, material)
    theta = material%theta_r + (material%theta_s - material%theta_r) * s
  end function water_content_from_head

  pure real(real64) function conductivity_from_head(head_cm, material) result(conductivity)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real64) :: s, m, term

    s = effective_saturation_from_head(head_cm, material)
    if (s >= 1.0_real64) then
      conductivity = material%ksatfit_cm_per_day
      return
    end if
    m = 1.0_real64 - 1.0_real64 / material%n
    term = (1.0_real64 - s**(1.0_real64 / m))**m
    conductivity = material%ksatfit_cm_per_day * s**material%lambda * (1.0_real64 - term)**2
  end function conductivity_from_head

  logical function full_attempt_interval_admitted(t0, t1)
    real(real64), intent(in) :: t0, t1
    real(real64) :: duration, expected_t1, tol
    integer :: index

    full_attempt_interval_admitted = .false.
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    do index = 0, ROSSFAST_D3R_MAX_FULL_INDEX
      duration = rossfast_d3r_full_duration_for_index(index)
      expected_t1 = t0 + duration
      tol = 2.0_real64 * max(spacing(t0), spacing(t1), spacing(expected_t1), spacing(duration))
      if (abs(t1 - expected_t1) <= tol) then
        full_attempt_interval_admitted = .true.
        return
      end if
    end do
  end function full_attempt_interval_admitted

  logical function outer_interval_admitted(t0, t1)
    real(real64), intent(in) :: t0, t1
    real(real64) :: remainder, grid_value, units_real, tol
    integer :: grid_units

    outer_interval_admitted = .false.
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    remainder = t1 - t0
    if (.not. ieee_is_finite(remainder)) return
    tol = 2.0_real64 * max(spacing(t0), spacing(t1), spacing(remainder), &
         spacing(ROSSFAST_D3R_OUTER_HORIZON_DAY))
    if (remainder > ROSSFAST_D3R_OUTER_HORIZON_DAY + tol) return
    units_real = remainder / ROSSFAST_D3R_MIN_FULL_DURATION_DAY
    grid_units = nint(units_real)
    if (grid_units < 1) return
    grid_value = real(grid_units, real64) * ROSSFAST_D3R_MIN_FULL_DURATION_DAY
    tol = 2.0_real64 * max(spacing(t0), spacing(t1), spacing(remainder), spacing(grid_value), &
         spacing(ROSSFAST_D3R_MIN_FULL_DURATION_DAY))
    outer_interval_admitted = abs(remainder - grid_value) <= tol
  end function outer_interval_admitted

  pure logical function rossfast_d3r_material_is_admitted(material)
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_material_t) :: expected
    logical :: found

    call rossfast_d3r_material_from_id(material%material_id, expected, found)
    rossfast_d3r_material_is_admitted = found .and. &
         material%theta_r == expected%theta_r .and. &
         material%theta_s == expected%theta_s .and. &
         material%alpha_per_cm == expected%alpha_per_cm .and. &
         material%n == expected%n .and. &
         material%ksatfit_cm_per_day == expected%ksatfit_cm_per_day .and. &
         material%ksatexm_cm_per_day == expected%ksatexm_cm_per_day .and. &
         material%lambda == expected%lambda .and. &
         material%h_enpr_cm == expected%h_enpr_cm
  end function rossfast_d3r_material_is_admitted

  pure subroutine rossfast_d3r_material_from_id(material_id, material, found)
    character(len=*), intent(in) :: material_id
    type(rossfast_d3r_material_t), intent(out) :: material
    logical, intent(out) :: found

    material = rossfast_d3r_material_t()
    found = .true.
    select case(trim(material_id))
    case('B01')
      material = rossfast_d3r_material_t('B01', 0.02_real64, 0.427494_real64, &
           0.021659_real64, 1.734737_real64, 31.225016_real64, 312.25016_real64, &
           0.98087_real64, 0.0_real64)
    case('B02')
      material = rossfast_d3r_material_t('B02', 0.02_real64, 0.433878_real64, &
           0.021645_real64, 1.34877_real64, 83.241635_real64, 832.41635_real64, &
           7.202077_real64, 0.0_real64)
    case('B03')
      material = rossfast_d3r_material_t('B03', 0.02_real64, 0.44279_real64, &
           0.014993_real64, 1.50488_real64, 19.077237_real64, 190.77237_real64, &
           0.139209_real64, 0.0_real64)
    case('B04')
      material = rossfast_d3r_material_t('B04', 0.02_real64, 0.461926_real64, &
           0.01488_real64, 1.39685_real64, 34.884276_real64, 348.84276_real64, &
           0.294536_real64, 0.0_real64)
    case('B05')
      material = rossfast_d3r_material_t('B05', 0.01_real64, 0.380881_real64, &
           0.042807_real64, 1.8078_real64, 63.650403_real64, 636.50403_real64, &
           0.024227_real64, 0.0_real64)
    case('B06')
      material = rossfast_d3r_material_t('B06', 0.01_real64, 0.384816_real64, &
           0.020923_real64, 1.24225_real64, 104.103005_real64, 1041.03005_real64, &
           -1.20013_real64, 0.0_real64)
    case('B07')
      material = rossfast_d3r_material_t('B07', 0.0_real64, 0.400582_real64, &
           0.018349_real64, 1.248279_real64, 14.582327_real64, 510.381445_real64, &
           0.952016_real64, 0.0_real64)
    case('B08')
      material = rossfast_d3r_material_t('B08', 0.01_real64, 0.432651_real64, &
           0.010478_real64, 1.277992_real64, 3.002741_real64, 105.095935_real64, &
           -1.919289_real64, 0.0_real64)
    case('B09')
      material = rossfast_d3r_material_t('B09', 0.0_real64, 0.429539_real64, &
           0.006964_real64, 1.267179_real64, 1.747586_real64, 61.16551_real64, &
           -2.387059_real64, 0.0_real64)
    case('B10')
      material = rossfast_d3r_material_t('B10', 0.01_real64, 0.448112_real64, &
           0.012834_real64, 1.13525_real64, 3.832283_real64, 306.58264_real64, &
           4.580513_real64, 0.0_real64)
    case('B11')
      material = rossfast_d3r_material_t('B11', 0.01_real64, 0.591286_real64, &
           0.02162_real64, 1.106695_real64, 6.30532_real64, 504.4256_real64, &
           -5.549216_real64, 0.0_real64)
    case('B12')
      material = rossfast_d3r_material_t('B12', 0.01_real64, 0.529749_real64, &
           0.016562_real64, 1.090671_real64, 2.245895_real64, 179.6716_real64, &
           -4.493581_real64, 0.0_real64)
    case('B13')
      material = rossfast_d3r_material_t('B13', 0.01_real64, 0.416084_real64, &
           0.008362_real64, 1.437024_real64, 29.832408_real64, 59.664816_real64, &
           -1.356913_real64, 0.0_real64)
    case('B14')
      material = rossfast_d3r_material_t('B14', 0.01_real64, 0.416774_real64, &
           0.00541_real64, 1.301528_real64, 0.895023_real64, 1.790046_real64, &
           -0.334926_real64, 0.0_real64)
    case('B15')
      material = rossfast_d3r_material_t('B15', 0.01_real64, 0.528458_real64, &
           0.023731_real64, 1.282347_real64, 87.450789_real64, 262.352367_real64, &
           -1.477564_real64, 0.0_real64)
    case('B16')
      material = rossfast_d3r_material_t('B16', 0.01_real64, 0.786061_real64, &
           0.021072_real64, 1.278798_real64, 12.357246_real64, 37.071738_real64, &
           -1.220936_real64, 0.0_real64)
    case('B17')
      material = rossfast_d3r_material_t('B17', 0.0_real64, 0.718626_real64, &
           0.019062_real64, 1.136658_real64, 4.483735_real64, 13.451205_real64, &
           0.0001_real64, 0.0_real64)
    case('B18')
      material = rossfast_d3r_material_t('B18', 0.0_real64, 0.765452_real64, &
           0.020468_real64, 1.150709_real64, 13.144562_real64, 39.433686_real64, &
           0.0001_real64, 0.0_real64)
    case('O01')
      material = rossfast_d3r_material_t('O01', 0.01_real64, 0.365847_real64, &
           0.015987_real64, 2.162751_real64, 22.322154_real64, 223.22154_real64, &
           2.867967_real64, 0.0_real64)
    case('O02')
      material = rossfast_d3r_material_t('O02', 0.02_real64, 0.387064_real64, &
           0.016083_real64, 1.524418_real64, 22.761756_real64, 227.61756_real64, &
           2.439662_real64, 0.0_real64)
    case('O03')
      material = rossfast_d3r_material_t('O03', 0.01_real64, 0.33981_real64, &
           0.017243_real64, 1.703395_real64, 12.36681_real64, 123.6681_real64, &
           0.0001_real64, 0.0_real64)
    case('O04')
      material = rossfast_d3r_material_t('O04', 0.01_real64, 0.364074_real64, &
           0.013642_real64, 1.48844_real64, 25.814715_real64, 258.14715_real64, &
           2.179397_real64, 0.0_real64)
    case('O05')
      material = rossfast_d3r_material_t('O05', 0.01_real64, 0.336701_real64, &
           0.030304_real64, 2.887502_real64, 17.418504_real64, 174.18504_real64, &
           0.0736_real64, 0.0_real64)
    case('O06')
      material = rossfast_d3r_material_t('O06', 0.01_real64, 0.333434_real64, &
           0.015959_real64, 1.288705_real64, 32.833899_real64, 328.33899_real64, &
           -1.009748_real64, 0.0_real64)
    case('O07')
      material = rossfast_d3r_material_t('O07', 0.01_real64, 0.513126_real64, &
           0.011985_real64, 1.153018_real64, 37.55042_real64, 375.5042_real64, &
           -2.013289_real64, 0.0_real64)
    case('O08')
      material = rossfast_d3r_material_t('O08', 0.0_real64, 0.453751_real64, &
           0.011324_real64, 1.345968_real64, 8.64086_real64, 302.4301_real64, &
           -0.903823_real64, 0.0_real64)
    case('O09')
      material = rossfast_d3r_material_t('O09', 0.0_real64, 0.458246_real64, &
           0.009715_real64, 1.375784_real64, 3.766627_real64, 131.831945_real64, &
           -1.013083_real64, 0.0_real64)
    case('O10')
      material = rossfast_d3r_material_t('O10', 0.01_real64, 0.472343_real64, &
           0.010048_real64, 1.245691_real64, 2.300067_real64, 80.502345_real64, &
           -0.792959_real64, 0.0_real64)
    case('O11')
      material = rossfast_d3r_material_t('O11', 0.0_real64, 0.443617_real64, &
           0.014316_real64, 1.126001_real64, 2.122436_real64, 169.79488_real64, &
           2.357139_real64, 0.0_real64)
    case('O12')
      material = rossfast_d3r_material_t('O12', 0.01_real64, 0.560703_real64, &
           0.008813_real64, 1.158128_real64, 1.079729_real64, 86.37832_real64, &
           -3.172265_real64, 0.0_real64)
    case('O13')
      material = rossfast_d3r_material_t('O13', 0.01_real64, 0.573268_real64, &
           0.027854_real64, 1.079952_real64, 9.689291_real64, 775.14328_real64, &
           -6.091311_real64, 0.0_real64)
    case('O14')
      material = rossfast_d3r_material_t('O14', 0.01_real64, 0.393878_real64, &
           0.003288_real64, 1.616573_real64, 2.495984_real64, 4.991968_real64, &
           0.514012_real64, 0.0_real64)
    case('O15')
      material = rossfast_d3r_material_t('O15', 0.01_real64, 0.410058_real64, &
           0.007756_real64, 1.287343_real64, 2.791251_real64, 5.582502_real64, &
           0.0001_real64, 0.0_real64)
    case('O16')
      material = rossfast_d3r_material_t('O16', 0.0_real64, 0.889246_real64, &
           0.009711_real64, 1.363576_real64, 1.462624_real64, 4.387872_real64, &
           -0.664647_real64, 0.0_real64)
    case('O17')
      material = rossfast_d3r_material_t('O17', 0.01_real64, 0.848635_real64, &
           0.011929_real64, 1.271536_real64, 3.402009_real64, 10.206027_real64, &
           -1.2493_real64, 0.0_real64)
    case('O18')
      material = rossfast_d3r_material_t('O18', 0.01_real64, 0.580278_real64, &
           0.012657_real64, 1.316172_real64, 35.951279_real64, 107.853837_real64, &
           -0.785534_real64, 0.0_real64)
    case default
      found = .false.
    end select
  end subroutine rossfast_d3r_material_from_id

end module mod_rossfast_d3r_model_binding
