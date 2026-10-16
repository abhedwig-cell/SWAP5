module mod_root_frost_stress
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  implicit none
  private

  integer, parameter, public :: ROOT_FROST_OK=0, ROOT_FROST_INVALID=1
  type, public :: root_frost_config_t
    logical :: active=.false.
    integer :: rooted_nodes=0
  end type
  public :: compose_legacy_zero_root_frost

contains
  subroutine compose_legacy_zero_root_frost(config,temperature_c,base,final,factors,loss,status)
    type(root_frost_config_t),intent(in)::config
    real(real64),intent(in)::temperature_c(:)
    type(root_water_uptake_flux_result_t),intent(in)::base
    type(root_water_uptake_flux_result_t),intent(out)::final
    real(real64),allocatable,intent(out)::factors(:)
    real(real64),intent(out)::loss
    integer,intent(out)::status
    integer::n,i
    final=root_water_uptake_flux_result_t();loss=0.0_real64;status=ROOT_FROST_INVALID
    if(.not.config%active) then
      final=base;status=ROOT_FROST_OK
      return
    end if
    if(.not.allocated(base%root_extraction_sink)) return
    n=size(base%root_extraction_sink)
    if(n==0.or.size(temperature_c)/=n) return
    if(config%rooted_nodes<0.or.config%rooted_nodes>n) return
    if(any(.not.ieee_is_finite(temperature_c))) return
    if(any(.not.ieee_is_finite(base%root_extraction_sink))) return
    if(any(base%root_extraction_sink<0.0_real64)) return
    if(.not.ieee_is_finite(base%actual_uptake_total)) return
    if(abs(sum(base%root_extraction_sink)-base%actual_uptake_total)> &
         256.0_real64*epsilon(1.0_real64)*max(1.0_real64,base%actual_uptake_total)) return
    if(any(base%root_extraction_sink(config%rooted_nodes+1:)/=0.0_real64)) return
    allocate(factors(n));factors=1.0_real64
    ! Explicit empirical B1.11 macro-root rule. No hydraulic rfcp, ice state,
    ! latent heat or inferred plant temperature threshold enters this law.
    do i=1,config%rooted_nodes
      if(temperature_c(i)<0.0_real64) factors(i)=0.0_real64
    end do
    final=base
    final%root_extraction_sink=base%root_extraction_sink*factors
    final%actual_uptake_total=sum(final%root_extraction_sink)
    loss=sum(base%root_extraction_sink-final%root_extraction_sink)
    status=ROOT_FROST_OK
  end subroutine
end module
