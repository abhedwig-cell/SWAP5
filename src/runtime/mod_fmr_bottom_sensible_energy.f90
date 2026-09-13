module mod_fmr_bottom_sensible_energy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_candidate_t, fmr_bottom_thermal_sample_t, &
       FMR_BOTTOM_THERMAL_DONOR_NONE, FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP, FMR_BOTTOM_THERMAL_DONOR_EXTERNAL
  use mod_fmr_external_bottom_thermal_donor, only: fmr_external_bottom_donor_request_t, &
       fmr_external_bottom_donor_response_t, fmr_external_bottom_donor_provider_i, &
       initialize_fmr_external_bottom_donor_request, FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE, &
       FMR_EXTERNAL_DONOR_RESPONSE_UNAVAILABLE, FMR_EXTERNAL_DONOR_RESPONSE_STALE
  use mod_liquid_water_sensible_enthalpy, only: liquid_water_sensible_enthalpy_parameters_t, &
       evaluate_liquid_water_sensible_transport, LWSE_OK
  implicit none
  private

  integer, parameter, public :: FMR_BOTTOM_ENERGY_NOT_EVALUATED = 0
  integer, parameter, public :: FMR_BOTTOM_ENERGY_COMPLETE = 1
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR = 2
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_CANDIDATE = 3
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_PROPERTIES = 4
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_SAMPLE = 5
  integer, parameter, public :: FMR_BOTTOM_ENERGY_NUMERIC_FAILURE = 6
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT = 7
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE = 8

  type, public :: fmr_bottom_sensible_energy_result_t
    private
    integer :: status_value = FMR_BOTTOM_ENERGY_NOT_EVALUATED
    logical :: complete_value = .false.
    real(real64) :: outward_positive_energy_j_m2_value = 0.0_real64
    real(real64) :: local_outward_subtotal_j_m2_value = 0.0_real64
    real(real64) :: external_inward_subtotal_j_m2_value = 0.0_real64
    integer :: sample_count_value = 0
    integer :: local_outward_sample_count_value = 0
    integer :: zero_sample_count_value = 0
    integer :: incomplete_external_sample_count_value = 0
    integer :: external_complete_sample_count_value = 0
    integer :: external_unavailable_sample_count_value = 0
    integer :: external_stale_sample_count_value = 0
    integer :: external_invalid_sample_count_value = 0
    integer :: external_identity_mismatch_count_value = 0
  contains
    procedure, public :: status => bottom_energy_result_status
    procedure, public :: complete => bottom_energy_result_complete
    procedure, public :: total_energy => bottom_energy_result_total_energy
    procedure, public :: local_outward_subtotal => bottom_energy_result_local_outward_subtotal
    procedure, public :: external_inward_subtotal => bottom_energy_result_external_inward_subtotal
    procedure, public :: counts => bottom_energy_result_counts
    procedure, public :: external_counts => bottom_energy_result_external_counts
  end type fmr_bottom_sensible_energy_result_t

  public :: evaluate_fmr_bottom_sensible_energy
  public :: evaluate_fmr_bottom_sensible_energy_with_external_provider

contains

  subroutine evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    type(fmr_bottom_thermal_candidate_t), intent(in) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    type(fmr_bottom_sensible_energy_result_t), intent(out) :: result

    call evaluate_fmr_bottom_sensible_energy_core(candidate, parameters, result)
  end subroutine evaluate_fmr_bottom_sensible_energy

  subroutine evaluate_fmr_bottom_sensible_energy_with_external_provider(candidate, parameters, evaluation_token, &
       provider, result)
    type(fmr_bottom_thermal_candidate_t), intent(in) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    integer(int64), intent(in) :: evaluation_token
    procedure(fmr_external_bottom_donor_provider_i) :: provider
    type(fmr_bottom_sensible_energy_result_t), intent(out) :: result

    call evaluate_fmr_bottom_sensible_energy_core(candidate, parameters, result, evaluation_token, provider)
  end subroutine evaluate_fmr_bottom_sensible_energy_with_external_provider

  subroutine evaluate_fmr_bottom_sensible_energy_core(candidate, parameters, result, evaluation_token, provider)
    type(fmr_bottom_thermal_candidate_t), intent(in) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    type(fmr_bottom_sensible_energy_result_t), intent(out) :: result
    integer(int64), intent(in), optional :: evaluation_token
    procedure(fmr_external_bottom_donor_provider_i), optional :: provider
    type(fmr_bottom_thermal_sample_t) :: sample
    type(fmr_external_bottom_donor_request_t) :: request
    type(fmr_external_bottom_donor_response_t) :: response
    real(real64) :: sample_energy, subtotal, external_subtotal, candidate_total, external_temperature_c
    integer :: i, n, enthalpy_status, response_disposition
    logical :: available, request_ok, provider_enabled

    result = fmr_bottom_sensible_energy_result_t()
    provider_enabled = present(provider)
    if (provider_enabled .neqv. present(evaluation_token)) then
      result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT
      return
    end if
    if (provider_enabled) then
      if (evaluation_token <= 0_int64) then
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT
        return
      end if
    end if
    if (.not. parameters%ready()) then
      result%status_value = FMR_BOTTOM_ENERGY_INVALID_PROPERTIES
      return
    end if
    if (.not. candidate%ready()) then
      result%status_value = FMR_BOTTOM_ENERGY_INVALID_CANDIDATE
      return
    end if

    n = candidate%sample_count()
    if (n <= 0) then
      result%status_value = FMR_BOTTOM_ENERGY_INVALID_CANDIDATE
      return
    end if
    result%sample_count_value = n
    subtotal = 0.0_real64
    external_subtotal = 0.0_real64
    candidate_total = 0.0_real64

    do i = 1, n
      call candidate%sample_at(i, sample, available)
      if (.not. available .or. .not. ieee_is_finite(sample%bottom_outward_exchange_native)) then
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
        return
      end if

      select case (sample%donor_class)
      case (FMR_BOTTOM_THERMAL_DONOR_NONE)
        if (sample%bottom_outward_exchange_native /= 0.0_real64 .or. .not. sample%donor_thermal_complete) then
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
          return
        end if
        result%zero_sample_count_value = result%zero_sample_count_value + 1

      case (FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP)
        if (sample%bottom_outward_exchange_native <= 0.0_real64 .or. .not. sample%donor_thermal_complete .or. &
            .not. ieee_is_finite(sample%local_end_temperature_c)) then
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
          return
        end if
        call evaluate_liquid_water_sensible_transport(sample%bottom_outward_exchange_native, &
             sample%local_end_temperature_c, parameters, sample_energy, enthalpy_status)
        if (enthalpy_status /= LWSE_OK .or. .not. ieee_is_finite(sample_energy)) then
          result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
          return
        end if
        subtotal = subtotal + sample_energy
        candidate_total = candidate_total + sample_energy
        if (.not. ieee_is_finite(subtotal) .or. .not. ieee_is_finite(candidate_total)) then
          result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
          return
        end if
        result%local_outward_sample_count_value = result%local_outward_sample_count_value + 1

      case (FMR_BOTTOM_THERMAL_DONOR_EXTERNAL)
        if (sample%bottom_outward_exchange_native >= 0.0_real64 .or. sample%donor_thermal_complete) then
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
          return
        end if

        if (.not. provider_enabled) then
          result%incomplete_external_sample_count_value = result%incomplete_external_sample_count_value + 1
          result%external_unavailable_sample_count_value = result%external_unavailable_sample_count_value + 1
          cycle
        end if

        call initialize_fmr_external_bottom_donor_request(evaluation_token, i, sample%t0, sample%t1, &
             sample%bottom_outward_exchange_native, request, request_ok)
        if (.not. request_ok) then
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_CONTEXT
          return
        end if

        call provider(request, response)
        if (.not. response%identity_matches(request)) then
          result%external_invalid_sample_count_value = result%external_invalid_sample_count_value + 1
          result%external_identity_mismatch_count_value = result%external_identity_mismatch_count_value + 1
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE
          return
        end if
        if (.not. response%well_formed()) then
          result%external_invalid_sample_count_value = result%external_invalid_sample_count_value + 1
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE
          return
        end if

        response_disposition = response%disposition()
        select case (response_disposition)
        case (FMR_EXTERNAL_DONOR_RESPONSE_COMPLETE)
          call response%donor_temperature(external_temperature_c, available)
          if (.not. available .or. .not. ieee_is_finite(external_temperature_c)) then
            result%external_invalid_sample_count_value = result%external_invalid_sample_count_value + 1
            result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE
            return
          end if
          call evaluate_liquid_water_sensible_transport(sample%bottom_outward_exchange_native, &
               external_temperature_c, parameters, sample_energy, enthalpy_status)
          if (enthalpy_status /= LWSE_OK .or. .not. ieee_is_finite(sample_energy)) then
            result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
            return
          end if
          external_subtotal = external_subtotal + sample_energy
          candidate_total = candidate_total + sample_energy
          if (.not. ieee_is_finite(external_subtotal) .or. .not. ieee_is_finite(candidate_total)) then
            result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
            return
          end if
          result%external_complete_sample_count_value = result%external_complete_sample_count_value + 1

        case (FMR_EXTERNAL_DONOR_RESPONSE_UNAVAILABLE)
          result%incomplete_external_sample_count_value = result%incomplete_external_sample_count_value + 1
          result%external_unavailable_sample_count_value = result%external_unavailable_sample_count_value + 1

        case (FMR_EXTERNAL_DONOR_RESPONSE_STALE)
          result%incomplete_external_sample_count_value = result%incomplete_external_sample_count_value + 1
          result%external_stale_sample_count_value = result%external_stale_sample_count_value + 1

        case default
          result%external_invalid_sample_count_value = result%external_invalid_sample_count_value + 1
          result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_RESPONSE
          return
        end select

      case default
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
        return
      end select
    end do

    result%local_outward_subtotal_j_m2_value = subtotal
    result%external_inward_subtotal_j_m2_value = external_subtotal
    if (result%incomplete_external_sample_count_value > 0) then
      ! Partial diagnostic subtotals are available, but the complete total is not.
      ! Never encode missing or stale external donor energy as zero.
      result%status_value = FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR
      result%complete_value = .false.
      result%outward_positive_energy_j_m2_value = 0.0_real64
      return
    end if

    result%outward_positive_energy_j_m2_value = candidate_total
    result%complete_value = .true.
    result%status_value = FMR_BOTTOM_ENERGY_COMPLETE
  end subroutine evaluate_fmr_bottom_sensible_energy_core

  integer function bottom_energy_result_status(self) result(status)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    status = self%status_value
  end function bottom_energy_result_status

  logical function bottom_energy_result_complete(self) result(complete)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    complete = self%complete_value .and. self%status_value == FMR_BOTTOM_ENERGY_COMPLETE
  end function bottom_energy_result_complete

  subroutine bottom_energy_result_total_energy(self, energy_j_m2, available)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    real(real64), intent(out) :: energy_j_m2
    logical, intent(out) :: available

    available = self%complete()
    energy_j_m2 = 0.0_real64
    if (available) energy_j_m2 = self%outward_positive_energy_j_m2_value
  end subroutine bottom_energy_result_total_energy

  subroutine bottom_energy_result_local_outward_subtotal(self, energy_j_m2, available)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    real(real64), intent(out) :: energy_j_m2
    logical, intent(out) :: available

    available = self%status_value == FMR_BOTTOM_ENERGY_COMPLETE .or. &
         self%status_value == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR
    energy_j_m2 = 0.0_real64
    if (available) energy_j_m2 = self%local_outward_subtotal_j_m2_value
  end subroutine bottom_energy_result_local_outward_subtotal

  subroutine bottom_energy_result_external_inward_subtotal(self, energy_j_m2, available)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    real(real64), intent(out) :: energy_j_m2
    logical, intent(out) :: available

    available = self%status_value == FMR_BOTTOM_ENERGY_COMPLETE .or. &
         self%status_value == FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR
    energy_j_m2 = 0.0_real64
    if (available) energy_j_m2 = self%external_inward_subtotal_j_m2_value
  end subroutine bottom_energy_result_external_inward_subtotal

  subroutine bottom_energy_result_counts(self, sample_count, local_outward_count, zero_count, incomplete_external_count)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    integer, intent(out) :: sample_count, local_outward_count, zero_count, incomplete_external_count

    sample_count = self%sample_count_value
    local_outward_count = self%local_outward_sample_count_value
    zero_count = self%zero_sample_count_value
    incomplete_external_count = self%incomplete_external_sample_count_value
  end subroutine bottom_energy_result_counts

  subroutine bottom_energy_result_external_counts(self, complete_count, unavailable_count, stale_count, &
       invalid_count, identity_mismatch_count)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    integer, intent(out) :: complete_count, unavailable_count, stale_count, invalid_count, identity_mismatch_count

    complete_count = self%external_complete_sample_count_value
    unavailable_count = self%external_unavailable_sample_count_value
    stale_count = self%external_stale_sample_count_value
    invalid_count = self%external_invalid_sample_count_value
    identity_mismatch_count = self%external_identity_mismatch_count_value
  end subroutine bottom_energy_result_external_counts

end module mod_fmr_bottom_sensible_energy
