program test_fvq51_divdra_active_runtime_callsite
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
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK, FMR_SERIAL_DISPATCH_INVALID_REQUEST
  use mod_fmr_divdra_serialized_runtime, only: fmr_divdra_serialized_column_request_t, &
       fmr_divdra_serialized_binding_record_t, fmr_run_serialized_physical_multiswap_with_divdra
  use mod_fmr_divdra_serialized_composition, only: FMR_DIVDRA_COMPOSE_OK, FMR_DIVDRA_COMPOSE_INVALID_SHAPE, &
       FMR_DIVDRA_COMPOSE_COLUMN_ID_MISMATCH, FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE, &
       FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF, FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF, &
       FMR_DIVDRA_COMPOSE_BIND_REJECTED
  use mod_fmr_divdra_runtime_binding, only: fmr_divdra_binding_diagnostics_t, &
       fmr_bind_single_level_positive_divdra, FMR_DIVDRA_BIND_OK
  use mod_drainage_spatial_distribution, only: drainage_distribution_parameters_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: qa_t0 = 7312.0625_real64
  real(real64), parameter :: qa_t1 = 7312.3125_real64
  real(real64), parameter :: qa_head = -123.0_real64
  real(real64), parameter :: mass_gate = 1.0e-12_real64
  integer(int64), parameter :: id1 = 510001_int64, id2 = 510002_int64
  real(real64), parameter :: gwls(3) = [-0.20_real64, -0.85_real64, -1.80_real64]
  real(real64), parameter :: transfers(4) = [0.0_real64, 2.0e-4_real64, 7.5e-3_real64, 3.25e-2_real64]
  integer :: i, j, valid_cases

  valid_cases = 0
  call verify_inactive_identity()
  do i = 1, size(gwls)
    do j = 1, size(transfers)
      call verify_single_active(gwls(i), transfers(j))
      valid_cases = valid_cases + 1
    end do
  end do
  call verify_two_active_columns()
  call verify_fail_closed_matrix()

  write(*,'(A,I0)') 'FVQ51_VALID_SINGLE_ACTIVE_CASES=', valid_cases
  write(*,'(A)') 'FVQ51_INDEPENDENT_ACTIVE_RUNTIME_CALLSITE PASS'

contains

  subroutine verify_inactive_identity()
    type(fmr_logical_column_t) :: c1(1), c2(1)
    type(fmr_template_t) :: t1(1), t2(1)
    type(fmr_b110_physical_parameters_t) :: p1(1), p2(1)
    type(fmr_b110_physical_forcing_t) :: f1(1), f2(1)
    type(kernel_committed_state_t) :: s1(1), s2(1)
    type(canonical_numerical_config_t) :: cfg1, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a1, a2
    type(fmr_divdra_serialized_column_request_t) :: req(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: dispatch1, dispatch2, compose

    call initialize_one(c1,t1,p1,f1,s1,cfg1)
    call initialize_one(c2,t2,p2,f2,s2,cfg2)
    call configure_distribution(dp(1))
    call configure_view(hv(1),-0.55_real64)
    req(1)=fmr_divdra_serialized_column_request_t()
    req(1)%column_id=id1

    call reset_legacy()
    call fmr_run_serialized_physical_multiswap(c1,t1,p1,f1,s1,cfg1,top,qa_t0,qa_t1,1,r1,d1,a1,dispatch1)
    call reset_legacy()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,qa_t0,qa_t1,1, &
         req,dp,hv,r2,d2,a2,dispatch2,compose,records)

    call require(dispatch1==FMR_SERIAL_DISPATCH_OK .and. dispatch2==FMR_SERIAL_DISPATCH_OK,'inactive dispatch')
    call require(r1(1)%committed .and. r2(1)%committed,'inactive committed')
    call require(compose==FMR_DIVDRA_COMPOSE_OK .and. size(records)==0,'inactive sparse composition')
    call require(same_result(r1(1),r2(1)),'inactive result identity')
    call require(state_fingerprint(s1(1))==state_fingerprint(s2(1)),'inactive state identity')
    call require(allocated(f2(1)%drainage_flux_by_level),'inactive drainage allocation retained')
    call require(all(f2(1)%drainage_flux_by_level==0.0_real64),'inactive forcing unchanged')
    write(*,'(A)') 'FVQ51_INACTIVE_EXACT_IDENTITY=PASS'
  end subroutine verify_inactive_identity

  subroutine verify_single_active(gwl, transfer_rate)
    real(real64), intent(in) :: gwl, transfer_rate
    type(fmr_logical_column_t) :: c1(1), c2(1)
    type(fmr_template_t) :: t1(1), t2(1)
    type(fmr_b110_physical_parameters_t) :: p1(1), p2(1)
    type(fmr_b110_physical_forcing_t) :: f1(1), f2(1)
    type(kernel_committed_state_t) :: s1(1), s2(1)
    type(canonical_numerical_config_t) :: cfg1, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a1, a2
    type(fmr_divdra_serialized_column_request_t) :: req(1)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr_divdra_binding_diagnostics_t) :: bd
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64), allocatable :: row(:)
    integer :: dispatch1, dispatch2, compose

    call initialize_one(c1,t1,p1,f1,s1,cfg1)
    call initialize_one(c2,t2,p2,f2,s2,cfg2)
    deallocate(f1(1)%drainage_flux_by_level, f2(1)%drainage_flux_by_level)
    call configure_distribution(dp(1))
    call configure_view(hv(1),gwl)

    call fmr_bind_single_level_positive_divdra(dp(1),hv(1),transfer_rate,f1(1)%drainage_flux_by_level,bd)
    call require(bd%status==FMR_DIVDRA_BIND_OK .and. bd%published,'manual binding accepted')
    allocate(row(numnod)); row=f1(1)%drainage_flux_by_level(1,:)
    call require(same_bits(sum(row),transfer_rate),'manual scalar closure')
    f1(1)%subsurface_irrigation_source=row
    f2(1)%subsurface_irrigation_source=row

    req(1)=fmr_divdra_serialized_column_request_t()
    req(1)%column_id=id1; req(1)%active=.true.
    req(1)%distribution_parameter_ref=1_int64
    req(1)%hydraulic_view_ref=1_int64
    req(1)%scalar_transfer=transfer_rate

    call reset_legacy()
    call fmr_run_serialized_physical_multiswap(c1,t1,p1,f1,s1,cfg1,top,qa_t0,qa_t1,1,r1,d1,a1,dispatch1)
    call require(dispatch1==FMR_SERIAL_DISPATCH_OK .and. r1(1)%committed,'manual runtime committed')
    call reset_legacy()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,qa_t0,qa_t1,1, &
         req,dp,hv,r2,d2,a2,dispatch2,compose,records)

    call require(dispatch2==FMR_SERIAL_DISPATCH_OK .and. compose==FMR_DIVDRA_COMPOSE_OK,'active dispatch')
    call require(r2(1)%committed .and. size(records)==1 .and. records(1)%binding%published,'active commit publication')
    call require(same_bits(records(1)%binding%authoritative_scalar_transfer,transfer_rate),'scalar retained')
    call require(same_result(r1(1),r2(1)),'manual/callsite result equivalence')
    call require(state_fingerprint(s1(1))==state_fingerprint(s2(1)),'manual/callsite state equivalence')
    call require(r2(1)%mass%complete .and. r2(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'mass complete')
    call require(abs(r2(1)%mass%residual)<=mass_gate,'hard mass gate')
    call require(.not.allocated(f2(1)%drainage_flux_by_level),'caller forcing restored')
    write(*,'(A,ES18.10,A,ES18.10,A,I0)') 'FVQ51_SINGLE GWL=',gwl,' Q=',transfer_rate,' WT=', &
         records(1)%binding%process%water_table_node
  end subroutine verify_single_active

  subroutine verify_two_active_columns()
    type(fmr_logical_column_t) :: c1(2), c2(2)
    type(fmr_template_t) :: t1(1), t2(1)
    type(fmr_b110_physical_parameters_t) :: p1(1), p2(1)
    type(fmr_b110_physical_forcing_t) :: f1(2), f2(2)
    type(kernel_committed_state_t) :: s1(2), s2(2)
    type(canonical_numerical_config_t) :: cfg1, cfg2
    type(fmr_serialized_column_result_t), allocatable :: r1(:), r2(:)
    type(fmr_column_diagnostics_t), allocatable :: d1(:), d2(:)
    type(fmr_aggregate_diagnostics_t) :: a1, a2
    type(fmr_divdra_serialized_column_request_t) :: req(2)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(2)
    type(fmr_divdra_binding_diagnostics_t) :: bd
    type(fmr04_fixed_flux_top_provider_t), target :: top
    real(real64), parameter :: q(2)=[0.011_real64,0.023_real64]
    real(real64), allocatable :: row(:)
    integer :: dispatch1,dispatch2,compose,k

    call initialize_two(c1,t1,p1,f1,s1,cfg1)
    call initialize_two(c2,t2,p2,f2,s2,cfg2)
    call configure_distribution(dp(1))
    call configure_view(hv(1),-0.35_real64)
    call configure_view(hv(2),-1.55_real64)
    do k=1,2
      deallocate(f1(k)%drainage_flux_by_level,f2(k)%drainage_flux_by_level)
      call fmr_bind_single_level_positive_divdra(dp(1),hv(k),q(k),f1(k)%drainage_flux_by_level,bd)
      call require(bd%status==FMR_DIVDRA_BIND_OK,'two-column manual bind')
      allocate(row(numnod)); row=f1(k)%drainage_flux_by_level(1,:)
      f1(k)%subsurface_irrigation_source=row
      f2(k)%subsurface_irrigation_source=row
      deallocate(row)
      req(k)=fmr_divdra_serialized_column_request_t()
      req(k)%column_id=c2(k)%column_id; req(k)%active=.true.
      req(k)%distribution_parameter_ref=1_int64; req(k)%hydraulic_view_ref=int(k,int64); req(k)%scalar_transfer=q(k)
    end do

    call reset_legacy()
    call fmr_run_serialized_physical_multiswap(c1,t1,p1,f1,s1,cfg1,top,qa_t0,qa_t1,2,r1,d1,a1,dispatch1)
    call require(dispatch1==FMR_SERIAL_DISPATCH_OK .and. all(r1%committed),'two-column manual committed')
    call reset_legacy()
    call fmr_run_serialized_physical_multiswap_with_divdra(c2,t2,p2,f2,s2,cfg2,top,qa_t0,qa_t1,2, &
         req,dp,hv,r2,d2,a2,dispatch2,compose,records)
    call require(dispatch2==FMR_SERIAL_DISPATCH_OK .and. compose==FMR_DIVDRA_COMPOSE_OK,'two-column active dispatch')
    call require(all(r2%committed) .and. size(records)==2,'two-column active committed')
    do k=1,2
      call require(records(k)%column_id==c2(k)%column_id .and. records(k)%column_index==k,'record column identity')
      call require(same_bits(records(k)%binding%authoritative_scalar_transfer,q(k)),'record scalar identity')
      call require(same_result(r1(k),r2(k)),'two-column result equivalence')
      call require(state_fingerprint(s1(k))==state_fingerprint(s2(k)),'two-column state equivalence')
      call require(.not.allocated(f2(k)%drainage_flux_by_level),'two-column forcing restored')
    end do
    call require(records(1)%binding%process%water_table_node /= records(2)%binding%process%water_table_node, &
         'two-column distinct explicit views retained')
    write(*,'(A)') 'FVQ51_TWO_ACTIVE_COLUMNS_NO_CROSS_CONTAMINATION=PASS'
  end subroutine verify_two_active_columns

  subroutine verify_fail_closed_matrix()
    type(fmr_logical_column_t) :: c(2)
    type(fmr_template_t) :: t(1)
    type(fmr_b110_physical_parameters_t) :: p(1)
    type(fmr_b110_physical_forcing_t) :: f(2)
    type(kernel_committed_state_t) :: s(2)
    type(canonical_numerical_config_t) :: cfg
    type(fmr_serialized_column_result_t), allocatable :: r(:)
    type(fmr_column_diagnostics_t), allocatable :: d(:)
    type(fmr_aggregate_diagnostics_t) :: a
    type(fmr_divdra_serialized_column_request_t), allocatable :: req(:)
    type(fmr_divdra_serialized_binding_record_t), allocatable :: records(:)
    type(drainage_distribution_parameters_t) :: dp(1)
    type(process_hydraulic_view_t) :: hv(1)
    type(fmr04_fixed_flux_top_provider_t), target :: top
    integer :: dispatch,compose

    call configure_distribution(dp(1)); call configure_view(hv(1),-0.45_real64)

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(1)); call make_request(req(1),c(1)%column_id,0.01_real64)
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_INVALID_SHAPE .and. dispatch==FMR_SERIAL_DISPATCH_INVALID_REQUEST, &
         'request shape rejection')
    call require(all_zero_revisions(s),'shape rejection premutation')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),999999_int64,0.01_real64); req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_COLUMN_ID_MISMATCH .and. all_zero_revisions(s),'column id premutation reject')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,-0.01_real64); req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. all_zero_revisions(s),'negative premutation reject')
    call require(.not.allocated(f(1)%drainage_flux_by_level),'negative no forcing mutation')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,1.0e-10_real64); req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. all_zero_revisions(s),'restricted seam premutation reject')

    call initialize_two(c,t,p,f,s,cfg)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,0.01_real64); req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_BIND_REJECTED .and. all_zero_revisions(s),'preallocated target premutation reject')
    call require(all(f(1)%drainage_flux_by_level==0.0_real64),'preallocated target unchanged')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    c(2)%forcing_handle=1_int64
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,0.01_real64); req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_SHARED_FORCING_HANDLE .and. all_zero_revisions(s),'shared forcing premutation reject')
    call require(.not.allocated(f(1)%drainage_flux_by_level),'shared forcing no mutation')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,0.01_real64); req(1)%distribution_parameter_ref=2_int64; req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_INVALID_PARAMETER_REF .and. all_zero_revisions(s),'parameter ref premutation reject')

    call initialize_two(c,t,p,f,s,cfg)
    deallocate(f(1)%drainage_flux_by_level)
    allocate(req(2)); req=fmr_divdra_serialized_column_request_t()
    call make_request(req(1),c(1)%column_id,0.01_real64); req(1)%hydraulic_view_ref=2_int64; req(2)%column_id=c(2)%column_id
    call fmr_run_serialized_physical_multiswap_with_divdra(c,t,p,f,s,cfg,top,qa_t0,qa_t1,2,req,dp,hv, &
         r,d,a,dispatch,compose,records)
    call require(compose==FMR_DIVDRA_COMPOSE_INVALID_HYDRAULIC_VIEW_REF .and. all_zero_revisions(s),'view ref premutation reject')

    write(*,'(A)') 'FVQ51_FAIL_CLOSED_PREMUTATION_MATRIX=PASS'
  end subroutine verify_fail_closed_matrix

  subroutine initialize_one(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), intent(out) :: c(1)
    type(fmr_template_t), intent(out) :: t(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: p(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: f(1)
    type(kernel_committed_state_t), intent(out) :: s(1)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: k0
    logical :: ok
    call configure_parameters(p(1),state,k0)
    call configure_template(t(1)); call configure_column(c(1),id1,1_int64,t(1))
    call configure_forcing(f(1),k0); call configure_config(cfg)
    call fmr_new_b110_committed_state(s(1),id1,state,qa_t0,ok); call require(ok,'one state init')
  end subroutine initialize_one

  subroutine initialize_two(c,t,p,f,s,cfg)
    type(fmr_logical_column_t), intent(out) :: c(2)
    type(fmr_template_t), intent(out) :: t(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: p(1)
    type(fmr_b110_physical_forcing_t), intent(out) :: f(2)
    type(kernel_committed_state_t), intent(out) :: s(2)
    type(canonical_numerical_config_t), intent(out) :: cfg
    type(fmr_b110_physical_state_t) :: state
    real(real64) :: k0
    logical :: ok
    call configure_parameters(p(1),state,k0); call configure_template(t(1)); call configure_config(cfg)
    call configure_column(c(1),id1,1_int64,t(1)); call configure_column(c(2),id2,2_int64,t(1))
    call configure_forcing(f(1),k0); call configure_forcing(f(2),k0)
    call fmr_new_b110_committed_state(s(1),id1,state,qa_t0,ok); call require(ok,'two state 1')
    call fmr_new_b110_committed_state(s(2),id2,state,qa_t0,ok); call require(ok,'two state 2')
  end subroutine initialize_two

  subroutine configure_template(t)
    type(fmr_template_t), intent(out) :: t
    t%template_id=510_int64; t%physics_topology_id=51011_int64; t%vertical_layout_id=51012_int64
    t%state_layout_id=51013_int64; t%solver_interface_id=51014_int64; t%optional_state_layout_id=51015_int64
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_column(c,id,state_handle,t)
    type(fmr_logical_column_t), intent(out) :: c
    integer(int64), intent(in) :: id,state_handle
    type(fmr_template_t), intent(in) :: t
    c%column_id=id; c%template_id=t%template_id; c%parameter_ref=1_int64
    c%state_handle=state_handle; c%forcing_handle=state_handle; c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k
    p%parameter_set_id=51001_int64; p%active_nodes=numnod
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
    call bind_b110_default_mvg_provider(provider,hp,qa_t1-qa_t0)
    heads=qa_head; call provider%evaluate(heads,water,conductivity,capacity,dkdh); k0=conductivity(1)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.25_real64
  end subroutine configure_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux=-k0; f%top_head=qa_head; f%bottom_flux=-k0; f%bottom_head=-321.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine configure_forcing

  subroutine configure_distribution(dp)
    type(drainage_distribution_parameters_t), intent(out) :: dp
    real(real64) :: depth
    integer :: k
    dp%active_nodes=numnod
    allocate(dp%dz(numnod),dp%zbotcp(numnod),dp%saturated_conductivity(numnod),dp%horizontal_anisotropy_factor(numnod))
    dp%dz=dz; depth=0.0_real64
    do k=1,numnod
      depth=depth+dz(k); dp%zbotcp(k)=-depth
    end do
    dp%saturated_conductivity=[1.0_real64,2.5_real64,0.7_real64,4.0_real64]
    dp%horizontal_anisotropy_factor=[1.2_real64,0.8_real64,1.5_real64,0.6_real64]
    dp%drain_spacing=7.3_real64
  end subroutine configure_distribution

  subroutine configure_view(hv,gwl)
    type(process_hydraulic_view_t), intent(out) :: hv
    real(real64), intent(in) :: gwl
    hv%active_nodes=numnod; allocate(hv%pressure_head(numnod),hv%water_content(numnod))
    hv%pressure_head=[-45.0_real64,-90.0_real64,-180.0_real64,-360.0_real64]
    hv%water_content=[0.31_real64,0.29_real64,0.27_real64,0.25_real64]
    hv%ponding_depth=0.013_real64; hv%groundwater_level=gwl
  end subroutine configure_view

  subroutine configure_config(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64; cfg%transaction%mass_tolerance=mass_gate
    cfg%transaction%retry_scale=0.5_real64; cfg%transaction%max_retries=2
    cfg%max_committed_substeps=8; cfg%progress_tolerance=0.0_real64
  end subroutine configure_config

  subroutine make_request(req,id,q)
    type(fmr_divdra_serialized_column_request_t), intent(out) :: req
    integer(int64), intent(in) :: id
    real(real64), intent(in) :: q
    req=fmr_divdra_serialized_column_request_t(); req%column_id=id; req%active=.true.
    req%distribution_parameter_ref=1_int64; req%hydraulic_view_ref=1_int64; req%scalar_transfer=q
  end subroutine make_request

  subroutine reset_legacy()
    legacy_qdra=88888.0_real64; legacy_qssdi=-77777.0_real64; legacy_qrot=66666.0_real64
    swmacro=0; legacy_melt=0.0_real64
  end subroutine reset_legacy

  logical function all_zero_revisions(s) result(ok)
    type(kernel_committed_state_t), intent(in) :: s(:)
    integer :: k
    ok=.true.
    do k=1,size(s)
      if (s(k)%current_revision()/=0_int64) then
        ok=.false.; return
      end if
    end do
  end function all_zero_revisions

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

  integer(int64) function state_fingerprint(state) result(fp)
    type(kernel_committed_state_t), intent(in) :: state
    class(transaction_state_t), allocatable :: snapshot
    logical :: got
    integer :: k
    call state%snapshot(snapshot,got); call require(got,'state snapshot')
    fp=1469598103934665603_int64
    select type (physical=>snapshot)
    type is (fmr_b110_physical_state_t)
      fp=ieor(fp,int(physical%active_nodes,int64))
      do k=1,physical%active_nodes
        fp=ieor(fp,transfer(physical%pressure_head(k),fp)); fp=ieor(fp,transfer(physical%water_content(k),fp))
      end do
      fp=ieor(fp,transfer(physical%ponding_depth,fp)); fp=ieor(fp,transfer(physical%groundwater_level,fp))
    class default
      error stop 'FVQ51 unexpected state type'
    end select
  end function state_fingerprint

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not.condition) then
      write(*,'(A,1X,A)') 'FVQ51_TEST_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fvq51_divdra_active_runtime_callsite
