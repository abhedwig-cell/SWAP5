module mod_b110_default_mvg_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  real(real64), parameter :: B110_H_CRIT = -1.0e-2_real64
  real(real64), parameter :: B110_HCON_VSMALL = 1.0e-10_real64
  integer, parameter :: B110_MCOF_REQUIRED = 42

  type, public :: b110_default_mvg_parameters_t
     integer :: active_nodes = 0
     real(real64), allocatable :: cofgen(:,:)
  end type b110_default_mvg_parameters_t

  type, extends(constitutive_hydraulics_provider_t), public :: b110_default_mvg_provider_t
     type(b110_default_mvg_parameters_t), pointer :: parameters => null()
     real(real64) :: step_duration = 0.0_real64
   contains
     procedure :: evaluate => b110_default_mvg_evaluate
  end type b110_default_mvg_provider_t

  public :: initialize_b110_default_mvg_parameters
  public :: bind_b110_default_mvg_provider

contains

  subroutine initialize_b110_default_mvg_parameters(parameters, cofgen_input)
    type(b110_default_mvg_parameters_t), intent(out) :: parameters
    real(real64), intent(in) :: cofgen_input(:,:)
    integer :: i, n
    real(real64) :: h105, t105, c105, a, b, alfa

    if (size(cofgen_input,1) < 24) error stop 'B1.10 default MvG provider: at least 24 cofgen rows required'
    n = size(cofgen_input,2)
    if (n <= 0) error stop 'B1.10 default MvG provider: active_nodes must be positive'
    parameters%active_nodes = n
    allocate(parameters%cofgen(B110_MCOF_REQUIRED,n))
    parameters%cofgen = 0.0_real64
    parameters%cofgen(1:min(size(cofgen_input,1),B110_MCOF_REQUIRED),:) = &
         cofgen_input(1:min(size(cofgen_input,1),B110_MCOF_REQUIRED),:)

    do i = 1, n
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
       conductivity(i) = b110_hconduc(self%parameters%cofgen(:,i), pressure_head(i), water_content(i))
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

  pure real(real64) function b110_hconduc(c, head, theta) result(hconduc)
    real(real64), intent(in) :: c(:), head, theta
    real(real64) :: relsat, term1, term2, se
    relsat = (theta-c(1))/c(25)
    if (c(9) > B110_H_CRIT) then
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
    hconduc = min(hconduc,c(3))
  end function b110_hconduc

end module mod_b110_default_mvg_provider
