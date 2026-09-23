module mod_tabhyd_raw_typed_provider_research
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider, &
       evaluate_b110_default_mvg_conductivity
  use swap_array_dimensions, only: matab
  use TSPACK, only: my_HVAL, my_HPVAL
  implicit none
  private

  integer, parameter, public :: TABHYD_RAW_TABLE_N = 400
  real(real64), parameter :: H_CRIT = -1.0e-2_real64

  type, extends(constitutive_hydraulics_provider_t), public :: tabhyd_raw_provider_t
    private
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
    procedure :: evaluate => tabhyd_raw_evaluate
  end type tabhyd_raw_provider_t

  public :: initialize_tabhyd_raw_provider, initialize_tabhyd_raw_provider_from_mvg
  public :: bind_tabhyd_raw_provider_step_duration

  interface
    subroutine PreProcTabulatedFunction(flag,n,x,y,dydx,sigma)
      import :: real64, matab
      integer, intent(in) :: flag, n
      real(real64), intent(in) :: x(matab), y(matab)
      real(real64), intent(out) :: dydx(matab), sigma(matab)
    end subroutine PreProcTabulatedFunction
  end interface

contains

  subroutine initialize_tabhyd_raw_provider_from_mvg(provider, cofgen, step_duration)
    type(tabhyd_raw_provider_t), intent(out) :: provider
    real(real64), intent(in) :: cofgen(:,:)
    real(real64), intent(in) :: step_duration
    type(b110_default_mvg_parameters_t), target :: analytic_parameters
    type(b110_default_mvg_provider_t) :: analytic
    real(real64), allocatable :: head_table(:,:), theta_table(:,:), conductivity_table(:,:)
    real(real64), allocatable :: lo(:), hi(:), mid(:), target(:), hvec(:), theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64) :: frac, u0
    integer :: i, j, n

    if (size(cofgen,1) < 12) error stop 'TAB-HYD typed research provider: insufficient MvG rows'
    n = size(cofgen,2)
    if (n <= 0) error stop 'TAB-HYD typed research provider: empty MvG parameter set'
    if (any(cofgen(9,1:n) /= 0.0_real64)) &
      error stop 'TAB-HYD typed research provider: generated route currently requires H_ENPR=0'
    if (any(cofgen(10,1:n) > cofgen(3,1:n))) &
      error stop 'TAB-HYD typed research provider: generated route excludes KSATEXM extension'
    if (step_duration <= 0.0_real64) error stop 'TAB-HYD typed research provider: invalid generation step duration'

    call initialize_b110_default_mvg_parameters(analytic_parameters, cofgen)
    call bind_b110_default_mvg_provider(analytic, analytic_parameters, step_duration)

    allocate(head_table(TABHYD_RAW_TABLE_N,n), theta_table(TABHYD_RAW_TABLE_N,n), &
             conductivity_table(TABHYD_RAW_TABLE_N,n))
    allocate(lo(n),hi(n),mid(n),target(n),hvec(n),theta(n),conductivity(n),capacity(n),dkdh(n))

    lo = -1.0e7_real64
    hi = -1.0e-12_real64
    target = cofgen(3,1:n)*(1.0_real64-1.0e-8_real64)
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

    u0 = log10(1.0e7_real64)
    do j = 1, TABHYD_RAW_TABLE_N-1
      frac = real(j-1,real64)/real(TABHYD_RAW_TABLE_N-2,real64)
      do i = 1, n
        if (j == TABHYD_RAW_TABLE_N-1) then
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
    head_table(TABHYD_RAW_TABLE_N,:) = hvec
    theta_table(TABHYD_RAW_TABLE_N,:) = theta
    conductivity_table(TABHYD_RAW_TABLE_N,:) = conductivity

    call initialize_tabhyd_raw_provider(provider,head_table,theta_table,conductivity_table,cofgen,step_duration)
  end subroutine initialize_tabhyd_raw_provider_from_mvg

  subroutine bind_tabhyd_raw_provider_step_duration(provider, step_duration)
    type(tabhyd_raw_provider_t), intent(inout) :: provider
    real(real64), intent(in) :: step_duration
    if (step_duration <= 0.0_real64) error stop 'TAB-HYD typed research provider: invalid bound step duration'
    if (provider%active_nodes <= 0 .or. .not. allocated(provider%head)) &
      error stop 'TAB-HYD typed research provider: bind before initialization'
    provider%step_duration = step_duration
  end subroutine bind_tabhyd_raw_provider_step_duration



  subroutine initialize_tabhyd_raw_provider(provider, head_table, theta_table, conductivity_table, cofgen, step_duration)
    type(tabhyd_raw_provider_t), intent(out) :: provider
    real(real64), intent(in) :: head_table(:,:), theta_table(:,:), conductivity_table(:,:)
    real(real64), intent(in) :: cofgen(:,:)
    real(real64), intent(in) :: step_duration
    real(real64) :: x(matab), y(matab), dydx(matab), sigma(matab)
    real(real64) :: m, help
    integer :: i, j, n

    if (size(head_table,1) /= TABHYD_RAW_TABLE_N .or. &
        size(theta_table,1) /= TABHYD_RAW_TABLE_N .or. &
        size(conductivity_table,1) /= TABHYD_RAW_TABLE_N) &
      error stop 'TAB-HYD typed research provider: table row count mismatch'
    n = size(head_table,2)
    if (n <= 0 .or. size(theta_table,2) /= n .or. size(conductivity_table,2) /= n) &
      error stop 'TAB-HYD typed research provider: node shape mismatch'
    if (size(cofgen,1) < 9 .or. size(cofgen,2) /= n) &
      error stop 'TAB-HYD typed research provider: cofgen shape mismatch'
    if (step_duration <= 0.0_real64) error stop 'TAB-HYD typed research provider: invalid step duration'
    if (.not. all(ieee_is_finite(head_table)) .or. .not. all(ieee_is_finite(theta_table)) .or. &
        .not. all(ieee_is_finite(conductivity_table)) .or. any(conductivity_table <= 0.0_real64)) &
      error stop 'TAB-HYD typed research provider: non-finite/invalid table'

    provider%active_nodes = n
    provider%step_duration = step_duration
    allocate(provider%head(TABHYD_RAW_TABLE_N,n), provider%theta(TABHYD_RAW_TABLE_N,n), &
             provider%logk(TABHYD_RAW_TABLE_N,n), provider%theta_slope(TABHYD_RAW_TABLE_N,n), &
             provider%theta_sigma(TABHYD_RAW_TABLE_N,n), provider%logk_slope(TABHYD_RAW_TABLE_N,n), &
             provider%logk_sigma(TABHYD_RAW_TABLE_N,n))
    allocate(provider%theta_saturated(n), provider%theta_crit(n), provider%wet_capacity(n), &
             provider%ksat(n), provider%kbranch_head(n))

    provider%head = head_table
    provider%theta = theta_table
    provider%logk = log(conductivity_table)

    do j = 1, n
      do i = 2, TABHYD_RAW_TABLE_N
        if (provider%head(i,j) <= provider%head(i-1,j)) &
          error stop 'TAB-HYD typed research provider: non-increasing head'
        if (provider%theta(i,j) <= provider%theta(i-1,j)) &
          error stop 'TAB-HYD typed research provider: non-increasing theta'
        if (provider%logk(i,j) <= provider%logk(i-1,j)) &
          error stop 'TAB-HYD typed research provider: non-increasing K'
      end do

      x = 0.0_real64; y = 0.0_real64; dydx = 0.0_real64; sigma = 0.0_real64
      x(1:TABHYD_RAW_TABLE_N) = provider%head(:,j)
      y(1:TABHYD_RAW_TABLE_N) = provider%theta(:,j)
      call PreProcTabulatedFunction(1,TABHYD_RAW_TABLE_N,x,y,dydx,sigma)
      provider%theta_slope(:,j) = dydx(1:TABHYD_RAW_TABLE_N)
      provider%theta_sigma(:,j) = sigma(1:TABHYD_RAW_TABLE_N)

      x = 0.0_real64; y = 0.0_real64; dydx = 0.0_real64; sigma = 0.0_real64
      x(1:TABHYD_RAW_TABLE_N) = provider%head(:,j)
      y(1:TABHYD_RAW_TABLE_N) = provider%logk(:,j)
      call PreProcTabulatedFunction(2,TABHYD_RAW_TABLE_N-1,x,y,dydx,sigma)
      provider%logk_slope(1:TABHYD_RAW_TABLE_N-1,j) = dydx(1:TABHYD_RAW_TABLE_N-1)
      provider%logk_sigma(1:TABHYD_RAW_TABLE_N-1,j) = sigma(1:TABHYD_RAW_TABLE_N-1)

      provider%theta_saturated(j) = cofgen(2,j)
      m = 1.0_real64 - 1.0_real64/cofgen(6,j)
      help = abs(cofgen(4,j)*H_CRIT)**cofgen(6,j)
      provider%theta_crit(j) = cofgen(1,j) + (cofgen(2,j)-cofgen(1,j)) / (1.0_real64+help)**m
      provider%wet_capacity(j) = (cofgen(2,j)-provider%theta_crit(j))/(-H_CRIT)
      provider%ksat(j) = cofgen(3,j)
      provider%kbranch_head(j) = provider%head(TABHYD_RAW_TABLE_N-1,j)
    end do
  end subroutine initialize_tabhyd_raw_provider

  subroutine tabhyd_raw_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(tabhyd_raw_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    real(real64) :: h, x(2), y(2), yp(2), sig(2), lv
    integer :: i, klo, khi, ierr, n

    n = self%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) &
      error stop 'TAB-HYD typed research provider: evaluate shape mismatch'

    do i = 1, n
      h = pressure_head(i)
      if (.not. ieee_is_finite(h)) error stop 'TAB-HYD typed research provider: non-finite head'

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
        klo = TABHYD_RAW_TABLE_N-2
        khi = TABHYD_RAW_TABLE_N-1
      else
        call locate_continuous_interval(self%head(:,i), h, klo, khi)
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
        if (ierr /= 0) error stop 'TAB-HYD typed research provider: theta HVAL failed'
        capacity(i) = my_HPVAL(h,x,y,yp,sig,ierr)
        if (ierr /= 0) error stop 'TAB-HYD typed research provider: theta HPVAL failed'
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
        if (ierr /= 0) error stop 'TAB-HYD typed research provider: K HVAL failed'
        conductivity(i) = exp(lv)
      end if
    end do
    dconductivity_dhead = 0.0_real64
  end subroutine tabhyd_raw_evaluate

  pure subroutine locate_continuous_interval(head, h, klo, khi)
    real(real64), intent(in) :: head(:), h
    integer, intent(out) :: klo, khi
    integer :: k, hi
    hi = TABHYD_RAW_TABLE_N-1
    klo = 1
    khi = hi
    do while (khi-klo > 1)
      k = (khi+klo)/2
      if (head(k) > h) then
        khi = k
      else
        klo = k
      end if
    end do
  end subroutine locate_continuous_interval

end module mod_tabhyd_raw_typed_provider_research
