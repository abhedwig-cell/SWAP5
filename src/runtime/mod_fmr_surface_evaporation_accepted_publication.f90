module mod_fmr_surface_evaporation_accepted_publication
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_surface_evaporation_runtime_materialization, only: &
       fmr_candidate_bound_surface_evaporation_t
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t
  implicit none
  private

  integer, parameter, public :: FMR_SURFACE_EVAP_PUBLICATION_OK = 0
  integer, parameter, public :: FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT = 1
  integer, parameter, public :: FMR_SURFACE_EVAP_PUBLICATION_INVALID_COMMIT_RECEIPT = 2
  integer, parameter, public :: FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH = 3
  integer, parameter, public :: FMR_SURFACE_EVAP_PUBLICATION_TIME_MISMATCH = 4

  ! Worker/job-local precommit attribution. It can only be prepared from an
  ! opaque result whose provenance was attached by the runtime materializer at
  ! the point where the exact candidate was available. No raw process result
  ! plus caller-supplied candidate stamping API exists.
  type, public :: fmr_prepared_surface_evaporation_publication_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: bare_soil_evaporation_rate_value = 0.0_real64
    real(real64) :: ponded_water_evaporation_rate_value = 0.0_real64
    character(len=24) :: route_value = 'not-run'
  contains
    procedure, public :: ready => prepared_ready
  end type fmr_prepared_surface_evaporation_publication_t

  ! Accepted-only immutable attribution metadata. The rates are a decomposition
  ! of already-accounted process behavior. This object is not an additional
  ! mass-ledger term and is not persistent continuation state.
  type, public :: fmr_surface_evaporation_publication_t
    private
    logical :: initialized = .false.
    integer(int64) :: lineage_id = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: bare_soil_evaporation_rate_value = 0.0_real64
    real(real64) :: ponded_water_evaporation_rate_value = 0.0_real64
    character(len=24) :: route_value = 'not-published'
  contains
    procedure, public :: ready => publication_ready
    procedure, public :: current_lineage_id => publication_lineage_id
    procedure, public :: origin_revision => publication_origin_revision
    procedure, public :: committed_revision => publication_committed_revision
    procedure, public :: origin_interval => publication_origin_interval
    procedure, public :: bare_soil_evaporation_rate => publication_bare_rate
    procedure, public :: ponded_water_evaporation_rate => publication_ponded_rate
    procedure, public :: route => publication_route
  end type fmr_surface_evaporation_publication_t

  public :: fmr_prepare_surface_evaporation_publication
  public :: fmr_finalize_surface_evaporation_publication

contains

  subroutine fmr_prepare_surface_evaporation_publication(bound_result, prepared, status)
    type(fmr_candidate_bound_surface_evaporation_t), intent(in) :: bound_result
    type(fmr_prepared_surface_evaporation_publication_t), intent(out) :: prepared
    integer, intent(out) :: status

    real(real64) :: t0, t1
    logical :: interval_available

    prepared = fmr_prepared_surface_evaporation_publication_t()
    status = FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT
    if (.not. bound_result%ready()) return

    call bound_result%origin_interval(t0, t1, interval_available)
    if (.not. interval_available) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    if (bound_result%current_lineage_id() <= 0_int64) return
    if (bound_result%origin_revision() < 0_int64) return

    prepared%lineage_id = bound_result%current_lineage_id()
    prepared%origin_revision_value = bound_result%origin_revision()
    prepared%t0_value = t0
    prepared%t1_value = t1
    prepared%bare_soil_evaporation_rate_value = bound_result%bare_soil_evaporation_rate()
    prepared%ponded_water_evaporation_rate_value = bound_result%ponded_water_evaporation_rate()
    prepared%route_value = bound_result%route()
    prepared%initialized = .true.
    status = FMR_SURFACE_EVAP_PUBLICATION_OK
  end subroutine fmr_prepare_surface_evaporation_publication

  subroutine fmr_finalize_surface_evaporation_publication(prepared, commit_receipt, publication, status)
    type(fmr_prepared_surface_evaporation_publication_t), intent(in) :: prepared
    type(fmr_accepted_commit_receipt_t), intent(in) :: commit_receipt
    type(fmr_surface_evaporation_publication_t), intent(out) :: publication
    integer, intent(out) :: status

    real(real64) :: t0, t1
    logical :: interval_available

    publication = fmr_surface_evaporation_publication_t()
    status = FMR_SURFACE_EVAP_PUBLICATION_INVALID_RESULT
    if (.not. prepared%ready()) return

    status = FMR_SURFACE_EVAP_PUBLICATION_INVALID_COMMIT_RECEIPT
    if (.not. commit_receipt%ready()) return
    call commit_receipt%origin_interval(t0, t1, interval_available)
    if (.not. interval_available) return

    status = FMR_SURFACE_EVAP_PUBLICATION_PROVENANCE_MISMATCH
    if (commit_receipt%current_lineage_id() /= prepared%lineage_id) return
    if (commit_receipt%origin_revision() /= prepared%origin_revision_value) return
    if (commit_receipt%committed_revision() /= prepared%origin_revision_value + 1_int64) return

    status = FMR_SURFACE_EVAP_PUBLICATION_TIME_MISMATCH
    if (.not. same_time_value(t0, prepared%t0_value)) return
    if (.not. same_time_value(t1, prepared%t1_value)) return

    publication%lineage_id = prepared%lineage_id
    publication%origin_revision_value = prepared%origin_revision_value
    publication%committed_revision_value = commit_receipt%committed_revision()
    publication%t0_value = prepared%t0_value
    publication%t1_value = prepared%t1_value
    publication%bare_soil_evaporation_rate_value = prepared%bare_soil_evaporation_rate_value
    publication%ponded_water_evaporation_rate_value = prepared%ponded_water_evaporation_rate_value
    publication%route_value = prepared%route_value
    publication%initialized = .true.
    status = FMR_SURFACE_EVAP_PUBLICATION_OK
  end subroutine fmr_finalize_surface_evaporation_publication

  pure logical function prepared_ready(self) result(ready)
    class(fmr_prepared_surface_evaporation_publication_t), intent(in) :: self

    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. &
         self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%bare_soil_evaporation_rate_value) .and. &
         self%bare_soil_evaporation_rate_value >= 0.0_real64 .and. &
         ieee_is_finite(self%ponded_water_evaporation_rate_value) .and. &
         self%ponded_water_evaporation_rate_value >= 0.0_real64 .and. &
         route_values_consistent(self%route_value, &
              self%bare_soil_evaporation_rate_value, self%ponded_water_evaporation_rate_value)
  end function prepared_ready

  pure logical function publication_ready(self) result(ready)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self

    ready = self%initialized .and. self%lineage_id > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + 1_int64 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. &
         self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%bare_soil_evaporation_rate_value) .and. &
         self%bare_soil_evaporation_rate_value >= 0.0_real64 .and. &
         ieee_is_finite(self%ponded_water_evaporation_rate_value) .and. &
         self%ponded_water_evaporation_rate_value >= 0.0_real64 .and. &
         route_values_consistent(self%route_value, &
              self%bare_soil_evaporation_rate_value, self%ponded_water_evaporation_rate_value)
  end function publication_ready

  pure logical function route_values_consistent(route, bare_rate, ponded_rate) result(valid)
    character(len=*), intent(in) :: route
    real(real64), intent(in) :: bare_rate, ponded_rate

    select case (trim(route))
    case ('dry')
      valid = ponded_rate <= 0.0_real64
    case ('ponded')
      valid = bare_rate <= 0.0_real64
    case default
      valid = .false.
    end select
  end function route_values_consistent

  pure integer(int64) function publication_lineage_id(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    value = self%lineage_id
  end function publication_lineage_id

  pure integer(int64) function publication_origin_revision(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    value = self%origin_revision_value
  end function publication_origin_revision

  pure integer(int64) function publication_committed_revision(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    value = self%committed_revision_value
  end function publication_committed_revision

  subroutine publication_origin_interval(self, t0, t1, available)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
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
  end subroutine publication_origin_interval

  pure real(real64) function publication_bare_rate(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    if (self%ready()) then
      value = self%bare_soil_evaporation_rate_value
    else
      value = 0.0_real64
    end if
  end function publication_bare_rate

  pure real(real64) function publication_ponded_rate(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    if (self%ready()) then
      value = self%ponded_water_evaporation_rate_value
    else
      value = 0.0_real64
    end if
  end function publication_ponded_rate

  pure character(len=24) function publication_route(self) result(value)
    class(fmr_surface_evaporation_publication_t), intent(in) :: self
    if (self%ready()) then
      value = self%route_value
    else
      value = 'not-published'
    end if
  end function publication_route

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

end module mod_fmr_surface_evaporation_accepted_publication
