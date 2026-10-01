module mod_macropore_covering_layer_input
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private

  type, public :: covering_layer_input_request_t
    integer :: top_node = 0
    real(real64) :: step_duration_day = 0.0_real64
    real(real64) :: matrix_head_above_cm = 0.0_real64
    real(real64) :: dz_above_cm = 0.0_real64
    real(real64) :: minimum_polygon_diameter_cm = 0.0_real64
    real(real64) :: covering_layer_ksat_cm_per_day = 0.0_real64
    real(real64) :: total_macropore_volume_top_cm = 0.0_real64
    real(real64), allocatable :: domain_top_volume_cm(:)
  contains
    procedure, public :: valid => covering_layer_request_valid
  end type covering_layer_input_request_t

  public :: evaluate_covering_layer_input

contains

  pure logical function covering_layer_request_valid(self) result(ok)
    class(covering_layer_input_request_t), intent(in) :: self
    real(real64) :: scalars(6)

    ok = .false.
    if (self%top_node <= 1) return
    if (.not. allocated(self%domain_top_volume_cm)) return
    if (size(self%domain_top_volume_cm) <= 0) return
    scalars = [self%step_duration_day, self%matrix_head_above_cm, self%dz_above_cm, &
         self%minimum_polygon_diameter_cm, self%covering_layer_ksat_cm_per_day, &
         self%total_macropore_volume_top_cm]
    if (.not. all(ieee_is_finite(scalars))) return
    if (self%step_duration_day <= 0.0_real64 .or. self%dz_above_cm <= 0.0_real64) return
    if (self%minimum_polygon_diameter_cm <= 0.0_real64 .or. self%covering_layer_ksat_cm_per_day < 0.0_real64) return
    if (self%total_macropore_volume_top_cm <= 0.0_real64 .or. self%total_macropore_volume_top_cm >= 1.0_real64) return
    if (any(.not. ieee_is_finite(self%domain_top_volume_cm)) .or. any(self%domain_top_volume_cm < 0.0_real64)) return
    if (abs(sum(self%domain_top_volume_cm)-self%total_macropore_volume_top_cm) > 1.0e-12_real64) return
    ok = .true.
  end function covering_layer_request_valid

  subroutine evaluate_covering_layer_input(request, requested_vertical_cm, ok)
    type(covering_layer_input_request_t), intent(in) :: request
    real(real64), allocatable, intent(out) :: requested_vertical_cm(:)
    logical, intent(out) :: ok

    real(real64), parameter :: pi_legacy = 3.14159_real64
    real(real64) :: ld, r0, w_geom, total_amount, domain_fraction

    ok = .false.
    if (.not. request%valid()) return
    allocate(requested_vertical_cm(size(request%domain_top_volume_cm)))
    requested_vertical_cm = 0.0_real64

    ! Exact B1.11 covering-layer branch. Henpr1/CritHtop is zero there.
    if (request%matrix_head_above_cm <= 0.0_real64) then
      ok = .true.
      return
    end if

    ld = request%minimum_polygon_diameter_cm
    r0 = 0.5_real64*ld*(1.0_real64-sqrt(1.0_real64-request%total_macropore_volume_top_cm))
    if (r0 <= 0.0_real64 .or. .not. ieee_is_finite(r0)) return

    w_geom = 1.0_real64/(1.0_real64 + ld/(pi_legacy*request%dz_above_cm/2.0_real64)* &
         log(ld/(pi_legacy*r0)) + ld**2/(6.0_real64*request%dz_above_cm**2))
    if (.not. ieee_is_finite(w_geom) .or. w_geom < 0.0_real64) return

    total_amount = w_geom*request%covering_layer_ksat_cm_per_day * &
         (request%matrix_head_above_cm/(request%dz_above_cm/2.0_real64)+1.0_real64) * &
         request%step_duration_day
    total_amount = max(0.0_real64,total_amount)

    do concurrent (integer :: id=1:size(requested_vertical_cm))
      domain_fraction = request%domain_top_volume_cm(id)/request%total_macropore_volume_top_cm
      requested_vertical_cm(id) = domain_fraction*total_amount
    end do

    if (any(.not. ieee_is_finite(requested_vertical_cm)) .or. any(requested_vertical_cm < 0.0_real64)) return
    if (abs(sum(requested_vertical_cm)-total_amount) > 1.0e-12_real64) return
    ok = .true.
  end subroutine evaluate_covering_layer_input

end module mod_macropore_covering_layer_input
