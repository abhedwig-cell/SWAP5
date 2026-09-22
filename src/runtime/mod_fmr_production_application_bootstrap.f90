module mod_fmr_production_application_bootstrap
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_EXECUTION_EASY, &
       FMR_OPTIONAL_STATE_LAYOUT_BASE, FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION, &
       FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION, FMR_NUMERICAL_CONTINUATION_NONE, FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_committed_state, &
       fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_black_evaporation_committed_state, &
       fmr_new_b110_boesten_evaporation_committed_state
  use mod_restricted_surface_evaporation, only: black_evaporation_state_t, boesten_evaporation_state_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, &
       fmr_serialized_batch_diagnostics_t, fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, &
       FMR_GW_REGISTRY_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t
  use mod_groundwater_topology_composition, only: groundwater_topology_t, groundwater_topology_cell_t, &
       GW_TOPOLOGY_OK, GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_application_plan_t, groundwater_tile_predictor_input_t, &
       groundwater_cell_area_input_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, &
       FMR_GW_APP_CONTEXT_OK
  use mod_fmr_groundwater_application_c_api, only: register_fmr_groundwater_application_context, &
       release_fmr_groundwater_application_context, FMR_GW_APP_C_API_OK, FMR_GW_APP_C_API_INVALID_CONTEXT, &
       FMR_GW_APP_C_API_CONTEXT_BUSY
  implicit none
  private

  integer, parameter, public :: FMR_APP_BOOT_OK = 0
  integer, parameter, public :: FMR_APP_BOOT_INVALID_CONFIG = 1
  integer, parameter, public :: FMR_APP_BOOT_PROFILE_NOT_ADMITTED = 2
  integer, parameter, public :: FMR_APP_BOOT_STATE_INIT_FAILED = 3
  integer, parameter, public :: FMR_APP_BOOT_REGISTRY_FAILED = 4
  integer, parameter, public :: FMR_APP_BOOT_LEDGER_FAILED = 5
  integer, parameter, public :: FMR_APP_BOOT_NOT_READY = 6
  integer, parameter, public :: FMR_APP_BOOT_CONTEXT_BUSY = 7
  integer, parameter, public :: FMR_APP_BOOT_PLAN_FAILED = 8
  integer, parameter, public :: FMR_APP_BOOT_CONTEXT_FAILED = 9
  integer, parameter, public :: FMR_APP_BOOT_RUNTIME_FAILED = 10

  ! WU01 established serialized Reference mode 7 standalone and mode 5 groundwater profiles.
  ! PPA-WU02-A additionally admits homogeneous typed bottom_mode=2 prescribed-qbot applications.
  ! WU03 may supply already-resolved effective forcing without changing lower-boundary ownership.
  type, public :: fmr_production_application_tile_config_t
    integer(int64) :: tile_id = 0_int64
    integer(int64) :: ledger_id = 0_int64
    integer :: execution_class = FMR_EXECUTION_EASY
    type(fmr_template_t) :: template
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: base_forcing
    type(fmr_b110_physical_state_t) :: initial_state
    real(real64) :: initial_black_ldwet = 0.0_real64
    real(real64) :: initial_boesten_spev = 0.0_real64
    real(real64) :: initial_boesten_saev = 0.0_real64
    type(groundwater_head_datum_t) :: groundwater_datum
    real(real64), allocatable :: initial_right_derivative(:)
  end type fmr_production_application_tile_config_t

  type, public :: fmr_production_application_config_t
    real(real64) :: initial_time = 0.0_real64
    type(canonical_numerical_config_t) :: numerical
    type(fmr_production_application_tile_config_t), allocatable :: tiles(:)
  end type fmr_production_application_config_t

  type, public :: fmr_production_application_bootstrap_t
    private
    logical :: initialized = .false.
    type(canonical_numerical_config_t) :: numerical
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t), allocatable :: templates(:)
    type(fmr_b110_physical_parameters_t), pointer :: parameters(:) => null()
    type(fmr_b110_physical_forcing_t), pointer :: base_forcing(:) => null()
    type(kernel_committed_state_t), pointer :: committed(:) => null()
    type(fmr_groundwater_head_forcing_materializer_t), pointer :: materializers(:) => null()
    type(groundwater_interface_mass_ledger_t), pointer :: ledgers(:) => null()
    type(fmr_groundwater_participant_registry_t), pointer :: registry => null()
    type(fmr_serialized_reference_backend_t), pointer :: backend => null()
    type(fixed_flux_top_boundary_provider_t), pointer :: top_boundary => null()
    integer(int64), allocatable :: participant_handles(:)
    type(groundwater_application_plan_t), pointer :: active_plan => null()
    type(fmr_groundwater_application_context_t), pointer :: active_context => null()
    integer(int64) :: active_context_handle = 0_int64
  contains
    procedure, public :: initialize => production_application_initialize
    procedure, public :: ready => production_application_ready
    procedure, public :: tile_count => production_application_tile_count
    procedure, public :: run_standalone => production_application_run_standalone
    procedure, public :: run_standalone_with_forcing => production_application_run_standalone_with_forcing
    procedure, public :: materialize_groundwater_context => production_application_materialize_groundwater_context
    procedure, public :: release_groundwater_context => production_application_release_groundwater_context
    procedure, public :: copy_committed_revisions => production_application_copy_committed_revisions
    procedure, public :: close => production_application_close
  end type fmr_production_application_bootstrap_t

contains

  subroutine production_application_initialize(self, config, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(fmr_production_application_config_t), intent(in) :: config
    integer, intent(out) :: status

    integer :: i, local_status, n
    logical :: ok, groundwater_profile, standalone_profile, prescribed_qbot_profile
    type(black_evaporation_state_t) :: initial_black_state
    type(boesten_evaporation_state_t) :: initial_boesten_state

    status = FMR_APP_BOOT_INVALID_CONFIG
    if (self%initialized) return
    if (.not. allocated(config%tiles)) return
    n = size(config%tiles)
    if (n <= 0) return
    if (.not. ieee_is_finite(config%initial_time)) return

    groundwater_profile = .true.
    standalone_profile = .true.
    prescribed_qbot_profile = .true.
    do i = 1, n
      if (.not. tile_config_valid(config%tiles(i), n, i)) then
        status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
        return
      end if
      groundwater_profile = groundwater_profile .and. config%tiles(i)%parameters%bottom_mode == 5
      standalone_profile = standalone_profile .and. config%tiles(i)%parameters%bottom_mode == 7
      prescribed_qbot_profile = prescribed_qbot_profile .and. config%tiles(i)%parameters%bottom_mode == 2
      if (i > 1) then
        if (any(config%tiles(1:i-1)%tile_id == config%tiles(i)%tile_id)) return
      end if
    end do
    if (.not. groundwater_profile .and. .not. standalone_profile .and. .not. prescribed_qbot_profile) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    if (groundwater_profile) then
      do i = 1, n
        if (config%tiles(i)%ledger_id <= 0_int64) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (.not. config%tiles(i)%groundwater_datum%valid()) then
          status = FMR_APP_BOOT_INVALID_CONFIG
          return
        end if
        if (i > 1) then
          if (any(config%tiles(1:i-1)%ledger_id == config%tiles(i)%ledger_id)) return
        end if
      end do
    end if

    allocate(self%columns(n), self%templates(n))
    allocate(self%parameters(n), self%base_forcing(n), self%committed(n))
    allocate(self%backend, self%top_boundary)
    self%numerical = config%numerical

    call self%backend%initialize(self%top_boundary)

    if (groundwater_profile) then
      allocate(self%participant_handles(n), self%materializers(n), self%ledgers(n), self%registry)
      self%participant_handles = 0_int64
      call self%registry%initialize(n, local_status)
      if (local_status /= FMR_GW_REGISTRY_OK) then
        status = FMR_APP_BOOT_REGISTRY_FAILED
        call discard_owner_storage(self)
        return
      end if
    end if

    do i = 1, n
      self%templates(i) = config%tiles(i)%template
      self%columns(i)%column_id = config%tiles(i)%tile_id
      self%columns(i)%template_id = self%templates(i)%template_id
      self%columns(i)%parameter_ref = int(i, int64)
      self%columns(i)%state_handle = int(i, int64)
      self%columns(i)%forcing_handle = int(i, int64)
      self%columns(i)%execution_class = config%tiles(i)%execution_class
      self%columns(i)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      self%parameters(i) = config%tiles(i)%parameters
      self%base_forcing(i) = config%tiles(i)%base_forcing
      if (groundwater_profile) call self%materializers(i)%initialize(self%base_forcing(i))

      select case (self%templates(i)%numerical_continuation_layout_id)
      case (FMR_NUMERICAL_CONTINUATION_NONE)
        if (self%templates(i)%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION) then
          initial_black_state%ldwet = config%tiles(i)%initial_black_ldwet
          call fmr_new_b110_black_evaporation_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, initial_black_state, config%initial_time, ok)
        else if (self%templates(i)%optional_state_layout_id == FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) then
          initial_boesten_state%spev = config%tiles(i)%initial_boesten_spev
          initial_boesten_state%saev = config%tiles(i)%initial_boesten_saev
          call fmr_new_b110_boesten_evaporation_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, initial_boesten_state, config%initial_time, ok)
        else
          call fmr_new_b110_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok)
        end if
      case (FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY)
        if (allocated(config%tiles(i)%initial_right_derivative)) then
          call fmr_new_b110_temporal_indicator_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok, config%tiles(i)%initial_right_derivative)
        else
          call fmr_new_b110_temporal_indicator_committed_state(self%committed(i), config%tiles(i)%tile_id, &
               config%tiles(i)%initial_state, config%initial_time, ok)
        end if
      case default
        ok = .false.
      end select
      if (.not. ok) then
        status = FMR_APP_BOOT_STATE_INIT_FAILED
        call discard_owner_storage(self)
        return
      end if

      if (groundwater_profile) then
        call self%registry%bind(config%tiles(i)%tile_id, self%backend, self%columns(i), self%templates(i), &
             self%parameters(i), self%committed(i), self%materializers(i), self%numerical, &
             config%tiles(i)%groundwater_datum, self%participant_handles(i), local_status)
        if (local_status /= FMR_GW_REGISTRY_OK .or. self%participant_handles(i) <= 0_int64) then
          status = FMR_APP_BOOT_REGISTRY_FAILED
          call discard_owner_storage(self)
          return
        end if

        call self%ledgers(i)%bind_identity(config%tiles(i)%ledger_id, local_status)
        if (local_status /= GW_MASS_LEDGER_OK) then
          status = FMR_APP_BOOT_LEDGER_FAILED
          call discard_owner_storage(self)
          return
        end if
      end if
    end do

    self%initialized = .true.
    status = FMR_APP_BOOT_OK
  end subroutine production_application_initialize

  logical function production_application_ready(self) result(ready)
    class(fmr_production_application_bootstrap_t), intent(in) :: self

    ready = self%initialized
    if (.not. ready) return
    ready = allocated(self%columns) .and. allocated(self%templates)
    if (.not. ready) return
    ready = associated(self%parameters) .and. associated(self%base_forcing) .and. associated(self%committed) .and. &
         associated(self%backend) .and. associated(self%top_boundary)
    if (.not. ready) return
    ready = size(self%columns) > 0 .and. size(self%templates) == size(self%columns) .and. &
         size(self%parameters) == size(self%columns) .and. size(self%base_forcing) == size(self%columns) .and. &
         size(self%committed) == size(self%columns)
  end function production_application_ready

  logical function production_application_groundwater_ready(self) result(ready)
    class(fmr_production_application_bootstrap_t), intent(in) :: self

    ready = self%ready()
    if (.not. ready) return
    ready = associated(self%materializers) .and. associated(self%ledgers) .and. associated(self%registry) .and. &
         allocated(self%participant_handles)
    if (.not. ready) return
    ready = size(self%materializers) == size(self%columns) .and. size(self%ledgers) == size(self%columns) .and. &
         size(self%participant_handles) == size(self%columns)
    if (.not. ready) return
    ready = self%registry%active_count() == size(self%columns) .and. all(self%participant_handles > 0_int64) .and. &
         all(self%parameters%bottom_mode == 5)
  end function production_application_groundwater_ready

  integer function production_application_tile_count(self) result(count)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    count = 0
    if (self%ready()) count = size(self%columns)
  end function production_application_tile_count

  subroutine production_application_run_standalone(self, t0, t1, results, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status

    if (allocated(results)) deallocate(results)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return

    call self%run_standalone_with_forcing(t0, t1, self%base_forcing, results, status)
  end subroutine production_application_run_standalone

  subroutine production_application_run_standalone_with_forcing(self, t0, t1, effective_forcing, results, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    real(real64), intent(in) :: t0, t1
    type(fmr_b110_physical_forcing_t), intent(in) :: effective_forcing(:)
    type(fmr_serialized_column_result_t), allocatable, intent(out) :: results(:)
    integer, intent(out) :: status

    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    integer :: dispatch_status

    if (allocated(results)) deallocate(results)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return
    if (associated(self%active_context)) then
      status = FMR_APP_BOOT_CONTEXT_BUSY
      return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) then
      status = FMR_APP_BOOT_INVALID_CONFIG
      return
    end if
    if (size(effective_forcing) /= size(self%columns)) then
      status = FMR_APP_BOOT_INVALID_CONFIG
      return
    end if

    call fmr_run_serialized_physical_multiswap(self%columns, self%templates, self%parameters, effective_forcing, &
         self%committed, self%numerical, self%top_boundary, t0, t1, size(self%columns), results, diagnostics, &
         aggregate, dispatch_status, runtime)

    status = FMR_APP_BOOT_RUNTIME_FAILED
    if (dispatch_status /= FMR_SERIAL_DISPATCH_OK) return
    if (.not. allocated(results)) return
    if (size(results) /= size(self%columns)) return
    if (.not. all(results%completed)) return
    if (.not. all(results%committed)) return
    status = FMR_APP_BOOT_OK
  end subroutine production_application_run_standalone_with_forcing

  subroutine production_application_materialize_groundwater_context(self, topology, predictors, cell_areas, &
       context_handle, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    type(groundwater_topology_t), intent(in) :: topology
    type(groundwater_tile_predictor_input_t), intent(in) :: predictors(:)
    type(groundwater_cell_area_input_t), intent(in) :: cell_areas(:)
    integer(int64), intent(out) :: context_handle
    integer, intent(out) :: status

    type(groundwater_topology_cell_t), allocatable :: authority_cells(:)
    integer :: local_status

    context_handle = 0_int64
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return

    status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
    if (.not. production_application_groundwater_ready(self)) return

    ! Fixed-interface closeout application authority:
    ! * native MODFLOW STO is head-state capacitance, not an independently
    !   additive physical storage reservoir in the accepted water balance;
    ! * active physical drainage is outside this admitted application profile.
    ! Research topologies may carry other or unresolved labels, but production
    ! materialization fails closed on them.
    call topology%copy_cells(authority_cells, local_status)
    if (local_status /= GW_TOPOLOGY_OK .or. .not. allocated(authority_cells)) return
    if (size(authority_cells) <= 0) return
    if (any(authority_cells%storage_state_role /= GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE)) return
    if (any(authority_cells%drainage_owner /= GW_DRAINAGE_OWNER_NONE)) return

    if (associated(self%active_context)) then
      call retire_active_context(self, local_status)
      if (local_status /= FMR_APP_BOOT_OK) then
        status = local_status
        return
      end if
    end if

    allocate(self%active_plan)
    call materialize_groundwater_application_plan(topology, predictors, cell_areas, self%active_plan, local_status)
    if (local_status /= GW_APP_PLAN_OK .or. .not. self%active_plan%ready()) then
      status = FMR_APP_BOOT_PLAN_FAILED
      deallocate(self%active_plan)
      nullify(self%active_plan)
      return
    end if

    allocate(self%active_context)
    call self%active_context%bind(self%active_plan, self%registry, self%participant_handles, self%ledgers, local_status)
    if (local_status /= FMR_GW_APP_CONTEXT_OK .or. .not. self%active_context%ready()) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      deallocate(self%active_context)
      deallocate(self%active_plan)
      nullify(self%active_context)
      nullify(self%active_plan)
      return
    end if

    call register_fmr_groundwater_application_context(self%active_context, self%active_context_handle, local_status)
    if (local_status /= FMR_GW_APP_C_API_OK .or. self%active_context_handle <= 0_int64) then
      status = FMR_APP_BOOT_CONTEXT_FAILED
      deallocate(self%active_context)
      deallocate(self%active_plan)
      nullify(self%active_context)
      nullify(self%active_plan)
      self%active_context_handle = 0_int64
      return
    end if

    context_handle = self%active_context_handle
    status = FMR_APP_BOOT_OK
  end subroutine production_application_materialize_groundwater_context

  subroutine production_application_release_groundwater_context(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status

    if (.not. self%ready()) then
      status = FMR_APP_BOOT_NOT_READY
      return
    end if
    if (.not. production_application_groundwater_ready(self)) then
      status = FMR_APP_BOOT_PROFILE_NOT_ADMITTED
      return
    end if
    call retire_active_context(self, status)
  end subroutine production_application_release_groundwater_context

  subroutine production_application_copy_committed_revisions(self, revisions, status)
    class(fmr_production_application_bootstrap_t), intent(in) :: self
    integer(int64), allocatable, intent(out) :: revisions(:)
    integer, intent(out) :: status
    integer :: i

    if (allocated(revisions)) deallocate(revisions)
    status = FMR_APP_BOOT_NOT_READY
    if (.not. self%ready()) return
    allocate(revisions(size(self%committed)))
    do i = 1, size(self%committed)
      revisions(i) = self%committed(i)%current_revision()
    end do
    status = FMR_APP_BOOT_OK
  end subroutine production_application_copy_committed_revisions

  subroutine production_application_close(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status

    integer :: i, local_status

    status = FMR_APP_BOOT_OK
    if (.not. self%initialized) then
      call discard_owner_storage(self)
      return
    end if

    if (associated(self%active_context)) then
      call retire_active_context(self, local_status)
      if (local_status /= FMR_APP_BOOT_OK) then
        status = local_status
        return
      end if
    end if

    if (associated(self%registry)) then
      if (.not. self%registry%quiescent()) then
        status = FMR_APP_BOOT_CONTEXT_BUSY
        return
      end if
      if (allocated(self%participant_handles)) then
        do i = 1, size(self%participant_handles)
          if (self%participant_handles(i) <= 0_int64) cycle
          call self%registry%release(self%participant_handles(i), local_status)
          if (local_status /= FMR_GW_REGISTRY_OK) then
            status = FMR_APP_BOOT_CONTEXT_BUSY
            return
          end if
        end do
      end if
    end if

    call discard_owner_storage(self)
    status = FMR_APP_BOOT_OK
  end subroutine production_application_close

  subroutine retire_active_context(self, status)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self
    integer, intent(out) :: status
    integer :: local_status

    status = FMR_APP_BOOT_OK
    if (.not. associated(self%active_context)) then
      self%active_context_handle = 0_int64
      if (associated(self%active_plan)) then
        deallocate(self%active_plan)
        nullify(self%active_plan)
      end if
      return
    end if

    if (self%active_context_handle > 0_int64) then
      call release_fmr_groundwater_application_context(self%active_context_handle, local_status)
      if (local_status == FMR_GW_APP_C_API_CONTEXT_BUSY) then
        status = FMR_APP_BOOT_CONTEXT_BUSY
        return
      end if
      if (local_status /= FMR_GW_APP_C_API_OK .and. local_status /= FMR_GW_APP_C_API_INVALID_CONTEXT) then
        status = FMR_APP_BOOT_CONTEXT_FAILED
        return
      end if
    end if

    deallocate(self%active_context)
    nullify(self%active_context)
    if (associated(self%active_plan)) then
      deallocate(self%active_plan)
      nullify(self%active_plan)
    end if
    self%active_context_handle = 0_int64
  end subroutine retire_active_context

  logical function tile_config_valid(tile, ntiles, slot) result(valid)
    type(fmr_production_application_tile_config_t), intent(in) :: tile
    integer, intent(in) :: ntiles, slot

    valid = .false.
    if (tile%tile_id <= 0_int64) return
    if (slot <= 0 .or. slot > ntiles) return
    if (tile%template%template_id <= 0_int64) return
    if (tile%template%compatible_backend_id /= FMR_BACKEND_SERIALIZED_REFERENCE) return
    if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION .and. &
        tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) return
    if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE .and. &
        tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY) return
    if (tile%parameters%parameter_set_id <= 0_int64) return
    if (tile%parameters%active_nodes <= 0) return
    if (tile%parameters%bottom_mode /= 5 .and. tile%parameters%bottom_mode /= 7 .and. &
        tile%parameters%bottom_mode /= 2) return

    ! WU01 established the no-new-physics production owner. PPA-WU02-A only
    ! widens normal application reachability to the already admitted typed
    ! prescribed-qbot mode 2; process composition remains fail-closed here.
    if (tile%parameters%macropore_active .or. tile%parameters%snow_active .or. &
        tile%parameters%hysteresis_active .or. tile%parameters%elasticity_active .or. &
        tile%parameters%frost_active .or. tile%parameters%soil_temperature_active .or. &
        tile%parameters%drainage_response_active .or. tile%parameters%root_extraction_active .or. &
        tile%parameters%tabulated_hydraulics_active) return

    if (tile%parameters%black_evaporation_active) then
      if (tile%parameters%boesten_evaporation_active) return
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BLACK_EVAPORATION) return
      if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      if (.not. allocated(tile%parameters%black_evaporation) .or. allocated(tile%parameters%boesten_evaporation)) return
      if (.not. ieee_is_finite(tile%parameters%black_evaporation%cofred) .or. &
          tile%parameters%black_evaporation%cofred < 0.0_real64) return
      if (.not. ieee_is_finite(tile%initial_black_ldwet) .or. tile%initial_black_ldwet < 0.0_real64) return
      if (tile%initial_boesten_spev /= 0.0_real64 .or. tile%initial_boesten_saev /= 0.0_real64) return
      if (tile%parameters%bottom_mode == 5) return
    else if (tile%parameters%boesten_evaporation_active) then
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BOESTEN_EVAPORATION) return
      if (tile%template%numerical_continuation_layout_id /= FMR_NUMERICAL_CONTINUATION_NONE) return
      if (allocated(tile%parameters%black_evaporation) .or. .not. allocated(tile%parameters%boesten_evaporation)) return
      if (.not. ieee_is_finite(tile%parameters%boesten_evaporation%cofred) .or. &
          tile%parameters%boesten_evaporation%cofred <= 0.0_real64 .or. &
          tile%parameters%boesten_evaporation%cofred > 1.0_real64) return
      if (.not. ieee_is_finite(tile%initial_boesten_spev) .or. tile%initial_boesten_spev < 0.0_real64) return
      if (.not. ieee_is_finite(tile%initial_boesten_saev) .or. tile%initial_boesten_saev < 0.0_real64) return
      if (tile%initial_black_ldwet /= 0.0_real64) return
      if (tile%parameters%bottom_mode == 5) return
    else
      if (tile%template%optional_state_layout_id /= FMR_OPTIONAL_STATE_LAYOUT_BASE) return
      if (allocated(tile%parameters%black_evaporation) .or. allocated(tile%parameters%boesten_evaporation)) return
      if (tile%initial_black_ldwet /= 0.0_real64 .or. tile%initial_boesten_spev /= 0.0_real64 .or. &
          tile%initial_boesten_saev /= 0.0_real64) return
    end if

    if (.not. allocated(tile%parameters%z) .or. .not. allocated(tile%parameters%dz) .or. &
        .not. allocated(tile%parameters%node_distance) .or. .not. allocated(tile%parameters%cofgen)) return
    if (size(tile%parameters%z) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%dz) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%node_distance) /= tile%parameters%active_nodes .or. &
        size(tile%parameters%cofgen, 2) /= tile%parameters%active_nodes) return

    if (tile%initial_state%active_nodes /= tile%parameters%active_nodes) return
    if (.not. allocated(tile%initial_state%pressure_head) .or. .not. allocated(tile%initial_state%water_content)) return
    if (size(tile%initial_state%pressure_head) /= tile%parameters%active_nodes .or. &
        size(tile%initial_state%water_content) /= tile%parameters%active_nodes) return
    if (tile%parameters%bottom_mode == 5) then
      if (tile%ledger_id <= 0_int64 .or. .not. tile%groundwater_datum%valid()) return
    end if
    if (allocated(tile%initial_right_derivative)) then
      if (size(tile%initial_right_derivative) /= tile%parameters%active_nodes) return
    end if
    valid = .true.
  end function tile_config_valid

  subroutine discard_owner_storage(self)
    class(fmr_production_application_bootstrap_t), intent(inout) :: self

    if (associated(self%active_context)) deallocate(self%active_context)
    if (associated(self%active_plan)) deallocate(self%active_plan)
    nullify(self%active_context)
    nullify(self%active_plan)
    self%active_context_handle = 0_int64

    if (associated(self%registry)) deallocate(self%registry)
    if (associated(self%ledgers)) deallocate(self%ledgers)
    if (associated(self%materializers)) deallocate(self%materializers)
    if (associated(self%committed)) deallocate(self%committed)
    if (associated(self%base_forcing)) deallocate(self%base_forcing)
    if (associated(self%parameters)) deallocate(self%parameters)
    if (associated(self%backend)) deallocate(self%backend)
    if (associated(self%top_boundary)) deallocate(self%top_boundary)
    nullify(self%registry)
    nullify(self%ledgers)
    nullify(self%materializers)
    nullify(self%committed)
    nullify(self%base_forcing)
    nullify(self%parameters)
    nullify(self%backend)
    nullify(self%top_boundary)

    if (allocated(self%participant_handles)) deallocate(self%participant_handles)
    if (allocated(self%columns)) deallocate(self%columns)
    if (allocated(self%templates)) deallocate(self%templates)
    self%initialized = .false.
  end subroutine discard_owner_storage

end module mod_fmr_production_application_bootstrap
