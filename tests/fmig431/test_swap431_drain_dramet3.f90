program test_swap431_drain_dramet3
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_dramet3_response, only: drainage_dramet3_parameters_t, drainage_dramet3_control_t, &
       drainage_dramet3_result_t, drainage_dramet3_diagnostics_t, evaluate_drainage_dramet3_response, &
       DRAMET3_OK, DRAMET3_ALLOCATE_BOTH, DRAMET3_SUPPRESS_DRAINAGE, DRAMET3_SUPPRESS_INFILTRATION, &
       DRAMET3_OPEN_CHANNEL
  implicit none
  type(drainage_dramet3_parameters_t) :: p
  type(drainage_dramet3_control_t) :: c
  type(drainage_dramet3_result_t) :: r
  type(drainage_dramet3_diagnostics_t) :: d
  type(process_hydraulic_view_t) :: v
  real(real64),parameter :: tol=1.0e-13_real64

  allocate(p%owltab_time_t1900(2),p%owltab_level_cm(2))
  p%owltab_time_t1900=[0.0_real64,10.0_real64]
  p%owltab_level_cm=[-50.0_real64,-30.0_real64]
  p%drain_bottom_cm=-60.0_real64
  p%drainage_resistance_day=100.0_real64
  p%infiltration_resistance_day=200.0_real64
  c%sample_time_t1900=5.0_real64
  v%groundwater_level=-20.0_real64

  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(d%status==DRAMET3_OK.and.abs(r%resolved_drain_level_cm+40.0_real64)<tol,'OWLTAB interpolation')
  call require(abs(r%signed_soil_to_drain_rate-0.2_real64)<tol,'positive DRARES response')

  p%allocation_mode=DRAMET3_SUPPRESS_DRAINAGE
  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(abs(r%signed_soil_to_drain_rate)<tol.and.d%drainage_suppressed,'SWALLO2 suppression')

  p%allocation_mode=DRAMET3_ALLOCATE_BOTH
  p%drain_type=DRAMET3_OPEN_CHANNEL
  p%limit_channel_infiltration=.true.
  v%groundwater_level=-80.0_real64
  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(d%infiltration_head_limit_active,'SWLIMINF activation')
  call require(abs(r%effective_head_difference_cm+20.0_real64)<tol,'SWLIMINF channel-depth cap')
  call require(abs(r%signed_soil_to_drain_rate+0.1_real64)<tol,'negative INFRES response')

  p%allocation_mode=DRAMET3_SUPPRESS_INFILTRATION
  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(abs(r%signed_soil_to_drain_rate)<tol.and.d%infiltration_suppressed,'SWALLO3 suppression')

  c%sample_time_t1900=-1.0_real64
  v%groundwater_level=-40.0_real64
  p%allocation_mode=DRAMET3_ALLOCATE_BOTH
  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(d%table_clamped_lower.and.abs(r%resolved_drain_level_cm+50.0_real64)<tol,'OWLTAB lower clamp')

  c%sample_time_t1900=5.0_real64
  p%owltab_level_cm=[-80.0_real64,-70.0_real64]
  call evaluate_drainage_dramet3_response(p,v,c,r,d)
  call require(d%drain_bottom_clamp_active.and.abs(r%resolved_drain_level_cm-p%drain_bottom_cm)<tol,'ZBOTDR clamp')

  print '(a)','SW431_DRAIN_DRAMET3_OWLTAB=PASS'
  print '(a)','SW431_DRAIN_DRAMET3_ALLOCATION=PASS'
  print '(a)','SW431_DRAIN_DRAMET3_INF_LIMIT=PASS'
  print '(a)','SW431_DRAIN_DRAMET3=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)')'SW431_DRAMET3_FAIL',trim(label)
      error stop 431
    end if
  end subroutine
end program
