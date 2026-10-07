module mod_drainage_spatial_distribution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  private

  integer, parameter, public :: DRAIN_DIST_OK = 0
  integer, parameter, public :: DRAIN_DIST_INVALID_PARAMETERS = 1
  integer, parameter, public :: DRAIN_DIST_INVALID_HYDRAULIC_VIEW = 2
  integer, parameter, public :: DRAIN_DIST_INVALID_TRANSFER = 3
  integer, parameter, public :: DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE = 4

  real(real64), parameter :: LEGACY_ACTIVE_MAGNITUDE = 1.0e-10_real64
  real(real64), parameter :: LEGACY_LEVEL_TO_COMPARTMENT_OFFSET = 1.0e-10_real64

  type, public :: drainage_distribution_parameters_t
    integer :: active_nodes = 0
    real(real64), allocatable :: dz(:)
    real(real64), allocatable :: zbotcp(:)
    real(real64), allocatable :: saturated_conductivity(:)
    real(real64), allocatable :: horizontal_anisotropy_factor(:)
    real(real64) :: drain_spacing = 0.0_real64
  end type drainage_distribution_parameters_t

  type, public :: drainage_node_transfer_t
    real(real64), allocatable :: soil_to_drain_rate(:)
  end type drainage_node_transfer_t

  type, public :: drainage_distribution_diagnostics_t
    integer :: status = DRAIN_DIST_OK
    logical :: evaluated = .false.
    logical :: zero_transfer = .false.
    integer :: water_table_node = 0
    integer :: discharge_bottom_node = 0
    real(real64) :: groundwater_depth = 0.0_real64
    real(real64) :: saturated_top_thickness = 0.0_real64
    real(real64) :: discharge_bottom_thickness = 0.0_real64
    real(real64) :: profile_anisotropy_factor = 0.0_real64
    real(real64) :: discharge_layer_bottom_depth = 0.0_real64
    real(real64) :: discharge_transmissivity = 0.0_real64
    real(real64) :: raw_partition_sum = 0.0_real64
    real(real64) :: closure_correction = 0.0_real64
    logical :: scalar_transfer_is_authoritative = .true.
    logical :: worker_scratch_only = .true.
  end type drainage_distribution_diagnostics_t

  type, public :: drainage_multilevel_diagnostics_t
    integer :: status = DRAIN_DIST_OK
    logical :: evaluated = .false.
    integer :: active_levels = 0
    integer :: water_table_node = 0
    real(real64) :: groundwater_depth = 0.0_real64
    real(real64) :: profile_anisotropy_factor = 0.0_real64
    real(real64), allocatable :: discharge_layer_bottom_depth(:)
    real(real64), allocatable :: discharge_transmissivity(:)
    real(real64), allocatable :: closure_correction(:)
    logical :: scalar_transfer_is_authoritative = .true.
    logical :: worker_scratch_only = .true.
  end type drainage_multilevel_diagnostics_t

  public :: distribute_single_level_positive_divdra
  public :: distribute_single_level_signed_divdra
  public :: distribute_multilevel_signed_divdra

contains

  subroutine distribute_single_level_positive_divdra(parameters, hydraulic_view, scalar_transfer, node_transfer, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer
    type(drainage_node_transfer_t), intent(out) :: node_transfer
    type(drainage_distribution_diagnostics_t), intent(out) :: diagnostics

    diagnostics = drainage_distribution_diagnostics_t()
    if (.not. ieee_is_finite(scalar_transfer) .or. scalar_transfer < 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_TRANSFER
      return
    end if
    call distribute_single_level_signed_divdra(parameters, hydraulic_view, scalar_transfer, node_transfer, diagnostics)
  end subroutine distribute_single_level_positive_divdra

  subroutine distribute_single_level_signed_divdra(parameters, hydraulic_view, scalar_transfer, node_transfer, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer
    type(drainage_node_transfer_t), intent(out) :: node_transfer
    type(drainage_distribution_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: khor(:), kver(:)
    real(real64) :: wlev, dz_top_sat, kd_hor, kd_ver, saturated_depth
    real(real64) :: khor_avg, kver_avg, fac_aniso, dmax, discharge_bottom
    real(real64) :: kd_drain, depth_accum, discharge_thickness, raw_bottom
    real(real64) :: sum_previous
    integer :: n, i, wt_node, bottom_node

    diagnostics = drainage_distribution_diagnostics_t()
    n = parameters%active_nodes

    if (.not. valid_parameters(parameters)) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    allocate(node_transfer%soil_to_drain_rate(n))
    node_transfer%soil_to_drain_rate = 0.0_real64

    if (.not. ieee_is_finite(scalar_transfer)) then
      diagnostics%status = DRAIN_DIST_INVALID_TRANSFER
      return
    end if

    if (.not. (scalar_transfer < 0.0_real64 .or. scalar_transfer > 0.0_real64)) then
      diagnostics%evaluated = .true.
      diagnostics%zero_transfer = .true.
      return
    end if

    if (abs(scalar_transfer) <= LEGACY_ACTIVE_MAGNITUDE) then
      diagnostics%status = DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    wlev = -min(hydraulic_view%groundwater_level, 0.0_real64)
    if (wlev >= -parameters%zbotcp(n)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    allocate(khor(n), kver(n))
    khor = parameters%saturated_conductivity * parameters%horizontal_anisotropy_factor
    kver = parameters%saturated_conductivity

    ! Frozen SWAP 4.3.1 Lev2Comp semantics deliberately retain the shallower
    ! compartment until the level is more than 1e-10 cm below its bottom.
    ! This is an explicit reference seam, not a configurable solver tolerance.
    wt_node = 1
    do while (wlev > -parameters%zbotcp(wt_node) + LEGACY_LEVEL_TO_COMPARTMENT_OFFSET)
      wt_node = wt_node + 1
      if (wt_node > n) then
        diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
        return
      end if
    end do

    dz_top_sat = -parameters%zbotcp(wt_node) - wlev
    if (wt_node == n .and. dz_top_sat <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    kd_hor = dz_top_sat * khor(wt_node)
    kd_ver = dz_top_sat / kver(wt_node)
    saturated_depth = dz_top_sat
    do i = wt_node + 1, n
      kd_hor = kd_hor + parameters%dz(i) * khor(i)
      kd_ver = kd_ver + parameters%dz(i) / kver(i)
      saturated_depth = saturated_depth + parameters%dz(i)
    end do

    if (kd_hor <= 0.0_real64 .or. kd_ver <= 0.0_real64 .or. saturated_depth <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    khor_avg = kd_hor / saturated_depth
    kver_avg = saturated_depth / kd_ver
    fac_aniso = sqrt(kver_avg / khor_avg)

    dmax = 0.25_real64 * parameters%drain_spacing * fac_aniso + wlev
    dmax = min(dmax, saturated_depth + wlev)

    discharge_bottom = -parameters%zbotcp(n)
    bottom_node = n
    discharge_thickness = parameters%dz(n)
    kd_drain = kd_hor

    if (discharge_bottom > dmax) then
      discharge_bottom = dmax
      bottom_node = wt_node
      depth_accum = dz_top_sat
      kd_drain = dz_top_sat * khor(wt_node)
      do while (discharge_bottom - wlev > depth_accum)
        bottom_node = bottom_node + 1
        if (bottom_node > n) then
          diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
          return
        end if
        depth_accum = depth_accum + parameters%dz(bottom_node)
        kd_drain = kd_drain + parameters%dz(bottom_node) * khor(bottom_node)
      end do
      kd_drain = kd_drain - (depth_accum - (discharge_bottom - wlev)) * khor(bottom_node)
      discharge_thickness = parameters%dz(bottom_node) - (depth_accum - (discharge_bottom - wlev))
    end if

    if (kd_drain <= 0.0_real64 .or. discharge_thickness <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if

    if (wt_node == bottom_node) then
      node_transfer%soil_to_drain_rate(wt_node) = scalar_transfer
      diagnostics%raw_partition_sum = scalar_transfer
    else
      node_transfer%soil_to_drain_rate(wt_node) = scalar_transfer * dz_top_sat * khor(wt_node) / kd_drain
      do i = wt_node + 1, bottom_node - 1
        node_transfer%soil_to_drain_rate(i) = scalar_transfer * parameters%dz(i) * khor(i) / kd_drain
      end do
      raw_bottom = scalar_transfer * discharge_thickness * khor(bottom_node) / kd_drain
      diagnostics%raw_partition_sum = sum(node_transfer%soil_to_drain_rate(1:bottom_node-1)) + raw_bottom

      sum_previous = sum(node_transfer%soil_to_drain_rate(1:bottom_node-1))
      node_transfer%soil_to_drain_rate(bottom_node) = scalar_transfer - sum_previous
      diagnostics%closure_correction = node_transfer%soil_to_drain_rate(bottom_node) - raw_bottom
    end if

    diagnostics%evaluated = .true.
    diagnostics%water_table_node = wt_node
    diagnostics%discharge_bottom_node = bottom_node
    diagnostics%groundwater_depth = wlev
    diagnostics%saturated_top_thickness = dz_top_sat
    diagnostics%discharge_bottom_thickness = discharge_thickness
    diagnostics%profile_anisotropy_factor = fac_aniso
    diagnostics%discharge_layer_bottom_depth = discharge_bottom
    diagnostics%discharge_transmissivity = kd_drain
  end subroutine distribute_single_level_signed_divdra


  subroutine distribute_multilevel_signed_divdra(level_parameters, hydraulic_view, scalar_transfer, &
       drainage_flux_by_level, diagnostics)
    type(drainage_distribution_parameters_t), intent(in) :: level_parameters(:)
    type(process_hydraulic_view_t), intent(in) :: hydraulic_view
    real(real64), intent(in) :: scalar_transfer(:)
    real(real64), allocatable, intent(out) :: drainage_flux_by_level(:,:)
    type(drainage_multilevel_diagnostics_t), intent(out) :: diagnostics

    real(real64), allocatable :: khor(:), kver(:), dmax(:), flow_discharge(:), kd_drain(:)
    real(real64), allocatable :: bottom_depth(:), bottom_thickness(:), helper_flow(:)
    integer, allocatable :: sequence(:), bottom_node(:)
    real(real64) :: wlev, dz_top_sat, kd_hor, kd_ver, saturated_depth
    real(real64) :: khor_avg, kver_avg, fac_aniso, depth_accum, target_depth
    real(real64) :: raw_bottom, sum_previous, tmp_r
    integer :: n, levels, level, i, j, wt_node, active_count, idr, jdr, tmp_i

    diagnostics = drainage_multilevel_diagnostics_t()
    levels = size(level_parameters)
    if (levels <= 1 .or. size(scalar_transfer) /= levels) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if
    if (any(.not. ieee_is_finite(scalar_transfer))) then
      diagnostics%status = DRAIN_DIST_INVALID_TRANSFER
      return
    end if

    n = level_parameters(1)%active_nodes
    if (.not. valid_parameters(level_parameters(1))) then
      diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
      return
    end if
    do level = 2, levels
      if (.not. valid_parameters(level_parameters(level))) then
        diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
        return
      end if
      if (level_parameters(level)%active_nodes /= n) then
        diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
        return
      end if
      if (any(abs(level_parameters(level)%dz - level_parameters(1)%dz) > 0.0_real64) .or. &
          any(abs(level_parameters(level)%zbotcp - level_parameters(1)%zbotcp) > 0.0_real64) .or. &
          any(abs(level_parameters(level)%saturated_conductivity - &
              level_parameters(1)%saturated_conductivity) > 0.0_real64) .or. &
          any(abs(level_parameters(level)%horizontal_anisotropy_factor - &
              level_parameters(1)%horizontal_anisotropy_factor) > 0.0_real64)) then
        diagnostics%status = DRAIN_DIST_INVALID_PARAMETERS
        return
      end if
    end do

    allocate(drainage_flux_by_level(levels,n))
    drainage_flux_by_level = 0.0_real64
    allocate(diagnostics%discharge_layer_bottom_depth(levels), diagnostics%discharge_transmissivity(levels), &
         diagnostics%closure_correction(levels))
    diagnostics%discharge_layer_bottom_depth = 0.0_real64
    diagnostics%discharge_transmissivity = 0.0_real64
    diagnostics%closure_correction = 0.0_real64

    active_count = count(abs(scalar_transfer) > LEGACY_ACTIVE_MAGNITUDE)
    diagnostics%active_levels = active_count
    if (active_count == 0) then
      diagnostics%evaluated = .true.
      return
    end if

    if (.not. ieee_is_finite(hydraulic_view%groundwater_level)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if
    wlev = -min(hydraulic_view%groundwater_level, 0.0_real64)
    if (wlev >= -level_parameters(1)%zbotcp(n)) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    wt_node = 1
    do while (wlev > -level_parameters(1)%zbotcp(wt_node) + LEGACY_LEVEL_TO_COMPARTMENT_OFFSET)
      wt_node = wt_node + 1
      if (wt_node > n) then
        diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
        return
      end if
    end do
    dz_top_sat = -level_parameters(1)%zbotcp(wt_node) - wlev
    if (wt_node == n .and. dz_top_sat <= 0.0_real64) then
      diagnostics%status = DRAIN_DIST_INVALID_HYDRAULIC_VIEW
      return
    end if

    allocate(khor(n),kver(n))
    khor = level_parameters(1)%saturated_conductivity * level_parameters(1)%horizontal_anisotropy_factor
    kver = level_parameters(1)%saturated_conductivity
    kd_hor = dz_top_sat*khor(wt_node)
    kd_ver = dz_top_sat/kver(wt_node)
    saturated_depth = dz_top_sat
    do i=wt_node+1,n
      kd_hor=kd_hor+level_parameters(1)%dz(i)*khor(i)
      kd_ver=kd_ver+level_parameters(1)%dz(i)/kver(i)
      saturated_depth=saturated_depth+level_parameters(1)%dz(i)
    end do
    if (kd_hor<=0.0_real64 .or. kd_ver<=0.0_real64 .or. saturated_depth<=0.0_real64) then
      diagnostics%status=DRAIN_DIST_INVALID_PARAMETERS
      return
    end if
    khor_avg=kd_hor/saturated_depth
    kver_avg=saturated_depth/kd_ver
    fac_aniso=sqrt(kver_avg/khor_avg)

    allocate(dmax(levels),flow_discharge(levels),kd_drain(levels),bottom_depth(levels), &
         bottom_thickness(levels),bottom_node(levels),sequence(active_count),helper_flow(active_count))
    dmax=0.0_real64; flow_discharge=0.0_real64; kd_drain=0.0_real64
    bottom_depth=wlev; bottom_thickness=0.0_real64; bottom_node=wt_node

    j=0
    do level=1,levels
      dmax(level)=min(0.25_real64*level_parameters(level)%drain_spacing*fac_aniso+wlev, &
           saturated_depth+wlev)
      if(abs(scalar_transfer(level))>LEGACY_ACTIVE_MAGNITUDE)then
        j=j+1
        sequence(j)=level
        helper_flow(j)=level_parameters(level)%drain_spacing
      end if
    end do

    do i=1,active_count-1
      do j=i+1,active_count
        if(helper_flow(i)<helper_flow(j))then
          tmp_r=helper_flow(j); helper_flow(j)=helper_flow(i); helper_flow(i)=tmp_r
          tmp_i=sequence(j); sequence(j)=sequence(i); sequence(i)=tmp_i
        end if
      end do
    end do

    idr=sequence(active_count)
    flow_discharge(idr)=abs(scalar_transfer(idr))*level_parameters(idr)%drain_spacing
    do i=active_count-1,1,-1
      idr=sequence(i); jdr=sequence(i+1)
      flow_discharge(idr)=flow_discharge(jdr)+abs(scalar_transfer(idr))*level_parameters(idr)%drain_spacing
    end do

    idr=sequence(1)
    kd_drain(idr)=kd_hor
    bottom_depth(idr)=-level_parameters(1)%zbotcp(n)
    bottom_node(idr)=n
    bottom_thickness(idr)=level_parameters(1)%dz(n)
    if(bottom_depth(idr)>dmax(idr)) then
      call layer_for_depth(idr,dmax(idr))
      if(diagnostics%status/=DRAIN_DIST_OK)return
    end if

    do i=2,active_count
      idr=sequence(i); jdr=sequence(i-1)
      if(flow_discharge(jdr)<=0.0_real64)then
        diagnostics%status=DRAIN_DIST_INVALID_PARAMETERS
        return
      end if
      kd_drain(idr)=kd_drain(jdr)*flow_discharge(idr)/flow_discharge(jdr)
      call layer_for_transmissivity(idr,kd_drain(idr))
      if(diagnostics%status/=DRAIN_DIST_OK)return
      if(bottom_depth(idr)>dmax(idr))then
        call layer_for_depth(idr,dmax(idr))
        if(diagnostics%status/=DRAIN_DIST_OK)return
      end if
    end do

    do i=1,active_count
      idr=sequence(i)
      if(kd_drain(idr)<=0.0_real64 .or. bottom_thickness(idr)<=0.0_real64)then
        diagnostics%status=DRAIN_DIST_INVALID_PARAMETERS
        return
      end if
      if(wt_node==bottom_node(idr))then
        drainage_flux_by_level(idr,wt_node)=scalar_transfer(idr)
      else
        drainage_flux_by_level(idr,wt_node)=scalar_transfer(idr)*dz_top_sat*khor(wt_node)/kd_drain(idr)
        do j=wt_node+1,bottom_node(idr)-1
          drainage_flux_by_level(idr,j)=scalar_transfer(idr)*level_parameters(1)%dz(j)*khor(j)/kd_drain(idr)
        end do
        raw_bottom=scalar_transfer(idr)*bottom_thickness(idr)*khor(bottom_node(idr))/kd_drain(idr)
        sum_previous=sum(drainage_flux_by_level(idr,1:bottom_node(idr)-1))
        drainage_flux_by_level(idr,bottom_node(idr))=scalar_transfer(idr)-sum_previous
        diagnostics%closure_correction(idr)=drainage_flux_by_level(idr,bottom_node(idr))-raw_bottom
      end if
      diagnostics%discharge_layer_bottom_depth(idr)=bottom_depth(idr)
      diagnostics%discharge_transmissivity(idr)=kd_drain(idr)
    end do

    diagnostics%evaluated=.true.
    diagnostics%water_table_node=wt_node
    diagnostics%groundwater_depth=wlev
    diagnostics%profile_anisotropy_factor=fac_aniso

  contains

    subroutine layer_for_depth(level_index, requested_depth)
      integer,intent(in)::level_index
      real(real64),intent(in)::requested_depth
      integer::node
      real(real64)::accum
      bottom_depth(level_index)=requested_depth
      node=wt_node
      accum=dz_top_sat
      kd_drain(level_index)=dz_top_sat*khor(wt_node)
      do while(requested_depth-wlev>accum)
        node=node+1
        if(node>n)then
          diagnostics%status=DRAIN_DIST_INVALID_PARAMETERS
          return
        end if
        accum=accum+level_parameters(1)%dz(node)
        kd_drain(level_index)=kd_drain(level_index)+level_parameters(1)%dz(node)*khor(node)
      end do
      kd_drain(level_index)=kd_drain(level_index)-(accum-(requested_depth-wlev))*khor(node)
      bottom_thickness(level_index)=level_parameters(1)%dz(node)-(accum-(requested_depth-wlev))
      bottom_node(level_index)=node
    end subroutine layer_for_depth

    subroutine layer_for_transmissivity(level_index, requested_kd)
      integer,intent(in)::level_index
      real(real64),intent(in)::requested_kd
      integer::node
      real(real64)::accum_kd,accum_depth
      node=wt_node
      accum_kd=dz_top_sat*khor(node)
      accum_depth=dz_top_sat
      do while(accum_kd<requested_kd)
        node=node+1
        if(node>n)then
          diagnostics%status=DRAIN_DIST_INVALID_PARAMETERS
          return
        end if
        accum_kd=accum_kd+level_parameters(1)%dz(node)*khor(node)
        accum_depth=accum_depth+level_parameters(1)%dz(node)
      end do
      bottom_thickness(level_index)=level_parameters(1)%dz(node)-(accum_kd-requested_kd)/khor(node)
      bottom_depth(level_index)=wlev+accum_depth+(requested_kd-accum_kd)/khor(node)
      bottom_node(level_index)=node
    end subroutine layer_for_transmissivity
  end subroutine distribute_multilevel_signed_divdra

  logical function valid_parameters(parameters) result(valid)
    type(drainage_distribution_parameters_t), intent(in) :: parameters
    integer :: i, n
    real(real64) :: cumulative_depth, tolerance

    valid = .false.
    n = parameters%active_nodes
    if (n <= 0) return
    if (.not. allocated(parameters%dz) .or. .not. allocated(parameters%zbotcp)) return
    if (.not. allocated(parameters%saturated_conductivity)) return
    if (.not. allocated(parameters%horizontal_anisotropy_factor)) return
    if (size(parameters%dz) /= n .or. size(parameters%zbotcp) /= n) return
    if (size(parameters%saturated_conductivity) /= n) return
    if (size(parameters%horizontal_anisotropy_factor) /= n) return
    if (any(.not. ieee_is_finite(parameters%dz)) .or. any(parameters%dz <= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%zbotcp)) .or. any(parameters%zbotcp >= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%saturated_conductivity)) .or. &
        any(parameters%saturated_conductivity <= 0.0_real64)) return
    if (any(.not. ieee_is_finite(parameters%horizontal_anisotropy_factor)) .or. &
        any(parameters%horizontal_anisotropy_factor <= 0.0_real64)) return
    if (.not. ieee_is_finite(parameters%drain_spacing) .or. parameters%drain_spacing <= 0.0_real64) return

    cumulative_depth = 0.0_real64
    do i = 1, n
      cumulative_depth = cumulative_depth + parameters%dz(i)
      tolerance = 4096.0_real64 * epsilon(1.0_real64) * max(1.0_real64, cumulative_depth)
      if (abs((-parameters%zbotcp(i)) - cumulative_depth) > tolerance) return
    end do
    valid = .true.
  end function valid_parameters

end module mod_drainage_spatial_distribution
