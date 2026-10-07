module mod_drainage_multilevel_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_MULTI_OK=0
  integer, parameter, public :: DRAIN_MULTI_INVALID=1
  integer, parameter, public :: DRAIN_MULTI_SMALL_LEVEL=2
  real(real64), parameter :: SMALL=1.0e-10_real64
  real(real64), parameter :: LEVEL_OFFSET=1.0e-10_real64

  type, public :: drainage_multilevel_diagnostics_t
    integer :: status=DRAIN_MULTI_OK
    logical :: evaluated=.false.
    integer :: active_levels=0
    integer :: water_table_node=0
    real(real64) :: anisotropy_factor=0.0_real64
    real(real64), allocatable :: discharge_bottom_depth(:)
    real(real64), allocatable :: discharge_transmissivity(:)
    real(real64), allocatable :: closure_correction(:)
  end type drainage_multilevel_diagnostics_t

  public :: distribute_multilevel_signed_divdra

contains

  subroutine distribute_multilevel_signed_divdra(profile, hydraulic_view, scalar_transfer, drain_spacing, &
       drainage_flux_by_level, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: profile
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer(:), drain_spacing(:)
    real(real64), allocatable, intent(out) :: drainage_flux_by_level(:,:)
    type(drainage_multilevel_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: khor(:), kver(:), dmax(:), kd_drain(:), flow(:)
    real(real64), allocatable :: bottom_thickness(:)
    integer, allocatable :: sequence(:), bottom_node(:)
    real(real64) :: wlev, dz_top_sat, kd_hor, kd_ver, saturated_depth
    real(real64) :: khor_avg, kver_avg, fac_aniso, profile_depth
    real(real64) :: depth_accum, kd_help, target_depth, raw_bottom, sum_previous
    real(real64) :: tmp_real
    integer :: n, levels, active_count, i, j, k, wt_node, idr, jdr, tmp_int

    diagnostics=drainage_multilevel_diagnostics_t()
    n=profile%active_nodes
    levels=size(scalar_transfer)
    if(n<=0 .or. levels<=0 .or. size(drain_spacing)/=levels)then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    if(.not.valid_profile(profile))then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    if(hydraulic_view%active_nodes/=n .or. .not.ieee_is_finite(hydraulic_view%groundwater_level))then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    if(any(.not.ieee_is_finite(scalar_transfer)).or.any(.not.ieee_is_finite(drain_spacing)))then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    if(any(drain_spacing<=0.0_real64))then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if

    allocate(drainage_flux_by_level(levels,n)); drainage_flux_by_level=0.0_real64
    allocate(diagnostics%discharge_bottom_depth(levels),diagnostics%discharge_transmissivity(levels), &
         diagnostics%closure_correction(levels))
    diagnostics%discharge_bottom_depth=0.0_real64
    diagnostics%discharge_transmissivity=0.0_real64
    diagnostics%closure_correction=0.0_real64

    active_count=count(abs(scalar_transfer)>SMALL)
    if(any((scalar_transfer/=0.0_real64).and.(abs(scalar_transfer)<=SMALL)))then
      diagnostics%status=DRAIN_MULTI_SMALL_LEVEL; return
    end if
    diagnostics%active_levels=active_count
    if(active_count==0)then
      diagnostics%evaluated=.true.; return
    end if

    profile_depth=-profile%zbotcp(n)
    wlev=-min(hydraulic_view%groundwater_level,0.0_real64)
    if(wlev>=profile_depth)then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    wt_node=1
    do while(wlev > -profile%zbotcp(wt_node)+LEVEL_OFFSET)
      wt_node=wt_node+1
      if(wt_node>n)then
        diagnostics%status=DRAIN_MULTI_INVALID; return
      end if
    end do
    diagnostics%water_table_node=wt_node
    dz_top_sat=-profile%zbotcp(wt_node)-wlev
    if(dz_top_sat<=0.0_real64)then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if

    allocate(khor(n),kver(n))
    khor=profile%saturated_conductivity*profile%horizontal_anisotropy_factor
    kver=profile%saturated_conductivity
    kd_hor=dz_top_sat*khor(wt_node)
    kd_ver=dz_top_sat/kver(wt_node)
    saturated_depth=dz_top_sat
    do i=wt_node+1,n
      kd_hor=kd_hor+profile%dz(i)*khor(i)
      kd_ver=kd_ver+profile%dz(i)/kver(i)
      saturated_depth=saturated_depth+profile%dz(i)
    end do
    if(kd_hor<=0.0_real64.or.kd_ver<=0.0_real64.or.saturated_depth<=0.0_real64)then
      diagnostics%status=DRAIN_MULTI_INVALID; return
    end if
    khor_avg=kd_hor/saturated_depth
    kver_avg=saturated_depth/kd_ver
    fac_aniso=sqrt(kver_avg/khor_avg)
    diagnostics%anisotropy_factor=fac_aniso

    allocate(dmax(levels),kd_drain(levels),flow(levels),bottom_thickness(levels),bottom_node(levels),sequence(active_count))
    dmax=0.0_real64;kd_drain=0.0_real64;flow=0.0_real64;bottom_thickness=0.0_real64;bottom_node=0
    k=0
    do i=1,levels
      if(abs(scalar_transfer(i))>SMALL)then
        k=k+1;sequence(k)=i
        dmax(i)=min(0.25_real64*drain_spacing(i)*fac_aniso+wlev,profile_depth)
      end if
    end do

    ! Frozen B1.11 paragraph 6: descending FDisInf*Lspacing. This bounded
    ! ordinary slice has FDisInf=1 for every level.
    do i=1,active_count-1
      do j=i+1,active_count
        if(drain_spacing(sequence(i))<drain_spacing(sequence(j)))then
          tmp_int=sequence(i);sequence(i)=sequence(j);sequence(j)=tmp_int
        end if
      end do
    end do

    idr=sequence(active_count)
    flow(idr)=abs(scalar_transfer(idr))*drain_spacing(idr)
    do i=active_count-1,1,-1
      idr=sequence(i);jdr=sequence(i+1)
      flow(idr)=flow(jdr)+abs(scalar_transfer(idr)*drain_spacing(idr))
    end do

    idr=sequence(1)
    kd_drain(idr)=kd_hor
    bottom_node(idr)=n
    bottom_thickness(idr)=profile%dz(n)
    diagnostics%discharge_bottom_depth(idr)=profile_depth
    if(diagnostics%discharge_bottom_depth(idr)>dmax(idr)) then
      call layer_for_depth(idr,dmax(idr))
      if(diagnostics%status/=DRAIN_MULTI_OK)return
    end if

    do i=2,active_count
      idr=sequence(i);jdr=sequence(i-1)
      if(flow(jdr)<=0.0_real64)then
        diagnostics%status=DRAIN_MULTI_INVALID; return
      end if
      kd_drain(idr)=kd_drain(jdr)*flow(idr)/flow(jdr)
      call layer_for_transmissivity(idr,kd_drain(idr))
      if(diagnostics%status/=DRAIN_MULTI_OK)return
      if(diagnostics%discharge_bottom_depth(idr)>dmax(idr))then
        call layer_for_depth(idr,dmax(idr))
        if(diagnostics%status/=DRAIN_MULTI_OK)return
      end if
    end do

    do k=1,active_count
      idr=sequence(k)
      if(kd_drain(idr)<=0.0_real64.or.bottom_node(idr)<wt_node)then
        diagnostics%status=DRAIN_MULTI_INVALID; return
      end if
      if(wt_node==bottom_node(idr))then
        drainage_flux_by_level(idr,wt_node)=scalar_transfer(idr)
      else
        drainage_flux_by_level(idr,wt_node)=scalar_transfer(idr)*dz_top_sat*khor(wt_node)/kd_drain(idr)
        do i=wt_node+1,bottom_node(idr)-1
          drainage_flux_by_level(idr,i)=scalar_transfer(idr)*profile%dz(i)*khor(i)/kd_drain(idr)
        end do
        raw_bottom=scalar_transfer(idr)*bottom_thickness(idr)*khor(bottom_node(idr))/kd_drain(idr)
        sum_previous=sum(drainage_flux_by_level(idr,1:bottom_node(idr)-1))
        drainage_flux_by_level(idr,bottom_node(idr))=scalar_transfer(idr)-sum_previous
        diagnostics%closure_correction(idr)=drainage_flux_by_level(idr,bottom_node(idr))-raw_bottom
      end if
      diagnostics%discharge_transmissivity(idr)=kd_drain(idr)
    end do

    diagnostics%evaluated=.true.
    diagnostics%status=DRAIN_MULTI_OK
    return

  contains

    subroutine layer_for_transmissivity(level,target_kd)
      integer,intent(in)::level
      real(real64),intent(in)::target_kd
      integer::node
      node=wt_node
      kd_help=dz_top_sat*khor(node)
      depth_accum=dz_top_sat
      do while(kd_help<target_kd)
        node=node+1
        if(node>n)then
          diagnostics%status=DRAIN_MULTI_INVALID; return
        end if
        kd_help=kd_help+profile%dz(node)*khor(node)
        depth_accum=depth_accum+profile%dz(node)
      end do
      bottom_node(level)=node
      bottom_thickness(level)=profile%dz(node)-(kd_help-target_kd)/khor(node)
      diagnostics%discharge_bottom_depth(level)=wlev+depth_accum+(target_kd-kd_help)/khor(node)
    end subroutine layer_for_transmissivity

    subroutine layer_for_depth(level,depth)
      integer,intent(in)::level
      real(real64),intent(in)::depth
      integer::node
      target_depth=depth-wlev
      if(target_depth<=0.0_real64)then
        diagnostics%status=DRAIN_MULTI_INVALID; return
      end if
      node=wt_node
      depth_accum=dz_top_sat
      kd_drain(level)=dz_top_sat*khor(node)
      do while(target_depth>depth_accum)
        node=node+1
        if(node>n)then
          diagnostics%status=DRAIN_MULTI_INVALID; return
        end if
        depth_accum=depth_accum+profile%dz(node)
        kd_drain(level)=kd_drain(level)+profile%dz(node)*khor(node)
      end do
      kd_drain(level)=kd_drain(level)-(depth_accum-target_depth)*khor(node)
      bottom_node(level)=node
      bottom_thickness(level)=profile%dz(node)-(depth_accum-target_depth)
      diagnostics%discharge_bottom_depth(level)=depth
    end subroutine layer_for_depth

  end subroutine distribute_multilevel_signed_divdra

  logical function valid_profile(profile) result(ok)
    type(drainage_distribution_parameters_t),intent(in)::profile
    integer::i,n
    real(real64)::depth,tol
    ok=.false.;n=profile%active_nodes
    if(n<=0)return
    if(.not.allocated(profile%dz).or..not.allocated(profile%zbotcp))return
    if(.not.allocated(profile%saturated_conductivity).or..not.allocated(profile%horizontal_anisotropy_factor))return
    if(size(profile%dz)/=n.or.size(profile%zbotcp)/=n)return
    if(size(profile%saturated_conductivity)/=n.or.size(profile%horizontal_anisotropy_factor)/=n)return
    if(any(.not.ieee_is_finite(profile%dz)).or.any(profile%dz<=0.0_real64))return
    if(any(.not.ieee_is_finite(profile%zbotcp)).or.any(profile%zbotcp>=0.0_real64))return
    if(any(.not.ieee_is_finite(profile%saturated_conductivity)).or.any(profile%saturated_conductivity<=0.0_real64))return
    if(any(.not.ieee_is_finite(profile%horizontal_anisotropy_factor)).or.any(profile%horizontal_anisotropy_factor<=0.0_real64))return
    depth=0.0_real64
    do i=1,n
      depth=depth+profile%dz(i)
      tol=4096.0_real64*epsilon(1.0_real64)*max(1.0_real64,depth)
      if(abs(-profile%zbotcp(i)-depth)>tol)return
    end do
    ok=.true.
  end function valid_profile

end module mod_drainage_multilevel_distribution
