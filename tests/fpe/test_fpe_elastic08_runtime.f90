program test_fpe_elastic08_runtime
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_accepted_step_direction_contract, only: SW_STEP_CONTROL_BOTTOM_FLUX
  use MOD_grid, only: numnod, z, dz, disnod
  implicit none

  real(real64), parameter :: h0=2.0_real64
  real(real64), parameter :: duration=0.02_real64
  real(real64), parameter :: mass_tolerance=1.0e-12_real64
  integer(int64), parameter :: column_id=880088_int64

  type(fmr_b110_physical_parameters_t) :: materialized, direct
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: committed_a, committed_b
  type(kernel_checkpoint_t) :: checkpoint_a, checkpoint_b
  type(kernel_result_t) :: result_a, result_b
  type(kernel_candidate_state_t) :: candidate_a, candidate_b
  type(kernel_diagnostics_t) :: diagnostics_a, diagnostics_b
  type(fmr_serialized_reference_backend_t) :: backend_a, backend_b
  type(fixed_flux_top_boundary_provider_t), target :: top
  class(transaction_state_t), allocatable :: snap_a, snap_b
  real(real64) :: k0,qeq
  logical :: ok,available_a,available_b

  call initialize_parameters(materialized)
  direct=materialized

  call prepare_fmr_b110_default_mvg(materialized,ok)
  call require(ok,'materialized preparation')

  call initialize_b110_default_mvg_parameters(direct%prepared_default_mvg,direct%cofgen, &
       enable_elastic_storage=.true.,specific_elastic_storage_input=direct%cofgen(24,:))
  direct%prepared_default_mvg_available=.true.

  call require(materialized%prepared_default_mvg%elastic_storage_active,'materialized ELAS active')
  call require(direct%prepared_default_mvg%elastic_storage_active,'direct ELAS active')
  call require(all(materialized%prepared_default_mvg%specific_elastic_storage == &
       direct%prepared_default_mvg%specific_elastic_storage),'prepared ELAS identity')

  call determine_initial_conductivity(direct,k0)
  qeq=-k0
  call initialize_forcing(forcing,qeq)
  call initialize_column_and_template(column,template)
  call initialize_config(config)

  call initialize_committed(committed_a,materialized,ok)
  call require(ok,'materialized committed state')
  call initialize_committed(committed_b,direct,ok)
  call require(ok,'direct committed state')
  call fmr_capture_checkpoint(committed_a,checkpoint_a,ok); call require(ok,'checkpoint a')
  call fmr_capture_checkpoint(committed_b,checkpoint_b,ok); call require(ok,'checkpoint b')

  call backend_a%initialize(top)
  call backend_b%initialize(top)

  call backend_a%run_trial(column,template,materialized,committed_a,forcing,config, &
       0.0_real64,duration,checkpoint_a,result_a,candidate_a,diagnostics_a)
  call backend_b%run_trial(column,template,direct,committed_b,forcing,config, &
       0.0_real64,duration,checkpoint_b,result_b,candidate_b,diagnostics_b)

  call require(result_a%status==CANONICAL_STATUS_COMPLETED .and. result_a%completed,'materialized completed')
  call require(result_b%status==CANONICAL_STATUS_COMPLETED .and. result_b%completed,'direct completed')
  call require(candidate_a%ready().and.candidate_b%ready(),'candidates ready')

  call require(diagnostics_a%retries==diagnostics_b%retries,'retry identity')
  call require(diagnostics_a%nonlinear_iterations==diagnostics_b%nonlinear_iterations,'nonlinear identity')
  call require(diagnostics_a%internal_retries==diagnostics_b%internal_retries,'internal retry identity')
  call require(diagnostics_a%linear_solves==diagnostics_b%linear_solves,'linear solve identity')
  call require(diagnostics_a%backtracking_attempts==diagnostics_b%backtracking_attempts,'backtracking identity')

  call require(result_a%mass%complete.and.result_b%mass%complete,'mass complete')
  call require(same_bits(result_a%mass%storage_start,result_b%mass%storage_start),'storage start identity')
  call require(same_bits(result_a%mass%storage_end,result_b%mass%storage_end),'storage end identity')
  call require(same_bits(result_a%mass%total_in,result_b%mass%total_in),'mass in identity')
  call require(same_bits(result_a%mass%total_out,result_b%mass%total_out),'mass out identity')
  call require(same_bits(result_a%mass%residual,result_b%mass%residual),'mass residual identity')

  call candidate_a%snapshot(snap_a,available_a)
  call candidate_b%snapshot(snap_b,available_b)
  call require(available_a.and.available_b,'candidate snapshots')
  call require_state_identity(snap_a,snap_b)

  write(*,'(A)')'F_PE_ELASTIC08_R3_RUNTIME_IDENTITY=PASS'
  write(*,'(A,I0)')'F_PE_ELASTIC08_R3_NL=',diagnostics_a%nonlinear_iterations
  write(*,'(A,I0)')'F_PE_ELASTIC08_R3_BACK=',diagnostics_a%backtracking_attempts

contains

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    real(real64),parameter :: tr=0.05_real64,ts=0.45_real64,alpha=0.02_real64,nvg=1.6_real64
    real(real64),parameter :: ksat=10.0_real64,lambda=0.5_real64
    p%parameter_set_id=880088_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ksat;p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lambda;p%cofgen(6,k)=nvg;p%cofgen(7,k)=1.0_real64-1.0_real64/nvg
      p%cofgen(8,k)=alpha;p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ksat
      p%cofgen(11,k)=0.999_real64;p%cofgen(12,k)=0.99_real64*ksat
      p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
      p%cofgen(24,k)=1.0e-6_real64
    end do
    p%bottom_mode=SW_STEP_CONTROL_BOTTOM_FLUX
    p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=mass_tolerance
    p%total_balance_tolerance=mass_tolerance
    p%head_abs_tolerance=mass_tolerance
    p%head_rel_tolerance=mass_tolerance
    p%ponding_tolerance=mass_tolerance
    p%elasticity_active=.true.
  end subroutine

  subroutine determine_initial_conductivity(p,k0)
    type(fmr_b110_physical_parameters_t),intent(in),target::p
    real(real64),intent(out)::k0
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,duration)
    heads=h0
    call provider%evaluate(heads,water,cond,cap,dk)
    k0=cond(1)
  end subroutine

  subroutine initialize_forcing(f,q)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::q
    f%top_flux=q;f%top_head=h0;f%bottom_flux=q;f%bottom_head=-999999.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine

  subroutine initialize_column_and_template(col,temp)
    type(fmr_logical_column_t),intent(out)::col
    type(fmr_template_t),intent(out)::temp
    temp%template_id=880001_int64;temp%physics_topology_id=880002_int64;temp%vertical_layout_id=880003_int64
    temp%state_layout_id=880004_int64;temp%solver_interface_id=880005_int64;temp%optional_state_layout_id=0_int64
    temp%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    temp%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=temp%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine initialize_config(cfg)
    type(canonical_numerical_config_t),intent(out)::cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    cfg%transaction%temporal_tolerance=1.0e-6_real64
    cfg%transaction%mass_tolerance=mass_tolerance
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=8
    cfg%max_committed_substeps=32
    cfg%progress_tolerance=0.0_real64
  end subroutine

  subroutine initialize_committed(committed,p,initialized)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in),target::p
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),cond(numnod),cap(numnod),dk(numnod)
    call bind_b110_default_mvg_provider(provider,p%prepared_default_mvg,duration)
    heads=h0;call provider%evaluate(heads,water,cond,cap,dk)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,column_id,state,0.0_real64,initialized)
  end subroutine

  subroutine require_state_identity(a,b)
    class(transaction_state_t),intent(in)::a,b
    select type(x=>a)
    type is(fmr_b110_physical_state_t)
      select type(y=>b)
      type is(fmr_b110_physical_state_t)
        call require(x%active_nodes==y%active_nodes,'state node count')
        call require(same_vector_bits(x%pressure_head,y%pressure_head),'pressure identity')
        call require(same_vector_bits(x%water_content,y%water_content),'water identity')
        call require(same_bits(x%ponding_depth,y%ponding_depth),'pond identity')
        call require(same_bits(x%groundwater_level,y%groundwater_level),'gwl identity')
      class default
        call require(.false.,'direct state type')
      end select
    class default
      call require(.false.,'materialized state type')
    end select
  end subroutine

  pure logical function same_bits(a,b)
    real(real64),intent(in)::a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function

  pure logical function same_vector_bits(a,b)
    real(real64),intent(in)::a(:),b(:)
    integer::i
    same_vector_bits=.false.
    if(size(a)/=size(b))return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i)))return
    end do
    same_vector_bits=.true.
  end function

  subroutine require(ok,msg)
    logical,intent(in)::ok
    character(len=*),intent(in)::msg
    if(.not.ok)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC08_RUNTIME_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine
end program test_fpe_elastic08_runtime
