module mod_rm13_management_c_bridge
  use, intrinsic :: iso_c_binding, only: c_double, c_int
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_candidate_state_t, &
       kernel_executor_t, kernel_result_t, kernel_diagnostics_t, KERNEL_COMMIT_STATUS_COMMITTED
  use mod_tcs1_dcs2_sprinkling_irrigation_process, only: tcs1_dcs2_sprinkling_parameters_t, &
       tcs1_dcs2_sprinkling_state_t, tcs1_dcs2_sprinkling_request_t
  use mod_rutter_interception_process, only: rutter_state_t, rutter_interval_input_t
  use mod_fmr_hupsel_management_transaction
  use mod_fmr_ribasim_management_binding
  implicit none
  private

  integer(int64), parameter :: LINEAGE_ID=130013_int64
  integer(int64), parameter :: CROP_REVISION=13_int64
  real(real64), parameter :: T0=237.0_real64
  real(real64), parameter :: DURATION_DAY=1.0e-4_real64
  real(real64), parameter :: T1=T0+DURATION_DAY
  real(real64), parameter :: REQUEST_DEPTH_CM=0.0036_real64
  real(real64), parameter :: RATE_CM_PER_DAY=36.0_real64

  type(fmr_hupsel_management_parameters_t), save :: parameters
  type(fmr_hupsel_management_demand_receipt_t), save :: demand
  type(fmr_hupsel_management_forcing_t), save :: forcing
  type(fmr_hupsel_management_model_t), target, save :: model
  type(kernel_executor_t), save :: executor
  type(kernel_committed_state_t), save :: committed
  type(kernel_candidate_state_t), save :: candidate
  type(kernel_diagnostics_t), save :: diagnostics
  type(fmr_hupsel_management_observation_t), save :: observation
  type(rutter_interval_input_t), save :: rutter_template
  type(canonical_numerical_config_t), save :: config
  logical, save :: initialized=.false.
  logical, save :: candidate_live=.false.

  public :: rm13_management_initialize_c, rm13_management_prepare_candidate_c
  public :: rm13_management_discard_candidate_c, rm13_management_preflight_c
  public :: rm13_management_commit_c, rm13_management_state_c

contains

  integer(c_int) function rm13_management_initialize_c(request_depth_cm) bind(C,name="rm13_management_initialize_c")
    real(c_double), intent(out) :: request_depth_cm
    type(tcs1_dcs2_sprinkling_parameters_t) :: irrigation_parameters
    type(tcs1_dcs2_sprinkling_state_t) :: irrigation0
    type(rutter_state_t) :: rutter0
    type(fmr_hupsel_management_state_t) :: management0
    type(tcs1_dcs2_sprinkling_request_t) :: request
    type(kernel_checkpoint_t) :: checkpoint
    class(transaction_state_t), allocatable :: initial
    logical :: ok,available
    integer :: status
    real(real64) :: committed_time

    rm13_management_initialize_c=10_c_int
    request_depth_cm=0.0_c_double
    initialized=.false.; candidate_live=.false.
    parameters=fmr_hupsel_management_parameters_t()
    demand=fmr_hupsel_management_demand_receipt_t()
    forcing=fmr_hupsel_management_forcing_t()
    observation=fmr_hupsel_management_observation_t()

    call setup_irrigation(irrigation_parameters)
    call construct_fmr_hupsel_management_parameters(irrigation_parameters,parameters,status)
    if(status/=FMR_RM_OK)then
      rm13_management_initialize_c=100_c_int+int(status,c_int)
      return
    end if

    irrigation0=tcs1_dcs2_sprinkling_state_t()
    irrigation0%dayfix=12
    rutter0=rutter_state_t()
    rutter0%canopy_storage_cm=0.0_real64
    call initialize_fmr_hupsel_management_state(irrigation0,rutter0,management0,status)
    if(status/=FMR_RM_OK)then
      rm13_management_initialize_c=200_c_int+int(status,c_int)
      return
    end if

    call management0%clone(initial)
    call committed%initialize(LINEAGE_ID,initial,ok,initial_time=T0)
    if(.not.ok)then
      rm13_management_initialize_c=301_c_int
      return
    end if
    call committed%capture_checkpoint(checkpoint,ok)
    if(.not.ok)then
      rm13_management_initialize_c=302_c_int
      return
    end if

    call setup_request(request)
    call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,CROP_REVISION,demand,status)
    if(status/=FMR_RM_OK)then
      rm13_management_initialize_c=400_c_int+int(status,c_int)
      return
    end if
    available=demand%ready()
    if(.not.available)then
      rm13_management_initialize_c=401_c_int
      return
    end if
    if(abs(demand%requested_depth_cm()-REQUEST_DEPTH_CM)>1.0e-12_real64)then
      rm13_management_initialize_c=402_c_int
      return
    end if

    call setup_rutter(rutter_template)
    call setup_config(config)
    call executor%bind_model(model)

    call committed%current_time(committed_time,available)
    if(.not.available)then
      rm13_management_initialize_c=501_c_int
      return
    end if
    if(abs(committed_time-T0)>1.0e-12_real64)then
      rm13_management_initialize_c=502_c_int
      return
    end if
    request_depth_cm=demand%requested_depth_cm()
    initialized=.true.
    rm13_management_initialize_c=0_c_int
  end function rm13_management_initialize_c

  integer(c_int) function rm13_management_prepare_candidate_c(ribasim_origin_id,ribasim_origin_revision, &
       allocated_depth_cm,supplied_depth_cm,source_level_margin_m,level_difference_threshold_m,low_storage_factor, &
       net_irrigation_cm,gross_rate_cm_per_day) bind(C,name="rm13_management_prepare_candidate_c")
    integer(c_int), value, intent(in) :: ribasim_origin_id,ribasim_origin_revision
    real(c_double), value, intent(in) :: allocated_depth_cm,supplied_depth_cm
    real(c_double), value, intent(in) :: source_level_margin_m,level_difference_threshold_m,low_storage_factor
    real(c_double), intent(out) :: net_irrigation_cm,gross_rate_cm_per_day
    type(fmr_ribasim_realization_receipt_t) :: realization
    type(kernel_result_t) :: result
    logical :: available
    integer :: status

    rm13_management_prepare_candidate_c=1_c_int
    net_irrigation_cm=0.0_c_double; gross_rate_cm_per_day=0.0_c_double
    if(.not.initialized .or. candidate_live)return

    call construct_fmr_ribasim_full_realization_receipt(demand,int(ribasim_origin_id,int64), &
         int(ribasim_origin_revision,int64),real(allocated_depth_cm,real64),real(supplied_depth_cm,real64), &
         real(source_level_margin_m,real64),real(level_difference_threshold_m,real64), &
         real(low_storage_factor,real64),realization,status)
    if(status/=FMR_RB_OK .or. .not.realization%ready())then
      rm13_management_prepare_candidate_c=100_c_int+int(status,c_int)
      return
    end if

    call prepare_fmr_hupsel_management_forcing_from_ribasim_receipt(demand,rutter_template,realization,forcing,status)
    if(status/=FMR_RB_OK .or. .not.forcing%ready())then
      rm13_management_prepare_candidate_c=200_c_int+int(status,c_int)
      return
    end if

    call executor%advance_interval(parameters,committed,forcing,config,T0,T1,result,candidate,diagnostics)
    if(.not.result%completed .or. .not.candidate%ready())then
      rm13_management_prepare_candidate_c=300_c_int+int(model%last_status_code(),c_int)
      return
    end if
    call model%observation(observation)
    if(.not.observation%decision_evaluated .or. .not.observation%irrigation_requested)return
    if(abs(observation%requested_depth_cm-REQUEST_DEPTH_CM)>1.0e-12_real64)return
    if(abs(observation%allocated_depth_cm-real(allocated_depth_cm,real64))>1.0e-12_real64)return
    if(abs(observation%supplied_depth_cm-real(supplied_depth_cm,real64))>1.0e-12_real64)return
    if(abs(observation%net_surface_irrigation_amount_cm-observation%supplied_depth_cm)>1.0e-12_real64)return
    available=candidate%ready()
    if(.not.available .or. committed%current_revision()/=0_int64)return

    candidate_live=.true.
    net_irrigation_cm=observation%net_surface_irrigation_amount_cm
    gross_rate_cm_per_day=observation%gross_surface_rate_cm_per_day
    rm13_management_prepare_candidate_c=0_c_int
  end function rm13_management_prepare_candidate_c

  integer(c_int) function rm13_management_discard_candidate_c() bind(C,name="rm13_management_discard_candidate_c")
    rm13_management_discard_candidate_c=1_c_int
    if(.not.initialized .or. .not.candidate_live)return
    call executor%rollback_candidate(candidate,diagnostics)
    if(candidate%ready())return
    if(committed%current_revision()/=0_int64)return
    candidate_live=.false.
    rm13_management_discard_candidate_c=0_c_int
  end function rm13_management_discard_candidate_c

  integer(c_int) function rm13_management_preflight_c() bind(C,name="rm13_management_preflight_c")
    rm13_management_preflight_c=1_c_int
    if(.not.initialized .or. .not.candidate_live)return
    if(.not.candidate%ready())return
    if(committed%current_revision()/=0_int64)return
    if(abs(observation%requested_depth_cm-REQUEST_DEPTH_CM)>1.0e-12_real64)return
    if(abs(observation%net_surface_irrigation_amount_cm-observation%supplied_depth_cm)>1.0e-12_real64)return
    rm13_management_preflight_c=0_c_int
  end function rm13_management_preflight_c

  integer(c_int) function rm13_management_commit_c() bind(C,name="rm13_management_commit_c")
    logical :: did_commit
    integer :: status,commit_status
    rm13_management_commit_c=1_c_int
    if(rm13_management_preflight_c()/=0_c_int)return
    call executor%commit_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    if(.not.did_commit .or. commit_status/=KERNEL_COMMIT_STATUS_COMMITTED)return
    if(committed%current_revision()/=1_int64)return
    candidate_live=.false.
    rm13_management_commit_c=0_c_int
  end function rm13_management_commit_c

  integer(c_int) function rm13_management_state_c(revision,request_depth_cm,allocated_depth_cm,supplied_depth_cm, &
       net_irrigation_cm,gross_rate_cm_per_day) bind(C,name="rm13_management_state_c")
    integer(c_int), intent(out) :: revision
    real(c_double), intent(out) :: request_depth_cm,allocated_depth_cm,supplied_depth_cm,net_irrigation_cm,gross_rate_cm_per_day
    rm13_management_state_c=1_c_int
    revision=-1_c_int; request_depth_cm=0.0_c_double; allocated_depth_cm=0.0_c_double
    supplied_depth_cm=0.0_c_double; net_irrigation_cm=0.0_c_double; gross_rate_cm_per_day=0.0_c_double
    if(.not.initialized)return
    revision=int(committed%current_revision(),c_int)
    request_depth_cm=demand%requested_depth_cm()
    allocated_depth_cm=observation%allocated_depth_cm
    supplied_depth_cm=observation%supplied_depth_cm
    net_irrigation_cm=observation%net_surface_irrigation_amount_cm
    gross_rate_cm_per_day=observation%gross_surface_rate_cm_per_day
    rm13_management_state_c=0_c_int
  end function rm13_management_state_c

  subroutine setup_irrigation(p)
    type(tcs1_dcs2_sprinkling_parameters_t),intent(out)::p
    p=tcs1_dcs2_sprinkling_parameters_t()
    p%enabled=.true.; p%rate_cm_per_day=RATE_CM_PER_DAY
    p%threshold_knot_count=2; p%threshold_dvs(1:2)=[0.0_real64,2.0_real64]
    p%threshold_trel(1:2)=[0.85_real64,0.85_real64]
    p%depth_knot_count=2; p%depth_dvs(1:2)=[0.0_real64,2.0_real64]
    p%depth_cm(1:2)=[REQUEST_DEPTH_CM,REQUEST_DEPTH_CM]
    p%minimum_interval_days=7
  end subroutine setup_irrigation

  subroutine setup_request(r)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::r
    r=tcs1_dcs2_sprinkling_request_t()
    r%t0=T0; r%t1=T1; r%dvs=1.5060476190476193_real64
    r%potential_transpiration_day_cm=0.31534971046284993_real64
    r%dry_reduction_day_cm=0.11551480616973946_real64
    r%salinity_reduction_day_cm=0.0_real64
    r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
    r%crop_emerged=.true.; r%irrigation_window_open=.true.; r%fixed_event_already_selected=.false.
  end subroutine setup_request

  subroutine setup_rutter(r)
    type(rutter_interval_input_t),intent(out)::r
    r=rutter_interval_input_t()
    r%gross_rain_cm_per_day=0.0_real64
    r%vegetation_cover_fraction=0.0_real64
    r%canopy_storage_capacity_cm=0.0_real64
    r%interception_evaporation_capacity_cm_per_day=0.0_real64
    r%potential_transpiration_dry_cm_per_day=0.0_real64
    r%potential_transpiration_wet_cm_per_day=0.0_real64
    r%interval_days=DURATION_DAY
  end subroutine setup_rutter

  subroutine setup_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c=canonical_numerical_config_t()
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=0.0_real64
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=0
    c%max_committed_substeps=1
    c%progress_tolerance=0.0_real64
  end subroutine setup_config

end module mod_rm13_management_c_bridge
