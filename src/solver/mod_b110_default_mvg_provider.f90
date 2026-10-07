module mod_b110_default_mvg_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t, &
       CONSTITUTIVE_DEMAND_WATER_CONTENT, CONSTITUTIVE_DEMAND_CONDUCTIVITY, &
       CONSTITUTIVE_DEMAND_CAPACITY, CONSTITUTIVE_DEMAND_DKDH
  implicit none
  private

  real(real64), parameter :: B110_H_CRIT = -1.0e-2_real64
  real(real64), parameter :: B110_HCON_VSMALL = 1.0e-10_real64
  integer, parameter :: B110_MCOF_REQUIRED = 42

  type, public :: b110_default_mvg_parameters_t
     integer :: active_nodes = 0
     real(real64), allocatable :: cofgen(:,:)
     logical :: ksatexm_extension_enabled = .false.
     logical :: elastic_storage_active = .false.
     logical :: conductivity_power_tail_enabled = .false.
     real(real64), allocatable :: specific_elastic_storage(:)
  end type b110_default_mvg_parameters_t

  type, extends(constitutive_hydraulics_provider_t), public :: b110_default_mvg_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     real(real64) :: step_duration = 0.0_real64
   contains
     procedure :: evaluate => b110_default_mvg_evaluate
     procedure :: evaluate_demand => b110_default_mvg_evaluate_demand
     procedure :: evaluate_water_content_increment => b110_default_mvg_evaluate_water_content_increment
     procedure :: supports_point_conductivity => b110_default_mvg_supports_point_conductivity
     procedure :: evaluate_point_conductivity => b110_default_mvg_evaluate_point_conductivity
  end type b110_default_mvg_provider_t

  public :: initialize_b110_default_mvg_parameters
  public :: bind_b110_default_mvg_provider
  public :: b110_hconduc
  public :: evaluate_b110_default_mvg_conductivity

contains

  subroutine initialize_b110_default_mvg_parameters(parameters, cofgen_input, enable_ksatexm_extension, &
                                                      enable_elastic_storage, specific_elastic_storage_input, &
                                                      enable_conductivity_power_tail)
    type(b110_default_mvg_parameters_t), intent(out) :: parameters
    real(real64), intent(in) :: cofgen_input(:,:)
    logical, intent(in), optional :: enable_ksatexm_extension
    logical, intent(in), optional :: enable_elastic_storage
    real(real64), intent(in), optional :: specific_elastic_storage_input(:)
    logical, intent(in), optional :: enable_conductivity_power_tail
    integer :: i, n
    real(real64) :: h105, t105, c105, a, b, alfa

    if (size(cofgen_input,1) < 24) error stop 'B1.10 default MvG provider: at least 24 cofgen rows required'
    n = size(cofgen_input,2)
    if (n <= 0) error stop 'B1.10 default MvG provider: active_nodes must be positive'
    parameters%active_nodes = n
    parameters%ksatexm_extension_enabled = .false.
    if (present(enable_ksatexm_extension)) parameters%ksatexm_extension_enabled = enable_ksatexm_extension
    parameters%elastic_storage_active = .false.
    if (present(enable_elastic_storage)) parameters%elastic_storage_active = enable_elastic_storage
    parameters%conductivity_power_tail_enabled = .false.
    if (present(enable_conductivity_power_tail)) parameters%conductivity_power_tail_enabled = enable_conductivity_power_tail
    if (parameters%elastic_storage_active .and. parameters%ksatexm_extension_enabled) &
         error stop 'B1.10 default MvG provider: elastic storage with KSATEXM is not qualified'
    if (parameters%elastic_storage_active .and. parameters%conductivity_power_tail_enabled) &
         error stop 'B1.11 MvG power tail: elastic storage combination is not qualified'
    if (parameters%elastic_storage_active) then
       if (.not. present(specific_elastic_storage_input)) &
            error stop 'B1.10 default MvG provider: elastic storage active without values'
       if (size(specific_elastic_storage_input) /= n) &
            error stop 'B1.10 default MvG provider: elastic storage shape mismatch'
       if (any(.not. ieee_is_finite(specific_elastic_storage_input)) .or. &
           any(specific_elastic_storage_input < 0.0_real64)) &
            error stop 'B1.10 default MvG provider: invalid elastic storage'
       allocate(parameters%specific_elastic_storage(n))
       parameters%specific_elastic_storage = specific_elastic_storage_input
    else
       if (present(specific_elastic_storage_input)) &
            error stop 'B1.10 default MvG provider: elastic storage values supplied while inactive'
    end if
    allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))
    parameters%cofgen = 0.0_real64
    parameters%cofgen(1:min(size(cofgen_input,1),B110_MCOF_REQUIRED),:) = &
         cofgen_input(1:min(size(cofgen_input,1),B110_MCOF_REQUIRED),:)

    do i = 1, n
       if (parameters%conductivity_power_tail_enabled) then
          if (.not. ieee_is_finite(parameters%cofgen(22,i)) .or. parameters%cofgen(22,i) >= 0.0_real64 .or. &
              parameters%cofgen(22,i) > parameters%cofgen(9,i)) &
               error stop 'B1.11 MvG power tail: invalid h_power'
          if (.not. ieee_is_finite(parameters%cofgen(23,i)) .or. parameters%cofgen(23,i) <= 0.0_real64) &
               error stop 'B1.11 MvG power tail: invalid k_power'
       end if
       if (parameters%ksatexm_extension_enabled .and. parameters%cofgen(10,i) > parameters%cofgen(3,i)) then
          if (.not. ieee_is_finite(parameters%cofgen(10,i)) .or. parameters%cofgen(10,i) <= 0.0_real64) &
               error stop 'B1.11 KSATEXM provider: invalid ksatexm'
          if (.not. ieee_is_finite(parameters%cofgen(11,i)) .or. parameters%cofgen(11,i) < 0.0_real64 .or. &
              parameters%cofgen(11,i) >= 1.0_real64) &
               error stop 'B1.11 KSATEXM provider: invalid relsat threshold'
          if (.not. ieee_is_finite(parameters%cofgen(12,i)) .or. parameters%cofgen(12,i) < 0.0_real64) &
               error stop 'B1.11 KSATEXM provider: invalid threshold conductivity'
       end if
       alfa = parameters%cofgen(4,i)
       parameters%cofgen(25,i) = parameters%cofgen(2,i) - parameters%cofgen(1,i)
       parameters%cofgen(26,i) = parameters%cofgen(1,i) + parameters%cofgen(25,i) / &
            ((1.0_real64 + (abs(alfa*B110_H_CRIT))**parameters%cofgen(6,i))**parameters%cofgen(7,i))
       parameters%cofgen(27,i) = (parameters%cofgen(2,i) - parameters%cofgen(26,i))/(-B110_H_CRIT)
       parameters%cofgen(28,i) = (1.0_real64 + &
            (abs(alfa*parameters%cofgen(9,i)))**parameters%cofgen(6,i))**(-parameters%cofgen(7,i))
       parameters%cofgen(29,i) = parameters%cofgen(6,i)*parameters%cofgen(7,i)*alfa
       parameters%cofgen(30,i) = parameters%cofgen(6,i) - 1.0_real64
       parameters%cofgen(31,i) = parameters%cofgen(7,i) + 1.0_real64
       parameters%cofgen(32,i) = 1.0_real64/parameters%cofgen(7,i)
       parameters%cofgen(33,i) = parameters%cofgen(6,i) * &
            (2.0_real64 + parameters%cofgen(7,i)*parameters%cofgen(5,i))
       parameters%cofgen(34,i) = parameters%cofgen(5,i) + 2.0_real64
       parameters%cofgen(35,i) = parameters%cofgen(7,i) - 1.0_real64
       parameters%cofgen(36,i) = parameters%cofgen(5,i) - 1.0_real64
       parameters%cofgen(37,i) = parameters%cofgen(14,i)*parameters%cofgen(15,i)*parameters%cofgen(13,i)
       parameters%cofgen(38,i) = parameters%cofgen(14,i) - 1.0_real64
       parameters%cofgen(39,i) = parameters%cofgen(15,i) + 1.0_real64
       if (parameters%cofgen(15,i) > 0.0_real64) then
          parameters%cofgen(40,i) = 1.0_real64/parameters%cofgen(15,i)
       else
          parameters%cofgen(40,i) = 0.0_real64
       end if

       if (parameters%cofgen(9,i) < 0.0_real64) then
          h105 = 1.05_real64 * parameters%cofgen(9,i)
          t105 = parameters%cofgen(1,i) + (parameters%cofgen(2,i)-parameters%cofgen(1,i)) * &
               ((1.0_real64 + (abs(alfa*parameters%cofgen(9,i)))**parameters%cofgen(6,i))**parameters%cofgen(7,i)) / &
               ((1.0_real64 + (abs(alfa*h105))**parameters%cofgen(6,i))**parameters%cofgen(7,i))
          c105 = (parameters%cofgen(2,i)-parameters%cofgen(1,i)) * alfa * parameters%cofgen(7,i) * &
               parameters%cofgen(6,i) * (abs(alfa*h105)**(parameters%cofgen(6,i)-1.0_real64)) * &
               ((1.0_real64 + abs(alfa*parameters%cofgen(9,i))**parameters%cofgen(6,i))**parameters%cofgen(7,i)) / &
               ((1.0_real64 + abs(alfa*h105)**parameters%cofgen(6,i))**(parameters%cofgen(7,i)+1.0_real64))
          a = (t105 - parameters%cofgen(2,i) - c105*h105)/(c105*h105**2)
          b = (t105**2 - 2.0_real64*t105*parameters%cofgen(2,i) + parameters%cofgen(2,i)**2) / &
               (t105 - parameters%cofgen(2,i) - c105*h105)
       else
          a = 0.0_real64
          b = 0.0_real64
       end if
       parameters%cofgen(41,i) = a
       parameters%cofgen(42,i) = a*b
    end do
  end subroutine initialize_b110_default_mvg_parameters

  subroutine bind_b110_default_mvg_provider(provider, parameters, step_duration)
    type(b110_default_mvg_provider_t), intent(out) :: provider
    type(b110_default_mvg_parameters_t), target, intent(in) :: parameters
    real(real64), intent(in) :: step_duration
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%cofgen)) &
         error stop 'B1.10 default MvG provider: invalid parameter set'
    if (step_duration <= 0.0_real64) error stop 'B1.10 default MvG provider: step_duration must be positive'
    provider%parameters => parameters
    provider%step_duration = step_duration
  end subroutine bind_b110_default_mvg_provider

  subroutine evaluate_b110_default_mvg_conductivity(parameters, node_index, pressure_head, conductivity, ok)
    type(b110_default_mvg_parameters_t), intent(in) :: parameters
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: ok
    real(real64) :: theta

    conductivity = 0.0_real64
    ok = .false.
    if (parameters%active_nodes <= 0 .or. .not. allocated(parameters%cofgen)) return
    if (size(parameters%cofgen,1) < B110_MCOF_REQUIRED .or. &
        size(parameters%cofgen,2) /= parameters%active_nodes) return
    if (node_index < 1 .or. node_index > parameters%active_nodes) return
    if (.not. ieee_is_finite(pressure_head)) return

    theta = b110_watcon(parameters%cofgen(:,node_index), pressure_head)
    if (.not. ieee_is_finite(theta)) return
    conductivity = b110_hconduc(parameters%cofgen(:,node_index), pressure_head, theta, &
         parameters%ksatexm_extension_enabled, parameters%conductivity_power_tail_enabled)
    if (.not. ieee_is_finite(conductivity) .or. conductivity < 0.0_real64) then
       conductivity = 0.0_real64
       return
    end if
    ok = .true.
  end subroutine evaluate_b110_default_mvg_conductivity

  subroutine b110_default_mvg_evaluate_water_content_increment(self, pressure_head, previous_pressure_head, &
                                                                 water_content, previous_water_content, increment)
    class(b110_default_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:), previous_pressure_head(:)
    real(real64), intent(in) :: water_content(:), previous_water_content(:)
    real(real64), intent(out) :: increment(:)
    integer :: i, n

    if (.not. associated(self%parameters)) error stop 'B1.10 default MvG provider: parameters not bound'
    n = self%parameters%active_nodes
    if (size(pressure_head) /= n .or. size(previous_pressure_head) /= n .or. size(water_content) /= n .or. &
        size(previous_water_content) /= n .or. size(increment) /= n) &
         error stop 'B1.10 default MvG provider: storage increment shape mismatch'

    do i = 1, n
      if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64 .and. &
          previous_pressure_head(i) >= 0.0_real64) then
        increment(i) = self%parameters%specific_elastic_storage(i) * &
             (pressure_head(i)-previous_pressure_head(i))
      else
        increment(i) = b110_watcon_increment(self%parameters%cofgen(:,i), pressure_head(i), &
             previous_pressure_head(i), water_content(i), previous_water_content(i))
      end if
    end do
  end subroutine b110_default_mvg_evaluate_water_content_increment

  logical function b110_default_mvg_supports_point_conductivity(self) result(supported)
    class(b110_default_mvg_provider_t), intent(in) :: self
    supported = associated(self%parameters)
  end function b110_default_mvg_supports_point_conductivity

  subroutine b110_default_mvg_evaluate_point_conductivity(self, node_index, pressure_head, water_content, conductivity, &
                                                           available)
    class(b110_default_mvg_provider_t), intent(in) :: self
    integer, intent(in) :: node_index
    real(real64), intent(in) :: pressure_head, water_content
    real(real64), intent(out) :: conductivity
    logical, intent(out) :: available

    conductivity = 0.0_real64
    available = .false.
    if (.not. associated(self%parameters)) return
    if (node_index < 1 .or. node_index > self%parameters%active_nodes) return
    if (.not. ieee_is_finite(pressure_head) .or. .not. ieee_is_finite(water_content)) return
    conductivity = b110_hconduc(self%parameters%cofgen(:,node_index), pressure_head, water_content, &
         self%parameters%ksatexm_extension_enabled)
    if (.not. ieee_is_finite(conductivity) .or. conductivity < 0.0_real64) then
      conductivity = 0.0_real64
      return
    end if
    available = .true.
  end subroutine b110_default_mvg_evaluate_point_conductivity

  subroutine b110_default_mvg_evaluate_demand(self, pressure_head, demand_mask, water_content, conductivity, &
                                                capacity, dconductivity_dhead)
    class(b110_default_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    integer, intent(in) :: demand_mask
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, n
    real(real64) :: theta_local
    logical :: need_theta, need_k, need_capacity, need_dkdh

    if (.not. associated(self%parameters)) error stop 'B1.10 default MvG provider: parameters not bound'
    n = self%parameters%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) &
         error stop 'B1.10 default MvG provider: shape mismatch'
    if (self%step_duration <= 0.0_real64) error stop 'B1.10 default MvG provider: invalid step_duration'

    select case (demand_mask)
    case (CONSTITUTIVE_DEMAND_WATER_CONTENT)
       do i = 1, n
          water_content(i) = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i))
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               water_content(i) = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
       end do
       return
    case (CONSTITUTIVE_DEMAND_CAPACITY)
       do i = 1, n
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               capacity(i) = self%parameters%specific_elastic_storage(i)
       end do
       return
    case (CONSTITUTIVE_DEMAND_WATER_CONTENT + CONSTITUTIVE_DEMAND_CONDUCTIVITY)
       do i = 1, n
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i))
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          water_content(i) = theta_local
          conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled, self%parameters%conductivity_power_tail_enabled)
       end do
       return
    case (CONSTITUTIVE_DEMAND_CONDUCTIVITY + CONSTITUTIVE_DEMAND_CAPACITY)
       do i = 1, n
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i))
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled)
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               capacity(i) = self%parameters%specific_elastic_storage(i)
       end do
       return
    case default
       continue
    end select

    need_theta = iand(demand_mask, CONSTITUTIVE_DEMAND_WATER_CONTENT) /= 0
    need_k = iand(demand_mask, CONSTITUTIVE_DEMAND_CONDUCTIVITY) /= 0
    need_capacity = iand(demand_mask, CONSTITUTIVE_DEMAND_CAPACITY) /= 0
    need_dkdh = iand(demand_mask, CONSTITUTIVE_DEMAND_DKDH) /= 0

    do i = 1, n
       if (need_theta .or. need_k) then
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i))
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          if (need_theta) water_content(i) = theta_local
          if (need_k) conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled)
       end if
       if (need_capacity) then
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               capacity(i) = self%parameters%specific_elastic_storage(i)
       end if
    end do
    if (need_dkdh) dconductivity_dhead = 0.0_real64
  end subroutine b110_default_mvg_evaluate_demand

  subroutine b110_default_mvg_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b110_default_mvg_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, n

    if (.not. associated(self%parameters)) error stop 'B1.10 default MvG provider: parameters not bound'
    n = self%parameters%active_nodes
    if (size(pressure_head) /= n .or. size(water_content) /= n .or. size(conductivity) /= n .or. &
        size(capacity) /= n .or. size(dconductivity_dhead) /= n) &
         error stop 'B1.10 default MvG provider: shape mismatch'
    if (self%step_duration <= 0.0_real64) error stop 'B1.10 default MvG provider: invalid step_duration'

    do i = 1, n
       water_content(i) = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i))
       capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration)
       if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) then
          water_content(i) = self%parameters%cofgen(2,i) + &
               pressure_head(i)*self%parameters%specific_elastic_storage(i)
          capacity(i) = self%parameters%specific_elastic_storage(i)
       end if
       conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), water_content(i), &
            self%parameters%ksatexm_extension_enabled, self%parameters%conductivity_power_tail_enabled)
    end do
    ! swkimpl=1 is deliberately not admitted by F-SI09. The common interface reserves this output.
    dconductivity_dhead = 0.0_real64
  end subroutine b110_default_mvg_evaluate

  pure real(real64) function b110_watcon(c, head) result(watcon)
    real(real64), intent(in) :: c(:), head
    real(real64) :: help, h105, alfa
    alfa = c(4)
    if (head >= 0.0_real64) then
       watcon = c(2)
    else
       if (c(9) > B110_H_CRIT) then
          if (head > B110_H_CRIT) then
             watcon = c(26) + c(27)*(head-B110_H_CRIT)
             watcon = min(watcon,c(2))
          else
             help = abs(alfa*head)**c(6)
             help = (1.0_real64 + help)**c(7)
             watcon = c(1) + c(25)/help
          end if
       else
          h105 = 1.05_real64*c(9)
          if (head >= h105) then
             watcon = c(2) + c(42)*head/(1.0_real64+c(41)*head)
          else
             help = abs(alfa*head)**c(6)
             help = (1.0_real64 + help)**c(7)
             watcon = c(1) + c(25)/(help*c(28))
          end if
       end if
    end if
  end function b110_watcon

  pure real(real64) function b110_watcon_increment(c, head_new, head_old, theta_new, theta_old) result(delta_theta)
    real(real64), intent(in) :: c(:), head_new, head_old, theta_new, theta_old
    real(real64) :: h105

    delta_theta = theta_new-theta_old
    if (head_new == head_old) then
      delta_theta = 0.0_real64
      return
    end if
    if (head_new >= 0.0_real64 .and. head_old >= 0.0_real64) then
      delta_theta = 0.0_real64
      return
    end if
    if (head_new >= 0.0_real64 .or. head_old >= 0.0_real64) return

    if (c(9) > B110_H_CRIT) then
      if (head_new > B110_H_CRIT .and. head_old > B110_H_CRIT) then
        delta_theta = c(27)*(head_new-head_old)
      else if (head_new <= B110_H_CRIT .and. head_old <= B110_H_CRIT) then
        delta_theta = b110_vg_same_branch_increment(c,head_new,head_old,1.0_real64,delta_theta)
      end if
    else
      h105 = 1.05_real64*c(9)
      if (head_new >= h105 .and. head_old >= h105) then
        delta_theta = c(42)*(head_new-head_old) / &
             ((1.0_real64+c(41)*head_new)*(1.0_real64+c(41)*head_old))
      else if (head_new < h105 .and. head_old < h105) then
        delta_theta = b110_vg_same_branch_increment(c,head_new,head_old,c(28),delta_theta)
      end if
    end if
  end function b110_watcon_increment

  pure real(real64) function b110_vg_same_branch_increment(c,head_new,head_old,normalization,fallback) result(delta_theta)
    real(real64), intent(in) :: c(:), head_new, head_old, normalization, fallback
    real(real64) :: abs_old, relative_abs_change, x_old, dx, dlog_se, se_old

    delta_theta = fallback
    abs_old = abs(head_old)
    if (abs_old <= 0.0_real64 .or. normalization <= 0.0_real64) return
    relative_abs_change = (abs(head_new)-abs_old)/abs_old
    if (relative_abs_change <= -1.0_real64) return

    x_old = abs(c(4)*head_old)**c(6)
    if (.not. ieee_is_finite(x_old)) return
    dx = x_old*b110_expm1(c(6)*b110_log1p(relative_abs_change))
    if (.not. ieee_is_finite(dx)) return
    dlog_se = -c(7)*b110_log1p(dx/(1.0_real64+x_old))
    if (.not. ieee_is_finite(dlog_se)) return
    se_old = 1.0_real64/((1.0_real64+x_old)**c(7))
    if (.not. ieee_is_finite(se_old)) return
    delta_theta = c(25)*se_old*b110_expm1(dlog_se)/normalization
    if (.not. ieee_is_finite(delta_theta)) delta_theta = fallback
  end function b110_vg_same_branch_increment

  pure real(real64) function b110_log1p(x) result(value)
    real(real64), intent(in) :: x
    real(real64) :: x2
    if (abs(x) < 1.0e-3_real64) then
      x2 = x*x
      value = x - 0.5_real64*x2 + x*x2/3.0_real64 - x2*x2/4.0_real64 + &
           x*x2*x2/5.0_real64 - x2*x2*x2/6.0_real64
    else
      value = log(1.0_real64+x)
    end if
  end function b110_log1p

  pure real(real64) function b110_expm1(x) result(value)
    real(real64), intent(in) :: x
    real(real64) :: x2
    if (abs(x) < 1.0e-3_real64) then
      x2 = x*x
      value = x + 0.5_real64*x2 + x*x2/6.0_real64 + x2*x2/24.0_real64 + &
           x*x2*x2/120.0_real64 + x2*x2*x2/720.0_real64
    else
      value = exp(x)-1.0_real64
    end if
  end function b110_expm1

  pure real(real64) function b110_moiscap(c, head, step_duration) result(capacity)
    real(real64), intent(in) :: c(:), head, step_duration
    real(real64) :: alphah, h105, term1, term2
    if (head >= 0.0_real64) then
       capacity = step_duration*1.0e-7_real64
    else
       alphah = abs(c(4)*head)
       if (c(9) > B110_H_CRIT) then
          if (head > B110_H_CRIT) then
             capacity = c(27)
          else
             term1 = alphah**c(30)
             term2 = c(25)/((1.0_real64 + term1*alphah)**c(31))
             capacity = c(29)*term2*term1
          end if
       else
          h105 = 1.05_real64*c(9)
          if (head >= h105) then
             capacity = c(42)/((1.0_real64+c(41)*head)**2)
          else
             term1 = alphah**c(30)
             term2 = (1.0_real64 + term1*alphah)**c(31)
             term2 = c(25)/term2
             capacity = c(29)*term2*term1/c(28)
          end if
       end if
       if (head > -1.0_real64 .and. capacity < step_duration*1.0e-7_real64) capacity = step_duration*1.0e-7_real64
    end if
  end function b110_moiscap

  pure real(real64) function b110_hconduc(c, head, theta, enable_ksatexm_extension, enable_power_tail) result(hconduc)
    real(real64), intent(in) :: c(:), head, theta
    logical, intent(in) :: enable_ksatexm_extension
    logical, intent(in), optional :: enable_power_tail
    real(real64) :: relsat, term1, term2, se
    logical :: ksatexm_applied, power_tail
    relsat = (theta-c(1))/c(25)
    ksatexm_applied = .false.
    power_tail = .false.
    if (present(enable_power_tail)) power_tail = enable_power_tail
    if (enable_ksatexm_extension .and. c(10) > c(3) .and. relsat > c(11)) then
       term1 = (relsat-c(11))/(1.0_real64-c(11))
       hconduc = term1*c(10) + (1.0_real64-term1)*c(12)
       ksatexm_applied = .true.
    else if (c(9) > B110_H_CRIT) then
       if (head < -1.0e14_real64) then
          hconduc = B110_HCON_VSMALL
       else if (relsat > (1.0_real64-1.0e-6_real64)) then
          hconduc = c(3)
       else if (power_tail .and. head <= c(22)) then
          hconduc = c(23)*(abs(c(22))/abs(head))**c(33)
       else
          term1 = (1.0_real64-relsat**c(32))**c(7)
          hconduc = c(3)*(relsat**c(5))*(1.0_real64-term1)**2
       end if
    else
       if (head < -1.0e14_real64) then
          hconduc = B110_HCON_VSMALL
       else
          if (head >= c(9)) then
             hconduc = c(3)
          else if (power_tail .and. head <= c(22)) then
             hconduc = c(23)*(abs(c(22))/abs(head))**c(33)
          else
             se = ((1.0_real64 + abs(c(4)*head)**c(6))**(-c(7)))/c(28)
             term1 = (1.0_real64-(se*c(28))**c(32))**c(7)
             term2 = (1.0_real64-c(28)**c(32))**c(7)
             hconduc = c(3)*se**c(5)*((1.0_real64-term1)/(1.0_real64-term2))**2
          end if
       end if
    end if
    if (.not. ksatexm_applied) hconduc = min(hconduc,c(3))
  end function b110_hconduc

end module mod_b110_default_mvg_provider

module mod_b111_analytical_hydraulic_provider
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private
  integer, parameter, public :: B111_HYD_EXPONENTIAL = 2
  integer, parameter, public :: B111_HYD_BIMODAL_MVG = 3
  integer, parameter, public :: B111_HYD_BIMODAL_MVG_WCK = 6

  type, public :: b111_analytical_hydraulic_parameters_t
    integer :: active_nodes = 0
    integer, allocatable :: model_kind(:)
    real(real64), allocatable :: theta_r(:), theta_s(:), ksat(:), alpha_1(:), lambda(:), n_1(:), m_1(:)
    real(real64), allocatable :: alpha_2(:), n_2(:), m_2(:), omega_1(:)
  end type

  type, extends(constitutive_hydraulics_provider_t), public :: b111_analytical_hydraulic_provider_t
    type(b111_analytical_hydraulic_parameters_t), pointer :: parameters => null()
  contains
    procedure :: evaluate => b111_analytical_evaluate
    procedure :: supports_point_conductivity => b111_analytical_supports_point_conductivity
    procedure :: evaluate_point_conductivity => b111_analytical_evaluate_point_conductivity
  end type

  public :: initialize_b111_analytical_hydraulic_parameters
  public :: bind_b111_analytical_hydraulic_provider
contains
  subroutine initialize_b111_analytical_hydraulic_parameters(parameters, model_kind, cofgen)
    type(b111_analytical_hydraulic_parameters_t), intent(out) :: parameters
    integer, intent(in) :: model_kind(:)
    real(real64), intent(in) :: cofgen(:,:)
    integer :: n, i
    n=size(model_kind)
    if(n<=0 .or. size(cofgen,1)<16 .or. size(cofgen,2)/=n) error stop 'B1.11 analytical hydraulics: shape mismatch'
    if(any(model_kind/=B111_HYD_EXPONENTIAL .and. model_kind/=B111_HYD_BIMODAL_MVG .and. &
           model_kind/=B111_HYD_BIMODAL_MVG_WCK)) &
      error stop 'B1.11 analytical hydraulics: unsupported model kind'
    if(any(.not.ieee_is_finite(cofgen(1:16,:)))) error stop 'B1.11 analytical hydraulics: non-finite parameter'
    if(any(cofgen(2,:)<=cofgen(1,:)) .or. any(cofgen(3,:)<=0.0_real64) .or. any(cofgen(4,:)<=0.0_real64)) &
      error stop 'B1.11 analytical hydraulics: invalid primary parameters'
    parameters%active_nodes=n
    allocate(parameters%model_kind(n),parameters%theta_r(n),parameters%theta_s(n),parameters%ksat(n), &
      parameters%alpha_1(n),parameters%lambda(n),parameters%n_1(n),parameters%m_1(n), &
      parameters%alpha_2(n),parameters%n_2(n),parameters%m_2(n),parameters%omega_1(n))
    parameters%model_kind=model_kind
    parameters%theta_r=cofgen(1,:); parameters%theta_s=cofgen(2,:); parameters%ksat=cofgen(3,:)
    parameters%alpha_1=cofgen(4,:); parameters%lambda=cofgen(5,:); parameters%n_1=cofgen(6,:); parameters%m_1=cofgen(7,:)
    parameters%alpha_2=cofgen(13,:); parameters%n_2=cofgen(14,:); parameters%m_2=cofgen(15,:); parameters%omega_1=cofgen(16,:)
    do i=1,n
      if(model_kind(i)==B111_HYD_BIMODAL_MVG .or. model_kind(i)==B111_HYD_BIMODAL_MVG_WCK) then
        if(parameters%n_1(i)<=1.0_real64 .or. parameters%m_1(i)<=0.0_real64 .or. &
          parameters%alpha_2(i)<=0.0_real64 .or. parameters%n_2(i)<=1.0_real64 .or. &
          parameters%m_2(i)<=0.0_real64 .or. parameters%omega_1(i)<0.0_real64 .or. parameters%omega_1(i)>1.0_real64) &
          error stop 'B1.11 analytical hydraulics: invalid bimodal parameters'
      end if
    end do
  end subroutine

  subroutine bind_b111_analytical_hydraulic_provider(provider,parameters)
    type(b111_analytical_hydraulic_provider_t),intent(out)::provider
    type(b111_analytical_hydraulic_parameters_t),target,intent(in)::parameters
    if(parameters%active_nodes<=0) error stop 'B1.11 analytical hydraulics: invalid parameter set'
    provider%parameters=>parameters
  end subroutine

  subroutine b111_analytical_evaluate(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head(:)
    real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
    integer::i,n
    if(.not.associated(self%parameters)) error stop 'B1.11 analytical hydraulics: parameters not bound'
    n=self%parameters%active_nodes
    if(size(pressure_head)/=n.or.size(water_content)/=n.or.size(conductivity)/=n.or.size(capacity)/=n.or.size(dconductivity_dhead)/=n) &
      error stop 'B1.11 analytical hydraulics: shape mismatch'
    do i=1,n
      call evaluate_node(self%parameters,i,pressure_head(i),water_content(i),conductivity(i),capacity(i),dconductivity_dhead(i))
    end do
  end subroutine

  pure subroutine evaluate_node(p,i,h,theta,k,cap,dkdh)
    type(b111_analytical_hydraulic_parameters_t),intent(in)::p
    integer,intent(in)::i
    real(real64),intent(in)::h
    real(real64),intent(out)::theta,k,cap,dkdh
    real(real64)::delta,s1,s2,relsat,a1,a2,term1,term2,scomb,denom,q
    real(real64)::ds1,ds2,dscomb,df1,df2,dtcond,dq
    delta=p%theta_s(i)-p%theta_r(i)
    select case(p%model_kind(i))
    case(B111_HYD_EXPONENTIAL)
      theta=max(1.0000001_real64*p%theta_r(i),p%theta_r(i)+delta*exp(p%alpha_1(i)*h))
      cap=p%alpha_1(i)*delta*exp(p%alpha_1(i)*h)
      relsat=(theta-p%theta_r(i))/delta
      k=p%ksat(i)*relsat
      dkdh=p%alpha_1(i)*p%ksat(i)*exp(p%alpha_1(i)*h)
    case(B111_HYD_BIMODAL_MVG,B111_HYD_BIMODAL_MVG_WCK)
      if(h>=0.0_real64) then
        theta=p%theta_s(i)
        cap=0.0_real64
        k=p%ksat(i)
        dkdh=1.0e-12_real64
      else
        s1=(1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i))
        s2=(1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i))
        scomb=p%omega_1(i)*s1+(1.0_real64-p%omega_1(i))*s2
        theta=p%theta_r(i)+delta*scomb
        cap=delta*(p%omega_1(i)*p%alpha_1(i)*p%n_1(i)*p%m_1(i)* &
          abs(p%alpha_1(i)*h)**(p%n_1(i)-1.0_real64)*(1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i)-1.0_real64) + &
          (1.0_real64-p%omega_1(i))*p%alpha_2(i)*p%n_2(i)*p%m_2(i)* &
          abs(p%alpha_2(i)*h)**(p%n_2(i)-1.0_real64)*(1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i)-1.0_real64))
        a1=1.0_real64-s1**(1.0_real64/p%m_1(i))
        a2=1.0_real64-s2**(1.0_real64/p%m_2(i))
        term1=p%omega_1(i)*p%alpha_1(i)*a1**p%m_1(i)
        term2=(1.0_real64-p%omega_1(i))*p%alpha_2(i)*a2**p%m_2(i)
        denom=p%omega_1(i)*p%alpha_1(i)+(1.0_real64-p%omega_1(i))*p%alpha_2(i)
        q=1.0_real64-(term1+term2)/denom
        k=p%ksat(i)*scomb**p%lambda(i)*q*q
        ds1=p%alpha_1(i)*p%n_1(i)*p%m_1(i)*abs(p%alpha_1(i)*h)**(p%n_1(i)-1.0_real64)* &
          (1.0_real64+abs(p%alpha_1(i)*h)**p%n_1(i))**(-p%m_1(i)-1.0_real64)
        ds2=p%alpha_2(i)*p%n_2(i)*p%m_2(i)*abs(p%alpha_2(i)*h)**(p%n_2(i)-1.0_real64)* &
          (1.0_real64+abs(p%alpha_2(i)*h)**p%n_2(i))**(-p%m_2(i)-1.0_real64)
        dscomb=p%omega_1(i)*ds1+(1.0_real64-p%omega_1(i))*ds2
        df1=-a1**(p%m_1(i)-1.0_real64)*s1**(1.0_real64/p%m_1(i)-1.0_real64)*ds1
        df2=-a2**(p%m_2(i)-1.0_real64)*s2**(1.0_real64/p%m_2(i)-1.0_real64)*ds2
        dtcond=p%omega_1(i)*p%alpha_1(i)*df1+(1.0_real64-p%omega_1(i))*p%alpha_2(i)*df2
        dq=-dtcond/denom
        dkdh=p%ksat(i)*(p%lambda(i)*scomb**(p%lambda(i)-1.0_real64)*dscomb*q*q + &
          2.0_real64*scomb**p%lambda(i)*q*dq)
      end if
    end select
  end subroutine

  logical function b111_analytical_supports_point_conductivity(self) result(supported)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    supported=associated(self%parameters)
  end function

  subroutine b111_analytical_evaluate_point_conductivity(self,node_index,pressure_head,water_content,conductivity,available)
    class(b111_analytical_hydraulic_provider_t),intent(in)::self
    integer,intent(in)::node_index
    real(real64),intent(in)::pressure_head,water_content
    real(real64),intent(out)::conductivity
    logical,intent(out)::available
    real(real64)::theta,cap,dk
    available=.false.
    conductivity=0.0_real64
    if(.not.associated(self%parameters))return
    if(node_index<1.or.node_index>self%parameters%active_nodes)return
    call evaluate_node(self%parameters,node_index,pressure_head,theta,conductivity,cap,dk)
    available=ieee_is_finite(conductivity).and.conductivity>=0.0_real64
  end subroutine
end module

