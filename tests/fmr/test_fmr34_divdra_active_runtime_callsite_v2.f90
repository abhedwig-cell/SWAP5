program test_fmr34_divdra_active_runtime_callsite_v2
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
  integer(int64), parameter :: id_a = 340001_int64
  integer(int64), parameter :: id_b = 340002_int64
  integer :: wt_shallow, wt_deep

  call test_inactive_identity()
  call test_active_equivalence(-0.25_real64, 1.0e-6_real64, wt_shallow)
  call test_active_equivalence(-1.25_real64, 1.0e-6_real64, wt_deep)
  call require(wt_shallow /= wt_deep, 'distinct explicit hydraulic views')
  write(*,'(A,I0,A,I0)') 'FMR34_EXPLICIT_VIEW_WT_NODES=', wt_shallow, ',', wt_deep
  write(*,'(A)') 'FMR34_EXPLICIT_HYDRAULIC_VIEW_NOT_SUBSTITUTED=PASS'
  call test_active_equivalence(-0.25_real64, 0.0_real64, wt_shallow)
  write(*,'(A)') 'FMR34_ZERO_TRANSFER_ACTIVE_CALLSITE=PASS'
  call test_preflight_rejections()
  call test_shared_forcing_rejection()
  write(*,'(A)') 'FMR34_ACTIVE_RUNTIME_CALLSITE_TEST PASS'

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
    integer :: dispatch, dispatch2, compose

    call initialize_case(c,t,p,f,s,cfg,.true.)
    call initialize_case(c2,t2,p2,f2,s2,cfg2,.true.)
    call configure_divdra(dp,hv,-0.25_real64)
    allocate(req(1)); req(1)%column_id=id_a; req(1)%active=.false.

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,t0,t1,1,r,d,a,dispatch)
    call require(dispatch==FMR_SERIAL_DISPATCH_OK .and. r(1)%committed, 'proven inactive baseline commits')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,1,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK, 'inactive wrapper dispatch')
    call require(r2(1)%committed .and. size(rec)==0, 'inactive wrapper commit and sparse records')
    call require(same_result(r(1),r2(1)), 'inactive result identity')
    call require(committed_fingerprint(s(1))==committed_fingerprint(s2(1)), 'inactive state identity')
    call require(allocated(f2(1)%drainage_flux_by_level), 'inactive forcing retained')
    call require(all(f2(1)%drainage_flux_by_level==f(1)%drainage_flux_by_level), 'inactive caller forcing unchanged')
    write(*,'(A)') 'FMR34_INACTIVE_GENERIC_RUNTIME_IDENTITY=PASS'
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
    integer :: dispatch, dispatch2, compose

    call initialize_case(c,t,p,f,s,cfg,.false.)
    call initialize_case(c2,t2,p2,f2,s2,cfg2,.false.)
    call configure_divdra(dp,hv,gwl)
    allocate(req(1))
    req(1)%column_id=id_a; req(1)%active=.true.; req(1)%distribution_parameter_ref=1_int64
    req(1)%hydraulic_view_ref=1_int64; req(1)%scalar_transfer=scalar_transfer

    call fmr_bind_single_level_positive_divdra(dp(1),hv(1),scalar_transfer,f(1)%drainage_flux_by_level,bd)
    call require(bd%status==FMR_DIVDRA_BIND_OK .and. bd%published, 'manual F-MR33 binding')
    allocate(expected(numnod)); expected=f(1)%drainage_flux_by_level(1,:)
    call require(same_bits(sum(expected),scalar_transfer), 'authoritative scalar closure')
    ! Keep the already-qualified F-MR31 hydraulic fixture on its proven path:
    ! irrigation exactly offsets drainage spatially, while drainage remains a
    ! distinct mass-ledger output and root extraction remains active.
    f(1)%subsurface_irrigation_source=expected
    f2(1)%subsurface_irrigation_source=expected

    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap(c,t,p,f,s,cfg,top,t0,t1,1,r,d,a,dispatch)
    call require(dispatch==FMR_SERIAL_DISPATCH_OK .and. r(1)%committed, 'manual prepared runtime commits')
    call require(r(1)%mass%complete .and. r(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE, 'manual mass complete')
    call require(abs(r(1)%mass%residual)<=hard_mass_gate, 'manual hard mass gate')

    call require(.not.allocated(f2(1)%drainage_flux_by_level), 'candidate starts unbound')
    call reset_legacy_globals()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,t0,t1,1,req,dp,hv, &
         r2,d2,a2,dispatch2,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK, 'active wrapper dispatch')
    call require(r2(1)%committed .and. size(rec)==1 .and. rec(1)%binding%published, 'active wrapper binding and commit')
    call require(same_bits(rec(1)%binding%authoritative_scalar_transfer,scalar_transfer), 'scalar diagnostic identity')
    call require(same_result(r(1),r2(1)), 'manual versus active runtime exact result identity')
    call require(committed_fingerprint(s(1))==committed_fingerprint(s2(1)), 'manual versus active state identity')
    call require(.not.allocated(f2(1)%drainage_flux_by_level), 'caller forcing restored after active return')
    call require(r2(1)%mass%complete .and. abs(r2(1)%mass%residual)<=hard_mass_gate, 'active hard mass gate')
    if (scalar_transfer>0.0_real64) then
      call require(r2(1)%mass%total_out >= scalar_transfer*(t1-t0), 'drainage represented in total out ledger')
      call require(r2(1)%mass%total_in >= scalar_transfer*(t1-t0), 'offset source represented in total in ledger')
    end if
    water_table_node=rec(1)%binding%process%water_table_node
    write(*,'(A,ES26.17E3,A,I0)') 'FMR34_ACTIVE_SCALAR=',scalar_transfer,',WT=',water_table_node
    write(*,'(A)') 'FMR34_MANUAL_BINDING_RUNTIME_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR34_EXISTING_MASS_LEDGER_EXACTLY_ONCE_EQUIVALENCE=PASS'
    write(*,'(A)') 'FMR34_CALLER_FORCING_RESTORED=PASS'
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
    call initialize_case(c,t,p,f,s,cfg,.false.); call request(req,-1.0e-6_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST, &
         'negative preflight rejection')
    call require(s(1)%current_revision()==0_int64 .and. .not.allocated(f(1)%drainage_flux_by_level), 'negative premutation')

    call initialize_case(c,t,p,f,s,cfg,.false.); call request(req,1.0e-10_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision()==0_int64, 'seam rejection premutation')
    call require(.not.allocated(f(1)%drainage_flux_by_level), 'seam no forcing mutation')

    call initialize_case(c,t,p,f,s,cfg,.true.); call request(req,1.0e-6_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,1,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. s(1)%current_revision()==0_int64, 'prebound target rejection')
    call require(allocated(f(1)%drainage_flux_by_level), 'prebound target retained')
    write(*,'(A)') 'FMR34_INVALID_TRANSFER_PRECOMMIT_REJECTION=PASS'
    write(*,'(A)') 'FMR34_PREBOUND_TARGET_NO_OVERWRITE=PASS'
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

    call initialize_shared_case(c,t,p,f,s,cfg)
    call configure_divdra(dp,hv,-0.25_real64)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    req(1)%column_id=id_a; req(1)%active=.true.; req(1)%distribution_parameter_ref=1_int64
    req(1)%hydraulic_view_ref=1_int64; req(1)%scalar_transfer=1.0e-6_real64
    req(2)%column_id=id_b
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,t0,t1,2,req,dp,hv,r,d,a,dispatch,compose,rec)
    call require(compose==FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE, 'shared forcing rejected')
    call require(all_revisions_zero(s) .and. .not.allocated(f(1)%drainage_flux_by_level), 'shared forcing premutation')
    write(*,'(A)') 'FMR34_SHARED_FORCING_NO_CROSS_COLUMN_LEAKAGE=PASS'
  end subroutine test_shared_forcing_rejection

  subroutine request(req,q)
    type(fmr_divdra_serialized_column_request_t), allocatable, intent(out) :: req(:)
    real(real64), intent(in) :: q
    allocate(req(1)); req(1)%column_id=id_a; req(1)%active=.true.
    req(1)%distribution_parameter_ref=1_int64; req(1)%hydraulic_view_ref=1_int64; req(1)%scalar_transfer=q
  end subroutine request

  subroutine initialize_case(c,t,p,f,s,cfg,prebound)
    type(fmr_logical_column_t), allocatable, intent(out) :: c(:)
    type(fmr_template_t), allocatable, intent(out) :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: f(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: s(:)
    type(canonical_numerical_config_t), intent(out) :: cfg
    logical, intent(in) :: prebound
    type(fmr_b110_physical_state_t) :: initial
    real(real64) :: conductivity0
    logical :: ok
    allocate(c(1),t(1),p(1),f(1),s(1))
    call configure_template(t(1)); call configure_parameters(p(1),initial,conductivity0)
    call configure_forcing(f(1),conductivity0,prebound); call configure_transaction(cfg)
    c(1)%column_id=id_a; c(1)%template_id=t(1)%template_id; c(1)%parameter_ref=1_int64
    c(1)%state_handle=1_int64; c(1)%forcing_handle=1_int64; c(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    call fmr_new_b110_committed_state(s(1),id_a,initial,t0,ok); call require(ok,'state init')
  end subroutine initialize_case

  subroutine initialize_shared_case(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), allocatable, intent(out) :: c(:)
    type(fmr_template_t), allocatable, intent(out) :: t(:)
    type(fmr_b110_physical_parameters_t), allocatable, intent(out) :: p(:)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: f(:)
    type(kernel_committed_state_t), allocatable, intent(out) :: s(:)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: initial
    real(real64) :: conductivity0
    logical :: ok
    integer :: k
    allocate(c(2),t(1),p(1),f(1),s(2))
    call configure_template(t(1)); call configure_parameters(p(1),initial,conductivity0)
    call configure_forcing(f(1),conductivity0,.false.); call configure_transaction(cfg)
    do k=1,2
      if (k==1) then; c(k)%column_id=id_a; else; c(k)%column_id=id_b; end if
      c(k)%template_id=t(1)%template_id; c(k)%parameter_ref=1_int64; c(k)%state_handle=int(k,int64)
      c(k)%forcing_handle=1_int64; c(k)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      call fmr_new_b110_committed_state(s(k),c(k)%column_id,initial,t0,ok); call require(ok,'shared state init')
    end do
  end subroutine initialize_shared_case

  subroutine configure_template(t)
    type(fmr_template_t), intent(out) :: t
    t%template_id=340_int64; t%physics_topology_id=34001_int64; t%vertical_layout_id=34002_int64
    t%state_layout_id=34003_int64; t%solver_interface_id=34004_int64; t%optional_state_layout_id=0_int64
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(p,state,conductivity0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: conductivity0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k
    p%parameter_set_id=34001_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7; p%swkimpl=0; p%swkmean=1; p%swsophy=0; p%root_extraction_active=.true.
    p%macropore_active=.false.; p%snow_active=.false.; p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.; p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    heads=head0; call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    call require(all(conductivity==conductivity(1)),'uniform conductivity')
    conductivity0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,conductivity0,prebound)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: conductivity0
    logical, intent(in) :: prebound
    integer :: k
    f%top_flux=-conductivity0; f%top_head=head0; f%bottom_flux=-conductivity0; f%bottom_head=-100.0_real64
    allocate(f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%subsurface_irrigation_source=0.0_real64
    do k=1,numnod; f%root_extraction_sink(k)=1.0e-5_real64*real(k,real64); end do
    if (prebound) then
      allocate(f%drainage_flux_by_level(2,numnod))
      do k=1,numnod
        f%drainage_flux_by_level(1,k)=1.0e-5_real64*real(k,real64)
        f%drainage_flux_by_level(2,k)=-2.0e-6_real64*real(k+1,real64)
        f%subsurface_irrigation_source(k)=sum(f%drainage_flux_by_level(:,k))
      end do
    end if
  end subroutine configure_forcing

  subroutine configure_divdra(dp,hv,gwl)
    type(drainage_distribution_parameters_t), allocatable, intent(out) :: dp(:)
    type(process_hydraulic_view_t), allocatable, intent(out) :: hv(:)
    real(real64), intent(in) :: gwl
    real(real64) :: depth
    integer :: k
    allocate(dp(1),hv(1)); dp(1)%active_nodes=numnod
    allocate(dp(1)%dz(numnod),dp(1)%zbotcp(numnod),dp(1)%saturated_conductivity(numnod), &
         dp(1)%horizontal_anisotropy_factor(numnod))
    dp(1)%dz=dz; depth=0.0_real64
    do k=1,numnod; depth=depth+dz(k); dp(1)%zbotcp(k)=-depth; end do
    dp(1)%saturated_conductivity=1.0_real64; dp(1)%horizontal_anisotropy_factor=1.0_real64; dp(1)%drain_spacing=4.0_real64
    hv(1)%active_nodes=numnod; allocate(hv(1)%pressure_head(numnod),hv(1)%water_content(numnod))
    hv(1)%pressure_head=head0; hv(1)%water_content=0.30_real64; hv(1)%ponding_depth=0.0_real64; hv(1)%groundwater_level=gwl
  end subroutine configure_divdra

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64; cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64; cfg%transaction%max_retries=2
    cfg%max_committed_substeps=8; cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine reset_legacy_globals()
    legacy_qdra=12345.0_real64; legacy_qssdi=-54321.0_real64; legacy_qrot=0.0_real64; swmacro=0; melt=0.0_real64
  end subroutine reset_legacy_globals

  logical function same_result(a,b) result(eq)
    type(fmr_serialized_column_result_t), intent(in) :: a,b
    eq=a%column_id==b%column_id .and. a%kernel_status==b%kernel_status .and. a%commit_status==b%commit_status .and. &
       a%completed.eqv.b%completed .and. a%committed.eqv.b%committed .and. a%solver_executed.eqv.b%solver_executed .and. &
       a%solver_iterations==b%solver_iterations .and. a%initial_revision==b%initial_revision .and. a%final_revision==b%final_revision .and. &
       same_bits(a%final_committed_time,b%final_committed_time) .and. a%mass%complete.eqv.b%mass%complete .and. &
       a%mass%missing_contribution_mask==b%mass%missing_contribution_mask .and. a%mass%origin_lineage_id==b%mass%origin_lineage_id .and. &
       a%mass%origin_revision==b%mass%origin_revision .and. a%mass%accepted_transaction_count==b%mass%accepted_transaction_count .and. &
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
    call state%snapshot(snapshot,got); call require(got,'snapshot')
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do k=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(k),fp)); fp=ieor(fp,transfer(physical%water_content(k),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'F-MR34 unexpected state type'
    end select
  end function committed_fingerprint

  logical function all_revisions_zero(s) result(ok)
    type(kernel_committed_state_t), intent(in) :: s(:)
    integer :: k
    ok=.true.; do k=1,size(s); if (s(k)%current_revision()/=0_int64) ok=.false.; end do
  end function all_revisions_zero

  logical function same_bits(a,b) result(eq)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); eq=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then; write(*,'(A,1X,A)') 'FMR34_TEST_FAIL',trim(label); error stop 1; end if
  end subroutine require
end program test_fmr34_divdra_active_runtime_callsite_v2
