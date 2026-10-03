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
     real(real64) :: near_saturation_transition_width_cm = 0.0_real64
     real(real64), allocatable :: specific_elastic_storage(:)
  end type b110_default_mvg_parameters_t

  type, extends(constitutive_hydraulics_provider_t), public :: b110_default_mvg_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     real(real64) :: step_duration = 0.0_real64
   contains
     procedure :: evaluate => b110_default_mvg_evaluate
     procedure :: evaluate_demand => b110_default_mvg_evaluate_demand
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
                                                      near_saturation_transition_width_cm)
    type(b110_default_mvg_parameters_t), intent(out) :: parameters
    real(real64), intent(in) :: cofgen_input(:,:)
    logical, intent(in), optional :: enable_ksatexm_extension
    logical, intent(in), optional :: enable_elastic_storage
    real(real64), intent(in), optional :: specific_elastic_storage_input(:)
    real(real64), intent(in), optional :: near_saturation_transition_width_cm
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
    parameters%near_saturation_transition_width_cm = 0.0_real64
    if (present(near_saturation_transition_width_cm)) &
         parameters%near_saturation_transition_width_cm = near_saturation_transition_width_cm
    if (.not. ieee_is_finite(parameters%near_saturation_transition_width_cm) .or. &
        parameters%near_saturation_transition_width_cm < 0.0_real64) &
         error stop 'B1.10 default MvG provider: invalid near-saturation transition width'
    if (parameters%near_saturation_transition_width_cm > 0.0_real64 .and. &
        (parameters%ksatexm_extension_enabled .or. parameters%elastic_storage_active)) &
         error stop 'B1.10 default MvG provider: near-saturation transition is not qualified with KSATEXM or elastic storage'
    if (parameters%elastic_storage_active .and. parameters%ksatexm_extension_enabled) &
         error stop 'B1.10 default MvG provider: elastic storage with KSATEXM is not qualified'
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
       if (parameters%near_saturation_transition_width_cm > 0.0_real64 .and. &
           parameters%cofgen(9,i) <= B110_H_CRIT) &
            error stop 'B1.10 default MvG provider: near-saturation transition requires dynamic MvG retention at every node'
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

    theta = b110_watcon(parameters%cofgen(:,node_index), pressure_head, &
         parameters%near_saturation_transition_width_cm)
    if (.not. ieee_is_finite(theta)) return
    conductivity = b110_hconduc(parameters%cofgen(:,node_index), pressure_head, theta, &
         parameters%ksatexm_extension_enabled, parameters%near_saturation_transition_width_cm)
    if (.not. ieee_is_finite(conductivity) .or. conductivity < 0.0_real64) then
       conductivity = 0.0_real64
       return
    end if
    ok = .true.
  end subroutine evaluate_b110_default_mvg_conductivity

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
         self%parameters%ksatexm_extension_enabled, self%parameters%near_saturation_transition_width_cm)
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
          water_content(i) = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i), &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               water_content(i) = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
       end do
       return
    case (CONSTITUTIVE_DEMAND_CAPACITY)
       do i = 1, n
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration, &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               capacity(i) = self%parameters%specific_elastic_storage(i)
       end do
       return
    case (CONSTITUTIVE_DEMAND_WATER_CONTENT + CONSTITUTIVE_DEMAND_CONDUCTIVITY)
       do i = 1, n
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i), &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          water_content(i) = theta_local
          conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled, self%parameters%near_saturation_transition_width_cm)
       end do
       return
    case (CONSTITUTIVE_DEMAND_CONDUCTIVITY + CONSTITUTIVE_DEMAND_CAPACITY)
       do i = 1, n
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i), &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled, self%parameters%near_saturation_transition_width_cm)
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration, &
               self%parameters%near_saturation_transition_width_cm)
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
       if (need_theta .or. need_k .or. need_dkdh) then
          theta_local = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i), &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               theta_local = self%parameters%cofgen(2,i) + &
                    pressure_head(i)*self%parameters%specific_elastic_storage(i)
          if (need_theta) water_content(i) = theta_local
          if (need_k) conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), theta_local, &
               self%parameters%ksatexm_extension_enabled, self%parameters%near_saturation_transition_width_cm)
       end if
       if (need_capacity) then
          capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration, &
               self%parameters%near_saturation_transition_width_cm)
          if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) &
               capacity(i) = self%parameters%specific_elastic_storage(i)
       end if
       if (need_dkdh) dconductivity_dhead(i) = b110_moiscap_dkdh(self%parameters%cofgen(:,i), pressure_head(i), &
            theta_local, self%step_duration, self%parameters%near_saturation_transition_width_cm)
    end do
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
       water_content(i) = b110_watcon(self%parameters%cofgen(:,i), pressure_head(i), &
            self%parameters%near_saturation_transition_width_cm)
       capacity(i) = b110_moiscap(self%parameters%cofgen(:,i), pressure_head(i), self%step_duration, &
            self%parameters%near_saturation_transition_width_cm)
       if (self%parameters%elastic_storage_active .and. pressure_head(i) >= 0.0_real64) then
          water_content(i) = self%parameters%cofgen(2,i) + &
               pressure_head(i)*self%parameters%specific_elastic_storage(i)
          capacity(i) = self%parameters%specific_elastic_storage(i)
       end if
       conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), water_content(i), &
            self%parameters%ksatexm_extension_enabled, self%parameters%near_saturation_transition_width_cm)
       dconductivity_dhead(i) = b110_moiscap_dkdh(self%parameters%cofgen(:,i), pressure_head(i), &
            water_content(i), self%step_duration, self%parameters%near_saturation_transition_width_cm)
    end do
  end subroutine b110_default_mvg_evaluate

  pure real(real64) function b110_watcon(c, head, transition_width_cm) result(watcon)
    real(real64), intent(in) :: c(:), head
    real(real64), intent(in), optional :: transition_width_cm
    real(real64) :: help, h105, alfa, width, s, w, theta_mvg
    alfa = c(4)
    width = 0.0_real64
    if (present(transition_width_cm)) width = transition_width_cm
    if (width > 0.0_real64 .and. c(9) > B110_H_CRIT .and. head >= -width .and. head < 0.0_real64) then
       s = (head+width)/width
       w = s**3*(10.0_real64+s*(-15.0_real64+6.0_real64*s))
       theta_mvg = c(1)+c(25)/(1.0_real64+abs(alfa*head)**c(6))**c(7)
       watcon = min((1.0_real64-w)*theta_mvg+w*c(2),c(2))
       return
    end if
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

  pure real(real64) function b110_moiscap(c, head, step_duration, transition_width_cm) result(capacity)
    real(real64), intent(in) :: c(:), head, step_duration
    real(real64), intent(in), optional :: transition_width_cm
    real(real64) :: alphah, h105, term1, term2, width, s, w, dw, theta_mvg, dtheta_mvg
    width = 0.0_real64
    if (present(transition_width_cm)) width = transition_width_cm
    if (width > 0.0_real64 .and. c(9) > B110_H_CRIT .and. head >= -width .and. head < 0.0_real64) then
       s = (head+width)/width
       w = s**3*(10.0_real64+s*(-15.0_real64+6.0_real64*s))
       dw = 30.0_real64*s**2*(1.0_real64-s)**2/width
       theta_mvg = c(1)+c(25)/(1.0_real64+abs(c(4)*head)**c(6))**c(7)
       dtheta_mvg = c(25)*c(6)*c(7)*c(4)**c(6)*abs(head)**(c(6)-1.0_real64) / &
            (1.0_real64+abs(c(4)*head)**c(6))**(c(7)+1.0_real64)
       capacity = (1.0_real64-w)*dtheta_mvg+dw*(c(2)-theta_mvg)
       return
    end if
    if (width > 0.0_real64 .and. c(9) > B110_H_CRIT .and. head >= 0.0_real64) then
       ! In the opt-in law theta is exactly saturated and constant above h=0.
       ! Its constitutive derivative is therefore zero; do not retain the
       ! legacy timestep-dependent capacity floor in this alternative law.
       capacity = 0.0_real64
       return
    end if
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

  pure real(real64) function b110_hconduc(c, head, theta, enable_ksatexm_extension, transition_width_cm) result(hconduc)
    real(real64), intent(in) :: c(:), head, theta
    logical, intent(in) :: enable_ksatexm_extension
    real(real64), intent(in), optional :: transition_width_cm
    real(real64) :: relsat, term1, term2, se, width, s, w
    logical :: ksatexm_applied
    relsat = (theta-c(1))/c(25)
    ksatexm_applied = .false.
    width = 0.0_real64
    if (present(transition_width_cm)) width = transition_width_cm
    if (width > 0.0_real64 .and. c(9) > B110_H_CRIT .and. head >= -width .and. head < 0.0_real64) then
       s = (head+width)/width
       w = s**3*(10.0_real64+s*(-15.0_real64+6.0_real64*s))
       se = max(0.0_real64,min(1.0_real64,relsat))
       term1 = (1.0_real64-se**c(32))**c(7)
       term2 = c(3)*se**c(5)*(1.0_real64-term1)**2
       hconduc = min(c(3),(1.0_real64-w)*term2+w*c(3))
       return
    end if
    if (enable_ksatexm_extension .and. c(10) > c(3) .and. relsat > c(11)) then
       term1 = (relsat-c(11))/(1.0_real64-c(11))
       hconduc = term1*c(10) + (1.0_real64-term1)*c(12)
       ksatexm_applied = .true.
    else if (c(9) > B110_H_CRIT) then
       if (head < -1.0e14_real64) then
          hconduc = B110_HCON_VSMALL
       else if (relsat > (1.0_real64-1.0e-6_real64)) then
          hconduc = c(3)
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

  pure real(real64) function b110_moiscap_dkdh(c, head, theta, step_duration, transition_width_cm) result(dkdh)
    real(real64), intent(in) :: c(:), head, theta, step_duration, transition_width_cm
    real(real64) :: s, w, dw, se, se_power, term, term_slope, k_mvg, dk_mvg_dse, capacity
    dkdh = 0.0_real64
    if (transition_width_cm <= 0.0_real64 .or. head >= 0.0_real64 .or. c(9) <= B110_H_CRIT) return
    w = 0.0_real64
    dw = 0.0_real64
    if (head >= -transition_width_cm) then
       s = (head+transition_width_cm)/transition_width_cm
       w = s**3*(10.0_real64+s*(-15.0_real64+6.0_real64*s))
       dw = 30.0_real64*s**2*(1.0_real64-s)**2/transition_width_cm
    end if
    se = max(0.0_real64,min(1.0_real64,(theta-c(1))/c(25)))
    if (se <= 0.0_real64 .or. se >= 1.0_real64) return
    se_power = se**c(32)
    term = (1.0_real64-se_power)**c(7)
    k_mvg = c(3)*se**c(5)*(1.0_real64-term)**2
    term_slope = c(7)*c(32)*se**(c(32)-1.0_real64)*(1.0_real64-se_power)**(c(7)-1.0_real64)
    dk_mvg_dse = c(3)*(c(5)*se**(c(5)-1.0_real64)*(1.0_real64-term)**2 + &
         2.0_real64*se**c(5)*(1.0_real64-term)*term_slope)
    capacity = b110_moiscap(c,head,step_duration,transition_width_cm)
    dkdh = (1.0_real64-w)*dk_mvg_dse*capacity/c(25)+dw*(c(3)-k_mvg)
  end function b110_moiscap_dkdh

end module mod_b110_default_mvg_provider
