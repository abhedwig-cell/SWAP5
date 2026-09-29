! PPA-WU05-A3 isolated MPVOLUME task-2 shrinkage-recovery candidate oracle.
! Updated arrays are candidates only; no macropore state is published.
module mod_ppa_wu05a3_mpvolume_hysteresis
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MPVOL_HYST_OK=0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MPVOL_HYST_INVALID=1_int32
  public :: ppa_wu05a3_mpvolume_hysteresis

contains

  subroutine ppa_wu05a3_mpvolume_hysteresis(num_nodes,num_domains,ic_top_mp,swmbf,potential_bottom, &
      static_volume,previous_domain_cell,current_domain_cell,current_domain_total,water_storage, &
      domain_cell_candidate,domain_total_candidate,dynamic_volume_candidate,total_volume,status)
    integer(int32),intent(in)::num_nodes,num_domains,ic_top_mp,swmbf
    integer(int32),intent(in)::potential_bottom(:)
    real(real64),intent(in)::static_volume(:),previous_domain_cell(:,:),current_domain_cell(:,:)
    real(real64),intent(in)::current_domain_total(:),water_storage(:)
    real(real64),intent(out)::domain_cell_candidate(:,:),domain_total_candidate(:)
    real(real64),intent(out)::dynamic_volume_candidate(:),total_volume
    integer(int32),intent(out)::status
    integer(int32)::ic,id,last_changed_node
    real(real64)::shrink_difference,needed
    real(real64)::cell_difference(max(1,num_nodes))

    status=PPA_WU05A3_MPVOL_HYST_INVALID
    domain_cell_candidate=0.0_real64
    domain_total_candidate=0.0_real64
    dynamic_volume_candidate=0.0_real64
    total_volume=0.0_real64
    if(num_nodes<1 .or. num_domains<1 .or. ic_top_mp<1 .or. ic_top_mp>num_nodes) return
    if(swmbf/=1 .and. swmbf/=2) return
    if(size(potential_bottom)<num_domains .or. size(static_volume)<num_nodes) return
    if(size(previous_domain_cell,1)<num_domains .or. size(previous_domain_cell,2)<num_nodes) return
    if(size(current_domain_cell,1)<num_domains .or. size(current_domain_cell,2)<num_nodes) return
    if(size(domain_cell_candidate,1)<num_domains .or. size(domain_cell_candidate,2)<num_nodes) return
    if(size(current_domain_total)<num_domains .or. size(domain_total_candidate)<num_domains) return
    if(size(water_storage)<num_domains .or. size(dynamic_volume_candidate)<num_nodes) return
    if(any(potential_bottom(1:num_domains)<0) .or. any(potential_bottom(1:num_domains)>num_nodes)) return
    if(.not.all(ieee_is_finite(static_volume(1:num_nodes))) .or. &
        .not.all(ieee_is_finite(previous_domain_cell(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(current_domain_cell(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(current_domain_total(1:num_domains))) .or. &
        .not.all(ieee_is_finite(water_storage(1:num_domains))) .or. &
        .not.all(ieee_is_finite(static_volume(ic_top_mp:num_nodes))) .or. &
        .not.all(ieee_is_finite(current_domain_cell(1:num_domains,ic_top_mp:num_nodes)))) return
    if(any(static_volume(ic_top_mp:num_nodes)<0.0_real64) .or. &
        any(current_domain_cell(1:num_domains,ic_top_mp:num_nodes)<0.0_real64) .or. &
        any(current_domain_total(1:num_domains)<0.0_real64) .or. &
        any(water_storage(1:num_domains)<0.0_real64)) return

    domain_cell_candidate(1:num_domains,1:num_nodes)= &
        current_domain_cell(1:num_domains,1:num_nodes)
    domain_total_candidate(1:num_domains)=current_domain_total(1:num_domains)
    dynamic_volume_candidate(ic_top_mp:num_nodes)=-static_volume(ic_top_mp:num_nodes)
    do id=1_int32,num_domains
      if(swmbf==1 .or. id>1) then
        if(domain_total_candidate(id)-water_storage(id)<-1.0e-7_real64) then
          needed=water_storage(id)-domain_total_candidate(id)
          shrink_difference=0.0_real64
          cell_difference=0.0_real64
          ic=ic_top_mp-1_int32
          do while(shrink_difference<needed-1.0e-8_real64 .and. ic<potential_bottom(id))
            ic=ic+1_int32
            cell_difference(ic)=max(previous_domain_cell(id,ic)- &
                current_domain_cell(id,ic),0.0_real64)
            shrink_difference=shrink_difference+cell_difference(ic)
          end do
          if(shrink_difference>0.0_real64) then
            last_changed_node=ic
            do ic=ic_top_mp,last_changed_node
              domain_cell_candidate(id,ic)=domain_cell_candidate(id,ic)+ &
                  (water_storage(id)-domain_total_candidate(id))* &
                  cell_difference(ic)/shrink_difference
            end do
            domain_total_candidate(id)=water_storage(id)
          end if
        end if
      end if
      do ic=ic_top_mp,num_nodes
        dynamic_volume_candidate(ic)=dynamic_volume_candidate(ic)+domain_cell_candidate(id,ic)
      end do
      total_volume=total_volume+domain_total_candidate(id)
    end do
    dynamic_volume_candidate(ic_top_mp:num_nodes)= &
        max(dynamic_volume_candidate(ic_top_mp:num_nodes),0.0_real64)
    if(.not.all(ieee_is_finite(domain_cell_candidate(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_total_candidate(1:num_domains))) .or. &
        .not.all(ieee_is_finite(dynamic_volume_candidate(1:num_nodes))) .or. &
        .not.ieee_is_finite(total_volume)) then
      domain_cell_candidate=0.0_real64
      domain_total_candidate=0.0_real64
      dynamic_volume_candidate=0.0_real64
      total_volume=0.0_real64
      return
    end if
    status=PPA_WU05A3_MPVOL_HYST_OK
  end subroutine ppa_wu05a3_mpvolume_hysteresis

end module mod_ppa_wu05a3_mpvolume_hysteresis
