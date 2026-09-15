module mod_eb_i26_outer_substep_sensible_boundary_aggregation
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_whole_column_sensible_energy_accounting, only: whole_column_sensible_boundary_t
  use mod_eb_i25_multisubstep_sensible_boundary_runtime, only: &
       eb_i25_sensible_boundary_publication_t, EB_I25_TOP_MULTISUBSTEP_INFLOW, EB_I25_TOP_ZERO_MATERIALIZED
  implicit none
  private

  integer, parameter, public :: EB_I26_NOT_PUBLISHED = 0
  integer, parameter, public :: EB_I26_ACCEPTED_COMPLETE = 1
  integer, parameter, public :: EB_I26_INSUFFICIENT_OUTER_SUBSTEPS = 2
  integer, parameter, public :: EB_I26_INVALID_SEQUENCE = 3
  integer, parameter, public :: EB_I26_INCOMPLETE_INPUT = 4
  integer, parameter, public :: EB_I26_NUMERIC_FAILURE = 5

  type, public :: eb_i26_outer_substep_sensible_boundary_publication_t
    private
    logical :: initialized = .false.
    integer :: status_value = EB_I26_NOT_PUBLISHED
    integer(int64) :: column_id_value = 0_int64
    integer(int64) :: lineage_id_value = 0_int64
    integer(int64) :: origin_revision_value = -1_int64
    integer(int64) :: committed_revision_value = -1_int64
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    integer :: accepted_outer_substeps_value = 0
    integer :: accepted_internal_half_samples_value = 0
    real(real64) :: top_liquid_inflow_cm_value = 0.0_real64
    type(whole_column_sensible_boundary_t) :: boundary_value
  contains
    procedure, public :: ready => publication_ready
    procedure, public :: status => publication_status
    procedure, public :: column_id => publication_column_id
    procedure, public :: current_lineage_id => publication_lineage_id
    procedure, public :: origin_revision => publication_origin_revision
    procedure, public :: committed_revision => publication_committed_revision
    procedure, public :: origin_interval => publication_origin_interval
    procedure, public :: accepted_outer_substeps => publication_accepted_outer_substeps
    procedure, public :: accepted_internal_half_samples => publication_accepted_internal_half_samples
    procedure, public :: top_liquid_inflow => publication_top_liquid_inflow
    procedure, public :: boundary_snapshot => publication_boundary_snapshot
    procedure, public :: runtime_materialization_complete => publication_runtime_complete
  end type eb_i26_outer_substep_sensible_boundary_publication_t

  public :: aggregate_accepted_outer_substep_sensible_boundaries

contains

  subroutine aggregate_accepted_outer_substep_sensible_boundaries(publications, aggregate)
    type(eb_i25_sensible_boundary_publication_t), intent(in) :: publications(:)
    type(eb_i26_outer_substep_sensible_boundary_publication_t), intent(out) :: aggregate

    type(whole_column_sensible_boundary_t) :: boundary
    real(real64) :: step_t0, step_t1, previous_t1, inflow_cm, reference_temperature_c
    integer(int64) :: previous_committed_revision
    integer :: i
    logical :: interval_available, boundary_available, inflow_available

    aggregate = eb_i26_outer_substep_sensible_boundary_publication_t()

    if (size(publications) < 2) then
      aggregate%status_value = EB_I26_INSUFFICIENT_OUTER_SUBSTEPS
      return
    end if

    do i = 1, size(publications)
      if (.not. publications(i)%ready()) then
        aggregate%status_value = EB_I26_INVALID_SEQUENCE
        return
      end if
      if (publications(i)%accepted_substeps() /= 1 .or. publications(i)%carrier_sample_count() /= 2) then
        aggregate%status_value = EB_I26_INVALID_SEQUENCE
        return
      end if
      if (publications(i)%top_status() /= EB_I25_TOP_MULTISUBSTEP_INFLOW .and. &
          publications(i)%top_status() /= EB_I25_TOP_ZERO_MATERIALIZED) then
        aggregate%status_value = EB_I26_INCOMPLETE_INPUT
        return
      end if
      if (.not. publications(i)%runtime_materialization_complete()) then
        aggregate%status_value = EB_I26_INCOMPLETE_INPUT
        return
      end if

      call publications(i)%origin_interval(step_t0, step_t1, interval_available)
      call publications(i)%boundary_snapshot(boundary, boundary_available)
      call publications(i)%top_liquid_inflow(inflow_cm, inflow_available)
      if (.not. interval_available .or. .not. boundary_available .or. .not. inflow_available .or. &
          .not. boundary%complete()) then
        aggregate%status_value = EB_I26_INCOMPLETE_INPUT
        return
      end if
      if (.not. boundary_values_finite(boundary) .or. .not. ieee_is_finite(inflow_cm) .or. inflow_cm < 0.0_real64) then
        aggregate%status_value = EB_I26_NUMERIC_FAILURE
        return
      end if

      if (i == 1) then
        aggregate%column_id_value = publications(i)%column_id()
        aggregate%lineage_id_value = publications(i)%current_lineage_id()
        aggregate%origin_revision_value = publications(i)%origin_revision()
        aggregate%t0_value = step_t0
        reference_temperature_c = boundary%mass_carried_reference_temperature_c
        aggregate%boundary_value%mass_carried_reference_available = .true.
        aggregate%boundary_value%mass_carried_reference_temperature_c = reference_temperature_c
      else
        if (publications(i)%column_id() /= aggregate%column_id_value .or. &
            publications(i)%current_lineage_id() /= aggregate%lineage_id_value .or. &
            publications(i)%origin_revision() /= previous_committed_revision .or. &
            .not. same_time(step_t0, previous_t1) .or. &
            .not. same_value(boundary%mass_carried_reference_temperature_c, reference_temperature_c)) then
          aggregate%status_value = EB_I26_INVALID_SEQUENCE
          return
        end if
      end if

      previous_committed_revision = publications(i)%committed_revision()
      previous_t1 = step_t1
      aggregate%accepted_outer_substeps_value = aggregate%accepted_outer_substeps_value + 1
      aggregate%accepted_internal_half_samples_value = aggregate%accepted_internal_half_samples_value + &
           publications(i)%carrier_sample_count()
      aggregate%top_liquid_inflow_cm_value = aggregate%top_liquid_inflow_cm_value + inflow_cm
      aggregate%boundary_value%top_conductive_into_j_m2 = aggregate%boundary_value%top_conductive_into_j_m2 + &
           boundary%top_conductive_into_j_m2
      aggregate%boundary_value%top_advective_into_j_m2 = aggregate%boundary_value%top_advective_into_j_m2 + &
           boundary%top_advective_into_j_m2
      aggregate%boundary_value%bottom_conductive_outward_j_m2 = &
           aggregate%boundary_value%bottom_conductive_outward_j_m2 + boundary%bottom_conductive_outward_j_m2
      aggregate%boundary_value%bottom_advective_outward_j_m2 = &
           aggregate%boundary_value%bottom_advective_outward_j_m2 + boundary%bottom_advective_outward_j_m2
    end do

    if (.not. ieee_is_finite(aggregate%top_liquid_inflow_cm_value) .or. &
        .not. boundary_values_finite(aggregate%boundary_value)) then
      aggregate = eb_i26_outer_substep_sensible_boundary_publication_t()
      aggregate%status_value = EB_I26_NUMERIC_FAILURE
      return
    end if

    aggregate%committed_revision_value = previous_committed_revision
    aggregate%t1_value = previous_t1
    aggregate%boundary_value%top_conductive_available = .true.
    aggregate%boundary_value%top_advective_available = .true.
    aggregate%boundary_value%bottom_conductive_available = .true.
    aggregate%boundary_value%bottom_advective_available = .true.
    aggregate%status_value = EB_I26_ACCEPTED_COMPLETE
    aggregate%initialized = .true.

    if (.not. aggregate%ready()) then
      aggregate = eb_i26_outer_substep_sensible_boundary_publication_t()
      aggregate%status_value = EB_I26_INVALID_SEQUENCE
    end if
  end subroutine aggregate_accepted_outer_substep_sensible_boundaries

  logical function publication_ready(self) result(ready)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    ready = self%initialized .and. self%status_value == EB_I26_ACCEPTED_COMPLETE .and. &
         self%column_id_value > 0_int64 .and. self%lineage_id_value > 0_int64 .and. &
         self%origin_revision_value >= 0_int64 .and. &
         self%committed_revision_value == self%origin_revision_value + int(self%accepted_outer_substeps_value, int64) .and. &
         self%accepted_outer_substeps_value >= 2 .and. &
         self%accepted_internal_half_samples_value == 2*self%accepted_outer_substeps_value .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%top_liquid_inflow_cm_value) .and. self%top_liquid_inflow_cm_value >= 0.0_real64 .and. &
         self%boundary_value%complete() .and. boundary_values_finite(self%boundary_value)
  end function publication_ready

  integer function publication_status(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = self%status_value
  end function publication_status

  integer(int64) function publication_column_id(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%column_id_value
  end function publication_column_id

  integer(int64) function publication_lineage_id(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%lineage_id_value
  end function publication_lineage_id

  integer(int64) function publication_origin_revision(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%origin_revision_value
  end function publication_origin_revision

  integer(int64) function publication_committed_revision(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = -1_int64
    if (self%ready()) value = self%committed_revision_value
  end function publication_committed_revision

  subroutine publication_origin_interval(self, t0, t1, available)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available
    available = self%ready()
    t0 = 0.0_real64
    t1 = 0.0_real64
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    end if
  end subroutine publication_origin_interval

  integer function publication_accepted_outer_substeps(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = 0
    if (self%ready()) value = self%accepted_outer_substeps_value
  end function publication_accepted_outer_substeps

  integer function publication_accepted_internal_half_samples(self) result(value)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    value = 0
    if (self%ready()) value = self%accepted_internal_half_samples_value
  end function publication_accepted_internal_half_samples

  subroutine publication_top_liquid_inflow(self, inflow_cm, available)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    real(real64), intent(out) :: inflow_cm
    logical, intent(out) :: available
    available = self%ready()
    inflow_cm = 0.0_real64
    if (available) inflow_cm = self%top_liquid_inflow_cm_value
  end subroutine publication_top_liquid_inflow

  subroutine publication_boundary_snapshot(self, boundary, available)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    type(whole_column_sensible_boundary_t), intent(out) :: boundary
    logical, intent(out) :: available
    available = self%ready()
    boundary = whole_column_sensible_boundary_t()
    if (available) boundary = self%boundary_value
  end subroutine publication_boundary_snapshot

  logical function publication_runtime_complete(self) result(complete)
    class(eb_i26_outer_substep_sensible_boundary_publication_t), intent(in) :: self
    complete = self%ready() .and. self%boundary_value%complete()
  end function publication_runtime_complete

  pure logical function boundary_values_finite(boundary) result(valid)
    type(whole_column_sensible_boundary_t), intent(in) :: boundary
    valid = ieee_is_finite(boundary%top_conductive_into_j_m2) .and. &
         ieee_is_finite(boundary%top_advective_into_j_m2) .and. &
         ieee_is_finite(boundary%bottom_conductive_outward_j_m2) .and. &
         ieee_is_finite(boundary%bottom_advective_outward_j_m2) .and. &
         ieee_is_finite(boundary%mass_carried_reference_temperature_c)
  end function boundary_values_finite

  pure logical function same_time(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_time

  pure logical function same_value(a, b) result(matches)
    real(real64), intent(in) :: a, b
    real(real64) :: scale
    if (.not. ieee_is_finite(a) .or. .not. ieee_is_finite(b)) then
      matches = .false.
      return
    end if
    scale = max(1.0_real64, abs(a), abs(b))
    matches = abs(a-b) <= 64.0_real64 * epsilon(1.0_real64) * scale
  end function same_value

end module mod_eb_i26_outer_substep_sensible_boundary_aggregation
