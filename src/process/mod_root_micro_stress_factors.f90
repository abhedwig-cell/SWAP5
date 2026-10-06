module mod_root_micro_stress_factors
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer, parameter, public :: MICRO_STRESS_OK=0, MICRO_STRESS_INVALID=1
  type, public :: micro_stress_parameters_t
    integer :: oxygen_mode=0, salinity_mode=0, combination_mode=1, upper_compartment_last_node=0
    real(real64) :: wet_limit_cm=0.0_real64, upper_oxygen_limit_cm=0.0_real64
    real(real64) :: lower_oxygen_limit_cm=0.0_real64, salt_threshold=0.0_real64
    real(real64) :: salt_slope=0.0_real64
  end type
  public :: evaluate_micro_stress_factors
contains
  ! Literal B1.11 rootextraction_micro Feddes/Maas-Hoffman and swAlpTot 1/2/3
  ! factor construction. This pure slice does not activate a MICRO runtime
  ! option, and mode 3's zero-skipping scalar is source fidelity, not policy.
  subroutine evaluate_micro_stress_factors(parameters, head_cm, concentration, rooted_nodes, factors, status)
    type(micro_stress_parameters_t), intent(in) :: parameters
    real(real64), intent(in) :: head_cm(:), concentration(:)
    integer, intent(in) :: rooted_nodes
    real(real64), allocatable, intent(out) :: factors(:)
    integer, intent(out) :: status
    real(real64), allocatable :: wet(:), salt(:)
    real(real64) :: oxygen_limit, scalar
    integer :: node, n

    status=MICRO_STRESS_INVALID
    n=size(head_cm)
    if(n<=0.or.size(concentration)/=n.or.rooted_nodes<0.or.rooted_nodes>n) return
    if(parameters%oxygen_mode<0.or.parameters%oxygen_mode>1) return
    if(parameters%salinity_mode<0.or.parameters%salinity_mode>1) return
    if(parameters%combination_mode<1.or.parameters%combination_mode>3) return
    if(parameters%upper_compartment_last_node<0.or.parameters%upper_compartment_last_node>n) return
    if(any(.not.ieee_is_finite(head_cm)).or.any(.not.ieee_is_finite(concentration))) return
    if(any(concentration<0.0_real64)) return
    if(.not.ieee_is_finite(parameters%wet_limit_cm).or. &
       .not.ieee_is_finite(parameters%upper_oxygen_limit_cm).or. &
       .not.ieee_is_finite(parameters%lower_oxygen_limit_cm).or. &
       .not.ieee_is_finite(parameters%salt_threshold).or. &
       .not.ieee_is_finite(parameters%salt_slope)) return
    if(parameters%salt_threshold<0.0_real64.or.parameters%salt_slope<0.0_real64) return
    if(parameters%oxygen_mode==1) then
      if(parameters%wet_limit_cm<=parameters%upper_oxygen_limit_cm.or. &
         parameters%wet_limit_cm<=parameters%lower_oxygen_limit_cm) return
    end if
    allocate(wet(rooted_nodes),salt(rooted_nodes),factors(n))
    factors=1.0_real64
    wet=1.0_real64
    salt=1.0_real64
    do node=1,rooted_nodes
      if(parameters%oxygen_mode==1) then
        oxygen_limit=parameters%upper_oxygen_limit_cm
        if(node>parameters%upper_compartment_last_node) oxygen_limit=parameters%lower_oxygen_limit_cm
        if(head_cm(node)<=parameters%wet_limit_cm.and.head_cm(node)>oxygen_limit) &
          wet(node)=(parameters%wet_limit_cm-head_cm(node))/(parameters%wet_limit_cm-oxygen_limit)
        if(head_cm(node)>parameters%wet_limit_cm) wet(node)=0.0_real64
      end if
      if(parameters%salinity_mode==1.and.concentration(node)>parameters%salt_threshold) &
        salt(node)=max(0.0_real64,1.0_real64- &
          (concentration(node)-parameters%salt_threshold)*parameters%salt_slope)
    end do
    select case(parameters%combination_mode)
    case(1,3)
      factors(1:rooted_nodes)=wet*salt
      if(parameters%combination_mode==3) then
        scalar=1.0_real64
        do node=1,rooted_nodes
          if(factors(node)>0.0_real64) scalar=scalar*factors(node)
        end do
        factors(1:rooted_nodes)=scalar
      end if
    case(2)
      factors(1:rooted_nodes)=min(wet,salt)
    end select
    if(any(.not.ieee_is_finite(factors))) then
      deallocate(factors)
      return
    end if
    status=MICRO_STRESS_OK
  end subroutine
end module
