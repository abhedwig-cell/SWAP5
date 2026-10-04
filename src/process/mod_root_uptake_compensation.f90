module mod_root_uptake_compensation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  implicit none
  private

  integer, parameter, public :: ROOT_COMP_OK=0, ROOT_COMP_INVALID=1, ROOT_COMP_UNSUPPORTED=2
  integer, parameter, public :: ROOT_COMP_OFF=0, ROOT_COMP_JARVIS=1
  integer, parameter, public :: ROOT_COMP_ALL=1, ROOT_COMP_DROUGHT=2, ROOT_COMP_OXYGEN=3

  type, public :: root_compensation_config_t
    integer :: method=ROOT_COMP_OFF
    integer :: stressor=ROOT_COMP_ALL
    real(real64) :: alpha_critical=1.0_real64
  end type

  type, public :: root_compensation_diagnostics_t
    logical :: applied=.false.
    real(real64) :: uncompensated_uptake=0.0_real64
    real(real64) :: compensated_uptake=0.0_real64
    real(real64) :: drought_reduction_total=0.0_real64
    real(real64) :: oxygen_reduction_total=0.0_real64
  end type

  public :: compose_jarvis_root_uptake, attribute_root_stress_losses

contains
  subroutine attribute_root_stress_losses(potential,drought_sink,oxygen_factor,drought_loss,oxygen_loss,status)
    real(real64),intent(in)::potential(:),drought_sink(:),oxygen_factor(:)
    real(real64),intent(out)::drought_loss,oxygen_loss
    integer,intent(out)::status
    integer::i
    real(real64)::dry,wet,loss,weight
    drought_loss=0.0_real64;oxygen_loss=0.0_real64;status=ROOT_COMP_INVALID
    if(size(potential)/=size(drought_sink).or.size(potential)/=size(oxygen_factor)) return
    if(any(.not.ieee_is_finite(potential)).or.any(.not.ieee_is_finite(drought_sink)).or. &
       any(.not.ieee_is_finite(oxygen_factor))) return
    if(any(potential<0.0_real64).or.any(drought_sink<0.0_real64).or.any(drought_sink>potential).or. &
       any(oxygen_factor<0.0_real64).or.any(oxygen_factor>1.0_real64)) return
    do i=1,size(potential)
      if(potential(i)<=0.0_real64) cycle
      dry=drought_sink(i)/potential(i);wet=oxygen_factor(i)
      loss=potential(i)-drought_sink(i)*wet
      if(loss<1.0e-14_real64) cycle
      weight=(1.0_real64-dry)+(1.0_real64-wet)
      if(weight<=0.0_real64) return
      drought_loss=drought_loss+(1.0_real64-dry)/weight*loss
      oxygen_loss=oxygen_loss+(1.0_real64-wet)/weight*loss
    end do
    status=ROOT_COMP_OK
  end subroutine

  subroutine compose_jarvis_root_uptake(config,ptra,base_fluxes,drought_reduction,oxygen_reduction,final_fluxes,diag,status)
    type(root_compensation_config_t),intent(in)::config
    real(real64),intent(in)::ptra,drought_reduction,oxygen_reduction
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    type(root_compensation_diagnostics_t),intent(out)::diag
    integer,intent(out)::status
    real(real64),parameter::vsmall=1.0e-14_real64
    integer::largest
    real(real64)::alptot,qred,alpdry,alpwet,alpdrycom,alpwetcom,alptotcom,redtot,reduction_tolerance

    final_fluxes=root_water_uptake_flux_result_t()
    diag=root_compensation_diagnostics_t()
    status=ROOT_COMP_OK

    if(config%method==ROOT_COMP_OFF) then
      final_fluxes=base_fluxes
      if(allocated(base_fluxes%root_extraction_sink)) then
        diag%uncompensated_uptake=sum(base_fluxes%root_extraction_sink)
        diag%compensated_uptake=diag%uncompensated_uptake
      end if
      diag%drought_reduction_total=drought_reduction
      diag%oxygen_reduction_total=oxygen_reduction
      return
    end if
    if(config%method/=ROOT_COMP_JARVIS) then
      status=ROOT_COMP_UNSUPPORTED;return
    end if
    if(config%stressor<ROOT_COMP_ALL .or. config%stressor>ROOT_COMP_OXYGEN) then
      status=ROOT_COMP_UNSUPPORTED;return
    end if
    ! Fortran does not guarantee short-circuit evaluation of logical operands.
    ! Reject absent storage before inspecting any array element.
    if(.not.allocated(base_fluxes%root_extraction_sink)) then
      status=ROOT_COMP_INVALID;return
    end if
    if(.not.ieee_is_finite(ptra) .or. ptra<0.0_real64 .or. &
       .not.ieee_is_finite(config%alpha_critical) .or. config%alpha_critical<=0.0_real64 .or. config%alpha_critical>1.0_real64 .or. &
       .not.ieee_is_finite(drought_reduction) .or. drought_reduction<0.0_real64 .or. &
       .not.ieee_is_finite(oxygen_reduction) .or. oxygen_reduction<0.0_real64 .or. &
       any(.not.ieee_is_finite(base_fluxes%root_extraction_sink)) .or. any(base_fluxes%root_extraction_sink<0.0_real64)) then
      status=ROOT_COMP_INVALID;return
    end if

    if(.not.ieee_is_finite(base_fluxes%actual_uptake_total)) then
      status=ROOT_COMP_INVALID;return
    end if
    final_fluxes=base_fluxes
    diag%uncompensated_uptake=sum(base_fluxes%root_extraction_sink)
    if(abs(base_fluxes%actual_uptake_total-diag%uncompensated_uptake)> &
         256.0_real64*epsilon(1.0_real64)*max(1.0_real64,diag%uncompensated_uptake)) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_INVALID;return
    end if
    final_fluxes%actual_uptake_total=diag%uncompensated_uptake
    if(ptra<=0.0_real64.and.diag%uncompensated_uptake>0.0_real64) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_INVALID;return
    end if
    diag%compensated_uptake=diag%uncompensated_uptake
    diag%drought_reduction_total=drought_reduction
    diag%oxygen_reduction_total=oxygen_reduction
    if(diag%uncompensated_uptake>ptra+256.0_real64*epsilon(1.0_real64)*max(1.0_real64,ptra)) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_INVALID;return
    end if
    if(ptra<=vsmall) return

    alptot=diag%uncompensated_uptake/ptra
    qred=ptra-diag%uncompensated_uptake
    if(abs(config%alpha_critical-1.0_real64)<vsmall .or. qred<=vsmall .or. alptot<0.05_real64) return

    ! D2 admits only drought and bounded oxygen. Their attributed losses must
    ! therefore close the full pre-compensation reduction. A mismatch implies
    ! an unadmitted/missing stressor and fails closed rather than silently
    ! changing the legacy exponent shares.
    reduction_tolerance=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,ptra,qred)
    if(abs((drought_reduction+oxygen_reduction)-qred)>reduction_tolerance) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_UNSUPPORTED;return
    end if

    alpdry=alptot**(drought_reduction/qred)
    alpwet=alptot**(oxygen_reduction/qred)
    alpdrycom=alpdry;alpwetcom=alpwet
    select case(config%stressor)
    case(ROOT_COMP_ALL)
      alptotcom=min(alptot/config%alpha_critical,1.0_real64)
    case(ROOT_COMP_DROUGHT)
      alpdrycom=min(alpdry/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom
    case(ROOT_COMP_OXYGEN)
      alpwetcom=min(alpwet/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom
    end select

    final_fluxes%root_extraction_sink=base_fluxes%root_extraction_sink*(alptotcom/alptot)
    ! Uniform floating-point scaling can overshoot PTRA by one ulp.
    ! Correct the largest sink downward rather than weakening the mass bound.
    do while(sum(final_fluxes%root_extraction_sink)>ptra)
      largest=maxloc(final_fluxes%root_extraction_sink,dim=1)
      final_fluxes%root_extraction_sink(largest)=nearest(final_fluxes%root_extraction_sink(largest),-1.0_real64)
    end do
    final_fluxes%actual_uptake_total=sum(final_fluxes%root_extraction_sink)
    diag%compensated_uptake=final_fluxes%actual_uptake_total
    diag%applied=.true.
    qred=ptra-final_fluxes%actual_uptake_total
    if(qred<vsmall) then
      diag%drought_reduction_total=0.0_real64;diag%oxygen_reduction_total=0.0_real64
    else
      redtot=(1.0_real64-alpdrycom)+(1.0_real64-alpwetcom)
      if(redtot<=vsmall) then
        diag%drought_reduction_total=0.0_real64;diag%oxygen_reduction_total=0.0_real64
      else
        diag%drought_reduction_total=(1.0_real64-alpdrycom)/redtot*qred
        diag%oxygen_reduction_total=(1.0_real64-alpwetcom)/redtot*qred
      end if
    end if
  end subroutine
end module
