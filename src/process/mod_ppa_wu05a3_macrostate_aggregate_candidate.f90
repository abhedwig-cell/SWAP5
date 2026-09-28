! PPA-WU05-A3 isolated MACROSTATE section-E SWAP/interface aggregate oracle.
! Returned interface values are candidates only and do not publish state.
module mod_ppa_wu05a3_macrostate_aggregate_candidate
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_AGGREGATE_OK=0_int32
  integer(int32),parameter,public::PPA_WU05A3_MACROSTATE_AGGREGATE_INVALID=1_int32
  public::ppa_wu05a3_macrostate_aggregate_candidate

contains

  subroutine ppa_wu05a3_macrostate_aggregate_candidate(num_nodes,num_domains,water_level, &
      domain_volume,water_storage,domain_cell_volume,water_level_main,volume_main, &
      storage_main,cell_volume_main,volume_internal,storage_internal,cell_volume_internal,status)
    integer(int32),intent(in)::num_nodes,num_domains
    real(real64),intent(in)::water_level(:),domain_volume(:),water_storage(:),domain_cell_volume(:,:)
    real(real64),intent(out)::water_level_main,volume_main,storage_main,cell_volume_main(:)
    real(real64),intent(out)::volume_internal,storage_internal,cell_volume_internal(:)
    integer(int32),intent(out)::status
    integer(int32)::id,ic

    status=PPA_WU05A3_MACROSTATE_AGGREGATE_INVALID
    water_level_main=0.0_real64; volume_main=0.0_real64; storage_main=0.0_real64
    cell_volume_main=0.0_real64; volume_internal=0.0_real64; storage_internal=0.0_real64
    cell_volume_internal=0.0_real64
    if(num_nodes<1 .or. num_domains<1) return
    if(size(water_level)<num_domains .or. size(domain_volume)<num_domains .or. &
        size(water_storage)<num_domains .or. size(domain_cell_volume,1)<num_domains .or. &
        size(domain_cell_volume,2)<num_nodes .or. size(cell_volume_main)<num_nodes .or. &
        size(cell_volume_internal)<num_nodes) return
    if(.not.all(ieee_is_finite(water_level(1:num_domains))) .or. &
        .not.all(ieee_is_finite(domain_volume(1:num_domains))) .or. &
        .not.all(ieee_is_finite(water_storage(1:num_domains))) .or. &
        .not.all(ieee_is_finite(domain_cell_volume(1:num_domains,1:num_nodes))) .or. &
        any(domain_volume(1:num_domains)<0.0_real64) .or. &
        any(water_storage(1:num_domains)<0.0_real64) .or. &
        any(domain_cell_volume(1:num_domains,1:num_nodes)<0.0_real64)) return

    water_level_main=water_level(1)
    volume_main=domain_volume(1)
    storage_main=water_storage(1)
    cell_volume_main(1:num_nodes)=domain_cell_volume(1,1:num_nodes)
    do id=2_int32,num_domains
      volume_internal=volume_internal+domain_volume(id)
      storage_internal=storage_internal+water_storage(id)
      do ic=1_int32,num_nodes
        cell_volume_internal(ic)=cell_volume_internal(ic)+domain_cell_volume(id,ic)
      end do
    end do
    if(.not.all(ieee_is_finite([water_level_main,volume_main,storage_main, &
        volume_internal,storage_internal])) .or. &
        .not.all(ieee_is_finite(cell_volume_main(1:num_nodes))) .or. &
        .not.all(ieee_is_finite(cell_volume_internal(1:num_nodes)))) then
      water_level_main=0.0_real64; volume_main=0.0_real64; storage_main=0.0_real64
      cell_volume_main=0.0_real64; volume_internal=0.0_real64; storage_internal=0.0_real64
      cell_volume_internal=0.0_real64
      return
    end if
    status=PPA_WU05A3_MACROSTATE_AGGREGATE_OK
  end subroutine ppa_wu05a3_macrostate_aggregate_candidate

end module mod_ppa_wu05a3_macrostate_aggregate_candidate
