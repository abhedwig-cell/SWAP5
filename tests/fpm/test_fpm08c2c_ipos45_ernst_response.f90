program test_fpm08c2c_ipos45_ernst_response
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_ernst_ipos45_preparation, only: &
       ernst_ipos4_geometry_t, ernst_ipos5_geometry_t, ernst_ipos4_prepared_t, ernst_ipos5_prepared_t, &
       ernst_preparation_diagnostics_t, prepare_ernst_ipos4, prepare_ernst_ipos5, ERNST_PREP_OK
  use mod_drainage_ernst_ipos45_response, only: &
       drainage_ernst_response_t, drainage_ernst_diagnostics_t, &
       evaluate_drainage_ernst_ipos4_response, evaluate_drainage_ernst_ipos5_response, &
       DRAIN_ERNST_OK, DRAIN_ERNST_NUMERICAL_DOMAIN, DRAIN_ERNST_B110_DIFFL_CUTOFF
  implicit none

  call test_ipos4_preparation_and_source_equation()
  call test_ipos5_preparation_and_source_equation()
  call test_ipos4_stable_branch_tangents()
  call test_ipos5_tangent()
  call test_ipos4_interface_kink()
  call test_negative_radial_resistance_admissible()
  call test_positive_total_resistance_fail_closed()
  call test_exact_cutoff_and_inactive_branch()
  call test_stateless_identity()
  call test_state_and_mass_ownership()

  write(*,'(a)') 'FPM08C2C_IPOS45_ERNST_RESPONSE_TEST PASS'

contains

  subroutine test_ipos4_preparation_and_source_equation()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d
    real(real64) :: eb, dbot, rhor, rrad, rver, total, diffl, expected
    real(real64), parameter :: pi = acos(-1.0_real64)

    g%drain_spacing = 100.0_real64
    g%shape_factor = 1.5_real64
    g%drain_bottom_level = 0.0_real64
    g%impermeable_base_level = -30.0_real64
    g%interface_level = 10.0_real64
    g%horizontal_conductivity_bottom = 8.0_real64
    g%vertical_conductivity_top = 4.0_real64
    g%vertical_conductivity_bottom = 6.0_real64
    g%wetted_perimeter = 2.0_real64
    g%entry_resistance = 1.25_real64

    call prepare_ernst_ipos4(g,p,pd)
    call require(pd%status == ERNST_PREP_OK .and. p%is_valid, 'ipos4 preparation failed')

    eb = max(g%impermeable_base_level, g%drain_bottom_level - 0.25_real64*g%drain_spacing)
    dbot = g%drain_bottom_level - eb
    rhor = g%drain_spacing**2 / (8.0_real64*g%horizontal_conductivity_bottom*dbot)
    rrad = g%drain_spacing / (pi*sqrt(g%horizontal_conductivity_bottom*g%vertical_conductivity_bottom)) * &
         log(dbot/g%wetted_perimeter)
    call require_close(p%effective_base_level, eb, 1.0e-13_real64, 'ipos4 effective base')
    call require_close(p%depth_below_drain, dbot, 1.0e-13_real64, 'ipos4 dbot')
    call require_close(p%horizontal_resistance, rhor, 1.0e-13_real64, 'ipos4 rhor')
    call require_close(p%radial_resistance, rrad, 1.0e-13_real64, 'ipos4 rrad')

    v%groundwater_level = 16.0_real64
    call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%evaluated, 'ipos4 response failed')
    diffl = (v%groundwater_level-g%drain_bottom_level)/g%shape_factor
    rver = (v%groundwater_level-g%interface_level)/g%vertical_conductivity_top + &
         (g%interface_level-g%drain_bottom_level)/g%vertical_conductivity_bottom
    total = rver + rhor + rrad + g%entry_resistance
    expected = diffl/total
    call require_close(r%signed_soil_to_drain_rate, expected, 2.0e-13_real64, 'ipos4 source equation')
    write(*,'(a)') 'FPM08C2C_IPOS4_SOURCE_EQUATION=PASS'
  end subroutine test_ipos4_preparation_and_source_equation

  subroutine test_ipos5_preparation_and_source_equation()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d
    real(real64) :: eb, hden, logarg, rhor, rrad, rver, total, diffl, expected
    real(real64), parameter :: pi = acos(-1.0_real64)

    g%drain_spacing = 120.0_real64
    g%shape_factor = 2.0_real64
    g%drain_bottom_level = 12.0_real64
    g%impermeable_base_level = -25.0_real64
    g%interface_level = 2.0_real64
    g%horizontal_conductivity_top = 10.0_real64
    g%horizontal_conductivity_bottom = 3.0_real64
    g%vertical_conductivity_top = 5.0_real64
    g%wetted_perimeter = 2.0_real64
    g%geometry_factor = 1.5_real64
    g%entry_resistance = 0.75_real64

    call prepare_ernst_ipos5(g,p,pd)
    call require(pd%status == ERNST_PREP_OK .and. p%is_valid, 'ipos5 preparation failed')

    eb = max(g%impermeable_base_level, g%drain_bottom_level - 0.25_real64*g%drain_spacing)
    hden = 8.0_real64*g%horizontal_conductivity_top*(g%drain_bottom_level-g%interface_level) + &
         8.0_real64*g%horizontal_conductivity_bottom*(g%interface_level-eb)
    logarg = g%geometry_factor*(g%drain_bottom_level-g%interface_level)/g%wetted_perimeter
    rhor = g%drain_spacing**2/hden
    rrad = g%drain_spacing/(pi*sqrt(g%horizontal_conductivity_top*g%vertical_conductivity_top))*log(logarg)
    call require_close(p%horizontal_resistance_denominator, hden, 1.0e-13_real64, 'ipos5 hden')
    call require_close(p%radial_log_argument, logarg, 1.0e-13_real64, 'ipos5 logarg')
    call require_close(p%horizontal_resistance, rhor, 1.0e-13_real64, 'ipos5 rhor')
    call require_close(p%radial_resistance, rrad, 1.0e-13_real64, 'ipos5 rrad')

    v%groundwater_level = 24.0_real64
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%evaluated, 'ipos5 response failed')
    diffl = (v%groundwater_level-g%drain_bottom_level)/g%shape_factor
    rver = (v%groundwater_level-g%drain_bottom_level)/g%vertical_conductivity_top
    total = rver+rhor+rrad+g%entry_resistance
    expected = diffl/total
    call require_close(r%signed_soil_to_drain_rate, expected, 2.0e-13_real64, 'ipos5 source equation')
    write(*,'(a)') 'FPM08C2C_IPOS5_SOURCE_EQUATION=PASS'
  end subroutine test_ipos5_preparation_and_source_equation

  subroutine test_ipos4_stable_branch_tangents()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    real(real64) :: analytic, fd

    call standard_ipos4_geometry(g)
    call prepare_ernst_ipos4(g,p,pd)
    call require(pd%status == ERNST_PREP_OK, 'ipos4 tangent preparation')
    call ipos4_tangent_at(p,5.0_real64,analytic,fd)
    call require_close(analytic,fd,2.0e-8_real64,'ipos4 below-interface tangent')
    call ipos4_tangent_at(p,15.0_real64,analytic,fd)
    call require_close(analytic,fd,2.0e-8_real64,'ipos4 above-interface tangent')
    write(*,'(a)') 'FPM08C2C_IPOS4_STABLE_BRANCH_TANGENTS_FD=PASS'
  end subroutine test_ipos4_stable_branch_tangents

  subroutine test_ipos5_tangent()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    real(real64) :: analytic, fd

    call standard_ipos5_geometry(g)
    call prepare_ernst_ipos5(g,p,pd)
    call require(pd%status == ERNST_PREP_OK, 'ipos5 tangent preparation')
    call ipos5_tangent_at(p,20.0_real64,analytic,fd)
    call require_close(analytic,fd,2.0e-8_real64,'ipos5 tangent')
    write(*,'(a)') 'FPM08C2C_IPOS5_TANGENT_FD=PASS'
  end subroutine test_ipos5_tangent

  subroutine test_ipos4_interface_kink()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos4_geometry(g)
    g%vertical_conductivity_top = 4.0_real64
    g%vertical_conductivity_bottom = 8.0_real64
    call prepare_ernst_ipos4(g,p,pd)
    v%groundwater_level = g%interface_level
    call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%at_ipos4_interface_kink, 'ipos4 kink not diagnosed')
    call require(.not. r%derivative_defined, 'ipos4 branch-sensitive kink derivative exposed')

    g%vertical_conductivity_top = 6.0_real64
    g%vertical_conductivity_bottom = 6.0_real64
    call prepare_ernst_ipos4(g,p,pd)
    call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%at_ipos4_interface_kink .and. r%derivative_defined, 'ipos4 equal-Kv differentiable interface')
    write(*,'(a)') 'FPM08C2C_IPOS4_INTERFACE_KINK_EXPLICIT=PASS'
  end subroutine test_ipos4_interface_kink

  subroutine test_negative_radial_resistance_admissible()
    type(ernst_ipos4_geometry_t) :: g4
    type(ernst_ipos5_geometry_t) :: g5
    type(ernst_ipos4_prepared_t) :: p4
    type(ernst_ipos5_prepared_t) :: p5
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos4_geometry(g4)
    g4%wetted_perimeter = 25.0_real64
    call prepare_ernst_ipos4(g4,p4,pd)
    call require(pd%status == ERNST_PREP_OK .and. p4%radial_resistance < 0.0_real64, 'ipos4 negative rrad prep')
    v%groundwater_level = 15.0_real64
    call evaluate_drainage_ernst_ipos4_response(p4,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%negative_radial_resistance .and. &
         d%total_resistance > 0.0_real64, 'ipos4 negative rrad rejected')

    call standard_ipos5_geometry(g5)
    g5%geometry_factor = 0.5_real64
    g5%wetted_perimeter = 10.0_real64
    g5%entry_resistance = 2.0_real64
    call prepare_ernst_ipos5(g5,p5,pd)
    call require(pd%status == ERNST_PREP_OK .and. p5%radial_resistance < 0.0_real64, 'ipos5 negative rrad prep')
    v%groundwater_level = 20.0_real64
    call evaluate_drainage_ernst_ipos5_response(p5,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%negative_radial_resistance .and. &
         d%total_resistance > 0.0_real64, 'ipos5 negative rrad rejected')
    write(*,'(a)') 'FPM08C2C_NEGATIVE_RADIAL_RESISTANCE_ADMISSIBLE=PASS'
  end subroutine test_negative_radial_resistance_admissible

  subroutine test_positive_total_resistance_fail_closed()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos4_geometry(g)
    g%wetted_perimeter = 500.0_real64
    g%entry_resistance = 0.0_real64
    call prepare_ernst_ipos4(g,p,pd)
    call require(pd%status == ERNST_PREP_OK .and. p%fixed_resistance < 0.0_real64, 'negative fixed prep fixture')
    v%groundwater_level = 1.0_real64
    call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%status == DRAIN_ERNST_NUMERICAL_DOMAIN .and. .not. d%evaluated, &
         'non-positive total resistance not rejected')
    write(*,'(a)') 'FPM08C2C_POSITIVE_TOTAL_RESISTANCE_FAIL_CLOSED=PASS'
  end subroutine test_positive_total_resistance_fail_closed

  subroutine test_exact_cutoff_and_inactive_branch()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos5_geometry(g)
    call prepare_ernst_ipos5(g,p,pd)
    v%groundwater_level = p%drain_bottom_level + p%shape_factor * 0.5_real64 * DRAIN_ERNST_B110_DIFFL_CUTOFF
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(d%inactive_below_compatibility_cutoff .and. r%derivative_defined .and. &
         r%signed_soil_to_drain_rate == 0.0_real64, 'inactive cutoff branch')

    v%groundwater_level = p%drain_bottom_level + p%shape_factor * DRAIN_ERNST_B110_DIFFL_CUTOFF
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(d%status == DRAIN_ERNST_OK .and. d%active, 'exact cutoff must use active legacy branch')
    call require(.not. r%derivative_defined .and. d%at_exact_compatibility_cutoff, &
         'exact cutoff derivative must be held')
    write(*,'(a)') 'FPM08C2C_EXACT_B110_CUTOFF_BRANCH_EXPLICIT=PASS'
  end subroutine test_exact_cutoff_and_inactive_branch

  subroutine test_stateless_identity()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: ra, rb, ra2
    type(drainage_ernst_diagnostics_t) :: da, db, da2

    call standard_ipos5_geometry(g)
    call prepare_ernst_ipos5(g,p,pd)
    v%groundwater_level = 20.0_real64
    call evaluate_drainage_ernst_ipos5_response(p,v,ra,da)
    v%groundwater_level = 30.0_real64
    call evaluate_drainage_ernst_ipos5_response(p,v,rb,db)
    v%groundwater_level = 20.0_real64
    call evaluate_drainage_ernst_ipos5_response(p,v,ra2,da2)
    call require(da%status == DRAIN_ERNST_OK .and. db%status == DRAIN_ERNST_OK .and. &
         da2%status == DRAIN_ERNST_OK, 'A/B/A status')
    call require(ra%signed_soil_to_drain_rate == ra2%signed_soil_to_drain_rate .and. &
         ra%dq_dgroundwater_level == ra2%dq_dgroundwater_level, 'A/B/A identity')
    write(*,'(a)') 'FPM08C2C_STATELESS_A_B_A_IDENTITY=PASS'
  end subroutine test_stateless_identity

  subroutine test_state_and_mass_ownership()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos5_geometry(g)
    call prepare_ernst_ipos5(g,p,pd)
    v%groundwater_level = 20.0_real64
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(pd%immutable_parameter_cache .and. .not. pd%persistent_process_state, 'prepared ownership')
    call require(d%prepared_geometry_is_shared_immutable .and. .not. d%persistent_process_state .and. &
         d%mass_is_authoritative_external_transfer, 'response ownership')
    write(*,'(a)') 'FPM08C2C_STATE_AND_MASS_OWNERSHIP=PASS'
  end subroutine test_state_and_mass_ownership

  subroutine ipos4_tangent_at(p,gwl,analytic,fd)
    type(ernst_ipos4_prepared_t), intent(in) :: p
    real(real64), intent(in) :: gwl
    real(real64), intent(out) :: analytic, fd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r0, rp, rm
    type(drainage_ernst_diagnostics_t) :: d0, dp, dm
    real(real64), parameter :: eps = 1.0e-6_real64

    v%groundwater_level = gwl
    call evaluate_drainage_ernst_ipos4_response(p,v,r0,d0)
    call require(d0%status == DRAIN_ERNST_OK .and. r0%derivative_defined, 'ipos4 analytic tangent unavailable')
    v%groundwater_level = gwl + eps
    call evaluate_drainage_ernst_ipos4_response(p,v,rp,dp)
    v%groundwater_level = gwl - eps
    call evaluate_drainage_ernst_ipos4_response(p,v,rm,dm)
    call require(dp%status == DRAIN_ERNST_OK .and. dm%status == DRAIN_ERNST_OK, 'ipos4 fd evaluation')
    analytic = r0%dq_dgroundwater_level
    fd = (rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*eps)
  end subroutine ipos4_tangent_at

  subroutine ipos5_tangent_at(p,gwl,analytic,fd)
    type(ernst_ipos5_prepared_t), intent(in) :: p
    real(real64), intent(in) :: gwl
    real(real64), intent(out) :: analytic, fd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r0, rp, rm
    type(drainage_ernst_diagnostics_t) :: d0, dp, dm
    real(real64), parameter :: eps = 1.0e-6_real64

    v%groundwater_level = gwl
    call evaluate_drainage_ernst_ipos5_response(p,v,r0,d0)
    call require(d0%status == DRAIN_ERNST_OK .and. r0%derivative_defined, 'ipos5 analytic tangent unavailable')
    v%groundwater_level = gwl + eps
    call evaluate_drainage_ernst_ipos5_response(p,v,rp,dp)
    v%groundwater_level = gwl - eps
    call evaluate_drainage_ernst_ipos5_response(p,v,rm,dm)
    call require(dp%status == DRAIN_ERNST_OK .and. dm%status == DRAIN_ERNST_OK, 'ipos5 fd evaluation')
    analytic = r0%dq_dgroundwater_level
    fd = (rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*eps)
  end subroutine ipos5_tangent_at

  subroutine standard_ipos4_geometry(g)
    type(ernst_ipos4_geometry_t), intent(out) :: g
    g%drain_spacing = 100.0_real64
    g%shape_factor = 1.0_real64
    g%drain_bottom_level = 0.0_real64
    g%impermeable_base_level = -20.0_real64
    g%interface_level = 10.0_real64
    g%horizontal_conductivity_bottom = 10.0_real64
    g%vertical_conductivity_top = 4.0_real64
    g%vertical_conductivity_bottom = 8.0_real64
    g%wetted_perimeter = 2.0_real64
    g%entry_resistance = 1.0_real64
  end subroutine standard_ipos4_geometry

  subroutine standard_ipos5_geometry(g)
    type(ernst_ipos5_geometry_t), intent(out) :: g
    g%drain_spacing = 100.0_real64
    g%shape_factor = 1.0_real64
    g%drain_bottom_level = 10.0_real64
    g%impermeable_base_level = -20.0_real64
    g%interface_level = 0.0_real64
    g%horizontal_conductivity_top = 10.0_real64
    g%horizontal_conductivity_bottom = 5.0_real64
    g%vertical_conductivity_top = 4.0_real64
    g%wetted_perimeter = 2.0_real64
    g%geometry_factor = 1.5_real64
    g%entry_resistance = 1.0_real64
  end subroutine standard_ipos5_geometry

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'FAIL', trim(message)
      error stop 1
    end if
  end subroutine require

  subroutine require_close(actual,expected,tolerance,message)
    real(real64), intent(in) :: actual, expected, tolerance
    character(len=*), intent(in) :: message
    call require(abs(actual-expected) <= tolerance*max(1.0_real64,abs(expected)), message)
  end subroutine require_close

end program test_fpm08c2c_ipos45_ernst_response
