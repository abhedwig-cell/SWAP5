module mod_b110_generated_mvg_table_state
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  use mod_b110_generated_mvg_tspack, only: TSPBI, my_HVAL, my_HPVAL
  implicit none
  private

  integer, parameter, public :: B110_GENERATED_MVG_TABLE_N = 32
  logical, parameter, public :: B110_GENERATED_MVG_CURVATURE_GRID = .true.
  real(real64), parameter :: H_CRIT = -1.0e-2_real64
  real(real64), parameter :: GENERATION_H_DRY = -1.0e7_real64
  real(real64), parameter :: GENERATION_H_WET = -1.0e-12_real64
  real(real64), parameter :: K_BRANCH_TARGET_FRACTION = 1.0_real64 - 1.0e-8_real64
  real(real64), parameter :: FSI39_SOURCE_HEAD = -2.0_real64
  real(real64), parameter :: HUPSEL_UPPER(7) = [0.02_real64,0.433878_real64,83.24164_real64, &
       0.021645_real64,7.202077_real64,1.34877_real64,832.4163_real64]
  real(real64), parameter :: HUPSEL_LOWER(7) = [0.02_real64,0.3870640000000001_real64,22.76176_real64, &
       0.016083_real64,2.4396619999999993_real64,1.524418_real64,227.61759999999998_real64]

  integer, parameter, public :: F_TAB02_STATE_OK = 0
  integer, parameter, public :: F_TAB02_STATE_INVALID_PARAMETERS = 1
  integer, parameter, public :: F_TAB02_STATE_UNSUPPORTED_HENPR = 2
  integer, parameter, public :: F_TAB02_STATE_UNSUPPORTED_KSATEXM = 3
  integer, parameter, public :: F_TAB02_STATE_GENERATION_FAILED = 4
  integer, parameter, public :: F_TAB02_STATE_SPLINE_FAILED = 5
  integer, parameter, public :: F_TAB02_STATE_NOT_READY = 6
  integer, parameter, public :: F_TAB02_STATE_SHAPE_MISMATCH = 7
  integer, parameter, public :: F_TAB02_STATE_EVALUATION_FAILED = 8

  type, public :: b110_generated_mvg_table_state_t
    private
    integer :: active_nodes = 0
    logical :: initialized = .false.
    real(real64), allocatable :: head(:,:)
    real(real64), allocatable :: theta(:,:)
    real(real64), allocatable :: logk(:,:)
    real(real64), allocatable :: theta_slope(:,:)
    real(real64), allocatable :: theta_sigma(:,:)
    real(real64), allocatable :: logk_slope(:,:)
    real(real64), allocatable :: logk_sigma(:,:)
    real(real64), allocatable :: theta_saturated(:)
    real(real64), allocatable :: theta_crit(:)
    real(real64), allocatable :: wet_capacity(:)
    real(real64), allocatable :: ksat(:)
    real(real64), allocatable :: kbranch_head(:)
    logical :: ksatexm_extension_enabled = .false.
    real(real64), allocatable :: theta_r(:)
    real(real64), allocatable :: delta_theta(:)
    real(real64), allocatable :: ksatexm(:)
    real(real64), allocatable :: relsat_threshold(:)
    real(real64), allocatable :: k_threshold(:)
    real(real64), allocatable :: first_active_head(:)
    logical :: source_ksatexm_extension_enabled = .false.
    real(real64), allocatable :: source_cofgen(:,:)
  contains
    procedure :: ready => generated_state_ready
    procedure :: matches => generated_state_matches
    procedure :: node_count => generated_state_node_count
    procedure :: estimated_bytes => generated_state_estimated_bytes
  end type b110_generated_mvg_table_state_t

  public :: initialize_b110_generated_mvg_table_state
  public :: evaluate_b110_generated_mvg_table_state
  public :: b110_generated_mvg_ksatexm_profile_supported

contains

  subroutine initialize_b110_generated_mvg_table_state(state, parameters, status)
    type(b110_generated_mvg_table_state_t), intent(out) :: state
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    integer, intent(out) :: status
    type(b110_default_mvg_provider_t) :: analytic
    type(b110_default_mvg_parameters_t), target :: base_parameters
    real(real64), allocatable :: lo(:), hi(:), mid(:), target(:)
    real(real64), allocatable :: hvec(:), theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64), allocatable :: ext_lo(:), ext_hi(:), ext_mid(:), relsat(:)
    real(real64) :: frac, u0
    integer :: i, j, n
    logical :: ok

    state = b110_generated_mvg_table_state_t()
    status = F_TAB02_STATE_INVALID_PARAMETERS

    n = parameters%active_nodes
    if (n <= 0 .or. .not. allocated(parameters%cofgen)) return
    if (size(parameters%cofgen,1) < 42 .or. size(parameters%cofgen,2) /= n) return
    if (.not. all(ieee_is_finite(parameters%cofgen))) return
    if (any(parameters%cofgen(2,1:n) <= parameters%cofgen(1,1:n))) return
    if (any(parameters%cofgen(3,1:n) <= 0.0_real64)) return
    if (any(parameters%cofgen(4,1:n) <= 0.0_real64)) return
    if (any(parameters%cofgen(6,1:n) <= 1.0_real64)) return

    if (parameters%ksatexm_extension_enabled) then
      if (.not. b110_generated_mvg_ksatexm_profile_supported(parameters%cofgen(:,1:n))) then
        status = F_TAB02_STATE_UNSUPPORTED_KSATEXM
        return
      end if
    end if
    if (any(parameters%cofgen(9,1:n) /= 0.0_real64)) then
      status = F_TAB02_STATE_UNSUPPORTED_HENPR
      return
    end if

    allocate(lo(n), hi(n), mid(n), target(n), hvec(n))
    allocate(theta(n), conductivity(n), capacity(n), dkdh(n))

    base_parameters = parameters
    base_parameters%ksatexm_extension_enabled = .false.
    call bind_b110_default_mvg_provider(analytic, base_parameters, 1.0_real64)

    lo = GENERATION_H_DRY
    hi = GENERATION_H_WET
    target = parameters%cofgen(3,1:n) * K_BRANCH_TARGET_FRACTION

    do j = 1, 140
      mid = 0.5_real64 * (lo + hi)
      call analytic%evaluate(mid, theta, conductivity, capacity, dkdh)
      if (.not. all(ieee_is_finite(conductivity))) then
        status = F_TAB02_STATE_GENERATION_FAILED
        return
      end if
      do i = 1, n
        if (conductivity(i) <= target(i)) then
          lo(i) = mid(i)
        else
          hi(i) = mid(i)
        end if
      end do
    end do

    if (.not. all(ieee_is_finite(lo)) .or. any(lo >= 0.0_real64) .or. any(lo <= GENERATION_H_DRY)) then
      status = F_TAB02_STATE_GENERATION_FAILED
      return
    end if
    state%active_nodes = n
    allocate(state%head(B110_GENERATED_MVG_TABLE_N,n), state%theta(B110_GENERATED_MVG_TABLE_N,n), &
             state%logk(B110_GENERATED_MVG_TABLE_N,n), &
             state%theta_slope(B110_GENERATED_MVG_TABLE_N,n), state%theta_sigma(B110_GENERATED_MVG_TABLE_N,n), &
             state%logk_slope(B110_GENERATED_MVG_TABLE_N,n), state%logk_sigma(B110_GENERATED_MVG_TABLE_N,n))
    allocate(state%theta_saturated(n), state%theta_crit(n), state%wet_capacity(n), &
             state%ksat(n), state%kbranch_head(n))
    state%ksatexm_extension_enabled = parameters%ksatexm_extension_enabled
    if (state%ksatexm_extension_enabled) then
      allocate(state%theta_r(n), state%delta_theta(n), state%ksatexm(n), state%relsat_threshold(n), &
               state%k_threshold(n), state%first_active_head(n))
      state%theta_r = parameters%cofgen(1,1:n)
      state%delta_theta = parameters%cofgen(2,1:n) - parameters%cofgen(1,1:n)
      state%ksatexm = parameters%cofgen(10,1:n)
      state%relsat_threshold = parameters%cofgen(11,1:n)
      state%k_threshold = parameters%cofgen(12,1:n)
    end if
    state%source_ksatexm_extension_enabled = parameters%ksatexm_extension_enabled
    allocate(state%source_cofgen(size(parameters%cofgen,1),n))
    state%source_cofgen = parameters%cofgen

    u0 = log10(-GENERATION_H_DRY)
    do j = 1, B110_GENERATED_MVG_TABLE_N - 1
      frac = real(j-1,real64) / real(B110_GENERATED_MVG_TABLE_N-2,real64)
      do i = 1, n
        if (j == B110_GENERATED_MVG_TABLE_N - 1) then
          hvec(i) = lo(i)
        else if (B110_GENERATED_MVG_CURVATURE_GRID) then
          ! Research-only deterministic sparse placement.  The smoothstep
          ! transform concentrates rows toward both dry and wet ends of the
          ! log-head interval, where theta/log(K) curvature and branch
          ! transitions are strongest, without changing interpolation.
          frac = frac*frac*(3.0_real64-2.0_real64*frac)
          hvec(i) = -10.0_real64**(u0 + frac * (log10(-lo(i)) - u0))
        else
          hvec(i) = -10.0_real64**(u0 + frac * (log10(-lo(i)) - u0))
        end if
      end do
      call analytic%evaluate(hvec, theta, conductivity, capacity, dkdh)
      if (.not. all(ieee_is_finite(theta)) .or. .not. all(ieee_is_finite(conductivity)) .or. &
          any(conductivity <= 0.0_real64)) then
        status = F_TAB02_STATE_GENERATION_FAILED
        return
      end if
      state%head(j,:) = hvec
      state%theta(j,:) = theta
      state%logk(j,:) = log(conductivity)
    end do

    hvec = 0.0_real64
    call analytic%evaluate(hvec, theta, conductivity, capacity, dkdh)
    if (.not. all(ieee_is_finite(theta)) .or. .not. all(ieee_is_finite(conductivity)) .or. &
        any(conductivity <= 0.0_real64)) then
      status = F_TAB02_STATE_GENERATION_FAILED
      return
    end if
    state%head(B110_GENERATED_MVG_TABLE_N,:) = hvec
    state%theta(B110_GENERATED_MVG_TABLE_N,:) = theta
    state%logk(B110_GENERATED_MVG_TABLE_N,:) = log(conductivity)

    state%theta_saturated = parameters%cofgen(2,1:n)
    state%ksat = parameters%cofgen(3,1:n)
    state%kbranch_head = state%head(B110_GENERATED_MVG_TABLE_N-1,:)

    hvec = H_CRIT
    call analytic%evaluate(hvec, theta, conductivity, capacity, dkdh)
    state%theta_crit = theta
    state%wet_capacity = (state%theta_saturated - state%theta_crit) / (-H_CRIT)
    if (.not. all(ieee_is_finite(state%theta_crit)) .or. .not. all(ieee_is_finite(state%wet_capacity)) .or. &
        any(state%wet_capacity < 0.0_real64)) then
      status = F_TAB02_STATE_GENERATION_FAILED
      return
    end if

    if (state%ksatexm_extension_enabled) then
      allocate(ext_lo(n), ext_hi(n), ext_mid(n), relsat(n))
      ! Reproduce the controlling TAB-HYD-KX05 floating-boundary authority.
      ! Branch ownership is located with the same explicit theta relation used
      ! by KX05, not with the generated table and not with a tolerance.
      ext_lo = FSI39_SOURCE_HEAD
      ext_hi = 0.0_real64

      do i = 1, n
        theta(i) = authority_theta(parameters%cofgen(:,i),ext_lo(i))
      end do
      relsat = (theta-state%theta_r)/state%delta_theta
      if (any(relsat > state%relsat_threshold)) then
        status = F_TAB02_STATE_GENERATION_FAILED
        return
      end if

      do i = 1, n
        theta(i) = authority_theta(parameters%cofgen(:,i),ext_hi(i))
      end do
      relsat = (theta-state%theta_r)/state%delta_theta
      if (any(relsat <= state%relsat_threshold)) then
        status = F_TAB02_STATE_GENERATION_FAILED
        return
      end if

      do j = 1, 128
        do i = 1, n
          if (nearest(ext_lo(i),1.0_real64) >= ext_hi(i)) then
            ext_mid(i) = ext_hi(i)
          else
            ext_mid(i) = ext_lo(i) + 0.5_real64*(ext_hi(i)-ext_lo(i))
          end if
        end do
        do i = 1, n
          theta(i) = authority_theta(parameters%cofgen(:,i),ext_mid(i))
        end do
        relsat = (theta-state%theta_r)/state%delta_theta
        do i = 1, n
          if (nearest(ext_lo(i),1.0_real64) >= ext_hi(i)) cycle
          if (relsat(i) > state%relsat_threshold(i)) then
            ext_hi(i) = ext_mid(i)
          else
            ext_lo(i) = ext_mid(i)
          end if
        end do
        if (all(nearest(ext_lo,1.0_real64) >= ext_hi)) exit
      end do
      if (.not. all(nearest(ext_lo,1.0_real64) >= ext_hi)) then
        status = F_TAB02_STATE_GENERATION_FAILED
        return
      end if
      state%first_active_head = ext_hi
    end if

    do i = 1, n
      do j = 2, B110_GENERATED_MVG_TABLE_N
        if (state%head(j,i) <= state%head(j-1,i)) then
          status = F_TAB02_STATE_GENERATION_FAILED
          return
        end if
        if (state%theta(j,i) <= state%theta(j-1,i)) then
          status = F_TAB02_STATE_GENERATION_FAILED
          return
        end if
        if (state%logk(j,i) <= state%logk(j-1,i)) then
          status = F_TAB02_STATE_GENERATION_FAILED
          return
        end if
      end do

      call preprocess_curve(state%head(:,i), state%theta(:,i), 1, state%theta_slope(:,i), &
           state%theta_sigma(:,i), ok)
      if (.not. ok) then
        status = F_TAB02_STATE_SPLINE_FAILED
        return
      end if

      state%logk_slope(:,i) = 0.0_real64
      state%logk_sigma(:,i) = 0.0_real64
      call preprocess_curve(state%head(1:B110_GENERATED_MVG_TABLE_N-1,i), &
           state%logk(1:B110_GENERATED_MVG_TABLE_N-1,i), 2, &
           state%logk_slope(1:B110_GENERATED_MVG_TABLE_N-1,i), &
           state%logk_sigma(1:B110_GENERATED_MVG_TABLE_N-1,i), ok)
      if (.not. ok) then
        status = F_TAB02_STATE_SPLINE_FAILED
        return
      end if
    end do

    state%initialized = .true.
    status = F_TAB02_STATE_OK
  end subroutine initialize_b110_generated_mvg_table_state

  subroutine preprocess_curve(x, y, flag, dydx, sigma, ok)
    real(real64), intent(in) :: x(:), y(:)
    integer, intent(in) :: flag
    real(real64), intent(out) :: dydx(:), sigma(:)
    logical, intent(out) :: ok
    real(real64), allocatable :: bounds(:,:), work(:)
    integer, allocatable :: constraint_flags(:)
    real(real64), parameter :: BMAX = 1.0e30_real64
    integer :: n, ncd, iendc, lwk, ier

    ok = .false.
    n = size(x)
    if (n < 3 .or. size(y) /= n .or. size(dydx) /= n .or. size(sigma) /= n) return
    if (.not. all(ieee_is_finite(x)) .or. .not. all(ieee_is_finite(y))) return

    allocate(bounds(5,n), constraint_flags(n))
    lwk = 2*(n-1)
    allocate(work(lwk))
    bounds(1,:) = 1.1_real64 * BMAX
    bounds(2,:) = -1.1_real64 * BMAX
    bounds(3,:) = 1.1_real64 * BMAX
    bounds(4,:) = -1.1_real64 * BMAX
    bounds(5,:) = 1.0_real64
    work = 0.0_real64
    sigma = 0.0_real64
    constraint_flags = 0
    dydx = 0.0_real64
    ncd = 2

    select case(flag)
    case(1)
      iendc = 1
      dydx(1) = 0.0_real64
      dydx(n) = 1.0e-7_real64
    case(2)
      iendc = 2
      dydx(1) = 0.0_real64
      dydx(n) = 0.0_real64
    case default
      return
    end select

    call TSPBI(n, x, y, ncd, iendc, .false., bounds, BMAX, lwk, work, dydx, sigma, constraint_flags, ier)
    if (ier < 0) return
    ! TSPBI constraint flags are diagnostic: the qualified historical
    ! preprocessing also accepts intervals where a requested convexity sign
    ! cannot be enforced.  The resulting finite spline parameters remain the
    ! numerical authority; do not widen the production rejection contract here.
    if (.not. all(ieee_is_finite(dydx)) .or. .not. all(ieee_is_finite(sigma))) return
    ok = .true.
  end subroutine preprocess_curve

  subroutine evaluate_b110_generated_mvg_table_state(state, pressure_head, water_content, conductivity, capacity, status)
    type(b110_generated_mvg_table_state_t), intent(in) :: state
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:)
    integer, intent(out) :: status
    real(real64) :: h, x(2), y(2), yp(2), sig(2), logk_value, frac
    integer :: i, klo, khi, ier, n

    status = F_TAB02_STATE_NOT_READY
    if (.not. state%ready()) return
    n = state%active_nodes
    status = F_TAB02_STATE_SHAPE_MISMATCH
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. &
        size(conductivity) /= n .or. size(capacity) /= n) return
    if (.not. all(ieee_is_finite(pressure_head))) then
      status = F_TAB02_STATE_EVALUATION_FAILED
      return
    end if

    do i = 1, n
      h = pressure_head(i)
      if (h >= 0.0_real64) then
        water_content(i) = state%theta_saturated(i)
        if (state%ksatexm_extension_enabled) then
          conductivity(i) = state%ksatexm(i)
        else
          conductivity(i) = state%ksat(i)
        end if
        capacity(i) = 0.0_real64
        cycle
      end if

      if (h <= state%head(1,i)) then
        water_content(i) = state%theta(1,i)
        conductivity(i) = exp(state%logk(1,i))
        capacity(i) = 0.0_real64
        cycle
      end if

      if (h > H_CRIT) then
        water_content(i) = state%theta_crit(i) + state%wet_capacity(i) * (h-H_CRIT)
        water_content(i) = min(water_content(i), state%theta_saturated(i))
        capacity(i) = state%wet_capacity(i)
      else
        call locate_interval(state%head(1:B110_GENERATED_MVG_TABLE_N-1,i), h, klo, khi)
        x = state%head(klo:khi,i)
        y = state%theta(klo:khi,i)
        yp = state%theta_slope(klo:khi,i)
        sig = state%theta_sigma(klo:khi,i)
        water_content(i) = my_HVAL(h, x, y, yp, sig, ier)
        if (ier /= 0) then
          status = F_TAB02_STATE_EVALUATION_FAILED
          return
        end if
        capacity(i) = my_HPVAL(h, x, y, yp, sig, ier)
        if (ier /= 0) then
          status = F_TAB02_STATE_EVALUATION_FAILED
          return
        end if
      end if

      if (h > state%kbranch_head(i)) then
        conductivity(i) = state%ksat(i)
      else
        call locate_interval(state%head(1:B110_GENERATED_MVG_TABLE_N-1,i), h, klo, khi)
        x = state%head(klo:khi,i)
        y = state%logk(klo:khi,i)
        yp = state%logk_slope(klo:khi,i)
        sig = state%logk_sigma(klo:khi,i)
        logk_value = my_HVAL(h, x, y, yp, sig, ier)
        if (ier /= 0) then
          status = F_TAB02_STATE_EVALUATION_FAILED
          return
        end if
        conductivity(i) = exp(logk_value)
      end if

      if (state%ksatexm_extension_enabled) then
        if (h >= state%first_active_head(i)) then
          frac = ((water_content(i)-state%theta_r(i))/state%delta_theta(i)-state%relsat_threshold(i)) / &
               (1.0_real64-state%relsat_threshold(i))
          if (.not. ieee_is_finite(frac) .or. frac < 0.0_real64 .or. frac > 1.0_real64) then
            status = F_TAB02_STATE_EVALUATION_FAILED
            return
          end if
          conductivity(i) = frac*state%ksatexm(i) + (1.0_real64-frac)*state%k_threshold(i)
        end if
      end if

      if (.not. ieee_is_finite(water_content(i)) .or. .not. ieee_is_finite(conductivity(i)) .or. &
          .not. ieee_is_finite(capacity(i)) .or. conductivity(i) <= 0.0_real64) then
        status = F_TAB02_STATE_EVALUATION_FAILED
        return
      end if
    end do

    status = F_TAB02_STATE_OK
  end subroutine evaluate_b110_generated_mvg_table_state

  pure subroutine locate_interval(head, h, klo, khi)
    real(real64), intent(in) :: head(:), h
    integer, intent(out) :: klo, khi
    integer :: k

    klo = 1
    khi = size(head)
    do while (khi-klo > 1)
      k = (khi+klo)/2
      if (head(k) > h) then
        khi = k
      else
        klo = k
      end if
    end do
  end subroutine locate_interval

  logical function generated_state_ready(self) result(ready)
    class(b110_generated_mvg_table_state_t), intent(in) :: self
    ready = self%initialized .and. self%active_nodes > 0
    if (.not. ready) return
    ready = allocated(self%head) .and. allocated(self%theta) .and. allocated(self%logk) .and. &
         allocated(self%theta_slope) .and. allocated(self%theta_sigma) .and. &
         allocated(self%logk_slope) .and. allocated(self%logk_sigma) .and. &
         allocated(self%theta_saturated) .and. allocated(self%theta_crit) .and. &
         allocated(self%wet_capacity) .and. allocated(self%ksat) .and. allocated(self%kbranch_head) .and. &
         allocated(self%source_cofgen)
    if (ready .and. self%ksatexm_extension_enabled) then
      ready = allocated(self%theta_r) .and. allocated(self%delta_theta) .and. allocated(self%ksatexm) .and. &
           allocated(self%relsat_threshold) .and. allocated(self%k_threshold) .and. allocated(self%first_active_head)
    end if
  end function generated_state_ready

  logical function generated_state_matches(self, parameters) result(matches)
    class(b110_generated_mvg_table_state_t), intent(in) :: self
    type(b110_default_mvg_parameters_t), intent(in) :: parameters

    matches = .false.
    if (.not. self%ready()) return
    if (parameters%ksatexm_extension_enabled .neqv. self%source_ksatexm_extension_enabled) return
    if (parameters%active_nodes /= self%active_nodes .or. .not. allocated(parameters%cofgen)) return
    if (size(parameters%cofgen,1) /= size(self%source_cofgen,1) .or. &
        size(parameters%cofgen,2) /= size(self%source_cofgen,2)) return
    matches = all(parameters%cofgen == self%source_cofgen)
  end function generated_state_matches

  integer function generated_state_node_count(self) result(n)
    class(b110_generated_mvg_table_state_t), intent(in) :: self
    n = 0
    if (self%ready()) n = self%active_nodes
  end function generated_state_node_count

  integer(int64) function generated_state_estimated_bytes(self) result(bytes)
    class(b110_generated_mvg_table_state_t), intent(in) :: self
    bytes = 0_int64
    if (.not. self%ready()) return
    bytes = int(7 * B110_GENERATED_MVG_TABLE_N * self%active_nodes, int64) * 8_int64 + &
         int((5 + size(self%source_cofgen,1)) * self%active_nodes, int64) * 8_int64
    if (self%ksatexm_extension_enabled) bytes = bytes + int(6*self%active_nodes,int64)*8_int64
  end function generated_state_estimated_bytes


  pure real(real64) function authority_theta(c,hv) result(theta)
    real(real64), intent(in) :: c(:),hv
    real(real64) :: m,delta,theta_crit,wet_capacity,help

    m = 1.0_real64 - 1.0_real64/c(6)
    delta = c(2)-c(1)
    if (hv >= 0.0_real64) then
      theta = c(2)
    else if (hv > H_CRIT) then
      help = abs(c(4)*H_CRIT)**c(6)
      theta_crit = c(1) + delta/((1.0_real64+help)**m)
      wet_capacity = (c(2)-theta_crit)/(-H_CRIT)
      theta = theta_crit + wet_capacity*(hv-H_CRIT)
      theta = min(theta,c(2))
    else
      help = abs(c(4)*hv)**c(6)
      help = (1.0_real64+help)**m
      theta = c(1) + delta/help
    end if
  end function authority_theta

  pure logical function b110_generated_mvg_ksatexm_profile_supported(cofgen) result(supported)
    real(real64), intent(in) :: cofgen(:,:)
    real(real64) :: se_threshold, k_threshold, m, term1
    integer :: i

    supported = .false.
    if (size(cofgen,1) < 12 .or. size(cofgen,2) <= 0) return
    if (.not. all(ieee_is_finite(cofgen(1:12,:)))) return

    do i = 1, size(cofgen,2)
      if (.not. (matches_hupsel_material(cofgen(:,i),HUPSEL_UPPER) .or. &
                 matches_hupsel_material(cofgen(:,i),HUPSEL_LOWER))) return
      if (cofgen(9,i) /= 0.0_real64 .or. cofgen(10,i) <= cofgen(3,i)) return

      m = 1.0_real64 - 1.0_real64/cofgen(6,i)
      se_threshold = (1.0_real64 + abs(cofgen(4,i)*FSI39_SOURCE_HEAD)**cofgen(6,i))**(-m)
      term1 = (1.0_real64-se_threshold**(1.0_real64/m))**m
      k_threshold = cofgen(3,i)*se_threshold**cofgen(5,i)*(1.0_real64-term1)*(1.0_real64-term1)

      if (.not. nearly_equal(cofgen(11,i),se_threshold)) return
      if (.not. nearly_equal(cofgen(12,i),k_threshold)) return
    end do
    supported = .true.
  end function b110_generated_mvg_ksatexm_profile_supported

  pure logical function matches_hupsel_material(c, expected) result(matches)
    real(real64), intent(in) :: c(:), expected(7)
    real(real64) :: actual(7)
    integer :: j

    actual = [c(1),c(2),c(3),c(4),c(5),c(6),c(10)]
    matches = .true.
    do j = 1, size(actual)
      if (.not. nearly_equal(actual(j),expected(j))) then
        matches = .false.
        return
      end if
    end do
  end function matches_hupsel_material

  pure logical function nearly_equal(a,b) result(equal)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale = max(1.0_real64,abs(a),abs(b))
    equal = abs(a-b) <= 128.0_real64*epsilon(1.0_real64)*scale
  end function nearly_equal

end module mod_b110_generated_mvg_table_state
