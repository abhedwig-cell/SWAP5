program test_fvq120_fapp07_composition_independent
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, IRRIGATION_APPLICATION_SURFACE
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t
  use mod_rutter_interception_process, only: rutter_interval_input_t, rutter_interval_result_t, rutter_diagnostics_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_hupsel_irrigation_application_binding
  implicit none

  character(len=1024) :: fixture, line
  integer :: unit, ios, n, n0, n3, year, daynr, swinter
  real(real64) :: tcum, dt, gross_irrig, net_irrig, maxerr
  type(b110_dynamic_top_boundary_request_t) :: base, top
  type(irrigation_flux_result_t) :: fixed
  type(irrigation_diagnostics_t) :: fixed_d
  type(tcs1_dcs2_sprinkling_result_t) :: sched
  type(tcs1_dcs2_sprinkling_diagnostics_t) :: sched_d
  type(rutter_interval_input_t) :: rin, rout
  type(rutter_interval_result_t) :: rr
  type(rutter_diagnostics_t) :: rd
  type(fmr_hupsel_irrigation_binding_diagnostics_t) :: d

  call get_command_argument(1,fixture)
  if(len_trim(fixture)==0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if(ios/=0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if(ios/=0) error stop 3

  n=0; n0=0; n3=0; maxerr=0.0_real64
  do
    read(unit,'(A)',iostat=ios) line
    if(ios<0) exit
    if(ios/=0) error stop 4
    read(line,*,iostat=ios) year,daynr,tcum,dt,swinter,gross_irrig,net_irrig
    if(ios/=0) error stop 5
    if(gross_irrig<=0.0_real64) error stop 6
    if(net_irrig<0.0_real64 .or. net_irrig>gross_irrig) error stop 7

    call sentinel_top(base)

    select case(swinter)
    case(0)
      fixed=irrigation_flux_result_t()
      fixed%applied=.true.
      fixed%application_type=IRRIGATION_APPLICATION_SURFACE
      fixed%surface_gross_rate=gross_irrig
      fixed_d=irrigation_diagnostics_t()
      call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base,fixed,fixed_d,top,d)
      if(d%status/=FMR_HUPSEL_IRR_BIND_OK .or. .not.d%result_produced) error stop 8
      maxerr=max(maxerr,abs(top%irrigation_rate_cm_per_day-net_irrig))
      call preserve_non_irrigation(base,top,9)
      n0=n0+1

    case(3)
      sched=tcs1_dcs2_sprinkling_result_t()
      sched%applied=.true.
      sched%gross_surface_rate_cm_per_day=gross_irrig
      sched_d=tcs1_dcs2_sprinkling_diagnostics_t()
      rin=rutter_interval_input_t()
      rin%gross_rain_cm_per_day=0.123_real64
      rin%vegetation_cover_fraction=0.456_real64
      rin%canopy_storage_capacity_cm=0.078_real64
      rin%interception_evaporation_capacity_cm_per_day=0.091_real64
      rin%potential_transpiration_dry_cm_per_day=0.22_real64
      rin%potential_transpiration_wet_cm_per_day=0.11_real64
      rin%interval_days=max(dt,1.0e-6_real64)
      call fmr_bind_tcs1_sprinkling_to_rutter(rin,sched,sched_d,rout,d)
      if(d%status/=FMR_HUPSEL_IRR_BIND_OK .or. .not.d%result_produced) error stop 10
      if(abs(rout%surface_irrigation_cm_per_day-gross_irrig)>0.0_real64) error stop 11
      if(.not.rout%surface_irrigation_is_intercepted) error stop 12
      if(rout%gross_rain_cm_per_day/=rin%gross_rain_cm_per_day) error stop 13
      if(rout%vegetation_cover_fraction/=rin%vegetation_cover_fraction) error stop 14

      rr=rutter_interval_result_t()
      rr%net_surface_irrigation_cm_per_day=net_irrig
      rd=rutter_diagnostics_t(); rd%result_produced=.true.
      call fmr_bind_rutter_net_irrigation_to_dynamic_top(base,rr,rd,top,d)
      if(d%status/=FMR_HUPSEL_IRR_BIND_OK .or. .not.d%result_produced) error stop 15
      maxerr=max(maxerr,abs(top%irrigation_rate_cm_per_day-net_irrig))
      call preserve_non_irrigation(base,top,16)
      n3=n3+1
    case default
      error stop 17
    end select
    n=n+1
  end do
  close(unit)

  if(n/=110 .or. n0/=18 .or. n3/=92) error stop 18
  if(maxerr/=0.0_real64) error stop 19

  ! Independent fail-closed check on an invalid scheduled gross rate.
  sched=tcs1_dcs2_sprinkling_result_t(); sched%applied=.true.; sched%gross_surface_rate_cm_per_day=-0.1_real64
  sched_d=tcs1_dcs2_sprinkling_diagnostics_t()
  call fmr_bind_tcs1_sprinkling_to_rutter(rin,sched,sched_d,rout,d)
  if(d%status/=FMR_HUPSEL_IRR_BIND_INVALID_RATE .or. d%result_produced) error stop 20

  write(*,'(A,I0)') 'F_VQ120_COMPOSITION_RECORDS=',n
  write(*,'(A,I0)') 'F_VQ120_COMPOSITION_SWINTER0=',n0
  write(*,'(A,I0)') 'F_VQ120_COMPOSITION_SWINTER3=',n3
  write(*,'(A,ES24.16)') 'F_VQ120_COMPOSITION_MAX_ERROR=',maxerr
  write(*,'(A)') 'F_VQ120_EXACT_110_BINDING_COMPOSITION=PASS'
contains
  subroutine sentinel_top(x)
    type(b110_dynamic_top_boundary_request_t),intent(out)::x
    x=b110_dynamic_top_boundary_request_t()
    x%conductivity_mean_method=4
    x%pressure_head_top_cm=-111.0_real64
    x%water_content_top=0.27_real64
    x%candidate_ponding_depth_cm=0.03_real64
    x%previous_ponding_depth_cm=0.02_real64
    x%step_duration_day=0.04_real64
    x%precipitation_rate_cm_per_day=0.12_real64
    x%irrigation_rate_cm_per_day=99.0_real64
    x%snowmelt_rate_cm_per_day=0.23_real64
    x%runon_rate_cm_per_day=0.34_real64
    x%potential_bare_soil_evaporation_cm_per_day=0.45_real64
    x%potential_pond_evaporation_cm_per_day=0.56_real64
    x%ponding_max_cm=1.2_real64
    x%runoff_resistance_day=0.4_real64
    x%runoff_exponent=1.0_real64
  end subroutine
  subroutine preserve_non_irrigation(a,b,n)
    type(b110_dynamic_top_boundary_request_t),intent(in)::a,b
    integer,intent(in)::n
    call require(a%conductivity_mean_method==b%conductivity_mean_method,n)
    call require(a%pressure_head_top_cm==b%pressure_head_top_cm,n)
    call require(a%water_content_top==b%water_content_top,n)
    call require(a%candidate_ponding_depth_cm==b%candidate_ponding_depth_cm,n)
    call require(a%previous_ponding_depth_cm==b%previous_ponding_depth_cm,n)
    call require(a%step_duration_day==b%step_duration_day,n)
    call require(a%precipitation_rate_cm_per_day==b%precipitation_rate_cm_per_day,n)
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
      write(*,'(A,I0)') 'F_VQ120_COMPOSITION_FAIL=',n
      error stop 1
    end if
  end subroutine
end program test_fvq120_fapp07_composition_independent
