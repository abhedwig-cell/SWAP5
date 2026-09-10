program test_fpm08b_drainage_spatial_distribution
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t, drainage_node_transfer_t, &
       drainage_distribution_diagnostics_t, distribute_single_level_positive_divdra, DRAIN_DIST_OK, &
       DRAIN_DIST_INVALID_PARAMETERS, DRAIN_DIST_INVALID_HYDRAULIC_VIEW, DRAIN_DIST_INVALID_TRANSFER, &
       DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
  implicit none

  type(drainage_distribution_parameters_t) :: p, p_variant
  type(process_hydraulic_view_t) :: view, view_b, bad_view
  type(drainage_node_transfer_t) :: a1, a2, b, flux
  type(drainage_distribution_diagnostics_t) :: da1, da2, db, diag
  real(real64), parameter :: tol = 4096.0_real64*epsilon(1.0_real64)
  real(real64), parameter :: q1 = 0.7_real64
  real(real64), parameter :: q2 = 0.8_real64
  real(real64) :: mass_sum

  call configure_base(p)
  view = process_hydraulic_view_t()
  view%groundwater_level = -30.0_real64

  ! Full saturated transmissivity interval: wt node has 10 cm saturated,
  ! nodes 3:5 each 20 cm. Homogeneous K gives weights 1:2:2:2.
  p%drain_spacing = 400.0_real64
  call distribute_single_level_positive_divdra(p, view, q1, a1, da1)
  call require(da1%status == DRAIN_DIST_OK .and. da1%evaluated, 'full profile status')
  call require(da1%water_table_node == 2 .and. da1%discharge_bottom_node == 5, 'full profile node bounds')
  call require(close(da1%saturated_top_thickness,10.0_real64), 'top saturated thickness')
  call require(close(da1%discharge_layer_bottom_depth,100.0_real64), 'full profile discharge bottom')
  call require(close(da1%discharge_transmissivity,700.0_real64), 'full profile transmissivity')
  call require(all_close(a1%soil_to_drain_rate,[0.0_real64,0.1_real64,0.2_real64,0.2_real64,0.2_real64]), &
       'principal transmissivity partition')
  mass_sum = ordered_sum(a1%soil_to_drain_rate)
  call require(same_bits(mass_sum,q1), 'full profile exact scalar-to-node closure')
  call require(abs(da1%closure_correction) <= tol*max(1.0_real64,abs(q1)), 'full profile closure correction bounded')
  write(*,'(A)') 'FPM08B_PRINCIPAL_TRANSMISSIVITY_PARTITION=PASS'
  write(*,'(A)') 'FPM08B_EXACT_SCALAR_TO_NODE_MASS_IDENTITY=PASS'

  ! Spacing limit: dmax=30 + 0.25*160 = 70 cm.
  ! Active thicknesses are 10,20,10 cm, yielding weights 1:2:1.
  p%drain_spacing = 160.0_real64
  call distribute_single_level_positive_divdra(p, view, q2, flux, diag)
  call require(diag%status == DRAIN_DIST_OK, 'spacing-limited status')
  call require(diag%water_table_node == 2 .and. diag%discharge_bottom_node == 4, 'spacing-limited bounds')
  call require(close(diag%discharge_bottom_thickness,10.0_real64), 'spacing-limited bottom thickness')
  call require(close(diag%discharge_layer_bottom_depth,70.0_real64), 'spacing-limited depth')
  call require(close(diag%discharge_transmissivity,400.0_real64), 'spacing-limited transmissivity')
  call require(all_close(flux%soil_to_drain_rate,[0.0_real64,0.2_real64,0.4_real64,0.2_real64,0.0_real64]), &
       'spacing-limited partition')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q2), 'spacing-limited exact closure')
  write(*,'(A)') 'FPM08B_SPACING_LIMITED_DISCHARGE_LAYER=PASS'

  ! Uniform horizontal anisotropy factor 4 gives FacAniso=sqrt(10/40)=0.5.
  ! dmax=30 + 0.25*160*0.5 = 50 cm, splitting equally over 10+10 cm.
  p_variant = p
  p_variant%horizontal_anisotropy_factor = 4.0_real64
  call distribute_single_level_positive_divdra(p_variant, view, q2, flux, diag)
  call require(diag%status == DRAIN_DIST_OK, 'anisotropic status')
  call require(close(diag%profile_anisotropy_factor,0.5_real64), 'anisotropy factor')
  call require(diag%water_table_node == 2 .and. diag%discharge_bottom_node == 3, 'anisotropic bounds')
  call require(close(diag%discharge_layer_bottom_depth,50.0_real64), 'anisotropic depth')
  call require(close(diag%discharge_transmissivity,800.0_real64), 'anisotropic transmissivity')
  call require(all_close(flux%soil_to_drain_rate,[0.0_real64,0.4_real64,0.4_real64,0.0_real64,0.0_real64]), &
       'anisotropic partition')
  call require(same_bits(ordered_sum(flux%soil_to_drain_rate),q2), 'anisotropic exact closure')
  write(*,'(A)') 'FPM08B_ANISOTROPY_DISCHARGE_DEPTH=PASS'

  ! Exact zero is dependency-free after immutable shape validation.
  bad_view = process_hydraulic_view_t()
  bad_view%groundwater_level = ieee_value(0.0_real64,ieee_quiet_nan)
  call distribute_single_level_positive_divdra(p,bad_view,0.0_real64,flux,diag)
  call require(diag%status == DRAIN_DIST_OK .and. diag%zero_transfer, 'zero transfer route')
  call require(all_close(flux%soil_to_drain_rate,[0.0_real64,0.0_real64,0.0_real64,0.0_real64,0.0_real64]), &
       'zero transfer vector')
  write(*,'(A)') 'FPM08B_ZERO_TRANSFER_NO_HYDRAULIC_DEPENDENCY=PASS'

  call distribute_single_level_positive_divdra(p,view,0.5e-10_real64,flux,diag)
  call require(diag%status == DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE, 'legacy small interval held')
  call distribute_single_level_positive_divdra(p,view,-0.1_real64,flux,diag)
  call require(diag%status == DRAIN_DIST_INVALID_TRANSFER, 'negative infiltration held')
  write(*,'(A)') 'FPM08B_HELD_TRANSFER_DOMAINS_FAIL_CLOSED=PASS'

  bad_view = view
  bad_view%groundwater_level = -100.0_real64
  call distribute_single_level_positive_divdra(p,bad_view,q1,flux,diag)
  call require(diag%status == DRAIN_DIST_INVALID_HYDRAULIC_VIEW, 'water table at profile bottom rejected')

  p_variant = p
  p_variant%zbotcp(4) = -79.0_real64
  call distribute_single_level_positive_divdra(p_variant,view,q1,flux,diag)
  call require(diag%status == DRAIN_DIST_INVALID_PARAMETERS, 'inconsistent cumulative grid rejected')
  write(*,'(A)') 'FPM08B_INVALID_DOMAIN_FAIL_CLOSED=PASS'

  ! Stateless A/B/A identity with a distinct groundwater depth B.
  p%drain_spacing = 400.0_real64
  view%groundwater_level = -30.0_real64
  call distribute_single_level_positive_divdra(p,view,q1,a1,da1)
  view_b = process_hydraulic_view_t()
  view_b%groundwater_level = -45.0_real64
  call distribute_single_level_positive_divdra(p,view_b,q1,b,db)
  call require(.not. all_bits_same(a1%soil_to_drain_rate,b%soil_to_drain_rate), 'B differs from A')
  view%groundwater_level = -30.0_real64
  call distribute_single_level_positive_divdra(p,view,q1,a2,da2)
  call require(all_bits_same(a1%soil_to_drain_rate,a2%soil_to_drain_rate), 'A/B/A vector identity')
  call require(same_diag(da1,da2), 'A/B/A diagnostics identity')
  write(*,'(A)') 'FPM08B_STATELESS_A_B_A_IDENTITY=PASS'

  call require(da1%scalar_transfer_is_authoritative .and. da1%worker_scratch_only, 'ownership diagnostics')
  write(*,'(A)') 'FPM08B_SCALAR_AUTHORITY_WORKER_SCRATCH_BOUNDARY=PASS'
  write(*,'(A)') 'FPM08B_DRAINAGE_SPATIAL_DISTRIBUTION_TEST PASS'

contains

  subroutine configure_base(parameters)
    type(drainage_distribution_parameters_t), intent(out) :: parameters
    parameters%active_nodes = 5
    allocate(parameters%dz(5),parameters%zbotcp(5),parameters%saturated_conductivity(5), &
         parameters%horizontal_anisotropy_factor(5))
    parameters%dz = 20.0_real64
    parameters%zbotcp = [-20.0_real64,-40.0_real64,-60.0_real64,-80.0_real64,-100.0_real64]
    parameters%saturated_conductivity = 10.0_real64
    parameters%horizontal_anisotropy_factor = 1.0_real64
    parameters%drain_spacing = 400.0_real64
  end subroutine configure_base

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal = abs(a-b) <= tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function all_close(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal = size(a)==size(b)
    if (.not. equal) return
    do i=1,size(a)
      if (.not. close(a(i),b(i))) then
        equal=.false.
        return
      end if
    end do
  end function all_close

  real(real64) function ordered_sum(a) result(total)
    real(real64), intent(in) :: a(:)
    integer :: i
    total=0.0_real64
    do i=1,size(a)
      total=total+a(i)
    end do
  end function ordered_sum

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function all_bits_same(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if (.not. equal) return
    do i=1,size(a)
      if (.not. same_bits(a(i),b(i))) then
        equal=.false.
        return
      end if
    end do
  end function all_bits_same

  logical function same_diag(a,b) result(equal)
    type(drainage_distribution_diagnostics_t), intent(in) :: a,b
    equal = a%status == b%status .and. (a%evaluated .eqv. b%evaluated) .and. &
         (a%zero_transfer .eqv. b%zero_transfer) .and. a%water_table_node == b%water_table_node .and. &
         a%discharge_bottom_node == b%discharge_bottom_node .and. same_bits(a%groundwater_depth,b%groundwater_depth) .and. &
         same_bits(a%saturated_top_thickness,b%saturated_top_thickness) .and. &
         same_bits(a%discharge_bottom_thickness,b%discharge_bottom_thickness) .and. &
         same_bits(a%profile_anisotropy_factor,b%profile_anisotropy_factor) .and. &
         same_bits(a%discharge_layer_bottom_depth,b%discharge_layer_bottom_depth) .and. &
         same_bits(a%discharge_transmissivity,b%discharge_transmissivity) .and. &
         same_bits(a%raw_partition_sum,b%raw_partition_sum) .and. same_bits(a%closure_correction,b%closure_correction)
  end function same_diag

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08b_drainage_spatial_distribution
