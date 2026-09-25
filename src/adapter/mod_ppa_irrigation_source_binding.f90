! Candidate SSDI binding; no scheduling, commit, or restart ownership.
module mod_ppa_irrigation_source_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_irrigation_process, only: irrigation_flux_result_t, irrigation_diagnostics_t, &
       IRRIGATION_OK, IRRIGATION_APPLICATION_SSDI
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_forcing_t
  implicit none
  private
  public :: bind_ppa_irrigation_source
contains
  subroutine bind_ppa_irrigation_source(previous,flux,diagnostics,t0,forcing,ok)
    type(fmr_b110_physical_forcing_t), intent(in) :: previous
    type(irrigation_flux_result_t), intent(in) :: flux
    type(irrigation_diagnostics_t), intent(in) :: diagnostics
    real(real64), intent(in) :: t0
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcing
    logical, intent(out) :: ok
    real(real64), allocatable :: source(:)
    logical :: marked
    integer :: n
    ok=.false.
    if(diagnostics%status/=IRRIGATION_OK.or.diagnostics%split_required) return
    if(.not.ieee_is_finite(t0)) return
    ! This route binds water-only SSDI. Do not silently discard a surface
    ! delivery or solute concentration carried by a broader process result.
    if(.not.ieee_is_finite(flux%surface_gross_rate)) return
    if(.not.ieee_is_finite(flux%concentration)) return
    if(flux%surface_gross_rate/=0.0_real64.or.flux%concentration/=0.0_real64) return
    if(.not.allocated(previous%subsurface_irrigation_source)) return
    n=size(previous%subsurface_irrigation_source)
    if(n<1) return
    if(.not.all(ieee_is_finite(previous%subsurface_irrigation_source))) return
    if(any(previous%subsurface_irrigation_source<0.0_real64)) return
    marked=.false.
    if(previous%temporal_forcing_event) then
      if(.not.ieee_is_finite(previous%temporal_forcing_event_time)) return
      if(previous%temporal_forcing_event_time>t0) return
      marked=previous%temporal_forcing_event_time==t0
    end if
    allocate(source(n))
    source=0.0_real64
    if(flux%applied) then
      if(flux%application_type/=IRRIGATION_APPLICATION_SSDI) return
      if(.not.allocated(flux%subsurface_source)) return
      if(size(flux%subsurface_source)/=n) return
      if(.not.all(ieee_is_finite(flux%subsurface_source))) return
      if(any(flux%subsurface_source<0.0_real64)) return
      source=flux%subsurface_source
    else
      ! Inactive process output must not conceal a nonzero delivery.
      if(allocated(flux%subsurface_source)) then
        if(size(flux%subsurface_source)/=n) return
        if(.not.all(ieee_is_finite(flux%subsurface_source))) return
        if(any(flux%subsurface_source/=0.0_real64)) return
      end if
    end if
    marked=marked.or.any(source/=previous%subsurface_irrigation_source)
    allocate(forcing,source=previous)
    forcing%subsurface_irrigation_source=source
    forcing%temporal_forcing_event=marked
    forcing%temporal_forcing_event_time=0.0_real64
    if(marked) forcing%temporal_forcing_event_time=t0
    ok=.true.
  end subroutine
end module
