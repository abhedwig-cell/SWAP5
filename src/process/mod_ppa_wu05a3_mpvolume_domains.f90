! PPA-WU05-A3 isolated MPVOLUME task-1 cell/domain volume candidate oracle.
! Returned arrays are candidates only; no production state is published.
module mod_ppa_wu05a3_mpvolume_domains
  use, intrinsic :: iso_fortran_env, only: real64, int32
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_DOMAINS_OK = 0_int32
  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_DOMAINS_INVALID = 1_int32
  integer(int32), parameter, public :: PPA_WU05A3_MPVOLUME_DOMAINS_NUMERIC = 2_int32
  public :: ppa_wu05a3_mpvolume_domains

contains

  subroutine ppa_wu05a3_mpvolume_domains(num_nodes,num_domains,ic_top_mp,potential_bottom, &
      dz,diameter,dynamic_volume,static_volume,pp_domain,cell_volume,domain_bottom, &
      domain_cell_volume,domain_total,total_volume,dynamic_nonnegative,status)
    integer(int32), intent(in) :: num_nodes,num_domains,ic_top_mp
    integer(int32), intent(in) :: potential_bottom(:)
    real(real64), intent(in) :: dz(:),diameter(:),dynamic_volume(:),static_volume(:)
    real(real64), intent(in) :: pp_domain(:,:)
    real(real64), intent(out) :: cell_volume(:),domain_cell_volume(:,:),domain_total(:)
    real(real64), intent(out) :: total_volume,dynamic_nonnegative(:)
    integer(int32), intent(out) :: domain_bottom(:),status
    integer(int32) :: ic,id
    real(real64) :: min_pore_volume
    real(real64), parameter :: min_crack_width=1.0e-3_real64
    logical :: numeric_failure

    status=PPA_WU05A3_MPVOLUME_DOMAINS_INVALID
    cell_volume=0.0_real64
    domain_cell_volume=0.0_real64
    domain_total=0.0_real64
    total_volume=0.0_real64
    dynamic_nonnegative=0.0_real64
    domain_bottom=0_int32
    if(num_nodes<1 .or. num_domains<1 .or. ic_top_mp<1 .or. ic_top_mp>num_nodes) return
    if(size(potential_bottom)<max(2,num_domains) .or. size(domain_bottom)<num_domains) return
    if(num_nodes>min(size(dz),size(diameter),size(dynamic_volume),size(static_volume), &
        size(cell_volume),size(dynamic_nonnegative))) return
    if(size(pp_domain,1)<num_domains .or. size(pp_domain,2)<num_nodes) return
    if(size(domain_cell_volume,1)<num_domains .or. size(domain_cell_volume,2)<num_nodes) return
    if(size(domain_total)<num_domains) return
    if(any(potential_bottom(1:max(2,num_domains))<0) .or. &
        any(potential_bottom(1:max(2,num_domains))>num_nodes)) return
    if(.not.all(ieee_is_finite(dz(ic_top_mp:num_nodes))) .or. &
        .not.all(ieee_is_finite(diameter(ic_top_mp:num_nodes))) .or. &
        .not.all(ieee_is_finite(dynamic_volume(ic_top_mp:num_nodes))) .or. &
        .not.all(ieee_is_finite(static_volume(ic_top_mp:num_nodes))) .or. &
        .not.all(ieee_is_finite(pp_domain(1:num_domains,1:num_nodes)))) return
    if(any(dz(ic_top_mp:num_nodes)<=0.0_real64) .or. &
        any(diameter(ic_top_mp:num_nodes)<=0.0_real64) .or. &
        any(static_volume(ic_top_mp:num_nodes)<0.0_real64) .or. &
        any(pp_domain(1:num_domains,1:num_nodes)<0.0_real64) .or. &
        any(pp_domain(1:num_domains,1:num_nodes)>1.0_real64)) return

    cell_volume(ic_top_mp:num_nodes)=dynamic_volume(ic_top_mp:num_nodes)+ &
        static_volume(ic_top_mp:num_nodes)
    domain_bottom(1)=0_int32
    do ic=num_nodes,ic_top_mp,-1_int32
      if(domain_bottom(1)==0) then
        min_pore_volume=(1.0_real64-(1.0_real64-min_crack_width/diameter(ic))**2)*dz(ic)
        if(cell_volume(ic)<min_pore_volume .and. static_volume(ic)<1.0e-5_real64) &
          cell_volume(ic)=0.0_real64
        if(cell_volume(ic)>0.0_real64) domain_bottom(1)=ic
      end if
    end do
    domain_bottom(1)=max(domain_bottom(1),potential_bottom(2))
    do id=2_int32,num_domains
      domain_bottom(id)=min(potential_bottom(id),domain_bottom(1))
    end do

    total_volume=0.0_real64
    do id=1_int32,num_domains
      do ic=ic_top_mp,domain_bottom(id)
        domain_cell_volume(id,ic)=pp_domain(id,ic)*cell_volume(ic)
        domain_total(id)=domain_total(id)+domain_cell_volume(id,ic)
      end do
      do ic=domain_bottom(id)+1_int32,num_nodes
        domain_cell_volume(id,ic)=0.0_real64
      end do
      total_volume=total_volume+domain_total(id)
    end do
    dynamic_nonnegative(ic_top_mp:num_nodes)=max(dynamic_volume(ic_top_mp:num_nodes),0.0_real64)
    numeric_failure=.not.all(ieee_is_finite(cell_volume(1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_cell_volume(1:num_domains,1:num_nodes))) .or. &
        .not.all(ieee_is_finite(domain_total(1:num_domains))) .or. &
        .not.ieee_is_finite(total_volume)
    if(numeric_failure) then
      cell_volume=0.0_real64
      domain_cell_volume=0.0_real64
      domain_total=0.0_real64
      total_volume=0.0_real64
      dynamic_nonnegative=0.0_real64
      domain_bottom=0_int32
      status=PPA_WU05A3_MPVOLUME_DOMAINS_NUMERIC
      return
    end if
    status=PPA_WU05A3_MPVOLUME_DOMAINS_OK
  end subroutine ppa_wu05a3_mpvolume_domains

end module mod_ppa_wu05a3_mpvolume_domains
