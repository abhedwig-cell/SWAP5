program test_fpm05_macro_feddes_root_uptake
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK, ROOT_UPTAKE_INVALID_PARAMETERS, ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW, &
       ROOT_UPTAKE_INVALID_REQUEST
  implicit none

  type(root_water_uptake_parameters_t) :: parameters, variant
  type(root_water_uptake_request_t) :: request
  type(root_water_uptake_flux_result_t) :: flux_a1, flux_b, flux_a2, flux
  type(root_water_uptake_diagnostics_t) :: diag_a1, diag_b, diag_a2, diag
  type(process_hydraulic_view_t) :: view_a, view_b, bad_view
  real(real64), parameter :: tol = 2048.0_real64*epsilon(1.0_real64)
  real(real64), parameter :: hlim3_expected = -650.0_real64
  real(real64), parameter :: expected_potential(5) = [0.03_real64, 0.06_real64, 0.09_real64, 0.12_real64, 0.0_real64]
  real(real64), parameter :: expected_actual(5) = [0.0_real64, 0.0_real64, 0.045_real64, 0.12_real64, 0.0_real64]
  real(real64), parameter :: expected_alpha(5) = [0.0_real64, 0.0_real64, 0.5_real64, 1.0_real64, 1.0_real64]

  call configure_parameters(parameters)
  call configure_view(view_a)
  request%potential_transpiration = 0.3_real64

  call evaluate_macro_feddes_drought_uptake(parameters, view_a, request, flux_a1, diag_a1)
  call require(diag_a1%status == ROOT_UPTAKE_OK, 'canonical status')
  call require(diag_a1%evaluated, 'canonical evaluated')
  call require(close(diag_a1%critical_pressure_head,hlim3_expected), 'interpolated hlim3')
  call require(all_close(diag_a1%potential_root_sink,expected_potential), 'potential root uptake equation')
  call require(all_close(flux_a1%root_extraction_sink,expected_actual), 'Feddes drought actual uptake equation')
  call require(all_close(diag_a1%drought_reduction_factor,expected_alpha), 'Feddes drought factor equation')
  call require(close(diag_a1%potential_uptake_total,0.3_real64), 'potential uptake sums to ptra')
  call require(close(flux_a1%actual_uptake_total,0.165_real64), 'actual uptake total')
  call require(close(diag_a1%drought_reduction_total,0.135_real64), 'drought reduction total')
  call require(close(flux_a1%actual_uptake_total+diag_a1%drought_reduction_total, &
       diag_a1%potential_uptake_total), 'potential equals actual plus drought reduction')
  write(*,'(A)') 'FPM05_MACRO_FEDDES_SOURCE_EQUATIONS=PASS'

  request%potential_transpiration = 0.05_real64
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_OK .and. close(diag%critical_pressure_head,parameters%hlim3l), &
       'hlim3 low branch')
  request%potential_transpiration = parameters%adcrl
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(close(diag%critical_pressure_head,parameters%hlim3l), 'hlim3 adcrl equality')
  request%potential_transpiration = parameters%adcrh
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(close(diag%critical_pressure_head,parameters%hlim3h), 'hlim3 adcrh equality')
  request%potential_transpiration = 0.8_real64
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(close(diag%critical_pressure_head,parameters%hlim3h), 'hlim3 high branch')
  write(*,'(A)') 'FPM05_HLIM3_BRANCH_BOUNDARIES=PASS'

  variant = parameters
  variant%rooted_nodes = 0
  if (allocated(variant%cumulative_root_fraction)) deallocate(variant%cumulative_root_fraction)
  request%potential_transpiration = 0.3_real64
  call evaluate_macro_feddes_drought_uptake(variant,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_OK .and. diag%no_roots, 'no-root early exit')
  call require(allocated(flux%root_extraction_sink) .and. all(flux%root_extraction_sink == 0.0_real64), &
       'no-root zero sink')

  request%potential_transpiration = 1.0e-12_real64
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_OK .and. diag%negligible_transpiration, &
       'negligible transpiration early exit')
  call require(all(flux%root_extraction_sink == 0.0_real64), 'negligible transpiration zero sink')
  write(*,'(A)') 'FPM05_LEGACY_EARLY_EXIT_ZERO_ROUTES=PASS'

  variant = parameters
  variant%adcrh = variant%adcrl
  request%potential_transpiration = 0.3_real64
  call evaluate_macro_feddes_drought_uptake(variant,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_INVALID_PARAMETERS, 'invalid ptra threshold interval')

  variant = parameters
  variant%cumulative_root_fraction(3) = variant%cumulative_root_fraction(2)-0.01_real64
  call evaluate_macro_feddes_drought_uptake(variant,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_INVALID_PARAMETERS, 'nonmonotonic root fractions')

  variant = parameters
  variant%cumulative_root_fraction(variant%rooted_nodes+1)=0.99_real64
  call evaluate_macro_feddes_drought_uptake(variant,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_INVALID_PARAMETERS, 'unnormalized root fractions')

  bad_view = view_a
  bad_view%active_nodes = view_a%active_nodes-1
  call evaluate_macro_feddes_drought_uptake(parameters,bad_view,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW, 'view active-node mismatch')

  request%potential_transpiration = -0.1_real64
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux,diag)
  call require(diag%status == ROOT_UPTAKE_INVALID_REQUEST, 'negative ptra fail closed')
  write(*,'(A)') 'FPM05_INVALID_DOMAIN_FAIL_CLOSED=PASS'

  request%potential_transpiration = 0.3_real64
  view_b = view_a
  view_b%pressure_head(3) = -12000.0_real64
  call evaluate_macro_feddes_drought_uptake(parameters,view_b,request,flux_b,diag_b)
  call require(.not. all_bits_identical(flux_a1%root_extraction_sink,flux_b%root_extraction_sink), &
       'B fixture distinct from A')
  call evaluate_macro_feddes_drought_uptake(parameters,view_a,request,flux_a2,diag_a2)
  call require(all_bits_identical(flux_a1%root_extraction_sink,flux_a2%root_extraction_sink), &
       'A/B/A root sink identity')
  call require(all_bits_identical(diag_a1%potential_root_sink,diag_a2%potential_root_sink), &
       'A/B/A potential identity')
  call require(all_bits_identical(diag_a1%drought_reduction,diag_a2%drought_reduction), &
       'A/B/A drought diagnostic identity')
  call require(same_bits(flux_a1%actual_uptake_total,flux_a2%actual_uptake_total), &
       'A/B/A total identity')
  write(*,'(A)') 'FPM05_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM05_MACRO_FEDDES_ROOT_UPTAKE_TEST PASS'

contains

  subroutine configure_parameters(p)
    type(root_water_uptake_parameters_t), intent(out) :: p
    p%active_nodes = 5
    p%rooted_nodes = 4
    p%hlim3l = -800.0_real64
    p%hlim3h = -500.0_real64
    p%hlim4 = -16000.0_real64
    p%adcrl = 0.1_real64
    p%adcrh = 0.5_real64
    allocate(p%cumulative_root_fraction(5))
    p%cumulative_root_fraction = [0.0_real64,0.1_real64,0.3_real64,0.6_real64,1.0_real64]
  end subroutine configure_parameters

  subroutine configure_view(view)
    type(process_hydraulic_view_t), intent(out) :: view
    view%active_nodes = 5
    allocate(view%pressure_head(5),view%water_content(5))
    view%pressure_head = [-17000.0_real64,-16000.0_real64,-8325.0_real64,-100.0_real64,-50.0_real64]
    view%water_content = 0.25_real64
    view%ponding_depth = 0.0_real64
    view%groundwater_level = -2.0_real64
  end subroutine configure_view

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

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  logical function all_bits_identical(a,b) result(equal)
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
  end function all_bits_identical

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM05_MACRO_FEDDES_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm05_macro_feddes_root_uptake
