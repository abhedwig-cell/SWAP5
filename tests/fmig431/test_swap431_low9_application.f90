program test_swap431_low9_application
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_EXTERNAL_FULL_HALF
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  real(real64), parameter :: t0=6200.0_real64,t1=6200.25_real64,mass_tol=1.0e-12_real64
  type(fmr_production_application_config_t) :: cfg,bad
  type(fmr_production_application_bootstrap_t) :: app,badapp
  type(fmr_serialized_column_result_t),allocatable :: result(:)
  integer :: status,j
  integer(int64),allocatable :: revisions(:)

  call initialize_config(cfg)
  call app%initialize(cfg,status)
  call require(status==FMR_APP_BOOT_OK .and. app%ready(),'mode9 bootstrap admitted')
  call app%run_standalone(t0,t1,result,status)
  call require(status==FMR_APP_BOOT_OK,'mode9 standalone status')
  call require(size(result)==1 .and. result(1)%completed .and. result(1)%committed,'mode9 transaction committed')
  call require(result(1)%mass%complete .and. abs(result(1)%mass%residual)<=mass_tol,'mode9 hard mass closure')
  call require(result(1)%solver_executed,'mode9 solver executed')
  call require(result(1)%accepted_substeps==1,'mode9 equilibrium one accepted substep')
  call app%copy_committed_revisions(revisions,status)
  call require(status==FMR_APP_BOOT_OK .and. all(revisions==1_int64),'mode9 one external commit')
  call app%close(status)
  print '(a)', 'SW431_LOW9_APPLICATION_TRANSACTION=PASS'

  do j=1,5
    bad=cfg
    select case(j)
    case(1); bad%tiles(1)%parameters%bottom_mode=8
    case(2); bad%tiles(1)%parameters%swkimpl=1
    case(3); bad%tiles(1)%parameters%macropore_active=.true.
    case(4); bad%tiles(1)%ordinary_lysimeter_plate=.true.
    case(5); bad%tiles(1)%base_forcing%bottom_head=huge(1.0_real64)
    end select
    call badapp%initialize(bad,status)
    call require(status/=FMR_APP_BOOT_OK .and. .not.badapp%ready(),'mode9 unsupported profile fail closed')
    call badapp%close(status)
  end do
  print '(a)', 'SW431_LOW9_APPLICATION_FAIL_CLOSED=PASS'
  print '(a)', 'SW431_LOW9_APPLICATION_GATE=PASS'
contains
  subroutine initialize_config(value)
    type(fmr_production_application_config_t),intent(out)::value
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),k(numnod),cap(numnod),dkdh(numnod)
    integer::i
    value%initial_time=t0
    value%numerical%transaction%temporal_mode=TX_TEMPORAL_EXTERNAL_FULL_HALF
    value%numerical%transaction%temporal_tolerance=1.0e-10_real64
    value%numerical%transaction%mass_tolerance=mass_tol
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=4
    value%numerical%max_committed_substeps=16
    allocate(value%tiles(1))
    value%tiles(1)%ordinary_simultaneous_head_flux=.true.
    value%tiles(1)%tile_id=990001_int64
    value%tiles(1)%ledger_id=0_int64
    value%tiles(1)%template%template_id=990101_int64
    value%tiles(1)%template%physics_topology_id=990102_int64
    value%tiles(1)%template%vertical_layout_id=990103_int64
    value%tiles(1)%template%state_layout_id=990104_int64
    value%tiles(1)%template%solver_interface_id=990105_int64
    value%tiles(1)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    value%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    value%tiles(1)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    value%tiles(1)%parameters%parameter_set_id=990201_int64
    value%tiles(1)%parameters%active_nodes=numnod
    allocate(value%tiles(1)%parameters%z(numnod),value%tiles(1)%parameters%dz(numnod), &
         value%tiles(1)%parameters%node_distance(numnod),value%tiles(1)%parameters%cofgen(24,numnod))
    value%tiles(1)%parameters%z=z;value%tiles(1)%parameters%dz=dz
    value%tiles(1)%parameters%node_distance=disnod(1:numnod);value%tiles(1)%parameters%cofgen=0.0_real64
    do i=1,numnod
      value%tiles(1)%parameters%cofgen(1,i)=0.032_real64
      value%tiles(1)%parameters%cofgen(2,i)=0.423_real64
      value%tiles(1)%parameters%cofgen(3,i)=4.75_real64
      value%tiles(1)%parameters%cofgen(4,i)=0.0135_real64
      value%tiles(1)%parameters%cofgen(5,i)=0.365_real64
      value%tiles(1)%parameters%cofgen(6,i)=1.455_real64
      value%tiles(1)%parameters%cofgen(7,i)=1.0_real64-1.0_real64/value%tiles(1)%parameters%cofgen(6,i)
      value%tiles(1)%parameters%cofgen(8,i)=value%tiles(1)%parameters%cofgen(4,i)
      value%tiles(1)%parameters%cofgen(10,i)=value%tiles(1)%parameters%cofgen(3,i)
      value%tiles(1)%parameters%cofgen(11,i)=0.999_real64
      value%tiles(1)%parameters%cofgen(12,i)=0.99_real64*value%tiles(1)%parameters%cofgen(3,i)
      value%tiles(1)%parameters%cofgen(22,i)=-1.0e6_real64
      value%tiles(1)%parameters%cofgen(23,i)=1.0e-12_real64
    end do
    value%tiles(1)%parameters%bottom_mode=9
    value%tiles(1)%parameters%swkimpl=0;value%tiles(1)%parameters%swkmean=1;value%tiles(1)%parameters%swsophy=0
    value%tiles(1)%parameters%max_iterations=32;value%tiles(1)%parameters%max_backtracking=16
    value%tiles(1)%parameters%min_step_duration=1.0e-10_real64
    value%tiles(1)%parameters%compartment_balance_tolerance=1.0e-10_real64
    value%tiles(1)%parameters%total_balance_tolerance=1.0e-10_real64
    value%tiles(1)%parameters%head_abs_tolerance=1.0e-10_real64
    value%tiles(1)%parameters%head_rel_tolerance=1.0e-10_real64
    value%tiles(1)%parameters%ponding_tolerance=1.0e-10_real64
    heads=-2.5_real64-z
    call initialize_b110_default_mvg_parameters(hp,value%tiles(1)%parameters%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,t1-t0)
    call provider%evaluate(heads,water,k,cap,dkdh)
    value%tiles(1)%initial_state%active_nodes=numnod
    allocate(value%tiles(1)%initial_state%pressure_head(numnod),value%tiles(1)%initial_state%water_content(numnod))
    value%tiles(1)%initial_state%pressure_head=heads;value%tiles(1)%initial_state%water_content=water
    value%tiles(1)%initial_state%ponding_depth=0.0_real64;value%tiles(1)%initial_state%groundwater_level=-2.5_real64
    value%tiles(1)%base_forcing%top_flux=0.0_real64;value%tiles(1)%base_forcing%top_head=heads(1)
    value%tiles(1)%base_forcing%bottom_flux=0.0_real64;value%tiles(1)%base_forcing%bottom_head=0.5_real64
    allocate(value%tiles(1)%base_forcing%drainage_flux_by_level(1,numnod), &
         value%tiles(1)%base_forcing%subsurface_irrigation_source(numnod),value%tiles(1)%base_forcing%root_extraction_sink(numnod))
    value%tiles(1)%base_forcing%drainage_flux_by_level=0.0_real64
    value%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
    value%tiles(1)%base_forcing%root_extraction_sink=0.0_real64
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      write(*,'(a,1x,a)') 'LOW9_APP_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
