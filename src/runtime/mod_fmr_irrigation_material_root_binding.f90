module mod_fmr_irrigation_material_root_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
    bind_b110_default_mvg_provider
  use mod_soil_water_solver_contract, only: CONSTITUTIVE_DEMAND_WATER_CONTENT
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_parameters_t
  implicit none
  private
  public :: fmr_build_irrigation_material_root_zone
contains
  ! Material thresholds follow B1.11 irrigation, not the transpiration-dependent
  ! Feddes threshold. No physical or crop state is mutated or owned here.
  subroutine fmr_build_irrigation_material_root_zone(material,dz,actual_depth,hfc,h3l,h3h,h4,root,ok)
    type(b110_default_mvg_parameters_t),target,intent(in)::material
    real(real64),intent(in)::dz(:),actual_depth,hfc,h3l,h3h,h4
    type(irrigation_root_zone_parameters_t),intent(out)::root
    logical,intent(out)::ok
    type(b110_default_mvg_provider_t)::provider
    type(irrigation_root_zone_parameters_t)::candidate
    real(real64)::heads(size(dz)),theta(size(dz)),k(size(dz)),c(size(dz)),dk(size(dz))
    real(real64)::remaining,values(5),mean_head
    integer::n,i
    root=irrigation_root_zone_parameters_t();ok=.false.;n=size(dz)
    values=[actual_depth,hfc,h3l,h3h,h4]
    if(.not.all(ieee_is_finite(values)))return
    if(n<=0.or.material%active_nodes/=n)return
    if(.not.allocated(material%cofgen))return
    if(size(material%cofgen,1)<42.or.size(material%cofgen,2)/=n)return
    if(.not.all(ieee_is_finite(material%cofgen)))return
    if(.not.all(ieee_is_finite(dz)))return
    if(any(dz<=0._real64))return
    if(.not.ieee_is_finite(sum(dz)))return
    if(actual_depth<=0._real64.or.actual_depth>sum(dz))return
    if(hfc< -500._real64.or.hfc>0._real64)return
    if(h3l< -10000._real64.or.h3l>100._real64.or.h3h< -10000._real64.or.h3h>100._real64)return
    if(h4< -20000._real64.or.h4>100._real64)return
    mean_head=(h3l+h3h)*.5_real64
    if(hfc<mean_head.or.mean_head<h4)return
    ! The managed profile admits only the existing ordinary default material.
    if(material%elastic_storage_active.or.material%conductivity_power_tail_enabled)return
    candidate%active_nodes=n;candidate%node_thickness_cm=dz
    remaining=actual_depth
    do i=1,n
      candidate%rooted_nodes=i
      candidate%last_rooted_fraction=min(1._real64,remaining/dz(i))
      if(remaining<=dz(i))exit
      remaining=remaining-dz(i)
    end do
    call bind_b110_default_mvg_provider(provider,material,1._real64)
    heads=hfc
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%field_capacity_water_content=theta
    heads=mean_head
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%stress_water_content=theta
    heads=h4
    call provider%evaluate_demand(heads,CONSTITUTIVE_DEMAND_WATER_CONTENT,theta,k,c,dk)
    candidate%wilting_water_content=theta
    if(.not.all(ieee_is_finite(candidate%field_capacity_water_content)).or. &
       .not.all(ieee_is_finite(candidate%stress_water_content)).or. &
       .not.all(ieee_is_finite(candidate%wilting_water_content)))return
    if(any(candidate%field_capacity_water_content>1._real64).or. &
       any(candidate%wilting_water_content<0._real64))return
    if(any(candidate%field_capacity_water_content<candidate%stress_water_content).or. &
       any(candidate%stress_water_content<candidate%wilting_water_content))return
    root=candidate;ok=.true.
  end subroutine
end module
