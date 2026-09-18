program test_fapp08_rutter_output_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process, only: rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_fmr_rutter_output_application_binding
  implicit none

  type(rutter_interval_result_t) :: r
  type(rutter_diagnostics_t) :: rd
  type(b110_dynamic_top_boundary_request_t) :: base, top
  type(crop_root_uptake_input_t) :: root, bound_root
  type(fmr_rutter_output_binding_diagnostics_t) :: d
  real(real64), parameter :: tol=1.0e-14_real64

  call setup_base(base)
  call setup_root(root)
  rd=rutter_diagnostics_t(); rd%status=RUTTER_OK; rd%result_produced=.true.

  call check_vector(0.0_real64,0.0_real64,0.36989155956560815_real64,1)
  call check_vector(0.54981549748798_real64,0.0_real64,0.0047014973566050335_real64,10)
  call check_vector(0.41764215626499124_real64,0.0_real64,0.03749398442638522_real64,20)

  ! Generic nonzero irrigation mapping.
  r=rutter_interval_result_t()
  r%net_rain_cm_per_day=0.12_real64
  r%net_surface_irrigation_cm_per_day=0.34_real64
  r%potential_transpiration_cm_per_day=0.56_real64
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,30)
  call require(abs(top%precipitation_rate_cm_per_day-0.12_real64)<tol,31)
  call require(abs(top%irrigation_rate_cm_per_day-0.34_real64)<tol,32)
  call preserve_top(base,top,33)

  call fmr_bind_rutter_ptra_to_root_input(root,3,r,rd,bound_root,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced .and. d%ptra_bound,50)
  call require(abs(bound_root%potential_transpiration-0.56_real64)<tol,51)
  call require(bound_root%rooted_nodes==root%rooted_nodes,52)
  call require(all(bound_root%cumulative_root_fraction==root%cumulative_root_fraction),53)

  ! Non-emerged crop uses canonical zero.
  root=crop_root_uptake_input_t()
  call fmr_bind_rutter_ptra_to_root_input(root,3,r,rd,bound_root,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%inactive_crop_zero_applied,60)
  call require(bound_root%potential_transpiration==0.0_real64 .and. bound_root%rooted_nodes==0,61)

  ! Fail closed on bad upstream/result fields.
  rd%result_produced=.false.
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_UPSTREAM_REJECTED .and. .not.d%result_produced,70)

  rd%result_produced=.true.
  r%net_rain_cm_per_day=-1.0_real64
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_SURFACE_FLUX .and. .not.d%result_produced,71)

  r%net_rain_cm_per_day=0.0_real64
  r%potential_transpiration_cm_per_day=-1.0_real64
  call setup_root(root)
  call fmr_bind_rutter_ptra_to_root_input(root,3,r,rd,bound_root,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_PTRA .and. .not.d%result_produced,72)

  print '(A)','F_APP08_FROZEN_B111_VECTORS=PASS'
  print '(A)','F_APP08_RUTTER_SURFACE_FLUX_BINDING=PASS'
  print '(A)','F_APP08_RUTTER_PTRA_ROOT_BINDING=PASS'
  print '(A)','F_APP08_FAIL_CLOSED=PASS'

contains
  subroutine check_vector(net_rain,net_irr,ptra,n)
    real(real64),intent(in)::net_rain,net_irr,ptra
    integer,intent(in)::n
    r=rutter_interval_result_t()
    r%net_rain_cm_per_day=net_rain
    r%net_surface_irrigation_cm_per_day=net_irr
    r%potential_transpiration_cm_per_day=ptra
    call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,n)
    call require(abs(top%precipitation_rate_cm_per_day-net_rain)<tol,n+1)
    call require(abs(top%irrigation_rate_cm_per_day-net_irr)<tol,n+2)
    call preserve_top(base,top,n+3)
    call fmr_bind_rutter_ptra_to_root_input(root,3,r,rd,bound_root,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,n+4)
    call require(abs(bound_root%potential_transpiration-ptra)<tol,n+5)
    call require(bound_root%rooted_nodes==root%rooted_nodes,n+6)
  end subroutine

  subroutine setup_root(x)
    type(crop_root_uptake_input_t),intent(out)::x
    x=crop_root_uptake_input_t()
    x%crop_emerged=.true.
    x%potential_transpiration=9.0_real64
    x%rooted_nodes=2
    allocate(x%cumulative_root_fraction(3))
    x%cumulative_root_fraction=[0.0_real64,0.5_real64,1.0_real64]
  end subroutine

  subroutine setup_base(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-123.0_real64
    x%water_content_top=0.27_real64
    x%candidate_ponding_depth_cm=0.02_real64
    x%previous_ponding_depth_cm=0.03_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.12_real64
    x%runon_rate_cm_per_day=0.23_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.34_real64
    x%potential_pond_evaporation_cm_per_day=0.45_real64
    x%ponding_max_cm=1.0_real64
    x%runoff_resistance_day=0.2_real64
    x%runoff_exponent=1.0_real64
  end subroutine

  subroutine preserve_top(a,b,n)
    type(b110_dynamic_top_boundary_request_t),intent(in)::a,b
    integer,intent(in)::n
    call require(a%conductivity_mean_method==b%conductivity_mean_method,n)
    call require(a%pressure_head_top_cm==b%pressure_head_top_cm,n)
    call require(a%water_content_top==b%water_content_top,n)
    call require(a%candidate_ponding_depth_cm==b%candidate_ponding_depth_cm,n)
    call require(a%previous_ponding_depth_cm==b%previous_ponding_depth_cm,n)
    call require(a%step_duration_day==b%step_duration_day,n)
    call require(a%snowmelt_rate_cm_per_day==b%snowmelt_rate_cm_per_day,n)
    call require(a%runon_rate_cm_per_day==b%runon_rate_cm_per_day,n)
    call require(a%potential_bare_soil_evaporation_cm_per_day==b%potential_bare_soil_evaporation_cm_per_day,n)
    call require(a%potential_pond_evaporation_cm_per_day==b%potential_pond_evaporation_cm_per_day,n)
    call require(a%ponding_max_cm==b%ponding_max_cm,n)
    call require(a%runoff_resistance_day==b%runoff_resistance_day,n)
    call require(a%runoff_exponent==b%runoff_exponent,n)
  end subroutine

  subroutine require(ok,n)
    logical,intent(in)::ok
    integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_APP08_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fapp08_rutter_output_binding
