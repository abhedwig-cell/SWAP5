program groundwater_runtime_driver
  use, intrinsic :: iso_c_binding, only: c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_fmr_runtime_core, only: fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_RUTTER
  use mod_interception_source_window_runtime, only: interception_source_window_t, initialize_interception_window, INTWIN_OK
  use mod_rutter_interception_process, only: rutter_interval_input_t
  use mod_root_uptake_compensation, only: ROOT_COMP_OFF
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_b110_physical_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK, FMR_APP_BOOT_PROFILE_NOT_ADMITTED
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fmr_groundwater_application_c_api, only: fgc49d_context_counts_c, fgc49d_capture_origins_c, &
       fgc49d_abort_prepublication_c
  use mod_kernel_transactions,only:kernel_committed_state_t
  use mod_kernel_committed_persistence,only:kernel_persistence_snapshot_t, &
       export_kernel_committed_state,restore_kernel_committed_state,KERNEL_PERSISTENCE_OK
  use mod_transaction_reference,only:transaction_state_t
  implicit none
  integer,parameter::NTILE=1
  real(real64),parameter::T0=0d0,T1=.01d0,H0_CM=-1d0,HARD_MASS_GATE=1d-10
  type(fmr_production_application_config_t)::config,bad_config
  type(fmr_production_application_bootstrap_t)::app,bad_app
  type(fmr_serialized_column_result_t),allocatable::results(:)
  integer(int64),allocatable::revisions(:)
  integer::status
  type(kernel_committed_state_t)::before,after,restored
  type(kernel_persistence_snapshot_t)::persisted
  class(transaction_state_t),allocatable::before_state,after_state,restored_state
  logical::available
  call initialize_application_config(config)
  bad_config=config;bad_config%tiles(1)%parameters%prescribed_groundwater_active=.false.
  call bad_app%initialize(bad_config,status)
  call require(status/=FMR_APP_BOOT_OK,'groundwater default off')
  call app%initialize(config,status)
  write(*,*)'BOOT',status
  call require(status==FMR_APP_BOOT_OK,'groundwater production bootstrap')
  call app%run_standalone(T0,T1,results,status)
  write(*,*)'RUN',status
  if(allocated(results))then
   write(*,*)'ADMISSION',trim(results(1)%admission_status),results(1)%kernel_status
   write(*,*)'COMMIT',results(1)%completed,results(1)%committed,results(1)%accepted_substeps
   write(*,*)'SOLVER',results(1)%solver_status,trim(results(1)%solver_route),results(1)%solver_rejections
   write(*,*)'REJECTIONS',results(1)%temporal_rejections,results(1)%mass_rejections
  end if
  call require(status==FMR_APP_BOOT_OK,'groundwater production run')
  call require(all(results%completed).and.all(results%committed),'groundwater publication')
  call require(maxval(abs(results%mass%residual))<HARD_MASS_GATE,'groundwater transaction mass')
  call app%copy_committed_revisions(revisions,status)
  call require(status==FMR_APP_BOOT_OK.and.all(revisions==1_int64),'owner revision')
  call app%copy_committed_for_crop(1,before,status)
  call require(status==FMR_APP_BOOT_OK,'copy accepted owner')
  call before%snapshot(before_state,available)
  call require(available,'accepted physical snapshot')
  call export_kernel_committed_state(before,610230_int64,persisted,available,status)
  call require(available.and.status==KERNEL_PERSISTENCE_OK,'accepted owner export')
  call restore_kernel_committed_state(persisted,610230_int64,restored,available,status)
  call require(available.and.status==KERNEL_PERSISTENCE_OK,'accepted owner restore')
  call require(restored%current_revision()==before%current_revision(),'restored revision')
  call restored%snapshot(restored_state,available)
  call require(available,'restored physical snapshot')
  call same_physical(before_state,restored_state)
  call app%run_standalone(T0,T1,results,status)
  call require(status/=FMR_APP_BOOT_OK,'stale interval rejected')
  call app%copy_committed_revisions(revisions,status)
  call require(all(revisions==1_int64),'rejected trial rollback revision')
  call app%copy_committed_for_crop(1,after,status)
  call require(status==FMR_APP_BOOT_OK,'copy rejected interval owner')
  call after%snapshot(after_state,available)
  call require(available,'rejected interval physical snapshot')
  call same_physical(before_state,after_state)
  call app%close(status)
  call require(status==FMR_APP_BOOT_OK,'owner close')
  write(*,*)'GROUNDWATER_FMR_TRANSACTION_PASS'
contains
  subroutine same_physical(a,b)
    class(transaction_state_t),intent(in)::a,b
    select type(a)
    type is(fmr_b110_physical_state_t)
      select type(b)
      type is(fmr_b110_physical_state_t)
        call require(a%active_nodes==b%active_nodes,'snapshot nodes')
        call require(all(transfer(a%pressure_head,[0_int64],a%active_nodes)== &
             transfer(b%pressure_head,[0_int64],b%active_nodes)),'snapshot pressure bits')
        call require(all(transfer(a%water_content,[0_int64],a%active_nodes)== &
             transfer(b%water_content,[0_int64],b%active_nodes)),'snapshot water bits')
        call require(transfer(a%groundwater_level,0_int64)==transfer(b%groundwater_level,0_int64),'snapshot groundwater bits')
        call require(transfer(a%ponding_depth,0_int64)==transfer(b%ponding_depth,0_int64),'snapshot pond bits')
      class default
        error stop 'wrong restored state'
      end select
    class default
      error stop 'wrong accepted state'
    end select
  end subroutine
  subroutine initialize_application_config(value)
    type(fmr_production_application_config_t), intent(out) :: value
    real(real64) :: conductivity0
    integer :: k

    value%initial_time = T0
    value%numerical%transaction%temporal_tolerance = 1.0e-4_real64
    value%numerical%transaction%mass_tolerance = HARD_MASS_GATE
    value%numerical%transaction%retry_scale = 0.5_real64
    value%numerical%transaction%max_retries = 32
    value%numerical%max_committed_substeps = 512
    value%numerical%progress_tolerance = 0.0_real64

    allocate(value%tiles(NTILE))
    do k = 1, NTILE
      value%tiles(k)%tile_id = 610100_int64 + int(k, int64)
      value%tiles(k)%ledger_id = 710100_int64 + int(k, int64)
      value%tiles(k)%template%template_id = 610200_int64 + int(k, int64)
      value%tiles(k)%template%physics_topology_id = 610210_int64
      value%tiles(k)%template%vertical_layout_id = 610220_int64
      value%tiles(k)%template%state_layout_id = 610230_int64
      value%tiles(k)%template%solver_interface_id = 610240_int64
      value%tiles(k)%template%optional_state_layout_id = 0_int64
      value%tiles(k)%template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
      value%tiles(k)%template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE

      call initialize_parameters(value%tiles(k)%parameters, 620000_int64 + int(k, int64))
      call initialize_state_and_forcing(value%tiles(k)%parameters, value%tiles(k)%initial_state, &
           value%tiles(k)%base_forcing, 1.0_real64 + 0.013_real64 * real(k, real64), conductivity0)
      value%tiles(k)%initial_state%groundwater_level = -1.5d0 - 0.007_real64 * real(k, real64)

      value%tiles(k)%groundwater_datum%available = .true.
      value%tiles(k)%groundwater_datum%datum_id = 630000_int64 + int(k, int64)
      value%tiles(k)%groundwater_datum%bottom_boundary_elevation_m = 0.0_real64
    end do
  end subroutine initialize_application_config

  subroutine initialize_parameters(p, parameter_id)
    type(fmr_b110_physical_parameters_t), intent(out) :: p
    integer(int64), intent(in) :: parameter_id
    integer :: k

    p%parameter_set_id = parameter_id
    p%active_nodes = numnod
    allocate(p%z(numnod), p%dz(numnod), p%node_distance(numnod), p%cofgen(24, numnod))
    p%z = z
    p%dz = dz
    p%node_distance(1)=.5d0*dz(1)
    p%node_distance(2:numnod)=z(1:numnod-1)-z(2:numnod)
    p%cofgen = 0.0_real64
    do k = 1, numnod
      p%cofgen(1,k) = 0.032_real64
      p%cofgen(2,k) = 0.423_real64
      p%cofgen(3,k) = 4.75_real64
      p%cofgen(4,k) = 0.0135_real64
      p%cofgen(5,k) = 0.365_real64
      p%cofgen(6,k) = 1.455_real64
      p%cofgen(7,k) = 1.0_real64 - 1.0_real64 / p%cofgen(6,k)
      p%cofgen(8,k) = p%cofgen(4,k)
      p%cofgen(10,k) = p%cofgen(3,k)
      p%cofgen(11,k) = 0.999_real64
      p%cofgen(12,k) = 0.99_real64 * p%cofgen(3,k)
      p%cofgen(22,k) = -1.0e6_real64
      p%cofgen(23,k) = 1.0e-12_real64
    end do
    p%bottom_mode = 1
    p%prescribed_groundwater_active=.true.
    p%swkimpl = 0
    p%swkmean = 1
    p%swsophy = 0
    p%root_extraction_active = .false.
    p%macropore_active = .false.
    p%snow_active = .false.
    p%hysteresis_active = .false.
    p%tabulated_hydraulics_active = .false.
    p%elasticity_active = .false.
    p%frost_active = .false.
    p%soil_temperature_active = .false.
    p%drainage_response_active = .false.
  end subroutine initialize_parameters

  subroutine initialize_state_and_forcing(p, state, forcing, scale, conductivity0)
    type(fmr_b110_physical_parameters_t), intent(in) :: p
    type(fmr_b110_physical_state_t), intent(out) :: state
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: scale
    real(real64), intent(out) :: conductivity0

    type(b110_default_mvg_parameters_t), target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: i

    heads = -1.5d0-z
    call initialize_b110_default_mvg_parameters(hp, p%cofgen)
    call bind_b110_default_mvg_provider(provider, hp, T1 - T0)
    call provider%evaluate(heads, water, conductivity, capacity, dkdh)
    conductivity0 = conductivity(1)

    state%active_nodes = numnod
    allocate(state%pressure_head(numnod), state%water_content(numnod))
    state%pressure_head = heads
    state%water_content = water
    state%ponding_depth = 0.0_real64
    state%groundwater_level = -1.5d0

    forcing%top_flux = 0d0
    forcing%top_head = H0_CM
    forcing%bottom_flux = 0d0
    forcing%bottom_head = -1.2d0
    allocate(forcing%drainage_flux_by_level(2,numnod), forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do i = 1, numnod
      forcing%drainage_flux_by_level(1,i) = scale * 1.0e-5_real64 * real(i,real64)
      forcing%drainage_flux_by_level(2,i) = -scale * 2.0e-6_real64 * real(i+1,real64)
      forcing%subsurface_irrigation_source(i) = forcing%drainage_flux_by_level(1,i) + &
           forcing%drainage_flux_by_level(2,i)
      forcing%root_extraction_sink(i) = 0.0_real64
    end do
  end subroutine initialize_state_and_forcing
  subroutine require(condition, message)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: message
    if (.not. condition) then
      write(*,'(a,1x,a)') 'PPA_WU01_FAIL', trim(message)
      error stop 1
    end if
  end subroutine require
end program
