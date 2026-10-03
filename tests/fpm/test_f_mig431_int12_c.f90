program test_f_mig431_int12_c
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_pmdirect_swetr0_process
  use mod_fmr_interception_source_window_binding
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t
  use mod_fmr_pmdirect_dynamic_top_boundary_binding
  implicit none

  type :: fmr_serialized_test_result_t
    integer(int64) :: column_id = 0_int64
    real(real64) :: requested_t0 = 0.0_real64
    real(real64) :: requested_t1 = 0.0_real64
    logical :: committed = .false.
    integer :: accepted_substeps = 0
    integer(int64) :: initial_revision = 0_int64
    integer(int64) :: final_revision = 0_int64
    real(real64) :: final_committed_time = 0.0_real64
    logical :: final_committed_time_bound = .false.
  end type fmr_serialized_test_result_t

  real(real64), parameter :: TOL=1.0e-14_real64
  integer(int64), parameter :: COLUMN_ID=430401_int64
  integer(int64), parameter :: WINDOW_ID=430402_int64
  type(pmdirect_swetr0_weather_t) :: weather
  type(pmdirect_swetr0_site_t) :: site
  type(pmdirect_swetr0_canopy_t) :: canopy
  type(pmdirect_swetr0_daily_result_t) :: daily
  type(pmdirect_swetr0_interval_result_t) :: interval, bound_interval
  type(pmdirect_swetr0_diagnostics_t) :: process_diagnostics
  type(fmr_interception_source_window_t) :: owner, restored
  type(fmr_interception_source_window_restart_t) :: restart
  type(b110_dynamic_top_boundary_request_t) :: base_request, bound_request
  type(fmr_pmdirect_top_precip_binding_diagnostics_t) :: binding_diagnostics
  type(fmr_serialized_test_result_t) :: hydraulic_result
  real(real64) :: amount, accepted_amount, accepted_t, accepted_total, gross_total, net_total
  real(real64) :: before_time, before_amount, daily_interception
  real(real64) :: endpoint, actual_endpoint, dt, net_rate
  logical :: complete
  integer :: status, i

  call set_site(site)
  weather=pmdirect_swetr0_weather_t(161,1.2450e7_real64,11.0_real64,18.1_real64, &
       1.315514_real64,4.92_real64,0.47_real64)
  canopy=pmdirect_swetr0_canopy_t(.true.,3.12683333333333335_real64, &
       0.755141552325116483_real64,0.25_real64,0.23_real64,70.0_real64,0.0_real64,1.0_real64)
  call evaluate_pmdirect_swetr0_daily(weather,site,canopy,daily,process_diagnostics)
  call require(process_diagnostics%status==PMDIRECT_SWETR0_OK .and. process_diagnostics%daily_result_produced, &
       'admitted daily provider rejected')
  call apply_swinter1_daily_interval(weather,canopy,daily,interval,process_diagnostics)
  call require(process_diagnostics%interval_result_produced, 'admitted SWINTER=1 interval rejected')
  call close_to(interval%interception_rate_cm_per_day,6.40612570512150981e-2_real64,'source oracle interception rate')
  call close_to(interval%net_rain_cm_per_day,4.05938742948784959e-1_real64,'source oracle net rain')
  call close_to(interval%wet_canopy_fraction,3.96478332498613917e-1_real64,'source oracle wet fraction')
  call close_to(interval%potential_transpiration_cm_per_day,1.80673591545995882e-1_real64,'source oracle ptra')

  daily_interception=interval%interception_rate_cm_per_day
  call initialize_fmr_interception_source_window(COLUMN_ID,WINDOW_ID,0.0_real64,1.0_real64, &
       daily_interception,owner,status)
  call require(status==FMR_INTWIN_OK,'source-window initialization')
  call set_base_request(base_request)

  ! A trial can be discarded after hydraulic rejection without advancing the
  ! accepted aggregate. The same interval is then retried at a shorter end.
  call prepare_fmr_interception_source_window_trial(owner,0.25_real64,amount,status)
  call require(status==FMR_INTWIN_OK,'first trial preparation')
  call make_result(COLUMN_ID,0.0_real64,0.25_real64,.false.,0,0_int64,0_int64, &
       0.0_real64,.false.,hydraulic_result)
  call accept_result(owner,hydraulic_result,accepted_amount,status)
  call require(status==FMR_INTWIN_NO_ACCEPTED_COMMIT,'rejected hydraulic trial advanced progress')
  call fmr_interception_source_window_progress(owner,before_time,before_amount,complete,status)
  call require(status==FMR_INTWIN_OK .and. same_bits(before_time,0.0_real64) .and. &
       same_bits(before_amount,0.0_real64),'rejected trial changed accepted progress')

  accepted_total=0.0_real64
  gross_total=0.0_real64
  net_total=0.0_real64

  call prepare_fmr_interception_source_window_trial(owner,0.25_real64,amount,status)
  call require(status==FMR_INTWIN_OK,'retry preparation')
  call make_result(COLUMN_ID,0.0_real64,0.25_real64,.true.,1,0_int64,1_int64, &
       0.125_real64,.true.,hydraulic_result)
  call accept_result(owner,hydraulic_result,accepted_amount,status)
  call require(status==FMR_INTWIN_OK,'partial accepted FMR result')
  actual_endpoint=0.125_real64
  call bind_and_account(actual_endpoint,accepted_amount)
  call require(same_bits(accepted_amount, daily_interception*actual_endpoint), &
       'partial source-window amount disagrees with uniform daily SWRAIN=0 allocation')

  ! Finish the requested interval from the exact accepted checkpoint, then
  ! export progress with a restart timestamp matching the FMR commit.
  call prepare_fmr_interception_source_window_trial(owner,0.25_real64,amount,status)
  call require(status==FMR_INTWIN_OK,'post-retry remainder preparation')
  call make_result(COLUMN_ID,0.125_real64,0.25_real64,.true.,1,1_int64,2_int64, &
       0.25_real64,.true.,hydraulic_result)
  call accept_result(owner,hydraulic_result,accepted_amount,status)
  call require(status==FMR_INTWIN_OK,'post-retry remainder acceptance')
  actual_endpoint=0.25_real64
  call bind_and_account(actual_endpoint,accepted_amount)

  call export_fmr_interception_source_window_restart(owner,0.25_real64,restart,status)
  call require(status==FMR_INTWIN_OK,'mid-window restart export')
  call restore_fmr_interception_source_window(restart,restored,status)
  call require(status==FMR_INTWIN_OK,'mid-window restart restore')
  call fmr_interception_source_window_progress(restored,accepted_t,before_amount,complete,status)
  call require(status==FMR_INTWIN_OK .and. same_bits(accepted_t,0.25_real64), &
       'restart did not retain accepted endpoint')

  owner=restored
  do i=1,3
    endpoint=0.25_real64+0.25_real64*real(i,real64)
    call fmr_interception_source_window_progress(owner,before_time,before_amount,complete,status)
    call require(status==FMR_INTWIN_OK,'progress read before accepted interval')
    call prepare_fmr_interception_source_window_trial(owner,endpoint,amount,status)
    call require(status==FMR_INTWIN_OK,'full interval preparation')
    call make_result(COLUMN_ID,before_time,endpoint,.true.,1,int(before_time*1000.0_real64,int64), &
         int(endpoint*1000.0_real64,int64),endpoint,.true.,hydraulic_result)
    call accept_result(owner,hydraulic_result,accepted_amount,status)
    call require(status==FMR_INTWIN_OK,'accepted FMR result')
    actual_endpoint=endpoint
    call bind_and_account(actual_endpoint,accepted_amount)
  end do

  call fmr_interception_source_window_progress(owner,accepted_t,before_amount,complete,status)
  call require(status==FMR_INTWIN_OK .and. complete .and. same_bits(accepted_t,1.0_real64), &
       'source window did not close')
  call close_to(accepted_total,daily_interception,'accepted aggregate closure')
  call close_to(gross_total,0.47_real64,'gross precipitation closure')
  call close_to(net_total,interval%net_rain_cm_per_day,'net precipitation closure')
  call close_to(gross_total,accepted_total+net_total,'gross/interception/net identity')

  restart%committed_time=0.9_real64
  call restore_fmr_interception_source_window(restart,restored,status)
  call require(status==FMR_INTWIN_RESTART_MISMATCH,'restart timestamp mismatch accepted')

  print '(a)','F-MIG431-INT12-C RESTRICTED HUPSEL COMPOSITION PASS'
  print '(a,es24.16)','interception=',accepted_total
  print '(a,es24.16)','net_rain=',net_total

contains

  subroutine accept_result(value,result,accepted,status_value)
    type(fmr_interception_source_window_t),intent(inout)::value
    type(fmr_serialized_test_result_t),intent(in)::result
    real(real64),intent(out)::accepted
    integer,intent(out)::status_value
    call accept_fmr_interception_source_window_result(value,result%column_id,result%requested_t0, &
         result%requested_t1,result%committed,result%accepted_substeps,result%initial_revision, &
         result%final_revision,result%final_committed_time,result%final_committed_time_bound,accepted,status_value)
  end subroutine accept_result

  subroutine bind_and_account(endpoint_value,intercepted_depth)
    real(real64),intent(in)::endpoint_value,intercepted_depth
    dt=endpoint_value-before_time
    call require(dt>0.0_real64,'nonpositive accepted duration')
    call close_to(intercepted_depth,daily_interception*dt,'time-apportioned interception')
    net_rate=(0.47_real64*dt-intercepted_depth)/dt
    bound_interval=interval
    bound_interval%net_rain_cm_per_day=net_rate
    process_diagnostics%status=PMDIRECT_SWETR0_OK
    process_diagnostics%interval_result_produced=.true.
    call fmr_bind_pmdirect_net_rain_to_dynamic_top_request(base_request,bound_interval, &
         process_diagnostics,bound_request,binding_diagnostics)
    call require(binding_diagnostics%status==FMR_PMDIRECT_TOP_PRECIP_BINDING_OK .and. &
         binding_diagnostics%result_produced,'accepted net rain failed dynamic-top binding')
    call require(same_bits(bound_request%precipitation_rate_cm_per_day,net_rate), &
         'net-rain dynamic-top binding changed value')
    gross_total=gross_total+0.47_real64*dt
    accepted_total=accepted_total+intercepted_depth
    net_total=net_total+bound_request%precipitation_rate_cm_per_day*dt
    before_time=endpoint_value
  end subroutine bind_and_account

  subroutine set_site(value)
    type(pmdirect_swetr0_site_t),intent(out)::value
    value%latitude_degrees=52.0_real64
    value%altitude_m=10.0_real64
    value%wind_measurement_height_m=10.0_real64
    value%humidity_measurement_height_m=1.5_real64
    value%angstrom_a=0.25_real64
    value%angstrom_b=0.5_real64
    value%wind_function_factor=1.0_real64
    value%soil_surface_resistance_s_m=600.0_real64
  end subroutine set_site

  subroutine set_base_request(value)
    type(b110_dynamic_top_boundary_request_t),intent(out)::value
    value=b110_dynamic_top_boundary_request_t()
    value%conductivity_mean_method=1
    value%pressure_head_top_cm=-80.0_real64
    value%water_content_top=0.25_real64
    value%step_duration_day=0.25_real64
    value%ponding_max_cm=2.0_real64
    value%runoff_resistance_day=1.0_real64
    value%runoff_exponent=1.0_real64
  end subroutine set_base_request

  subroutine make_result(column,t0,t1,did_commit,substeps,revision0,revision1,final_time,final_bound,value)
    integer(int64),intent(in)::column,revision0,revision1
    real(real64),intent(in)::t0,t1,final_time
    logical,intent(in)::did_commit,final_bound
    integer,intent(in)::substeps
    type(fmr_serialized_test_result_t),intent(out)::value
    value=fmr_serialized_test_result_t()
    value%column_id=column
    value%requested_t0=t0
    value%requested_t1=t1
    value%committed=did_commit
    value%accepted_substeps=substeps
    value%initial_revision=revision0
    value%final_revision=revision1
    value%final_committed_time=final_time
    value%final_committed_time_bound=final_bound
  end subroutine make_result

  subroutine close_to(a,b,label)
    real(real64),intent(in)::a,b
    character(*),intent(in)::label
    if(abs(a-b)>TOL) then
      write(*,'(a,2(1x,es25.17e3) )') trim(label)//' mismatch:',a,b
      error stop 1
    end if
  end subroutine close_to

  pure logical function same_bits(a,b)
    real(real64),intent(in)::a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok) then
      write(*,'(a)') trim(label)
      error stop 1
    end if
  end subroutine require

end program test_f_mig431_int12_c
