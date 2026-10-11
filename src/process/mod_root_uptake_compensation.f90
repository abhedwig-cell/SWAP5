module mod_root_uptake_compensation
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  implicit none
  private

  integer, parameter, public :: ROOT_COMP_OK=0, ROOT_COMP_INVALID=1, ROOT_COMP_UNSUPPORTED=2
  integer, parameter, public :: ROOT_COMP_OFF=0, ROOT_COMP_JARVIS=1, ROOT_COMP_WALSUM=2
  integer, parameter, public :: ROOT_COMP_ALL=1, ROOT_COMP_DROUGHT=2, ROOT_COMP_OXYGEN=3, ROOT_COMP_SALINITY=4, ROOT_COMP_FROST=5

  type, public :: root_walsum_geometry_t
    real(real64) :: critical_root_zone_depth_cm=0.0_real64
    real(real64) :: maximum_root_depth_cm=0.0_real64
    real(real64) :: current_root_depth_cm=0.0_real64
  end type

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
    real(real64) :: salinity_reduction_total=0.0_real64
    real(real64) :: frost_reduction_total=0.0_real64
  end type

  public :: compose_jarvis_root_uptake, attribute_root_stress_losses, evaluate_walsum_geometry

contains
  subroutine evaluate_walsum_geometry(geometry,node_thickness_cm,alpha,deepest_node,status)
    type(root_walsum_geometry_t),intent(in)::geometry
    real(real64),intent(in)::node_thickness_cm(:)
    real(real64),intent(out)::alpha
    integer,intent(out)::deepest_node,status
    real(real64)::bottom,rd,rdm,dcrit
    integer::i
    alpha=0.0_real64;deepest_node=0;status=ROOT_COMP_INVALID
    rd=geometry%current_root_depth_cm;rdm=geometry%maximum_root_depth_cm
    dcrit=geometry%critical_root_zone_depth_cm
    if(.not.all(ieee_is_finite([rd,rdm,dcrit]))) return
    if(rdm<=0.0_real64.or.dcrit<0.0_real64.or.rd<0.0_real64.or.rd>rdm) return
    if(size(node_thickness_cm)==0) return
    if(any(.not.ieee_is_finite(node_thickness_cm))) return
    if(any(node_thickness_cm<=0.0_real64)) return
    if(rd==0.0_real64) then
      alpha=1.0_real64;status=ROOT_COMP_OK;return
    end if
    bottom=0.0_real64
    do i=1,size(node_thickness_cm)
      if(node_thickness_cm(i)>huge(bottom)-bottom) return
      bottom=bottom+node_thickness_cm(i)
      if(rd<=bottom) then
        deepest_node=i
        exit
      end if
    end do
    if(deepest_node==0) return
    ! Equivalent source formula, ordered to avoid overflow before min(...,1).
    if(dcrit>=bottom) then
      alpha=1.0_real64
    else
      if(bottom-dcrit>=rdm) return
      alpha=1.0_real64-(bottom-dcrit)/rdm
    end if
    if(alpha<=0.0_real64) return
    status=ROOT_COMP_OK
  end subroutine

  subroutine attribute_root_stress_losses(potential,drought_sink,oxygen_factor,drought_loss,oxygen_loss,status, &
       salinity_factor,salinity_loss,frost_factor,frost_loss)
    real(real64),intent(in)::potential(:),drought_sink(:),oxygen_factor(:)
    real(real64),intent(out)::drought_loss,oxygen_loss
    integer,intent(out)::status
    real(real64),optional,intent(in)::salinity_factor(:)
    real(real64),optional,intent(out)::salinity_loss
    real(real64),optional,intent(in)::frost_factor(:)
    real(real64),optional,intent(out)::frost_loss
    integer::i
    real(real64)::dry,wet,salt,frs,loss,weight,salt_total,frs_total
    drought_loss=0.0_real64;oxygen_loss=0.0_real64;status=ROOT_COMP_INVALID
    salt_total=0.0_real64;frs_total=0.0_real64
    if(present(frost_loss)) frost_loss=0.0_real64
    if(present(salinity_loss))salinity_loss=0.0_real64
    if(present(frost_factor)) then
      if(.not.present(frost_loss)) return
      ! The joint source formula must expose both loss channels.
      if(present(salinity_factor).and..not.present(salinity_loss)) return
      if(size(frost_factor)/=size(potential)) return
      if(any(.not.ieee_is_finite(frost_factor))) return
      if(any(frost_factor<0.0_real64).or.any(frost_factor>1.0_real64)) return
    end if
    if(size(potential)/=size(drought_sink).or.size(potential)/=size(oxygen_factor)) return
    if(present(salinity_factor))then
      if(size(potential)/=size(salinity_factor))return
      if(any(.not.ieee_is_finite(salinity_factor)))return
      if(any(salinity_factor<0.0_real64).or.any(salinity_factor>1.0_real64))return
    end if
    if(any(.not.ieee_is_finite(potential)).or.any(.not.ieee_is_finite(drought_sink)).or. &
       any(.not.ieee_is_finite(oxygen_factor))) return
    if(any(potential<0.0_real64).or.any(drought_sink<0.0_real64).or.any(drought_sink>potential).or. &
       any(oxygen_factor<0.0_real64).or.any(oxygen_factor>1.0_real64)) return
    do i=1,size(potential)
      if(potential(i)<=0.0_real64) cycle
      dry=drought_sink(i)/potential(i);wet=oxygen_factor(i);salt=1.0_real64
      if(present(salinity_factor))salt=salinity_factor(i)
      frs=1.0_real64
      if(present(frost_factor)) frs=frost_factor(i)
      loss=potential(i)-drought_sink(i)*wet*salt*frs
      if(loss<1.0e-14_real64) cycle
      weight=(1.0_real64-dry)+(1.0_real64-wet)+(1.0_real64-salt)+(1.0_real64-frs)
      if(weight<=0.0_real64) return
      drought_loss=drought_loss+(1.0_real64-dry)/weight*loss
      oxygen_loss=oxygen_loss+(1.0_real64-wet)/weight*loss
      salt_total=salt_total+(1.0_real64-salt)/weight*loss
      frs_total=frs_total+(1.0_real64-frs)/weight*loss
    end do
    if(present(salinity_loss))salinity_loss=salt_total
    if(present(frost_loss))frost_loss=frs_total
    status=ROOT_COMP_OK
  end subroutine

  subroutine compose_jarvis_root_uptake(config,ptra,base_fluxes,drought_reduction,oxygen_reduction,final_fluxes,diag,status, &
       salinity_reduction,frost_reduction)
    type(root_compensation_config_t),intent(in)::config
    real(real64),intent(in)::ptra,drought_reduction,oxygen_reduction
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    type(root_compensation_diagnostics_t),intent(out)::diag
    integer,intent(out)::status
    real(real64),optional,intent(in)::salinity_reduction,frost_reduction
    real(real64)::frs_loss,alpfrs,alpfrscom
    real(real64),parameter::vsmall=1.0e-14_real64
    integer::largest
    real(real64)::alptot,qred,alpdry,alpwet,alpsol,alpdrycom,alpwetcom,alpsolcom,alptotcom,redtot, &
         reduction_tolerance,salt_reduction

    final_fluxes=root_water_uptake_flux_result_t()
    diag=root_compensation_diagnostics_t()
    status=ROOT_COMP_OK
    frs_loss=0.0_real64
    if(present(frost_reduction))frs_loss=frost_reduction
    if(.not.ieee_is_finite(frs_loss).or.frs_loss<0.0_real64)then
      status=ROOT_COMP_INVALID;return
    end if
    salt_reduction=0.0_real64
    if(present(salinity_reduction))salt_reduction=salinity_reduction
    if(.not.ieee_is_finite(salt_reduction).or.salt_reduction<0.0_real64)then
      status=ROOT_COMP_INVALID;return
    end if

    if(config%method==ROOT_COMP_OFF) then
      final_fluxes=base_fluxes
      if(allocated(base_fluxes%root_extraction_sink)) then
        diag%uncompensated_uptake=sum(base_fluxes%root_extraction_sink)
        diag%compensated_uptake=diag%uncompensated_uptake
      end if
      diag%drought_reduction_total=drought_reduction
      diag%oxygen_reduction_total=oxygen_reduction
      diag%salinity_reduction_total=salt_reduction
      diag%frost_reduction_total=frs_loss
      return
    end if
    if(config%method/=ROOT_COMP_JARVIS) then
      status=ROOT_COMP_UNSUPPORTED;return
    end if
    if(config%stressor<ROOT_COMP_ALL .or. config%stressor>ROOT_COMP_FROST) then
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
       .not.ieee_is_finite(salt_reduction) .or. salt_reduction<0.0_real64 .or. &
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
    diag%salinity_reduction_total=salt_reduction
      diag%frost_reduction_total=frs_loss
    if(diag%uncompensated_uptake>ptra+256.0_real64*epsilon(1.0_real64)*max(1.0_real64,ptra)) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_INVALID;return
    end if
    if(ptra<=vsmall) return

    alptot=diag%uncompensated_uptake/ptra
    qred=ptra-diag%uncompensated_uptake
    if(abs(config%alpha_critical-1.0_real64)<vsmall .or. qred<=vsmall .or. alptot<vsmall) return

    ! Every active pre-compensation stress loss must be explicitly attributed;
    ! a mismatch implies an unadmitted or missing stressor and fails closed.
    reduction_tolerance=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,ptra,qred)
    if(abs((drought_reduction+oxygen_reduction+salt_reduction+frs_loss)-qred)>reduction_tolerance) then
      final_fluxes=root_water_uptake_flux_result_t();status=ROOT_COMP_UNSUPPORTED;return
    end if

    alpdry=alptot**(drought_reduction/qred)
    alpwet=alptot**(oxygen_reduction/qred)
    alpsol=alptot**(salt_reduction/qred)
    alpfrs=alptot**(frs_loss/qred)
    alpdrycom=alpdry;alpwetcom=alpwet;alpsolcom=alpsol;alpfrscom=alpfrs
    alptotcom=alptot
    select case(config%stressor)
    case(ROOT_COMP_ALL)
      alptotcom=min(alptot/config%alpha_critical,1.0_real64)
    case(ROOT_COMP_DROUGHT)
      alpdrycom=min(alpdry/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom*alpsolcom*alpfrscom
    case(ROOT_COMP_OXYGEN)
      alpwetcom=min(alpwet/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom*alpsolcom*alpfrscom
    case(ROOT_COMP_SALINITY)
      alpsolcom=min(alpsol/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom*alpsolcom*alpfrscom
    case(ROOT_COMP_FROST)
      alpfrscom=min(alpfrs/config%alpha_critical,1.0_real64)
      alptotcom=alpdrycom*alpwetcom*alpsolcom*alpfrscom
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
      diag%salinity_reduction_total=0.0_real64;diag%frost_reduction_total=0.0_real64
    else
      redtot=(1.0_real64-alpdrycom)+(1.0_real64-alpwetcom)+(1.0_real64-alpsolcom)+(1.0_real64-alpfrscom)
      if(redtot<=vsmall) then
        diag%drought_reduction_total=0.0_real64;diag%oxygen_reduction_total=0.0_real64
        diag%salinity_reduction_total=0.0_real64;diag%frost_reduction_total=0.0_real64
      else
        diag%drought_reduction_total=(1.0_real64-alpdrycom)/redtot*qred
        diag%oxygen_reduction_total=(1.0_real64-alpwetcom)/redtot*qred
        diag%salinity_reduction_total=(1.0_real64-alpsolcom)/redtot*qred
        diag%frost_reduction_total=(1.0_real64-alpfrscom)/redtot*qred
      end if
    end if
  end subroutine
end module
