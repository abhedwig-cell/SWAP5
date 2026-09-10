program test_fmr36_divdra_active_runtime_callsite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_divdra_serialized_runtime, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_run_serialized_physical_multiswap_with_divdra
  use mod_fmr_divdra_serialized_composition, only: FMR_DIVDRA_COMPOSE_OK, FMR_DIVDRA_COMPOSE_BIND_REJECTED, &
       FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  ! Exact temporal/physical scaffold from the F-VQ21/F-MR09 real-physics oracle
  ! replayed successfully by F-VQ50. F-MR36 changes only drainage preparation.
  real(real64), parameter :: t0 = 2100.375_real64
  real(real64), parameter :: t1 = 2100.875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: column_id = 909001_int64
  integer :: wt_shallow, wt_deep

  call test_fvq21_control_replay()
  call test_inactive_wrapper_identity()
  call test_active_equivalence(-0.25_real64, 0.04_real64, wt_shallow)
  call test_active_equivalence(-1.25_real64, 0.04_real64, wt_deep)
  call require(wt_shallow /= wt_deep, 'explicit hydraulic views select distinct water-table nodes')
  write(*,'(A,I0,A,I0)') 'FMR36_EXPLICIT_VIEW_WT_NODES=', wt_shallow, ',', wt_deep
  write(*,'(A)') 'FMR36_EXPLICIT_HYDRAULIC_VIEW_NOT_SUBSTITUTED=PASS'
  call test_zero_transfer()
  call test_preflight_rejections()
  call test_shared_forcing_rejection()
  write(*,'(A)') 'FMR36_ACTIVE_RUNTIME_CALLSITE_TEST PASS'

contains

  subroutine test_fvq21_control_replay()
    type(fmr_logical_column_t) :: c(1)
    type(fmr_template_t) :: t(1)
    type(fmr_b110_physical_parameters_t) :: p(1)
    type(fmr_b110_physical_forcing_t) :: f(1)
    type(fmr_b110_physical_state_t) :: initial
    type(kernel_committed_state_t) :: s(1)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_serialized_batch_diagnostics_t) :: rd
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: conductivity0
    logical :: ok
    integer :: dispatch

    call configure_physical_parameters(p(1),initial,conductivity0)
    p(1)%root_extraction_active = .true.
    call configure_column(c(1),t(1))
    call configure_transaction(cfg)
    call configure_control_forcing(f(1),conductivity0)
    call fmr_new_b110_committed_state(s(1),c(1)%column_id,initial,t0,ok)
    call require(ok,'F-VQ21 control committed init')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,t0,t1,1,r,d,a,dispatch,rd)
    call require(dispatch == FMR_SERIAL_DISPATCH_OK, 'F-VQ21 control dispatch')
    call require(r(1)%completed .and. r(1)%committed .and. r(1)%solver_executed, 'F-VQ21 control commit')
    call require(r(1)%mass%complete .and. r(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, &
         'F-VQ21 control mass complete')
    call require(abs(r(1)%mass%residual) <= hard_mass_gate, 'F-VQ21 control hard mass gate')
    call require(rd%max_simultaneous_real_physical_solves == 1, 'F-VQ21 serialized physical solve')
    write(*,'(A)') 'FMR36_FVQ21_CONTROL_REPLAY=PASS'
  end subroutine test_fvq21_control_replay

  subroutine test_inactive_wrapper_identity()
    type(fmr_logical_column_t) :: c1(1), c2(1)
    type(fmr_template_t) :: t1(1), t2(1)
    type(fmr_b110_physical_parameters_t) :: p1(1), p2(1)
    type(fmr_b110_physical_forcing_t) :: f1(1), f2(1)
    type(fmr_b110_physical_state_t) :: initial1, initial2
    type(kernel_committed_state_t) :: s1(1), s2(1)
    type(canonical_numerical_config_t) :: cfg1, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a1, a2
    type(fmr_divdra_serialized_column_request_t) :: req(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: k1, k2
    logical :: ok
    integer :: dispatch1, dispatch2, compose

    call configure_physical_parameters(p1(1),initial1,k1); p1(1)%root_extraction_active=.true.
    call configure_physical_parameters(p2(1),initial2,k2); p2(1)%root_extraction_active=.true.
    call configure_column(c1(1),t1(1)); call configure_column(c2(1),t2(1))
    call configure_transaction(cfg1); call configure_transaction(cfg2)
    call configure_control_forcing(f1(1),k1); call configure_control_forcing(f2(1),k2)
    call fmr_new_b110_committed_state(s1(1),column_id,initial1,t0,ok); call require(ok,'inactive state 1')
    call fmr_new_b110_committed_state(s2(1),column_id,initial2,t0,ok); call require(ok,'inactive state 2')
    call configure_divdra(dp(1),hv(1),-0.25_real64)
    req(1)=fmr_divdra_serialized_column_request_t(); req(1)%column_id=column_id; req(1)%active=.false.

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c1,t1,p1,f1,s1,cfg1,top,t0,t1,1,r1,d1,a1,dispatch1)
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,1,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(dispatch1==FMR_SERIAL_DISPATCH_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK, 'inactive dispatch identity')
    call require(r1(1)%committed .and. r2(1)%committed .and. compose==FMR_DIVDRA_COMPOSE_OK, 'inactive commit identity')
    call require(size(rec)==0, 'inactive sparse diagnostics')
    call require(same_result(r1(1),r2(1)), 'inactive exact result identity')
    call require(committed_fingerprint(s1(1))==committed_fingerprint(s2(1)), 'inactive committed state identity')
    call require(allocated(f2(1)%drainage_flux_by_level), 'inactive drainage retained')
    call require(all(f2(1)%drainage_flux_by_level==0.0_real64), 'inactive caller forcing unchanged')
    write(*,'(A)') 'FMR36_INACTIVE_FVQ21_RUNTIME_IDENTITY=PASS'
  end subroutine test_inactive_wrapper_identity

  subroutine test_active_equivalence(gwl,scalar_transfer,water_table_node)
    real(real64), intent(in) :: gwl, scalar_transfer
    integer, intent(out) :: water_table_node
    type(fmr_logical_column_t) :: c1(1), c2(1)
    type(fmr_template_t) :: t1(1), t2(1)
    type(fmr_b110_physical_parameters_t) :: p1(1), p2(1)
    type(fmr_b110_physical_forcing_t) :: f1(1), f2(1)
    type(fmr_b110_physical_state_t) :: initial1, initial2
    type(kernel_committed_state_t) :: s1(1), s2(1)
    type(canonical_numerical_config_t) :: cfg1, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a1, a2
    type(fmr_divdra_serialized_column_request_t) :: req(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr_divdra_binding_diagnostics_t) :: bd
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: k1,k2,tolerance
    real(real64), allocatable :: expected(:)
    logical :: ok
    integer :: dispatch1,dispatch2,compose

    call configure_physical_parameters(p1(1),initial1,k1); p1(1)%root_extraction_active=.true.
    call configure_physical_parameters(p2(1),initial2,k2); p2(1)%root_extraction_active=.true.
    call configure_column(c1(1),t1(1)); call configure_column(c2(1),t2(1))
    call configure_transaction(cfg1); call configure_transaction(cfg2)
    call configure_control_forcing(f1(1),k1); call configure_control_forcing(f2(1),k2)
    deallocate(f1(1)%drainage_flux_by_level,f2(1)%drainage_flux_by_level)
    call fmr_new_b110_committed_state(s1(1),column_id,initial1,t0,ok); call require(ok,'active state 1')
    call fmr_new_b110_committed_state(s2(1),column_id,initial2,t0,ok); call require(ok,'active state 2')
    call configure_divdra(dp(1),hv(1),gwl)

    call fmr_bind_single_level_positive_divdra(dp(1),hv(1),scalar_transfer,f1(1)%drainage_flux_by_level,bd)
    call require(bd%status==FMR_DIVDRA_BIND_OK .and. bd%published,'manual F-MR33 binding')
    allocate(expected(numnod)); expected=f1(1)%drainage_flux_by_level(1,:)
    call require(same_bits(sum(expected),scalar_transfer),'authoritative scalar closure')

    ! Exact F-VQ21 balancing principle: source and sink are identical per node,
    ! so drainage changes the mass ledger but not the hydraulic trajectory.
    f1(1)%subsurface_irrigation_source=expected
    f2(1)%subsurface_irrigation_source=expected
    f1(1)%root_extraction_sink=0.0_real64
    f2(1)%root_extraction_sink=0.0_real64

    req(1)=fmr_divdra_serialized_column_request_t()
    req(1)%column_id=column_id; req(1)%active=.true.
    req(1)%distribution_parameter_ref=1_int64; req(1)%hydraulic_view_ref=1_int64
    req(1)%scalar_transfer=scalar_transfer

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c1,t1,p1,f1,s1,cfg1,top,t0,t1,1,r1,d1,a1,dispatch1)
    call require(dispatch1==FMR_SERIAL_DISPATCH_OK .and. r1(1)%committed,'manual prepared runtime commits')
    call require(r1(1)%mass%complete .and. abs(r1(1)%mass%residual)<=hard_mass_gate,'manual hard mass')

    call require(.not.allocated(f2(1)%drainage_flux_by_level),'candidate starts unbound')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,1,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK,'active wrapper dispatch')
    call require(r2(1)%committed .and. size(rec)==1 .and. rec(1)%binding%published,'active wrapper binding and commit')
    call require(same_bits(rec(1)%binding%authoritative_scalar_transfer,scalar_transfer),'scalar diagnostic identity')
    call require(same_result(r1(1),r2(1)),'manual versus active exact result identity')
    call require(committed_fingerprint(s1(1))==committed_fingerprint(s2(1)),'manual versus active state identity')
    call require(.not.allocated(f2(1)%drainage_flux_by_level),'caller forcing restored after active return')
    call require(r2(1)%mass%complete .and. abs(r2(1)%mass%residual)<=hard_mass_gate,'active hard mass')
    tolerance=256.0_real64*epsilon(1.0_real64)*max(1.0_real64,scalar_transfer*(t1-t0))
    call require(abs(r2(1)%mass%total_in-r2(1)%mass%total_out)<=tolerance,'balanced process mass input output')

    water_table_node=rec(1)%binding%process%water_table_node
    write(*,'(A,ES24.16,A,I0)') 'FMR36_ACTIVE_SCALAR=',scalar_transfer,',WT=',water_table_node
    write(*,'(A)') 'FMR36_MANUAL_BINDING_RUNTIME_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_EXISTING_MASS_LEDGER_EXACTLY_ONCE_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_CALLER_FORCING_RESTORED=PASS'
  end subroutine test_active_equivalence

  subroutine test_zero_transfer()
    integer :: wt
    call test_active_equivalence(-0.25_real64,0.0_real64,wt)
    write(*,'(A)') 'FMR36_ZERO_TRANSFER_ACTIVE_CALLSITE=PASS'
  end subroutine test_zero_transfer

  subroutine test_preflight_rejections()
    type(fmr_logical_column_t) :: c(1)
    type(fmr_template_t) :: t(1)
    type(fmr_b110_physical_parameters_t) :: p(1)
    type(fmr_b110_physical_forcing_t) :: f(1)
    type(fmr_b110_physical_state_t) :: initial
    type(kernel_committed_state_t) :: s(1)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_divdra_serialized_column_request_t) :: req(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: conductivity0
    logical :: ok
    integer :: dispatch,compose

    call configure_divdra(dp(1),hv(1),-0.25_real64)

    call configure_physical_parameters(p(1),initial,conductivity0); p(1)%root_extraction_active=.true.
    call configure_column(c(1),t(1)); call configure_transaction(cfg); call configure_control_forcing(f(1),conductivity0)
    deallocate(f(1)%drainage_flux_by_level)
    call fmr_new_b110_committed_state(s(1),column_id,initial,t0,ok); call require(ok,'negative state')
    call make_active_request(req(1),-0.04_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST, &
         'negative transfer rejected')
    call require(s(1)%current_revision()==0_int64 .and. .not.allocated(f(1)%drainage_flux_by_level),'negative premutation')

    call configure_physical_parameters(p(1),initial,conductivity0); p(1)%root_extraction_active=.true.
    call configure_column(c(1),t(1)); call configure_transaction(cfg); call configure_control_forcing(f(1),conductivity0)
    deallocate(f(1)%drainage_flux_by_level)
    call fmr_new_b110_committed_state(s(1),column_id,initial,t0,ok); call require(ok,'seam state')
    call make_active_request(req(1),1.0e-10_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision()==0_int64,'restricted seam rejected')
    call require(.not.allocated(f(1)%drainage_flux_by_level),'restricted seam no forcing mutation')

    call configure_physical_parameters(p(1),initial,conductivity0); p(1)%root_extraction_active=.true.
    call configure_column(c(1),t(1)); call configure_transaction(cfg); call configure_control_forcing(f(1),conductivity0)
    call fmr_new_b110_committed_state(s(1),column_id,initial,t0,ok); call require(ok,'prebound state')
    call make_active_request(req(1),0.04_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision()==0_int64,'prebound target rejected')
    call require(allocated(f(1)%drainage_flux_by_level) .and. all(f(1)%drainage_flux_by_level==0.0_real64), &
         'prebound target unchanged')

    write(*,'(A)') 'FMR36_INVALID_TRANSFER_PRECOMMIT_REJECTION=PASS'
    write(*,'(A)') 'FMR36_PREBOUND_TARGET_NO_OVERWRITE=PASS'
  end subroutine test_preflight_rejections

  subroutine test_shared_forcing_rejection()
    type(fmr_logical_column_t) :: c(2)
    type(fmr_template_t) :: t(1)
    type(fmr_b110_physical_parameters_t) :: p(1)
    type(fmr_b110_physical_forcing_t) :: f(1)
    type(fmr_b110_physical_state_t) :: initial
    type(kernel_committed_state_t) :: s(2)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_divdra_serialized_column_request_t) :: req(2)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64) :: conductivity0
    logical :: ok
    integer :: dispatch,compose

    call configure_physical_parameters(p(1),initial,conductivity0); p(1)%root_extraction_active=.true.
    call configure_column(c(1),t(1)); c(2)=c(1); c(2)%column_id=909002_int64; c(2)%state_handle=2_int64
    c(2)%forcing_handle=1_int64
    call configure_transaction(cfg); call configure_control_forcing(f(1),conductivity0)
    deallocate(f(1)%drainage_flux_by_level)
    call fmr_new_b110_committed_state(s(1),c(1)%column_id,initial,t0,ok); call require(ok,'shared state 1')
    call fmr_new_b110_committed_state(s(2),c(2)%column_id,initial,t0,ok); call require(ok,'shared state 2')
    call configure_divdra(dp(1),hv(1),-0.25_real64)
    req=fmr_divdra_serialized_column_request_t()
    call make_active_request(req(1),0.04_real64)
    req(2)%column_id=c(2)%column_id; req(2)%active=.false.

    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE,'shared forcing rejected')
    call require(dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST,'shared forcing no core dispatch')
    call require(s(1)%current_revision()==0_int64 .and. s(2)%current_revision()==0_int64,'shared forcing premutation')
    call require(.not.allocated(f(1)%drainage_flux_by_level),'shared forcing no mutation')
    write(*,'(A)') 'FMR36_SHARED_FORCING_NO_CROSS_COLUMN_LEAKAGE=PASS'
  end subroutine test_shared_forcing_rejection

  subroutine make_active_request(req,scalar_transfer)
    type(fmr_divdra_serialized_column_request_t), intent(out) :: req
    real(real64), intent(in) :: scalar_transfer
    req=fmr_divdra_serialized_column_request_t()
    req%column_id=column_id; req%active=.true.
    req%distribution_parameter_ref=1_int64; req%hydraulic_view_ref=1_int64
    req%scalar_transfer=scalar_transfer
  end subroutine make_active_request

  subroutine configure_column(column,template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id=909_int64
    template%physics_topology_id=90901_int64
    template%vertical_layout_id=90902_int64
    template%state_layout_id=90903_int64
    template%solver_interface_id=90904_int64
    template%optional_state_layout_id=90905_int64
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=column_id; column%template_id=template%template_id
    column%parameter_ref=1_int64; column%state_handle=1_int64; column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_physical_parameters(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=90901_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hyd_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads=head0; call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    conductivity0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_physical_parameters

  subroutine configure_control_forcing(f,conductivity0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    f%top_flux=-conductivity0; f%top_head=head0
    f%bottom_flux=-conductivity0; f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine configure_control_forcing

  subroutine configure_divdra(dp,hv,gwl)
    type(drainage_distribution_parameters_t), intent(out) :: dp
    type(process_hydraulic_view_t), intent(out) :: hv
    real(real64), intent(in) :: gwl
    real(real64) :: depth
    integer :: k
    dp%active_nodes=numnod
    allocate(dp%dz(numnod),dp%zbotcp(numnod),dp%saturated_conductivity(numnod),dp%horizontal_anisotropy_factor(numnod))
    dp%dz=dz; depth=0.0_real64
    do k=1,numnod
      depth=depth+dz(k); dp%zbotcp(k)=-depth
    end do
    dp%saturated_conductivity=1.0_real64
    dp%horizontal_anisotropy_factor=1.0_real64
    dp%drain_spacing=4.0_real64
    hv%active_nodes=numnod
    allocate(hv%pressure_head(numnod),hv%water_content(numnod))
    hv%pressure_head=head0; hv%water_content=0.30_real64
    hv%ponding_depth=0.0_real64; hv%groundwater_level=gwl
  end subroutine configure_divdra

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=2
    cfg%max_committed_substeps=8
    cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64
    legacy_qrot=-99999.0_real64; swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_legacy_globals

  logical function same_result(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal=a%column_id==b%column_id .and. a%kernel_status==b%kernel_status .and. a%commit_status==b%commit_status .and. &
      a%completed.eqv.b%completed .and. a%committed.eqv.b%committed .and. a%solver_executed.eqv.b%solver_executed .and. &
      a%solver_iterations==b%solver_iterations .and. a%initial_revision==b%initial_revision .and. &
      a%final_revision==b%final_revision .and. same_bits(a%final_committed_time,b%final_committed_time) .and. &
      a%actual_transpiration_available.eqv.b%actual_transpiration_available .and. &
      same_bits(a%actual_transpiration_amount,b%actual_transpiration_amount) .and. &
      a%mass%complete.eqv.b%mass%complete .and. a%mass%missing_contribution_mask==b%mass%missing_contribution_mask .and. &
      a%mass%origin_lineage_id==b%mass%origin_lineage_id .and. a%mass%origin_revision==b%mass%origin_revision .and. &
      a%mass%accepted_transaction_count==b%mass%accepted_transaction_count .and. &
      same_bits(a%mass%interval_t0,b%mass%interval_t0) .and. same_bits(a%mass%interval_t1,b%mass%interval_t1) .and. &
      same_bits(a%mass%storage_start,b%mass%storage_start) .and. same_bits(a%mass%storage_end,b%mass%storage_end) .and. &
      same_bits(a%mass%storage_change,b%mass%storage_change) .and. same_bits(a%mass%total_in,b%mass%total_in) .and. &
      same_bits(a%mass%total_out,b%mass%total_out) .and. same_bits(a%mass%residual,b%mass%residual)
  end function same_result

  integer(int64) function committed_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: k
    call state%snapshot(snapshot,got); call require(got,'committed snapshot')
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do k=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(k),fp)); fp=ieor(fp,transfer(physical%water_content(k),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR36 unexpected state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FMR36_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fmr36_divdra_active_runtime_callsite
