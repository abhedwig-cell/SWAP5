module mod_fmr_bottom_external_thermal_provider
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: FMR_EXT_THERMAL_RESPONSE_NOT_SET = 0
  integer, parameter, public :: FMR_EXT_THERMAL_RESPONSE_COMPLETE = 1
  integer, parameter, public :: FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE = 2
  integer, parameter, public :: FMR_EXT_THERMAL_RESPONSE_STALE = 3

  type, public :: fmr_external_bottom_thermal_request_t
    private
    logical :: initialized = .false.
    integer(int64) :: column_id_value = 0_int64
    integer :: sample_ordinal_value = 0
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: bottom_outward_exchange_native_value = 0.0_real64
  contains
    procedure, public :: ready => request_ready
    procedure, public :: column_id => request_column_id
    procedure, public :: sample_ordinal => request_sample_ordinal
    procedure, public :: interval => request_interval
    procedure, public :: bottom_outward_exchange_native => request_bottom_outward_exchange
  end type fmr_external_bottom_thermal_request_t

  type, public :: fmr_external_bottom_thermal_response_t
    private
    logical :: initialized = .false.
    integer :: disposition_value = FMR_EXT_THERMAL_RESPONSE_NOT_SET
    integer(int64) :: column_id_value = 0_int64
    integer :: sample_ordinal_value = 0
    real(real64) :: t0_value = 0.0_real64
    real(real64) :: t1_value = 0.0_real64
    real(real64) :: bottom_outward_exchange_native_value = 0.0_real64
    logical :: donor_temperature_available = .false.
    real(real64) :: donor_temperature_c_value = 0.0_real64
    integer(int64) :: source_provenance_token_value = 0_int64
  contains
    procedure, public :: set_complete => response_set_complete
    procedure, public :: set_unavailable => response_set_unavailable
    procedure, public :: set_stale => response_set_stale
    procedure, public :: ready => response_ready
    procedure, public :: identity_matches => response_identity_matches
    procedure, public :: disposition => response_disposition
    procedure, public :: donor_temperature => response_donor_temperature
    procedure, public :: source_provenance_token => response_source_provenance_token
  end type fmr_external_bottom_thermal_response_t

  abstract interface
    subroutine fmr_external_bottom_thermal_provider_i(request, response)
      import :: fmr_external_bottom_thermal_request_t, fmr_external_bottom_thermal_response_t
      type(fmr_external_bottom_thermal_request_t), intent(in) :: request
      type(fmr_external_bottom_thermal_response_t), intent(out) :: response
    end subroutine fmr_external_bottom_thermal_provider_i
  end interface

  public :: initialize_fmr_external_bottom_thermal_request
  public :: fmr_external_bottom_thermal_provider_i

contains

  subroutine initialize_fmr_external_bottom_thermal_request(column_id, sample_ordinal, t0, t1, &
       bottom_outward_exchange_native, request, ok)
    integer(int64), intent(in) :: column_id
    integer, intent(in) :: sample_ordinal
    real(real64), intent(in) :: t0, t1, bottom_outward_exchange_native
    type(fmr_external_bottom_thermal_request_t), intent(out) :: request
    logical, intent(out) :: ok

    request = fmr_external_bottom_thermal_request_t()
    ok = .false.
    if (column_id <= 0_int64 .or. sample_ordinal <= 0) return
    if (.not. ieee_is_finite(t0) .or. .not. ieee_is_finite(t1) .or. t1 <= t0) return
    if (.not. ieee_is_finite(bottom_outward_exchange_native) .or. &
        bottom_outward_exchange_native >= 0.0_real64) return

    request%column_id_value = column_id
    request%sample_ordinal_value = sample_ordinal
    request%t0_value = t0
    request%t1_value = t1
    request%bottom_outward_exchange_native_value = bottom_outward_exchange_native
    request%initialized = .true.
    ok = .true.
  end subroutine initialize_fmr_external_bottom_thermal_request

  logical function request_ready(self) result(ready)
    class(fmr_external_bottom_thermal_request_t), intent(in) :: self

    ready = self%initialized .and. self%column_id_value > 0_int64 .and. self%sample_ordinal_value > 0 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%bottom_outward_exchange_native_value) .and. &
         self%bottom_outward_exchange_native_value < 0.0_real64
  end function request_ready

  integer(int64) function request_column_id(self) result(value)
    class(fmr_external_bottom_thermal_request_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%column_id_value
  end function request_column_id

  integer function request_sample_ordinal(self) result(value)
    class(fmr_external_bottom_thermal_request_t), intent(in) :: self
    value = 0
    if (self%ready()) value = self%sample_ordinal_value
  end function request_sample_ordinal

  subroutine request_interval(self, t0, t1, available)
    class(fmr_external_bottom_thermal_request_t), intent(in) :: self
    real(real64), intent(out) :: t0, t1
    logical, intent(out) :: available

    available = self%ready()
    t0 = 0.0_real64
    t1 = 0.0_real64
    if (available) then
      t0 = self%t0_value
      t1 = self%t1_value
    end if
  end subroutine request_interval

  subroutine request_bottom_outward_exchange(self, value, available)
    class(fmr_external_bottom_thermal_request_t), intent(in) :: self
    real(real64), intent(out) :: value
    logical, intent(out) :: available

    available = self%ready()
    value = 0.0_real64
    if (available) value = self%bottom_outward_exchange_native_value
  end subroutine request_bottom_outward_exchange

  subroutine response_set_complete(self, request, donor_temperature_c, source_provenance_token, ok)
    class(fmr_external_bottom_thermal_response_t), intent(out) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    real(real64), intent(in) :: donor_temperature_c
    integer(int64), intent(in), optional :: source_provenance_token
    logical, intent(out) :: ok
    integer(int64) :: token

    call reset_response(self)
    ok = .false.
    if (.not. request%ready() .or. .not. ieee_is_finite(donor_temperature_c)) return
    token = 0_int64
    if (present(source_provenance_token)) token = source_provenance_token
    if (token < 0_int64) return

    call bind_response_identity(self, request, FMR_EXT_THERMAL_RESPONSE_COMPLETE)
    self%donor_temperature_available = .true.
    self%donor_temperature_c_value = donor_temperature_c
    self%source_provenance_token_value = token
    ok = self%ready()
  end subroutine response_set_complete

  subroutine response_set_unavailable(self, request, source_provenance_token, ok)
    class(fmr_external_bottom_thermal_response_t), intent(out) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    integer(int64), intent(in), optional :: source_provenance_token
    logical, intent(out) :: ok

    call set_noncomplete_response(self, request, FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, source_provenance_token, ok)
  end subroutine response_set_unavailable

  subroutine response_set_stale(self, request, source_provenance_token, ok)
    class(fmr_external_bottom_thermal_response_t), intent(out) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    integer(int64), intent(in), optional :: source_provenance_token
    logical, intent(out) :: ok

    call set_noncomplete_response(self, request, FMR_EXT_THERMAL_RESPONSE_STALE, source_provenance_token, ok)
  end subroutine response_set_stale

  subroutine set_noncomplete_response(self, request, disposition, source_provenance_token, ok)
    class(fmr_external_bottom_thermal_response_t), intent(out) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    integer, intent(in) :: disposition
    integer(int64), intent(in), optional :: source_provenance_token
    logical, intent(out) :: ok
    integer(int64) :: token

    call reset_response(self)
    ok = .false.
    if (.not. request%ready()) return
    if (disposition /= FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE .and. &
        disposition /= FMR_EXT_THERMAL_RESPONSE_STALE) return
    token = 0_int64
    if (present(source_provenance_token)) token = source_provenance_token
    if (token < 0_int64) return

    call bind_response_identity(self, request, disposition)
    self%source_provenance_token_value = token
    ok = self%ready()
  end subroutine set_noncomplete_response

  subroutine reset_response(self)
    class(fmr_external_bottom_thermal_response_t), intent(out) :: self

    self%initialized = .false.
    self%disposition_value = FMR_EXT_THERMAL_RESPONSE_NOT_SET
    self%column_id_value = 0_int64
    self%sample_ordinal_value = 0
    self%t0_value = 0.0_real64
    self%t1_value = 0.0_real64
    self%bottom_outward_exchange_native_value = 0.0_real64
    self%donor_temperature_available = .false.
    self%donor_temperature_c_value = 0.0_real64
    self%source_provenance_token_value = 0_int64
  end subroutine reset_response

  subroutine bind_response_identity(self, request, disposition)
    class(fmr_external_bottom_thermal_response_t), intent(inout) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request
    integer, intent(in) :: disposition

    self%initialized = .true.
    self%disposition_value = disposition
    self%column_id_value = request%column_id_value
    self%sample_ordinal_value = request%sample_ordinal_value
    self%t0_value = request%t0_value
    self%t1_value = request%t1_value
    self%bottom_outward_exchange_native_value = request%bottom_outward_exchange_native_value
  end subroutine bind_response_identity

  logical function response_ready(self) result(ready)
    class(fmr_external_bottom_thermal_response_t), intent(in) :: self

    ready = self%initialized .and. self%column_id_value > 0_int64 .and. self%sample_ordinal_value > 0 .and. &
         ieee_is_finite(self%t0_value) .and. ieee_is_finite(self%t1_value) .and. self%t1_value > self%t0_value .and. &
         ieee_is_finite(self%bottom_outward_exchange_native_value) .and. &
         self%bottom_outward_exchange_native_value < 0.0_real64 .and. self%source_provenance_token_value >= 0_int64
    if (.not. ready) return

    select case (self%disposition_value)
    case (FMR_EXT_THERMAL_RESPONSE_COMPLETE)
      ready = self%donor_temperature_available .and. ieee_is_finite(self%donor_temperature_c_value)
    case (FMR_EXT_THERMAL_RESPONSE_UNAVAILABLE, FMR_EXT_THERMAL_RESPONSE_STALE)
      ready = .not. self%donor_temperature_available
    case default
      ready = .false.
    end select
  end function response_ready

  logical function response_identity_matches(self, request) result(matches)
    class(fmr_external_bottom_thermal_response_t), intent(in) :: self
    type(fmr_external_bottom_thermal_request_t), intent(in) :: request

    matches = self%ready() .and. request%ready()
    if (.not. matches) return
    matches = self%column_id_value == request%column_id_value .and. &
         self%sample_ordinal_value == request%sample_ordinal_value .and. &
         same_bits(self%t0_value, request%t0_value) .and. same_bits(self%t1_value, request%t1_value) .and. &
         same_bits(self%bottom_outward_exchange_native_value, request%bottom_outward_exchange_native_value)
  end function response_identity_matches

  integer function response_disposition(self) result(value)
    class(fmr_external_bottom_thermal_response_t), intent(in) :: self
    value = FMR_EXT_THERMAL_RESPONSE_NOT_SET
    if (self%ready()) value = self%disposition_value
  end function response_disposition

  subroutine response_donor_temperature(self, donor_temperature_c, available)
    class(fmr_external_bottom_thermal_response_t), intent(in) :: self
    real(real64), intent(out) :: donor_temperature_c
    logical, intent(out) :: available

    available = self%ready() .and. self%disposition_value == FMR_EXT_THERMAL_RESPONSE_COMPLETE .and. &
         self%donor_temperature_available
    donor_temperature_c = 0.0_real64
    if (available) donor_temperature_c = self%donor_temperature_c_value
  end subroutine response_donor_temperature

  integer(int64) function response_source_provenance_token(self) result(value)
    class(fmr_external_bottom_thermal_response_t), intent(in) :: self
    value = 0_int64
    if (self%ready()) value = self%source_provenance_token_value
  end function response_source_provenance_token

  pure logical function same_bits(a, b) result(equal)
    real(real64), intent(in) :: a, b
    integer(int64) :: ia, ib
    ia = transfer(a, ia)
    ib = transfer(b, ib)
    equal = ia == ib
  end function same_bits

end module mod_fmr_bottom_external_thermal_provider
