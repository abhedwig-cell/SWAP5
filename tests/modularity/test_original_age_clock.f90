program test_original_age_clock
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_solute_compartment_state
  use mod_b111_age_tracer_substep
  implicit none
  type(solute_compartment_state_t)::s,c,before
  type(b111_age_tracer_substep_forcing_t)::f,g
  type(b111_age_tracer_substep_receipt_t)::r
  real(real64)::production
  integer::status,i
  call initialize_solute_compartment_state([0d0],0d0,0d0,[2d0],s,status)
  call require(status==SOLCOMP_OK,'initial state')
  f%dt_day=.25d0;f%theta_previous=[.5d0];f%theta=[.25d0];f%dz_cm=[4d0]
  f%q_face_up_cm_day=[1d0,0d0];f%root_sink_cm_day=[0d0]
  allocate(f%qdra_cm_day(0,1))
  f%accepted_surface_age_available=.true.
  call advance_b111_age_tracer_substep(s,f,c,r)
  call require(r%status==B111_AGE_SUBSTEP_INVALID,'default top domain preserved')
  f%evaporative_top_retains_age=.true.;f%production_theta_mean=[.375d0]
  production=0d0
  do i=1,4
    before=s
    call advance_b111_age_tracer_substep(s,f,c,r)
    call require(r%status==B111_AGE_SUBSTEP_OK,'explicit original top and midpoint accepted')
    call require(all(s%age_amount==before%age_amount),'committed amount unchanged')
    call require(r%production_amount_cm_day==.375d0,'water-step midpoint despite age subcycling')
    call require(r%pond_to_soil_cm_day==0d0,'retained tracer has no age boundary flux')
    call require(r%balance_residual_cm_day==0d0,'exact dyadic age balance')
    production=production+r%production_amount_cm_day;s=c;f%theta_previous=f%theta
  end do
  call require(production==1.5d0.and.sum(s%age_amount)==3.5d0,'cm day production and four-step inventory')
  g=f;g%production_theta_mean=[ieee_value(0d0,ieee_quiet_nan)];call refused(g,'nonfinite midpoint')
  g=f;g%production_theta_mean=[-1d0];call refused(g,'negative midpoint')
  g=f;g%production_theta_mean=[1.01d0];call refused(g,'invalid water midpoint')
  g=f;g%production_theta_mean=[.3d0,.3d0];call refused(g,'wrong midpoint geometry')
  g=f;g%accepted_surface_age_available=.false.;call refused(g,'implicit retention refused')
  g=f;g%accepted_surface_age_input_cm_day=.01d0;call refused(g,'retention with inflowing age refused')
  g=f;g%accepted_surface_age_input_cm_day=-.01d0;call refused(g,'negative handoff still refused')
  g=f;g%q_face_up_cm_day(1)=-1d0;call refused(g,'retention with infiltrating water refused')
  print *,'ORIGINAL_AGE_CLOCK_RETENTION_UNITS_AND_REFUSALS=PASS'
contains
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print *,label
      error stop 'original age clock'
    end if
  end subroutine
  subroutine refused(input,label)
    type(b111_age_tracer_substep_forcing_t),intent(in)::input
    character(*),intent(in)::label
    call advance_b111_age_tracer_substep(s,input,c,r)
    call require(r%status==B111_AGE_SUBSTEP_INVALID,label)
    call require(all(c%age_amount==s%age_amount),'invalid candidate preserves amount')
  end subroutine
end program
