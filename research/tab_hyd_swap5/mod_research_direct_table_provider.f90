module mod_research_direct_table_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  implicit none
  private

  real(real64), parameter :: B110_H_CRIT = -1.0e-2_real64
  real(real64), parameter :: B110_SAT_K_SWITCH = 1.0_real64 - 1.0e-6_real64

  type, public :: direct_table_storage_t
     integer :: active_nodes = 0
     integer :: n_points = 0
     real(real64) :: h_min = 0.0_real64
     real(real64) :: h_scale = 1.0_real64
     real(real64) :: x_min = 0.0_real64
     real(real64) :: dx = 0.0_real64
     real(real64), allocatable :: theta(:,:)
     real(real64), allocatable :: logk(:,:)
     real(real64), allocatable :: logc(:,:)
     real(real64), allocatable :: theta_slope(:,:)
     real(real64), allocatable :: logk_slope(:,:)
     real(real64), allocatable :: logc_slope(:,:)
     real(real64), allocatable :: saturated_capacity(:)
     logical, allocatable :: branch_a(:)
     real(real64), allocatable :: capacity_transition(:)
     real(real64), allocatable :: capacity_near_saturation(:)
     real(real64), allocatable :: conductivity_switch_head(:)
     real(real64), allocatable :: conductivity_left_limit(:)
     real(real64), allocatable :: saturated_conductivity(:)
  end type direct_table_storage_t

  type, extends(constitutive_hydraulics_provider_t), public :: direct_table_provider_t
     type(direct_table_storage_t), pointer :: table => null()
   contains
     procedure :: evaluate => direct_table_evaluate
  end type direct_table_provider_t

  public :: build_direct_table_from_provider
  public :: bind_direct_table_provider

contains

  subroutine build_direct_table_from_provider(table, source, active_nodes, n_points, h_min, h_scale)
    type(direct_table_storage_t), intent(out) :: table
    type(b110_default_mvg_provider_t), intent(in) :: source
    integer, intent(in) :: active_nodes, n_points
    real(real64), intent(in) :: h_min, h_scale

    real(real64), allocatable :: head(:), theta(:), conductivity(:), capacity(:), dkdh(:)
    real(real64), allocatable :: x(:)
    real(real64) :: xj, hj, tiny_positive, negative_endpoint_head
    real(real64) :: theta_switch, c1, c2, c25, c26, c27, eps_head
    real(real64), allocatable :: knot_head(:)
    integer :: i, j

    if (active_nodes <= 0) error stop 'TAB-HYD SWAP5 table: active_nodes must be positive'
    if (n_points < 4) error stop 'TAB-HYD SWAP5 table: n_points must be at least four'
    if (.not. ieee_is_finite(h_min) .or. h_min >= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: h_min must be finite and negative'
    if (.not. ieee_is_finite(h_scale) .or. h_scale <= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: h_scale must be finite and positive'

    table%active_nodes = active_nodes
    table%n_points = n_points
    table%h_min = h_min
    table%h_scale = h_scale
    table%x_min = -log(1.0_real64-h_min/h_scale)
    table%dx = -table%x_min/real(n_points-1,real64)
    if (.not. ieee_is_finite(table%dx) .or. table%dx <= 0.0_real64) &
         error stop 'TAB-HYD SWAP5 table: invalid transformed spacing'

    allocate(table%theta(n_points,active_nodes), table%logk(n_points,active_nodes), &
             table%logc(n_points,active_nodes), table%theta_slope(n_points,active_nodes), &
             table%logk_slope(n_points,active_nodes), table%logc_slope(n_points,active_nodes), &
             table%saturated_capacity(active_nodes), table%branch_a(active_nodes), &
             table%capacity_transition(active_nodes), table%capacity_near_saturation(active_nodes), &
             table%conductivity_switch_head(active_nodes), table%conductivity_left_limit(active_nodes), &
             table%saturated_conductivity(active_nodes))
    allocate(head(active_nodes),theta(active_nodes),conductivity(active_nodes),capacity(active_nodes),dkdh(active_nodes))
    allocate(x(n_points),knot_head(n_points))
    table%branch_a = .false.
    table%capacity_transition = 0.0_real64
    table%capacity_near_saturation = 0.0_real64
    table%conductivity_switch_head = 0.0_real64
    table%conductivity_left_limit = 0.0_real64
    table%saturated_conductivity = 0.0_real64

    if (.not. associated(source%parameters)) error stop 'TAB-HYD SWAP5 table: B1.10 source parameters not bound'
    if (source%parameters%active_nodes /= active_nodes) &
         error stop 'TAB-HYD SWAP5 table: B1.10 source node count mismatch'

    tiny_positive = tiny(1.0_real64)
    do j = 1, n_points
       xj = table%x_min + real(j-1,real64)*table%dx
       if (j == n_points) xj = 0.0_real64
       x(j) = xj
       hj = h_scale*(1.0_real64-exp(-xj))
       knot_head(j) = hj
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
       if (j == n_points) then
          table%saturated_capacity = capacity
          table%saturated_conductivity = conductivity
       end if
    end do

    ! Preserve the explicit branch surfaces of the qualified B1.10 provider.
    ! A smooth interpolant must not smear the C jump at Hcrit or the Ksat guard.
    do i = 1, active_nodes
       if (source%parameters%cofgen(9,i) > B110_H_CRIT) then
          table%branch_a(i) = .true.
          c1 = source%parameters%cofgen(1,i)
          c2 = source%parameters%cofgen(2,i)
          c25 = source%parameters%cofgen(25,i)
          c26 = source%parameters%cofgen(26,i)
          c27 = source%parameters%cofgen(27,i)
          if (c25 <= 0.0_real64 .or. c27 <= 0.0_real64) &
               error stop 'TAB-HYD SWAP5 table: invalid Branch-A parameters'

          head = B110_H_CRIT
          call source%evaluate(head,theta,conductivity,capacity,dkdh)
          table%capacity_transition(i) = capacity(i)

          head = 0.5_real64*B110_H_CRIT
          call source%evaluate(head,theta,conductivity,capacity,dkdh)
          table%capacity_near_saturation(i) = capacity(i)

          theta_switch = c1 + c25*B110_SAT_K_SWITCH
          table%conductivity_switch_head(i) = B110_H_CRIT + (theta_switch-c26)/c27
          if (table%conductivity_switch_head(i) <= B110_H_CRIT .or. &
              table%conductivity_switch_head(i) >= 0.0_real64) &
               error stop 'TAB-HYD SWAP5 table: Branch-A K switch outside near-saturation interval'
       end if
    end do

    head = 0.0_real64
    do i = 1, active_nodes
       if (table%branch_a(i)) then
          eps_head = max(1.0e-12_real64,abs(table%conductivity_switch_head(i))*1.0e-10_real64)
          head(i) = table%conductivity_switch_head(i)-eps_head
       end if
    end do
    call source%evaluate(head,theta,conductivity,capacity,dkdh)
    do i = 1, active_nodes
       if (table%branch_a(i)) then
          table%conductivity_left_limit(i) = conductivity(i)
          if (table%capacity_transition(i) <= 0.0_real64 .or. table%capacity_near_saturation(i) <= 0.0_real64 .or. &
              table%conductivity_left_limit(i) <= 0.0_real64 .or. table%saturated_conductivity(i) <= 0.0_real64) &
               error stop 'TAB-HYD SWAP5 table: invalid Branch-A support value'
          do j = 1, n_points
             if (knot_head(j) > B110_H_CRIT) &
                  table%logc(j,i) = log(table%capacity_transition(i))
             if (knot_head(j) > table%conductivity_switch_head(i)) &
                  table%logk(j,i) = log(table%conductivity_left_limit(i))
          end do
       end if
    end do

    ! Preserve the separate saturated C branch at h >= 0. The negative endpoint
    ! is support for the unsaturated interpolant only.
    negative_endpoint_head = -max(1.0e-12_real64,1.0e-10_real64*h_scale)
    head = negative_endpoint_head
    call source%evaluate(head,theta,conductivity,capacity,dkdh)
    if (any(.not. ieee_is_finite(capacity)) .or. any(capacity <= 0.0_real64)) &
         error stop 'TAB-HYD SWAP5 table: invalid negative endpoint C'
    do i = 1, active_nodes
       if (.not. table%branch_a(i)) table%logc(n_points,i) = log(max(capacity(i),tiny_positive))
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
       if (self%table%branch_a(i) .and. pressure_head(i) > self%table%conductivity_switch_head(i)) then
          conductivity(i) = self%table%saturated_conductivity(i)
       else if (self%table%branch_a(i) .and. pressure_head(i) == self%table%conductivity_switch_head(i)) then
          conductivity(i) = self%table%conductivity_left_limit(i)
       else
          logk_value = interpolate_field(self%table, pressure_head(i), i, self%table%logk, self%table%logk_slope)
          conductivity(i) = exp(logk_value)
       end if

       if (pressure_head(i) >= 0.0_real64) then
          capacity(i) = self%table%saturated_capacity(i)
       else if (self%table%branch_a(i) .and. pressure_head(i) > B110_H_CRIT) then
          capacity(i) = self%table%capacity_near_saturation(i)
       else if (self%table%branch_a(i) .and. pressure_head(i) == B110_H_CRIT) then
          capacity(i) = self%table%capacity_transition(i)
       else
          logc_value = interpolate_field(self%table, pressure_head(i), i, self%table%logc, self%table%logc_slope)
          capacity(i) = exp(logc_value)
       end if
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

    x = -log(1.0_real64-head/table%h_scale)
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
