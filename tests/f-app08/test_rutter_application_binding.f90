program test_fapp08_rutter_application_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process, only: rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_fmr_rutter_application_binding
  implicit none

  type(rutter_interval_result_t) :: r
  type(rutter_diagnostics_t) :: rd
  type(b110_dynamic_top_boundary_request_t) :: base_top, top
  type(crop_root_uptake_input_t) :: base_root, root
  type(fmr_rutter_binding_diagnostics_t) :: d
  real(real64), parameter :: tol=1.0e-14_real64

  rd=rutter_diagnostics_t(); rd%status=RUTTER_OK; rd%result_produced=.true.
  r=rutter_interval_result_t()
  r%net_rain_cm_per_day=0.41764215626499124_real64
  r%net_surface_irrigation_cm_per_day=31.25_real64
  r%potential_transpiration_cm_per_day=0.037493984426385220_real64

  call setup_top(base_top)
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base_top,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,1)
  call require(abs(top%precipitation_rate_cm_per_day-r%net_rain_cm_per_day)<tol,2)
  call require(abs(top%irrigation_rate_cm_per_day-r%net_surface_irrigation_cm_per_day)<tol,3)
  call preserve_top(base_top,top,4)

  call setup_root(base_root)
  call fmr_bind_rutter_ptra_to_root_input(base_root,4,r,rd,root,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,20)
  call require(root%crop_emerged .and. root%rooted_nodes==2,21)
  call require(abs(root%potential_transpiration-r%potential_transpiration_cm_per_day)<tol,22)
  call require(allocated(root%cumulative_root_fraction),23)
  call require(maxval(abs(root%cumulative_root_fraction-[0.0_real64,0.4_real64,1.0_real64]))<tol,24)

  base_root=crop_root_uptake_input_t()
  call fmr_bind_rutter_ptra_to_root_input(base_root,4,r,rd,root,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%inactive_crop_zero_applied,25)
  call require(.not.root%crop_emerged .and. root%potential_transpiration==0.0_real64 .and. root%rooted_nodes==0,26)

  r%net_rain_cm_per_day=-1.0_real64
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base_top,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_NET_RAIN .and. .not.d%result_produced,27)

  r=rutter_interval_result_t(); r%potential_transpiration_cm_per_day=-1.0_real64
  call setup_root(base_root)
  call fmr_bind_rutter_ptra_to_root_input(base_root,4,r,rd,root,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_PTRA .and. .not.d%result_produced,28)

  rd%result_produced=.false.
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base_top,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_UPSTREAM_REJECTED .and. .not.d%result_produced,29)

  print '(A)','F_APP08_RUTTER_SURFACE_FLUX_IDENTITY=PASS'
  print '(A)','F_APP08_RUTTER_ROOT_PTRA_IDENTITY=PASS'
  print '(A)','F_APP08_INACTIVE_CROP_CANONICAL_ZERO=PASS'
  print '(A)','F_APP08_FAIL_CLOSED=PASS'
contains
  subroutine setup_top(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-123.0_real64
    x%water_content_top=0.21_real64
    x%candidate_ponding_depth_cm=0.02_real64
    x%previous_ponding_depth_cm=0.03_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.31_real64
    x%runon_rate_cm_per_day=0.41_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.51_real64
    x%potential_pond_evaporation_cm_per_day=0.61_real64
    x%ponding_max_cm=1.2_real64
    x%runoff_resistance_day=0.2_real64
    x%runoff_exponent=1.0_real64
  end subroutine
  subroutine preserve_top(a,b,n)
    type(b110_dynamic_top_boundary_request_t),intent(in)::a,b
    integer,intent(in)::n
    call require(a%conductivity_mean_method==b%conductivity_mean_method,n)
    call require(a%pressure_head_top_cm==b%pressure_head_top_cm,n+1)
    call require(a%water_content_top==b%water_content_top,n+2)
    call require(a%candidate_ponding_depth_cm==b%candidate_ponding_depth_cm,n+3)
    call require(a%previous_ponding_depth_cm==b%previous_ponding_depth_cm,n+4)
    call require(a%step_duration_day==b%step_duration_day,n+5)
    call require(a%snowmelt_rate_cm_per_day==b%snowmelt_rate_cm_per_day,n+6)
    call require(a%runon_rate_cm_per_day==b%runon_rate_cm_per_day,n+7)
    call require(a%potential_bare_soil_evaporation_cm_per_day==b%potential_bare_soil_evaporation_cm_per_day,n+8)
    call require(a%potential_pond_evaporation_cm_per_day==b%potential_pond_evaporation_cm_per_day,n+9)
    call require(a%ponding_max_cm==b%ponding_max_cm,n+10)
    call require(a%runoff_resistance_day==b%runoff_resistance_day,n+11)
    call require(a%runoff_exponent==b%runoff_exponent,n+12)
  end subroutine
  subroutine setup_root(x)
    type(crop_root_uptake_input_t),intent(out)::x
    x=crop_root_uptake_input_t()
    x%crop_emerged=.true.; x%potential_transpiration=99.0_real64; x%rooted_nodes=2
    allocate(x%cumulative_root_fraction(3))
    x%cumulative_root_fraction=[0.0_real64,0.4_real64,1.0_real64]
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok; integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_APP08_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fapp08_rutter_application_binding
