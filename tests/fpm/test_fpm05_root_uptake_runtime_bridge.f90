program test_fpm05_root_uptake_runtime_bridge
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
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_request_t, &
       root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t, evaluate_macro_feddes_drought_uptake, &
       ROOT_UPTAKE_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr04_fixed_top_provider, only: fmr04_fixed_flux_top_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 2500.25_real64
  real(real64), parameter :: t1 = 2500.75_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64

  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1)
  type(fmr_b110_physical_parameters_t) :: physical_parameters(1)
  type(fmr_b110_physical_forcing_t) :: forcing_control(1), forcing_bridge(1)
  type(fmr_b110_physical_state_t) :: initial_state
  type(kernel_committed_state_t) :: state_control(1), state_bridge(1)
  type(process_hydraulic_view_t) :: committed_view
  type(root_water_uptake_parameters_t) :: process_parameters
  type(root_water_uptake_request_t) :: process_request
  type(root_water_uptake_flux_result_t) :: process_fluxes
  type(root_water_uptake_diagnostics_t) :: process_diagnostics
  type(fmr_serialized_column_result_t), allocatable :: result_control(:), result_bridge(:)
  type(fmr_column_diagnostics_t), allocatable :: diag_control(:), diag_bridge(:)
  type(fmr_aggregate_diagnostics_t) :: aggregate_control, aggregate_bridge
  type(fmr_serialized_batch_diagnostics_t) :: run_control, run_bridge
  type(fmr04_fixed_flux_top_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  real(real64) :: conductivity0, expected_amount, in_delta, out_delta, tolerance
  integer :: dispatch_control, dispatch_bridge
  logical :: ok

  call configure_physical_parameters(physical_parameters(1),initial_state,conductivity0)
  physical_parameters(1)%root_extraction_active=.true.
  call configure_column(columns(1),templates(1))
  call configure_forcing(forcing_control(1),conductivity0)
  forcing_bridge(1)=forcing_control(1)
  call configure_transaction(config)

  call fmr_new_b110_committed_state(state_control(1),columns(1)%column_id,initial_state,t0,ok)
  call require(ok,'control state init')
  call fmr_new_b110_committed_state(state_bridge(1),columns(1)%column_id,initial_state,t0,ok)
  call require(ok,'bridge state init')

  call fmr_build_committed_process_hydraulic_view(state_bridge(1),committed_view,ok)
  call require(ok,'qualified committed hydraulic view available')
  call configure_process_parameters(process_parameters)
  call configure_process_request(process_request)
  call evaluate_macro_feddes_drought_uptake(process_parameters,committed_view,process_request, &
       process_fluxes,process_diagnostics)
  call require(process_diagnostics%status==ROOT_UPTAKE_OK .and. process_diagnostics%evaluated, &
       'process evaluation admitted')
  call require(size(process_fluxes%root_extraction_sink)==numnod,'process result shape')
  call require(all(process_fluxes%root_extraction_sink>=0.0_real64),'process result sign')
  call require(abs(process_fluxes%actual_uptake_total-process_request%potential_transpiration) <= &
       512.0_real64*epsilon(1.0_real64), 'unstressed uptake equals ptra')

  forcing_bridge(1)%root_extraction_sink=process_fluxes%root_extraction_sink
  forcing_bridge(1)%subsurface_irrigation_source=process_fluxes%root_extraction_sink
  expected_amount=process_fluxes%actual_uptake_total*(t1-t0)
  tolerance=512.0_real64*epsilon(1.0_real64)*max(1.0_real64,expected_amount)

  call poison_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns,templates,physical_parameters,forcing_control,state_control,config, &
       top_provider,t0,t1,1,result_control,diag_control,aggregate_control,dispatch_control,run_control)
  call poison_legacy_globals()
  call fmr_run_serialized_physical_multiswap(columns,templates,physical_parameters,forcing_bridge,state_bridge,config, &
       top_provider,t0,t1,1,result_bridge,diag_bridge,aggregate_bridge,dispatch_bridge,run_bridge)

  call require(dispatch_control==FMR_SERIAL_DISPATCH_OK .and. dispatch_bridge==FMR_SERIAL_DISPATCH_OK, &
       'runtime dispatch')
  call require(result_control(1)%completed .and. result_control(1)%committed,'control commit')
  call require(result_bridge(1)%completed .and. result_bridge(1)%committed,'bridge commit')
  call require(result_control(1)%mass%complete .and. result_bridge(1)%mass%complete,'mass complete')
  call require(result_control(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE .and. &
       result_bridge(1)%mass%missing_contribution_mask==TX_MASS_MISSING_NONE,'mass mask complete')
  call require(abs(result_control(1)%mass%residual)<=hard_mass_gate .and. &
       abs(result_bridge(1)%mass%residual)<=hard_mass_gate,'hard mass gate')
  call require(committed_physics_identical(state_control(1),state_bridge(1)), &
       'balanced process root sink and qssdi preserve hydraulic state')

  in_delta=result_bridge(1)%mass%total_in-result_control(1)%mass%total_in
  out_delta=result_bridge(1)%mass%total_out-result_control(1)%mass%total_out
  call require(abs(in_delta-expected_amount)<=tolerance,'process bridge qssdi total_in exactly once')
  call require(abs(out_delta-expected_amount)<=tolerance,'process bridge qrot total_out exactly once')
  call require(abs(run_bridge%authoritative_aggregate_mass%residual)<=hard_mass_gate,'aggregate hard mass')
  call require(abs(run_bridge%authoritative_aggregate_mass%total_out-result_bridge(1)%mass%total_out)<=tolerance, &
       'aggregate root total_out not double booked')

  write(*,'(A,1X,ES24.16)') 'FPM05_PROCESS_ACTUAL_UPTAKE_RATE=',process_fluxes%actual_uptake_total
  write(*,'(A,1X,ES24.16)') 'FPM05_PROCESS_EXPECTED_ROOT_AMOUNT=',expected_amount
  write(*,'(A,1X,ES24.16)') 'FPM05_PROCESS_OBSERVED_TOTAL_OUT_DELTA=',out_delta
  write(*,'(A)') 'FPM05_COMMITTED_HYDRAULIC_VIEW_PROCESS_READ=PASS'
  write(*,'(A)') 'FPM05_DYNAMIC_ROOT_DISTRIBUTION_RUNTIME_INPUT=PASS'
  write(*,'(A)') 'FPM05_PROCESS_QROT_RUNTIME_BRIDGE=PASS'
  write(*,'(A)') 'FPM05_PROCESS_ROOT_MASS_EXACTLY_ONCE=PASS'
  write(*,'(A)') 'FPM05_PROCESS_BRIDGE_HARD_MASS=PASS'
  write(*,'(A)') 'FPM05_PROCESS_RUNTIME_BRIDGE_TEST PASS'

contains

  subroutine configure_column(column,template)
    type(fmr_logical_column_t), intent(out) :: column
    type(fmr_template_t), intent(out) :: template
    template%template_id=905_int64
    template%physics_topology_id=90501_int64
    template%vertical_layout_id=90502_int64
    template%state_layout_id=90503_int64
    template%solver_interface_id=90504_int64
    template%optional_state_layout_id=90505_int64
    template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    column%column_id=905001_int64
    column%template_id=template%template_id
    column%parameter_ref=1_int64
    column%state_handle=1_int64
    column%forcing_handle=1_int64
    column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_process_parameters(p)
    type(root_water_uptake_parameters_t), intent(out) :: p
    p%active_nodes=numnod
    p%hlim3l=-800.0_real64
    p%hlim3h=-500.0_real64
    p%hlim4=-16000.0_real64
    p%adcrl=0.1_real64
    p%adcrh=0.5_real64
  end subroutine configure_process_parameters

  subroutine configure_process_request(r)
    type(root_water_uptake_request_t), intent(out) :: r
    integer :: k
    r%potential_transpiration=0.08_real64
    r%rooted_nodes=numnod
    allocate(r%cumulative_root_fraction(numnod+1))
    do k=1,numnod+1
      r%cumulative_root_fraction(k)=real(k-1,real64)/real(numnod,real64)
    end do
  end subroutine configure_process_request

  subroutine configure_physical_parameters(p,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    integer :: k

    p%parameter_set_id=90501_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z
    p%dz=dz
    p%node_distance=disnod(1:numnod)
    p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64
      p%cofgen(2,k)=0.423_real64
      p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64
      p%cofgen(5,k)=0.365_real64
      p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k)
      p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64
      p%cofgen(10,k)=p%cofgen(3,k)
      p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k)
      p%cofgen(22,k)=-1.0e6_real64
      p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=7
    p%swkimpl=0
    p%swkmean=1
    p%swsophy=0
    p%root_extraction_active=.false.
    p%macropore_active=.false.
    p%snow_active=.false.
    p%hysteresis_active=.false.
    p%tabulated_hydraulics_active=.false.
    p%elasticity_active=.false.
    p%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hp,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads
    state%water_content=water
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
  end subroutine configure_physical_parameters

  subroutine configure_forcing(f,k0)
    type(fmr_b110_physical_forcing_t), intent(out) :: f
    real(real64), intent(in) :: k0
    f%top_flux=-k0
    f%top_head=head0
    f%bottom_flux=-k0
    f%bottom_head=-100.0_real64
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine configure_forcing

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t), intent(out) :: cfg
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=2
    cfg%max_committed_substeps=8
    cfg%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine poison_legacy_globals()
    legacy_qdra=12345.0_real64
    legacy_qssdi=-54321.0_real64
    legacy_qrot=-99999.0_real64
    swmacro=0
    legacy_melt=0.0_real64
  end subroutine poison_legacy_globals

  logical function committed_physics_identical(a,b) result(equal)
    type(kernel_committed_state_t), intent(in) :: a,b
    class(transaction_state_t), allocatable :: sa,sb
    logical :: oka,okb
    integer :: k
    equal=.false.
    call a%snapshot(sa,oka)
    call b%snapshot(sb,okb)
    if (.not. oka .or. .not. okb) return
    select type (pa=>sa)
    type is (fmr_b110_physical_state_t)
      select type (pb=>sb)
      type is (fmr_b110_physical_state_t)
        if (pa%active_nodes/=pb%active_nodes) return
        if (.not. allocated(pa%pressure_head) .or. .not. allocated(pb%pressure_head)) return
        if (.not. allocated(pa%water_content) .or. .not. allocated(pb%water_content)) return
        do k=1,pa%active_nodes
          if (.not. same_bits(pa%pressure_head(k),pb%pressure_head(k))) return
          if (.not. same_bits(pa%water_content(k),pb%water_content(k))) return
        end do
        if (.not. same_bits(pa%ponding_depth,pb%ponding_depth)) return
        if (.not. same_bits(pa%groundwater_level,pb%groundwater_level)) return
        equal=.true.
      end select
    end select
  end function committed_physics_identical

  logical function same_bits(a,b) result(equal)
    real(real64), intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia)
    ib=transfer(b,ib)
    equal=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FPM05_RUNTIME_BRIDGE_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpm05_root_uptake_runtime_bridge
