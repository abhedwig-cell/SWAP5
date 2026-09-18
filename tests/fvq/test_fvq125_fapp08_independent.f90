program test_fvq125_fapp08_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process, only: rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_fmr_rutter_output_application_binding
  implicit none
  integer :: i
  real(real64) :: rain,irr,ptra
  type(rutter_interval_result_t)::r
  type(rutter_diagnostics_t)::rd
  type(b110_dynamic_top_boundary_request_t)::base,top
  type(crop_root_uptake_input_t)::root,bound
  type(fmr_rutter_output_binding_diagnostics_t)::d

  rd=rutter_diagnostics_t(); rd%status=RUTTER_OK; rd%result_produced=.true.
  call setup_base(base)
  call setup_root(root)

  do i=0,200
    rain=0.013_real64*real(i,real64)
    irr=0.017_real64*real(200-i,real64)
    ptra=0.002_real64*real(i,real64)
    r=rutter_interval_result_t()
    r%net_rain_cm_per_day=rain
    r%net_surface_irrigation_cm_per_day=irr
    r%potential_transpiration_cm_per_day=ptra

    call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,1)
    call require(top%precipitation_rate_cm_per_day==rain,2)
    call require(top%irrigation_rate_cm_per_day==irr,3)
    call require(top%snowmelt_rate_cm_per_day==base%snowmelt_rate_cm_per_day,4)
    call require(top%runon_rate_cm_per_day==base%runon_rate_cm_per_day,5)

    call fmr_bind_rutter_ptra_to_root_input(root,4,r,rd,bound,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,6)
    call require(bound%potential_transpiration==ptra,7)
    call require(bound%rooted_nodes==root%rooted_nodes,8)
    call require(all(bound%cumulative_root_fraction==root%cumulative_root_fraction),9)
  end do

  root=crop_root_uptake_input_t()
  r%potential_transpiration_cm_per_day=0.5_real64
  call fmr_bind_rutter_ptra_to_root_input(root,4,r,rd,bound,d)
  call require(d%status==FMR_RUTTER_BIND_OK .and. d%inactive_crop_zero_applied,10)
  call require(bound%potential_transpiration==0.0_real64 .and. bound%rooted_nodes==0,11)

  rd%result_produced=.false.
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,top,d)
  call require(d%status==FMR_RUTTER_BIND_UPSTREAM_REJECTED .and. .not.d%result_produced,12)

  print '(A)','F_VQ125_SURFACE_SWEEP=PASS'
  print '(A)','F_VQ125_ROOT_SWEEP=PASS'
  print '(A)','F_VQ125_INACTIVE_CROP_ZERO=PASS'
  print '(A)','F_VQ125_FAIL_CLOSED=PASS'
contains
  subroutine setup_base(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-111.0_real64
    x%water_content_top=0.2_real64
    x%candidate_ponding_depth_cm=0.01_real64
    x%previous_ponding_depth_cm=0.02_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.1_real64
    x%runon_rate_cm_per_day=0.2_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.3_real64
    x%potential_pond_evaporation_cm_per_day=0.4_real64
    x%ponding_max_cm=1.0_real64
    x%runoff_resistance_day=0.3_real64
    x%runoff_exponent=1.0_real64
  end subroutine
  subroutine setup_root(x)
    type(crop_root_uptake_input_t),intent(out)::x
    x=crop_root_uptake_input_t()
    x%crop_emerged=.true.; x%potential_transpiration=9.0_real64; x%rooted_nodes=3
    allocate(x%cumulative_root_fraction(4))
    x%cumulative_root_fraction=[0.0_real64,0.2_real64,0.7_real64,1.0_real64]
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok; integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_VQ125_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fvq125_fapp08_independent
