program test_swap431_dramet3
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_dramet3_response
  implicit none
  type(process_hydraulic_view_t)::h
  type(dramet3_level_parameters_t)::p
  type(dramet3_level_result_t)::r
  h%active_nodes=1;allocate(h%pressure_head(1),h%water_content(1));h%pressure_head=0.;h%water_content=.3
  allocate(p%control_time(3),p%control_level(3))
  p%control_time=[100._real64,110._real64,120._real64]
  p%control_level=[-2._real64,-1._real64,-3._real64]
  p%drain_bottom=-2.5_real64;p%drainage_resistance=10._real64;p%infiltration_resistance=20._real64

  ! query=t1900+dt-1 = 105: interpolated control -1.5
  h%groundwater_level=-.5_real64
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(r%status==DRAMET3_OK.and.abs(r%resolved_control_level+1.5_real64)<1e-14_real64,'owl interpolation')
  call req(abs(r%signed_soil_to_drain_rate-.1_real64)<1e-14_real64,'drainage resistance')

  p%allocation=DRAMET3_INFILTRATION_ONLY
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(r%signed_soil_to_drain_rate==0._real64.and.r%suppressed_by_allocation,'swallo2')

  p%allocation=DRAMET3_ALLOW_BOTH;p%drain_type=DRAMET3_TYPE_CHANNEL;p%limit_channel_infiltration=.true.
  h%groundwater_level=-4._real64
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(r%infiltration_head_limited,'swliminf active')
  call req(abs(r%head_difference+1._real64)<1e-14_real64,'channel depth cap')
  call req(abs(r%signed_soil_to_drain_rate+.05_real64)<1e-14_real64,'infiltration resistance')

  p%allocation=DRAMET3_DRAINAGE_ONLY
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(r%signed_soil_to_drain_rate==0._real64.and.r%suppressed_by_allocation,'swallo3')

  ! Source clamp: interpolated level below bottom becomes bottom, then no infiltration when equal.
  p%allocation=DRAMET3_ALLOW_BOTH;p%control_level=[-4._real64,-4._real64,-4._real64]
  h%groundwater_level=-3._real64
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(r%control_clamped_to_bottom.and.abs(r%resolved_control_level+2.5_real64)<1e-14_real64,'zbotdr clamp')
  call req(r%signed_soil_to_drain_rate==0._real64,'bottom equal infiltration suppression')

  p%control_level=[-2._real64,-1._real64,-3._real64]
  p%empirical_interflow=.true.;p%interflow_coefficient=2._real64;p%interflow_exponent=.5_real64
  h%groundwater_level=-.5_real64
  call evaluate_dramet3_level(p,h,105._real64,1._real64,r)
  call req(abs(r%signed_soil_to_drain_rate-2._real64)<1e-14_real64,'highest empirical drainage branch')

  print '(A)','SW431_DRAIN_DRAMET3_OWL_RESOLUTION=PASS'
  print '(A)','SW431_DRAIN_ALLOCATION=PASS'
  print '(A)','SW431_DRAIN_INF_LIMIT=PASS'
  print '(A)','SW431_DRAIN_DRAMET3_SIGNED_RESISTANCE=PASS'
contains
  subroutine req(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then;write(*,'(A,1X,A)')'DRAMET3_FAIL',trim(label);error stop 83;end if
  end subroutine
end program
