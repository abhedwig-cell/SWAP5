module mod_solute_water_face_flux_reconstruction
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  integer, parameter, public :: WATER_FACE_FLUX_OK = 0
  integer, parameter, public :: WATER_FACE_FLUX_INVALID = 1
  integer, parameter, public :: WATER_FACE_FLUX_BOUNDARY_CLOSURE = 2

  public :: reconstruct_interval_water_face_flux

contains

  ! Reconstructs the unique conservative, interval-mean vertical face fluxes
  ! from the accepted water storage change and the signed net source rate in
  ! each node. Positive flux is downward. This is a continuity reconstruction,
  ! not a Richards constitutive flux evaluation; the independently supplied
  ! bottom flux is the closure check. Sources are positive into the node and
  ! sinks are negative. All water quantities use cm, cm/day, and day.
  subroutine reconstruct_interval_water_face_flux(node_thickness_cm, water_start, water_end, net_source_rate, &
       top_flux_down_cm_day, bottom_flux_down_cm_day, dt_day, closure_tolerance_cm_day, face_flux_down_cm_day, &
       bottom_closure_cm_day, status)
    real(real64), intent(in) :: node_thickness_cm(:), water_start(:), water_end(:), net_source_rate(:)
    real(real64), intent(in) :: top_flux_down_cm_day, bottom_flux_down_cm_day, dt_day, closure_tolerance_cm_day
    real(real64), allocatable, intent(out) :: face_flux_down_cm_day(:)
    real(real64), intent(out) :: bottom_closure_cm_day
    integer, intent(out) :: status

    real(real64) :: storage_rate, scale, tolerance
    integer :: n, i

    if (allocated(face_flux_down_cm_day)) deallocate(face_flux_down_cm_day)
    bottom_closure_cm_day = 0.0_real64
    status = WATER_FACE_FLUX_INVALID
    n = size(node_thickness_cm)
    if (n <= 0 .or. size(water_start) /= n .or. size(water_end) /= n .or. size(net_source_rate) /= n) return
    if (.not. all(ieee_is_finite(node_thickness_cm)) .or. .not. all(ieee_is_finite(water_start)) .or. &
        .not. all(ieee_is_finite(water_end)) .or. .not. all(ieee_is_finite(net_source_rate)) .or. &
        .not. all(ieee_is_finite([top_flux_down_cm_day, bottom_flux_down_cm_day, dt_day, &
                                  closure_tolerance_cm_day]))) return
    if (any(node_thickness_cm <= 0.0_real64) .or. any(water_start <= 0.0_real64) .or. &
        any(water_end <= 0.0_real64) .or. dt_day <= 0.0_real64 .or. closure_tolerance_cm_day < 0.0_real64) return

    allocate(face_flux_down_cm_day(n+1))
    face_flux_down_cm_day(1) = top_flux_down_cm_day
    do i = 1, n
      storage_rate = (water_end(i)-water_start(i))*node_thickness_cm(i)/dt_day
      face_flux_down_cm_day(i+1) = face_flux_down_cm_day(i) + net_source_rate(i) - storage_rate
      if (.not. ieee_is_finite(face_flux_down_cm_day(i+1))) then
        deallocate(face_flux_down_cm_day)
        return
      end if
    end do

    bottom_closure_cm_day = face_flux_down_cm_day(n+1) - bottom_flux_down_cm_day
    scale = max(1.0_real64, abs(top_flux_down_cm_day), abs(bottom_flux_down_cm_day), &
                maxval(abs(face_flux_down_cm_day)), maxval(abs(net_source_rate)))
    tolerance = max(closure_tolerance_cm_day, 128.0_real64*epsilon(1.0_real64)*scale)
    if (abs(bottom_closure_cm_day) > tolerance) then
      status = WATER_FACE_FLUX_BOUNDARY_CLOSURE
      deallocate(face_flux_down_cm_day)
      return
    end if
    status = WATER_FACE_FLUX_OK
  end subroutine reconstruct_interval_water_face_flux

end module mod_solute_water_face_flux_reconstruction
