program test_fvq122_fapp08_rutter_bindings_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process, only: rutter_interval_result_t, rutter_diagnostics_t, RUTTER_OK
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_fmr_rutter_application_binding
  implicit none
  integer :: i
  real(real64) :: rain, irr, ptra
  type(rutter_interval_result_t) :: r
  type(rutter_diagnostics_t) :: rd
  type(b110_dynamic_top_boundary_request_t) :: base, bound
  type(crop_root_uptake_input_t) :: root0, root
  type(fmr_rutter_binding_diagnostics_t) :: d

  rd=rutter_diagnostics_t(); rd%status=RUTTER_OK; rd%result_produced=.true.
  do i=0,100
    rain=0.013_real64*real(i,real64)
    irr=0.071_real64*real(100-i,real64)
    ptra=0.0027_real64*real(i,real64)
    r=rutter_interval_result_t()
    r%net_rain_cm_per_day=rain
    r%net_surface_irrigation_cm_per_day=irr
    r%potential_transpiration_cm_per_day=ptra

    call top_sentinel(base)
    call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,bound,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,1)
    call require(bound%precipitation_rate_cm_per_day==rain,2)
    call require(bound%irrigation_rate_cm_per_day==irr,3)
    call preserve_top(base,bound,4)

    call root_sentinel(root0)
    call fmr_bind_rutter_ptra_to_root_input(root0,5,r,rd,root,d)
    call require(d%status==FMR_RUTTER_BIND_OK .and. d%result_produced,20)
    call require(root%potential_transpiration==ptra,21)
    call require(root%crop_emerged .and. root%rooted_nodes==3,22)
    call require(allocated(root%cumulative_root_fraction),23)
    call require(maxval(abs(root%cumulative_root_fraction-[0.0_real64,0.2_real64,0.7_real64,1.0_real64]))==0.0_real64,24)
  end do

  r=rutter_interval_result_t(); r%net_rain_cm_per_day=-1.0_real64
  call top_sentinel(base)
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,bound,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_NET_RAIN .and. .not.d%result_produced,30)

  r=rutter_interval_result_t(); r%potential_transpiration_cm_per_day=-1.0_real64
  call root_sentinel(root0)
  call fmr_bind_rutter_ptra_to_root_input(root0,5,r,rd,root,d)
  call require(d%status==FMR_RUTTER_BIND_INVALID_PTRA .and. .not.d%result_produced,31)

  rd%result_produced=.false.
  r=rutter_interval_result_t()
  call fmr_bind_rutter_surface_fluxes_to_dynamic_top(base,r,rd,bound,d)
  call require(d%status==FMR_RUTTER_BIND_UPSTREAM_REJECTED .and. .not.d%result_produced,32)

  print '(A)','F_VQ122_GENERIC_SURFACE_IDENTITY_SWEEP=PASS'
  print '(A)','F_VQ122_GENERIC_ROOT_IDENTITY_SWEEP=PASS'
  print '(A)','F_VQ122_PRESERVATION=PASS'
  print '(A)','F_VQ122_FAIL_CLOSED=PASS'
contains
  subroutine top_sentinel(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=5
    x%pressure_head_top_cm=-444.0_real64
    x%water_content_top=0.29_real64
    x%candidate_ponding_depth_cm=0.01_real64
    x%previous_ponding_depth_cm=0.02_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=99.0_real64
    x%irrigation_rate_cm_per_day=88.0_real64
    x%snowmelt_rate_cm_per_day=0.11_real64
    x%runon_rate_cm_per_day=0.22_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.33_real64
    x%potential_pond_evaporation_cm_per_day=0.44_real64
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
  subroutine root_sentinel(x)
    type(crop_root_uptake_input_t),intent(out)::x
    x=crop_root_uptake_input_t()
    x%crop_emerged=.true.; x%potential_transpiration=77.0_real64; x%rooted_nodes=3
    allocate(x%cumulative_root_fraction(4))
    x%cumulative_root_fraction=[0.0_real64,0.2_real64,0.7_real64,1.0_real64]
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok; integer,intent(in)::n
    if(.not.ok) then
      write(*,'(A,I0)') 'F_VQ122_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fvq122_fapp08_rutter_bindings_independent
