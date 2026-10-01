module mod_macropore_surface_top_input
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_ppa_wu05a5_top_partition, only: macropore_top_partition_request_t, &
       macropore_top_partition_result_t, evaluate_macropore_top_partition
  implicit none
  private

  type, public :: macropore_surface_forcing_t
    real(real64) :: precipitation_rate_cm_per_day = 0.0_real64
    real(real64) :: irrigation_rate_cm_per_day = 0.0_real64
    real(real64) :: snowmelt_rate_cm_per_day = 0.0_real64
    real(real64) :: runon_rate_cm_per_day = 0.0_real64
    real(real64) :: lateral_overland_to_macropores_cm = 0.0_real64
  contains
    procedure, public :: valid => surface_forcing_valid
  end type macropore_surface_forcing_t

  type, public :: macropore_surface_geometry_t
    integer :: num_domains = 0
    real(real64) :: top_area_fraction = 0.0_real64
    real(real64), allocatable :: domain_top_area_fraction(:)
  contains
    procedure, public :: valid => surface_geometry_valid
  end type macropore_surface_geometry_t

  type, public :: macropore_surface_partition_result_t
    logical :: valid = .false.
    real(real64) :: direct_supply_total_cm = 0.0_real64
    real(real64) :: matrix_direct_supply_total_cm = 0.0_real64
    real(real64) :: runon_total_cm = 0.0_real64
    real(real64) :: lateral_requested_total_cm = 0.0_real64
    real(real64) :: requested_macropore_total_cm = 0.0_real64
    real(real64) :: accepted_macropore_total_cm = 0.0_real64
    real(real64) :: returned_surface_cm = 0.0_real64
    real(real64) :: source_partition_residual_cm = huge(1.0_real64)
    type(macropore_top_partition_result_t) :: top
  end type macropore_surface_partition_result_t

  public :: evaluate_macropore_surface_partition

contains

  pure logical function surface_forcing_valid(self) result(ok)
    class(macropore_surface_forcing_t), intent(in) :: self
    ok = self%precipitation_rate_cm_per_day >= 0.0_real64 .and. &
         self%irrigation_rate_cm_per_day >= 0.0_real64 .and. &
         self%snowmelt_rate_cm_per_day >= 0.0_real64 .and. &
         self%runon_rate_cm_per_day >= 0.0_real64 .and. &
         self%lateral_overland_to_macropores_cm >= 0.0_real64
  end function surface_forcing_valid

  pure logical function surface_geometry_valid(self) result(ok)
    class(macropore_surface_geometry_t), intent(in) :: self
    real(real64) :: area_sum

    ok = self%num_domains > 0 .and. self%top_area_fraction >= 0.0_real64 .and. &
         self%top_area_fraction <= 1.0_real64 .and. allocated(self%domain_top_area_fraction)
    if (.not. ok) return
    ok = size(self%domain_top_area_fraction) == self%num_domains .and. &
         all(self%domain_top_area_fraction >= 0.0_real64)
    if (.not. ok) return
    area_sum = sum(self%domain_top_area_fraction)
    ok = abs(area_sum-self%top_area_fraction) <= 1.0e-12_real64
  end function surface_geometry_valid

  subroutine evaluate_macropore_surface_partition(forcing,geometry,step_duration,available_capacity_cm,result)
    type(macropore_surface_forcing_t), intent(in) :: forcing
    type(macropore_surface_geometry_t), intent(in) :: geometry
    real(real64), intent(in) :: step_duration
    real(real64), intent(in) :: available_capacity_cm(:)
    type(macropore_surface_partition_result_t), intent(out) :: result

    type(macropore_top_partition_request_t) :: request
    real(real64) :: direct_rate, source_total, matrix_direct
    integer :: nd

    result = macropore_surface_partition_result_t()
    if (.not. forcing%valid() .or. .not. geometry%valid()) return
    if (step_duration <= 0.0_real64) return
    nd = geometry%num_domains
    if (size(available_capacity_cm) /= nd .or. any(available_capacity_cm < 0.0_real64)) return

    direct_rate = forcing%precipitation_rate_cm_per_day + &
         forcing%irrigation_rate_cm_per_day + forcing%snowmelt_rate_cm_per_day

    result%direct_supply_total_cm = direct_rate*step_duration
    matrix_direct = (1.0_real64-geometry%top_area_fraction)*direct_rate*step_duration
    result%matrix_direct_supply_total_cm = matrix_direct
    result%runon_total_cm = forcing%runon_rate_cm_per_day*step_duration
    result%lateral_requested_total_cm = forcing%lateral_overland_to_macropores_cm

    request%num_domains = nd
    request%top_node = 1
    allocate(request%requested_vertical_cm(nd),request%requested_lateral_cm(nd), &
         request%available_capacity_cm(nd),request%domain_fraction(nd))

    request%requested_vertical_cm = geometry%domain_top_area_fraction*direct_rate*step_duration
    if (geometry%top_area_fraction > 1.0e-30_real64) then
      request%domain_fraction = geometry%domain_top_area_fraction/geometry%top_area_fraction
      request%requested_lateral_cm = request%domain_fraction*forcing%lateral_overland_to_macropores_cm
    else
      request%domain_fraction = 1.0_real64/real(nd,real64)
      request%requested_lateral_cm = 0.0_real64
    end if
    request%available_capacity_cm = available_capacity_cm

    call evaluate_macropore_top_partition(request,result%top)
    if (.not. result%top%valid) return

    result%requested_macropore_total_cm = result%top%requested_total_cm
    result%accepted_macropore_total_cm = result%top%accepted_total_cm
    result%returned_surface_cm = result%top%returned_surface_cm

    ! External source ownership: direct P/I/M supply is partitioned between
    ! matrix top-area and requested macropore top-area. Runon remains with the
    ! surface owner; lateral macropore inflow is already a surface-owner receipt.
    source_total = result%direct_supply_total_cm + result%lateral_requested_total_cm
    result%source_partition_residual_cm = &
         result%matrix_direct_supply_total_cm + &
         (sum(request%requested_vertical_cm)+result%lateral_requested_total_cm) - source_total

    result%valid = abs(result%source_partition_residual_cm) <= 1.0e-12_real64 .and. &
         abs(result%top%receipt_residual_cm) <= 1.0e-12_real64
  end subroutine evaluate_macropore_surface_partition

end module mod_macropore_surface_top_input
