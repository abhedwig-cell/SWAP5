module mod_fmr_irrigation_reference_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_state_t, irrigation_flux_result_t, irrigation_diagnostics_t
  use mod_fmr_irrigation_source_binding, only: fmr_bind_irrigation_to_subsurface_source, &
       fmr_irrigation_source_diagnostics_t, FMR_IRR_SOURCE_OK
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t
  implicit none
  private
  integer, parameter, public :: FMR_IRR_REFERENCE_OK = 0
  integer, parameter, public :: FMR_IRR_REFERENCE_INVALID = 1
  public :: fmr_bind_ssdi_reference_candidate, fmr_publish_accepted_irrigation_state
contains
  subroutine fmr_bind_ssdi_reference_candidate(base, flux, diagnostics, candidate, status)
    type(fmr_b110_physical_forcing_t), intent(in) :: base
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: diagnostics
    type(fmr_b110_physical_forcing_t), intent(out) :: candidate
    integer, intent(out) :: status
    type(fmr_irrigation_source_diagnostics_t) :: bound
    real(real64), allocatable :: source(:)

    status = FMR_IRR_REFERENCE_INVALID
    if (.not. allocated(base%subsurface_irrigation_source)) return
    if (.not. allocated(flux%subsurface_source)) return
    if (.not. ieee_is_finite(flux%active_duration) .or. &
        .not. ieee_is_finite(flux%external_inflow_amount)) return
    if (flux%active_duration <= 0.0_real64 .or. flux%external_inflow_amount < 0.0_real64) return
    if (size(flux%subsurface_source) /= size(base%subsurface_irrigation_source)) return
    if (abs(sum(flux%subsurface_source)*flux%active_duration-flux%external_inflow_amount) > &
        1.e-12_real64*max(1.0_real64,flux%external_inflow_amount)) return
    call fmr_bind_irrigation_to_subsurface_source(base%subsurface_irrigation_source, &
         flux, diagnostics, source, bound)
    if (bound%status /= FMR_IRR_SOURCE_OK) return
    candidate = base
    candidate%subsurface_irrigation_source = source
    status = FMR_IRR_REFERENCE_OK
  end subroutine

  subroutine fmr_publish_accepted_irrigation_state(committed, proposed, result, &
       expected_column_id, expected_t1, published)
    type(irrigation_state_t), intent(inout) :: committed
    type(irrigation_state_t), intent(in) :: proposed
    type(fmr_serialized_column_result_t), intent(in) :: result
    integer(int64), intent(in) :: expected_column_id
    real(real64), intent(in) :: expected_t1
    logical, intent(out) :: published
    published = .false.
    if (expected_column_id <= 0_int64 .or. .not. ieee_is_finite(expected_t1)) return
    if (result%column_id /= expected_column_id) return
    if (.not. result%completed .or. .not. result%committed .or. &
        .not. result%mass%complete .or. .not. result%final_committed_time_bound) return
    if (.not. ieee_is_finite(result%final_committed_time)) return
    if (result%final_committed_time /= expected_t1) return
    published = .true.
    if (published) committed = proposed
  end subroutine
end module
