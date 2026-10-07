module mod_fmr_b111_soil_crop_n_transaction
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t,transaction_model_t,trial_outcome_t, &
       TX_MASS_MISSING_NONE,TX_MASS_MISSING_UNSPECIFIED
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t,soil_n_pool_state_t,soil_n_transfer_t, &
       soil_n_receipt_t,apply_soil_n_transfer,SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t,b111_soil_n_split_parameters_t, &
       build_b111_residue_transfer,B111_NADD_OK
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t
  use mod_b111_soil_n_daily_candidate, only: b111_soil_n_rate_environment_t,b111_soil_n_daily_candidate_result_t, &
       evaluate_b111_soil_n_daily_candidate,B111_NDAY_OK
  use mod_b111_crop_n_owner, only: b111_crop_n_state_t,b111_crop_n_forcing_t,b111_crop_n_request_t,b111_crop_n_receipt_t, &
       prepare_b111_crop_n_request,apply_b111_crop_n_day,B111_CROPN_OK
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t,FMR_SOIL_N_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_COUPLED_N_OK=0
  integer,parameter,public::FMR_B111_COUPLED_N_INVALID=1
  integer,parameter,public::FMR_B111_COUPLED_N_SOIL_FAILED=2
  integer,parameter,public::FMR_B111_COUPLED_N_CROP_FAILED=3
  integer,parameter,public::FMR_B111_COUPLED_N_TRANSFER_MISMATCH=4
  integer,parameter,public::FMR_B111_COUPLED_N_DUPLICATE_INTERVAL=5

  type,extends(transaction_state_t),public::fmr_b111_soil_crop_n_state_t
    private
    type(fmr_b111_soil_n_state_t)::soil
    type(b111_crop_n_state_t)::crop
    logical::initialized=.false.
    logical::interval_consumed=.false.
    real(real64)::last_t0=0.0_real64
    real(real64)::last_t1=0.0_real64
    real(real64)::pending_root_dm_kg_ha=0.0_real64
    real(real64)::pending_root_n_kg_ha=0.0_real64
    real(real64)::pending_leaf_dm_kg_ha=0.0_real64
    real(real64)::pending_leaf_n_kg_ha=0.0_real64
  contains
    procedure::clone=>coupled_clone
    procedure,public::ready=>coupled_ready
    procedure,public::snapshot=>coupled_snapshot
    procedure,public::consumed_interval=>coupled_consumed_interval
  end type

  type,public::fmr_b111_soil_crop_n_receipt_t
    integer::status=FMR_B111_COUPLED_N_INVALID
    type(b111_crop_n_request_t)::crop_request
    type(b111_soil_n_daily_candidate_result_t)::soil_process
    type(b111_crop_n_receipt_t)::crop_process
    real(real64)::internal_soil_to_crop_kg_m2=0.0_real64
    real(real64)::external_fixation_input_kg_m2=0.0_real64
    real(real64)::external_crop_loss_kg_m2=0.0_real64
    real(real64)::pending_residue_consumed_kg_m2=0.0_real64
    real(real64)::pending_residue_created_kg_m2=0.0_real64
  end type

  type,extends(transaction_model_t),public::fmr_b111_soil_crop_n_model_t
    private
    type(b111_organic_turnover_parameters_t)::turnover
    real(real64),allocatable::cfrac_fom(:)
    real(real64)::cfrac_biomass=0.0_real64
    real(real64)::cfrac_humus=0.0_real64
    type(b111_soil_n_rate_environment_t)::rate_environment
    type(b111_soil_n_exchange_forcing_t)::soil_forcing
    type(b111_crop_n_forcing_t)::crop_forcing
    type(b111_soil_n_split_parameters_t)::residue_split
    real(real64)::root_residue_age=0.0_real64
    real(real64)::leaf_residue_age=0.0_real64
    real(real64)::fra_deceased_leaf_to_soil=0.0_real64
    logical::residue_return_enabled=.false.
    type(fmr_b111_soil_crop_n_receipt_t)::last_receipt
    logical::configured=.false.
    integer::last_status=FMR_B111_COUPLED_N_INVALID
  contains
    procedure::advance=>coupled_advance
    procedure::storage=>coupled_storage
    procedure::temporal_error=>coupled_temporal_error
    procedure::storage_accounting_status=>coupled_storage_accounting_status
    procedure::attempt_context_required=>coupled_attempt_context_required
    procedure,public::last_status_code=>coupled_last_status
    procedure,public::snapshot_receipt=>coupled_snapshot_receipt
  end type

  public::initialize_fmr_b111_soil_crop_n_state
  public::configure_fmr_b111_soil_crop_n_model

contains

  subroutine initialize_fmr_b111_soil_crop_n_state(soil,crop,state,status,last_t0,last_t1,interval_consumed, &
       pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha)
    type(fmr_b111_soil_n_state_t),intent(in)::soil
    type(b111_crop_n_state_t),intent(in)::crop
    type(fmr_b111_soil_crop_n_state_t),intent(out)::state
    integer,intent(out)::status
    real(real64),intent(in),optional::last_t0,last_t1
    logical,intent(in),optional::interval_consumed
    real(real64),intent(in),optional::pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha

    state=fmr_b111_soil_crop_n_state_t();status=FMR_B111_COUPLED_N_INVALID
    if(.not.soil%ready().or..not.crop%valid())return
    if((present(last_t0).neqv.present(last_t1)).or.(present(last_t0).neqv.present(interval_consumed)))return
    if((present(pending_root_dm_kg_ha).or.present(pending_root_n_kg_ha).or.present(pending_leaf_dm_kg_ha).or. &
        present(pending_leaf_n_kg_ha)).and..not.(present(pending_root_dm_kg_ha).and.present(pending_root_n_kg_ha).and. &
        present(pending_leaf_dm_kg_ha).and.present(pending_leaf_n_kg_ha)))return
    if(present(last_t0))then
      if(.not.all(ieee_is_finite([last_t0,last_t1])).or.last_t1<=last_t0)return
      if(.not.interval_consumed)return
      state%last_t0=last_t0;state%last_t1=last_t1;state%interval_consumed=.true.
    end if
    if(present(pending_root_dm_kg_ha))then
      if(.not.all(ieee_is_finite([pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha])))return
      if(min(pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha)<0.0_real64)return
      if(pending_root_n_kg_ha>pending_root_dm_kg_ha.or.pending_leaf_n_kg_ha>pending_leaf_dm_kg_ha)return
      state%pending_root_dm_kg_ha=pending_root_dm_kg_ha;state%pending_root_n_kg_ha=pending_root_n_kg_ha
      state%pending_leaf_dm_kg_ha=pending_leaf_dm_kg_ha;state%pending_leaf_n_kg_ha=pending_leaf_n_kg_ha
    end if
    state%soil=soil;state%crop=crop;state%initialized=.true.;status=FMR_B111_COUPLED_N_OK
  end subroutine

  subroutine configure_fmr_b111_soil_crop_n_model(turnover,cfrac_fom,cfrac_biomass,cfrac_humus, &
       rate_environment,soil_forcing,crop_forcing,model,status,residue_split,root_residue_age,leaf_residue_age, &
       fra_deceased_leaf_to_soil)
    type(b111_organic_turnover_parameters_t),intent(in)::turnover
    real(real64),intent(in)::cfrac_fom(:),cfrac_biomass,cfrac_humus
    type(b111_soil_n_rate_environment_t),intent(in)::rate_environment
    type(b111_soil_n_exchange_forcing_t),intent(in)::soil_forcing
    type(b111_crop_n_forcing_t),intent(in)::crop_forcing
    type(fmr_b111_soil_crop_n_model_t),intent(out)::model
    integer,intent(out)::status
    type(b111_soil_n_split_parameters_t),intent(in),optional::residue_split
    real(real64),intent(in),optional::root_residue_age,leaf_residue_age,fra_deceased_leaf_to_soil

    model=fmr_b111_soil_crop_n_model_t();status=FMR_B111_COUPLED_N_INVALID
    if(size(cfrac_fom)<1.or..not.all(ieee_is_finite(cfrac_fom)).or. &
       .not.all(ieee_is_finite([cfrac_biomass,cfrac_humus])))return
    if(any(cfrac_fom<0.0_real64).or.cfrac_biomass<0.0_real64.or.cfrac_humus<0.0_real64)return
    if(abs(soil_forcing%dt_day-1.0_real64)>64.0_real64*epsilon(1.0_real64))return
    if(abs(crop_forcing%delt_day-1.0_real64)>64.0_real64*epsilon(1.0_real64))return
    if((present(residue_split).or.present(root_residue_age).or.present(leaf_residue_age).or. &
        present(fra_deceased_leaf_to_soil)).and..not.(present(residue_split).and.present(root_residue_age).and. &
        present(leaf_residue_age).and.present(fra_deceased_leaf_to_soil)))return
    if(.not.present(residue_split))then
      if(crop_forcing%drlv_kg_ha_day/=0.0_real64.or.crop_forcing%drst_kg_ha_day/=0.0_real64.or. &
         crop_forcing%drrt_kg_ha_day/=0.0_real64)return
    else
      if(.not.all(ieee_is_finite([root_residue_age,leaf_residue_age,fra_deceased_leaf_to_soil])))return
      if(root_residue_age<0.0_real64.or.leaf_residue_age<0.0_real64.or.fra_deceased_leaf_to_soil<0.0_real64.or. &
         fra_deceased_leaf_to_soil>1.0_real64)return
      model%residue_split=residue_split;model%root_residue_age=root_residue_age;model%leaf_residue_age=leaf_residue_age
      model%fra_deceased_leaf_to_soil=fra_deceased_leaf_to_soil;model%residue_return_enabled=.true.
    end if
    model%turnover=turnover;model%cfrac_fom=cfrac_fom
    model%cfrac_biomass=cfrac_biomass;model%cfrac_humus=cfrac_humus
    model%rate_environment=rate_environment;model%soil_forcing=soil_forcing;model%crop_forcing=crop_forcing
    model%configured=.true.;model%last_status=FMR_B111_COUPLED_N_OK;status=FMR_B111_COUPLED_N_OK
  end subroutine

  subroutine coupled_clone(self,copy)
    class(fmr_b111_soil_crop_n_state_t),intent(in)::self
    class(transaction_state_t),allocatable,intent(out)::copy
    allocate(fmr_b111_soil_crop_n_state_t::copy)
    select type(copy)
    type is(fmr_b111_soil_crop_n_state_t)
      copy%soil=self%soil;copy%crop=self%crop;copy%initialized=self%initialized
      copy%interval_consumed=self%interval_consumed;copy%last_t0=self%last_t0;copy%last_t1=self%last_t1
      copy%pending_root_dm_kg_ha=self%pending_root_dm_kg_ha;copy%pending_root_n_kg_ha=self%pending_root_n_kg_ha
      copy%pending_leaf_dm_kg_ha=self%pending_leaf_dm_kg_ha;copy%pending_leaf_n_kg_ha=self%pending_leaf_n_kg_ha
    end select
  end subroutine

  logical function coupled_ready(self) result(ok)
    class(fmr_b111_soil_crop_n_state_t),intent(in)::self
    ok=self%initialized.and.self%soil%ready().and.self%crop%valid().and. &
       all(ieee_is_finite([self%pending_root_dm_kg_ha,self%pending_root_n_kg_ha,self%pending_leaf_dm_kg_ha, &
       self%pending_leaf_n_kg_ha])).and.min(self%pending_root_dm_kg_ha,self%pending_root_n_kg_ha, &
       self%pending_leaf_dm_kg_ha,self%pending_leaf_n_kg_ha)>=0.0_real64.and. &
       self%pending_root_n_kg_ha<=self%pending_root_dm_kg_ha.and.self%pending_leaf_n_kg_ha<=self%pending_leaf_dm_kg_ha
    if(ok.and.self%interval_consumed)ok=ieee_is_finite(self%last_t0).and.ieee_is_finite(self%last_t1).and.self%last_t1>self%last_t0
  end function

  subroutine coupled_snapshot(self,soil,crop,last_t0,last_t1,interval_consumed,available, &
       pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha)
    class(fmr_b111_soil_crop_n_state_t),intent(in)::self
    type(fmr_b111_soil_n_state_t),intent(out)::soil
    type(b111_crop_n_state_t),intent(out)::crop
    real(real64),intent(out)::last_t0,last_t1
    logical,intent(out)::interval_consumed,available
    real(real64),intent(out),optional::pending_root_dm_kg_ha,pending_root_n_kg_ha,pending_leaf_dm_kg_ha,pending_leaf_n_kg_ha
    soil=fmr_b111_soil_n_state_t();crop=b111_crop_n_state_t()
    last_t0=0.0_real64;last_t1=0.0_real64;interval_consumed=.false.;available=self%ready()
    if(available)then
      soil=self%soil;crop=self%crop;last_t0=self%last_t0;last_t1=self%last_t1;interval_consumed=self%interval_consumed
      if(present(pending_root_dm_kg_ha))pending_root_dm_kg_ha=self%pending_root_dm_kg_ha
      if(present(pending_root_n_kg_ha))pending_root_n_kg_ha=self%pending_root_n_kg_ha
      if(present(pending_leaf_dm_kg_ha))pending_leaf_dm_kg_ha=self%pending_leaf_dm_kg_ha
      if(present(pending_leaf_n_kg_ha))pending_leaf_n_kg_ha=self%pending_leaf_n_kg_ha
    end if
  end subroutine

  logical function coupled_consumed_interval(self,t0,t1) result(consumed)
    class(fmr_b111_soil_crop_n_state_t),intent(in)::self
    real(real64),intent(in)::t0,t1
    real(real64)::tol
    consumed=.false.
    if(.not.self%ready().or..not.self%interval_consumed)return
    tol=64.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(t0),abs(t1),abs(self%last_t0),abs(self%last_t1))
    consumed=abs(t0-self%last_t0)<=tol.and.abs(t1-self%last_t1)<=tol
  end function

  subroutine coupled_advance(self,state,t0,t1,outcome)
    class(fmr_b111_soil_crop_n_model_t),intent(inout)::self
    class(transaction_state_t),intent(inout)::state
    real(real64),intent(in)::t0,t1
    type(trial_outcome_t),intent(out)::outcome
    type(soil_n_inventory_parameters_t)::soil_params
    type(soil_n_pool_state_t)::soil_committed,soil_prepared,soil_candidate
    type(b111_crop_n_state_t)::crop_candidate
    type(b111_crop_n_forcing_t)::crop_forcing
    type(b111_soil_n_exchange_forcing_t)::soil_forcing
    logical::available
    integer::status
    real(real64)::soil_uptake_m2,crop_uptake_m2,tol,external_out,pending_internal_n_m2,new_pending_n_m2

    outcome=trial_outcome_t();self%last_receipt=fmr_b111_soil_crop_n_receipt_t()
    self%last_status=FMR_B111_COUPLED_N_INVALID
    if(.not.self%configured.or..not.all(ieee_is_finite([t0,t1])))return
    if(abs((t1-t0)-1.0_real64)>64.0_real64*epsilon(1.0_real64))return

    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      if(.not.state%ready())return
      if(state%consumed_interval(t0,t1))then
        self%last_status=FMR_B111_COUPLED_N_DUPLICATE_INTERVAL;return
      end if
      call state%soil%snapshot(soil_params,soil_committed,available)
      if(.not.available.or.size(self%cfrac_fom)/=size(soil_committed%fom_kg_m3))return
      soil_prepared=soil_committed;pending_internal_n_m2=0.0_real64
      if(state%pending_root_dm_kg_ha>1.0e-8_real64.or.state%pending_leaf_dm_kg_ha>1.0e-8_real64)then
        if(.not.self%residue_return_enabled)then;self%last_status=FMR_B111_COUPLED_N_CROP_FAILED;return;end if
        call apply_pending_residues(soil_params,soil_prepared,state,self%residue_split,self%root_residue_age, &
             self%leaf_residue_age,soil_prepared,pending_internal_n_m2,status)
        if(status/=FMR_B111_COUPLED_N_OK)then;self%last_status=status;return;end if
        tol=4096.0_real64*epsilon(1.0_real64)*max(1.0_real64,pending_internal_n_m2, &
             (state%pending_root_n_kg_ha+state%pending_leaf_n_kg_ha)*1.0e-4_real64)
        if(abs(pending_internal_n_m2-(state%pending_root_n_kg_ha+state%pending_leaf_n_kg_ha)*1.0e-4_real64)>tol)then
          self%last_status=FMR_B111_COUPLED_N_TRANSFER_MISMATCH;return
        end if
        self%last_receipt%pending_residue_consumed_kg_m2=pending_internal_n_m2
      end if

      crop_forcing=self%crop_forcing
      crop_forcing%soil_supply_kg_m2_day=0.0_real64
      call prepare_b111_crop_n_request(state%crop,crop_forcing,self%last_receipt%crop_request)
      if(self%last_receipt%crop_request%status/=B111_CROPN_OK)then
        self%last_status=FMR_B111_COUPLED_N_CROP_FAILED;return
      end if

      soil_forcing=self%soil_forcing
      soil_forcing%crop_n_demand_kg_m2=self%last_receipt%crop_request%soil_demand_kg_ha*1.0e-4_real64
      call evaluate_b111_soil_n_daily_candidate(soil_params,soil_prepared,self%turnover,self%cfrac_fom, &
           self%cfrac_biomass,self%cfrac_humus,self%rate_environment,soil_forcing,soil_candidate, &
           self%last_receipt%soil_process)
      if(self%last_receipt%soil_process%status/=B111_NDAY_OK)then
        self%last_status=FMR_B111_COUPLED_N_SOIL_FAILED;return
      end if

      crop_forcing=self%crop_forcing
      crop_forcing%soil_supply_kg_m2_day=self%last_receipt%soil_process%exchange%nsupply_total_kg_m2_day
      call apply_b111_crop_n_day(state%crop,crop_forcing,crop_candidate,self%last_receipt%crop_process)
      if(self%last_receipt%crop_process%status/=B111_CROPN_OK)then
        self%last_status=FMR_B111_COUPLED_N_CROP_FAILED;return
      end if

      soil_uptake_m2=self%last_receipt%soil_process%exchange%nsupply_total_kg_m2_day
      crop_uptake_m2=self%last_receipt%crop_process%soil_uptake_kg_ha*1.0e-4_real64
      tol=4096.0_real64*epsilon(1.0_real64)*max(1.0_real64,abs(soil_uptake_m2),abs(crop_uptake_m2))
      if(abs(soil_uptake_m2-crop_uptake_m2)>tol)then
        self%last_status=FMR_B111_COUPLED_N_TRANSFER_MISMATCH;return
      end if
      call state%soil%replace_inventory_candidate(soil_candidate,status)
      if(status/=FMR_SOIL_N_OK)then
        self%last_status=FMR_B111_COUPLED_N_SOIL_FAILED;return
      end if
      state%crop=crop_candidate
      state%pending_root_dm_kg_ha=self%crop_forcing%drrt_kg_ha_day*self%crop_forcing%delt_day
      state%pending_root_n_kg_ha=self%crop_forcing%rnfrt*self%crop_forcing%drrt_kg_ha_day*self%crop_forcing%delt_day
      state%pending_leaf_dm_kg_ha=self%fra_deceased_leaf_to_soil*self%crop_forcing%drlv_kg_ha_day*self%crop_forcing%delt_day
      state%pending_leaf_n_kg_ha=self%fra_deceased_leaf_to_soil*self%crop_forcing%rnflv*self%crop_forcing%drlv_kg_ha_day*self%crop_forcing%delt_day
      state%last_t0=t0;state%last_t1=t1;state%interval_consumed=.true.

      self%last_receipt%internal_soil_to_crop_kg_m2=soil_uptake_m2
      self%last_receipt%external_fixation_input_kg_m2=self%last_receipt%crop_process%fixation_kg_ha*1.0e-4_real64
      new_pending_n_m2=(state%pending_root_n_kg_ha+state%pending_leaf_n_kg_ha)*1.0e-4_real64
      self%last_receipt%pending_residue_created_kg_m2=new_pending_n_m2
      self%last_receipt%external_crop_loss_kg_m2=max(0.0_real64,self%last_receipt%crop_process%loss_kg_ha*1.0e-4_real64-new_pending_n_m2)
      external_out=self%last_receipt%soil_process%owner_receipt%external_n_output_kg_m2-soil_uptake_m2+ &
           self%last_receipt%external_crop_loss_kg_m2
      if(external_out<0.0_real64.and.abs(external_out)<=tol)external_out=0.0_real64
      if(external_out<0.0_real64)return

      outcome%solver_ok=.true.
      outcome%mass_in=self%last_receipt%soil_process%owner_receipt%external_n_input_kg_m2+ &
           self%last_receipt%external_fixation_input_kg_m2
      outcome%mass_out=external_out
      outcome%mass_accounting_complete=.true.
      outcome%missing_mass_contribution_mask=TX_MASS_MISSING_NONE
      outcome%temporal_certificate_available=.true.;outcome%temporal_indicator=0.0_real64
      self%last_receipt%status=FMR_B111_COUPLED_N_OK
      self%last_status=FMR_B111_COUPLED_N_OK
    end select
  end subroutine


  subroutine apply_pending_residues(params,committed,state,split,root_age,leaf_age,candidate,internal_n,status)
    type(soil_n_inventory_parameters_t),intent(in)::params
    type(soil_n_pool_state_t),intent(in)::committed
    type(fmr_b111_soil_crop_n_state_t),intent(in)::state
    type(b111_soil_n_split_parameters_t),intent(in)::split
    real(real64),intent(in)::root_age,leaf_age
    type(soil_n_pool_state_t),intent(out)::candidate
    real(real64),intent(out)::internal_n
    integer,intent(out)::status
    type(soil_n_pool_state_t)::current,next
    type(b111_soil_n_material_t)::material
    type(soil_n_transfer_t)::transfer
    type(soil_n_receipt_t)::receipt
    integer::build_status

    current=committed;candidate=committed;internal_n=0.0_real64;status=FMR_B111_COUPLED_N_INVALID
    if(state%pending_root_dm_kg_ha>1.0e-8_real64)then
      material=b111_soil_n_material_t()
      material%application_kg_m2=state%pending_root_dm_kg_ha*1.0e-4_real64
      material%application_age=root_age;material%organic_matter_fraction=1.0_real64
      material%organic_n_fraction=state%pending_root_n_kg_ha/state%pending_root_dm_kg_ha
      call build_b111_residue_transfer(params%depth_m,material,split,transfer,build_status)
      if(build_status/=B111_NADD_OK)return
      call apply_soil_n_transfer(params,current,transfer,next,receipt)
      if(receipt%status/=SOIL_N_OK)return
      internal_n=internal_n+receipt%external_n_input_kg_m2
      current=next
    end if
    if(state%pending_leaf_dm_kg_ha>1.0e-8_real64)then
      material=b111_soil_n_material_t()
      material%application_kg_m2=state%pending_leaf_dm_kg_ha*1.0e-4_real64
      material%application_age=leaf_age;material%organic_matter_fraction=1.0_real64
      material%organic_n_fraction=state%pending_leaf_n_kg_ha/state%pending_leaf_dm_kg_ha
      call build_b111_residue_transfer(params%depth_m,material,split,transfer,build_status)
      if(build_status/=B111_NADD_OK)return
      call apply_soil_n_transfer(params,current,transfer,next,receipt)
      if(receipt%status/=SOIL_N_OK)return
      internal_n=internal_n+receipt%external_n_input_kg_m2
      current=next
    end if
    candidate=current
    status=FMR_B111_COUPLED_N_OK
  end subroutine

  real(real64) function coupled_storage(self,state) result(value)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    type(soil_n_inventory_parameters_t)::params
    type(soil_n_pool_state_t)::inventory
    logical::available
    value=0.0_real64
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      call state%soil%snapshot(params,inventory,available)
      if(available)value=inventory%nitrogen_total(params)+ &
           (state%crop%anlv_kg_ha+state%crop%anst_kg_ha+state%crop%anrt_kg_ha+state%crop%anso_kg_ha+ &
           state%pending_root_n_kg_ha+state%pending_leaf_n_kg_ha)*1.0e-4_real64
    end select
  end function

  real(real64) function coupled_temporal_error(self,full_state,half_state) result(value)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::full_state,half_state
    value=0.0_real64
    if(.not.self%configured.or..not.same_type_as(full_state,half_state))value=huge(0.0_real64)
  end function

  subroutine coupled_storage_accounting_status(self,state,complete,missing_mask)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    class(transaction_state_t),intent(in)::state
    logical,intent(out)::complete
    integer(int64),intent(out)::missing_mask
    complete=.false.;missing_mask=TX_MASS_MISSING_UNSPECIFIED
    if(.not.self%configured)return
    select type(state)
    type is(fmr_b111_soil_crop_n_state_t)
      complete=state%ready()
      if(complete)missing_mask=TX_MASS_MISSING_NONE
    end select
  end subroutine

  logical function coupled_attempt_context_required(self) result(required)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    required=.false.
    if(.not.same_type_as(self,self))required=.true.
  end function

  integer function coupled_last_status(self) result(status)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    status=self%last_status
  end function

  subroutine coupled_snapshot_receipt(self,receipt,available)
    class(fmr_b111_soil_crop_n_model_t),intent(in)::self
    type(fmr_b111_soil_crop_n_receipt_t),intent(out)::receipt
    logical,intent(out)::available
    receipt=self%last_receipt
    available=self%last_status==FMR_B111_COUPLED_N_OK.and.receipt%status==FMR_B111_COUPLED_N_OK
  end subroutine
end module
