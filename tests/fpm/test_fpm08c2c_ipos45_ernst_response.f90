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

  call source_equations()
  call stable_branch_tangents()
  call interface_kink()
  call negative_radial_resistance()
  call total_resistance_fail_closed()
  call cutoff_semantics()
  call stateless_and_ownership()
  write(*,'(a)') 'FPM08C2C_IPOS45_ERNST_RESPONSE_TEST PASS'

contains

  subroutine source_equations()
    type(ernst_ipos4_geometry_t) :: g4
    type(ernst_ipos5_geometry_t) :: g5
    type(ernst_ipos4_prepared_t) :: p4
    type(ernst_ipos5_prepared_t) :: p5
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d
    real(real64) :: eb, dbot, rhor, rrad, rver, total, diffl, hden, logarg
    real(real64), parameter :: pi = acos(-1.0_real64)

    call standard_ipos4(g4)
    call prepare_ernst_ipos4(g4,p4,pd)
    call require(pd%status == ERNST_PREP_OK .and. p4%is_valid,'ipos4 prepare')
    eb=max(g4%impermeable_base_level,g4%drain_bottom_level-0.25_real64*g4%drain_spacing)
    dbot=g4%drain_bottom_level-eb
    rhor=g4%drain_spacing**2/(8.0_real64*g4%horizontal_conductivity_bottom*dbot)
    rrad=g4%drain_spacing/(pi*sqrt(g4%horizontal_conductivity_bottom*g4%vertical_conductivity_bottom))* &
         log(dbot/g4%wetted_perimeter)
    call require_close(p4%horizontal_resistance,rhor,2.0e-13_real64,'ipos4 rhor')
    call require_close(p4%radial_resistance,rrad,2.0e-13_real64,'ipos4 rrad')
    v%groundwater_level=15.0_real64
    call evaluate_drainage_ernst_ipos4_response(p4,v,r,d)
    diffl=(v%groundwater_level-g4%drain_bottom_level)/g4%shape_factor
    rver=(v%groundwater_level-g4%interface_level)/g4%vertical_conductivity_top + &
         (g4%interface_level-g4%drain_bottom_level)/g4%vertical_conductivity_bottom
    total=rver+rhor+rrad+g4%entry_resistance
    call require(d%status==DRAIN_ERNST_OK .and. d%evaluated,'ipos4 evaluate')
    call require_close(r%signed_soil_to_drain_rate,diffl/total,2.0e-13_real64,'ipos4 q')
    write(*,'(a)') 'FPM08C2C_IPOS4_SOURCE_EQUATION=PASS'

    call standard_ipos5(g5)
    call prepare_ernst_ipos5(g5,p5,pd)
    call require(pd%status == ERNST_PREP_OK .and. p5%is_valid,'ipos5 prepare')
    eb=max(g5%impermeable_base_level,g5%drain_bottom_level-0.25_real64*g5%drain_spacing)
    hden=8.0_real64*g5%horizontal_conductivity_top*(g5%drain_bottom_level-g5%interface_level)+ &
         8.0_real64*g5%horizontal_conductivity_bottom*(g5%interface_level-eb)
    logarg=g5%geometry_factor*(g5%drain_bottom_level-g5%interface_level)/g5%wetted_perimeter
    rhor=g5%drain_spacing**2/hden
    rrad=g5%drain_spacing/(pi*sqrt(g5%horizontal_conductivity_top*g5%vertical_conductivity_top))*log(logarg)
    call require_close(p5%horizontal_resistance,rhor,2.0e-13_real64,'ipos5 rhor')
    call require_close(p5%radial_resistance,rrad,2.0e-13_real64,'ipos5 rrad')
    v%groundwater_level=20.0_real64
    call evaluate_drainage_ernst_ipos5_response(p5,v,r,d)
    diffl=(v%groundwater_level-g5%drain_bottom_level)/g5%shape_factor
    rver=(v%groundwater_level-g5%drain_bottom_level)/g5%vertical_conductivity_top
    total=rver+rhor+rrad+g5%entry_resistance
    call require(d%status==DRAIN_ERNST_OK .and. d%evaluated,'ipos5 evaluate')
    call require_close(r%signed_soil_to_drain_rate,diffl/total,2.0e-13_real64,'ipos5 q')
    write(*,'(a)') 'FPM08C2C_IPOS5_SOURCE_EQUATION=PASS'
  end subroutine source_equations

  subroutine stable_branch_tangents()
    type(ernst_ipos4_geometry_t) :: g4
    type(ernst_ipos5_geometry_t) :: g5
    type(ernst_ipos4_prepared_t) :: p4
    type(ernst_ipos5_prepared_t) :: p5
    type(ernst_preparation_diagnostics_t) :: pd
    real(real64) :: a,fd

    call standard_ipos4(g4); call prepare_ernst_ipos4(g4,p4,pd)
    call tangent4(p4,5.0_real64,a,fd); call require_close(a,fd,2.0e-8_real64,'ipos4 below tangent')
    call tangent4(p4,15.0_real64,a,fd); call require_close(a,fd,2.0e-8_real64,'ipos4 above tangent')
    write(*,'(a)') 'FPM08C2C_IPOS4_STABLE_BRANCH_TANGENTS_FD=PASS'
    call standard_ipos5(g5); call prepare_ernst_ipos5(g5,p5,pd)
    call tangent5(p5,20.0_real64,a,fd); call require_close(a,fd,2.0e-8_real64,'ipos5 tangent')
    write(*,'(a)') 'FPM08C2C_IPOS5_TANGENT_FD=PASS'
  end subroutine stable_branch_tangents

  subroutine interface_kink()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos4(g)
    g%vertical_conductivity_top=4.0_real64; g%vertical_conductivity_bottom=8.0_real64
    call prepare_ernst_ipos4(g,p,pd); v%groundwater_level=g%interface_level
    call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%at_ipos4_interface_kink .and. .not.r%derivative_defined,'branch-sensitive kink')
    g%vertical_conductivity_top=6.0_real64; g%vertical_conductivity_bottom=6.0_real64
    call prepare_ernst_ipos4(g,p,pd); call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%at_ipos4_interface_kink .and. r%derivative_defined,'equal-Kv interface')
    write(*,'(a)') 'FPM08C2C_IPOS4_INTERFACE_KINK_EXPLICIT=PASS'
  end subroutine interface_kink

  subroutine negative_radial_resistance()
    type(ernst_ipos4_geometry_t) :: g4
    type(ernst_ipos5_geometry_t) :: g5
    type(ernst_ipos4_prepared_t) :: p4
    type(ernst_ipos5_prepared_t) :: p5
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos4(g4); g4%wetted_perimeter=25.0_real64
    call prepare_ernst_ipos4(g4,p4,pd); call require(p4%radial_resistance<0.0_real64,'ipos4 negative rrad')
    v%groundwater_level=15.0_real64; call evaluate_drainage_ernst_ipos4_response(p4,v,r,d)
    call require(d%status==DRAIN_ERNST_OK .and. d%negative_radial_resistance .and. d%total_resistance>0.0_real64,'ipos4 negative rrad admissible')

    call standard_ipos5(g5); g5%geometry_factor=0.5_real64; g5%wetted_perimeter=10.0_real64; g5%entry_resistance=2.0_real64
    call prepare_ernst_ipos5(g5,p5,pd); call require(p5%radial_resistance<0.0_real64,'ipos5 negative rrad')
    v%groundwater_level=20.0_real64; call evaluate_drainage_ernst_ipos5_response(p5,v,r,d)
    call require(d%status==DRAIN_ERNST_OK .and. d%negative_radial_resistance .and. d%total_resistance>0.0_real64,'ipos5 negative rrad admissible')
    write(*,'(a)') 'FPM08C2C_NEGATIVE_RADIAL_RESISTANCE_ADMISSIBLE=PASS'
  end subroutine negative_radial_resistance

  subroutine total_resistance_fail_closed()
    type(ernst_ipos4_geometry_t) :: g
    type(ernst_ipos4_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d
    call standard_ipos4(g); g%wetted_perimeter=500.0_real64; g%entry_resistance=0.0_real64
    call prepare_ernst_ipos4(g,p,pd); call require(pd%status==ERNST_PREP_OK .and. p%fixed_resistance<0.0_real64,'negative fixed fixture')
    v%groundwater_level=1.0_real64; call evaluate_drainage_ernst_ipos4_response(p,v,r,d)
    call require(d%status==DRAIN_ERNST_NUMERICAL_DOMAIN .and. .not.d%evaluated,'total resistance fail closed')
    write(*,'(a)') 'FPM08C2C_POSITIVE_TOTAL_RESISTANCE_FAIL_CLOSED=PASS'
  end subroutine total_resistance_fail_closed

  subroutine cutoff_semantics()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: r
    type(drainage_ernst_diagnostics_t) :: d

    call standard_ipos5(g)
    g%drain_bottom_level=0.0_real64; g%interface_level=-10.0_real64; g%impermeable_base_level=-20.0_real64
    call prepare_ernst_ipos5(g,p,pd); call require(pd%status==ERNST_PREP_OK,'cutoff prepare')
    v%groundwater_level=0.5_real64*DRAIN_ERNST_B110_DIFFL_CUTOFF
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(d%inactive_below_compatibility_cutoff .and. r%derivative_defined .and. r%signed_soil_to_drain_rate==0.0_real64,'below cutoff')
    v%groundwater_level=DRAIN_ERNST_B110_DIFFL_CUTOFF
    call evaluate_drainage_ernst_ipos5_response(p,v,r,d)
    call require(d%status==DRAIN_ERNST_OK .and. d%active .and. d%at_exact_compatibility_cutoff .and. .not.r%derivative_defined,'exact cutoff')
    write(*,'(a)') 'FPM08C2C_EXACT_B110_CUTOFF_BRANCH_EXPLICIT=PASS'
  end subroutine cutoff_semantics

  subroutine stateless_and_ownership()
    type(ernst_ipos5_geometry_t) :: g
    type(ernst_ipos5_prepared_t) :: p
    type(ernst_preparation_diagnostics_t) :: pd
    type(process_hydraulic_view_t) :: v
    type(drainage_ernst_response_t) :: a,b,a2
    type(drainage_ernst_diagnostics_t) :: da,db,da2
    call standard_ipos5(g); call prepare_ernst_ipos5(g,p,pd)
    v%groundwater_level=20.0_real64; call evaluate_drainage_ernst_ipos5_response(p,v,a,da)
    v%groundwater_level=30.0_real64; call evaluate_drainage_ernst_ipos5_response(p,v,b,db)
    v%groundwater_level=20.0_real64; call evaluate_drainage_ernst_ipos5_response(p,v,a2,da2)
    call require(a%signed_soil_to_drain_rate==a2%signed_soil_to_drain_rate .and. a%dq_dgroundwater_level==a2%dq_dgroundwater_level,'A/B/A identity')
    write(*,'(a)') 'FPM08C2C_STATELESS_A_B_A_IDENTITY=PASS'
    call require(pd%immutable_parameter_cache .and. .not.pd%persistent_process_state,'prepared ownership')
    call require(da%prepared_geometry_is_shared_immutable .and. da%mass_is_authoritative_external_transfer .and. .not.da%persistent_process_state,'response ownership')
    write(*,'(a)') 'FPM08C2C_STATE_AND_MASS_OWNERSHIP=PASS'
  end subroutine stateless_and_ownership

  subroutine tangent4(p,gwl,a,fd)
    type(ernst_ipos4_prepared_t),intent(in)::p
    real(real64),intent(in)::gwl
    real(real64),intent(out)::a,fd
    type(process_hydraulic_view_t)::v
    type(drainage_ernst_response_t)::r0,rp,rm
    type(drainage_ernst_diagnostics_t)::d0,dp,dm
    real(real64),parameter::eps=1.0e-6_real64
    v%groundwater_level=gwl; call evaluate_drainage_ernst_ipos4_response(p,v,r0,d0)
    v%groundwater_level=gwl+eps; call evaluate_drainage_ernst_ipos4_response(p,v,rp,dp)
    v%groundwater_level=gwl-eps; call evaluate_drainage_ernst_ipos4_response(p,v,rm,dm)
    call require(r0%derivative_defined .and. dp%status==DRAIN_ERNST_OK .and. dm%status==DRAIN_ERNST_OK,'ipos4 FD domain')
    a=r0%dq_dgroundwater_level; fd=(rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*eps)
  end subroutine tangent4

  subroutine tangent5(p,gwl,a,fd)
    type(ernst_ipos5_prepared_t),intent(in)::p
    real(real64),intent(in)::gwl
    real(real64),intent(out)::a,fd
    type(process_hydraulic_view_t)::v
    type(drainage_ernst_response_t)::r0,rp,rm
    type(drainage_ernst_diagnostics_t)::d0,dp,dm
    real(real64),parameter::eps=1.0e-6_real64
    v%groundwater_level=gwl; call evaluate_drainage_ernst_ipos5_response(p,v,r0,d0)
    v%groundwater_level=gwl+eps; call evaluate_drainage_ernst_ipos5_response(p,v,rp,dp)
    v%groundwater_level=gwl-eps; call evaluate_drainage_ernst_ipos5_response(p,v,rm,dm)
    call require(r0%derivative_defined .and. dp%status==DRAIN_ERNST_OK .and. dm%status==DRAIN_ERNST_OK,'ipos5 FD domain')
    a=r0%dq_dgroundwater_level; fd=(rp%signed_soil_to_drain_rate-rm%signed_soil_to_drain_rate)/(2.0_real64*eps)
  end subroutine tangent5

  subroutine standard_ipos4(g)
    type(ernst_ipos4_geometry_t),intent(out)::g
    g%drain_spacing=100.0_real64; g%shape_factor=1.0_real64; g%drain_bottom_level=0.0_real64
    g%impermeable_base_level=-20.0_real64; g%interface_level=10.0_real64
    g%horizontal_conductivity_bottom=10.0_real64; g%vertical_conductivity_top=4.0_real64
    g%vertical_conductivity_bottom=8.0_real64; g%wetted_perimeter=2.0_real64; g%entry_resistance=1.0_real64
  end subroutine standard_ipos4

  subroutine standard_ipos5(g)
    type(ernst_ipos5_geometry_t),intent(out)::g
    g%drain_spacing=100.0_real64; g%shape_factor=1.0_real64; g%drain_bottom_level=10.0_real64
    g%impermeable_base_level=-20.0_real64; g%interface_level=0.0_real64
    g%horizontal_conductivity_top=10.0_real64; g%horizontal_conductivity_bottom=5.0_real64
    g%vertical_conductivity_top=4.0_real64; g%wetted_perimeter=2.0_real64
    g%geometry_factor=1.5_real64; g%entry_resistance=1.0_real64
  end subroutine standard_ipos5

  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok) then; write(*,'(a,1x,a)') 'FAIL',trim(msg); error stop 1; end if
  end subroutine require

  subroutine require_close(actual,expected,tol,msg)
    real(real64),intent(in)::actual,expected,tol
    character(len=*),intent(in)::msg
    call require(abs(actual-expected)<=tol*max(1.0_real64,abs(expected)),msg)
  end subroutine require_close
end program test_fpm08c2c_ipos45_ernst_response
