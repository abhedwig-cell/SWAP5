module mod_ahl04_hybrid_lookup_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       bind_b110_default_mvg_provider
  implicit none
  private

  real(real64), parameter :: LOOKUP_H_MAX = -1.0_real64

  type, extends(constitutive_hydraulics_provider_t), public :: ahl04_hybrid_lookup_provider_t
    private
    type(b110_default_mvg_provider_t) :: analytical
    real(real64), pointer :: cofgen(:,:) => null()
    real(real64), allocatable :: x(:), zse(:), logc(:), logk(:)
    logical :: ready = .false.
    logical :: lookup_theta = .true.
    logical :: lookup_capacity = .true.
    logical :: lookup_conductivity = .true.
  contains
    procedure :: evaluate => ahl04_evaluate
  end type ahl04_hybrid_lookup_provider_t

  public :: bind_ahl04_hybrid_lookup_provider

contains

  subroutine bind_ahl04_hybrid_lookup_provider(provider, parameters, step_duration, table_path, valid, &
       lookup_theta, lookup_capacity, lookup_conductivity)
    type(ahl04_hybrid_lookup_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    character(len=*), intent(in) :: table_path
    logical, intent(out) :: valid
    logical, intent(in), optional :: lookup_theta, lookup_capacity, lookup_conductivity
    integer :: u, ios, n, i

    valid = .false.
    provider%ready = .false.
    provider%lookup_theta = .true.
    provider%lookup_capacity = .true.
    provider%lookup_conductivity = .true.
    if (present(lookup_theta)) provider%lookup_theta = lookup_theta
    if (present(lookup_capacity)) provider%lookup_capacity = lookup_capacity
    if (present(lookup_conductivity)) provider%lookup_conductivity = lookup_conductivity
    call bind_b110_default_mvg_provider(provider%analytical, parameters, step_duration)
    if (.not. allocated(parameters%cofgen)) return
    provider%cofgen => parameters%cofgen

    open(newunit=u, file=trim(table_path), status='old', action='read', iostat=ios)
    if (ios /= 0) return
    read(u,*,iostat=ios) n
    if (ios /= 0 .or. n < 2) then
      close(u); return
    end if
    allocate(provider%x(n), provider%zse(n), provider%logc(n), provider%logk(n))
    do i=1,n
      read(u,*,iostat=ios) provider%x(i), provider%zse(i), provider%logc(i), provider%logk(i)
      if (ios /= 0) then
        close(u); return
      end if
    end do
    close(u)
    if (any(provider%x(2:) <= provider%x(:n-1))) return
    provider%ready = .true.
    valid = .true.
  end subroutine bind_ahl04_hybrid_lookup_provider

  subroutine ahl04_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(ahl04_hybrid_lookup_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, idx
    real(real64) :: xv, f, z, se, span, tr

    if (.not. self%ready .or. .not. associated(self%cofgen)) error stop 'AHL04 provider not ready'
    ! Stage A deliberately starts from the exact provider and overwrites only
    ! lookup-domain nodes. This isolates solver-response fidelity. Runtime
    ! qualification requires a later provider that avoids analytical work for
    ! lookup-domain nodes.
    call self%analytical%evaluate(pressure_head, water_content, conductivity, capacity, dconductivity_dhead)

    do i=1,size(pressure_head)
      if (pressure_head(i) <= LOOKUP_H_MAX .and. pressure_head(i) >= -1.0e6_real64) then
        xv = log10(-pressure_head(i))
        call locate(self%x, xv, idx, f)
        z = self%zse(idx) + f*(self%zse(idx+1)-self%zse(idx))
        if (z >= 0.0_real64) then
          se = 1.0_real64/(1.0_real64+exp(-z))
        else
          se = exp(z)/(1.0_real64+exp(z))
        end if
        tr = self%cofgen(1,i)
        span = self%cofgen(2,i)-tr
        if (self%lookup_theta) water_content(i) = tr + span*se
        if (self%lookup_capacity) capacity(i) = exp(self%logc(idx)+f*(self%logc(idx+1)-self%logc(idx)))
        if (self%lookup_conductivity) conductivity(i) = exp(self%logk(idx)+f*(self%logk(idx+1)-self%logk(idx)))
        dconductivity_dhead(i) = 0.0_real64
      end if
    end do
  end subroutine ahl04_evaluate

  pure subroutine locate(x, value, idx, fraction)
    real(real64), intent(in) :: x(:), value
    integer, intent(out) :: idx
    real(real64), intent(out) :: fraction
    integer :: lo, hi, mid, n
    n=size(x)
    if (value <= x(1)) then
      idx=1; fraction=0.0_real64; return
    else if (value >= x(n)) then
      idx=n-1; fraction=1.0_real64; return
    end if
    lo=1; hi=n
    do while (hi-lo>1)
      mid=(lo+hi)/2
      if (x(mid) <= value) then
        lo=mid
      else
        hi=mid
      end if
    end do
    idx=lo
    fraction=(value-x(lo))/(x(lo+1)-x(lo))
  end subroutine locate

end module mod_ahl04_hybrid_lookup_provider
