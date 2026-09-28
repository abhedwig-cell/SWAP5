module mod_ppa_wu05a3_drainable_storage
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a3_volundr, only: ppa_wu05a3_volume_under_level, PPA_WU05A3_OK
  implicit none
  private

  integer, parameter, public :: PPA_WU05A3_STORAGE_OK = 0
  integer, parameter, public :: PPA_WU05A3_STORAGE_INVALID_INPUT = 1
  integer, parameter, public :: PPA_WU05A3_STORAGE_GEOMETRY_ERROR = 2

  public :: ppa_wu05a3_drainable_storage

contains

  pure subroutine ppa_wu05a3_drainable_storage(drain_base, macropore_bottom, bottom_compartment, dz, &
                                                pore_volume, domain_storage, drainable, status)
    real(real64), intent(in) :: drain_base, macropore_bottom, dz(:), pore_volume(:), domain_storage
    integer, intent(in) :: bottom_compartment
    real(real64), intent(out) :: drainable
    integer, intent(out) :: status
    real(real64) :: volume_under_drain
    integer :: volume_status, n

    drainable = 0.0_real64
    status = PPA_WU05A3_STORAGE_INVALID_INPUT
    n = size(dz)
    if (n <= 0 .or. size(pore_volume) /= n) return
    if (bottom_compartment < 1 .or. bottom_compartment > n) return
    if (.not. ieee_is_finite(drain_base) .or. .not. ieee_is_finite(macropore_bottom) .or. &
        .not. ieee_is_finite(domain_storage)) return
    if (domain_storage < 0.0_real64) return
    if (.not. all(ieee_is_finite(dz)) .or. any(dz <= 0.0_real64)) return
    if (macropore_bottom < drain_base) then
      call ppa_wu05a3_volume_under_level(drain_base, macropore_bottom - 0.5_real64*dz(bottom_compartment), &
                                        bottom_compartment, dz, pore_volume, volume_under_drain, volume_status)
      if (volume_status /= PPA_WU05A3_OK) then
        status = PPA_WU05A3_STORAGE_GEOMETRY_ERROR
        return
      end if
    else
      volume_under_drain = 0.0_real64
    end if

    ! Source: B1.11 SWAP/macrorate.f90 RAPIDDRAIN, lines 1905-1906.
    drainable = max(0.0_real64, domain_storage - volume_under_drain)
    if (.not. ieee_is_finite(drainable)) then
      drainable = 0.0_real64
      return
    end if
    status = PPA_WU05A3_STORAGE_OK
  end subroutine ppa_wu05a3_drainable_storage

end module mod_ppa_wu05a3_drainable_storage
