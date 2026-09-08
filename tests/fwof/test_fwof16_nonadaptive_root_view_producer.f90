program test_fwof16_nonadaptive_root_view_producer
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_root_uptake_input_assembly, only: crop_root_state_view_t, validate_crop_root_state_view, &
       CROP_ROOT_ASSEMBLY_OK
  use mod_nonadaptive_crop_root_view_producer, only: nonadaptive_root_profile_parameters_t, &
       crop_root_geometry_snapshot_t, nonadaptive_root_view_diagnostics_t, &
       build_nonadaptive_crop_root_state_view, NONADAPT_ROOT_VIEW_OK, NONADAPT_ROOT_VIEW_INVALID_GRID, &
       NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH, NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH, &
       NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE, NONADAPT_ROOT_VIEW_ZERO_DENSITY_INTEGRAL, &
       NONADAPT_ROOT_VIEW_AMBIGUOUS_NODE_BOUNDARY
  implicit none

  type(nonadaptive_root_profile_parameters_t) :: p, p_before, invalid
  type(crop_root_geometry_snapshot_t) :: inactive, zero_root, a, b, a_before
  type(crop_root_state_view_t) :: view, oracle, a1, bview, a2
  type(nonadaptive_root_view_diagnostics_t) :: diag
  integer :: status
  real(real64) :: max_diff

  inactive%crop_emerged = .false.
  inactive%current_root_depth = ieee_value(0.0_real64, ieee_quiet_nan)
  p%active_nodes = 5
  call build_nonadaptive_crop_root_state_view(p, inactive, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK .and. diag%built, 'inactive status')
  call require(.not. view%crop_emerged .and. view%rooted_nodes == 0, 'inactive canonical fields')
  call require(.not. allocated(view%cumulative_root_fraction), 'inactive no distribution')
  call require(.not. diag%grid_consumed .and. .not. diag%density_table_consumed, 'inactive dependencies')
  write(*,'(A)') 'FWOF16_INACTIVE_CROP_DEPENDENCY_FREE=PASS'

  zero_root%crop_emerged = .true.
  zero_root%current_root_depth = 0.0_real64
  call build_nonadaptive_crop_root_state_view(p, zero_root, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK .and. diag%built .and. diag%output_validated, 'zero root status')
  call require(view%crop_emerged .and. view%rooted_nodes == 0, 'zero root fields')
  call require(.not. allocated(view%cumulative_root_fraction), 'zero root no distribution')
  call require(.not. diag%grid_consumed .and. .not. diag%density_table_consumed, 'zero root dependencies')
  write(*,'(A)') 'FWOF16_EMERGED_ZERO_ROOT_DEPENDENCY_FREE=PASS'

  call configure_parameters(p)
  p_before = p
  a%crop_emerged = .true.
  a%current_root_depth = 60.0_real64
  a_before = a
  call build_nonadaptive_crop_root_state_view(p, a, a1, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK .and. diag%built, 'A built')
  call require(diag%rooted_nodes == 4 .and. diag%maximum_rooted_nodes == 5, 'A node mapping')
  call legacy_nonadaptive_oracle(p, a, oracle)
  call require(same_view(a1, oracle, 2.0e-15_real64, max_diff), 'A legacy oracle')
  call require(max_diff <= 2.0e-15_real64, 'A oracle tolerance')
  call validate_crop_root_state_view(a1, p%active_nodes, status)
  call require(status == CROP_ROOT_ASSEMBLY_OK, 'A F-WOF13 validation')
  call require(same_parameters(p, p_before), 'parameters read only')
  call require(same_geometry(a, a_before), 'geometry read only')
  write(*,'(A,ES24.16E3)') 'FWOF16_MULTI_NODE_B110_ORACLE_MAX_ABS_DIFF=', max_diff
  write(*,'(A)') 'FWOF16_MULTI_NODE_NONUNIFORM_RDCTB_B110_ORACLE=PASS'
  write(*,'(A)') 'FWOF16_FWO13_VIEW_VALIDATION=PASS'
  write(*,'(A)') 'FWOF16_INPUTS_READ_ONLY=PASS'

  a%current_root_depth = 5.0_real64
  call build_nonadaptive_crop_root_state_view(p, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK .and. view%rooted_nodes == 1, 'one node rooted')
  call require(allocated(view%cumulative_root_fraction) .and. size(view%cumulative_root_fraction) == 2, 'one node shape')
  call require(same_bits(view%cumulative_root_fraction(1), 0.0_real64), 'one node zero endpoint')
  call require(same_bits(view%cumulative_root_fraction(2), 1.0_real64), 'one node one endpoint')
  write(*,'(A)') 'FWOF16_ONE_NODE_ENDPOINTS=PASS'

  a%current_root_depth = 25.0_real64 + 5.0e-9_real64
  call build_nonadaptive_crop_root_state_view(p, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_AMBIGUOUS_NODE_BOUNDARY, 'boundary ambiguity')
  write(*,'(A)') 'FWOF16_NODE_BOUNDARY_AMBIGUITY_FAIL_CLOSED=PASS'

  invalid = p
  invalid%node_bottom_depth(3) = invalid%node_bottom_depth(2)
  a%current_root_depth = 60.0_real64
  call build_nonadaptive_crop_root_state_view(invalid, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_INVALID_GRID, 'invalid grid')

  invalid = p
  invalid%maximum_root_depth = 120.0_real64
  call build_nonadaptive_crop_root_state_view(invalid, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_INVALID_MAX_ROOT_DEPTH, 'invalid max depth')

  invalid = p
  a%current_root_depth = 91.0_real64
  call build_nonadaptive_crop_root_state_view(invalid, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_INVALID_ROOT_DEPTH, 'invalid root depth')

  invalid = p
  invalid%relative_root_depth(1) = 0.1_real64
  a%current_root_depth = 60.0_real64
  call build_nonadaptive_crop_root_state_view(invalid, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_INVALID_DENSITY_TABLE, 'invalid table endpoint')

  invalid = p
  invalid%relative_root_density = 0.0_real64
  call build_nonadaptive_crop_root_state_view(invalid, a, view, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_ZERO_DENSITY_INTEGRAL, 'zero density integral')
  write(*,'(A)') 'FWOF16_INVALID_GRID_DEPTH_TABLE_FAIL_CLOSED=PASS'

  call configure_parameters(p)
  a%crop_emerged = .true.
  a%current_root_depth = 60.0_real64
  b%crop_emerged = .true.
  b%current_root_depth = 35.0_real64
  call build_nonadaptive_crop_root_state_view(p, a, a1, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK, 'A1 status')
  call build_nonadaptive_crop_root_state_view(p, b, bview, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK, 'B status')
  call require(.not. same_view_bits(a1, bview), 'B differs')
  call build_nonadaptive_crop_root_state_view(p, a, a2, diag)
  call require(diag%status == NONADAPT_ROOT_VIEW_OK, 'A2 status')
  call require(same_view_bits(a1, a2), 'A/B/A identity')
  write(*,'(A)') 'FWOF16_A_B_A_BITWISE_IDENTITY=PASS'
  write(*,'(A)') 'FWOF16_NONADAPTIVE_ROOT_VIEW_PRODUCER_TEST PASS'

contains

  subroutine configure_parameters(x)
    type(nonadaptive_root_profile_parameters_t), intent(out) :: x
    x%active_nodes = 5
    x%maximum_root_depth = 90.0_real64
    allocate(x%node_bottom_depth(5), x%relative_root_depth(4), x%relative_root_density(4))
    x%node_bottom_depth = [10.0_real64, 25.0_real64, 45.0_real64, 70.0_real64, 100.0_real64]
    x%relative_root_depth = [0.0_real64, 0.3_real64, 0.7_real64, 1.0_real64]
    x%relative_root_density = [2.0_real64, 1.0_real64, 0.5_real64, 0.2_real64]
  end subroutine configure_parameters

  subroutine legacy_nonadaptive_oracle(parameters, snapshot, result)
    type(nonadaptive_root_profile_parameters_t), intent(in) :: parameters
    type(crop_root_geometry_snapshot_t), intent(in) :: snapshot
    type(crop_root_state_view_t), intent(out) :: result
    real(real64), allocatable :: zbotcp(:), rootdist(:), cumdens(:), rdctb(:)
    real(real64) :: rdepth, sumv, rd_noddrz
    integer :: i, node, mxnoddrz, macroptb

    result = crop_root_state_view_t()
    result%crop_emerged = snapshot%crop_emerged
    if (.not. snapshot%crop_emerged .or. snapshot%current_root_depth < 1.0e-14_real64) return

    allocate(zbotcp(parameters%active_nodes))
    zbotcp = -parameters%node_bottom_depth

    node = 1
    do
      if (zbotcp(node) < (-snapshot%current_root_depth + 1.0e-8_real64)) exit
      node = node + 1
    end do
    result%rooted_nodes = node

    mxnoddrz = 1
    do
      if (zbotcp(mxnoddrz) < (-parameters%maximum_root_depth + 1.0e-8_real64)) exit
      mxnoddrz = mxnoddrz + 1
    end do

    macroptb = 2 * size(parameters%relative_root_depth)
    allocate(rdctb(macroptb))
    do i = 1, size(parameters%relative_root_depth)
      rdctb(2*i-1) = parameters%relative_root_depth(i)
      rdctb(2*i) = parameters%relative_root_density(i)
    end do

    allocate(rootdist((mxnoddrz+1)*2), cumdens((mxnoddrz+1)*2))
    rootdist = 0.0_real64
    cumdens = 0.0_real64
    rootdist(2) = legacy_afgen(rdctb, macroptb, 0.0_real64)
    do i = 1, mxnoddrz
      rdepth = min(1.0_real64, abs(zbotcp(i) / parameters%maximum_root_depth))
      rootdist(i*2+1) = rdepth
      rootdist(i*2+2) = legacy_afgen(rdctb, macroptb, rdepth)
    end do

    sumv = 0.0_real64
    cumdens(2) = 0.0_real64
    do i = 1, mxnoddrz
      sumv = sumv + (rootdist(i*2) + rootdist(i*2+2)) * 0.5_real64 * &
              (rootdist(i*2+1) - rootdist(i*2-1))
      cumdens(i*2+1) = rootdist(i*2+1)
      cumdens(i*2+2) = sumv
    end do
    do i = 1, mxnoddrz
      cumdens(i*2+2) = cumdens(i*2+2) / sumv
    end do

    allocate(result%cumulative_root_fraction(result%rooted_nodes+1))
    result%cumulative_root_fraction = 0.0_real64
    result%cumulative_root_fraction(1) = 0.0_real64
    rd_noddrz = abs(zbotcp(result%rooted_nodes))
    do i = 1, result%rooted_nodes
      rdepth = abs(zbotcp(i) / rd_noddrz)
      result%cumulative_root_fraction(i+1) = legacy_afgen(cumdens, (mxnoddrz+1)*2, rdepth)
    end do
    result%cumulative_root_fraction(result%rooted_nodes+1) = 1.0_real64
  end subroutine legacy_nonadaptive_oracle

  real(real64) function legacy_afgen(table, iltab, x) result(value)
    integer, intent(in) :: iltab
    real(real64), intent(in) :: table(iltab), x
    integer :: i
    real(real64) :: slope

    if (table(1) >= x) then
      value = table(2)
      return
    end if
    do i = 3, iltab-1, 2
      if (table(i) >= x) then
        slope = (table(i+1)-table(i-1))/(table(i)-table(i-2))
        value = table(i-1) + (x-table(i-2))*slope
        return
      end if
      if (table(i) < table(i-2)) then
        value = table(i-1)
        return
      end if
    end do
    value = table(iltab)
  end function legacy_afgen

  logical function same_view(left, right, tolerance, max_diff) result(equal)
    type(crop_root_state_view_t), intent(in) :: left, right
    real(real64), intent(in) :: tolerance
    real(real64), intent(out) :: max_diff
    max_diff = 0.0_real64
    equal = left%crop_emerged .eqv. right%crop_emerged
    if (.not. equal) return
    equal = left%rooted_nodes == right%rooted_nodes
    if (.not. equal) return
    equal = allocated(left%cumulative_root_fraction) .eqv. allocated(right%cumulative_root_fraction)
    if (.not. equal .or. .not. allocated(left%cumulative_root_fraction)) return
    equal = size(left%cumulative_root_fraction) == size(right%cumulative_root_fraction)
    if (.not. equal) return
    max_diff = maxval(abs(left%cumulative_root_fraction-right%cumulative_root_fraction))
    equal = max_diff <= tolerance
  end function same_view

  logical function same_view_bits(left, right) result(equal)
    type(crop_root_state_view_t), intent(in) :: left, right
    integer :: i
    equal = left%crop_emerged .eqv. right%crop_emerged
    if (.not. equal) return
    equal = left%rooted_nodes == right%rooted_nodes
    if (.not. equal) return
    equal = allocated(left%cumulative_root_fraction) .eqv. allocated(right%cumulative_root_fraction)
    if (.not. equal) return
    if (.not. allocated(left%cumulative_root_fraction)) return
    if (size(left%cumulative_root_fraction) /= size(right%cumulative_root_fraction)) then
      equal = .false.
      return
    end if
    do i = 1, size(left%cumulative_root_fraction)
      if (.not. same_bits(left%cumulative_root_fraction(i), right%cumulative_root_fraction(i))) then
        equal = .false.
        return
      end if
    end do
  end function same_view_bits

  logical function same_parameters(left, right) result(equal)
    type(nonadaptive_root_profile_parameters_t), intent(in) :: left, right
    integer :: i
    equal = left%active_nodes == right%active_nodes .and. same_bits(left%maximum_root_depth, right%maximum_root_depth)
    if (.not. equal) return
    equal = allocated(left%node_bottom_depth) .eqv. allocated(right%node_bottom_depth)
    equal = equal .and. allocated(left%relative_root_depth) .eqv. allocated(right%relative_root_depth)
    equal = equal .and. allocated(left%relative_root_density) .eqv. allocated(right%relative_root_density)
    if (.not. equal) return
    if (allocated(left%node_bottom_depth)) then
      if (size(left%node_bottom_depth) /= size(right%node_bottom_depth)) then; equal=.false.; return; end if
      do i=1,size(left%node_bottom_depth)
        if (.not. same_bits(left%node_bottom_depth(i),right%node_bottom_depth(i))) then; equal=.false.; return; end if
      end do
    end if
    if (allocated(left%relative_root_depth)) then
      if (size(left%relative_root_depth) /= size(right%relative_root_depth)) then; equal=.false.; return; end if
      do i=1,size(left%relative_root_depth)
        if (.not. same_bits(left%relative_root_depth(i),right%relative_root_depth(i))) then; equal=.false.; return; end if
      end do
    end if
    if (allocated(left%relative_root_density)) then
      if (size(left%relative_root_density) /= size(right%relative_root_density)) then; equal=.false.; return; end if
      do i=1,size(left%relative_root_density)
        if (.not. same_bits(left%relative_root_density(i),right%relative_root_density(i))) then; equal=.false.; return; end if
      end do
    end if
  end function same_parameters

  logical function same_geometry(left, right) result(equal)
    type(crop_root_geometry_snapshot_t), intent(in) :: left, right
    equal = (left%crop_emerged .eqv. right%crop_emerged) .and. &
            same_bits(left%current_root_depth, right%current_root_depth)
  end function same_geometry

  logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FWOF16_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fwof16_nonadaptive_root_view_producer
