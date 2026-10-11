program test_crop_file_weather_production
  use iso_fortran_env, only: real64,int64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE,FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t,fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t,fmr_application_crop_daystart_controls_t,FMR_APP_BOOT_OK, &
       FMR_APP_BOOT_WEATHER_REJECTED,FMR_APP_BOOT_CROP_PREFLIGHT_FAILED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_swap_daily_weather_file_adapter, only: swap_daily_weather_record_t,read_swap_daily_weather_file, &
       swap_weather_calendar_day,SWAP_WEATHER_FILE_OK
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_crop_certified_daily_preflight, only: crop_certified_daily_preflight_t
  use mod_fmr_crop_certified_germination_moisture, only: sample_certified_committed_germination_head,CROP_CERT_GERM_OK
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t
  use mod_reference_et_demand_process, only: reference_et_demand_canopy_view_t
  use mod_kernel_transactions, only: kernel_executor_t,kernel_result_t
  use mod_kernel_committed_persistence, only: kernel_persistence_snapshot_t, &
       export_kernel_committed_state,restore_kernel_committed_state,KERNEL_PERSISTENCE_OK, &
       KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t, &
       fmr_wofost_crop_transaction_model_t, fmr_wofost_crop_transaction_parameters_t, &
       initialize_fmr_wofost_crop_transaction_state, construct_fmr_wofost_crop_transaction_parameters, FMR_WOF38_OK
  use mod_crop_lifecycle_continuation, only: crop_lifecycle_continuation_t
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_wofost_crop_owner_state, only: WOFOST_CROP_OWNER_OK,wofost_crop_owner_state_t
  use mod_wofost_rate_parameters
  use mod_wofost_rate_table
  use mod_wofost_one_day_structural_evolution, only: wofost_one_day_update_parameters_t
  use mod_fmr_production_application_bootstrap, only: FMR_APP_BOOT_CROP_WINDOW_UNAVAILABLE, &
       FMR_APP_BOOT_CROP_EVENT_DELIVERED,FMR_APP_BOOT_CROP_TRANSACTION_FAILED,FMR_APP_BOOT_INVALID_CONFIG,FMR_APP_BOOT_PROFILE_NOT_ADMITTED, &
       fmr_weather_crop_application_continuation_t
  implicit none
  interface
    function b111_daily_tav(tmin,tmax) result(tav)
      import real64
      real(real64),intent(in)::tmin,tmax
      real(real64)::tav
    end function
    subroutine b111_germination_oracle(mode,temperature_sum,optimal_sum,base_temperature, &
         maximum_temperature,air_temperature,head,dry_head,wet_head,response,complete)
      import real64
      integer,intent(in)::mode
      real(real64),intent(inout)::temperature_sum
      real(real64),intent(in)::optimal_sum,base_temperature,maximum_temperature,air_temperature, &
           head,dry_head,wet_head,response
      logical,intent(out)::complete
    end subroutine
    subroutine b111_initial_owner_oracle(tdwi,fr,fl,fs,fo,sla,ssa,spa,result)
      import real64
      real(real64),intent(in)::tdwi,fr,fl,fs,fo,sla,ssa,spa
      real(real64),intent(out)::result(10)
    end subroutine
  end interface
  real(real64),parameter::T0=0.0_real64,T1=T0+1.0_real64,H0_CM=-75.0_real64,HARD_MASS_GATE=1.0e-12_real64
  type(fmr_production_application_config_t)::config,reject_config
  type(fmr_production_application_bootstrap_t)::app,reject_app
  type(fmr_application_crop_daystart_controls_t)::controls,bad_controls
  type(swap_daily_weather_record_t)::record,old_record,altered,empty
  type(kernel_committed_state_t)::soil
  type(crop_certified_daily_preflight_t)::candidate,repeated
  type(ppa_wu03_common_forcing_config_t)::forcing_config
  type(reference_et_demand_canopy_view_t)::canopy
  type(fmr_serialized_column_result_t),allocatable::results(:)
  integer(int64),allocatable::revisions(:)
  character(1024)::path,altered_path,bad_path,backup_path
  real(real64)::k,day,tmin,tmax,rain,etref,hgerm,before_time,previous_storage,initial_head
  integer::s,d,i
  type(kernel_executor_t)::crop_kernel
  type(fmr_wofost_crop_transaction_model_t),target::crop_model
  type(fmr_wofost_crop_transaction_parameters_t)::crop_parameters,bad_crop_parameters
  type(kernel_committed_state_t)::crop_committed,restored_crop
  type(kernel_persistence_snapshot_t)::crop_restart
  type(fmr_weather_crop_application_continuation_t)::application_restart,empty_restart
  type(fmr_production_application_bootstrap_t)::restored_app
  type(kernel_committed_state_t)::joint_crop,foreign_crop
  class(transaction_state_t),allocatable::foreign_physical
  character(32)::continuation_mode,moisture_mode
  type(canonical_numerical_config_t)::crop_config
  type(kernel_result_t)::crop_result
  type(crop_lifecycle_continuation_t)::lifecycle
  type(wofost_crop_owner_state_t)::initial_owner
  real(real64)::accepted_germination_sum,expected_germination_sum
  real(real64)::historical_sum
  logical::historical_complete
  logical::available
  call get_command_argument(1,path);call get_command_argument(2,altered_path);call get_command_argument(3,bad_path)
  call get_command_argument(4,backup_path)
  call get_command_argument(5,continuation_mode)
  call require(trim(continuation_mode)=='continuous'.or.trim(continuation_mode)=='restart','explicit replay mode')
  call get_command_argument(6,moisture_mode)
  call require(trim(moisture_mode)=='neutral'.or.trim(moisture_mode)=='dry'.or. &
       trim(moisture_mode)=='hydraulic','explicit hydraulic qualification mode')
  call restored_app%restore_weather_crop_continuation(empty_restart,joint_crop,s)
  call require(s==FMR_APP_BOOT_INVALID_CONFIG.and..not.restored_app%ready().and..not.joint_crop%ready(), &
       'empty joint continuation cannot initialize owners')
  call require(swap_weather_calendar_day(1999,1,20)==729774,'explicit Gregorian epoch')
  call require(swap_weather_calendar_day(2000,2,29)>0.and.swap_weather_calendar_day(1900,2,29)==0,'leap calendar')
  call read_swap_daily_weather_file(trim(bad_path),1999,1,20,record,s)
  call require(s/=SWAP_WEATHER_FILE_OK.and..not.record%ready(),'malformed daily record rejected')
  call initialize_application_config(config,k)
  ! Explicit 30 cm, four-compartment homogeneous test soil. The legacy
  ! four-node linkage stubs are not the authority for production geometry.
  ! Weather bytes are Andelst; no Andelst soil/reference trajectory claim.
  config%file_weather_daystart=.true.
  config%file_weather_epoch_day=swap_weather_calendar_day(1999,1,20)
  ! Use the admitted nonsteady Richards history certificate (ROOT-HYD01),
  ! not the base full/half bit-identity comparator used by steady WU03.
  config%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  allocate(config%tiles(1)%initial_right_derivative(numnod))
  config%tiles(1)%initial_right_derivative=0.0_real64
  config%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  config%numerical%transaction%temporal_tolerance=0.0_real64
  config%numerical%model_temporal_indicator_budget_available=.true.
  config%numerical%model_temporal_indicator_budget=1.0e-5_real64
  config%numerical%transaction%max_retries=32
  ! Use admitted BOFEK00 wet-trajectory head convergence policy;
  ! residual-rate tolerance is 1e-10 as in that gate; independently
  ! require the full physical transaction mass residual <= 1e-12 cm.
  config%tiles(1)%parameters%head_abs_tolerance=1.0e-9_real64
  config%tiles(1)%parameters%head_rel_tolerance=1.0e-9_real64
  config%tiles(1)%parameters%ponding_tolerance=HARD_MASS_GATE
  config%tiles(1)%parameters%max_iterations=20
  config%tiles(1)%parameters%max_backtracking=8
  config%tiles(1)%parameters%min_step_duration=1.0e-10_real64
  config%tiles(1)%parameters%compartment_balance_tolerance=1.0e-10_real64
  config%tiles(1)%parameters%total_balance_tolerance=1.0e-10_real64
  ! Real atmospheric forcing is nonsteady. The accepted production mass
  ! threshold remains unchanged; no forcing is reverse-engineered to steady.
  config%numerical%max_committed_substeps=262144
  call test_immediate_startup()
  call app%initialize(config,s);call require(s==FMR_APP_BOOT_OK,'production bootstrap')
  call app%run_standalone(T0,T1,results,s)
  call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(results),'enabled file-weather path rejects unbound hydrology bypass')
  call initialize_crop(crop_committed,crop_parameters,crop_config)
  call crop_kernel%bind_model(crop_model)
  accepted_germination_sum=0.0_real64
  controls%germ_mode=2;controls%optimal_sum=9.5_real64
  if(trim(moisture_mode)=='dry') then
    controls%dry_head=-50.0_real64
    controls%water_response_a=1.0_real64
  end if
  if(trim(moisture_mode)=='hydraulic') then
    controls%swprep=1;controls%hprep_threshold=-85.0_real64
  end if
  controls%zprep=-1.0_real64;controls%zsow=-1.0_real64
  controls%ztempsow=-1.0_real64;controls%zgerm=-1.0_real64
  call app%begin_weather_day(empty,controls,candidate,s)
  call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.candidate%valid,'unconstructed file record rejected')
  initial_head=H0_CM;previous_storage=0.0_real64
  do d=20,23
    call read_swap_daily_weather_file(trim(path),1999,1,d,record,s)
    call require(s==SWAP_WEATHER_FILE_OK.and.record%ready(),'actual historical daily weather file read')
    call record%values(day,tmin,tmax,rain,etref,available)
    day=day-real(config%file_weather_epoch_day,real64)
    call require(available.and.day==T0+real(d-20,real64),'calendar record time binding')
    if(d==20) call require(tmin==3.2_real64.and.tmax==7.7_real64.and.rain==0.0_real64.and. &
         etref==0.2355_real64,'authentic Andelst first day input')
    call app%copy_committed_for_crop(1,soil,s)
    call require(s==FMR_APP_BOOT_OK,'read-only actual committed carrier')
    call soil%current_time(before_time,available)
    call require(available.and.before_time==day,'previous accepted soil at current daystart')
    call sample_certified_committed_germination_head(soil,soil%current_lineage_id(), &
         soil%current_revision(),day,controls%zgerm,hgerm,s)
    call require(s==CROP_CERT_GERM_OK,'certified real production daystart head')
    if(d==20) then
      bad_controls=controls;bad_controls%swsow=1
      call app%begin_weather_day(record,bad_controls,candidate,s)
      call require(s==FMR_APP_BOOT_CROP_PREFLIGHT_FAILED.and..not.candidate%valid,'heat-off simulated sowing fails closed')
    end if
    call app%begin_weather_day(record,controls,candidate,s)
    call require(s==FMR_APP_BOOT_OK.and.candidate%valid,'production meteorology before future hydrology acceptance')
    call require(candidate%hgerm==hgerm,'crop reads actual same-owner accepted soil')
    if(trim(moisture_mode)/='dry'.or.tmax+tmin<=0.0_real64) then
      call require(candidate%germination%next_temperature_sum==max(0.0_real64,b111_daily_tav(tmin,tmax)), &
           'historical source-derived daily TAV with cold-day germination stop')
    else
      call require(hgerm<controls%dry_head.and.candidate%germination%next_temperature_sum>0.0_real64.and. &
           candidate%germination%next_temperature_sum<max(0.0_real64,b111_daily_tav(tmin,tmax)), &
           'actual accepted FKT soil head reduces germination under identical authentic temperature')
    end if
    call app%begin_weather_day(record,controls,repeated,s)
    call require(s==FMR_APP_BOOT_OK.and.repeated%germination%next_temperature_sum== &
         candidate%germination%next_temperature_sum,'retry daystart does not double-add')
    ! Existing owner creation consumes day-zero weather/accepted initial
    ! soil before future hydrology; it invents no positive hydro receipt.
    if(d==20) then
      call app%initialize_weather_crop_daystart(record,controls,initial_owner,0_int64,931_int64,crop_committed,s)
      call require(s==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.crop_committed%ready(), &
           'invalid first-day crop identity cannot publish owner')
      bad_controls=controls;bad_controls%temperature_sum=999.0_real64
      bad_controls%prep_delay=99;bad_controls%sow_delay=99
      call app%initialize_weather_crop_daystart(record,bad_controls,initial_owner,1_int64,931_int64,crop_committed,s)
      call require(s==FMR_APP_BOOT_OK.and.crop_committed%current_revision()==0_int64, &
           'first-day crop initialized through existing authority without invented event')
      call read_lifecycle(crop_committed,lifecycle)
      if(trim(moisture_mode)=='hydraulic') then
        accepted_germination_sum=0.0_real64
        call require(hgerm>controls%hprep_threshold.and..not.lifecycle%prepared.and..not.lifecycle%sown.and. &
             .not.lifecycle%germinated.and.lifecycle%preparation_delay==1.and.lifecycle%sowing_delay==0.and. &
             lifecycle%germination_temperature_sum==0.0_real64,'actual initial wet soil blocks preparation and germination publication')
      else
        accepted_germination_sum=candidate%germination%next_temperature_sum
        call require(lifecycle%prepared.and.lifecycle%sown.and..not.lifecycle%germinated.and. &
             lifecycle%germination_temperature_sum==accepted_germination_sum.and. &
             lifecycle%preparation_delay==0.and.lifecycle%sowing_delay==0, &
             'authentic initial lifecycle owns zero-based continuation')
      end if
      historical_sum=0.0_real64;historical_complete=.false.
      if(lifecycle%prepared.and.lifecycle%sown) call historical_germination(historical_sum,historical_complete)
      call require(transfer(lifecycle%germination_temperature_sum,0_int64)==transfer(historical_sum,0_int64).and. &
           (lifecycle%germinated.eqv.historical_complete),'initial physical germination equals literal B111 source')
      call require(.not.lifecycle%last_event_identity%ready(),'initial lifecycle has no invented positive event')
      call app%initialize_weather_crop_daystart(record,controls,initial_owner,1_int64,931_int64,crop_committed,s)
      call require(s==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and.crop_committed%current_revision()==0_int64, &
           'repeat first-day creation cannot replace accepted crop')
      call app%capture_weather_crop_continuation(crop_committed,application_restart,s)
      call require(s==FMR_APP_BOOT_OK,'initial joint continuation without fabricated event receipt')
      if(trim(continuation_mode)=='restart') then
        call app%close(s);call require(s==FMR_APP_BOOT_OK,'close first-day application before restore')
        crop_committed=kernel_committed_state_t()
        call app%restore_weather_crop_continuation(application_restart,crop_committed,s)
        call require(s==FMR_APP_BOOT_OK,'restore first-day authenticated owner creation')
        call app%initialize_weather_crop_daystart(record,controls,initial_owner,1_int64,931_int64,crop_committed,s)
        call require(s==FMR_APP_BOOT_CROP_TRANSACTION_FAILED,'restored initial owner rejects repeat creation')
      end if
    else
      bad_controls=controls
      bad_controls%temperature_sum=accepted_germination_sum
      if(lifecycle%germinated) bad_controls%germ_mode=0
      call app%begin_weather_day(record,bad_controls,repeated,s)
      call require(s==FMR_APP_BOOT_OK.and.repeated%hgerm==hgerm,'actual physical source for live hydraulic crop proposal')
      expected_germination_sum=repeated%germination%next_temperature_sum
      if(lifecycle%germinated) then
        call require(expected_germination_sum==accepted_germination_sum,'completed germination retained without further accumulation')
      else if(trim(moisture_mode)/='dry') then
        call require(expected_germination_sum==accepted_germination_sum+max(0.0_real64,b111_daily_tav(tmin,tmax)), &
             'neutral accepted physical crop retains exact historical TAV oracle')
      else if(tmax+tmin>0.0_real64) then
        call require(expected_germination_sum>accepted_germination_sum.and. &
             expected_germination_sum<accepted_germination_sum+max(0.0_real64,b111_daily_tav(tmin,tmax)), &
             'hydraulic reduction affects actual forthcoming physical crop commit')
      else
        call require(expected_germination_sum==accepted_germination_sum,'cold hydraulic case retains accepted germination sum')
      end if
      historical_sum=accepted_germination_sum;historical_complete=lifecycle%germinated
      if(.not.historical_complete) call historical_germination(historical_sum,historical_complete)
      call require(transfer(expected_germination_sum,0_int64)==transfer(historical_sum,0_int64), &
           'accepted soil and authentic weather equal literal B111 germination arithmetic')
      if(d==21) then
        call app%capture_weather_crop_continuation(crop_committed,application_restart,s)
        call require(s==FMR_APP_BOOT_OK,'pending initial crop successor window captured before trial')
        if(trim(continuation_mode)=='restart') then
          call app%close(s);call require(s==FMR_APP_BOOT_OK,'close pending crop application before restore')
          crop_committed=kernel_committed_state_t()
          call app%restore_weather_crop_continuation(application_restart,crop_committed,s)
          call require(s==FMR_APP_BOOT_OK,'restore actual undelivered previous-day window before retry')
        end if
      end if
      bad_controls=controls
      ! These deliberately wrong caller values must be ignored for live
      ! continuation: the existing committed crop state is authoritative.
      bad_controls%temperature_sum=999.0_real64
      bad_controls%prep_delay=99;bad_controls%sow_delay=99
      call app%run_weather_crop_daystart(record,bad_controls,crop_kernel,bad_crop_parameters, &
           crop_config,crop_committed,crop_result,s)
      call require(s==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and.crop_committed%current_revision()==int(d-21,int64), &
           'failed crop trial leaves accepted state and event delivery unchanged')
      call app%run_weather_interval(record,day,day+1.0_real64/64.0_real64,forcing_config,canopy,results,s)
      call require(s==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.allocated(results), &
           'pending crop daystart cannot be bypassed by current-day hydrology')
      call app%run_weather_crop_daystart(record,bad_controls,crop_kernel,crop_parameters, &
           crop_config,crop_committed,crop_result,s)
      call require(s==FMR_APP_BOOT_OK.and.crop_result%completed,'live physical crop event committed')
      call read_lifecycle(crop_committed,lifecycle)
      call require(transfer(lifecycle%germination_temperature_sum,0_int64)==transfer(historical_sum,0_int64).and. &
           (lifecycle%germinated.eqv.historical_complete),'physical crop commit equals literal B111 germination source')
      accepted_germination_sum=expected_germination_sum
      call require(lifecycle%revision==int(d-20,int64).and.lifecycle%prepared.and.lifecycle%sown.and. &
           lifecycle%germination_temperature_sum==accepted_germination_sum.and. &
           lifecycle%preparation_delay==lifecycle%sowing_delay,'existing crop continuation owns actual values')
      if(trim(moisture_mode)=='hydraulic') then
        call require(lifecycle%preparation_delay==1,'one actual blocked preparation day retained by crop owner')
        call require(lifecycle%germinated.eqv.(d>=22),'germination only after actual hydraulic preparation and sowing')
        if(d==21) call require(hgerm<=controls%hprep_threshold,'accepted previous-day soil enables actual preparation')
        if(d==22) call require(hgerm>controls%hprep_threshold.and.lifecycle%prepared, &
             'completed preparation persists when later soil would block a new preparation')
      else
        call require(lifecycle%preparation_delay==0,'scheduled crop retains zero preparation delay')
        call require(lifecycle%germinated.eqv.(d>=21),'physical germination threshold reached and retained')
      end if
      call app%run_weather_crop_daystart(record,bad_controls,crop_kernel,crop_parameters, &
           crop_config,crop_committed,crop_result,s)
      call require(s==FMR_APP_BOOT_CROP_EVENT_DELIVERED.and.crop_committed%current_revision()==int(d-20,int64), &
           'accepted crop event published exactly once')
    end if
    if(d==20) then
      if(trim(moisture_mode)/='dry') call require( &
           candidate%germination%next_temperature_sum==(7.7_real64+3.2_real64)*0.5_real64, &
           'literal historical temperature sum from actual first source day')
      ! Same pathname, changed bytes: a pathname-only provenance check would
      ! miss this. Restore the authentic input before any positive run.
      call copy_input_file(trim(altered_path),trim(path))
      call read_swap_daily_weather_file(trim(path),1999,1,d,altered,s)
      call copy_input_file(trim(backup_path),trim(path))
      call require(s==SWAP_WEATHER_FILE_OK,'altered input parse remains valid')
      call app%begin_weather_day(altered,controls,repeated,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'same TAV different Tmin Tmax input conflict')
      call app%run_weather_interval(altered,day,day+0.5_real64,forcing_config,canopy,results,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(results),'alternate file cannot drive hydrology')
      reject_config=config
      reject_config%numerical%transaction%max_retries=0
      reject_config%numerical%max_committed_substeps=1
      reject_config%numerical%model_temporal_indicator_budget=0.0_real64
      call reject_app%initialize(reject_config,s)
      call require(s==FMR_APP_BOOT_OK,'deliberately rejecting production policy owner')
      call reject_app%begin_weather_day(record,controls,repeated,s)
      call require(s==FMR_APP_BOOT_OK,'rejected-day meteorology acquired independently')
      do i=1,2
        call reject_app%run_weather_interval(record,day,day+0.5_real64,forcing_config,canopy,results,s)
        call require(s/=FMR_APP_BOOT_OK.and.allocated(results),'real physical rejection and repeated attempt')
        call require(.not.results(1)%committed.and.results(1)%final_revision==0_int64, &
             'rejected physical attempt never commits accepted state')
        call reject_app%copy_committed_for_crop(1,soil,s)
        call soil%current_time(before_time,available)
        call require(s==FMR_APP_BOOT_OK.and.available.and.before_time==day.and. &
             soil%current_revision()==0_int64,'rejected attempt leaves time/revision intact')
        call sample_certified_committed_germination_head(soil,soil%current_lineage_id(), &
             soil%current_revision(),day,controls%zgerm,hgerm,s)
        call require(s==CROP_CERT_GERM_OK.and.hgerm==candidate%hgerm,'physical rejection leaves accepted soil intact')
      end do
      call reject_app%close(s)
      call require(s==FMR_APP_BOOT_OK,'rejected owner close')
    end if
    do i=0,63
      call app%run_weather_interval(record,day+real(i,real64)/64.0_real64, &
           day+real(i+1,real64)/64.0_real64,forcing_config,canopy,results,s)
      if(s/=FMR_APP_BOOT_OK) then
        print *, 'RUN_STATUS',s,d,i
        if(allocated(results)) then
          print *, 'RUNTIME_COMPLETED',results(1)%completed,results(1)%committed
          print *, 'RUNTIME_COMMIT',results(1)%commit_status,results(1)%accepted_substeps
          print *, 'RUNTIME_DIAGNOSTICS',results(1)%kernel_status,results(1)%admission_status, &
               results(1)%solver_status,results(1)%solver_rejections,results(1)%temporal_rejections, &
               results(1)%mass_rejections,results(1)%mass%residual
        end if
      end if
      call require(s==FMR_APP_BOOT_OK,'file-derived hydrological production interval')
      call require(size(results)==1.and.results(1)%completed.and.results(1)%committed,'actual FKT accept')
      if(abs(results(1)%mass%residual)>HARD_MASS_GATE) print *, 'MASS_FAILURE',d,i,results(1)%mass%residual
      call require(abs(results(1)%mass%residual)<=HARD_MASS_GATE,'unchanged hard water mass gate')
      if(d/=20.or.i/=0) call require(abs(results(1)%mass%storage_start-previous_storage)<=HARD_MASS_GATE, &
           'continuous hydrological accepted storage')
      previous_storage=results(1)%mass%storage_end
      call app%copy_committed_revisions(revisions,s)
      call require(s==FMR_APP_BOOT_OK.and.revisions(1)>=int((d-20)*64+i+1,int64),'actual accepted revisions')
    end do
    call app%run_weather_interval(record,day,day+0.5_real64,forcing_config,canopy,results,s)
    call require(s==FMR_APP_BOOT_WEATHER_REJECTED.and..not.allocated(results),'accepted interval duplicate rejected')
    call app%begin_weather_day(record,controls,repeated,s)
    call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'daystart cannot be applied after same-day hydrology')
    if(d>20) then
      call app%run_weather_interval(old_record,day+1.0_real64,day+1.5_real64,forcing_config,canopy,results,s)
      call require(s==FMR_APP_BOOT_WEATHER_REJECTED,'old meteorology rejected after accepted midnight')
    end if
    if(d==22) then
      ! Existing opaque F-KT persistence creates a new crop carrier with all
      ! committed owner fields and the physical event history. The weather
      ! and hydro application is deliberately not claimed as disk-restarted.
      call export_kernel_committed_state(crop_committed,904001_int64,crop_restart,available,s)
      call require(available.and.s==KERNEL_PERSISTENCE_OK,'actual accepted crop persistence export')
      call restore_kernel_committed_state(crop_restart,904001_int64,crop_committed,available,s)
      call require(.not.available.and.s==KERNEL_PERSISTENCE_TARGET_ALREADY_INITIALIZED, &
           'restart cannot overwrite live authoritative crop state')
      call restore_kernel_committed_state(crop_restart,904001_int64,restored_crop,available,s)
      call require(available.and.s==KERNEL_PERSISTENCE_OK,'actual accepted crop continuation restore')
      call read_lifecycle(restored_crop,lifecycle)
      call require(lifecycle%germinated.and.lifecycle%revision==2_int64.and. &
           lifecycle%germination_temperature_sum==accepted_germination_sum,'crop restart retains physical lifecycle')
      crop_committed=restored_crop
      call crop_committed%snapshot(foreign_physical,available)
      call require(available,'foreign paired-source negative crop snapshot')
      call foreign_crop%initialize(999_int64,foreign_physical,available,day)
      call require(available,'foreign same-time crop owner constructed by existing FKT')
      call app%capture_weather_crop_continuation(foreign_crop,empty_restart,s)
      call require(s==FMR_APP_BOOT_PROFILE_NOT_ADMITTED,'foreign crop lineage cannot join accepted hydro history')
      call app%capture_weather_crop_continuation(crop_committed,application_restart,s)
      call require(s==FMR_APP_BOOT_OK,'joint actual accepted source/weather/hydro/crop/window capture')
      call app%restore_weather_crop_continuation(application_restart,joint_crop,s)
      call require(s==FMR_APP_BOOT_INVALID_CONFIG.and..not.joint_crop%ready().and.app%ready(), &
           'joint restore never overwrites a live application')
      call restored_app%restore_weather_crop_continuation(application_restart,joint_crop,s)
      call require(s==FMR_APP_BOOT_OK.and.restored_app%ready(),'joint fresh application restore')
      call restored_app%copy_committed_for_crop(1,soil,s)
      call soil%current_time(before_time,available)
      call require(s==FMR_APP_BOOT_OK.and.available.and.before_time==day+1.0_real64.and. &
           soil%current_revision()==192_int64,'restored actual hydrology time/revision')
      call read_lifecycle(joint_crop,lifecycle)
      call require(lifecycle%germinated.and.lifecycle%germination_temperature_sum==accepted_germination_sum, &
           'joint restored crop germination state')
      call restored_app%close(s)
      call require(s==FMR_APP_BOOT_OK,'temporary restored owner disposed without overwriting reference')
      if(trim(continuation_mode)=='restart') then
        call app%close(s)
        call require(s==FMR_APP_BOOT_OK,'real production application disposed for continuation')
        crop_committed=kernel_committed_state_t()
        crop_kernel=kernel_executor_t()
        crop_model=fmr_wofost_crop_transaction_model_t()
        call crop_kernel%bind_model(crop_model)
        call app%restore_weather_crop_continuation(application_restart,crop_committed,s)
        call require(s==FMR_APP_BOOT_OK,'real production and crop owners recreated from joint continuation')
      end if
    end if
    old_record=record
    write(*,'(a,i2,a,f10.5,a,f12.7)') 'CROP_FILE_WEATHER_DAY=',d,' TAV=',(tmax+tmin)*0.5_real64, &
         ' HEAD=',hgerm
  end do
  call app%copy_committed_for_crop(1,soil,s)
  call sample_certified_committed_germination_head(soil,soil%current_lineage_id(), &
       soil%current_revision(),T0+4.0_real64,controls%zgerm,hgerm,s)
  call require(s==CROP_CERT_GERM_OK.and.abs(hgerm-initial_head)>1.0e-6_real64,'physical soil trajectory actually changes')
  call print_exact_postimage(soil,crop_committed,previous_storage)
  call app%close(s);call require(s==FMR_APP_BOOT_OK,'production owner close')
  print '(a)', 'CROP_FILE_WEATHER_AUTHENTIC_SHARED_RECORD=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PRIOR_ACCEPTED_DAYSTART=PASS'
  print '(a)', 'CROP_FILE_WEATHER_FOUR_DAY_PHYSICAL_MASS_CONTINUITY=PASS'
  print '(a)', 'CROP_FILE_WEATHER_RETRY_CONFLICT_DUPLICATE=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PHYSICAL_REJECT_ROLLBACK=PASS'
  print '(a)', 'CROP_FILE_WEATHER_LIVE_FKT_WINDOW=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PHYSICAL_CROP_CONTINUATION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PHYSICAL_GERMINATION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_CROP_CONTINUATION_RESTORE=PASS'
  print '(a)', 'CROP_FILE_WEATHER_JOINT_OPAQUE_CONTINUATION=PASS'
  if(trim(moisture_mode)=='dry') print '(a)', 'CROP_FILE_WEATHER_ACCEPTED_SOIL_PHYSICAL_GERMINATION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_CROP_REJECT_RETRY_EXACTLY_ONCE=PASS'
  print '(a)', 'CROP_FILE_WEATHER_INITIAL_DAY_OWNER_CREATION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PENDING_DAYSTART_RESTORE=PASS'
  print '(a)', 'CROP_FILE_WEATHER_COMPLETED_PHASE_RETENTION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_LITERAL_B111_GERMINATION=PASS'
  if(trim(moisture_mode)=='hydraulic') print '(a)', 'CROP_FILE_WEATHER_HYDRAULIC_PREPARATION_PHASE_TRANSITION=PASS'
  print '(a)', 'CROP_FILE_WEATHER_PRODUCTION=PASS'
contains
  subroutine test_immediate_startup()
    type(fmr_production_application_bootstrap_t)::initial_app
    type(kernel_committed_state_t)::initial_crop,initial_soil
    type(fmr_weather_crop_application_continuation_t)::saved
    type(fmr_application_crop_daystart_controls_t)::c,bad
    type(swap_daily_weather_record_t)::r
    type(wofost_rate_parameter_bundle_t)::bundle,invalid_bundle
    type(wofost_rate_table_t)::depth,density
    type(wofost_crop_owner_state_t)::empty_owner,actual
    type(crop_lifecycle_continuation_t)::life
    type(crop_root_uptake_input_t)::root_input
    class(transaction_state_t),allocatable::snapshot
    real(real64)::expected(10),values(10),lai
    integer::st,j
    logical::ok
    call make_bundle(bundle)
    call b111_initial_owner_oracle(100.0_real64,0.2_real64,0.4_real64,0.4_real64,0.2_real64, &
         0.02_real64,0.025_real64,0.01_real64,expected)
    c%swprep=0;c%swsow=0;c%germ_mode=0;c%zgerm=-1.0_real64
    call read_swap_daily_weather_file(trim(path),1999,1,20,r,st)
    call require(st==SWAP_WEATHER_FILE_OK,'immediate startup authentic source')
    call initial_app%initialize(config,st);call require(st==FMR_APP_BOOT_OK,'immediate initial physical soil')
    call initial_app%initialize_weather_crop_daystart(r,c,empty_owner,2_int64,932_int64,initial_crop,st, &
         initial_dry_weight=100.0_real64)
    call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.initial_crop%ready(),'partial seed rejected atomically')
    call initial_app%initialize_weather_crop_daystart(r,c,empty_owner,2_int64,932_int64,initial_crop,st, &
         -1.0_real64,bundle)
    call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.initial_crop%ready(),'negative initial biomass rejected')
    bad=c;bad%swprep=1
    call initial_app%initialize_weather_crop_daystart(r,bad,empty_owner,2_int64,932_int64,initial_crop,st, &
         100.0_real64,bundle)
    call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.initial_crop%ready(),'blocked source flag profile rejected')
    call initial_app%initialize_weather_crop_daystart(r,c,empty_owner,2_int64,932_int64,initial_crop,st, &
         100.0_real64,invalid_bundle)
    call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and..not.initial_crop%ready(),'unconstructed WOFOST parameters rejected')
    call initial_app%initialize_weather_crop_daystart(r,c,empty_owner,2_int64,932_int64,initial_crop,st, &
         100.0_real64,bundle)
    call require(st==FMR_APP_BOOT_OK.and.initial_crop%current_revision()==0_int64,'physical immediate crop initialization')
    call initial_app%capture_weather_crop_continuation(initial_crop,saved,st)
    call require(st==FMR_APP_BOOT_OK,'immediate emerged owner and actual soil joint persistence')
    do j=1,2
      call initial_crop%snapshot(snapshot,ok);call require(ok,'immediate physical owner snapshot')
      select type(snapshot)
      type is(fmr_wofost_crop_transaction_state_t)
        call snapshot%snapshot_owner(actual,ok);call require(ok.and.actual%crop_emerged,'actual source initialized emerged owner')
      class default
        call require(.false.,'existing immediate crop transaction type')
      end select
      call read_lifecycle(initial_crop,life)
      call require(life%prepared.and.life%sown.and.life%germinated.and.life%emerged.and. &
           life%germination_temperature_sum==0.0_real64,'source task2 immediate flags and zero germination sum')
      call actual%derive_actual_leaf_area_index(0.025_real64,0.01_real64,lai,st)
      call require(st==WOFOST_CROP_OWNER_OK,'actual source canopy derivation')
      values=[actual%biomass%root_biomass,actual%biomass%stem_biomass,actual%biomass%leaf_biomass(1), &
           actual%biomass%storage_biomass,actual%biomass%exponential_leaf_area_index, &
           actual%biomass%specific_leaf_area(1),actual%biomass%leaf_age(1),actual%development_stage, &
           actual%evolution_continuation%temperature_sum,lai]
      call require(all(transfer(values,[0_int64],10)==transfer(expected,[0_int64],10)), &
           'literal B111 initialization equals real physical owner including restart')
      call require(abs(sum(values(1:4))-100.0_real64)<=1.0e-12_real64,'initial crop biomass conservation')
      call constant_table(5.0_real64,depth);call constant_table(1.0_real64,density)
      call actual%derive_dvs_root_uptake_input(depth,density,30.0_real64, &
           [-5.0_real64,-10.0_real64,-20.0_real64,-30.0_real64],root_input,ok,st)
      call require(ok.and.st==WOFOST_CROP_OWNER_OK.and.root_input%crop_emerged.and.root_input%rooted_nodes==1, &
           'existing DVS static root owner materializes initial emerged crop profile')
      call require(root_input%cumulative_root_fraction(1)==0.0_real64.and. &
           root_input%cumulative_root_fraction(root_input%rooted_nodes+1)==1.0_real64, &
           'initial root profile closes normalized extraction geometry')
      call initial_app%copy_committed_for_crop(1,initial_soil,st)
      call require(st==FMR_APP_BOOT_OK.and.initial_soil%current_revision()==0_int64,'initialization invents no accepted hydro event')
      call initial_app%initialize_weather_crop_daystart(r,c,empty_owner,2_int64,932_int64,initial_crop,st, &
           100.0_real64,bundle)
      call require(st==FMR_APP_BOOT_CROP_TRANSACTION_FAILED.and.initial_crop%current_revision()==0_int64, &
           'initial emerged crop cannot be reinitialized, including after restore')
      call initial_app%close(st);call require(st==FMR_APP_BOOT_OK,'close immediate profile')
      if(j==1) then
        initial_crop=kernel_committed_state_t()
        call initial_app%restore_weather_crop_continuation(saved,initial_crop,st)
        call require(st==FMR_APP_BOOT_OK,'joint immediate WOFOST startup restoration')
      end if
    end do
    print '(a)', 'CROP_FILE_WEATHER_IMMEDIATE_SOURCE_OWNER_ROOT_RESTART=PASS'
  end subroutine
  subroutine historical_germination(sum,complete)
    real(real64),intent(inout)::sum
    logical,intent(out)::complete
    call b111_germination_oracle(controls%germ_mode,sum,controls%optimal_sum,controls%base_temperature, &
         controls%max_effective_temperature,b111_daily_tav(tmin,tmax),hgerm, &
         controls%dry_head,controls%wet_head,controls%water_response_a,complete)
  end subroutine
  subroutine print_exact_postimage(soil,crop,storage)
    type(kernel_committed_state_t),intent(in)::soil,crop
    real(real64),intent(in)::storage
    class(transaction_state_t),allocatable::physical
    real(real64),allocatable::derivative(:)
    type(crop_lifecycle_continuation_t)::value
    logical::ok
    integer::i
    call soil%snapshot(physical,ok)
    call require(ok,'exact hydro postimage snapshot')
    select type(physical)
    type is(fmr_b110_temporal_indicator_state_t)
      do i=1,physical%active_nodes
        write(*,'(a,i0,2(1x,z16.16))') 'CROP_FILE_WEATHER_SOIL_BITS=',i, &
             transfer(physical%pressure_head(i),0_int64),transfer(physical%water_content(i),0_int64)
      end do
      write(*,'(a,3(1x,z16.16))') 'CROP_FILE_WEATHER_SURFACE_LEDGER_BITS=', &
           transfer(physical%ponding_depth,0_int64),transfer(physical%groundwater_level,0_int64),transfer(storage,0_int64)
      call physical%temporal_history_snapshot(derivative,ok)
      call require(ok,'exact Richards physical history postimage')
      do i=1,size(derivative)
        write(*,'(a,i0,1x,z16.16)') 'CROP_FILE_WEATHER_HISTORY_BITS=',i,transfer(derivative(i),0_int64)
      end do
    class default
      call require(.false.,'complete actual physical profile postimage type')
    end select
    call read_lifecycle(crop,value)
    write(*,'(a,4(1x,i0),1x,z16.16,5(1x,l1))') 'CROP_FILE_WEATHER_CROP_BITS=', &
         crop%current_lineage_id(),crop%current_revision(),value%revision,value%crop_identity, &
         transfer(value%germination_temperature_sum,0_int64), &
         value%prepared,value%sown,value%germinated,value%emerged,value%harvested
  end subroutine
  subroutine initialize_crop(committed,parameters,numerical)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_wofost_crop_transaction_parameters_t),intent(out)::parameters
    type(canonical_numerical_config_t),intent(out)::numerical
    type(wofost_crop_owner_state_t)::owner
    type(crop_lifecycle_continuation_t)::initial
    type(fmr_wofost_crop_transaction_state_t)::state
    type(wofost_rate_parameter_bundle_t)::bundle
    type(wofost_one_day_update_parameters_t)::update
    class(transaction_state_t),allocatable::physical
    integer::s
    logical::ok
    call make_bundle(bundle)
    call construct_fmr_wofost_crop_transaction_parameters(bundle,update,0.0_real64,0.0_real64,parameters,s)
    call require(s==FMR_WOF38_OK,'existing WOFOST parameters ready')
    numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    numerical%transaction%temporal_tolerance=0.0_real64
    numerical%transaction%mass_tolerance=0.0_real64
    numerical%transaction%max_retries=0
    numerical%max_committed_substeps=1
  end subroutine
  subroutine read_lifecycle(committed,value)
    type(kernel_committed_state_t),intent(in)::committed
    type(crop_lifecycle_continuation_t),intent(out)::value
    class(transaction_state_t),allocatable::physical
    logical::ok
    call committed%snapshot(physical,ok)
    call require(ok,'accepted crop snapshot')
    select type(physical)
    type is(fmr_wofost_crop_transaction_state_t)
      call physical%snapshot_lifecycle(value,ok)
      call require(ok.and.value%ready(),'accepted lifecycle')
      if(committed%current_revision()>0_int64) call require(physical%receipt_ready(),'positive event receipt')
      if(committed%current_revision()==0_int64) call require(.not.physical%receipt_ready(),'initialization is not a physical event')
    class default
      call require(.false.,'accepted crop state type')
    end select
  end subroutine
  subroutine make_bundle(bundle)
    type(wofost_rate_parameter_bundle_t), intent(out) :: bundle
    type(wofost_rate_scalar_parameters_t) :: scalar
    type(wofost_rate_parameter_tables_t) :: tables
    integer :: status

    scalar = wofost_rate_scalar_parameters_t()
    scalar%development_daylength_mode = 1
    scalar%daylength_upper_hours = 16.0_real64
    scalar%daylength_lower_hours = 8.0_real64
    scalar%vegetative_temperature_sum_required = 1000.0_real64
    scalar%generative_temperature_sum_required = 800.0_real64
    scalar%diffuse_extinction_coefficient = 0.6_real64
    scalar%initial_light_use_efficiency = 0.45_real64
    scalar%co2_to_dry_matter_fraction = 0.4_real64
    scalar%attainable_yield_multiplier = 0.9_real64
    scalar%conversion_efficiency_root = 0.7_real64
    scalar%conversion_efficiency_stem = 0.65_real64
    scalar%conversion_efficiency_leaf = 0.72_real64
    scalar%conversion_efficiency_storage = 0.8_real64
    scalar%respiration_temperature_q10 = 2.0_real64
    scalar%maintenance_respiration_root = 0.01_real64
    scalar%maintenance_respiration_leaf = 0.02_real64
    scalar%maintenance_respiration_stem = 0.015_real64
    scalar%maintenance_respiration_storage = 0.005_real64
    scalar%maximum_leaf_relative_death_rate = 0.03_real64
    scalar%leaf_age_base_temperature = 0.0_real64
    scalar%maximum_relative_lai_growth_rate = 0.04_real64

    call constant_table(10.0_real64, tables%temperature_sum_increment)
    call constant_table(30.0_real64, tables%maximum_assimilation)
    call constant_table(1.0_real64, tables%daytime_temperature_factor)
    call constant_table(1.0_real64, tables%minimum_temperature_factor)
    call constant_table(1.0_real64, tables%maintenance_respiration_factor)
    call constant_table(0.2_real64, tables%root_partition_fraction)
    call constant_table(0.4_real64, tables%leaf_partition_fraction)
    call constant_table(0.4_real64, tables%stem_partition_fraction)
    call constant_table(0.2_real64, tables%storage_partition_fraction)
    call constant_table(0.01_real64, tables%relative_root_death_rate)
    call constant_table(0.01_real64, tables%relative_stem_death_rate)
    call constant_table(0.02_real64, tables%specific_leaf_area)

    call construct_wofost_rate_parameter_bundle(scalar, tables, bundle, status)
    call require(status == WOFOST_RATE_PARAMETER_OK, 'rate parameter bundle status')
    call require(bundle%ready(), 'rate parameter bundle ready')
  end subroutine make_bundle

  subroutine constant_table(value, table)
    real(real64), intent(in) :: value
    type(wofost_rate_table_t), intent(out) :: table
    real(real64) :: x(1), y(1)
    integer :: status
    x = [0.0_real64]
    y = [value]
    call construct_wofost_rate_table(x, y, table, status)
    call require(status == WOFOST_RATE_TABLE_OK, 'constant rate table')
  end subroutine constant_table

  subroutine copy_input_file(source,target)
    character(*),intent(in)::source,target
    character(:),allocatable::bytes
    integer::unit,n,ios
    open(newunit=unit,file=source,status='old',access='stream',form='unformatted',action='read',iostat=ios)
    call require(ios==0,'negative input copy source open')
    inquire(unit=unit,size=n)
    allocate(character(n)::bytes)
    read(unit)bytes
    close(unit)
    open(newunit=unit,file=target,status='replace',access='stream',form='unformatted',action='write',iostat=ios)
    call require(ios==0,'negative input copy target open')
    write(unit)bytes
    close(unit)
  end subroutine
  subroutine initialize_application_config(value, conductivity0)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64), intent(out) :: conductivity0

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 0.0_real64
    ! Tighten each internal transaction so accumulated interval residual
    ! remains beneath the independent 1e-12 cm interval acceptance gate.
    value%numerical%transaction%mass_tolerance = 1.0e-14_real64
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 2
    value%numerical%max_committed_substeps = 8
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id = 630101_int64
    value%tiles(1)%ledger_id = 730101_int64
    value%tiles(1)%template%template_id = 630201_int64
    value%tiles(1)%template%physics_topology_id = 630210_int64
    value%tiles(1)%template%vertical_layout_id = 630220_int64
    value%tiles(1)%template%state_layout_id = 630230_int64
    value%tiles(1)%template%solver_interface_id = 630240_int64
    value%tiles(1)%template%optional_state_layout_id = 0_int64
    value%tiles(1)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters)
    call initialize_state_and_forcing(value%tiles(1)%parameters, value%tiles(1)%initial_state, &
         value%tiles(1)%base_forcing, conductivity0)
  end subroutine initialize_application_config

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: k

    p%parameter_set_id = 640001_int64
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance = disnod(1:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 7
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads = H0_CM
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -2.0_real64

    forcing%top_flux = -conductivity0
    forcing%top_head = H0_CM
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing

  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok) then
      print *, 'CROP_FILE_WEATHER_FAIL ',message
      error stop 1
    end if
  end subroutine
end program
