program test_fwof17_option_aware_root_geometry
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_crop_root_uptake_input_assembly, only: crop_root_state_view_t, validate_crop_root_state_view, &
       CROP_ROOT_ASSEMBLY_OK
  use mod_nonadaptive_crop_root_view_producer, only: crop_root_geometry_snapshot_t, &
       nonadaptive_root_profile_parameters_t, nonadaptive_root_view_diagnostics_t, &
       build_nonadaptive_crop_root_state_view, NONADAPT_ROOT_VIEW_OK
  use mod_crop_root_geometry_snapshot_producer, only: root_depth_table_t, crop_root_geometry_diagnostics_t, &
       build_swrd1_root_geometry_snapshot, build_swrd2_root_geometry_snapshot, build_swrd3_root_geometry_snapshot, &
       CROP_ROOT_GEOMETRY_OK, CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH, CROP_ROOT_GEOMETRY_INVALID_DVS, &
       CROP_ROOT_GEOMETRY_INVALID_ROOT_BIOMASS, CROP_ROOT_GEOMETRY_INVALID_COMMITTED_DEPTH, &
       CROP_ROOT_GEOMETRY_INVALID_TABLE
  implicit none

  type(root_depth_table_t) :: rdtb, rlwtb, before, bad
  type(crop_root_geometry_snapshot_t) :: snapshot, a1, b, a2
  type(crop_root_geometry_diagnostics_t) :: diag
  type(nonadaptive_root_profile_parameters_t) :: profile
  type(nonadaptive_root_view_diagnostics_t) :: view_diag
  type(crop_root_state_view_t) :: view
  real(real64) :: nanv, expected
  integer :: status

  nanv = ieee_value(0.0_real64, ieee_quiet_nan)

  call build_swrd1_root_geometry_snapshot(.false., nanv, nanv, rdtb, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. diag%built, 'inactive swrd1')
  call require(.not. snapshot%crop_emerged .and. same_bits(snapshot%current_root_depth, 0.0_real64), 'inactive swrd1 snapshot')
  call require(.not. diag%committed_crop_state_consumed .and. .not. diag%interpolation_table_consumed, 'inactive swrd1 dependencies')

  call build_swrd2_root_geometry_snapshot(.false., nanv, nanv, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. diag%built, 'inactive swrd2')
  call require(.not. diag%committed_crop_state_consumed .and. .not. diag%interpolation_table_consumed, 'inactive swrd2 dependencies')

  call build_swrd3_root_geometry_snapshot(.false., nanv, nanv, rlwtb, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. diag%built, 'inactive swrd3')
  call require(.not. diag%committed_crop_state_consumed .and. .not. diag%interpolation_table_consumed, 'inactive swrd3 dependencies')
  write(*,'(A)') 'FWOF17_INACTIVE_ALL_MODES_DEPENDENCY_FREE=PASS'

  call configure_rdtb(rdtb)
  before = rdtb

  call build_swrd1_root_geometry_snapshot(.true., -1.0_real64, 90.0_real64, rdtb, snapshot, diag)
  expected = min(legacy_afgen(rdtb, -1.0_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. diag%built, 'swrd1 lower endpoint status')
  call require(same_bits(snapshot%current_root_depth, expected), 'swrd1 lower endpoint')

  call build_swrd1_root_geometry_snapshot(.true., 0.25_real64, 90.0_real64, rdtb, snapshot, diag)
  expected = min(legacy_afgen(rdtb, 0.25_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK, 'swrd1 interior status')
  call require(same_bits(snapshot%current_root_depth, expected), 'swrd1 interior')

  call build_swrd1_root_geometry_snapshot(.true., 3.0_real64, 90.0_real64, rdtb, snapshot, diag)
  expected = min(legacy_afgen(rdtb, 3.0_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK, 'swrd1 upper endpoint status')
  call require(same_bits(snapshot%current_root_depth, expected), 'swrd1 upper endpoint clip')
  call require(same_table(rdtb, before), 'swrd1 table read only')
  write(*,'(A)') 'FWOF17_SWRD1_AFGEN_B110_IDENTITY=PASS'

  call build_swrd2_root_geometry_snapshot(.true., 37.5_real64, 90.0_real64, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. diag%built, 'swrd2 status')
  call require(snapshot%crop_emerged .and. same_bits(snapshot%current_root_depth, 37.5_real64), 'swrd2 pass through')
  call require(diag%committed_crop_state_consumed .and. .not. diag%interpolation_table_consumed, 'swrd2 ownership')
  write(*,'(A)') 'FWOF17_SWRD2_COMMITTED_DEPTH_BITWISE_PASSTHROUGH=PASS'

  call configure_rlwtb(rlwtb)
  before = rlwtb

  call build_swrd3_root_geometry_snapshot(.true., 0.0_real64, 90.0_real64, rlwtb, snapshot, diag)
  expected = min(legacy_afgen(rlwtb, 0.0_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. same_bits(snapshot%current_root_depth, expected), 'swrd3 lower endpoint')

  call build_swrd3_root_geometry_snapshot(.true., 200.0_real64, 90.0_real64, rlwtb, snapshot, diag)
  expected = min(legacy_afgen(rlwtb, 200.0_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. same_bits(snapshot%current_root_depth, expected), 'swrd3 interior')

  call build_swrd3_root_geometry_snapshot(.true., 600.0_real64, 90.0_real64, rlwtb, snapshot, diag)
  expected = min(legacy_afgen(rlwtb, 600.0_real64), 90.0_real64)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. same_bits(snapshot%current_root_depth, expected), 'swrd3 upper clip')
  call require(same_table(rlwtb, before), 'swrd3 table read only')
  write(*,'(A)') 'FWOF17_SWRD3_AFGEN_B110_IDENTITY=PASS'
  write(*,'(A)') 'FWOF17_INPUT_TABLES_READ_ONLY=PASS'

  call build_swrd1_root_geometry_snapshot(.true., 0.5_real64, 0.0_real64, rdtb, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_INVALID_MAX_DEPTH, 'invalid max depth')
  call build_swrd1_root_geometry_snapshot(.true., nanv, 90.0_real64, rdtb, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_INVALID_DVS, 'invalid dvs')

  bad = rdtb
  bad%x(3) = bad%x(2)
  call build_swrd1_root_geometry_snapshot(.true., 0.5_real64, 90.0_real64, bad, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_INVALID_TABLE, 'invalid rdtb')

  call build_swrd2_root_geometry_snapshot(.true., 91.0_real64, 90.0_real64, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_INVALID_COMMITTED_DEPTH, 'invalid swrd2 depth')

  call build_swrd3_root_geometry_snapshot(.true., -1.0_real64, 90.0_real64, rlwtb, snapshot, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_INVALID_ROOT_BIOMASS, 'invalid wrt')
  write(*,'(A)') 'FWOF17_INVALID_ACTIVE_INPUTS_FAIL_CLOSED=PASS'

  call build_swrd1_root_geometry_snapshot(.true., 0.5_real64, 90.0_real64, rdtb, a1, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK, 'A1')
  call build_swrd1_root_geometry_snapshot(.true., 1.25_real64, 90.0_real64, rdtb, b, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK, 'B')
  call require(.not. same_snapshot_bits(a1, b), 'B differs')
  call build_swrd1_root_geometry_snapshot(.true., 0.5_real64, 90.0_real64, rdtb, a2, diag)
  call require(diag%status == CROP_ROOT_GEOMETRY_OK .and. same_snapshot_bits(a1, a2), 'A/B/A')
  write(*,'(A)') 'FWOF17_A_B_A_BITWISE_IDENTITY=PASS'

  call configure_profile(profile)
  call build_nonadaptive_crop_root_state_view(profile, a1, view, view_diag)
  call require(view_diag%status == NONADAPT_ROOT_VIEW_OK .and. view_diag%built, 'F-WOF16 composition status')
  call require(view%crop_emerged .and. view%rooted_nodes == 3, 'F-WOF16 composition rooted nodes')
  call validate_crop_root_state_view(view, profile%active_nodes, status)
  call require(status == CROP_ROOT_ASSEMBLY_OK, 'F-WOF13 validation')
  write(*,'(A,ES24.16E3)') 'FWOF17_COMPOSED_ROOT_DEPTH=', a1%current_root_depth
  write(*,'(A,I0)') 'FWOF17_COMPOSED_ROOTED_NODES=', view%rooted_nodes
  write(*,'(A)') 'FWOF17_FWO16_NONADAPTIVE_VIEW_COMPOSITION=PASS'
  write(*,'(A)') 'FWOF17_FWO13_VIEW_VALIDATION=PASS'
  write(*,'(A)') 'FWOF17_OPTION_AWARE_ROOT_GEOMETRY_TEST PASS'

contains

  subroutine configure_rdtb(table)
    type(root_depth_table_t), intent(out) :: table
    allocate(table%x(4), table%root_depth(4))
    table%x = [0.0_real64, 0.5_real64, 1.5_real64, 2.0_real64]
    table%root_depth = [10.0_real64, 40.0_real64, 80.0_real64, 100.0_real64]
  end subroutine configure_rdtb

  subroutine configure_rlwtb(table)
    type(root_depth_table_t), intent(out) :: table
    allocate(table%x(4), table%root_depth(4))
    table%x = [0.0_real64, 100.0_real64, 300.0_real64, 500.0_real64]
    table%root_depth = [5.0_real64, 30.0_real64, 70.0_real64, 120.0_real64]
  end subroutine configure_rlwtb

  subroutine configure_profile(p)
    type(nonadaptive_root_profile_parameters_t), intent(out) :: p
    p%active_nodes = 5
    p%maximum_root_depth = 90.0_real64
    allocate(p%node_bottom_depth(5), p%relative_root_depth(4), p%relative_root_density(4))
    p%node_bottom_depth = [10.0_real64, 25.0_real64, 45.0_real64, 70.0_real64, 100.0_real64]
    p%relative_root_depth = [0.0_real64, 0.3_real64, 0.7_real64, 1.0_real64]
    p%relative_root_density = [2.0_real64, 1.0_real64, 0.5_real64, 0.2_real64]
  end subroutine configure_profile

  real(real64) function legacy_afgen(table, query) result(value)
    type(root_depth_table_t), intent(in) :: table
    real(real64), intent(in) :: query
    real(real64), allocatable :: packed(:)
    integer :: i, n

    n = size(table%x)
    allocate(packed(2*n))
    do i = 1, n
      packed(2*i-1) = table%x(i)
      packed(2*i) = table%root_depth(i)
    end do
    value = legacy_afgen_packed(packed, query)
  end function legacy_afgen

  real(real64) function legacy_afgen_packed(table, x) result(value)
    real(real64), intent(in) :: table(:), x
    integer :: i, iltab
    real(real64) :: slope

    iltab = size(table)
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
  end function legacy_afgen_packed

  logical function same_table(left, right) result(equal)
    type(root_depth_table_t), intent(in) :: left, right
    integer :: i

    equal = allocated(left%x) .eqv. allocated(right%x)
    equal = equal .and. (allocated(left%root_depth) .eqv. allocated(right%root_depth))
    if (.not. equal) return
    if (.not. allocated(left%x)) return
    if (size(left%x) /= size(right%x) .or. size(left%root_depth) /= size(right%root_depth)) then
      equal = .false.
      return
    end if
    do i = 1, size(left%x)
      if (.not. same_bits(left%x(i), right%x(i)) .or. .not. same_bits(left%root_depth(i), right%root_depth(i))) then
        equal = .false.
        return
      end if
    end do
  end function same_table

  logical function same_snapshot_bits(left, right) result(equal)
    type(crop_root_geometry_snapshot_t), intent(in) :: left, right
    equal = (left%crop_emerged .eqv. right%crop_emerged) .and. &
            same_bits(left%current_root_depth, right%current_root_depth)
  end function same_snapshot_bits

  logical function same_bits(left, right) result(equal)
    real(real64), intent(in) :: left, right
    integer(int64) :: li, ri
    li = transfer(left, li)
    ri = transfer(right, ri)
    equal = li == ri
  end function same_bits

  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(A)') 'FAIL: '//trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fwof17_option_aware_root_geometry
