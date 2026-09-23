program test_rm08_swap_ribasim_bridge
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions
  use mod_tcs1_dcs2_sprinkling_irrigation_process
  use mod_rutter_interception_process
  use mod_fmr_hupsel_management_transaction
  implicit none

  integer(int64), parameter :: lineage = 8008_int64
  integer(int64), parameter :: crop_revision = 101_int64
  real(real64), parameter :: t0 = 237.0_real64
  real(real64), parameter :: t1 = 238.0_real64
  real(real64), parameter :: tol = 1.0e-10_real64

  character(len=32) :: mode, arg
  real(real64) :: allocated_cm, supplied_cm
  type(tcs1_dcs2_sprinkling_parameters_t) :: p
  type(tcs1_dcs2_sprinkling_state_t) :: irrigation0, ia, ib
  type(rutter_state_t) :: rutter0, ra, rb
  type(rutter_interval_input_t) :: rutter_template
  type(tcs1_dcs2_sprinkling_request_t) :: request
  type(fmr_hupsel_management_state_t) :: management0
  type(fmr_hupsel_management_parameters_t) :: parameters
  type(fmr_hupsel_management_demand_receipt_t) :: receipt
  type(fmr_hupsel_management_forcing_t) :: forcing
  type(fmr_hupsel_management_model_t), target :: model
  type(fmr_hupsel_management_observation_t) :: oa, ob
  type(kernel_committed_state_t) :: committed
  type(kernel_checkpoint_t) :: checkpoint
  type(kernel_candidate_state_t) :: ca, cb
  type(kernel_result_t) :: result_a, result_b
  type(kernel_diagnostics_t) :: da, db
  type(kernel_executor_t) :: executor
  type(canonical_numerical_config_t) :: config
  class(transaction_state_t), allocatable :: initial, sa, sb
  logical :: ok, available, did_commit
  integer :: status, commit_status, ios

  call get_command_argument(1,mode)
  if (len_trim(mode)==0) error stop 'usage: test_rm08_swap_ribasim_bridge request|consume [allocated_cm supplied_cm]'

  call setup_parameters(p)
  call construct_fmr_hupsel_management_parameters(p,parameters,status)
  call require(status==FMR_RM_OK,'parameters')
  irrigation0=tcs1_dcs2_sprinkling_state_t()
  irrigation0%dayfix=12
  rutter0=rutter_state_t()
  rutter0%canopy_storage_cm=0.02_real64
  call initialize_fmr_hupsel_management_state(irrigation0,rutter0,management0,status)
  call require(status==FMR_RM_OK,'management origin')
  call management0%clone(initial)
  call committed%initialize(lineage,initial,ok,initial_time=t0)
  call require(ok,'committed origin')
  call committed%capture_checkpoint(checkpoint,ok)
  call require(ok,'checkpoint')
  call setup_request(request)

  call derive_fmr_hupsel_management_demand_receipt(checkpoint,parameters,request,crop_revision,receipt,status)
  call require(status==FMR_RM_OK,'RM07 receipt')
  available=receipt%ready()
  call require(available,'RM07 receipt ready')
  call require(abs(receipt%requested_depth_cm()-2.0_real64)<=tol,'frozen 2 cm request')

  select case(trim(mode))
  case('request')
    write(*,'(A,ES26.17E3)') 'RM08_SWAP_REQUEST_DEPTH_CM=',receipt%requested_depth_cm()
    write(*,'(A,I0)') 'RM08_SWAP_ORIGIN_LINEAGE=',receipt%origin_lineage_id()
    write(*,'(A,I0)') 'RM08_SWAP_ORIGIN_REVISION=',receipt%origin_revision()
    write(*,'(A)') 'RM08_SWAP_READ_ONLY_REQUEST=PASS'

  case('consume')
    call get_command_argument(2,arg); read(arg,*,iostat=ios) allocated_cm
    call require(ios==0,'parse allocated depth')
    call get_command_argument(3,arg); read(arg,*,iostat=ios) supplied_cm
    call require(ios==0,'parse supplied depth')
    call require(allocated_cm>=0.0_real64 .and. supplied_cm>=0.0_real64,'nonnegative Ribasim receipt values')

    call setup_rutter(rutter_template)
    call prepare_fmr_hupsel_management_forcing(request,rutter_template,crop_revision,allocated_cm,supplied_cm,forcing,status)
    call require(status==FMR_RM_OK,'bind Ribasim allocation/supply to RM06')
    call setup_config(config)
    call executor%bind_model(model)

    call executor%advance_interval(parameters,committed,forcing,config,t0,t1,result_a,ca,da,checkpoint)
    call require(result_a%completed,'candidate A')
    available=ca%ready(); call require(available,'candidate A ready')
    call model%observation(oa)
    call ca%snapshot(sa,available); call require(available,'candidate A snapshot')
    call extract(sa,ia,ra)
    call require(committed%current_revision()==0_int64,'candidate A nonmutating')
    call executor%rollback_candidate(ca,da)
    available=ca%ready(); call require(.not.available,'candidate A discarded')
    call require(committed%current_revision()==0_int64,'discard leaves origin revision')

    call executor%advance_interval(parameters,committed,forcing,config,t0,t1,result_b,cb,db,checkpoint)
    call require(result_b%completed,'candidate B')
    available=cb%ready(); call require(available,'candidate B ready')
    call model%observation(ob)
    call cb%snapshot(sb,available); call require(available,'candidate B snapshot')
    call extract(sb,ib,rb)

    call require(same_irrigation(ia,ib),'SWAP candidate replay irrigation')
    call require(same_rutter(ra,rb),'SWAP candidate replay Rutter')
    call require(same_observation(oa,ob),'SWAP candidate replay observation')
    call require(abs(ob%requested_depth_cm-receipt%requested_depth_cm())<=tol,'request preserved through Ribasim')
    call require(abs(ob%allocated_depth_cm-allocated_cm)<=tol,'Ribasim allocation consumed separately')
    call require(abs(ob%supplied_depth_cm-supplied_cm)<=tol,'Ribasim physical supply consumed separately')

    call executor%commit_candidate(committed,cb,db,did_commit,commit_status)
    call require(did_commit .and. commit_status==KERNEL_COMMIT_STATUS_COMMITTED,'exactly once SWAP management commit')
    call require(committed%current_revision()==1_int64,'one committed revision')

    write(*,'(A,ES26.17E3)') 'RM08_CONSUMED_REQUEST_DEPTH_CM=',ob%requested_depth_cm
    write(*,'(A,ES26.17E3)') 'RM08_CONSUMED_ALLOCATED_DEPTH_CM=',ob%allocated_depth_cm
    write(*,'(A,ES26.17E3)') 'RM08_CONSUMED_SUPPLIED_DEPTH_CM=',ob%supplied_depth_cm
    write(*,'(A,ES26.17E3)') 'RM08_CONSUMED_NET_IRRIGATION_CM=',ob%net_surface_irrigation_amount_cm
    write(*,'(A)') 'RM08_SWAP_CANDIDATE_REPLAY=PASS'
    write(*,'(A)') 'RM08_ALLOCATION_SUPPLY_BOUND_TO_SAME_ORIGIN=PASS'
    write(*,'(A)') 'RM08_SWAP_EXACTLY_ONCE_MANAGEMENT_COMMIT=PASS'
    write(*,'(A)') 'RM08 SWAP SIDE REAL RIBASIM RECEIPT CONSUMPTION PASS'

  case default
    error stop 'unknown RM08 mode'
  end select

contains

  subroutine setup_parameters(x)
    type(tcs1_dcs2_sprinkling_parameters_t),intent(out)::x
    x=tcs1_dcs2_sprinkling_parameters_t()
    x%enabled=.true.; x%rate_cm_per_day=36.0_real64
    x%threshold_knot_count=2; x%threshold_dvs(1:2)=[0.0_real64,2.0_real64]
    x%threshold_trel(1:2)=[0.85_real64,0.85_real64]
    x%depth_knot_count=2; x%depth_dvs(1:2)=[0.0_real64,2.0_real64]
    x%depth_cm(1:2)=[2.0_real64,2.0_real64]
    x%minimum_interval_days=7
  end subroutine setup_parameters

  subroutine setup_request(r)
    type(tcs1_dcs2_sprinkling_request_t),intent(out)::r
    r=tcs1_dcs2_sprinkling_request_t()
    r%t0=t0; r%t1=t1; r%dvs=1.5060476190476193_real64
    r%potential_transpiration_day_cm=0.31534971046284993_real64
    r%dry_reduction_day_cm=0.11551480616973946_real64
    r%salinity_reduction_day_cm=0.0_real64
    r%selection_opportunity=.true.; r%irrigation_enabled=.true.; r%schedule_enabled=.true.
    r%crop_emerged=.true.; r%irrigation_window_open=.true.
  end subroutine setup_request

  subroutine setup_rutter(r)
    type(rutter_interval_input_t),intent(out)::r
    r=rutter_interval_input_t()
    r%gross_rain_cm_per_day=0.0_real64
    r%vegetation_cover_fraction=0.5_real64
    r%canopy_storage_capacity_cm=0.12_real64
    r%interception_evaporation_capacity_cm_per_day=0.01_real64
    r%potential_transpiration_dry_cm_per_day=0.011621209174202582_real64
    r%potential_transpiration_wet_cm_per_day=0.0047014973566050335_real64
  end subroutine setup_rutter

  subroutine setup_config(x)
    type(canonical_numerical_config_t),intent(out)::x
    x=canonical_numerical_config_t()
    x%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    x%transaction%temporal_tolerance=0.0_real64
    x%transaction%mass_tolerance=0.0_real64
    x%transaction%retry_scale=0.5_real64
    x%transaction%max_retries=0
    x%max_committed_substeps=1
    x%progress_tolerance=0.0_real64
  end subroutine setup_config

  subroutine extract(box,irrigation,rutter)
    class(transaction_state_t),allocatable,intent(in)::box
    type(tcs1_dcs2_sprinkling_state_t),intent(out)::irrigation
    type(rutter_state_t),intent(out)::rutter
    logical::got
    call require(allocated(box),'candidate snapshot allocated')
    select type(typed=>box)
    type is(fmr_hupsel_management_state_t)
      call typed%snapshot(irrigation,rutter,got)
      call require(got,'typed candidate snapshot')
    class default
      call require(.false.,'candidate snapshot type')
    end select
  end subroutine extract

  logical function same_irrigation(x,y)
    type(tcs1_dcs2_sprinkling_state_t),intent(in)::x,y
    same_irrigation=x%dayfix==y%dayfix .and. (x%active_event .eqv. y%active_event) .and. &
      transfer(x%active_event_start,0_int64)==transfer(y%active_event_start,0_int64) .and. &
      transfer(x%active_event_end,0_int64)==transfer(y%active_event_end,0_int64)
  end function same_irrigation

  logical function same_rutter(x,y)
    type(rutter_state_t),intent(in)::x,y
    same_rutter=transfer(x%canopy_storage_cm,0_int64)==transfer(y%canopy_storage_cm,0_int64)
  end function same_rutter

  logical function same_observation(x,y)
    type(fmr_hupsel_management_observation_t),intent(in)::x,y
    same_observation=(x%decision_evaluated .eqv. y%decision_evaluated) .and. &
      (x%irrigation_requested .eqv. y%irrigation_requested) .and. x%crop_origin_revision==y%crop_origin_revision
    same_observation=same_observation .and. &
      transfer(x%requested_depth_cm,0_int64)==transfer(y%requested_depth_cm,0_int64) .and. &
      transfer(x%allocated_depth_cm,0_int64)==transfer(y%allocated_depth_cm,0_int64) .and. &
      transfer(x%supplied_depth_cm,0_int64)==transfer(y%supplied_depth_cm,0_int64) .and. &
      transfer(x%net_surface_irrigation_amount_cm,0_int64)==transfer(y%net_surface_irrigation_amount_cm,0_int64)
  end function same_observation

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'RM08_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_rm08_swap_ribasim_bridge
