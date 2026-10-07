program test_mc_irr01_management_routing
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_irrigation_process, only: irrigation_flux_result_t, IRRIGATION_APPLICATION_SURFACE, &
       IRRIGATION_APPLICATION_SPRINKLER
  use mod_scheduled_irrigation_management_policy, only: irrigation_management_policy_result_t
  use mod_irrigation_root_zone_summary, only: irrigation_root_zone_summary_t
  use mod_fmr_scheduled_management_irrigation_application
  use mod_fmr_scheduled_management_irrigation_routing
  use mod_fmr_hupsel_irrigation_application_binding, only: fmr_hupsel_irrigation_binding_diagnostics_t, &
       FMR_HUPSEL_IRR_BIND_OK, FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_rutter_interception_process, only: rutter_interval_input_t
  implicit none

  type(fmr_irrigation_management_parameters_t) :: p
  type(fmr_irrigation_management_state_t) :: s,c
  type(fmr_irrigation_management_request_t) :: r
  type(process_hydraulic_view_t) :: h
  type(irrigation_flux_result_t) :: flux
  type(irrigation_management_policy_result_t) :: policy
  type(irrigation_root_zone_summary_t) :: summary
  type(fmr_irrigation_management_diagnostics_t) :: mdiag
  type(fmr_hupsel_irrigation_binding_diagnostics_t) :: bdiag
  type(b110_dynamic_top_boundary_request_t) :: base_top,bound_top
  type(rutter_interval_input_t) :: base_rutter,bound_rutter
  real(real64), parameter :: tol=1.0e-12_real64

  call setup(p,h,r)
  p%application_type=IRRIGATION_APPLICATION_SURFACE
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,mdiag)
  call require(mdiag%status==FMR_IRR_MGMT_APP_OK .and. flux%applied,1)
  base_top=b110_dynamic_top_boundary_request_t()
  base_top%precipitation_rate_cm_per_day=1.25_real64
  call fmr_bind_management_surface_to_dynamic_top(base_top,flux,mdiag,bound_top,bdiag)
  call require(bdiag%status==FMR_HUPSEL_IRR_BIND_OK .and. bdiag%result_produced,2)
  call require(abs(bound_top%irrigation_rate_cm_per_day-flux%surface_gross_rate)<tol,3)
  call require(abs(bound_top%precipitation_rate_cm_per_day-base_top%precipitation_rate_cm_per_day)<tol,4)

  call setup(p,h,r)
  p%application_type=IRRIGATION_APPLICATION_SPRINKLER
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,mdiag)
  call require(mdiag%status==FMR_IRR_MGMT_APP_OK .and. flux%applied,5)
  base_rutter=rutter_interval_input_t()
  base_rutter%gross_rain_cm_per_day=0.2_real64
  base_rutter%vegetation_cover_fraction=0.4_real64
  call fmr_bind_management_sprinkler_to_rutter(base_rutter,flux,mdiag,bound_rutter,bdiag)
  call require(bdiag%status==FMR_HUPSEL_IRR_BIND_OK .and. bdiag%result_produced,6)
  call require(bound_rutter%surface_irrigation_is_intercepted,7)
  call require(abs(bound_rutter%surface_irrigation_cm_per_day-flux%surface_gross_rate)<tol,8)
  call require(abs(bound_rutter%gross_rain_cm_per_day-base_rutter%gross_rain_cm_per_day)<tol,9)

  ! Rejected management evaluation may not be converted into an application route.
  call setup(p,h,r)
  r%t1=r%t0
  call fmr_evaluate_scheduled_management_irrigation(p,s,r,h,c,flux,policy,summary,mdiag)
  call require(mdiag%status/=FMR_IRR_MGMT_APP_OK,10)
  call fmr_bind_management_surface_to_dynamic_top(base_top,flux,mdiag,bound_top,bdiag)
  call require(bdiag%status==FMR_HUPSEL_IRR_BIND_UPSTREAM_REJECTED .and. .not.bdiag%result_produced,11)

  print '(A)','MC_IRR01_MANAGEMENT_SURFACE_ROUTE=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_SPRINKLER_ROUTE=PASS'
  print '(A)','MC_IRR01_MANAGEMENT_ROUTING_FAIL_CLOSED=PASS'

contains

  subroutine setup(p,h,r)
    type(fmr_irrigation_management_parameters_t),intent(out)::p
    type(process_hydraulic_view_t),intent(out)::h
    type(fmr_irrigation_management_request_t),intent(out)::r

    p=fmr_irrigation_management_parameters_t()
    p%active_nodes=3
    p%rate_cm_per_day=0.0_real64
    p%root_zone%active_nodes=3
    p%root_zone%rooted_nodes=2
    p%root_zone%last_rooted_fraction=0.5_real64
    allocate(p%root_zone%node_thickness_cm(3),p%root_zone%field_capacity_water_content(3), &
             p%root_zone%stress_water_content(3),p%root_zone%wilting_water_content(3))
    p%root_zone%node_thickness_cm=[10.0_real64,20.0_real64,30.0_real64]
    p%root_zone%field_capacity_water_content=[0.30_real64,0.35_real64,0.40_real64]
    p%root_zone%stress_water_content=[0.20_real64,0.25_real64,0.30_real64]
    p%root_zone%wilting_water_content=[0.10_real64,0.15_real64,0.20_real64]
    p%policy%timing_criterion=2
    p%policy%tcs2_knot_count=2
    p%policy%tcs2_dvs(1:2)=[0.0_real64,2.0_real64]
    p%policy%tcs2_fraction(1:2)=[0.5_real64,0.5_real64]
    p%policy%depth_criterion=2
    p%policy%dcs2_knot_count=2
    p%policy%dcs2_dvs(1:2)=[0.0_real64,2.0_real64]
    p%policy%dcs2_depth_cm(1:2)=[1.0_real64,1.0_real64]

    h=process_hydraulic_view_t()
    h%active_nodes=3
    allocate(h%pressure_head(3),h%water_content(3))
    h%pressure_head=-100.0_real64
    h%water_content=[0.25_real64,0.30_real64,0.99_real64]

    r=fmr_irrigation_management_request_t()
    r%t0=100.0_real64
    r%t1=101.0_real64
    r%dvs=1.0_real64
    r%selection_opportunity=.true.
    r%irrigation_enabled=.true.
    r%schedule_enabled=.true.
    r%crop_emerged=.true.
    r%irrigation_window_open=.true.
  end subroutine setup

  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok)then
      write(*,'(A,I0)')'MC_IRR01_MANAGEMENT_ROUTING_FAIL=',n
      error stop 1
    end if
  end subroutine require
end program test_mc_irr01_management_routing
