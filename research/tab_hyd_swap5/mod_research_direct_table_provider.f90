module mod_research_direct_table_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  type, public :: direct_table_storage_t
     integer :: active_nodes = 0
     integer :: n_points = 0
     real(real64) :: h_min = 0.0_real64
     real(real64) :: x_min = 0.0_real64
     real(real64) :: dx = 0.0_real64
     real(real64), allocatable :: theta(:,:)
     real(real64), allocatable :: logk(:,:)
     real(real64), allocatable :: logc(:,:)
     real(real64), allocatable :: theta_slope(:,:)
     real(real64), allocatable :: logk_slope(:,:)
     real(real64), allocatable :: logc_slope(:,:)
  end type direct_table_storage_t

  type, extends(constitutive_hydraulics_provider_t), public :: direct_table_provider_t
     type(direct_table_storage_t), pointer :: table => null()
   contains
     procedure :: evaluate => direct_table_evaluate
  end type direct_table_provider_t

  public :: build_direct_table_from_provider
  public :: bind_direct_table_provider

contains

  subroutine build_direct_table_from_provider(table, source, active_nodes, n_points, h_min)
    type(direct_table_storage_t), intent(out) :: table
    class(constitutive_hydraulics_provider_t), intent(in) :: source
    integer, intent(in) :: active_nodes, n_points
    real(real64), intent(in) :: h_min

    real(real64), allocatable :: head(:), theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64), allocatable :: x(:)
    real(real64) :: xj, hj, tiny_positive
    integer :: i, j

    if (active_nodes <= 0) error stop 'TAB-HYD SWAP5 table: active_nodes must be positive'
    if (n_points < 4) error stop 'TAB-HYD SWAP5 table: n_points must be at least four'
    if (.not. ieee_is_finite(h_min) .or. h_min >= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: h_min must be finite and negative'

    table%active_nodes = active_nodes
    table%n_points = n_points
    table%h_min = h_min
    table%x_min = -log(1.0_real64-h_min)
    table%dx = -table%x_min/real(n_points-1,real64)
    if (.not. ieee_is_finite(table%dx) .or. table%dx <= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: invalid transformed spacing'

    allocate(table%theta(n_points,active_nodes), table%logk(n_points,active_nodes), &
             table%logc(n_points,active_nodes), table%theta_slope(n_points,active_nodes), &
             table%logk_slope(n_points,active_nodes), table%logc_slope(n_points,active_nodes))
    allocate(head(active_nodes),theta(active_nodes),conductivity(active_nodes),capacity(active_nodes),dkdh(active_nodes))
    allocate(x(n_points))

    tiny_positive = tiny(1.0_real64)
    do j = 1, n_points
       xj = table%x_min + real(j-1,real64)*table%dx
       if (j == n_points) xj = 0.0_real64
       x(j) = xj
       hj = 1.0_real64-exp(-xj)
       if (j == n_points) hj = 0.0_real64
       head = hj
       call source%evaluate(head,theta,conductivity,capacity,dkdh)
       if (any(.not. ieee_is_finite(theta)) .or. any(.not. ieee_is_finite(conductivity)) .or. &
           any(.not. ieee_is_finite(capacity))) &
            error stop 'TAB-HYD SWAP5 table: non-finite source constitutive value'
       if (any(conductivity <= 0.0_real64)) error stop 'TAB-HYD SWAP5 table: source K must be positive'
       if (any(capacity <= 0.0_real64)) error stop 'TAB-HYD SWAP5 table: source C must be positive'
       table%theta(j,:) = theta
       table%logk(j,:) = log(max(conductivity,tiny_positive))
       table%logc(j,:) = log(max(capacity,tiny_positive))
    end do

    do i = 1, active_nodes
       call monotone_cubic_slopes(table%theta(:,i),table%dx,table%theta_slope(:,i))
       call monotone_cubic_slopes(table%logk(:,i),table%dx,table%logk_slope(:,i))
       call monotone_cubic_slopes(table%logc(:,i),table%dx,table%logc_slope(:,i))
    end do
  end subroutine build_direct_table_from_provider

  subroutine bind_direct_table_provider(provider, table)
    type(direct_table_provider_t), intent(out) :: provider
    type(direct_table_storage_t), target, intent(in) :: table
    if (table%active_nodes <= 0 .or. table%n_points < 4 .or. table%dx <= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: invalid storage binding'
    if (.not. allocated(table%theta) .or. .not. allocated(table%logk) .or. .not. allocated(table%logc)) &
         error stop 'TAB-HYD SWAP5 table: storage arrays unavailable'
    provider%table => table
  end subroutine bind_direct_table_provider

  subroutine direct_table_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(direct_table_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)

    integer :: i, n
    real(real64) :: logk_value, logc_value

    if (.not. associated(self%table)) error stop 'TAB-HYD SWAP5 table: provider not bound'
    n = self%table%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) &
         error stop 'TAB-HYD SWAP5 table: shape mismatch'
    if (any(.not. ieee_is_finite(pressure_head))) error stop 'TAB-HYD SWAP5 table: non-finite head'

    do i = 1, n
       water_content(i) = interpolate_field(self%table, pressure_head(i), i, self%table%theta, self%table%theta_slope)
       logk_value = interpolate_field(self%table, pressure_head(i), i, self%table%logk, self%table%logk_slope)
       logc_value = interpolate_field(self%table, pressure_head(i), i, self%table%logc, self%table%logc_slope)
       conductivity(i) = exp(logk_value)
       capacity(i) = exp(logc_value)
    end do

    ! Current Status-A ordinary provider contract does not admit SWKIMPL=1.
    dconductivity_dhead = 0.0_real64

    if (any(.not. ieee_is_finite(water_content)) .or. any(.not. ieee_is_finite(conductivity)) .or. &
        any(.not. ieee_is_finite(capacity)) .or. any(conductivity <= 0.0_real64) .or. any(capacity <= 0.0_real64)) &
         error stop 'TAB-HYD SWAP5 table: invalid evaluated constitutive value'
  end subroutine direct_table_evaluate

  real(real64) function interpolate_field(table, head, node, values, slopes) result(value)
    type(direct_table_storage_t), intent(in) :: table
    real(real64), intent(in) :: head
    integer, intent(in) :: node
    real(real64), intent(in) :: values(:,:), slopes(:,:)

    real(real64) :: x, position, t, t2, t3
    real(real64) :: h00, h10, h01, h11
    integer :: lo

    if (head <= table%h_min) then
       value = values(1,node)
       return
    else if (head >= 0.0_real64) then
       value = values(table%n_points,node)
       return
    end if

    x = -log(1.0_real64-head)
    position = (x-table%x_min)/table%dx
    lo = int(floor(position)) + 1
    lo = max(1,min(table%n_points-1,lo))
    t = (x-(table%x_min+real(lo-1,real64)*table%dx))/table%dx
    t = max(0.0_real64,min(1.0_real64,t))
    t2 = t*t
    t3 = t2*t
    h00 = 2.0_real64*t3 - 3.0_real64*t2 + 1.0_real64
    h10 = t3 - 2.0_real64*t2 + t
    h01 = -2.0_real64*t3 + 3.0_real64*t2
    h11 = t3 - t2
    value = h00*values(lo,node) + h10*table%dx*slopes(lo,node) + &
            h01*values(lo+1,node) + h11*table%dx*slopes(lo+1,node)
  end function interpolate_field

  subroutine monotone_cubic_slopes(values, dx, slopes)
    real(real64), intent(in) :: values(:), dx
    real(real64), intent(out) :: slopes(:)
    real(real64), allocatable :: secant(:)
    real(real64) :: candidate
    integer :: n, j

    n = size(values)
    if (size(slopes) /= n .or. n < 4 .or. dx <= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: invalid slope construction'
    allocate(secant(n-1))
    secant = (values(2:n)-values(1:n-1))/dx

    do j = 2, n-1
       if (secant(j-1)*secant(j) <= 0.0_real64) then
          slopes(j) = 0.0_real64
       else
          slopes(j) = 2.0_real64*secant(j-1)*secant(j)/(secant(j-1)+secant(j))
       end if
    end do

    candidate = 0.5_real64*(3.0_real64*secant(1)-secant(2))
    slopes(1) = endpoint_slope(candidate,secant(1),secant(2))
    candidate = 0.5_real64*(3.0_real64*secant(n-1)-secant(n-2))
    slopes(n) = endpoint_slope(candidate,secant(n-1),secant(n-2))
  end subroutine monotone_cubic_slopes

  pure real(real64) function endpoint_slope(candidate, adjacent, next_adjacent) result(value)
    real(real64), intent(in) :: candidate, adjacent, next_adjacent
    value = candidate
    if (value*adjacent <= 0.0_real64) then
       value = 0.0_real64
    else if (adjacent*next_adjacent < 0.0_real64 .and. abs(value) > 3.0_real64*abs(adjacent)) then
       value = 3.0_real64*adjacent
    end if
  end function endpoint_slope

end module mod_research_direct_table_provider
