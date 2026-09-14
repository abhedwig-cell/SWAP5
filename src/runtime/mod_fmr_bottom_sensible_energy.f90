module mod_fmr_bottom_sensible_energy
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_bottom_thermal_carrier, only: fmr_bottom_thermal_candidate_t, fmr_bottom_thermal_sample_t, &
       FMR_BOTTOM_THERMAL_DONOR_NONE, FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP, FMR_BOTTOM_THERMAL_DONOR_EXTERNAL
  use mod_fmr_bottom_external_thermal_binding, only: fmr_bottom_external_thermal_binding_bundle_t, &
       FMR_EXT_THERMAL_BINDING_OK, FMR_EXT_THERMAL_BINDING_UNAVAILABLE
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
  integer, parameter, public :: FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING = 7

  type, public :: fmr_bottom_sensible_energy_result_t
    private
    integer :: status_value = FMR_BOTTOM_ENERGY_NOT_EVALUATED
    logical :: complete_value = .false.
    real(real64) :: outward_positive_energy_j_m2_value = 0.0_real64
    real(real64) :: local_outward_subtotal_j_m2_value = 0.0_real64
    integer :: sample_count_value = 0
    integer :: local_outward_sample_count_value = 0
    integer :: zero_sample_count_value = 0
    integer :: incomplete_external_sample_count_value = 0
  contains
    procedure, public :: status => bottom_energy_result_status
    procedure, public :: complete => bottom_energy_result_complete
    procedure, public :: total_energy => bottom_energy_result_total_energy
    procedure, public :: local_outward_subtotal => bottom_energy_result_local_outward_subtotal
    procedure, public :: counts => bottom_energy_result_counts
  end type fmr_bottom_sensible_energy_result_t

  public :: evaluate_fmr_bottom_sensible_energy
  public :: evaluate_fmr_bottom_sensible_energy_with_external

contains

  subroutine evaluate_fmr_bottom_sensible_energy(candidate, parameters, result)
    type(fmr_bottom_thermal_candidate_t), intent(in) :: candidate
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    type(fmr_bottom_sensible_energy_result_t), intent(out) :: result
    type(fmr_bottom_thermal_sample_t) :: sample
    real(real64) :: sample_energy, subtotal, candidate_total
    integer :: i, n, enthalpy_status
    logical :: available

    result = fmr_bottom_sensible_energy_result_t()
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
        result%incomplete_external_sample_count_value = result%incomplete_external_sample_count_value + 1

      case default
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
        return
      end select
    end do

    result%local_outward_subtotal_j_m2_value = subtotal
    if (result%incomplete_external_sample_count_value > 0) then
      ! A local subtotal is useful diagnostics, but the total remains unavailable.
      ! Never encode missing external donor energy as zero.
      result%status_value = FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR
      result%complete_value = .false.
      result%outward_positive_energy_j_m2_value = 0.0_real64
      return
    end if

    result%outward_positive_energy_j_m2_value = candidate_total
    result%complete_value = .true.
    result%status_value = FMR_BOTTOM_ENERGY_COMPLETE
  end subroutine evaluate_fmr_bottom_sensible_energy

  subroutine evaluate_fmr_bottom_sensible_energy_with_external(candidate, candidate_lineage_id, bindings, parameters, result)
    type(fmr_bottom_thermal_candidate_t), intent(in) :: candidate
    integer(int64), intent(in) :: candidate_lineage_id
    type(fmr_bottom_external_thermal_binding_bundle_t), intent(in) :: bindings
    type(liquid_water_sensible_enthalpy_parameters_t), intent(in) :: parameters
    type(fmr_bottom_sensible_energy_result_t), intent(out) :: result

    type(fmr_bottom_sensible_energy_result_t) :: base_result
    type(fmr_bottom_thermal_sample_t) :: sample
    real(real64) :: donor_temperature_c, sample_energy, candidate_total
    integer(int64) :: provenance_token
    integer :: i, n, binding_status, enthalpy_status, resolved_external_count, missing_external_count
    logical :: sample_available, binding_available

    call evaluate_fmr_bottom_sensible_energy(candidate, parameters, base_result)
    result = base_result

    if (.not. candidate%ready() .or. .not. parameters%ready()) return
    if (candidate_lineage_id <= 0_int64 .or. .not. bindings%ready()) then
      call mark_invalid_external_binding(result)
      return
    end if
    if (bindings%candidate_lineage_id() /= candidate_lineage_id) then
      call mark_invalid_external_binding(result)
      return
    end if

    if (base_result%status_value == FMR_BOTTOM_ENERGY_COMPLETE) then
      if (bindings%binding_count() /= 0) call mark_invalid_external_binding(result)
      return
    end if
    if (base_result%status_value /= FMR_BOTTOM_ENERGY_INCOMPLETE_EXTERNAL_DONOR) return

    n = candidate%sample_count()
    candidate_total = base_result%local_outward_subtotal_j_m2_value
    resolved_external_count = 0
    missing_external_count = 0

    do i = 1, n
      call candidate%sample_at(i, sample, sample_available)
      if (.not. sample_available) then
        result = base_result
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
        return
      end if

      call bindings%resolve(candidate_lineage_id, i, donor_temperature_c, provenance_token, binding_available, binding_status)

      select case (sample%donor_class)
      case (FMR_BOTTOM_THERMAL_DONOR_EXTERNAL)
        if (binding_status == FMR_EXT_THERMAL_BINDING_UNAVAILABLE .and. .not. binding_available) then
          missing_external_count = missing_external_count + 1
        else
          if (binding_status /= FMR_EXT_THERMAL_BINDING_OK .or. .not. binding_available) then
            result = base_result
            call mark_invalid_external_binding(result)
            return
          end if
          if (provenance_token < 0_int64 .or. .not. ieee_is_finite(donor_temperature_c)) then
            result = base_result
            call mark_invalid_external_binding(result)
            return
          end if
          call evaluate_liquid_water_sensible_transport(sample%bottom_outward_exchange_native, donor_temperature_c, &
               parameters, sample_energy, enthalpy_status)
          if (enthalpy_status /= LWSE_OK .or. .not. ieee_is_finite(sample_energy)) then
            result = base_result
            result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
            result%complete_value = .false.
            result%outward_positive_energy_j_m2_value = 0.0_real64
            return
          end if
          candidate_total = candidate_total + sample_energy
          if (.not. ieee_is_finite(candidate_total)) then
            result = base_result
            result%status_value = FMR_BOTTOM_ENERGY_NUMERIC_FAILURE
            result%complete_value = .false.
            result%outward_positive_energy_j_m2_value = 0.0_real64
            return
          end if
          resolved_external_count = resolved_external_count + 1
        end if

      case (FMR_BOTTOM_THERMAL_DONOR_LOCAL_SWAP, FMR_BOTTOM_THERMAL_DONOR_NONE)
        if (binding_status == FMR_EXT_THERMAL_BINDING_OK .and. binding_available) then
          result = base_result
          call mark_invalid_external_binding(result)
          return
        end if
        if (binding_status /= FMR_EXT_THERMAL_BINDING_UNAVAILABLE .or. binding_available) then
          result = base_result
          call mark_invalid_external_binding(result)
          return
        end if

      case default
        result = base_result
        result%status_value = FMR_BOTTOM_ENERGY_INVALID_SAMPLE
        return
      end select
    end do

    ! Scan all candidate ordinals before classifying missing provenance. This
    ! ensures extra or out-of-range bundle entries fail invalid rather than
    ! being hidden behind an earlier missing external donor.
    if (bindings%binding_count() /= resolved_external_count) then
      result = base_result
      call mark_invalid_external_binding(result)
      return
    end if

    if (missing_external_count > 0) then
      result = base_result
      return
    end if

    result = base_result
    result%outward_positive_energy_j_m2_value = candidate_total
    result%incomplete_external_sample_count_value = 0
    result%complete_value = .true.
    result%status_value = FMR_BOTTOM_ENERGY_COMPLETE
  end subroutine evaluate_fmr_bottom_sensible_energy_with_external

  subroutine mark_invalid_external_binding(result)
    type(fmr_bottom_sensible_energy_result_t), intent(inout) :: result

    result%status_value = FMR_BOTTOM_ENERGY_INVALID_EXTERNAL_BINDING
    result%complete_value = .false.
    result%outward_positive_energy_j_m2_value = 0.0_real64
  end subroutine mark_invalid_external_binding

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

  subroutine bottom_energy_result_counts(self, sample_count, local_outward_count, zero_count, incomplete_external_count)
    class(fmr_bottom_sensible_energy_result_t), intent(in) :: self
    integer, intent(out) :: sample_count, local_outward_count, zero_count, incomplete_external_count

    sample_count = self%sample_count_value
    local_outward_count = self%local_outward_sample_count_value
    zero_count = self%zero_sample_count_value
    incomplete_external_count = self%incomplete_external_sample_count_value
  end subroutine bottom_energy_result_counts

end module mod_fmr_bottom_sensible_energy
