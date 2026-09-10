program test_fmr36_divdra_active_runtime_callsite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: melt
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
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
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

  real(real64), parameter :: t0 = 4100.125_real64
  real(real64), parameter :: t1 = 4100.4375_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer(int64), parameter :: ids(2) = [310001_int64, 310002_int64]
  integer :: wt_shallow, wt_deep

  call test_inactive_identity()
  call test_active_equivalence(-0.25_real64, 1.0e-6_real64, wt_shallow)
  call test_active_equivalence(-1.25_real64, 1.0e-6_real64, wt_deep)
  call require(wt_shallow /= wt_deep, 'explicit hydraulic views select different water-table nodes')
  write(*,'(A,I0,A,I0)') 'FMR36_EXPLICIT_VIEW_WT_NODES=', wt_shallow, ',', wt_deep
  write(*,'(A)') 'FMR36_EXPLICIT_HYDRAULIC_VIEW_NOT_SUBSTITUTED=PASS'
  call test_preflight_rejections()
  call test_shared_forcing_rejection()
  write(*,'(A)') 'FMR36_ACTIVE_RUNTIME_CALLSITE_TEST PASS'

contains

  subroutine test_inactive_identity()
    type(fmr_logical_column_t), allocatable :: c(:), c2(:)
    type(fmr_template_t), allocatable :: t(:), t2(:)
    type(fmr_b110_physical_parameters_t), allocatable :: p(:), p2(:)
    type(fmr_b110_physical_forcing_t), allocatable :: f(:), f2(:)
    type(kernel_committed_state_t), allocatable :: s(:), s2(:)
    type(canonical_numerical_config_t) :: cfg, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a, a2
    type(fmr_divdra_serialized_column_request_t), allocatable :: req(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t), allocatable :: dp(:)
    type(process_hydraulic_view_t), allocatable :: hv(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: dispatch, dispatch2, compose, k

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    call initialize_fmr31_case(c2,t2,p2,f2,s2,cfg2)
    call configure_divdra(dp,hv,-0.25_real64)
    allocate(req(2)); req = fmr_divdra_serialized_column_request_t()
    do k=1,2
      req(k)%column_id = ids(k)
      req(k)%active = .false.
    end do

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,t0,t1,2,r,d,a,dispatch)
    call require(dispatch == FMR_SERIAL_DISPATCH_OK .and. all(r%committed), 'exact F-MR31-derived baseline commits')

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,2,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_OK .and. dispatch2 == FMR_SERIAL_DISPATCH_OK, 'inactive wrapper dispatch')
    call require(all(r2%committed) .and. size(rec) == 0, 'inactive wrapper commit and sparse diagnostics')
    do k=1,2
      call require(same_result(r(k),r2(k)), 'inactive exact result identity')
      call require(committed_fingerprint(s(k)) == committed_fingerprint(s2(k)), 'inactive committed state identity')
      call require(allocated(f2(k)%drainage_flux_by_level), 'inactive pre-existing drainage retained')
      call require(all(f2(k)%drainage_flux_by_level == f(k)%drainage_flux_by_level), 'inactive caller forcing unchanged')
    end do
    write(*,'(A)') 'FMR36_INACTIVE_FMR31_RUNTIME_IDENTITY=PASS'
  end subroutine test_inactive_identity

  subroutine test_active_equivalence(gwl, scalar_transfer, water_table_node)
    real(real64), intent(in) :: gwl, scalar_transfer
    integer, intent(out) :: water_table_node
    type(fmr_logical_column_t), allocatable :: c(:), c2(:)
    type(fmr_template_t), allocatable :: t(:), t2(:)
    type(fmr_b110_physical_parameters_t), allocatable :: p(:), p2(:)
    type(fmr_b110_physical_forcing_t), allocatable :: f(:), f2(:)
    type(kernel_committed_state_t), allocatable :: s(:), s2(:)
    type(canonical_numerical_config_t) :: cfg, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a, a2
    type(fmr_divdra_serialized_column_request_t), allocatable :: req(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t), allocatable :: dp(:)
    type(process_hydraulic_view_t), allocatable :: hv(:)
    type(fmr_divdra_binding_diagnostics_t) :: bd
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64), allocatable :: expected(:)
    integer :: dispatch, dispatch2, compose, k

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    call initialize_fmr31_case(c2,t2,p2,f2,s2,cfg2)
    call configure_divdra(dp,hv,gwl)

    ! Preserve exact F-MR31 control-column physics on column B. Only column A's
    ! already-existing drainage forcing is replaced by the qualified DIVDRA row.
    deallocate(f(1)%drainage_flux_by_level, f2(1)%drainage_flux_by_level)
    f(1)%subsurface_irrigation_source = 0.0_real64
    f2(1)%subsurface_irrigation_source = 0.0_real64
    call fmr_bind_single_level_positive_divdra(dp(1),hv(1),scalar_transfer,f(1)%drainage_flux_by_level,bd)
    call require(bd%status == FMR_DIVDRA_BIND_OK .and. bd%published, 'manual F-MR33 binding')
    allocate(expected(numnod)); expected = f(1)%drainage_flux_by_level(1,:)
    call require(same_bits(sum(expected),scalar_transfer), 'authoritative scalar closure')
    f(1)%subsurface_irrigation_source = expected
    f2(1)%subsurface_irrigation_source = expected

    allocate(req(2)); req = fmr_divdra_serialized_column_request_t()
    do k=1,2
      req(k)%column_id = ids(k)
    end do
    req(1)%active = .true.
    req(1)%distribution_parameter_ref = 1_int64
    req(1)%hydraulic_view_ref = 1_int64
    req(1)%scalar_transfer = scalar_transfer

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,t0,t1,2,r,d,a,dispatch)
    call require(dispatch == FMR_SERIAL_DISPATCH_OK .and. all(r%committed), 'manual prepared two-column runtime commits')
    call require(r(1)%mass%complete .and. r(1)%mass%missing_contribution_mask == TX_MASS_MISSING_NONE, 'manual mass complete')
    call require(abs(r(1)%mass%residual) <= hard_mass_gate, 'manual hard mass gate')

    call require(.not.allocated(f2(1)%drainage_flux_by_level), 'active candidate starts unbound')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,2,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_OK .and. dispatch2 == FMR_SERIAL_DISPATCH_OK, 'active wrapper dispatch')
    call require(all(r2%committed) .and. size(rec) == 1 .and. rec(1)%binding%published, 'active wrapper commits and publishes')
    call require(rec(1)%column_id == ids(1) .and. rec(1)%column_index == 1, 'sparse binding identity')
    call require(same_bits(rec(1)%binding%authoritative_scalar_transfer,scalar_transfer), 'scalar diagnostic identity')
    do k=1,2
      call require(same_result(r(k),r2(k)), 'manual versus active exact result identity')
      call require(committed_fingerprint(s(k)) == committed_fingerprint(s2(k)), 'manual versus active state identity')
    end do
    call require(.not.allocated(f2(1)%drainage_flux_by_level), 'active caller drainage scratch restored')
    call require(allocated(f2(2)%drainage_flux_by_level), 'inactive control forcing retained')
    call require(all(f2(2)%drainage_flux_by_level == f(2)%drainage_flux_by_level), 'inactive control forcing unchanged')
    call require(r2(1)%mass%complete .and. abs(r2(1)%mass%residual) <= hard_mass_gate, 'active hard mass gate')
    call require(r2(1)%mass%total_out >= scalar_transfer*(t1-t0), 'drainage occurs exactly through existing output ledger')
    call require(r2(1)%mass%total_in >= scalar_transfer*(t1-t0), 'fixture balancing source occurs through existing input ledger')

    water_table_node = rec(1)%binding%process%water_table_node
    write(*,'(A,ES26.17E3,A,I0)') 'FMR36_ACTIVE_SCALAR=',scalar_transfer,',WT=',water_table_node
    write(*,'(A)') 'FMR36_MANUAL_BINDING_RUNTIME_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_EXISTING_MASS_LEDGER_EXACTLY_ONCE_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR36_CALLER_FORCING_RESTORED=PASS'
    write(*,'(A)') 'FMR36_INACTIVE_NEIGHBOR_UNCHANGED=PASS'
  end subroutine test_active_equivalence

  subroutine test_preflight_rejections()
    type(fmr_logical_column_t), allocatable :: c(:)
    type(fmr_template_t), allocatable :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable :: f(:)
    type(kernel_committed_state_t), allocatable :: s(:)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_divdra_serialized_column_request_t), allocatable :: req(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t), allocatable :: dp(:)
    type(process_hydraulic_view_t), allocatable :: hv(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: dispatch, compose

    call configure_divdra(dp,hv,-0.25_real64)

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    call make_requests(req,-1.0e-6_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. dispatch == FMR_SERIAL_DISPATCH_INVALID_REQUEST, &
         'negative transfer preflight rejection')
    call require(s(1)%current_revision() == 0_int64 .and. s(2)%current_revision() == 0_int64, 'negative reject precommit')
    call require(.not.allocated(f(1)%drainage_flux_by_level), 'negative reject no forcing mutation')

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    call make_requests(req,1.0e-10_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision() == 0_int64, 'seam reject precommit')
    call require(.not.allocated(f(1)%drainage_flux_by_level), 'seam reject no forcing mutation')

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    call make_requests(req,1.0e-6_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision() == 0_int64, 'prebound reject precommit')
    call require(allocated(f(1)%drainage_flux_by_level), 'prebound caller target retained')

    write(*,'(A)') 'FMR36_INVALID_TRANSFER_PRECOMMIT_REJECTION=PASS'
    write(*,'(A)') 'FMR36_PREBOUND_TARGET_NO_OVERWRITE=PASS'
  end subroutine test_preflight_rejections

  subroutine test_shared_forcing_rejection()
    type(fmr_logical_column_t), allocatable :: c(:)
    type(fmr_template_t), allocatable :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable :: f(:)
    type(kernel_committed_state_t), allocatable :: s(:)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_divdra_serialized_column_request_t), allocatable :: req(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: rec(:)
    type(drainage_distribution_parameters_t), allocatable :: dp(:)
    type(process_hydraulic_view_t), allocatable :: hv(:)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: dispatch, compose

    call initialize_fmr31_case(c,t,p,f,s,cfg)
    c(2)%forcing_handle = 1_int64
    deallocate(f(1)%drainage_flux_by_level)
    call configure_divdra(dp,hv,-0.25_real64)
    call make_requests(req,1.0e-6_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose == FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE, 'shared forcing rejected')
    call require(dispatch == FMR_SERIAL_DISPATCH_INVALID_REQUEST, 'shared forcing no core dispatch')
    call require(s(1)%current_revision() == 0_int64 .and. s(2)%current_revision() == 0_int64, 'shared forcing precommit')
    call require(.not.allocated(f(1)%drainage_flux_by_level), 'shared forcing no mutation')
    write(*,'(A)') 'FMR36_SHARED_FORCING_NO_CROSS_COLUMN_LEAKAGE=PASS'
  end subroutine test_shared_forcing_rejection

  subroutine make_requests(req,scalar_transfer)
    type(fmr_divdra_serialized_column_request_t), allocatable, intent(out) :: req(:)
    real(real64), intent(in) :: scalar_transfer
    allocate(req(2)); req = fmr_divdra_serialized_column_request_t()
    req(1)%column_id = ids(1); req(1)%active = .true.
    req(1)%distribution_parameter_ref = 1_int64; req(1)%hydraulic_view_ref = 1_int64
    req(1)%scalar_transfer = scalar_transfer
    req(2)%column_id = ids(2); req(2)%active = .false.
  end subroutine make_requests

  subroutine initialize_fmr31_case(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), allocatable, intent(out) :: c(:)
    type(fmr_template_t), allocatable, intent(out) :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: f(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: s(:)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: conductivity0
    logical :: ok
    integer :: k

    allocate(c(2),t(1),p(1),f(2),s(2))
    call configure_template(t(1))
    call configure_parameters(p(1),initial_state,conductivity0)
    call configure_transaction(cfg)
    do k=1,2
      c(k)%column_id = ids(k)
      c(k)%template_id = t(1)%template_id
      c(k)%parameter_ref = 1_int64
      c(k)%state_handle = int(k,int64)
      c(k)%forcing_handle = int(k,int64)
      c(k)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(f(k),conductivity0,real(k,real64))
      call fmr_new_b110_committed_state(s(k),ids(k),initial_state,t0,ok)
      call require(ok,'committed state init')
    end do
  end subroutine initialize_fmr31_case

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 310_int64
    template%physics_topology_id = 31001_int64
    template%vertical_layout_id = 31002_int64
    template%state_layout_id = 31003_int64
    template%solver_interface_id = 31004_int64
    template%optional_state_layout_id = 0_int64
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(parameter,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameter
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hyd_parameters
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    parameter%parameter_set_id = 31001_int64
    parameter%active_nodes = numnod
    allocate(parameter%z(numnod),parameter%dz(numnod),parameter%node_distance(numnod),parameter%cofgen(24,numnod))
    parameter%z = z; parameter%dz = dz; parameter%node_distance = disnod(1:numnod); parameter%cofgen = 0.0_real64
    do k=1,numnod
      parameter%cofgen(1,k)=0.032_real64; parameter%cofgen(2,k)=0.423_real64; parameter%cofgen(3,k)=4.75_real64
      parameter%cofgen(4,k)=0.0135_real64; parameter%cofgen(5,k)=0.365_real64; parameter%cofgen(6,k)=1.455_real64
      parameter%cofgen(7,k)=1.0_real64-1.0_real64/parameter%cofgen(6,k); parameter%cofgen(8,k)=parameter%cofgen(4,k)
      parameter%cofgen(9,k)=0.0_real64; parameter%cofgen(10,k)=parameter%cofgen(3,k); parameter%cofgen(11,k)=0.999_real64
      parameter%cofgen(12,k)=0.99_real64*parameter%cofgen(3,k); parameter%cofgen(22,k)=-1.0e6_real64
      parameter%cofgen(23,k)=1.0e-12_real64
    end do
    parameter%bottom_mode=7; parameter%swkimpl=0; parameter%swkmean=1; parameter%swsophy=0
    parameter%root_extraction_active=.true.; parameter%macropore_active=.false.; parameter%snow_active=.false.
    parameter%hysteresis_active=.false.; parameter%tabulated_hydraulics_active=.false.
    parameter%elasticity_active=.false.; parameter%frost_active=.false.

    call initialize_b110_default_mvg_parameters(hyd_parameters,parameter%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd_parameters,t1-t0)
    heads = head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(conductivity == conductivity(1)),'uniform conductivity fixture')
    conductivity0 = conductivity(1)
    state%active_nodes = numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head = heads; state%water_content = water
    state%ponding_depth = 0.0_real64; state%groundwater_level = -2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing,conductivity0,scale)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: conductivity0,scale
    integer :: k

    forcing%top_flux = -conductivity0
    forcing%top_head = head0
    forcing%bottom_flux = -conductivity0
    forcing%bottom_head = -100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do k=1,numnod
      forcing%drainage_flux_by_level(1,k) = 1.0e-5_real64*real(k,real64)
      forcing%drainage_flux_by_level(2,k) = -2.0e-6_real64*real(k+1,real64)
      forcing%subsurface_irrigation_source(k) = forcing%drainage_flux_by_level(1,k) + forcing%drainage_flux_by_level(2,k)
      forcing%root_extraction_sink(k) = scale*1.0e-5_real64*real(k,real64)
    end do
  end subroutine configure_forcing

  subroutine configure_divdra(dp,hv,gwl)
    type(drainage_distribution_parameters_t), allocatable, intent(out) :: dp(:)
    type(process_hydraulic_view_t), allocatable, intent(out) :: hv(:)
    real(real64), intent(in) :: gwl
    real(real64) :: depth
    integer :: k
    allocate(dp(1),hv(1))
    dp(1)%active_nodes = numnod
    allocate(dp(1)%dz(numnod),dp(1)%zbotcp(numnod),dp(1)%saturated_conductivity(numnod), &
         dp(1)%horizontal_anisotropy_factor(numnod))
    dp(1)%dz = dz; depth = 0.0_real64
    do k=1,numnod
      depth = depth + dz(k); dp(1)%zbotcp(k) = -depth
    end do
    dp(1)%saturated_conductivity = 1.0_real64
    dp(1)%horizontal_anisotropy_factor = 1.0_real64
    dp(1)%drain_spacing = 4.0_real64
    hv(1)%active_nodes = numnod
    allocate(hv(1)%pressure_head(numnod),hv(1)%water_content(numnod))
    hv(1)%pressure_head = head0; hv(1)%water_content = 0.30_real64
    hv(1)%ponding_depth = 0.0_real64; hv(1)%groundwater_level = gwl
  end subroutine configure_divdra

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance = 0.0_real64
    cfg%transaction%mass_tolerance = hard_mass_gate
    cfg%transaction%retry_scale = 0.5_real64
    cfg%transaction%max_retries = 2
    cfg%max_committed_substeps = 8
    cfg%progress_tolerance = 0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra = 12345.0_real64
    legacy_qssdi = -54321.0_real64
    legacy_qrot = 0.0_real64
    swmacro = 0
    melt = 0.0_real64
  end subroutine reset_legacy_globals

  logical function same_result(a,b) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    equal = a%column_id == b%column_id .and. a%kernel_status == b%kernel_status .and. &
         a%commit_status == b%commit_status .and. a%completed .eqv. b%completed .and. &
         a%committed .eqv. b%committed .and. a%solver_executed .eqv. b%solver_executed .and. &
         a%solver_iterations == b%solver_iterations .and. a%initial_revision == b%initial_revision .and. &
         a%final_revision == b%final_revision .and. same_bits(a%final_committed_time,b%final_committed_time) .and. &
         a%mass%complete .eqv. b%mass%complete .and. a%mass%missing_contribution_mask == b%mass%missing_contribution_mask .and. &
         a%mass%origin_lineage_id == b%mass%origin_lineage_id .and. a%mass%origin_revision == b%mass%origin_revision .and. &
         a%mass%accepted_transaction_count == b%mass%accepted_transaction_count .and. &
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
    fp = 1469598103934665603_int64
    select type (physical => snapshot)
    type is (fmr_b110_physical_state_t)
      fp = ieor(fp,int(physical%active_nodes,int64))
      do k=1,physical%active_nodes
        fp = ieor(fp,transfer(physical%pressure_head(k),fp))
        fp = ieor(fp,transfer(physical%water_content(k),fp))
      end do
      fp = ieor(fp,transfer(physical%ponding_depth,fp))
      fp = ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR36 unexpected state type'
    end select
  end function committed_fingerprint

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia = transfer(a,ia); ib = transfer(b,ib); equal = ia == ib
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
