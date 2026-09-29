! PPA-WU05-A3 isolated MACROSTATE section-D wetting/water-level candidate.
! Outputs are candidates only; production macropore state is not changed.
module mod_ppa_wu05a3_macrostate_wetting_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_WETTING_OK=0_int32
  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_WETTING_INVALID=1_int32
  public::ppa_wu05a3_macrostate_wetting_candidate

contains

  subroutine ppa_wu05a3_macrostate_wetting_candidate(num_nodes,num_domains,ic_top_mp,swmbf, &
      domain_bottom,domain_water_storage,domain_bottom_depth,domain_cell_volume,dz, &
      wet_fraction_previous,water_cell_previous,wet_fraction_candidate,water_cell_candidate, &
      water_top_candidate,water_level_candidate,status)
    integer(int32),intent(in)::num_nodes,num_domains,ic_top_mp,swmbf
    integer(int32),intent(in)::domain_bottom(:)
    real(real64),intent(in)::domain_water_storage(:),domain_bottom_depth(:),domain_cell_volume(:,:),dz(:)
    real(real64),intent(in)::wet_fraction_previous(:,:),water_cell_previous(:,:)
    real(real64),intent(out)::wet_fraction_candidate(:,:),water_cell_candidate(:,:)
    integer(int32),intent(out)::water_top_candidate(:),status
    real(real64),intent(out)::water_level_candidate(:)
    integer(int32)::id,ic,water_top
    real(real64)::volume_to_top

    status=PPA_WU05A3_MACROSTATE_WETTING_INVALID
    wet_fraction_candidate=0.0_real64
    water_cell_candidate=0.0_real64
    water_top_candidate=0_int32
    water_level_candidate=0.0_real64
    if(num_nodes<1 .or. num_domains<1 .or. ic_top_mp<1 .or. ic_top_mp>num_nodes) return
    if(swmbf/=1 .and. swmbf/=2) return
    if(size(domain_bottom)<num_domains .or. size(domain_water_storage)<num_domains .or. &
        size(domain_bottom_depth)<num_domains .or. size(water_top_candidate)<num_domains .or. &
        size(water_level_candidate)<num_domains) return
    if(size(dz)<num_nodes .or. size(domain_cell_volume,1)<num_domains .or. &
        size(domain_cell_volume,2)<num_nodes .or. &
        size(wet_fraction_previous,1)<num_domains .or. size(wet_fraction_previous,2)<num_nodes .or. &
        size(water_cell_previous,1)<num_domains .or. size(water_cell_previous,2)<num_nodes .or. &
        size(wet_fraction_candidate,1)<num_domains .or. size(wet_fraction_candidate,2)<num_nodes .or. &
        size(water_cell_candidate,1)<num_domains .or. size(water_cell_candidate,2)<num_nodes) return
    if(any(domain_bottom(1:num_domains)<0) .or. any(domain_bottom(1:num_domains)>num_nodes)) return
    if(any(domain_bottom(1:num_domains)>0 .and. domain_bottom(1:num_domains)<ic_top_mp)) return
    if(.not.all(ieee_is_finite(domain_water_storage(1:num_domains))) .or. &
        .not.all(ieee_is_finite(domain_bottom_depth(1:num_domains))) .or. &
        .not.all(ieee_is_finite(dz(1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_cell_volume(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(wet_fraction_previous(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_cell_previous(1:num_domains,1:num_nodes)))) return
    if(any(domain_water_storage(1:num_domains)<0.0_real64) .or. &
        any(dz(1:num_nodes)<=0.0_real64) .or. &
        any(domain_cell_volume(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(wet_fraction_previous(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(wet_fraction_previous(1:num_domains,1:num_nodes)>1.0_real64) .or. &
        any(water_cell_previous(1:num_domains,1:num_nodes)<0.0_real64)) return

    wet_fraction_candidate(1:num_domains,1:num_nodes)=wet_fraction_previous(1:num_domains,1:num_nodes)
    water_cell_candidate(1:num_domains,1:num_nodes)=water_cell_previous(1:num_domains,1:num_nodes)
    do id=1_int32,num_domains
      wet_fraction_candidate(id,ic_top_mp:num_nodes)=0.0_real64
      if(swmbf==1 .or. id>1) water_cell_candidate(id,1:num_nodes)=0.0_real64
      if(domain_bottom(id)>0) then
        wet_fraction_candidate(id,domain_bottom(id):num_nodes)=1.0_real64
        ic=domain_bottom(id)
        volume_to_top=domain_cell_volume(id,ic)
        do while(volume_to_top<domain_water_storage(id)-1.0e-12_real64 .and. ic>ic_top_mp)
          wet_fraction_candidate(id,ic)=1.0_real64
          if(swmbf==1 .or. id>1) water_cell_candidate(id,ic)=domain_cell_volume(id,ic)
          ic=ic-1_int32
          volume_to_top=volume_to_top+domain_cell_volume(id,ic)
        end do
        if(domain_cell_volume(id,ic)>1.0e-8_real64) then
          wet_fraction_candidate(id,ic)=1.0_real64- &
              (volume_to_top-domain_water_storage(id))/domain_cell_volume(id,ic)
          if(swmbf==1 .or. id>1) water_cell_candidate(id,ic)= &
              domain_cell_volume(id,ic)*wet_fraction_candidate(id,ic)
          water_top=ic
        else
          wet_fraction_candidate(id,ic)=0.0_real64
          water_top=ic+1_int32
        end if
        if(water_top>num_nodes) then
          wet_fraction_candidate=0.0_real64
          water_cell_candidate=0.0_real64
          water_top_candidate=0_int32
          water_level_candidate=0.0_real64
          return
        end if
        water_level_candidate(id)=domain_bottom_depth(id)
        do ic=domain_bottom(id),water_top+1_int32,-1_int32
          water_level_candidate(id)=water_level_candidate(id)+dz(ic)
        end do
        water_level_candidate(id)=water_level_candidate(id)+ &
            wet_fraction_candidate(id,water_top)*dz(water_top)
        water_top_candidate(id)=water_top
      else
        water_top_candidate(id)=1_int32
        water_level_candidate(id)=0.0_real64
      end if
    end do
    if(.not.all(ieee_is_finite(wet_fraction_candidate(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_cell_candidate(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_level_candidate(1:num_domains)))) then
      wet_fraction_candidate=0.0_real64
      water_cell_candidate=0.0_real64
      water_top_candidate=0_int32
      water_level_candidate=0.0_real64
      return
    end if
    status=PPA_WU05A3_MACROSTATE_WETTING_OK
  end subroutine ppa_wu05a3_macrostate_wetting_candidate

end module mod_ppa_wu05a3_macrostate_wetting_candidate
