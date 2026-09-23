module mod_b110_generated_mvg_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_tabulated_hydraulics_tspack, only: TSPBI, my_HVAL, my_HPVAL
  implicit none
  private

  integer, parameter, public :: B110_GENERATED_MVG_OK = 0
  integer, parameter, public :: B110_GENERATED_MVG_INVALID_INPUT = 1
  integer, parameter, public :: B110_GENERATED_MVG_UNSUPPORTED_PROFILE = 2
  integer, parameter, public :: B110_GENERATED_MVG_GENERATION_FAILED = 3
  integer, parameter, public :: B110_GENERATED_MVG_TABLE_N = 400
  real(real64), parameter :: H_CRIT = -1.0e-2_real64
  real(real64), parameter :: H_DRY = -1.0e7_real64
  real(real64), parameter :: H_WET_SEARCH = -1.0e-12_real64
  real(real64), parameter :: K_BRANCH_FRACTION = 1.0_real64 - 1.0e-8_real64

  type, extends(constitutive_hydraulics_provider_t), public :: b110_generated_mvg_provider_t
    private
    logical :: initialized = .false.
    integer :: active_nodes = 0
    real(real64) :: step_duration = 0.0_real64
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
  contains
    procedure :: evaluate => b110_generated_mvg_evaluate
    procedure :: context_compatible => b110_generated_mvg_context_compatible
    procedure :: ready => b110_generated_mvg_ready
  end type b110_generated_mvg_provider_t

  public :: initialize_b110_generated_mvg_provider, bind_b110_generated_mvg_step_duration

contains

  subroutine initialize_b110_generated_mvg_provider(provider, cofgen, status)
    type(b110_generated_mvg_provider_t), intent(out) :: provider
    real(real64), intent(in) :: cofgen(:,:)
    integer, intent(out) :: status

    type(b110_default_mvg_parameters_t), target :: analytic_parameters
    type(b110_default_mvg_provider_t) :: analytic
    real(real64), allocatable :: head_table(:,:), theta_table(:,:), conductivity_table(:,:)
    real(real64), allocatable :: lo(:), hi(:), mid(:), target(:), hvec(:)
    real(real64), allocatable :: theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64) :: frac, u0, m, help
    integer :: i, j, n, prep_status

    provider = b110_generated_mvg_provider_t()
    status = B110_GENERATED_MVG_INVALID_INPUT

    if (size(cofgen,1) < 24) return
    n = size(cofgen,2)
    if (n <= 0) return
    if (any(.not. ieee_is_finite(cofgen(1:12,1:n)))) return
    if (any(cofgen(2,1:n) <= cofgen(1,1:n))) return
    if (any(cofgen(3,1:n) <= 0.0_real64)) return
    if (any(cofgen(4,1:n) <= 0.0_real64)) return
    if (any(cofgen(6,1:n) <= 1.0_real64)) return

    status = B110_GENERATED_MVG_UNSUPPORTED_PROFILE
    if (any(cofgen(9,1:n) /= 0.0_real64)) return
    if (any(cofgen(10,1:n) > cofgen(3,1:n))) return

    call initialize_b110_default_mvg_parameters(analytic_parameters, cofgen)
    call bind_b110_default_mvg_provider(analytic, analytic_parameters, 1.0_real64)

    allocate(head_table(B110_GENERATED_MVG_TABLE_N,n), theta_table(B110_GENERATED_MVG_TABLE_N,n), &
             conductivity_table(B110_GENERATED_MVG_TABLE_N,n))
    allocate(lo(n), hi(n), mid(n), target(n), hvec(n), theta(n), conductivity(n), capacity(n), dkdh(n))

    lo = H_DRY
    hi = H_WET_SEARCH
    target = cofgen(3,1:n)*K_BRANCH_FRACTION

    call analytic%evaluate(lo,theta,conductivity,capacity,dkdh)
    if (any(conductivity > target)) then
      status = B110_GENERATED_MVG_GENERATION_FAILED
      return
    end if
    call analytic%evaluate(hi,theta,conductivity,capacity,dkdh)
    if (any(conductivity <= target)) then
      status = B110_GENERATED_MVG_GENERATION_FAILED
      return
    end if

    do j = 1, 140
      mid = 0.5_real64*(lo+hi)
      call analytic%evaluate(mid,theta,conductivity,capacity,dkdh)
      do i = 1, n
        if (conductivity(i) <= target(i)) then
          lo(i) = mid(i)
        else
          hi(i) = mid(i)
        end if
      end do
    end do

    u0 = log10(-H_DRY)
    do j = 1, B110_GENERATED_MVG_TABLE_N-1
      frac = real(j-1,real64)/real(B110_GENERATED_MVG_TABLE_N-2,real64)
      do i = 1, n
        if (j == B110_GENERATED_MVG_TABLE_N-1) then
          hvec(i) = lo(i)
        else
          hvec(i) = -10.0_real64**(u0 + frac*(log10(-lo(i))-u0))
        end if
      end do
      call analytic%evaluate(hvec,theta,conductivity,capacity,dkdh)
      head_table(j,:) = hvec
      theta_table(j,:) = theta
      conductivity_table(j,:) = conductivity
    end do

    hvec = 0.0_real64
    call analytic%evaluate(hvec,theta,conductivity,capacity,dkdh)
    head_table(B110_GENERATED_MVG_TABLE_N,:) = hvec
    theta_table(B110_GENERATED_MVG_TABLE_N,:) = theta
    conductivity_table(B110_GENERATED_MVG_TABLE_N,:) = conductivity

    if (.not. all(ieee_is_finite(head_table)) .or. .not. all(ieee_is_finite(theta_table)) .or. &
        .not. all(ieee_is_finite(conductivity_table)) .or. any(conductivity_table <= 0.0_real64)) then
      status = B110_GENERATED_MVG_GENERATION_FAILED
      return
    end if

    provider%active_nodes = n
    provider%step_duration = 0.0_real64
    allocate(provider%head(B110_GENERATED_MVG_TABLE_N,n), provider%theta(B110_GENERATED_MVG_TABLE_N,n), &
             provider%logk(B110_GENERATED_MVG_TABLE_N,n), provider%theta_slope(B110_GENERATED_MVG_TABLE_N,n), &
             provider%theta_sigma(B110_GENERATED_MVG_TABLE_N,n), provider%logk_slope(B110_GENERATED_MVG_TABLE_N,n), &
             provider%logk_sigma(B110_GENERATED_MVG_TABLE_N,n))
    allocate(provider%theta_saturated(n), provider%theta_crit(n), provider%wet_capacity(n), &
             provider%ksat(n), provider%kbranch_head(n))

    provider%head = head_table
    provider%theta = theta_table
    provider%logk = log(conductivity_table)

    do i = 1, n
      if (any(provider%head(2:,i) <= provider%head(:B110_GENERATED_MVG_TABLE_N-1,i)) .or. &
          any(provider%theta(2:,i) <= provider%theta(:B110_GENERATED_MVG_TABLE_N-1,i)) .or. &
          any(provider%logk(2:,i) <= provider%logk(:B110_GENERATED_MVG_TABLE_N-1,i))) then
        call reset_provider(provider)
        status = B110_GENERATED_MVG_GENERATION_FAILED
        return
      end if

      call preprocess_tspack(1, provider%head(:,i), provider%theta(:,i), &
           provider%theta_slope(:,i), provider%theta_sigma(:,i), prep_status)
      if (prep_status /= B110_GENERATED_MVG_OK) then
        call reset_provider(provider)
        status = prep_status
        return
      end if

      provider%logk_slope(:,i) = 0.0_real64
      provider%logk_sigma(:,i) = 0.0_real64
      call preprocess_tspack(2, provider%head(:B110_GENERATED_MVG_TABLE_N-1,i), &
           provider%logk(:B110_GENERATED_MVG_TABLE_N-1,i), &
           provider%logk_slope(:B110_GENERATED_MVG_TABLE_N-1,i), &
           provider%logk_sigma(:B110_GENERATED_MVG_TABLE_N-1,i), prep_status)
      if (prep_status /= B110_GENERATED_MVG_OK) then
        call reset_provider(provider)
        status = prep_status
        return
      end if

      provider%theta_saturated(i) = cofgen(2,i)
      m = 1.0_real64 - 1.0_real64/cofgen(6,i)
      help = abs(cofgen(4,i)*H_CRIT)**cofgen(6,i)
      provider%theta_crit(i) = cofgen(1,i) + (cofgen(2,i)-cofgen(1,i))/(1.0_real64+help)**m
      provider%wet_capacity(i) = (cofgen(2,i)-provider%theta_crit(i))/(-H_CRIT)
      provider%ksat(i) = cofgen(3,i)
      provider%kbranch_head(i) = provider%head(B110_GENERATED_MVG_TABLE_N-1,i)
    end do

    provider%initialized = .true.
    status = B110_GENERATED_MVG_OK
  end subroutine initialize_b110_generated_mvg_provider

  subroutine bind_b110_generated_mvg_step_duration(provider, step_duration, status)
    type(b110_generated_mvg_provider_t), intent(inout) :: provider
    real(real64), intent(in) :: step_duration
    integer, intent(out) :: status

    status = B110_GENERATED_MVG_INVALID_INPUT
    if (.not. provider%initialized) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    provider%step_duration = step_duration
    status = B110_GENERATED_MVG_OK
  end subroutine bind_b110_generated_mvg_step_duration

  subroutine preprocess_tspack(flag, x, y, dydx, sigma, status)
    integer, intent(in) :: flag
    real(real64), intent(in) :: x(:), y(:)
    real(real64), intent(out) :: dydx(:), sigma(:)
    integer, intent(out) :: status

    integer :: n, iendc, ier, lwk
    integer, allocatable :: icflg(:)
    real(real64), allocatable :: b(:,:), wk(:)
    real(real64), parameter :: bmax = 1.0e30_real64

    status = B110_GENERATED_MVG_GENERATION_FAILED
    n = size(x)
    if (n < 2 .or. size(y) /= n .or. size(dydx) /= n .or. size(sigma) /= n) return
    if (flag /= 1 .and. flag /= 2) return
    if (any(.not. ieee_is_finite(x)) .or. any(.not. ieee_is_finite(y))) return
    if (any(x(2:) <= x(:n-1))) return

    lwk = 7*n
    allocate(icflg(n), b(5,n), wk(lwk))
    icflg = 0
    b(1,:) = 1.1_real64*bmax
    b(2,:) = -1.1_real64*bmax
    b(3,:) = 1.1_real64*bmax
    b(4,:) = -1.1_real64*bmax
    b(5,:) = 1.0_real64
    wk = 0.0_real64
    dydx = 0.0_real64
    sigma = 0.0_real64

    if (flag == 1) then
      iendc = 1
      dydx(1) = 0.0_real64
      dydx(n) = 1.0e-7_real64
    else
      iendc = 2
      dydx(1) = 0.0_real64
      dydx(n) = 0.0_real64
    end if

    call TSPBI(n,x,y,2,iendc,.false.,b,bmax,lwk,wk,dydx,sigma,icflg,ier)
    ! Preserve qualified TSPACK semantics: ICFLG marks local constraints that
    ! TSPACK treats as null constraints.  Only an actual preprocessing error
    ! (negative IER) or non-finite output invalidates the generated provider.
    if (ier < 0) return
    if (any(.not. ieee_is_finite(dydx)) .or. any(.not. ieee_is_finite(sigma))) return
    status = B110_GENERATED_MVG_OK
  end subroutine preprocess_tspack

  logical function b110_generated_mvg_context_compatible(self, step_duration) result(compatible)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: step_duration
    real(real64) :: scale

    compatible = .false.
    if (.not. self%initialized) return
    if (.not. ieee_is_finite(step_duration) .or. step_duration <= 0.0_real64) return
    if (.not. ieee_is_finite(self%step_duration) .or. self%step_duration <= 0.0_real64) return
    scale = max(1.0_real64,abs(step_duration),abs(self%step_duration))
    compatible = abs(step_duration-self%step_duration) <= 16.0_real64*epsilon(1.0_real64)*scale
  end function b110_generated_mvg_context_compatible

  logical function b110_generated_mvg_ready(self) result(ready)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    ready = self%initialized .and. self%active_nodes > 0 .and. allocated(self%head) .and. &
         allocated(self%theta) .and. allocated(self%logk)
  end function b110_generated_mvg_ready

  subroutine b110_generated_mvg_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b110_generated_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    real(real64) :: h, x(2), y(2), yp(2), sig(2), lv
    integer :: i, klo, khi, ierr, n

    if (.not. self%initialized) error stop 'F-TAB02 generated MvG provider: not initialized'
    n = self%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) &
      error stop 'F-TAB02 generated MvG provider: shape mismatch'

    do i = 1, n
      h = pressure_head(i)
      if (.not. ieee_is_finite(h)) error stop 'F-TAB02 generated MvG provider: non-finite head'

      if (h >= 0.0_real64) then
        water_content(i) = self%theta_saturated(i)
        capacity(i) = self%step_duration*1.0e-7_real64
        conductivity(i) = self%ksat(i)
        cycle
      end if

      if (h < self%head(1,i)) then
        water_content(i) = self%theta(1,i)
        capacity(i) = 0.0_real64
        conductivity(i) = exp(self%logk(1,i))
        cycle
      end if

      if (h > self%kbranch_head(i)) then
        klo = B110_GENERATED_MVG_TABLE_N-2
        khi = B110_GENERATED_MVG_TABLE_N-1
      else
        call locate_interval(self%head(:,i),h,klo,khi)
      end if

      if (h > H_CRIT) then
        water_content(i) = self%theta_crit(i) + self%wet_capacity(i)*(h-H_CRIT)
        water_content(i) = min(water_content(i),self%theta_saturated(i))
        capacity(i) = self%wet_capacity(i)
      else
        x = self%head(klo:khi,i)
        y = self%theta(klo:khi,i)
        yp = self%theta_slope(klo:khi,i)
        sig = self%theta_sigma(klo:khi,i)
        water_content(i) = my_HVAL(h,x,y,yp,sig,ierr)
        if (ierr /= 0) error stop 'F-TAB02 generated MvG provider: theta interpolation failed'
        capacity(i) = my_HPVAL(h,x,y,yp,sig,ierr)
        if (ierr /= 0) error stop 'F-TAB02 generated MvG provider: capacity interpolation failed'
      end if
      if (h > -1.0_real64 .and. capacity(i) < self%step_duration*1.0e-7_real64) &
        capacity(i) = self%step_duration*1.0e-7_real64

      if (h > self%kbranch_head(i)) then
        conductivity(i) = self%ksat(i)
      else
        x = self%head(klo:khi,i)
        y = self%logk(klo:khi,i)
        yp = self%logk_slope(klo:khi,i)
        sig = self%logk_sigma(klo:khi,i)
        lv = my_HVAL(h,x,y,yp,sig,ierr)
        if (ierr /= 0) error stop 'F-TAB02 generated MvG provider: conductivity interpolation failed'
        conductivity(i) = exp(lv)
      end if
    end do

    dconductivity_dhead = 0.0_real64
  end subroutine b110_generated_mvg_evaluate

  pure subroutine locate_interval(head, h, klo, khi)
    real(real64), intent(in) :: head(:), h
    integer, intent(out) :: klo, khi
    integer :: k

    klo = 1
    khi = B110_GENERATED_MVG_TABLE_N-1
    do while (khi-klo > 1)
      k = (khi+klo)/2
      if (head(k) > h) then
        khi = k
      else
        klo = k
      end if
    end do
  end subroutine locate_interval

  subroutine reset_provider(provider)
    type(b110_generated_mvg_provider_t), intent(inout) :: provider
    provider = b110_generated_mvg_provider_t()
  end subroutine reset_provider

end module mod_b110_generated_mvg_provider
