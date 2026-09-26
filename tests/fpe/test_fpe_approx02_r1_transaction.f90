program test_fpe_approx02_r1_transaction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_canonical_contracts, only: canonical_numerical_config_t, CANONICAL_STATUS_COMPLETED
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  integer, parameter :: nsteps=8
  real(real64), parameter :: duration=1.0e-3_real64
  real(real64), parameter :: exact_tol=1.0e-12_real64
  real(real64), parameter :: r1_tol=1.0e-2_real64
  real(real64), parameter :: transaction_mass_tol=1.0e-12_real64
  real(real64), parameter :: forcing_pattern(nsteps)=[0.0_real64,1.0_real64,0.0_real64,-2.0_real64, &
       0.0_real64,1.0_real64,0.0_real64,-1.0_real64]
  integer(int64), parameter :: lineage=630501_int64

  type trajectory_summary_t
    logical :: completed=.false.
    integer :: completed_steps=0
    integer :: failed_step=0
    integer :: failed_status=0
    integer :: commits=0
    integer :: accepted_substeps=0
    integer :: retries=0
    integer :: mass_rejections=0
    integer :: solver_rejections=0
    integer :: nonlinear=0
    integer :: jacobian=0
    integer :: linear=0
    integer :: backtrack=0
    real(real64) :: seconds=0.0_real64
    real(real64) :: cumulative_bottom=0.0_real64
    real(real64) :: cumulative_in=0.0_real64
    real(real64) :: cumulative_out=0.0_real64
    real(real64) :: max_abs_mass_residual=0.0_real64
    real(real64) :: final_storage=0.0_real64
    real(real64) :: pressure_head(numnod)=0.0_real64
    real(real64) :: water_content(numnod)=0.0_real64
  end type trajectory_summary_t

  type(fmr_b110_physical_parameters_t) :: exact_parameters,r1_parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(canonical_numerical_config_t) :: config
  type(trajectory_summary_t) :: exact,r1
  real(real64) :: h0,k0
  character(len=8) :: material,regime
  character(len=64) :: arg

  if(command_argument_count()/=3) error stop 'usage: MATERIAL REGIME H0_CM'
  call get_command_argument(1,material)
  call get_command_argument(2,regime)
  call get_command_argument(3,arg); read(arg,*) h0

  call initialize_parameters(exact_parameters,trim(material),exact_tol)
  call initialize_parameters(r1_parameters,trim(material),r1_tol)
  call determine_initial_conductivity(exact_parameters,h0,k0)
  call initialize_forcing(forcing,h0,0.0_real64)
  call initialize_column_and_template(column,template)
  call initialize_config(config)

  call run_trajectory('exact',exact_parameters,forcing,column,template,config,h0,k0,exact)
  call run_trajectory('R1',r1_parameters,forcing,column,template,config,h0,k0,r1)

  write(*,'(*(g0))') 'APPROX02_R1_TRANSACTION|MATERIAL=',trim(material),'|REGIME=',trim(regime), &
       '|EXACT_COMPLETED=',exact%completed,'|R1_COMPLETED=',r1%completed, &
       '|EXACT_STEPS=',exact%completed_steps,'|R1_STEPS=',r1%completed_steps, &
       '|R1_FAILED_STEP=',r1%failed_step,'|R1_FAILED_STATUS=',r1%failed_status, &
       '|EXACT_SECONDS=',exact%seconds,'|R1_SECONDS=',r1%seconds, &
       '|RUNTIME_RATIO=',safe_ratio(r1%seconds,exact%seconds), &
       '|SPEEDUP_PERCENT=',100.0_real64*(1.0_real64-safe_ratio(r1%seconds,exact%seconds)), &
       '|EXACT_NONLINEAR=',exact%nonlinear,'|R1_NONLINEAR=',r1%nonlinear, &
       '|EXACT_BACKTRACK=',exact%backtrack,'|R1_BACKTRACK=',r1%backtrack, &
       '|EXACT_ACCEPTED_SUBSTEPS=',exact%accepted_substeps,'|R1_ACCEPTED_SUBSTEPS=',r1%accepted_substeps, &
       '|EXACT_RETRIES=',exact%retries,'|R1_RETRIES=',r1%retries, &
       '|EXACT_MASS_REJECTIONS=',exact%mass_rejections,'|R1_MASS_REJECTIONS=',r1%mass_rejections, &
       '|EXACT_MAX_MASS_RESIDUAL=',exact%max_abs_mass_residual,'|R1_MAX_MASS_RESIDUAL=',r1%max_abs_mass_residual, &
       '|EXACT_CUM_BOTTOM=',exact%cumulative_bottom,'|R1_CUM_BOTTOM=',r1%cumulative_bottom

  if(exact%completed .and. r1%completed)then
    write(*,'(*(g0))') 'APPROX02_R1_TRANSACTION_ERROR|MATERIAL=',trim(material),'|REGIME=',trim(regime), &
         '|MAX_HEAD_ABS_CM=',maxval(abs(r1%pressure_head-exact%pressure_head)), &
         '|MAX_HEAD_REL=',maxval(abs(r1%pressure_head-exact%pressure_head)/max(abs(exact%pressure_head),1.0e-30_real64)), &
         '|MAX_THETA_ABS=',maxval(abs(r1%water_content-exact%water_content)), &
         '|MAX_THETA_REL=',maxval(abs(r1%water_content-exact%water_content)/max(abs(exact%water_content),1.0e-30_real64)), &
         '|CUM_BOTTOM_ABS=',abs(r1%cumulative_bottom-exact%cumulative_bottom), &
         '|CUM_BOTTOM_REL=',abs(r1%cumulative_bottom-exact%cumulative_bottom)/max(abs(exact%cumulative_bottom),1.0e-30_real64), &
         '|FINAL_STORAGE_ABS=',abs(r1%final_storage-exact%final_storage), &
         '|FINAL_STORAGE_REL=',abs(r1%final_storage-exact%final_storage)/max(abs(exact%final_storage),1.0e-30_real64)
  end if

  if(.not.exact%completed) error stop 'exact transaction trajectory failed'
  print '(A)','FPE_APPROX02_R1_TRANSACTION=PASS'

contains

  subroutine run_trajectory(label,parameters,base_forcing,column,template,config,h0,k0,summary)
    character(len=*),intent(in)::label
    type(fmr_b110_physical_parameters_t),intent(in)::parameters
    type(fmr_b110_physical_forcing_t),intent(in)::base_forcing
    type(fmr_logical_column_t),intent(in)::column
    type(fmr_template_t),intent(in)::template
    type(canonical_numerical_config_t),intent(in)::config
    real(real64),intent(in)::h0,k0
    type(trajectory_summary_t),intent(out)::summary

    type(fmr_b110_physical_forcing_t) :: local_forcing
    type(kernel_committed_state_t) :: committed
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target::top
    class(transaction_state_t),allocatable::snapshot
    real(real64)::t0,t1,start_time,end_time
    integer::step,status
    logical::ok,did_commit,available

    summary=trajectory_summary_t()
    call initialize_committed(committed,parameters,h0,ok)
    if(.not.ok) return
    call backend%initialize(top)
    local_forcing=base_forcing

    call cpu_time(start_time)
    do step=1,nsteps
      t0=real(step-1,real64)*duration
      t1=real(step,real64)*duration
      local_forcing%top_flux=forcing_pattern(step)*k0
      local_forcing%bottom_head=h0

      call fmr_capture_checkpoint(committed,checkpoint,ok)
      if(.not.ok)then
        summary%failed_step=step
        summary%failed_status=-100
        exit
      end if
      diagnostics=kernel_diagnostics_t()
      call backend%run_trial(column,template,parameters,committed,local_forcing,config,t0,t1,checkpoint, &
           result,candidate,diagnostics)

      summary%accepted_substeps=summary%accepted_substeps+diagnostics%accepted_substeps
      summary%retries=summary%retries+diagnostics%retries
      summary%mass_rejections=summary%mass_rejections+diagnostics%mass_rejections
      summary%solver_rejections=summary%solver_rejections+diagnostics%solver_rejections
      summary%nonlinear=summary%nonlinear+diagnostics%nonlinear_iterations
      summary%jacobian=summary%jacobian+diagnostics%jacobian_builds
      summary%linear=summary%linear+diagnostics%linear_solves
      summary%backtrack=summary%backtrack+diagnostics%backtracking_attempts
      summary%max_abs_mass_residual=max(summary%max_abs_mass_residual,abs(diagnostics%max_abs_step_mass_residual))

      if(result%status/=CANONICAL_STATUS_COMPLETED .or. .not.result%completed .or. .not.candidate%ready())then
        summary%failed_step=step
        summary%failed_status=result%status
        exit
      end if
      if(.not.result%mass%complete)then
        summary%failed_step=step
        summary%failed_status=-101
        exit
      end if
      summary%cumulative_bottom=summary%cumulative_bottom+result%bottom_outward_exchange_native
      summary%cumulative_in=summary%cumulative_in+result%mass%total_in
      summary%cumulative_out=summary%cumulative_out+result%mass%total_out
      summary%max_abs_mass_residual=max(summary%max_abs_mass_residual,abs(result%mass%residual))
      summary%final_storage=result%mass%storage_end

      call backend%commit_trial_candidate(committed,candidate,diagnostics,did_commit,status)
      if(.not.did_commit)then
        summary%failed_step=step
        summary%failed_status=status
        exit
      end if
      summary%commits=summary%commits+1
      summary%completed_steps=step
    end do
    call cpu_time(end_time)
    summary%seconds=end_time-start_time

    if(summary%completed_steps==nsteps)then
      summary%completed=.true.
      call committed%snapshot(snapshot,available)
      if(.not.available .or. .not.allocated(snapshot))then
        summary%completed=.false.
        summary%failed_status=-102
        return
      end if
      select type(state=>snapshot)
      type is(fmr_b110_physical_state_t)
        if(.not.allocated(state%pressure_head) .or. .not.allocated(state%water_content))then
          summary%completed=.false.
          summary%failed_status=-103
          return
        end if
        summary%pressure_head=state%pressure_head
        summary%water_content=state%water_content
      class default
        summary%completed=.false.
        summary%failed_status=-104
      end select
    end if

    write(*,'(*(g0))') 'APPROX02_R1_ARM|LABEL=',trim(label),'|COMPLETED=',summary%completed, &
         '|STEPS=',summary%completed_steps,'|FAILED_STEP=',summary%failed_step,'|FAILED_STATUS=',summary%failed_status, &
         '|SECONDS=',summary%seconds,'|NONLINEAR=',summary%nonlinear,'|BACKTRACK=',summary%backtrack, &
         '|ACCEPTED_SUBSTEPS=',summary%accepted_substeps,'|RETRIES=',summary%retries, &
         '|MASS_REJECTIONS=',summary%mass_rejections,'|MAX_MASS_RESIDUAL=',summary%max_abs_mass_residual
  end subroutine run_trajectory

  subroutine initialize_parameters(p,name,tol)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    character(len=*),intent(in)::name
    real(real64),intent(in)::tol
    real(real64)::tr,ts,alpha,nvg,ksat,lambda
    integer::k
    call material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    p%parameter_set_id=630501_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr; p%cofgen(2,k)=ts; p%cofgen(3,k)=ksat
      p%cofgen(4,k)=alpha; p%cofgen(5,k)=lambda; p%cofgen(6,k)=nvg
      p%cofgen(7,k)=1.0_real64-1.0_real64/nvg; p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=ksat; p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ksat; p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5
    p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16
    p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=tol
    p%total_balance_tolerance=tol
    p%head_abs_tolerance=tol
    p%head_rel_tolerance=tol
    p%ponding_tolerance=exact_tol
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%direct_retention_active=.false.
    p%ksatexm_extension_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    p%soil_temperature_active=.false.; p%black_evaporation_active=.false.; p%boesten_evaporation_active=.false.
    p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f,h0,top_flux)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    real(real64),intent(in)::h0,top_flux
    f%top_flux=top_flux
    f%top_head=h0
    f%bottom_flux=0.0_real64
    f%bottom_head=h0
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_column_and_template(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    t%template_id=630501_int64; t%physics_topology_id=630502_int64; t%vertical_layout_id=630503_int64
    t%state_layout_id=630504_int64; t%solver_interface_id=630505_int64; t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=lineage; c%template_id=t%template_id; c%parameter_ref=1_int64; c%state_handle=1_int64
    c%forcing_handle=1_int64; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_and_template

  subroutine initialize_config(c)
    type(canonical_numerical_config_t),intent(out)::c
    c%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    c%transaction%temporal_tolerance=1.0e-6_real64
    c%transaction%mass_tolerance=transaction_mass_tol
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=64
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.false.
    c%model_temporal_indicator_budget=0.0_real64
    c%accepted_trajectory_direction%requested=.false.
  end subroutine initialize_config

  subroutine initialize_committed(committed,p,h0,ok)
    type(kernel_committed_state_t),intent(out)::committed
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::h0
    logical,intent(out)::ok
    type(fmr_b110_physical_state_t)::state
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
    call fmr_new_b110_committed_state(committed,lineage,state,0.0_real64,ok)
  end subroutine initialize_committed

  subroutine determine_initial_conductivity(p,h0,k0)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::h0
    real(real64),intent(out)::k0
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,duration)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
  end subroutine determine_initial_conductivity

  subroutine material_parameters(name,tr,ts,alpha,nvg,ksat,lambda)
    character(len=*),intent(in)::name
    real(real64),intent(out)::tr,ts,alpha,nvg,ksat,lambda
    select case(trim(name))
    case('B01')
      tr=0.02_real64; ts=0.427494_real64; alpha=0.021659_real64; nvg=1.734737_real64
      ksat=31.225016_real64; lambda=0.98087_real64
    case('B12')
      tr=0.01_real64; ts=0.529749_real64; alpha=0.016562_real64; nvg=1.090671_real64
      ksat=2.245895_real64; lambda=-4.493581_real64
    case('O05')
      tr=0.01_real64; ts=0.336701_real64; alpha=0.030304_real64; nvg=2.887502_real64
      ksat=17.418504_real64; lambda=0.0736_real64
    case('O14')
      tr=0.01_real64; ts=0.393878_real64; alpha=0.003288_real64; nvg=1.616573_real64
      ksat=2.495984_real64; lambda=0.514012_real64
    case default
      error stop 'unknown material'
    end select
  end subroutine material_parameters

  pure real(real64) function safe_ratio(a,b) result(v)
    real(real64),intent(in)::a,b
    if(abs(b)>tiny(1.0_real64))then
      v=a/b
    else
      v=huge(1.0_real64)
    end if
  end function safe_ratio

end program test_fpe_approx02_r1_transaction
