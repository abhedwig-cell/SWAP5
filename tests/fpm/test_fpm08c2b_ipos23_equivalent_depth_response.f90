program test_fpm08c2b_ipos23_equivalent_depth_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_hooghoudt_equivalent_depth, only: hooghoudt_equivalent_depth_geometry_t, &
       hooghoudt_equivalent_depth_prepared_t, hooghoudt_equivalent_depth_diagnostics_t, &
       prepare_hooghoudt_equivalent_depth, EQDEPTH_OK, EQDEPTH_INVALID_PARAMETERS, &
       EQDEPTH_NUMERICAL_DOMAIN, EQDEPTH_BRANCH_SHALLOW, EQDEPTH_BRANCH_ASYMPTOTIC, &
       EQDEPTH_BRANCH_SERIES
  use mod_drainage_hooghoudt_ipos23_response, only: drainage_hooghoudt_ipos2_parameters_t, &
       drainage_hooghoudt_ipos3_parameters_t, drainage_hooghoudt_ipos23_result_t, &
       drainage_hooghoudt_ipos23_diagnostics_t, evaluate_drainage_hooghoudt_ipos2_response, &
       evaluate_drainage_hooghoudt_ipos3_response, DRAIN_IPOS23_OK, DRAIN_IPOS23_INVALID_PARAMETERS, &
       DRAIN_IPOS23_INVALID_PREPARED_GEOMETRY, DRAIN_IPOS23_B110_DIFFL_CUTOFF
  implicit none

  type(hooghoudt_equivalent_depth_geometry_t) :: geometry, g_left, g_right, g_bad, g_cut
  type(hooghoudt_equivalent_depth_prepared_t) :: prepared, prepared2, p_left, p_right, invalid_prepared, prepared_cut
  type(hooghoudt_equivalent_depth_diagnostics_t) :: gd, gd2, gd_left, gd_right, gd_bad, gd_cut
  type(drainage_hooghoudt_ipos2_parameters_t) :: p2, p2_bad, p2_cut
  type(drainage_hooghoudt_ipos3_parameters_t) :: p3, p3_bad
  type(process_hydraulic_view_t) :: view, view_plus, view_minus, view_b
  type(drainage_hooghoudt_ipos23_result_t) :: r2, r3, rp, rm, a1, a2, b
  type(drainage_hooghoudt_ipos23_diagnostics_t) :: d2, d3, dp, dm, da1, da2, db
  real(real64), parameter :: tol = 16384.0_real64 * epsilon(1.0_real64)
  real(real64), parameter :: fd_step = 1.0e-4_real64
  real(real64), parameter :: pi = acos(-1.0_real64)
  real(real64) :: expected, numerical_derivative, target_x, dbot

  call configure_geometry(geometry)
  call prepare_hooghoudt_equivalent_depth(geometry, prepared, gd)
  call require(gd%status == EQDEPTH_OK .and. gd%prepared .and. prepared%is_valid, 'base preparation status')
  call require(prepared%branch == EQDEPTH_BRANCH_SERIES, 'base preparation series branch')
  call require(close(prepared%equivalent_depth, reference_equivalent_depth(geometry)), 'equivalent depth source equation')
  call require(gd%immutable_parameter_cache .and. .not. gd%persistent_process_state, 'immutable cache ownership')
  write(*,'(A)') 'FPM08C2B_EQDEPTH_SOURCE_EQUATION=PASS'
  write(*,'(A)') 'FPM08C2B_EQDEPTH_IMMUTABLE_CACHE_OWNERSHIP=PASS'

  call prepare_hooghoudt_equivalent_depth(geometry, prepared2, gd2)
  call require(same_prepared_bits(prepared,prepared2), 'repeat preparation bit identity')
  call require(same_eqdiag_bits(gd,gd2), 'repeat preparation diagnostic identity')
  write(*,'(A)') 'FPM08C2B_EQDEPTH_REPEAT_IDENTITY=PASS'

  g_left = geometry
  target_x = 1.0e-6_real64 * (1.0_real64 - 1.0e-8_real64)
  dbot = target_x * g_left%drain_spacing / (2.0_real64*pi)
  g_left%drain_bottom_level = 0.0_real64
  g_left%impermeable_base_level = -dbot
  call prepare_hooghoudt_equivalent_depth(g_left,p_left,gd_left)
  g_right = g_left
  target_x = 1.0e-6_real64 * (1.0_real64 + 1.0e-8_real64)
  dbot = target_x * g_right%drain_spacing / (2.0_real64*pi)
  g_right%impermeable_base_level = -dbot
  call prepare_hooghoudt_equivalent_depth(g_right,p_right,gd_right)
  call require(p_left%branch == EQDEPTH_BRANCH_SHALLOW, 'x1e-6 left shallow')
  call require(p_right%branch == EQDEPTH_BRANCH_ASYMPTOTIC, 'x1e-6 right asymptotic')
  call require(abs(p_right%equivalent_depth-p_left%equivalent_depth) < 1.0e-8_real64, 'x1e-6 effective continuity')
  write(*,'(A)') 'FPM08C2B_EQDEPTH_X1E6_EFFECTIVELY_CONTINUOUS=PASS'

  g_left = geometry
  target_x = 0.5_real64 * (1.0_real64 - 1.0e-8_real64)
  dbot = target_x * g_left%drain_spacing / (2.0_real64*pi)
  g_left%drain_bottom_level = 0.0_real64
  g_left%impermeable_base_level = -dbot
  call prepare_hooghoudt_equivalent_depth(g_left,p_left,gd_left)
  g_right = g_left
  target_x = 0.5_real64 * (1.0_real64 + 1.0e-8_real64)
  dbot = target_x * g_right%drain_spacing / (2.0_real64*pi)
  g_right%impermeable_base_level = -dbot
  call prepare_hooghoudt_equivalent_depth(g_right,p_right,gd_right)
  call require(p_left%branch == EQDEPTH_BRANCH_ASYMPTOTIC, 'x0.5 left asymptotic')
  call require(p_right%branch == EQDEPTH_BRANCH_SERIES, 'x0.5 right series')
  call require(abs(p_right%equivalent_depth-p_left%equivalent_depth) > 1.0e-3_real64, 'x0.5 finite branch jump')
  write(*,'(A)') 'FPM08C2B_EQDEPTH_X05_FINITE_BRANCH_JUMP=PASS'

  g_bad = geometry
  g_bad%wetted_perimeter = 0.0_real64
  call prepare_hooghoudt_equivalent_depth(g_bad,p_left,gd_bad)
  call require(gd_bad%status == EQDEPTH_INVALID_PARAMETERS .and. .not. gd_bad%prepared, 'zero wetted perimeter rejected')
  g_bad = geometry
  g_bad%impermeable_base_level = g_bad%drain_bottom_level + 1.0_real64
  call prepare_hooghoudt_equivalent_depth(g_bad,p_left,gd_bad)
  call require(gd_bad%status == EQDEPTH_INVALID_PARAMETERS, 'base above drain rejected')
  g_bad = geometry
  g_bad%wetted_perimeter = 1.0e200_real64
  call prepare_hooghoudt_equivalent_depth(g_bad,p_left,gd_bad)
  call require(gd_bad%status == EQDEPTH_NUMERICAL_DOMAIN, 'nonpositive logarithmic denominator rejected')
  write(*,'(A)') 'FPM08C2B_EQDEPTH_DOMAIN_FAIL_CLOSED=PASS'

  call configure_ipos2(p2)
  call configure_ipos3(p3)
  view = process_hydraulic_view_t()
  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view,r2,d2)
  expected = legacy_ipos23_reference(2,p2%shape_factor,p2%horizontal_conductivity_top, &
       p2%horizontal_conductivity_top,p2%entry_resistance,prepared,view%groundwater_level)
  call require(d2%status == DRAIN_IPOS23_OK .and. d2%active .and. close(r2%signed_soil_to_drain_rate,expected), &
       'IPOS2 source response')
  call require(r2%derivative_defined .and. r2%dq_dgroundwater_level > 0.0_real64, 'IPOS2 derivative')
  write(*,'(A)') 'FPM08C2B_IPOS2_SOURCE_EQUATION=PASS'

  call evaluate_drainage_hooghoudt_ipos3_response(p3,prepared,view,r3,d3)
  expected = legacy_ipos23_reference(3,p3%shape_factor,p3%horizontal_conductivity_top, &
       p3%horizontal_conductivity_bottom,p3%entry_resistance,prepared,view%groundwater_level)
  call require(d3%status == DRAIN_IPOS23_OK .and. d3%active .and. close(r3%signed_soil_to_drain_rate,expected), &
       'IPOS3 source response')
  call require(r3%derivative_defined .and. r3%dq_dgroundwater_level > 0.0_real64, 'IPOS3 derivative')
  write(*,'(A)') 'FPM08C2B_IPOS3_SOURCE_EQUATION=PASS'

  view_plus = process_hydraulic_view_t()
  view_minus = process_hydraulic_view_t()
  view_plus%groundwater_level = view%groundwater_level + fd_step
  view_minus%groundwater_level = view%groundwater_level - fd_step
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view_plus,rp,dp)
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view_minus,rm,dm)
  numerical_derivative = (rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*fd_step)
  call require(abs(numerical_derivative-r2%dq_dgroundwater_level) <= 2.0e-10_real64, 'IPOS2 tangent finite difference')
  call evaluate_drainage_hooghoudt_ipos3_response(p3,prepared,view_plus,rp,dp)
  call evaluate_drainage_hooghoudt_ipos3_response(p3,prepared,view_minus,rm,dm)
  numerical_derivative = (rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*fd_step)
  call require(abs(numerical_derivative-r3%dq_dgroundwater_level) <= 2.0e-10_real64, 'IPOS3 tangent finite difference')
  write(*,'(A)') 'FPM08C2B_IPOS23_ANALYTIC_TANGENTS_FINITE_DIFFERENCE=PASS'

  p3_bad = p3
  p3_bad%horizontal_conductivity_bottom = 0.0_real64
  call evaluate_drainage_hooghoudt_ipos3_response(p3_bad,prepared,view,r3,d3)
  call require(d3%status == DRAIN_IPOS23_OK .and. d3%active .and. r3%derivative_defined, 'IPOS3 zero bottom conductivity admissible')
  write(*,'(A)') 'FPM08C2B_IPOS3_ZERO_BOTTOM_CONDUCTIVITY_ADMISSIBLE=PASS'

  p2_bad = p2
  p2_bad%horizontal_conductivity_top = 0.0_real64
  call evaluate_drainage_hooghoudt_ipos2_response(p2_bad,prepared,view,r2,d2)
  call require(d2%status == DRAIN_IPOS23_INVALID_PARAMETERS .and. .not. d2%evaluated, 'IPOS2 zero top conductivity rejected')
  p3_bad = p3
  p3_bad%horizontal_conductivity_bottom = -1.0_real64
  call evaluate_drainage_hooghoudt_ipos3_response(p3_bad,prepared,view,r3,d3)
  call require(d3%status == DRAIN_IPOS23_INVALID_PARAMETERS, 'IPOS3 negative bottom conductivity rejected')
  invalid_prepared = hooghoudt_equivalent_depth_prepared_t()
  call evaluate_drainage_hooghoudt_ipos2_response(p2,invalid_prepared,view,r2,d2)
  call require(d2%status == DRAIN_IPOS23_INVALID_PREPARED_GEOMETRY, 'invalid prepared geometry rejected')
  write(*,'(A)') 'FPM08C2B_RESPONSE_DOMAIN_FAIL_CLOSED=PASS'

  g_cut = geometry
  g_cut%drain_bottom_level = 0.0_real64
  g_cut%impermeable_base_level = -100.0_real64
  call prepare_hooghoudt_equivalent_depth(g_cut,prepared_cut,gd_cut)
  call require(prepared_cut%is_valid, 'cutoff prepared geometry')
  p2_cut = p2
  p2_cut%shape_factor = 1.0_real64
  view%groundwater_level = DRAIN_IPOS23_B110_DIFFL_CUTOFF
  call evaluate_drainage_hooghoudt_ipos2_response(p2_cut,prepared_cut,view,r2,d2)
  call require(d2%active .and. d2%at_exact_compatibility_cutoff .and. &
       r2%signed_soil_to_drain_rate > 0.0_real64 .and. .not. r2%derivative_defined, 'exact cutoff parity')
  view%groundwater_level = 0.5_real64*DRAIN_IPOS23_B110_DIFFL_CUTOFF
  call evaluate_drainage_hooghoudt_ipos2_response(p2_cut,prepared_cut,view,r2,d2)
  call require(d2%inactive_below_compatibility_cutoff .and. r2%derivative_defined, 'below cutoff')
  write(*,'(A)') 'FPM08C2B_EXACT_CUTOFF_BRANCH_EXPLICIT=PASS'

  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view,a1,da1)
  view_b = process_hydraulic_view_t()
  view_b%groundwater_level = -75.0_real64
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view_b,b,db)
  call require(.not. same_response_bits(a1,b), 'B differs from A')
  view%groundwater_level = -50.0_real64
  call evaluate_drainage_hooghoudt_ipos2_response(p2,prepared,view,a2,da2)
  call require(same_response_bits(a1,a2), 'A/B/A response identity')
  call require(same_response_diag_bits(da1,da2), 'A/B/A response diagnostics identity')
  call require(.not. da1%persistent_process_state .and. da1%prepared_equivalent_depth_is_shared_immutable, &
       'response state ownership')
  call require(da1%mass_is_authoritative_external_transfer, 'response mass ownership')
  write(*,'(A)') 'FPM08C2B_STATELESS_A_B_A_IDENTITY=PASS'
  write(*,'(A)') 'FPM08C2B_STATE_AND_MASS_OWNERSHIP=PASS'

  write(*,'(A)') 'FPM08C2B_IPOS23_EQDEPTH_RESPONSE_TEST PASS'

contains

  subroutine configure_geometry(g)
    type(hooghoudt_equivalent_depth_geometry_t), intent(out) :: g
    g%drain_spacing = 1000.0_real64
    g%drain_bottom_level = -100.0_real64
    g%impermeable_base_level = -500.0_real64
    g%wetted_perimeter = 10.0_real64
  end subroutine configure_geometry

  subroutine configure_ipos2(p)
    type(drainage_hooghoudt_ipos2_parameters_t), intent(out) :: p
    p%shape_factor = 0.8_real64
    p%horizontal_conductivity_top = 10.0_real64
    p%entry_resistance = 5.0_real64
  end subroutine configure_ipos2

  subroutine configure_ipos3(p)
    type(drainage_hooghoudt_ipos3_parameters_t), intent(out) :: p
    p%shape_factor = 0.8_real64
    p%horizontal_conductivity_top = 10.0_real64
    p%horizontal_conductivity_bottom = 5.0_real64
    p%entry_resistance = 5.0_real64
  end subroutine configure_ipos3

  real(real64) function reference_equivalent_depth(g) result(eqd)
    type(hooghoudt_equivalent_depth_geometry_t), intent(in) :: g
    real(real64) :: effective_base, depth, x, fx, raw, ee
    integer :: i
    effective_base = max(g%impermeable_base_level,g%drain_bottom_level-0.25_real64*g%drain_spacing)
    depth = g%drain_bottom_level-effective_base
    x = 2.0_real64*pi*depth/g%drain_spacing
    if (x > 0.5_real64) then
      fx = 0.0_real64
      do i=1,5,2
        ee=exp(-2.0_real64*real(i,real64)*x)
        fx=fx+4.0_real64*ee/(real(i,real64)*(1.0_real64-ee))
      end do
      raw=pi*g%drain_spacing/(8.0_real64*(log(g%drain_spacing/g%wetted_perimeter)+fx))
    else if (x < 1.0e-6_real64) then
      raw=depth
    else
      fx=pi*pi/(4.0_real64*x)+log(x/(2.0_real64*pi))
      raw=pi*g%drain_spacing/(8.0_real64*(log(g%drain_spacing/g%wetted_perimeter)+fx))
    end if
    eqd=min(raw,depth)
  end function reference_equivalent_depth

  real(real64) function legacy_ipos23_reference(ipos,shape,ktop,keqd,entry,prep,gwl) result(q)
    integer, intent(in) :: ipos
    real(real64), intent(in) :: shape,ktop,keqd,entry,gwl
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: prep
    real(real64) :: difference,denominator,resistance
    call require(ipos==2 .or. ipos==3,'reference ipos')
    difference=(gwl-prep%drain_bottom_level)/shape
    if (difference < DRAIN_IPOS23_B110_DIFFL_CUTOFF) then
      q=0.0_real64
      return
    end if
    denominator=8.0_real64*keqd*prep%equivalent_depth+4.0_real64*ktop*abs(difference)
    resistance=prep%drain_spacing**2/denominator+entry
    q=difference/resistance
  end function legacy_ipos23_reference

  logical function close(a,b) result(equal)
    real(real64), intent(in) :: a,b
    equal=abs(a-b)<=tol*max(1.0_real64,abs(a),abs(b))
  end function close

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  logical function same_prepared_bits(a,b) result(equal)
    type(hooghoudt_equivalent_depth_prepared_t), intent(in) :: a,b
    equal=(a%is_valid .eqv. b%is_valid) .and. same_bits(a%drain_spacing,b%drain_spacing) .and. &
      same_bits(a%drain_bottom_level,b%drain_bottom_level) .and. &
      same_bits(a%effective_base_level,b%effective_base_level) .and. &
      same_bits(a%depth_below_drain,b%depth_below_drain) .and. &
      same_bits(a%wetted_perimeter,b%wetted_perimeter) .and. same_bits(a%x,b%x) .and. &
      same_bits(a%equivalent_depth,b%equivalent_depth) .and. a%branch==b%branch .and. &
      (a%clipped_to_depth_below_drain .eqv. b%clipped_to_depth_below_drain) .and. &
      (a%at_x_shallow_boundary .eqv. b%at_x_shallow_boundary) .and. &
      (a%at_x_series_boundary .eqv. b%at_x_series_boundary)
  end function same_prepared_bits

  logical function same_eqdiag_bits(a,b) result(equal)
    type(hooghoudt_equivalent_depth_diagnostics_t), intent(in) :: a,b
    equal=a%status==b%status .and. (a%prepared .eqv. b%prepared) .and. &
      same_bits(a%raw_equivalent_depth,b%raw_equivalent_depth) .and. &
      same_bits(a%formula_denominator,b%formula_denominator) .and. &
      (a%immutable_parameter_cache .eqv. b%immutable_parameter_cache) .and. &
      (a%persistent_process_state .eqv. b%persistent_process_state)
  end function same_eqdiag_bits

  logical function same_response_bits(a,b) result(equal)
    type(drainage_hooghoudt_ipos23_result_t), intent(in) :: a,b
    equal=same_bits(a%signed_soil_to_drain_rate,b%signed_soil_to_drain_rate) .and. &
      (a%derivative_defined .eqv. b%derivative_defined) .and. &
      same_bits(a%dq_dgroundwater_level,b%dq_dgroundwater_level)
  end function same_response_bits

  logical function same_response_diag_bits(a,b) result(equal)
    type(drainage_hooghoudt_ipos23_diagnostics_t), intent(in) :: a,b
    equal=a%status==b%status .and. a%ipos==b%ipos .and. (a%evaluated .eqv. b%evaluated) .and. &
      (a%inactive_below_compatibility_cutoff .eqv. b%inactive_below_compatibility_cutoff) .and. &
      (a%active .eqv. b%active) .and. (a%at_exact_compatibility_cutoff .eqv. b%at_exact_compatibility_cutoff) .and. &
      same_bits(a%groundwater_level,b%groundwater_level) .and. same_bits(a%difference,b%difference) .and. &
      same_bits(a%conductance_denominator,b%conductance_denominator) .and. &
      same_bits(a%horizontal_resistance,b%horizontal_resistance) .and. same_bits(a%total_resistance,b%total_resistance) .and. &
      (a%prepared_equivalent_depth_is_shared_immutable .eqv. b%prepared_equivalent_depth_is_shared_immutable) .and. &
      (a%mass_is_authoritative_external_transfer .eqv. b%mass_is_authoritative_external_transfer) .and. &
      (a%persistent_process_state .eqv. b%persistent_process_state)
  end function same_response_diag_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM08C2B_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm08c2b_ipos23_equivalent_depth_response
