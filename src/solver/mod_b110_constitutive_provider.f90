module mod_b110_constitutive_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  implicit none
  private

  real(real64), parameter :: H_CRIT = -1.0e-2_real64
  real(real64), parameter :: HCONODE_VSMALL = 1.0e-10_real64

  type, public :: b110_constitutive_parameters_t
     integer :: active_nodes = 0
     integer, allocatable :: model(:)
     real(real64), allocatable :: wcr(:), wcs(:), wcs_min_wcr(:)
     real(real64), allocatable :: alpha(:), npar(:), mpar(:), ksat(:), lambda(:)
     real(real64), allocatable :: alpha2(:), npar2(:), mpar2(:), omega1(:)
     real(real64), allocatable :: alfanm(:), nmin1(:), mplus1(:), one_over_m(:)
     real(real64), allocatable :: alfanm2(:), nmin1_2(:), mplus1_2(:), one_over_m2(:)
     real(real64), allocatable :: h_enpr(:), wc_crit(:), c_crit(:), s_enpr(:)
     real(real64), allocatable :: term_105_a(:), term_105_ab(:)
  end type b110_constitutive_parameters_t

  type, public :: b110_constitutive_conditions_t
     real(real64) :: step_duration = 0.0_real64
     integer :: conductivity_implicit_mode = 0
     logical :: hysteresis_active = .false.
     logical :: frost_active = .false.
     logical :: macropore_active = .false.
     logical :: tabulated_input = .false.
     logical :: conductivity_power_tail = .false.
     logical :: saturated_extrapolation = .false.
     logical :: elasticity_active = .false.
  end type b110_constitutive_conditions_t

  type, extends(constitutive_hydraulics_provider_t), public :: b110_constitutive_provider_t
     type(b110_constitutive_parameters_t), pointer :: parameters => null()
     type(b110_constitutive_conditions_t), pointer :: conditions => null()
     logical :: admitted = .false.
   contains
     procedure :: evaluate => b110_evaluate
  end type b110_constitutive_provider_t

  public :: bind_b110_constitutive_provider
  public :: validate_b110_constitutive_profile

contains

  subroutine bind_b110_constitutive_provider(provider, parameters, conditions, ok)
    type(b110_constitutive_provider_t), intent(out) :: provider
    type(b110_constitutive_parameters_t), target, intent(in) :: parameters
    type(b110_constitutive_conditions_t), target, intent(in) :: conditions
    logical, intent(out) :: ok

    call validate_b110_constitutive_profile(parameters, conditions, ok)
    if (.not. ok) return
    provider%parameters => parameters
    provider%conditions => conditions
    provider%admitted = .true.
  end subroutine bind_b110_constitutive_provider

  subroutine validate_b110_constitutive_profile(parameters, conditions, ok)
    type(b110_constitutive_parameters_t), intent(in) :: parameters
    type(b110_constitutive_conditions_t), intent(in) :: conditions
    logical, intent(out) :: ok
    integer :: n

    ok = .false.
    n = parameters%active_nodes
    if (n <= 0) return
    if (conditions%step_duration <= 0.0_real64) return
    if (conditions%conductivity_implicit_mode /= 0) return
    if (conditions%hysteresis_active .or. conditions%frost_active .or. conditions%macropore_active) return
    if (conditions%tabulated_input .or. conditions%conductivity_power_tail) return
    if (conditions%saturated_extrapolation .or. conditions%elasticity_active) return
    if (.not. allocated(parameters%model)) return
    if (size(parameters%model) /= n) return
    if (any(parameters%model < 1) .or. any(parameters%model > 3)) return
    if (.not. all_real_arrays_valid(parameters, n)) return
    if (any(parameters%wcs <= parameters%wcr)) return
    if (any(parameters%wcs_min_wcr <= 0.0_real64)) return
    if (any(parameters%ksat <= 0.0_real64)) return
    if (any(parameters%mpar <= 0.0_real64) .or. any(parameters%npar <= 0.0_real64)) return
    ok = .true.
  end subroutine validate_b110_constitutive_profile

  logical function all_real_arrays_valid(p, n) result(ok)
    type(b110_constitutive_parameters_t), intent(in) :: p
    integer, intent(in) :: n
    ok = allocated(p%wcr) .and. allocated(p%wcs) .and. allocated(p%wcs_min_wcr) .and. &
         allocated(p%alpha) .and. allocated(p%npar) .and. allocated(p%mpar) .and. &
         allocated(p%ksat) .and. allocated(p%lambda) .and. allocated(p%alpha2) .and. &
         allocated(p%npar2) .and. allocated(p%mpar2) .and. allocated(p%omega1) .and. &
         allocated(p%alfanm) .and. allocated(p%nmin1) .and. allocated(p%mplus1) .and. &
         allocated(p%one_over_m) .and. allocated(p%alfanm2) .and. allocated(p%nmin1_2) .and. &
         allocated(p%mplus1_2) .and. allocated(p%one_over_m2) .and. allocated(p%h_enpr) .and. &
         allocated(p%wc_crit) .and. allocated(p%c_crit) .and. allocated(p%s_enpr) .and. &
         allocated(p%term_105_a) .and. allocated(p%term_105_ab)
    if (.not. ok) return
    ok = size(p%wcr)==n .and. size(p%wcs)==n .and. size(p%wcs_min_wcr)==n .and. &
         size(p%alpha)==n .and. size(p%npar)==n .and. size(p%mpar)==n .and. &
         size(p%ksat)==n .and. size(p%lambda)==n .and. size(p%alpha2)==n .and. &
         size(p%npar2)==n .and. size(p%mpar2)==n .and. size(p%omega1)==n .and. &
         size(p%alfanm)==n .and. size(p%nmin1)==n .and. size(p%mplus1)==n .and. &
         size(p%one_over_m)==n .and. size(p%alfanm2)==n .and. size(p%nmin1_2)==n .and. &
         size(p%mplus1_2)==n .and. size(p%one_over_m2)==n .and. size(p%h_enpr)==n .and. &
         size(p%wc_crit)==n .and. size(p%c_crit)==n .and. size(p%s_enpr)==n .and. &
         size(p%term_105_a)==n .and. size(p%term_105_ab)==n
  end function all_real_arrays_valid

  subroutine b110_evaluate(self, pressure_head, water_content, conductivity, capacity, dconductivity_dhead)
    class(b110_constitutive_provider_t), intent(in) :: self
    real(real64), intent(in) :: pressure_head(:)
    real(real64), intent(out) :: water_content(:), conductivity(:), capacity(:), dconductivity_dhead(:)
    integer :: i, n

    if (.not. self%admitted .or. .not. associated(self%parameters) .or. .not. associated(self%conditions)) &
       error stop 'F-SI09 B1.10 constitutive provider is not admitted/bound'
    n = self%parameters%active_nodes
    if (size(pressure_head)/=n .or. size(water_content)/=n .or. size(conductivity)/=n .or. &
        size(capacity)/=n .or. size(dconductivity_dhead)/=n) &
       error stop 'F-SI09 B1.10 constitutive provider shape mismatch'

    do i = 1, n
       select case (self%parameters%model(i))
       case (1)
          call evaluate_model1(self%parameters, self%conditions, i, pressure_head(i), &
               water_content(i), conductivity(i), capacity(i))
       case (2)
          call evaluate_model2(self%parameters, i, pressure_head(i), &
               water_content(i), conductivity(i), capacity(i))
       case (3)
          call evaluate_model3(self%parameters, i, pressure_head(i), &
               water_content(i), conductivity(i), capacity(i))
       case default
          error stop 'F-SI09 unsupported B1.10 constitutive model escaped admission'
       end select
       ! B1.10 dhconduc is deliberately not admitted by this swkimpl=0 provider slice.
       dconductivity_dhead(i) = 0.0_real64
    end do
  end subroutine b110_evaluate

  subroutine evaluate_model2(p, i, head, theta, k, c)
    type(b110_constitutive_parameters_t), intent(in) :: p
    integer, intent(in) :: i
    real(real64), intent(in) :: head
    real(real64), intent(out) :: theta, k, c
    real(real64) :: relsat, expterm

    expterm = exp(p%alpha(i)*head)
    theta = max(1.0000001*p%wcr(i), p%wcr(i) + p%wcs_min_wcr(i)*expterm)
    c = p%alpha(i)*p%wcs_min_wcr(i)*expterm
    relsat = (theta-p%wcr(i))/p%wcs_min_wcr(i)
    k = p%ksat(i)*relsat
  end subroutine evaluate_model2

  subroutine evaluate_model3(p, i, head, theta, k, c)
    type(b110_constitutive_parameters_t), intent(in) :: p
    integer, intent(in) :: i
    real(real64), intent(in) :: head
    real(real64), intent(out) :: theta, k, c
    real(real64) :: s1, s2, term1, term2, relsat

    if (head < 0.0_real64) then
       theta = p%omega1(i)/(1.0_real64+abs(p%alpha(i)*head)**p%npar(i))**p%mpar(i)
       theta = theta + (1.0_real64-p%omega1(i))/(1.0_real64+abs(p%alpha2(i)*head)**p%npar2(i))**p%mpar2(i)
       theta = p%wcr(i) + p%wcs_min_wcr(i)*theta
       c = p%omega1(i)*p%alfanm(i)*abs(p%alpha(i)*head)**p%nmin1(i) * &
           (1.0_real64+abs(p%alpha(i)*head)**p%npar(i))**(-p%mplus1(i))
       c = c + (1.0_real64-p%omega1(i))*p%alfanm2(i)*abs(p%alpha2(i)*head)**p%nmin1_2(i) * &
           (1.0_real64+abs(p%alpha2(i)*head)**p%npar2(i))**(-p%mplus1_2(i))
       c = p%wcs_min_wcr(i)*c
    else
       theta = p%wcs(i)
       c = 0.0_real64
    end if

    relsat = (theta-p%wcr(i))/p%wcs_min_wcr(i)
    if (relsat < 1.0_real64) then
       s1 = (1.0_real64+abs(p%alpha(i)*head)**p%npar(i))**(-p%mpar(i))
       s2 = (1.0_real64+abs(p%alpha2(i)*head)**p%npar2(i))**(-p%mpar2(i))
       term1 = p%omega1(i)*p%alpha(i)*(1.0_real64-s1**p%one_over_m(i))**p%mpar(i)
       term2 = (1.0_real64-p%omega1(i))*p%alpha2(i)*(1.0_real64-s2**p%one_over_m2(i))**p%mpar2(i)
       k = p%ksat(i)*(p%omega1(i)*s1+(1.0_real64-p%omega1(i))*s2)**p%lambda(i)
       k = k*(1.0_real64-(term1+term2)/(p%omega1(i)*p%alpha(i)+(1.0_real64-p%omega1(i))*p%alpha2(i)))**2
    else
       k = p%ksat(i)
    end if
  end subroutine evaluate_model3

  subroutine evaluate_model1(p, cond, i, head, theta, k, c)
    type(b110_constitutive_parameters_t), intent(in) :: p
    type(b110_constitutive_conditions_t), intent(in) :: cond
    integer, intent(in) :: i
    real(real64), intent(in) :: head
    real(real64), intent(out) :: theta, k, c
    real(real64) :: help, h105, alphah, term1, term2, relsat, se

    if (head >= 0.0_real64) then
       theta = p%wcs(i)
    else if (p%h_enpr(i) > H_CRIT) then
       if (head > H_CRIT) then
          theta = min(p%wc_crit(i)+p%c_crit(i)*(head-H_CRIT), p%wcs(i))
       else
          help = abs(p%alpha(i)*head)**p%npar(i)
          help = (1.0_real64+help)**p%mpar(i)
          theta = p%wcr(i)+p%wcs_min_wcr(i)/help
       end if
    else
       h105 = 1.05_real64*p%h_enpr(i)
       if (head >= h105) then
          theta = p%wcs(i)+p%term_105_ab(i)*head/(1.0_real64+p%term_105_a(i)*head)
       else
          help = abs(p%alpha(i)*head)**p%npar(i)
          help = (1.0_real64+help)**p%mpar(i)
          theta = p%wcr(i)+p%wcs_min_wcr(i)/(help*p%s_enpr(i))
       end if
    end if

    if (head >= 0.0_real64) then
       c = cond%step_duration*1.0e-7_real64
    else
       alphah = abs(p%alpha(i)*head)
       if (p%h_enpr(i) > H_CRIT) then
          if (head > H_CRIT) then
             c = p%c_crit(i)
          else
             term1 = alphah**p%nmin1(i)
             term2 = p%wcs_min_wcr(i)/((1.0_real64+term1*alphah)**p%mplus1(i))
             c = p%alfanm(i)*term2*term1
          end if
       else
          h105 = 1.05_real64*p%h_enpr(i)
          if (head >= h105) then
             c = p%term_105_ab(i)/((1.0_real64+p%term_105_a(i)*head)**2)
          else
             term1 = alphah**p%nmin1(i)
             term2 = p%wcs_min_wcr(i)/(1.0_real64+term1*alphah)**p%mplus1(i)
             c = p%alfanm(i)*term2*term1/p%s_enpr(i)
          end if
       end if
       if (head > -1.0_real64 .and. c < cond%step_duration*1.0e-7_real64) c = cond%step_duration*1.0e-7_real64
    end if

    relsat = (theta-p%wcr(i))/p%wcs_min_wcr(i)
    if (p%h_enpr(i) > H_CRIT) then
       if (head < -1.0e14_real64) then
          k = HCONODE_VSMALL
       else if (relsat > 1.0_real64-1.0e-6_real64) then
          k = p%ksat(i)
       else
          term1 = (1.0_real64-relsat**p%one_over_m(i))**p%mpar(i)
          k = p%ksat(i)*(relsat**p%lambda(i))*(1.0_real64-term1)**2
       end if
    else
       if (head < -1.0e14_real64) then
          k = HCONODE_VSMALL
       else if (head >= p%h_enpr(i)) then
          k = p%ksat(i)
       else
          se = (1.0_real64+abs(p%alpha(i)*head)**p%npar(i))**(-p%mpar(i))/p%s_enpr(i)
          term1 = (1.0_real64-(se*p%s_enpr(i))**p%one_over_m(i))**p%mpar(i)
          term2 = (1.0_real64-p%s_enpr(i)**p%one_over_m(i))**p%mpar(i)
          k = p%ksat(i)*se**p%lambda(i)*((1.0_real64-term1)/(1.0_real64-term2))**2
       end if
       k = min(k,p%ksat(i))
    end if
  end subroutine evaluate_model1

end module mod_b110_constitutive_provider
