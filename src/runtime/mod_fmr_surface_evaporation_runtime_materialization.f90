module mod_fmr_surface_evaporation_runtime_materialization
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_candidate_state_t
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_surface_evaporation_capacity_contract, only: surface_evaporation_capacity_provider_t, &
       surface_evaporation_capacity_result_t, SURFACE_EVAP_CAPACITY_AVAILABLE
  use mod_restricted_surface_evaporation, only: surface_evaporation_demand_t, &
       surface_evaporation_hydraulic_input_t, surface_evaporation_result_t, &
       evaluate_restricted_surface_evaporation, SURFACE_EVAP_AVAILABLE
  use mod_reference_et_demand_process, only: reference_et_demand_result_t
  use mod_fmr_reference_et_demand_binding, only: fmr_reference_et_binding_diagnostics_t, &
       FMR_REFERENCE_ET_BINDING_OK
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  implicit none
  private

  real(real64), parameter, public :: FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM = 1.0e-10_real64

  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_OK = 0
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED = 1
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED = 2
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED = 3
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED = 4
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_CANDIDATE_REJECTED = 5
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH = 6
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_TIME_MISMATCH = 7
  integer, parameter, public :: FMR_SURFACE_EVAP_RUNTIME_EXACT_PROVENANCE_UNAVAILABLE = 8

  type, public :: fmr_surface_evaporation_runtime_diagnostics_t
    integer :: status = FMR_SURFACE_EVAP_RUNTIME_OK
    integer :: capacity_status = 0
    integer :: process_status = 0
    logical :: demand_accepted = .false.
    logical :: committed_view_built = .false.
    logical :: capacity_called = .false.
    logical :: process_called = .false.
    logical :: surface_is_ponded = .false.
    logical :: result_produced = .false.
    real(real64) :: base_ponding_depth = 0.0_real64
    real(real64) :: raw_evaporation_capacity = 0.0_real64
    character(len=48) :: route = 'not-run'
  end type fmr_surface_evaporation_runtime_diagnostics_t

  ! Opaque worker/job-local carrier for a surface-evaporation result. Accepted
  ! publication requires exact F-KT attempt provenance in addition to the
  ! physical transaction origin. The pair execution provenance id + candidate
  ! sequence is attached by F-KT and cannot be supplied or rewritten here.
  ! This object is runtime attribution metadata, not persistent column state and
  ! not an additional mass-ledger authority.
  type, public :: fmr_candidate_bound_surface_evaporation_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer(int64) :: execution_provenance_id_value = 0_int64
    integer(int64) :: candidate_sequence_value = 0_int64
    type(surface_evaporation_result_t) :: result_value
  contains
    procedure, public :: ready => candidate_bound_ready
    procedure, public :: current_lineage_id => candidate_bound_lineage_id
    procedure, public :: origin_revision => candidate_bound_origin_revision
    procedure, public :: origin_interval => candidate_bound_origin_interval
    procedure, public :: exact_attempt_provenance => candidate_bound_exact_attempt_provenance
    procedure, public :: bare_soil_evaporation_rate => candidate_bound_bare_rate
    procedure, public :: ponded_water_evaporation_rate => candidate_bound_ponded_rate
    procedure, public :: route => candidate_bound_route
  end type fmr_candidate_bound_surface_evaporation_t

  public :: fmr_materialize_restricted_surface_evaporation
  public :: fmr_materialize_candidate_bound_surface_evaporation

contains

  subroutine fmr_materialize_restricted_surface_evaporation(committed, et_result, et_diagnostics, &
                                                              capacity_provider, result, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    class(surface_evaporation_capacity_provider_t), intent(in) :: capacity_provider
    type(surface_evaporation_result_t), intent(out) :: result
    type(fmr_surface_evaporation_runtime_diagnostics_t), intent(out) :: diagnostics

    type(process_hydraulic_view_t) :: view
    type(soil_water_physical_state_t) :: base_state
    type(surface_evaporation_capacity_result_t) :: capacity
    type(surface_evaporation_demand_t) :: demand
    type(surface_evaporation_hydraulic_input_t) :: hydraulic
    logical :: ok

    result = surface_evaporation_result_t()
    diagnostics = fmr_surface_evaporation_runtime_diagnostics_t()

    if (et_diagnostics%status /= FMR_REFERENCE_ET_BINDING_OK .or. .not. et_diagnostics%result_produced) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_DEMAND_REJECTED
      diagnostics%route = 'demand-not-qualified'
      return
    end if
    diagnostics%demand_accepted = .true.

    call fmr_build_committed_process_hydraulic_view(committed, view, ok)
    if (.not. ok) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'committed-view-rejected'
      return
    end if
    diagnostics%committed_view_built = .true.
    diagnostics%base_ponding_depth = view%ponding_depth
    if (.not. ieee_is_finite(view%ponding_depth)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'nonfinite-base-ponding'
      return
    end if

    call detached_state_from_view(view, base_state, ok)
    if (.not. ok) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'hydraulic-view-invalid'
      return
    end if

    diagnostics%capacity_called = .true.
    call capacity_provider%evaluate(base_state, capacity)
    diagnostics%capacity_status = capacity%status
    diagnostics%raw_evaporation_capacity = capacity%evaporation_capacity
    if (capacity%status /= SURFACE_EVAP_CAPACITY_AVAILABLE .or. &
        .not. ieee_is_finite(capacity%evaporation_capacity)) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CAPACITY_REJECTED
      diagnostics%route = 'capacity-rejected'
      return
    end if

    demand%bare_soil_demand = et_result%potential_soil_evaporation_cm_per_day
    demand%ponded_water_demand = et_result%potential_pond_evaporation_cm_per_day
    hydraulic%surface_is_ponded = view%ponding_depth > FMR_SURFACE_EVAP_PONDING_THRESHOLD_CM
    hydraulic%evaporation_capacity = capacity%evaporation_capacity
    diagnostics%surface_is_ponded = hydraulic%surface_is_ponded

    diagnostics%process_called = .true.
    call evaluate_restricted_surface_evaporation(demand, hydraulic, result)
    diagnostics%process_status = result%status
    if (result%status /= SURFACE_EVAP_AVAILABLE) then
      result = surface_evaporation_result_t()
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_PROCESS_REJECTED
      diagnostics%route = 'process-rejected'
      return
    end if

    diagnostics%result_produced = .true.
    diagnostics%route = result%route
  end subroutine fmr_materialize_restricted_surface_evaporation

  subroutine fmr_materialize_candidate_bound_surface_evaporation(committed, candidate, et_result, et_diagnostics, &
                                                                  capacity_provider, bound_result, diagnostics)
    type(kernel_committed_state_t), intent(in) :: committed
    type(kernel_candidate_state_t), intent(in) :: candidate
    type(reference_et_demand_result_t), intent(in) :: et_result
    type(fmr_reference_et_binding_diagnostics_t), intent(in) :: et_diagnostics
    class(surface_evaporation_capacity_provider_t), intent(in) :: capacity_provider
    type(fmr_candidate_bound_surface_evaporation_t), intent(out) :: bound_result
    type(fmr_surface_evaporation_runtime_diagnostics_t), intent(out) :: diagnostics

    type(surface_evaporation_result_t) :: process_result
    integer(int64) :: lineage_id, origin_revision
    integer(int64) :: execution_provenance_id, candidate_sequence
    real(real64) :: t0, t1, committed_time
    logical :: interval_available, time_available, exact_available

    bound_result = fmr_candidate_bound_surface_evaporation_t()
    diagnostics = fmr_surface_evaporation_runtime_diagnostics_t()

    if (.not. committed%ready()) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_COMMITTED_VIEW_REJECTED
      diagnostics%route = 'committed-not-ready'
      return
    end if
    if (.not. candidate%ready()) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CANDIDATE_REJECTED
      diagnostics%route = 'candidate-not-ready'
      return
    end if

    lineage_id = candidate%current_lineage_id()
    origin_revision = candidate%origin_revision()
    call candidate%origin_interval(t0, t1, interval_available)
    if (.not. interval_available .or. lineage_id <= 0_int64 .or. origin_revision < 0_int64) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CANDIDATE_REJECTED
      diagnostics%route = 'candidate-origin-invalid'
      return
    end if
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_CANDIDATE_REJECTED
      diagnostics%route = 'candidate-interval-invalid'
      return
    end if

    call candidate%exact_attempt_provenance(execution_provenance_id, candidate_sequence, exact_available)
    if (.not. exact_available) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_EXACT_PROVENANCE_UNAVAILABLE
      diagnostics%route = 'exact-provenance-unavailable'
      return
    end if

    if (committed%current_lineage_id() /= lineage_id .or. committed%current_revision() /= origin_revision) then
      diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_PROVENANCE_MISMATCH
      diagnostics%route = 'candidate-origin-mismatch'
      return
    end if

    if (committed%time_is_bound()) then
      call committed%current_time(committed_time, time_available)
      if (.not. time_available) then
        diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_TIME_MISMATCH
        diagnostics%route = 'committed-time-unavailable'
        return
      end if
      if (.not. same_time_value(committed_time, t0)) then
        diagnostics%status = FMR_SURFACE_EVAP_RUNTIME_TIME_MISMATCH
        diagnostics%route = 'candidate-time-mismatch'
        return
      end if
    end if

    ! Physical attribution is materialized only after both transaction-origin
    ! and exact-attempt provenance have been established by F-KT. Callers cannot
    ! later restamp the result with a different candidate identity.
    call fmr_materialize_restricted_surface_evaporation(committed, et_result, et_diagnostics, &
                                                         capacity_provider, process_result, diagnostics)
    if (diagnostics%status /= FMR_SURFACE_EVAP_RUNTIME_OK .or. .not. diagnostics%result_produced) return

    bound_result%lineage_id = lineage_id
    bound_result%origin_revision_value = origin_revision
    bound_result%t0_value = t0
    bound_result%t1_value = t1
    bound_result%execution_provenance_id_value = execution_provenance_id
    bound_result%candidate_sequence_value = candidate_sequence
    bound_result%result_value = process_result
    bound_result%initialized = .true.
  end subroutine fmr_materialize_candidate_bound_surface_evaporation

  subroutine detached_state_from_view(view, state, ok)
    type(process_hydraulic_view_t), intent(inout) :: view
    type(soil_water_physical_state_t), intent(out) :: state
    logical, intent(out) :: ok
    integer :: n

    state = soil_water_physical_state_t()
    ok = .false.
    n = view%active_nodes
    if (n <= 0) return
    if (.not. allocated(view%pressure_head) .or. .not. allocated(view%water_content)) return
    if (size(view%pressure_head) /= n .or. size(view%water_content) /= n) return
    if (.not. all(ieee_is_finite(view%pressure_head))) return
    if (.not. all(ieee_is_finite(view%water_content))) return
    if (.not. ieee_is_finite(view%groundwater_level)) return

    state%active_nodes = n
    call move_alloc(view%pressure_head, state%pressure_head)
    call move_alloc(view%water_content, state%water_content)
    state%ponding_depth = view%ponding_depth
    state%groundwater_level = view%groundwater_level
    ok = .true.
  end subroutine detached_state_from_view

  pure logical function candidate_bound_ready(self) result(ready)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self

    ready = .false.
    if (.not. self%initialized) return
    if (self%lineage_id <= 0_int64 .or. self%origin_revision_value < 0_int64) return
    if (self%execution_provenance_id_value <= 0_int64 .or. self%candidate_sequence_value <= 0_int64) return
    if (.not. ieee_is_finite(self%t0_value) .or. .not. ieee_is_finite(self%t1_value)) return
    if (self%t1_value <= self%t0_value) return
    if (self%result_value%status /= SURFACE_EVAP_AVAILABLE) return
    if (.not. ieee_is_finite(self%result_value%bare_soil_evaporation)) return
    if (.not. ieee_is_finite(self%result_value%ponded_water_evaporation)) return
    if (self%result_value%bare_soil_evaporation < 0.0_real64 .or. &
        self%result_value%ponded_water_evaporation < 0.0_real64) return

    select case (trim(self%result_value%route))
    case ('dry')
      if (self%result_value%ponded_water_evaporation > 0.0_real64) return
    case ('ponded')
      if (self%result_value%bare_soil_evaporation > 0.0_real64) return
    case default
      return
    end select
    ready = .true.
  end function candidate_bound_ready

  pure integer(int64) function candidate_bound_lineage_id(self) result(value)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    value = self%lineage_id
  end function candidate_bound_lineage_id

  pure integer(int64) function candidate_bound_origin_revision(self) result(value)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    value = self%origin_revision_value
  end function candidate_bound_origin_revision

  subroutine candidate_bound_origin_interval(self, t0, t1, available)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    else
      t0 = 0.0_real64
      t1 = 0.0_real64
    end if
  end subroutine candidate_bound_origin_interval

  subroutine candidate_bound_exact_attempt_provenance(self, execution_provenance_id, candidate_sequence, available)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    integer(int64), intent(out) :: execution_provenance_id, candidate_sequence
    logical, intent(out) :: available

    available = self%ready()
    if (available) then
      execution_provenance_id = self%execution_provenance_id_value
      candidate_sequence = self%candidate_sequence_value
    else
      execution_provenance_id = 0_int64
      candidate_sequence = 0_int64
    end if
  end subroutine candidate_bound_exact_attempt_provenance

  pure real(real64) function candidate_bound_bare_rate(self) result(value)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    if (self%ready()) then
      value = self%result_value%bare_soil_evaporation
    else
      value = 0.0_real64
    end if
  end function candidate_bound_bare_rate

  pure real(real64) function candidate_bound_ponded_rate(self) result(value)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    if (self%ready()) then
      value = self%result_value%ponded_water_evaporation
    else
      value = 0.0_real64
    end if
  end function candidate_bound_ponded_rate

  pure character(len=24) function candidate_bound_route(self) result(value)
    class(fmr_candidate_bound_surface_evaporation_t), intent(in) :: self
    if (self%ready()) then
      value = self%result_value%route
    else
      value = 'not-bound'
    end if
  end function candidate_bound_route

  pure logical function same_time_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale

    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time_value

end module mod_fmr_surface_evaporation_runtime_materialization
