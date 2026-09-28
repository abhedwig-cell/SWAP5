! PPA-WU05-A3 isolated MACROSTATE section-D internal-flux candidate oracle.
! Flux arrays are candidates only; no accepted exchange or state is published.
module mod_ppa_wu05a3_macrostate_flux_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_FLUX_OK=0_int32
  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_FLUX_INVALID=1_int32
  public::ppa_wu05a3_macrostate_flux_candidate

contains

  subroutine ppa_wu05a3_macrostate_flux_candidate(num_nodes,num_domains,ic_top_mp,swmbf, &
      domain_bottom,previous_domain_bottom,water_top,dt,incoming_lateral,incoming_vertical, &
      matrix_exchange,water_cell,water_cell_previous,domain_volume,domain_volume_previous, &
      flux_previous,flux_candidate,status)
    integer(int32),intent(in)::num_nodes,num_domains,ic_top_mp,swmbf
    integer(int32),intent(in)::domain_bottom(:),previous_domain_bottom(:),water_top(:)
    real(real64),intent(in)::dt,incoming_lateral(:),incoming_vertical(:),matrix_exchange(:,:)
    real(real64),intent(in)::water_cell(:,:),water_cell_previous(:,:)
    real(real64),intent(in)::domain_volume(:,:),domain_volume_previous(:,:),flux_previous(:,:)
    real(real64),intent(out)::flux_candidate(:,:)
    integer(int32),intent(out)::status
    integer(int32)::id,ic

    status=PPA_WU05A3_MACROSTATE_FLUX_INVALID
    flux_candidate=0.0_real64
    if(num_nodes<1 .or. num_domains<1 .or. ic_top_mp<1 .or. ic_top_mp>num_nodes) return
    if(swmbf/=1 .and. swmbf/=2) return
    if(.not.ieee_is_finite(dt) .or. dt<=0.0_real64) return
    if(size(domain_bottom)<num_domains .or. size(previous_domain_bottom)<num_domains .or. &
        size(water_top)<num_domains .or. size(incoming_lateral)<num_domains .or. &
        size(incoming_vertical)<num_domains) return
    if(size(matrix_exchange,1)<num_domains .or. size(matrix_exchange,2)<num_nodes .or. &
        size(water_cell,1)<num_domains .or. size(water_cell,2)<num_nodes .or. &
        size(water_cell_previous,1)<num_domains .or. size(water_cell_previous,2)<num_nodes .or. &
        size(domain_volume,1)<num_domains .or. size(domain_volume,2)<num_nodes .or. &
        size(domain_volume_previous,1)<num_domains .or. size(domain_volume_previous,2)<num_nodes .or. &
        size(flux_previous,1)<num_domains .or. size(flux_previous,2)<num_nodes .or. &
        size(flux_candidate,1)<num_domains .or. size(flux_candidate,2)<num_nodes) return
    if(any(domain_bottom(1:num_domains)<0) .or. any(domain_bottom(1:num_domains)>num_nodes) .or. &
        any(previous_domain_bottom(1:num_domains)<0) .or. &
        any(previous_domain_bottom(1:num_domains)>num_nodes) .or. &
        any(water_top(1:num_domains)<1) .or. any(water_top(1:num_domains)>num_nodes) .or. &
        any(domain_bottom(1:num_domains)>0 .and. domain_bottom(1:num_domains)<ic_top_mp)) return
    if(.not.all(ieee_is_finite(incoming_lateral(1:num_domains))) .or. &
        .not.all(ieee_is_finite(incoming_vertical(1:num_domains))) .or. &
        .not.all(ieee_is_finite(matrix_exchange(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_cell(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(water_cell_previous(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_volume(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_volume_previous(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(flux_previous(1:num_domains,1:num_nodes)))) return
    if(any(water_cell(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(water_cell_previous(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(domain_volume(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(domain_volume_previous(1:num_domains,1:num_nodes)<0.0_real64)) return

    ! Both descending recurrences read one flux below the deepest active cell.
    ! This bounded interface has no num_nodes+1 boundary-flux slot.
    do id=1_int32,num_domains
      if((swmbf==1 .or. id>1) .and. water_top(id)<domain_bottom(id)) then
        if(max(domain_bottom(id),previous_domain_bottom(id))>=num_nodes) return
      end if
    end do
    flux_candidate(1:num_domains,1:num_nodes)=flux_previous(1:num_domains,1:num_nodes)
    do id=1_int32,num_domains
      if(swmbf==1 .or. id>1) then
        do ic=ic_top_mp,water_top(id)
          if(ic==ic_top_mp) then
            flux_candidate(id,ic)=incoming_lateral(id)+incoming_vertical(id)
          else
            flux_candidate(id,ic)=flux_candidate(id,ic-1)-matrix_exchange(id,ic-1)- &
                (water_cell(id,ic-1)-water_cell_previous(id,ic-1))/dt
          end if
        end do
        if(water_top(id)<domain_bottom(id)) then
          if(domain_bottom(id)<previous_domain_bottom(id)) then
            do ic=previous_domain_bottom(id),domain_bottom(id)+1_int32,-1_int32
              flux_candidate(id,ic)=flux_candidate(id,ic+1)-water_cell_previous(id,ic)/dt
            end do
          end if
          do ic=domain_bottom(id),water_top(id)+1_int32,-1_int32
            flux_candidate(id,ic)=flux_candidate(id,ic+1)+matrix_exchange(id,ic)+ &
                (domain_volume(id,ic)-domain_volume_previous(id,ic))/dt
          end do
        end if
      end if
    end do
    if(.not.all(ieee_is_finite(flux_candidate(1:num_domains,1:num_nodes)))) then
      flux_candidate=0.0_real64
      return
    end if
    status=PPA_WU05A3_MACROSTATE_FLUX_OK
  end subroutine ppa_wu05a3_macrostate_flux_candidate

end module mod_ppa_wu05a3_macrostate_flux_candidate
