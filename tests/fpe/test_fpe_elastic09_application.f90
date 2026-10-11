program test_fpe_elastic09_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, &
       fmr_column_diagnostics_t, fmr_aggregate_diagnostics_t, &
       FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t, &
       fmr_new_b110_committed_state, prepare_fmr_b110_default_mvg
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_PROFILE_NOT_ADMITTED
  use mod_b110_default_mvg_provider, only: b110_default_mvg_provider_t, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: T0=9200.0_real64, T1=9200.02_real64
  real(real64), parameter :: H0=2.0_real64, MASS_TOL=1.0e-12_real64
  integer(int64), parameter :: COLUMN_ID=990091_int64

  type(fmr_production_application_config_t) :: cfg, bad
  type(fmr_production_application_bootstrap_t) :: app, bad_app
  type(fmr_serialized_column_result_t), allocatable :: app_results(:), direct_results(:)
  type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate
  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: params(1)
  type(fmr_b110_physical_forcing_t) :: forcing(1)
  type(kernel_committed_state_t) :: committed(1)
  type(fixed_flux_top_boundary_provider_t), target :: top
  integer :: status, dispatch, k
  logical :: ok

  call initialize_config(cfg)

  ! A1 + A3: admitted application bootstrap with active, heterogeneous row-24 ELAS.
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK .and. app%ready(),'A1 active ELAS bootstrap')
  call app%run_standalone(T0,T1,app_results,status)
  call require(status==FMR_APP_BOOT_OK,'A1 application run')
  call require(allocated(app_results).and.size(app_results)==1,'A1 result shape')
  call require(app_results(1)%completed.and.app_results(1)%committed,'A1 committed')
  call require(abs(app_results(1)%mass%residual)<=MASS_TOL,'A1 mass closure')

  ! A5 direct serialized authority from the same typed configuration.
  templates(1)=cfg%tiles(1)%template
  columns(1)%column_id=cfg%tiles(1)%tile_id
  columns(1)%template_id=templates(1)%template_id
  columns(1)%parameter_ref=1_int64
  columns(1)%state_handle=1_int64
  columns(1)%forcing_handle=1_int64
  columns(1)%execution_class=cfg%tiles(1)%execution_class
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  params(1)=cfg%tiles(1)%parameters
  call prepare_fmr_b110_default_mvg(params(1),ok)
  call require(ok.and.params(1)%prepared_default_mvg_available,'A5 direct prepare')
  call require(params(1)%prepared_default_mvg%elastic_storage_active,'A5 direct ELAS active')
  call require(all(params(1)%prepared_default_mvg%specific_elastic_storage==params(1)%cofgen(24,:)), &
       'A3 heterogeneous row24 survives preparation')
  forcing(1)=cfg%tiles(1)%base_forcing
  call fmr_new_b110_committed_state(committed(1),COLUMN_ID,cfg%tiles(1)%initial_state,T0,ok)
  call require(ok,'A5 direct committed state')
  call fmr_run_serialized_physical_multiswap(columns,templates,params,forcing,committed,cfg%numerical,top,T0,T1,1, &
       direct_results,diagnostics,aggregate,dispatch,materialize_worker_assignments=.false., &
       materialize_summary_diagnostics=.false.,materialize_diagnostic_metadata=.false., &
       materialize_column_diagnostics=.false.,trusted_prepared_parameters=.true.)
  call require(dispatch==FMR_SERIAL_DISPATCH_OK,'A5 direct dispatch')
  call require(allocated(direct_results).and.size(direct_results)==1,'A5 direct result shape')
  call require(direct_results(1)%completed.and.direct_results(1)%committed,'A5 direct committed')
  call require_result_identity(app_results(1),direct_results(1))

  call app%close(status)
  call require(status==FMR_APP_BOOT_OK.and..not.app%ready(),'A1 clean close')
  write(*,'(A)')'F_PE_ELASTIC09_A1_BOOTSTRAP=PASS'
  write(*,'(A)')'F_PE_ELASTIC09_A3_HETEROGENEOUS=PASS'
  write(*,'(A)')'F_PE_ELASTIC09_A5_DYNAMIC_IDENTITY=PASS'

  ! A4 fail-closed combinations and invalid row 24.
  bad=cfg; bad%tiles(1)%parameters%ksatexm_extension_active=.true.
  call expect_rejected(bad,'ksatexm')
  bad=cfg; bad%tiles(1)%parameters%direct_retention_active=.true.
  call expect_rejected(bad,'direct-retention')
  bad=cfg; bad%tiles(1)%parameters%tabulated_hydraulics_active=.true.
  call expect_rejected(bad,'tabulated')
  bad=cfg; bad%tiles(1)%parameters%hysteresis_active=.true.
  call expect_rejected(bad,'hysteresis')
  bad=cfg; bad%tiles(1)%parameters%cofgen(24,1)=-1.0e-6_real64
  call expect_rejected(bad,'negative')
  bad=cfg; bad%tiles(1)%parameters%cofgen(24,1)=ieee_value(0.0_real64,ieee_quiet_nan)
  call expect_rejected(bad,'nan')
  write(*,'(A)')'F_PE_ELASTIC09_A4_FAIL_CLOSED=PASS'

contains

  subroutine initialize_config(value)
    type(fmr_production_application_config_t), intent(out) :: value
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), cond(numnod), cap(numnod), dk(numnod)
    real(real64) :: qeq

    value%initial_time=T0
    value%numerical%transaction%temporal_tolerance=0.0_real64
    value%numerical%transaction%mass_tolerance=MASS_TOL
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=2
    value%numerical%max_committed_substeps=8
    value%numerical%progress_tolerance=0.0_real64

    allocate(value%tiles(1))
    value%tiles(1)%tile_id=COLUMN_ID
    value%tiles(1)%template%template_id=990001_int64
    value%tiles(1)%template%physics_topology_id=990002_int64
    value%tiles(1)%template%vertical_layout_id=990003_int64
    value%tiles(1)%template%state_layout_id=990004_int64
    value%tiles(1)%template%solver_interface_id=990005_int64
    value%tiles(1)%template%optional_state_layout_id=0_int64
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

    call initialize_parameters(value%tiles(1)%parameters)
    call prepare_fmr_b110_default_mvg(value%tiles(1)%parameters,ok)
    call require(ok,'fixture prepare')
    call bind_b110_default_mvg_provider(provider,value%tiles(1)%parameters%prepared_default_mvg,T1-T0)
    heads=H0
    call provider%evaluate(heads,water,cond,cap,dk)
    qeq=-cond(1)

    value%tiles(1)%initial_state%active_nodes=numnod
    allocate(value%tiles(1)%initial_state%pressure_head(numnod),value%tiles(1)%initial_state%water_content(numnod))
    value%tiles(1)%initial_state%pressure_head=heads
    value%tiles(1)%initial_state%water_content=water
    value%tiles(1)%initial_state%ponding_depth=0.0_real64
    value%tiles(1)%initial_state%groundwater_level=-2.0_real64

    value%tiles(1)%base_forcing%top_flux=qeq
    value%tiles(1)%base_forcing%top_head=H0
    value%tiles(1)%base_forcing%bottom_flux=qeq
    value%tiles(1)%base_forcing%bottom_head=-999999.0_real64
    allocate(value%tiles(1)%base_forcing%drainage_flux_by_level(1,numnod), &
         value%tiles(1)%base_forcing%subsurface_irrigation_source(numnod), &
         value%tiles(1)%base_forcing%root_extraction_sink(numnod))
    value%tiles(1)%base_forcing%drainage_flux_by_level=0.0_real64
    value%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
    value%tiles(1)%base_forcing%root_extraction_sink=0.0_real64
  end subroutine

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer :: i
    p%parameter_set_id=990090_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do i=1,numnod
      p%cofgen(1,i)=0.05_real64
      p%cofgen(2,i)=0.45_real64
      p%cofgen(3,i)=10.0_real64
      p%cofgen(4,i)=0.02_real64
      p%cofgen(5,i)=0.5_real64
      p%cofgen(6,i)=1.6_real64
      p%cofgen(7,i)=1.0_real64-1.0_real64/p%cofgen(6,i)
      p%cofgen(8,i)=p%cofgen(4,i)
      p%cofgen(9,i)=0.0_real64
      p%cofgen(10,i)=p%cofgen(3,i)
      p%cofgen(11,i)=0.999_real64
      p%cofgen(12,i)=0.99_real64*p%cofgen(3,i)
      p%cofgen(22,i)=-1.0e6_real64
      p%cofgen(23,i)=1.0e-12_real64
      p%cofgen(24,i)=2.0e-7_real64+real(i,real64)*1.0e-7_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8
    p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=MASS_TOL
    p%total_balance_tolerance=MASS_TOL
    p%head_abs_tolerance=MASS_TOL
    p%head_rel_tolerance=MASS_TOL
    p%ponding_tolerance=MASS_TOL
    p%elasticity_active=.true.
  end subroutine

  subroutine expect_rejected(value,label)
    type(fmr_production_application_config_t), intent(in) :: value
    character(len=*), intent(in) :: label
    type(fmr_production_application_bootstrap_t) :: local_app
    integer :: local_status
    call local_app%initialize(value,local_status)
    call require(local_status==FMR_APP_BOOT_PROFILE_NOT_ADMITTED.and..not.local_app%ready(), &
         'A4 '//trim(label))
  end subroutine

  subroutine require_result_identity(a,b)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    call require(a%admitted.eqv.b%admitted,'A5 admitted')
    call require(a%completed.eqv.b%completed,'A5 completed')
    call require(a%committed.eqv.b%committed,'A5 committed')
    call require(a%kernel_status==b%kernel_status,'A5 kernel status')
    call require(a%accepted_substeps==b%accepted_substeps,'A5 substeps')
    call require(a%solver_iterations==b%solver_iterations,'A5 solver iterations')
    call require(a%solver_nonlinear_iterations==b%solver_nonlinear_iterations,'A5 nonlinear')
    call require(a%solver_internal_retries==b%solver_internal_retries,'A5 internal retries')
    call require(a%solver_headcalc_calls==b%solver_headcalc_calls,'A5 headcalc')
    call require(a%solver_jacobian_builds==b%solver_jacobian_builds,'A5 jacobian')
    call require(a%solver_linear_solves==b%solver_linear_solves,'A5 linear')
    call require(a%solver_backtracking_attempts==b%solver_backtracking_attempts,'A5 backtracking')
    call require(same_bits(a%mass%storage_start,b%mass%storage_start),'A5 storage start')
    call require(same_bits(a%mass%storage_end,b%mass%storage_end),'A5 storage end')
    call require(same_bits(a%mass%total_in,b%mass%total_in),'A5 total in')
    call require(same_bits(a%mass%total_out,b%mass%total_out),'A5 total out')
    call require(same_bits(a%mass%residual,b%mass%residual),'A5 residual')
  end subroutine

  pure logical function same_bits(a,b)
    real(real64), intent(in) :: a,b
    same_bits=transfer(a,0_int64)==transfer(b,0_int64)
  end function

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC09_FAIL',trim(label)
      error stop 1
    end if
  end subroutine

end program test_fpe_elastic09_application
