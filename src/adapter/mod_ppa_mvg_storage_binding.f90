! Candidate-only binding. Never silently replaces inconsistent committed water.
module mod_ppa_mvg_storage_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t
  use mod_soil_water_solver_contract, only: constitutive_hydraulics_provider_t
  use mod_ppa_mvg_storage_difference, only: local_mvg_storage_difference
  implicit none
  private
  public :: evaluate_bound_mvg_storage_difference
  public :: evaluate_mvg_storage_difference_service
contains
  subroutine evaluate_mvg_storage_difference_service(provider,before,water_before,after,difference,available)
    class(constitutive_hydraulics_provider_t),intent(in)::provider
    real(real64),intent(in)::before(:),water_before(:),after(:)
    real(real64),intent(out)::difference(:)
    logical,intent(out)::available
    difference=0.0_real64
    available=.false.
    select type(provider)
    type is(b110_default_mvg_provider_t)
      call evaluate_bound_mvg_storage_difference(provider,before,water_before,after,difference,available)
    end select
  end subroutine

  subroutine evaluate_bound_mvg_storage_difference(provider,before,water_before,after,difference,available)
    type(b110_default_mvg_provider_t),intent(in)::provider
    real(real64),intent(in)::before(:),water_before(:),after(:)
    real(real64),intent(out)::difference(:)
    logical,intent(out)::available
    real(real64),allocatable::trial(:)
    real(real64)::expected,denominator
    integer::n,i
    logical::ok
    difference=0.0_real64
    available=.false.
    if(.not.associated(provider%parameters))return
    if(provider%parameters%ksatexm_extension_enabled)return
    n=provider%parameters%active_nodes
    if(n<=0)return
    if(size(before)/=n.or.size(after)/=n.or.size(water_before)/=n.or.size(difference)/=n)return
    if(.not.allocated(provider%parameters%cofgen))return
    if(size(provider%parameters%cofgen,1)<25.or.size(provider%parameters%cofgen,2)/=n)return
    if(.not.all(ieee_is_finite(provider%parameters%cofgen)))return
    if(.not.all(ieee_is_finite(water_before)))return
    allocate(trial(n))
    do i=1,n
      associate(c=>provider%parameters%cofgen(:,i))
        if(c(9)<=-0.01_real64)return
        if(c(1)<0.0_real64.or.c(1)>1.0_real64)return
        if(c(25)<=0.0_real64.or.c(25)>1.0_real64-c(1))return
        call local_mvg_storage_difference(c(25),c(4),c(6),c(7),before(i),after(i),trial(i),ok)
        if(.not.ok)return
        ! Match reference watcon grouping, including its rounded base value.
        denominator=(1.0_real64+abs(c(4)*before(i))**c(6))**c(7)
        expected=c(1)+c(25)/denominator
        if(water_before(i)/=expected)return
      end associate
    end do
    difference=trial
    available=.true.
  end subroutine
end module
