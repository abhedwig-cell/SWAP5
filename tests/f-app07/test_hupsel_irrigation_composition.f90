program test_fapp07_hupsel_irrigation_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_APPLICATION_SURFACE, scheduled_irrigation_parameters_t, scheduled_irrigation_request_t, &
       irrigation_state_t, IRRIGATION_OK
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_result_t, &
       tcs1_dcs2_sprinkling_diagnostics_t
  use mod_rutter_interception_process, only: rutter_interval_input_t, rutter_interval_result_t, rutter_diagnostics_t
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr_hupsel_irrigation_application_binding
  implicit none

  character(len=1024) :: fixture, line
  integer :: unit, ios, n, n0, n3, iyear, daynr, swinter
  real(real64) :: tcum, dt, gird, nird
  type(b110_dynamic_top_boundary_request_t) :: base_top, bound_top
  type(irrigation_flux_result_t) :: fixed_flux
  type(irrigation_diagnostics_t) :: fixed_diag
  type(tcs1_dcs2_sprinkling_result_t) :: scheduled
  type(tcs1_dcs2_sprinkling_diagnostics_t) :: scheduled_diag
  type(rutter_interval_input_t) :: base_rutter, bound_rutter
  type(rutter_interval_result_t) :: rutter
  type(rutter_diagnostics_t) :: rutter_diag
  type(fmr_hupsel_irrigation_binding_diagnostics_t) :: d
  type(scheduled_irrigation_parameters_t) :: ssdi_p
  type(scheduled_irrigation_request_t) :: ssdi_r
  type(irrigation_state_t) :: ssdi_s, ssdi_c
  type(process_hydraulic_view_t) :: ssdi_view
  type(irrigation_flux_result_t) :: ssdi_flux
  type(irrigation_diagnostics_t) :: ssdi_diag
  real(real64) :: max_error

  call get_command_argument(1,fixture)
  if (len_trim(fixture) == 0) error stop 1
  open(newunit=unit,file=trim(fixture),status='old',action='read',iostat=ios)
  if (ios /= 0) error stop 2
  read(unit,'(A)',iostat=ios) line
  if (ios /= 0) error stop 3

  n=0; n0=0; n3=0; max_error=0.0_real64
  do
    read(unit,'(A)',iostat=ios) line
    if (ios < 0) exit
    if (ios /= 0) error stop 4
    read(line,*,iostat=ios) iyear,daynr,tcum,dt,swinter,gird,nird
    if (ios /= 0) error stop 5

    base_top = b110_dynamic_top_boundary_request_t()
    base_top%precipitation_rate_cm_per_day = 1.25_real64
    base_top%snowmelt_rate_cm_per_day = 2.5_real64
    base_top%runon_rate_cm_per_day = 3.75_real64
    base_top%potential_bare_soil_evaporation_cm_per_day = 0.125_real64

    select case(swinter)
    case(0)
      fixed_flux = irrigation_flux_result_t()
      fixed_flux%applied = .true.
      fixed_flux%application_type = IRRIGATION_APPLICATION_SURFACE
      fixed_flux%surface_gross_rate = gird
      fixed_diag = irrigation_diagnostics_t()
      call fmr_bind_fixed_surface_irrigation_identity_to_dynamic_top(base_top,fixed_flux,fixed_diag,bound_top,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 6
      max_error=max(max_error,abs(bound_top%irrigation_rate_cm_per_day-nird))
      if (bound_top%precipitation_rate_cm_per_day /= base_top%precipitation_rate_cm_per_day) error stop 7
      if (bound_top%snowmelt_rate_cm_per_day /= base_top%snowmelt_rate_cm_per_day) error stop 8
      if (bound_top%runon_rate_cm_per_day /= base_top%runon_rate_cm_per_day) error stop 9
      n0=n0+1

    case(3)
      scheduled = tcs1_dcs2_sprinkling_result_t()
      scheduled%applied = .true.
      scheduled%gross_surface_rate_cm_per_day = gird
      scheduled_diag = tcs1_dcs2_sprinkling_diagnostics_t()
      base_rutter = rutter_interval_input_t()
      base_rutter%gross_rain_cm_per_day = 0.33_real64
      base_rutter%vegetation_cover_fraction = 0.42_real64
      call fmr_bind_tcs1_sprinkling_to_rutter(base_rutter,scheduled,scheduled_diag,bound_rutter,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 10
      if (.not. bound_rutter%surface_irrigation_is_intercepted) error stop 11
      if (bound_rutter%surface_irrigation_cm_per_day /= gird) error stop 12
      if (bound_rutter%gross_rain_cm_per_day /= base_rutter%gross_rain_cm_per_day) error stop 13
      if (bound_rutter%vegetation_cover_fraction /= base_rutter%vegetation_cover_fraction) error stop 14

      rutter = rutter_interval_result_t()
      rutter%net_surface_irrigation_cm_per_day = nird
      rutter_diag = rutter_diagnostics_t()
      rutter_diag%result_produced = .true.
      call fmr_bind_rutter_net_irrigation_to_dynamic_top(base_top,rutter,rutter_diag,bound_top,d)
      if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 15
      max_error=max(max_error,abs(bound_top%irrigation_rate_cm_per_day-nird))
      if (bound_top%precipitation_rate_cm_per_day /= base_top%precipitation_rate_cm_per_day) error stop 16
      if (bound_top%snowmelt_rate_cm_per_day /= base_top%snowmelt_rate_cm_per_day) error stop 17
      if (bound_top%runon_rate_cm_per_day /= base_top%runon_rate_cm_per_day) error stop 18
      n3=n3+1

    case default
      error stop 19
    end select
    n=n+1
  end do
  close(unit)

  if (n /= 110 .or. n0 /= 18 .or. n3 /= 92) error stop 20
  if (max_error /= 0.0_real64) error stop 21

  ! Invalid gross scheduled irrigation must fail closed.
  scheduled = tcs1_dcs2_sprinkling_result_t()
  scheduled%applied = .true.
  scheduled%gross_surface_rate_cm_per_day = -1.0_real64
  scheduled_diag = tcs1_dcs2_sprinkling_diagnostics_t()
  call fmr_bind_tcs1_sprinkling_to_rutter(base_rutter,scheduled,scheduled_diag,bound_rutter,d)
  if (d%status /= FMR_HUPSEL_IRR_BIND_INVALID_RATE .or. d%result_produced) error stop 22

  ! Fixed sprinkling uses interception rather than the surface identity route.
  fixed_flux = irrigation_flux_result_t()
  fixed_flux%applied = .true.
  fixed_flux%application_type = 0
  fixed_flux%surface_gross_rate = 4.25_real64
  fixed_diag = irrigation_diagnostics_t()
  base_rutter = rutter_interval_input_t()
  base_rutter%gross_rain_cm_per_day = 0.2_real64
  call fmr_bind_fixed_sprinkler_to_rutter(base_rutter,fixed_flux,fixed_diag,bound_rutter,d)
  if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 23
  if (.not. bound_rutter%surface_irrigation_is_intercepted) error stop 24
  if (bound_rutter%surface_irrigation_cm_per_day /= 4.25_real64) error stop 25

  ! Scheduled surface irrigation bypasses canopy interception and binds gross=net to the top boundary.
  scheduled = tcs1_dcs2_sprinkling_result_t()
  scheduled%applied = .true.
  scheduled%gross_surface_rate_cm_per_day = 5.5_real64
  scheduled_diag = tcs1_dcs2_sprinkling_diagnostics_t()
  base_top = b110_dynamic_top_boundary_request_t()
  base_top%precipitation_rate_cm_per_day = 1.25_real64
  call fmr_bind_tcs1_surface_identity_to_dynamic_top(base_top,scheduled,scheduled_diag,bound_top,d)
  if (d%status /= FMR_HUPSEL_IRR_BIND_OK .or. .not. d%result_produced) error stop 26
  if (bound_top%irrigation_rate_cm_per_day /= 5.5_real64) error stop 27
  if (bound_top%precipitation_rate_cm_per_day /= base_top%precipitation_rate_cm_per_day) error stop 28

  ! Runtime owner invokes the independently qualified TCS7/DCS2 single-node SSDI process.
  ssdi_p = scheduled_irrigation_parameters_t()
  ssdi_p%scheduled_irrigation_enabled = .true.
  ssdi_p%active_nodes = 3
  ssdi_p%sensor_node = 2
  ssdi_p%single_ssdi_node = 3
  ssdi_p%irr_rate_cm_per_day = 1.0_real64
  ssdi_p%tcs7_knot_count = 2
  ssdi_p%tcs7_dvs(1:2) = [0.0_real64,2.0_real64]
  ssdi_p%tcs7_pressure_head(1:2) = [-100.0_real64,-100.0_real64]
  ssdi_p%dcs2_knot_count = 2
  ssdi_p%dcs2_dvs(1:2) = [0.0_real64,2.0_real64]
  ssdi_p%dcs2_depth_cm(1:2) = [0.25_real64,0.25_real64]
  allocate(ssdi_view%pressure_head(3),ssdi_view%water_content(3))
  ssdi_view%active_nodes = 3
  ssdi_view%pressure_head = -50.0_real64
  ssdi_view%pressure_head(2) = -150.0_real64
  ssdi_view%water_content = 0.25_real64
  ssdi_r = scheduled_irrigation_request_t()
  ssdi_r%t0 = 0.0_real64; ssdi_r%t1 = 0.25_real64; ssdi_r%dvs = 1.0_real64
  ssdi_r%selection_opportunity = .true.; ssdi_r%irrigation_enabled = .true.
  ssdi_r%schedule_enabled = .true.; ssdi_r%crop_emerged = .true.; ssdi_r%irrigation_window_open = .true.
  call fmr_evaluate_tcs7_dcs2_ssdi(ssdi_p,ssdi_s,ssdi_r,ssdi_view,ssdi_c,ssdi_flux,ssdi_diag)
  if (ssdi_diag%status /= IRRIGATION_OK .or. .not. ssdi_flux%applied) error stop 29
  if (.not. allocated(ssdi_flux%subsurface_source)) error stop 30
  if (count(abs(ssdi_flux%subsurface_source) > tiny(1.0_real64)) /= 1) error stop 31
  if (ssdi_flux%subsurface_source(3) /= 1.0_real64) error stop 32
  if (ssdi_flux%external_inflow_amount /= 0.25_real64) error stop 33

  write(*,'(A,I0)') 'F_APP07_EXACT_ACTIVE_INTERVALS=',n
  write(*,'(A,I0)') 'F_APP07_SWINTER0_INTERVALS=',n0
  write(*,'(A,I0)') 'F_APP07_SWINTER3_INTERVALS=',n3
  write(*,'(A,ES24.16)') 'F_APP07_MAX_COMPOSITION_ERROR=',max_error
  write(*,'(A)') 'F_APP07_IRRIGATION_RUTTER_DYNAMIC_TOP_COMPOSITION=PASS'
  write(*,'(A)') 'F_APP07_COMPOSITION_FAIL_CLOSED=PASS'
end program test_fapp07_hupsel_irrigation_composition
