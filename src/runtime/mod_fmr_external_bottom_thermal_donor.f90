module mod_fmr_external_bottom_thermal_donor
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FMR_EXTERNAL_DONOR_RESPONSE_NOT_SET = 0
  integer, parameter, public :: FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE = 1
  integer, parameter, public :: FMR_EXTERNAL_DONOR_RESPONSE_UNAVAILABLE = 2
  integer, parameter, public :: FMR_EXTERNAL_DONOR_RESPONSE_STALE = 3

  type, public :: fmr_external_bottom_donor_request_t
    private
    integer(int64) :: evaluation_token_value = 0_int64
    integer :: sample_ordinal_value = 0
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: outward_exchange_context_value = 0.0_real64
    real(real64) :: quadrature_time_value = 0.0_real64
  contains
    procedure, public :: ready => external_request_ready
    procedure, public :: evaluation_token => external_request_evaluation_token
    procedure, public :: sample_ordinal => external_request_sample_ordinal
    procedure, public :: interval => external_request_interval
    procedure, public :: outward_exchange_context => external_request_outward_exchange_context
    procedure, public :: quadrature_time => external_request_quadrature_time
  end type fmr_external_bottom_donor_request_t

  type, public :: fmr_external_bottom_donor_response_t
    private
    integer(int64) :: evaluation_token_value = 0_int64
    integer :: sample_ordinal_value = 0
    integer :: disposition_value = FMR_EXTERNAL_DONOR_RESPONSE_NOT_SET
    real(real64) :: donor_temperature_c_value = 0.0_real64
    integer(int64) :: provenance_id_value = 0_int64
    integer(int64) :: provenance_revision_value = -1_int64
  contains
    procedure, public :: clear => external_response_clear
    procedure, public :: set_complete => external_response_set_complete
    procedure, public :: set_unavailable => external_response_set_unavailable
    procedure, public :: set_stale => external_response_set_stale
    procedure, public :: disposition => external_response_disposition
    procedure, public :: identity_matches => external_response_identity_matches
    procedure, public :: well_formed => external_response_well_formed
    procedure, public :: donor_temperature => external_response_donor_temperature
    procedure, public :: provenance => external_response_provenance
  end type fmr_external_bottom_donor_response_t

  abstract interface
    subroutine fmr_external_bottom_donor_provider_i(request, response)
      import :: fmr_external_bottom_donor_request_t, fmr_external_bottom_donor_response_t
      type(fmr_external_bottom_donor_request_t), intent(in) :: request
      type(fmr_external_bottom_donor_response_t), intent(out) :: response
    end subroutine fmr_external_bottom_donor_provider_i
  end interface

  public :: fmr_external_bottom_donor_provider_i
  public :: initialize_fmr_external_bottom_donor_request

contains

  subroutine initialize_fmr_external_bottom_donor_request(evaluation_token, sample_ordinal, t0, t1, &
       outward_exchange_context, request, ok)
    integer(int64), intent(in) :: evaluation_token
    integer, intent(in) :: sample_ordinal
    real(real64), intent(in) :: t0, t1, outward_exchange_context
    type(fmr_external_bottom_donor_request_t), intent(out) :: request
    logical, intent(out) :: ok

    request = fmr_external_bottom_donor_request_t()
    ok = .false.
    if (evaluation_token <= 0_int64) return
    if (sample_ordinal <= 0) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    if (.not. ieee_is_finite(outward_exchange_context) .or. outward_exchange_context >= 0.0_real64) return

    request%evaluation_token_value = evaluation_token
    request%sample_ordinal_value = sample_ordinal
    request%t0_value = t0
    request%t1_value = t1
    request%outward_exchange_context_value = outward_exchange_context
    request%quadrature_time_value = t1
    ok = request%ready()
  end subroutine initialize_fmr_external_bottom_donor_request

  logical function external_request_ready(self) result(ready)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self

    ready = .false.
    if (self%evaluation_token_value <= 0_int64) return
    if (self%sample_ordinal_value <= 0) return
    if (.not. ieee_is_finite(self%t0_value) .or. .not. ieee_is_finite(self%t1_value)) return
    if (self%t1_value <= self%t0_value) return
    if (.not. ieee_is_finite(self%outward_exchange_context_value)) return
    if (self%outward_exchange_context_value >= 0.0_real64) return
    if (.not. ieee_is_finite(self%quadrature_time_value)) return
    if (self%quadrature_time_value /= self%t1_value) return
    ready = .true.
  end function external_request_ready

  integer(int64) function external_request_evaluation_token(self) result(value)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self
    value = self%evaluation_token_value
  end function external_request_evaluation_token

  integer function external_request_sample_ordinal(self) result(value)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self
    value = self%sample_ordinal_value
  end function external_request_sample_ordinal

  subroutine external_request_interval(self, t0, t1, available)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    t0 = 0.0_real64
    t1 = 0.0_real64
    if (.not. available) return
    t0 = self%t0_value
    t1 = self%t1_value
  end subroutine external_request_interval

  subroutine external_request_outward_exchange_context(self, value, available)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    available = self%ready()
    value = 0.0_real64
    if (available) value = self%outward_exchange_context_value
  end subroutine external_request_outward_exchange_context

  subroutine external_request_quadrature_time(self, value, available)
    class(fmr_external_bottom_donor_request_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    available = self%ready()
    value = 0.0_real64
    if (available) value = self%quadrature_time_value
  end subroutine external_request_quadrature_time

  subroutine external_response_clear(self)
    class(fmr_external_bottom_donor_response_t), intent(inout) :: self
    self = fmr_external_bottom_donor_response_t()
  end subroutine external_response_clear

  subroutine external_response_set_complete(self, request, donor_temperature_c, provenance_id, &
       provenance_revision, ok)
    class(fmr_external_bottom_donor_response_t), intent(inout) :: self
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    real(real64), intent(in) :: donor_temperature_c
    integer(int64), intent(in) :: provenance_id, provenance_revision
    logical, intent(out) :: ok

    call self%clear()
    ok = .false.
    if (.not. request%ready()) return
    if (.not. ieee_is_finite(donor_temperature_c)) return
    if (provenance_id <= 0_int64 .or. provenance_revision < 0_int64) return
    self%evaluation_token_value = request%evaluation_token()
    self%sample_ordinal_value = request%sample_ordinal()
    self%disposition_value = FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE
    self%donor_temperature_c_value = donor_temperature_c
    self%provenance_id_value = provenance_id
    self%provenance_revision_value = provenance_revision
    ok = self%well_formed()
  end subroutine external_response_set_complete

  subroutine external_response_set_unavailable(self, request, ok)
    class(fmr_external_bottom_donor_response_t), intent(inout) :: self
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    logical, intent(out) :: ok

    call self%clear()
    ok = .false.
    if (.not. request%ready()) return
    self%evaluation_token_value = request%evaluation_token()
    self%sample_ordinal_value = request%sample_ordinal()
    self%disposition_value = FMR_EXTERNAL_DONOR_RESPONSE_UNAVAILABLE
    ok = self%well_formed()
  end subroutine external_response_set_unavailable

  subroutine external_response_set_stale(self, request, provenance_id, provenance_revision, ok)
    class(fmr_external_bottom_donor_response_t), intent(inout) :: self
    type(fmr_external_bottom_donor_request_t), intent(in) :: request
    integer(int64), intent(in) :: provenance_id, provenance_revision
    logical, intent(out) :: ok

    call self%clear()
    ok = .false.
    if (.not. request%ready()) return
    if (provenance_id <= 0_int64 .or. provenance_revision < 0_int64) return
    self%evaluation_token_value = request%evaluation_token()
    self%sample_ordinal_value = request%sample_ordinal()
    self%disposition_value = FMR_EXTERNAL_DONOR_RESPONSE_STALE
    self%provenance_id_value = provenance_id
    self%provenance_revision_value = provenance_revision
    ok = self%well_formed()
  end subroutine external_response_set_stale

  integer function external_response_disposition(self) result(value)
    class(fmr_external_bottom_donor_response_t), intent(in) :: self
    value = self%disposition_value
  end function external_response_disposition

  logical function external_response_identity_matches(self, request) result(matches)
    class(fmr_external_bottom_donor_response_t), intent(in) :: self
    type(fmr_external_bottom_donor_request_t), intent(in) :: request

    matches = .false.
    if (.not. request%ready()) return
    matches = self%evaluation_token_value == request%evaluation_token() .and. &
         self%sample_ordinal_value == request%sample_ordinal()
  end function external_response_identity_matches

  logical function external_response_well_formed(self) result(valid)
    class(fmr_external_bottom_donor_response_t), intent(in) :: self

    valid = .false.
    if (self%evaluation_token_value <= 0_int64 .or. self%sample_ordinal_value <= 0) return
    select case (self%disposition_value)
    case (FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE)
      valid = ieee_is_finite(self%donor_temperature_c_value) .and. self%provenance_id_value > 0_int64 .and. &
           self%provenance_revision_value >= 0_int64
    case (FMR_EXTERNAL_DONOR_RESPONSE_UNAVAILABLE)
      valid = self%provenance_id_value == 0_int64 .and. self%provenance_revision_value == -1_int64
    case (FMR_EXTERNAL_DONOR_RESPONSE_STALE)
      valid = self%provenance_id_value > 0_int64 .and. self%provenance_revision_value >= 0_int64
    case default
      valid = .false.
    end select
  end function external_response_well_formed

  subroutine external_response_donor_temperature(self, donor_temperature_c, available)
    class(fmr_external_bottom_donor_response_t), intent(in) :: self
    real(real64), intent(out) :: donor_temperature_c
    logical, intent(out) :: available

    available = self%well_formed() .and. self%disposition_value == FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE
    donor_temperature_c = 0.0_real64
    if (available) donor_temperature_c = self%donor_temperature_c_value
  end subroutine external_response_donor_temperature

  subroutine external_response_provenance(self, provenance_id, provenance_revision, available)
    class(fmr_external_bottom_donor_response_t), intent(in) :: self
    integer(int64), intent(out) :: provenance_id, provenance_revision
    logical, intent(out) :: available

    available = self%well_formed() .and. (self%disposition_value == FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE .or. &
         self%disposition_value == FMR_EXTERNAL_DONOR_RESPONSE_STALE)
    provenance_id = 0_int64
    provenance_revision = -1_int64
    if (.not. available) return
    provenance_id = self%provenance_id_value
    provenance_revision = self%provenance_revision_value
  end subroutine external_response_provenance

end module mod_fmr_external_bottom_thermal_donor
