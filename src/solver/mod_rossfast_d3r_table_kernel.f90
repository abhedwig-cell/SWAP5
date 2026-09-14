module mod_rossfast_d3r_table_kernel
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real32, real64
  use mod_rossfast_d3r_model_binding, only: rossfast_d3r_trial_kernel_t, &
       rossfast_d3r_kernel_request_t, rossfast_d3r_kernel_result_t, &
       rossfast_d3r_material_t, rossfast_d3r_state_t, rossfast_d3r_forcing_t, &
       rossfast_d3r_material_is_admitted, ROSSFAST_D3R_N_CELLS, ROSSFAST_D3R_DZ_CM, &
       ROSSFAST_D3R_SIGMA, ROSSFAST_D3R_HARD_MASS_TOL_CM, &
       ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION, ROSSFAST_D3R_STATE_CONSISTENCY_TOL, &
       ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR, ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE, &
       ROSSFAST_D3R_H_MIN_CM, ROSSFAST_D3R_H_MAX_CM
  implicit none
  private

  integer, parameter, public :: ROSSFAST_D3R_TABLE_N = 241
  real(real64), parameter :: TABLE_DXDU = real(ROSSFAST_D3R_TABLE_N - 1, real64) / 4.0_real64
  real(real64), parameter :: LN10 = log(10.0_real64)
  integer, parameter :: CERTIFICATE_INTERNAL_SUBSTEPS = 8

  type :: face_linearization_t
    real(real64) :: q0 = 0.0_real64
    real(real64) :: dq_dtheta_upper = 0.0_real64
    real(real64) :: dq_dtheta_lower = 0.0_real64
  end type face_linearization_t

  type, extends(rossfast_d3r_trial_kernel_t), public :: rossfast_d3r_table_kernel_t
    private
    type(rossfast_d3r_material_t) :: material
    real(real32), allocatable :: log_mobility(:,:)
    logical :: initialized = .false.
  contains
    procedure :: solve => rossfast_d3r_table_kernel_solve
  end type rossfast_d3r_table_kernel_t

  public :: initialize_rossfast_d3r_table_kernel

contains

  subroutine initialize_rossfast_d3r_table_kernel(kernel, material, log_mobility, valid)
    type(rossfast_d3r_table_kernel_t), intent(inout) :: kernel
    type(rossfast_d3r_material_t), intent(in) :: material
    real(real32), intent(in) :: log_mobility(:,:)
    logical, intent(out) :: valid

    valid = .false.
    kernel%initialized = .false.
    if (allocated(kernel%log_mobility)) deallocate(kernel%log_mobility)
    if (.not. rossfast_d3r_material_is_admitted(material)) return
    if (size(log_mobility, 1) /= ROSSFAST_D3R_TABLE_N .or. &
        size(log_mobility, 2) /= ROSSFAST_D3R_TABLE_N) return
    if (.not. all(ieee_is_finite(log_mobility))) return

    kernel%material = material
    allocate(kernel%log_mobility(ROSSFAST_D3R_TABLE_N, ROSSFAST_D3R_TABLE_N))
    kernel%log_mobility = log_mobility
    kernel%initialized = .true.
    valid = .true.
  end subroutine initialize_rossfast_d3r_table_kernel

  subroutine rossfast_d3r_table_kernel_solve(self, request, result)
    class(rossfast_d3r_table_kernel_t), intent(in) :: self
    type(rossfast_d3r_kernel_request_t), intent(in) :: request
    type(rossfast_d3r_kernel_result_t), intent(out) :: result
    type(rossfast_d3r_state_t) :: coarse, half1, refined
    real(real64) :: duration, half_duration, span, raw_estimator, bound
    integer :: coarse_solves, half1_solves, half2_solves
    logical :: ok

    result = rossfast_d3r_kernel_result_t()
    if (.not. self%initialized .or. .not. allocated(self%log_mobility)) return
    if (.not. same_material(request%material, self%material)) return
    if (.not. request_contract_is_admitted(request)) return
    if (.not. valid_state(request%base_state)) return

    result%request_admitted = .true.
    duration = request%t1_day - request%t0_day
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64) return
    half_duration = 0.5_real64 * duration

    call run_window(self, request%material, request%forcing, request%base_state, duration, &
         coarse, coarse_solves, ok)
    if (.not. ok) return
    call run_window(self, request%material, request%forcing, request%base_state, half_duration, &
         half1, half1_solves, ok)
    if (.not. ok) return
    call run_window(self, request%material, request%forcing, half1, half_duration, &
         refined, half2_solves, ok)
    if (.not. ok) return

    span = request%material%theta_s - request%material%theta_r
    if (.not. ieee_is_finite(span) .or. span <= 0.0_real64) return
    raw_estimator = maxval(abs(refined%water_content - coarse%water_content)) / span
    if (.not. ieee_is_finite(raw_estimator) .or. raw_estimator < 0.0_real64) return
    bound = max(raw_estimator, ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR)

    result%candidate_state = refined
    result%temporal_certificate_available = .true.
    result%temporal_indicator = bound / ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE
    if (.not. ieee_is_finite(result%temporal_indicator) .or. result%temporal_indicator < 0.0_real64) then
      result%temporal_certificate_available = .false.
      result%temporal_indicator = huge(0.0_real64)
      return
    end if
    result%linear_solves = coarse_solves + half1_solves + half2_solves
    result%solver_ok = .true.
  end subroutine rossfast_d3r_table_kernel_solve

  logical function request_contract_is_admitted(request)
    type(rossfast_d3r_kernel_request_t), intent(in) :: request

    request_contract_is_admitted = .false.
    if (request%base_state%active_nodes /= ROSSFAST_D3R_N_CELLS) return
    ! The admitted D3G02R3 certificate matrix used exactly eight internal
    ! substeps for each coarse/half component trial. Other D2 counts remain
    ! research-only and are not silently generalized by this production kernel.
    if (request%equal_internal_substeps /= CERTIFICATE_INTERNAL_SUBSTEPS) return
    if (request%sigma /= ROSSFAST_D3R_SIGMA) return
    if (request%hard_mass_tolerance_cm /= ROSSFAST_D3R_HARD_MASS_TOL_CM) return
    if (request%boundary_envelope_fraction /= ROSSFAST_D3R_BOUNDARY_ENVELOPE_FRACTION) return
    if (request%state_consistency_tolerance /= ROSSFAST_D3R_STATE_CONSISTENCY_TOL) return
    if (request%temporal_resolution_floor /= ROSSFAST_D3R_TEMPORAL_RESOLUTION_FLOOR) return
    if (request%temporal_accuracy_tolerance /= ROSSFAST_D3R_TEMPORAL_ACCURACY_TOLERANCE) return
    if (.not. ieee_is_finite(request%t0_day) .or. .not. ieee_is_finite(request%t1_day)) return
    if (request%t1_day <= request%t0_day) return
    if (.not. ieee_is_finite(request%forcing%top_flux_cm_per_day)) return
    if (.not. ieee_is_finite(request%forcing%bottom_flux_upward_cm_per_day)) return
    request_contract_is_admitted = .true.
  end function request_contract_is_admitted

  subroutine run_window(self, material, forcing, initial_state, duration, terminal_state, linear_solves, ok)
    class(rossfast_d3r_table_kernel_t), intent(in) :: self
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_forcing_t), intent(in) :: forcing
    type(rossfast_d3r_state_t), intent(in) :: initial_state
    real(real64), intent(in) :: duration
    type(rossfast_d3r_state_t), intent(out) :: terminal_state
    integer, intent(out) :: linear_solves
    logical, intent(out) :: ok
    real(real64) :: dt
    integer :: istep

    ok = .false.
    linear_solves = 0
    if (.not. valid_state(initial_state)) return
    if (.not. ieee_is_finite(duration) .or. duration <= 0.0_real64) return
    terminal_state = initial_state
    dt = duration / real(CERTIFICATE_INTERNAL_SUBSTEPS, real64)
    if (.not. ieee_is_finite(dt) .or. dt <= 0.0_real64) return

    do istep = 1, CERTIFICATE_INTERNAL_SUBSTEPS
      call candidate_step(self, material, forcing, terminal_state, dt, ok)
      if (.not. ok) return
      linear_solves = linear_solves + 1
    end do
    ok = .true.
  end subroutine run_window

  subroutine candidate_step(self, material, forcing, state, dt, ok)
    class(rossfast_d3r_table_kernel_t), intent(in) :: self
    type(rossfast_d3r_material_t), intent(in) :: material
    type(rossfast_d3r_forcing_t), intent(in) :: forcing
    type(rossfast_d3r_state_t), intent(inout) :: state
    real(real64), intent(in) :: dt
    type(face_linearization_t) :: faces(ROSSFAST_D3R_N_CELLS - 1)
    real(real64) :: lower(ROSSFAST_D3R_N_CELLS - 1)
    real(real64) :: diag(ROSSFAST_D3R_N_CELLS)
    real(real64) :: upper(ROSSFAST_D3R_N_CELLS - 1)
    real(real64) :: rhs(ROSSFAST_D3R_N_CELLS)
    real(real64) :: delta(ROSSFAST_D3R_N_CELLS)
    real(real64) :: inv_capacity(ROSSFAST_D3R_N_CELLS)
    real(real64) :: q_top, q_bottom_down, fac, linfac, q_in0, q_out0
    integer :: i
    logical :: face_ok, solve_ok

    ok = .false.
    if (.not. valid_state(state)) return
    if (.not. ieee_is_finite(dt) .or. dt <= 0.0_real64) return

    do i = 1, ROSSFAST_D3R_N_CELLS
      inv_capacity(i) = inverse_capacity(state%pressure_head_cm(i), material, face_ok)
      if (.not. face_ok) return
    end do
    do i = 1, ROSSFAST_D3R_N_CELLS - 1
      call table_face_linearization(self, state%pressure_head_cm(i), state%pressure_head_cm(i + 1), &
           inv_capacity(i), inv_capacity(i + 1), faces(i), face_ok)
      if (.not. face_ok) return
    end do

    lower = 0.0_real64
    diag = 1.0_real64
    upper = 0.0_real64
    rhs = 0.0_real64
    q_top = forcing%top_flux_cm_per_day
    q_bottom_down = -forcing%bottom_flux_upward_cm_per_day
    fac = dt / ROSSFAST_D3R_DZ_CM
    linfac = fac * ROSSFAST_D3R_SIGMA

    do i = 1, ROSSFAST_D3R_N_CELLS
      if (i == 1) then
        q_in0 = q_top
      else
        q_in0 = faces(i - 1)%q0
      end if
      if (i == ROSSFAST_D3R_N_CELLS) then
        q_out0 = q_bottom_down
      else
        q_out0 = faces(i)%q0
      end if
      rhs(i) = fac * (q_in0 - q_out0)

      if (i > 1) then
        lower(i - 1) = lower(i - 1) - linfac * faces(i - 1)%dq_dtheta_upper
        diag(i) = diag(i) - linfac * faces(i - 1)%dq_dtheta_lower
      end if
      if (i < ROSSFAST_D3R_N_CELLS) then
        diag(i) = diag(i) + linfac * faces(i)%dq_dtheta_upper
        upper(i) = upper(i) + linfac * faces(i)%dq_dtheta_lower
      end if
    end do

    call factor_and_solve(lower, diag, upper, rhs, delta, solve_ok)
    if (.not. solve_ok) return
    if (.not. all(ieee_is_finite(delta))) return

    state%water_content = state%water_content + delta
    do i = 1, ROSSFAST_D3R_N_CELLS
      state%pressure_head_cm(i) = head_from_water_content(state%water_content(i), material, face_ok)
      if (.not. face_ok) return
    end do
    if (.not. valid_state(state)) return
    ok = .true.
  end subroutine candidate_step

  subroutine table_face_linearization(self, h_upper, h_lower, inv_capacity_upper, inv_capacity_lower, face, ok)
    class(rossfast_d3r_table_kernel_t), intent(in) :: self
    real(real64), intent(in) :: h_upper, h_lower, inv_capacity_upper, inv_capacity_lower
    type(face_linearization_t), intent(out) :: face
    logical, intent(out) :: ok
    real(real64) :: u_upper, u_lower, x_upper, x_lower, f_upper, f_lower
    real(real64) :: l00, l10, l01, l11, ell, dell_du_upper, dell_du_lower
    real(real64) :: mobility, driving, dq_dh_upper, dq_dh_lower
    integer :: i_upper, i_lower

    face = face_linearization_t()
    ok = .false.
    if (.not. ieee_is_finite(h_upper) .or. .not. ieee_is_finite(h_lower)) return
    if (h_upper <= ROSSFAST_D3R_H_MIN_CM .or. h_upper >= ROSSFAST_D3R_H_MAX_CM) return
    if (h_lower <= ROSSFAST_D3R_H_MIN_CM .or. h_lower >= ROSSFAST_D3R_H_MAX_CM) return

    u_upper = log10(-h_upper)
    u_lower = log10(-h_lower)
    x_upper = TABLE_DXDU * u_upper
    x_lower = TABLE_DXDU * u_lower
    i_upper = floor(x_upper)
    i_lower = floor(x_lower)
    i_upper = min(ROSSFAST_D3R_TABLE_N - 2, max(0, i_upper))
    i_lower = min(ROSSFAST_D3R_TABLE_N - 2, max(0, i_lower))
    f_upper = x_upper - real(i_upper, real64)
    f_lower = x_lower - real(i_lower, real64)

    ! J1A's admitted analytic face derivative is strict-cell-interior only.
    if (f_upper <= 0.0_real64 .or. f_upper >= 1.0_real64) return
    if (f_lower <= 0.0_real64 .or. f_lower >= 1.0_real64) return

    l00 = real(self%log_mobility(i_upper + 1, i_lower + 1), real64)
    l10 = real(self%log_mobility(i_upper + 2, i_lower + 1), real64)
    l01 = real(self%log_mobility(i_upper + 1, i_lower + 2), real64)
    l11 = real(self%log_mobility(i_upper + 2, i_lower + 2), real64)
    ell = (1.0_real64 - f_upper) * (1.0_real64 - f_lower) * l00 + &
          f_upper * (1.0_real64 - f_lower) * l10 + &
          (1.0_real64 - f_upper) * f_lower * l01 + f_upper * f_lower * l11
    dell_du_upper = TABLE_DXDU * ((1.0_real64 - f_lower) * (l10 - l00) + &
         f_lower * (l11 - l01))
    dell_du_lower = TABLE_DXDU * ((1.0_real64 - f_upper) * (l01 - l00) + &
         f_upper * (l11 - l10))
    mobility = exp(ell)
    if (.not. ieee_is_finite(mobility) .or. mobility <= 0.0_real64) return

    driving = ROSSFAST_D3R_DZ_CM + h_upper - h_lower
    face%q0 = driving * mobility
    dq_dh_upper = mobility * (1.0_real64 + driving * dell_du_upper / (LN10 * h_upper))
    dq_dh_lower = mobility * (-1.0_real64 + driving * dell_du_lower / (LN10 * h_lower))
    face%dq_dtheta_upper = dq_dh_upper * inv_capacity_upper
    face%dq_dtheta_lower = dq_dh_lower * inv_capacity_lower
    if (.not. ieee_is_finite(face%q0) .or. &
        .not. ieee_is_finite(face%dq_dtheta_upper) .or. &
        .not. ieee_is_finite(face%dq_dtheta_lower)) return
    ok = .true.
  end subroutine table_face_linearization

  pure real(real64) function inverse_capacity(head_cm, material, ok) result(value)
    real(real64), intent(in) :: head_cm
    type(rossfast_d3r_material_t), intent(in) :: material
    logical, intent(out) :: ok
    real(real64) :: m, x, dsdh, capacity

    value = 0.0_real64
    ok = .false.
    if (.not. ieee_is_finite(head_cm) .or. head_cm >= 0.0_real64) return
    m = 1.0_real64 - 1.0_real64 / material%n
    x = abs(material%alpha_per_cm * head_cm)
    dsdh = m * material%n * material%alpha_per_cm * x**(material%n - 1.0_real64) * &
         (1.0_real64 + x**material%n)**(-m - 1.0_real64)
    capacity = (material%theta_s - material%theta_r) * dsdh
    if (.not. ieee_is_finite(capacity) .or. capacity <= 0.0_real64) return
    value = 1.0_real64 / capacity
    ok = ieee_is_finite(value) .and. value > 0.0_real64
  end function inverse_capacity

  pure real(real64) function head_from_water_content(theta, material, ok) result(head_cm)
    real(real64), intent(in) :: theta
    type(rossfast_d3r_material_t), intent(in) :: material
    logical, intent(out) :: ok
    real(real64) :: span, s, m

    head_cm = 0.0_real64
    ok = .false.
    span = material%theta_s - material%theta_r
    if (.not. ieee_is_finite(theta) .or. .not. ieee_is_finite(span) .or. span <= 0.0_real64) return
    s = (theta - material%theta_r) / span
    if (s <= 0.0_real64 .or. s >= 1.0_real64) return
    m = 1.0_real64 - 1.0_real64 / material%n
    head_cm = -((s**(-1.0_real64 / m) - 1.0_real64)**(1.0_real64 / material%n)) / material%alpha_per_cm
    if (.not. ieee_is_finite(head_cm)) return
    if (head_cm <= ROSSFAST_D3R_H_MIN_CM .or. head_cm >= ROSSFAST_D3R_H_MAX_CM) return
    ok = .true.
  end function head_from_water_content

  subroutine factor_and_solve(lower, diag, upper, rhs, x, ok)
    real(real64), intent(in) :: lower(:), diag(:), upper(:), rhs(:)
    real(real64), intent(out) :: x(:)
    logical, intent(out) :: ok
    real(real64) :: d(ROSSFAST_D3R_N_CELLS)
    real(real64) :: u(ROSSFAST_D3R_N_CELLS - 1)
    real(real64) :: multipliers(ROSSFAST_D3R_N_CELLS - 1)
    real(real64) :: y(ROSSFAST_D3R_N_CELLS), w
    integer :: i

    ok = .false.
    x = 0.0_real64
    if (size(lower) /= ROSSFAST_D3R_N_CELLS - 1 .or. &
        size(diag) /= ROSSFAST_D3R_N_CELLS .or. &
        size(upper) /= ROSSFAST_D3R_N_CELLS - 1 .or. &
        size(rhs) /= ROSSFAST_D3R_N_CELLS .or. &
        size(x) /= ROSSFAST_D3R_N_CELLS) return
    if (.not. all(ieee_is_finite(lower)) .or. .not. all(ieee_is_finite(diag)) .or. &
        .not. all(ieee_is_finite(upper)) .or. .not. all(ieee_is_finite(rhs))) return

    d = diag
    u = upper
    multipliers = 0.0_real64
    do i = 2, ROSSFAST_D3R_N_CELLS
      if (d(i - 1) == 0.0_real64 .or. .not. ieee_is_finite(d(i - 1))) return
      w = lower(i - 1) / d(i - 1)
      multipliers(i - 1) = w
      d(i) = d(i) - w * u(i - 1)
    end do
    if (d(ROSSFAST_D3R_N_CELLS) == 0.0_real64 .or. &
        .not. ieee_is_finite(d(ROSSFAST_D3R_N_CELLS))) return

    y = rhs
    do i = 2, ROSSFAST_D3R_N_CELLS
      y(i) = y(i) - multipliers(i - 1) * y(i - 1)
    end do
    x(ROSSFAST_D3R_N_CELLS) = y(ROSSFAST_D3R_N_CELLS) / d(ROSSFAST_D3R_N_CELLS)
    do i = ROSSFAST_D3R_N_CELLS - 1, 1, -1
      if (d(i) == 0.0_real64 .or. .not. ieee_is_finite(d(i))) return
      x(i) = (y(i) - u(i) * x(i + 1)) / d(i)
    end do
    ok = all(ieee_is_finite(x))
  end subroutine factor_and_solve

  logical function valid_state(state)
    type(rossfast_d3r_state_t), intent(in) :: state

    valid_state = .false.
    if (state%active_nodes /= ROSSFAST_D3R_N_CELLS) return
    if (.not. allocated(state%pressure_head_cm) .or. .not. allocated(state%water_content)) return
    if (size(state%pressure_head_cm) /= ROSSFAST_D3R_N_CELLS) return
    if (size(state%water_content) /= ROSSFAST_D3R_N_CELLS) return
    if (.not. all(ieee_is_finite(state%pressure_head_cm))) return
    if (.not. all(ieee_is_finite(state%water_content))) return
    if (any(state%pressure_head_cm <= ROSSFAST_D3R_H_MIN_CM)) return
    if (any(state%pressure_head_cm >= ROSSFAST_D3R_H_MAX_CM)) return
    valid_state = .true.
  end function valid_state

  pure logical function same_material(a, b)
    type(rossfast_d3r_material_t), intent(in) :: a, b

    same_material = trim(a%material_id) == trim(b%material_id) .and. &
         a%theta_r == b%theta_r .and. a%theta_s == b%theta_s .and. &
         a%alpha_per_cm == b%alpha_per_cm .and. a%n == b%n .and. &
         a%ksatfit_cm_per_day == b%ksatfit_cm_per_day .and. &
         a%ksatexm_cm_per_day == b%ksatexm_cm_per_day .and. &
         a%lambda == b%lambda .and. a%h_enpr_cm == b%h_enpr_cm
  end function same_material

end module mod_rossfast_d3r_table_kernel
