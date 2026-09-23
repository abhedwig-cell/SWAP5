! PPA-WU05-A3 isolated MACROSTATE water-storage candidate oracle.
! Returned inventories are candidates only; no mutable state or flux is published.
module mod_ppa_wu05a3_macrostate_storage_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_STORAGE_OK=0_int32
  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_STORAGE_INVALID=1_int32
  public::ppa_wu05a3_macrostate_storage_candidate

contains

  subroutine ppa_wu05a3_macrostate_storage_candidate(num_nodes,num_domains,ic_top_mp,swmbf, &
      domain_bottom,dt,saturated_storage_previous,incoming_lateral,incoming_vertical, &
      matrix_exchange,rapid_drainage,profile_water,profile_volume,water_unsaturated, &
      saturated_candidate,unsaturated_candidate,groundwater_top_candidate,total_storage,status)
    integer(int32),intent(in)::num_nodes,num_domains,ic_top_mp,swmbf
    integer(int32),intent(in)::domain_bottom(:)
    real(real64),intent(in)::dt,saturated_storage_previous(:),incoming_lateral(:),incoming_vertical(:)
    real(real64),intent(in)::matrix_exchange(:,:),rapid_drainage(:),profile_water(:,:),profile_volume(:,:)
    real(real64),intent(in)::water_unsaturated(:)
    real(real64),intent(out)::saturated_candidate(:),unsaturated_candidate(:),total_storage
    integer(int32),intent(out)::groundwater_top_candidate(:),status
    integer(int32)::id,ic,ic_gwl
    real(real64)::net_flux

    status=PPA_WU05A3_MACROSTATE_STORAGE_INVALID
    saturated_candidate=0.0_real64
    unsaturated_candidate=0.0_real64
    groundwater_top_candidate=0_int32
    total_storage=0.0_real64
    if(num_nodes<1 .or. num_domains<1 .or. ic_top_mp<1 .or. ic_top_mp>num_nodes) return
    if(swmbf/=1 .and. swmbf/=2) return
    if(.not.ieee_is_finite(dt) .or. dt<=0.0_real64) return
    if(size(domain_bottom)<num_domains .or. size(saturated_storage_previous)<num_domains .or. &
        size(incoming_lateral)<num_domains .or. size(incoming_vertical)<num_domains .or. &
        size(water_unsaturated)<num_domains .or. size(saturated_candidate)<num_domains .or. &
        size(unsaturated_candidate)<num_domains .or. size(groundwater_top_candidate)<num_domains) return
    if(size(matrix_exchange,1)<num_domains .or. size(matrix_exchange,2)<num_nodes .or. &
        size(rapid_drainage)<num_nodes .or. size(profile_water,1)<num_domains .or. &
        size(profile_water,2)<num_nodes .or. size(profile_volume,1)<num_domains .or. &
        size(profile_volume,2)<num_nodes) return
    if(any(domain_bottom(1:num_domains)<0) .or. any(domain_bottom(1:num_domains)>num_nodes)) return
    if(.not.all(ieee_is_finite(saturated_storage_previous(1:num_domains))) .or. &
        .not.all(ieee_is_finite(incoming_lateral(1:num_domains))) .or. &
        .not.all(ieee_is_finite(incoming_vertical(1:num_domains))) .or. &
        .not.all(ieee_is_finite(matrix_exchange(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(rapid_drainage(1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_unsaturated(1:num_domains)))) return
    if(any(saturated_storage_previous(1:num_domains)<0.0_real64) .or. &
        any(water_unsaturated(1:num_domains)<0.0_real64)) return

    do id=1_int32,num_domains
      if(swmbf==1 .or. id>1) then
        net_flux=incoming_lateral(id)+incoming_vertical(id)- &
            sum(matrix_exchange(id,ic_top_mp:domain_bottom(id)))
        if(id==1) net_flux=net_flux-sum(rapid_drainage(ic_top_mp:domain_bottom(id)))
        saturated_candidate(id)=max(0.0_real64,saturated_storage_previous(id)+net_flux*dt)
        unsaturated_candidate(id)=saturated_candidate(id)
      else
        if(domain_bottom(id)>0) then
          if(.not.all(ieee_is_finite(profile_water(id,ic_top_mp:domain_bottom(id)))) .or. &
              .not.all(ieee_is_finite(profile_volume(id,ic_top_mp:domain_bottom(id))))) return
          if(any(profile_water(id,ic_top_mp:domain_bottom(id))<0.0_real64) .or. &
              any(profile_volume(id,ic_top_mp:domain_bottom(id))<=0.0_real64)) return
        end if
        ic_gwl=domain_bottom(id)+1_int32
        ic=domain_bottom(id)
        do while(ic_gwl>domain_bottom(id) .and. ic>=ic_top_mp)
          if(profile_water(id,ic)/profile_volume(id,ic)<1.0_real64) ic_gwl=ic
          ic=ic-1_int32
        end do
        if(ic_gwl>domain_bottom(id)) ic_gwl=1_int32
        unsaturated_candidate(id)=sum(profile_water(id,ic_top_mp:domain_bottom(id)))
        saturated_candidate(id)=max(0.0_real64, &
            sum(profile_water(id,ic_gwl:domain_bottom(id)))-water_unsaturated(id))
        groundwater_top_candidate(id)=ic_gwl
      end if
      total_storage=total_storage+unsaturated_candidate(id)
    end do
    if(.not.all(ieee_is_finite(saturated_candidate(1:num_domains))) .or. &
        .not.all(ieee_is_finite(unsaturated_candidate(1:num_domains))) .or. &
        .not.ieee_is_finite(total_storage)) then
      saturated_candidate=0.0_real64
      unsaturated_candidate=0.0_real64
      groundwater_top_candidate=0_int32
      total_storage=0.0_real64
      return
    end if
    status=PPA_WU05A3_MACROSTATE_STORAGE_OK
  end subroutine ppa_wu05a3_macrostate_storage_candidate

end module mod_ppa_wu05a3_macrostate_storage_candidate
