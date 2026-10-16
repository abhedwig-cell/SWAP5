program test_hydro_memory_dyn01_forcing_root_composition
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t
  use mod_canonical_contracts, only: canonical_interval_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_b110_dynamic_top_boundary_provider, only: b110_dynamic_top_boundary_request_t, &
       b110_dynamic_top_boundary_result_t, evaluate_b110_dynamic_top_boundary, B110_DYN_TOP_AVAILABLE, &
       B110_DYN_TOP_REGIME_FLUX
  use mod_reference_et_demand_process, only: reference_et_demand_result_t, reference_et_demand_diagnostics_t, &
       reference_et_demand_canopy_view_t, REF_ET_DEMAND_OK
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_forcing_span_t, &
       fmr_reference_et_binding_diagnostics_t, fmr_evaluate_reference_et_demand, FMR_REFERENCE_ET_BINDING_OK
  use mod_ppa_wu03_common_forcing_adapter, only: ppa_wu03_common_forcing_config_t, &
       ppa_wu03_common_forcing_input_t, ppa_wu03_common_forcing_result_t, &
       ppa_wu03_common_forcing_diagnostics_t, materialize_ppa_wu03_common_forcing, &
       PPA_WU03_OK, PPA_WU03_ET_REFERENCE, PPA_WU03_INTERCEPTION_NONE, PPA_WU03_IRRIGATION_NONE
  use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_reference_et_ptra_root_input_binding, only: fmr_ptra_root_input_binding_diagnostics_t
  use mod_fmr_crop_root_uptake_input_adapter, only: fmr_crop_root_uptake_adapter_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_reference_et_root_uptake_composition, only: fmr_reference_et_root_uptake_diagnostics_t, &
       fmr_evaluate_reference_et_root_uptake, FMR_REFERENCE_ET_ROOT_UPTAKE_OK
  implicit none

  real(real64), parameter :: T0=0.0_real64, T1=0.1_real64
  real(real64), parameter :: H_WET=-75.0_real64
  real(real64), parameter :: DROUGHT_P=0.0_real64, DROUGHT_ET_MM=4.0_real64
  real(real64), parameter :: RECOVERY_P=0.5_real64, RECOVERY_ET_MM=3.0_real64
  real(real64), parameter :: TOL=128.0_real64*epsilon(1.0_real64)

  type(b110_default_mvg_parameters_t), target :: hp
  type(b110_default_mvg_provider_t) :: constitutive
  type(soil_water_parameter_set_t) :: geometry
  type(kernel_committed_state_t) :: wet_committed, dry_committed
  type(root_water_uptake_parameters_t) :: root_params
  type(crop_root_uptake_input_t) :: root_input
  type(ppa_wu03_common_forcing_config_t) :: forcing_config
  type(ppa_wu03_common_forcing_input_t) :: drought_input, recovery_input
  type(ppa_wu03_common_forcing_result_t) :: drought_a, recovery, drought_b
  type(ppa_wu03_common_forcing_diagnostics_t) :: drought_diag_a, recovery_diag, drought_diag_b
  type(b110_dynamic_top_boundary_request_t) :: base_top
  type(b110_dynamic_top_boundary_result_t) :: drought_top, recovery_top
  type(reference_et_demand_result_t) :: drought_et, recovery_et
  type(reference_et_demand_diagnostics_t) :: drought_et_process, recovery_et_process
  type(fmr_reference_et_binding_diagnostics_t) :: drought_et_diag, recovery_et_diag
  type(root_water_uptake_flux_result_t) :: wet_flux_a, wet_flux_b, dry_flux, recovery_flux
  type(root_water_uptake_diagnostics_t) :: wet_proc_a, wet_proc_b, dry_proc, recovery_proc
  type(fmr_ptra_root_input_binding_diagnostics_t) :: ptra1,ptra2,ptra3,ptra4
  type(fmr_crop_root_uptake_adapter_diagnostics_t) :: adapter1,adapter2,adapter3,adapter4
  type(fmr_root_uptake_binding_diagnostics_t) :: binding1,binding2,binding3,binding4
  type(fmr_reference_et_root_uptake_diagnostics_t) :: comp1,comp2,comp3,comp4
  real(real64) :: wet_heads(numnod), dry_heads(numnod), wet_theta(numnod), dry_theta(numnod)
  real(real64) :: k(numnod),cap(numnod),dkdh(numnod)
  integer(int64) :: wet_revision_before, dry_revision_before
  logical :: ok

  call initialize_hydraulics()
  wet_heads=H_WET
  dry_heads=H_WET
  call require(numnod>=3,'DYN01 requires at least three nodes')
  dry_heads(1:3)=[-1200.0_real64,-800.0_real64,-400.0_real64]

  call constitutive%evaluate(wet_heads,wet_theta,k,cap,dkdh)
  call initialize_committed(wet_heads,wet_theta,610101_int64,wet_committed)
  call constitutive%evaluate(dry_heads,dry_theta,k,cap,dkdh)
  call initialize_committed(dry_heads,dry_theta,610102_int64,dry_committed)
  wet_revision_before=wet_committed%current_revision()
  dry_revision_before=dry_committed%current_revision()

  call initialize_forcing_config()
  call initialize_normal_input(DROUGHT_P,DROUGHT_ET_MM,drought_input)
  call initialize_normal_input(RECOVERY_P,RECOVERY_ET_MM,recovery_input)
  call initialize_top_request(wet_theta(1),base_top)

  call materialize_ppa_wu03_common_forcing(forcing_config,drought_input,base_top,drought_a,drought_diag_a)
  call materialize_ppa_wu03_common_forcing(forcing_config,recovery_input,base_top,recovery,recovery_diag)
  call materialize_ppa_wu03_common_forcing(forcing_config,drought_input,base_top,drought_b,drought_diag_b)
  call require(drought_diag_a%status==PPA_WU03_OK .and. drought_a%valid,'drought forcing materialization')
  call require(recovery_diag%status==PPA_WU03_OK .and. recovery%valid,'recovery forcing materialization')
  call require(drought_diag_b%status==PPA_WU03_OK .and. drought_b%valid,'drought replay materialization')
  call require(same_bits(drought_a%reference_et_demand%potential_transpiration_cm_per_day, &
       drought_b%reference_et_demand%potential_transpiration_cm_per_day),'forcing A-B-A ptra identity')
  call require(same_bits(drought_a%top_request%precipitation_rate_cm_per_day, &
       drought_b%top_request%precipitation_rate_cm_per_day),'forcing A-B-A precipitation identity')

  call require(close(drought_a%reference_et_demand%potential_transpiration_cm_per_day,0.4_real64), &
       'drought ptra is not 0.4 cm/day')
  call require(close(recovery%reference_et_demand%potential_transpiration_cm_per_day,0.3_real64), &
       'recovery ptra is not 0.3 cm/day')
  call require(close(drought_a%reference_et_demand%potential_soil_evaporation_cm_per_day,0.0_real64), &
       'drought soil evaporation demand nonzero')
  call require(close(recovery%reference_et_demand%potential_soil_evaporation_cm_per_day,0.0_real64), &
       'recovery soil evaporation demand nonzero')

  call evaluate_b110_dynamic_top_boundary(geometry,hp,drought_a%top_request,drought_top)
  call evaluate_b110_dynamic_top_boundary(geometry,hp,recovery%top_request,recovery_top)
  call require(drought_top%status==B110_DYN_TOP_AVAILABLE .and. drought_top%regime==B110_DYN_TOP_REGIME_FLUX, &
       'drought top not pure flux')
  call require(recovery_top%status==B110_DYN_TOP_AVAILABLE .and. recovery_top%regime==B110_DYN_TOP_REGIME_FLUX, &
       'recovery top not pure flux')
  call require(close(drought_top%actual_top_flux_cm_per_day,0.0_real64),'drought top flux not zero')
  call require(close(recovery_top%actual_top_flux_cm_per_day,-0.5_real64),'recovery top flux not -0.5 cm/day')

  call fmr_evaluate_reference_et_demand(drought_input%interval,drought_input%reference_et, &
       forcing_config%reference_et_parameters,drought_input%canopy,drought_et,drought_et_process,drought_et_diag)
  call fmr_evaluate_reference_et_demand(recovery_input%interval,recovery_input%reference_et, &
       forcing_config%reference_et_parameters,recovery_input%canopy,recovery_et,recovery_et_process,recovery_et_diag)
  call require(drought_et_diag%status==FMR_REFERENCE_ET_BINDING_OK .and. drought_et_process%status==REF_ET_DEMAND_OK, &
       'direct drought ET authority')
  call require(recovery_et_diag%status==FMR_REFERENCE_ET_BINDING_OK .and. recovery_et_process%status==REF_ET_DEMAND_OK, &
       'direct recovery ET authority')

  call initialize_root_authority()
  call fmr_evaluate_reference_et_root_uptake(wet_committed,root_params,root_input,drought_et,drought_et_diag, &
       wet_flux_a,wet_proc_a,ptra1,adapter1,binding1,comp1)
  call fmr_evaluate_reference_et_root_uptake(dry_committed,root_params,root_input,drought_et,drought_et_diag, &
       dry_flux,dry_proc,ptra2,adapter2,binding2,comp2)
  call fmr_evaluate_reference_et_root_uptake(wet_committed,root_params,root_input,recovery_et,recovery_et_diag, &
       recovery_flux,recovery_proc,ptra3,adapter3,binding3,comp3)
  call fmr_evaluate_reference_et_root_uptake(wet_committed,root_params,root_input,drought_et,drought_et_diag, &
       wet_flux_b,wet_proc_b,ptra4,adapter4,binding4,comp4)

  call require(comp1%status==FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. comp1%result_produced,'wet drought uptake')
  call require(comp2%status==FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. comp2%result_produced,'dry drought uptake')
  call require(comp3%status==FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. comp3%result_produced,'wet recovery uptake')
  call require(comp4%status==FMR_REFERENCE_ET_ROOT_UPTAKE_OK .and. comp4%result_produced,'wet replay uptake')
  call require(all(ieee_is_finite(wet_flux_a%root_extraction_sink)) .and. all(wet_flux_a%root_extraction_sink>=0.0_real64), &
       'wet sink invalid')
  call require(close(wet_flux_a%actual_uptake_total,0.4_real64),'wet drought actual uptake not potential')
  call require(close(recovery_flux%actual_uptake_total,0.3_real64),'wet recovery actual uptake not potential')
  call require(dry_flux%actual_uptake_total < wet_flux_a%actual_uptake_total-TOL,'dry state did not reduce uptake')
  call require(dry_flux%actual_uptake_total>=0.0_real64,'dry uptake negative')
  call require(all_bits_equal(wet_flux_a%root_extraction_sink,wet_flux_b%root_extraction_sink), &
       'same-state root sink replay drift')
  call require(same_bits(wet_flux_a%actual_uptake_total,wet_flux_b%actual_uptake_total),'same-state uptake replay drift')
  call require(wet_committed%current_revision()==wet_revision_before .and. dry_committed%current_revision()==dry_revision_before, &
       'root composition mutated committed revision')

  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_DROUGHT_PTRA_CM_PER_DAY=',drought_et%potential_transpiration_cm_per_day
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_RECOVERY_PTRA_CM_PER_DAY=',recovery_et%potential_transpiration_cm_per_day
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_DROUGHT_TOP_FLUX_CM_PER_DAY=',drought_top%actual_top_flux_cm_per_day
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_RECOVERY_TOP_FLUX_CM_PER_DAY=',recovery_top%actual_top_flux_cm_per_day
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_WET_DROUGHT_UPTAKE_CM_PER_DAY=',wet_flux_a%actual_uptake_total
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_DRY_DROUGHT_UPTAKE_CM_PER_DAY=',dry_flux%actual_uptake_total
  write(*,'(a,es24.16)') 'HYDRO_MEMORY_DYN01_WET_RECOVERY_UPTAKE_CM_PER_DAY=',recovery_flux%actual_uptake_total
  write(*,'(a)') 'HYDRO_MEMORY_DYN01_REFERENCE_ET_MAPPING=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN01_DYNAMIC_TOP_MAPPING=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN01_ACCEPTED_STATE_DEPENDENT_FEDDES=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN01_STATELESS_REPLAY=PASS'
  write(*,'(a)') 'HYDRO_MEMORY_DYN01_GATE=PASS'

contains

  subroutine initialize_hydraulics()
    real(real64) :: cofgen(24,numnod)
    integer :: i
    cofgen=0.0_real64
    do i=1,numnod
      cofgen(1,i)=0.032_real64; cofgen(2,i)=0.423_real64; cofgen(3,i)=4.75_real64
      cofgen(4,i)=0.0135_real64; cofgen(5,i)=0.365_real64; cofgen(6,i)=1.455_real64
      cofgen(7,i)=1.0_real64-1.0_real64/cofgen(6,i); cofgen(8,i)=cofgen(4,i)
      cofgen(10,i)=cofgen(3,i); cofgen(11,i)=0.999_real64; cofgen(12,i)=0.99_real64*cofgen(3,i)
      cofgen(22,i)=-1.0e6_real64; cofgen(23,i)=1.0e-12_real64
    end do
    call initialize_b110_default_mvg_parameters(hp,cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,T1-T0)
    geometry%parameter_set_id=610001_int64
    geometry%active_nodes=numnod
    allocate(geometry%z(numnod),geometry%dz(numnod),geometry%node_distance(numnod))
    geometry%z=z; geometry%dz=dz; geometry%node_distance=disnod(1:numnod)
  end subroutine initialize_hydraulics

  subroutine initialize_committed(heads,theta,lineage,state)
    real(real64), intent(in) :: heads(:),theta(:)
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: state
    type(fmr_b110_physical_state_t) :: physical
    logical :: local_ok
    physical%active_nodes=numnod
    allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=theta
    physical%ponding_depth=0.0_real64; physical%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(state,lineage,physical,T0,local_ok)
    call require(local_ok,'committed initialization')
  end subroutine initialize_committed

  subroutine initialize_forcing_config()
    forcing_config%et_mode=PPA_WU03_ET_REFERENCE
    forcing_config%interception_mode=PPA_WU03_INTERCEPTION_NONE
    forcing_config%irrigation_mode=PPA_WU03_IRRIGATION_NONE
    forcing_config%reference_et_parameters%pond_evaporation_factor=1.0_real64
  end subroutine initialize_forcing_config

  subroutine initialize_normal_input(p,etmm,input)
    real(real64), intent(in) :: p,etmm
    type(ppa_wu03_common_forcing_input_t), intent(out) :: input
    input%interval%t0=T0; input%interval%t1=T1
    input%forcing_t0=T0; input%forcing_t1=T1
    input%precipitation_rate_cm_per_day=p
    input%surface_irrigation_rate_cm_per_day=0.0_real64
    input%reference_et%t0=T0; input%reference_et%t1=T1
    input%reference_et%reference_et_mm_per_day=etmm
    input%canopy%crop_emerged=.true.
    input%canopy%vegetation_cover_fraction=1.0_real64
    input%canopy%crop_factor=1.0_real64
    input%canopy%co2_transpiration_factor=1.0_real64
  end subroutine initialize_normal_input

  subroutine initialize_top_request(theta_top,request)
    real(real64), intent(in) :: theta_top
    type(b110_dynamic_top_boundary_request_t), intent(out) :: request
    request=b110_dynamic_top_boundary_request_t()
    request%conductivity_mean_method=1
    request%pressure_head_top_cm=H_WET
    request%water_content_top=theta_top
    request%candidate_ponding_depth_cm=0.0_real64
    request%previous_ponding_depth_cm=0.0_real64
    request%step_duration_day=T1-T0
    request%ponding_max_cm=2.0_real64
    request%runoff_resistance_day=1.0_real64
    request%runoff_exponent=1.0_real64
  end subroutine initialize_top_request

  subroutine initialize_root_authority()
    root_params%active_nodes=numnod
    root_params%hlim3l=-800.0_real64; root_params%hlim3h=-400.0_real64
    root_params%hlim4=-16000.0_real64; root_params%adcrl=0.10_real64; root_params%adcrh=0.50_real64
    root_input=crop_root_uptake_input_t()
    root_input%crop_emerged=.true.; root_input%potential_transpiration=999.0_real64
    root_input%rooted_nodes=3
    allocate(root_input%cumulative_root_fraction(4))
    root_input%cumulative_root_fraction=[0.0_real64,0.10_real64,0.55_real64,1.0_real64]
  end subroutine initialize_root_authority

  pure logical function close(a,b) result(ok_close)
    real(real64), intent(in) :: a,b
    real(real64) :: scale
    scale=max(1.0_real64,abs(a),abs(b))
    ok_close=abs(a-b)<=TOL*scale
  end function close

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  logical function all_bits_equal(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=size(a)==size(b)
    if(.not.equal)return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))then; equal=.false.; return; end if
    end do
  end function all_bits_equal

  subroutine require(condition,message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if(.not.condition)then
      write(*,'(a,1x,a)') 'HYDRO_MEMORY_DYN01_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_hydro_memory_dyn01_forcing_root_composition
