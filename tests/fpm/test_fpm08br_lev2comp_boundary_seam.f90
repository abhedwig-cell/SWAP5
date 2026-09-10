program test_fpm08br_lev2comp_boundary_seam
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, DRAIN_DIST_OK, &
       DRAIN_DIST_INVALID_HYDRAULIC_VIEW
  implicit none

  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: view
  type(drainage_node_transfer_t) :: flux
  type(drainage_distribution_diagnostics_t) :: diag
  real(real64), parameter :: q = 0.7_real64
  real(real64), parameter :: seam = 1.0e-10_real64
  real(real64), parameter :: tol = 4096.0_real64*epsilon(1.0_real64)

  call configure(p)

  ! Internal boundary at 40 cm: frozen Lev2Comp keeps compartment 2 at the
  ! boundary and throughout the +1e-10 cm seam below it.
  call evaluate_at_depth(40.0_real64, 2, 0, 'exact boundary')
  call require(close(diag%saturated_top_thickness,0.0_real64), 'exact boundary top thickness')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q), 'exact boundary mass closure')
  write(*,'(A)') 'FPM08BR_EXACT_INTERNAL_BOUNDARY_SHALLOWER_COMPARTMENT=PASS'

  call evaluate_at_depth(40.0_real64 + 0.5_real64*seam, 2, -1, 'half seam below boundary')
  call require(close(diag%saturated_top_thickness,-0.5_real64*seam), 'half seam top thickness')
  call require(flux%soil_to_drain_rate(2) < 0.0_real64, 'half seam legacy signed top contribution')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q), 'half seam mass closure')
  write(*,'(A)') 'FPM08BR_HALF_SEAM_BELOW_BOUNDARY_SHALLOWER_COMPARTMENT=PASS'

  call evaluate_at_depth(40.0_real64 + seam, 2, -1, 'full seam below boundary')
  call require(close(diag%saturated_top_thickness,-seam), 'full seam top thickness')
  call require(flux%soil_to_drain_rate(2) < 0.0_real64, 'full seam legacy signed top contribution')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q), 'full seam mass closure')
  write(*,'(A)') 'FPM08BR_FULL_SEAM_BELOW_BOUNDARY_SHALLOWER_COMPARTMENT=PASS'

  call evaluate_at_depth(40.0_real64 + 1.1_real64*seam, 3, 1, 'beyond seam')
  call require(diag%saturated_top_thickness > 0.0_real64, 'beyond seam positive top thickness')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q), 'beyond seam mass closure')
  write(*,'(A)') 'FPM08BR_BEYOND_SEAM_NEXT_COMPARTMENT=PASS'

  ! A second internal boundary proves the rule is geometric rather than tied
  ! to one fixed node index.
  call evaluate_at_depth(20.0_real64 + 0.5_real64*seam, 1, -1, 'first boundary seam')
  call require(flux%soil_to_drain_rate(1) < 0.0_real64, 'first boundary signed top contribution')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q), 'first boundary mass closure')
  write(*,'(A)') 'FPM08BR_GENERIC_INTERNAL_BOUNDARY_SEAM=PASS'

  ! Remediation does not open the profile-bottom boundary.
  view = process_hydraulic_view_t()
  view%groundwater_level = -100.0_real64
  call distribute_single_level_positive_divdra(p,view,q,flux,diag)
  call require(diag%status == DRAIN_DIST_INVALID_HYDRAULIC_VIEW, 'profile bottom remains invalid')
  write(*,'(A)') 'FPM08BR_PROFILE_BOTTOM_REMAINS_FAIL_CLOSED=PASS'

  write(*,'(A)') 'FPM08BR_EXACT_SCALAR_TO_NODE_MASS_IDENTITY=PASS'
  write(*,'(A)') 'FPM08BR_LEV2COMP_BOUNDARY_SEAM_TEST PASS'

contains

  subroutine configure(parameters)
    type(drainage_distribution_parameters_t), intent(out) :: parameters
    parameters%active_nodes = 5
    allocate(parameters%dz(5),parameters%zbotcp(5),parameters%saturated_conductivity(5), &
         parameters%horizontal_anisotropy_factor(5))
    parameters%dz = 20.0_real64
    parameters%zbotcp = [-20.0_real64,-40.0_real64,-60.0_real64,-80.0_real64,-100.0_real64]
    parameters%saturated_conductivity = 10.0_real64
    parameters%horizontal_anisotropy_factor = 1.0_real64
    parameters%drain_spacing = 400.0_real64
  end subroutine configure

  subroutine evaluate_at_depth(depth, expected_node, top_sign, label)
    real(real64), intent(in) :: depth
    integer, intent(in) :: expected_node, top_sign
    character(len=*), intent(in) :: label

    view = process_hydraulic_view_t()
    view%groundwater_level = -depth
    call distribute_single_level_positive_divdra(p,view,q,flux,diag)
    call require(diag%status == DRAIN_DIST_OK .and. diag%evaluated, trim(label)//' accepted')
    call require(diag%water_table_node == expected_node, trim(label)//' water table node')
    if (top_sign < 0) call require(diag%saturated_top_thickness < 0.0_real64, trim(label)//' negative top thickness')
    if (top_sign > 0) call require(diag%saturated_top_thickness > 0.0_real64, trim(label)//' positive top thickness')
  end subroutine evaluate_at_depth

  real(real64) function ordered_sum(a) result(total)
    real(real64), intent(in) :: a(:)
    integer :: i
    total = 0.0_real64
    do i = 1,size(a)
      total = total + a(i)
    end do
  end function ordered_sum

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia)
    ib = transfer(b,ib)
    equal = ia == ib
  end function same_bits

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08BR_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpm08br_lev2comp_boundary_seam
