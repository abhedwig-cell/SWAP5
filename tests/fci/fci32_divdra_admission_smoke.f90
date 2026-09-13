program fci32_divdra_admission_smoke
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_drainage_spatial_distribution, only: &
       drainage_distribution_parameters_t, drainage_node_transfer_t, drainage_distribution_diagnostics_t, &
       distribute_single_level_positive_divdra, DRAIN_DIST_OK, DRAIN_DIST_INVALID_HYDRAULIC_VIEW, &
       DRAIN_DIST_INVALID_TRANSFER, DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE
  implicit none

  type(drainage_distribution_parameters_t) :: p
  type(process_hydraulic_view_t) :: v
  type(drainage_node_transfer_t) :: transfer
  type(drainage_distribution_diagnostics_t) :: d
  real(real64), parameter :: q = 3.0e-4_real64
  real(real64) :: mass_error

  p%active_nodes = 3
  allocate(p%dz(3), p%zbotcp(3), p%saturated_conductivity(3), p%horizontal_anisotropy_factor(3))
  p%dz = [10.0_real64, 10.0_real64, 10.0_real64]
  p%zbotcp = [-10.0_real64, -20.0_real64, -30.0_real64]
  p%saturated_conductivity = [1.0_real64, 2.0_real64, 4.0_real64]
  p%horizontal_anisotropy_factor = [1.0_real64, 1.5_real64, 2.0_real64]
  p%drain_spacing = 80.0_real64

  v%active_nodes = 3
  allocate(v%pressure_head(3), v%water_content(3))
  v%pressure_head = [-100.0_real64, -50.0_real64, -20.0_real64]
  v%water_content = [0.20_real64, 0.25_real64, 0.30_real64]
  v%groundwater_level = -5.0_real64

  call distribute_single_level_positive_divdra(p, v, q, transfer, d)
  call require(d%status == DRAIN_DIST_OK .and. d%evaluated, "accepted transfer status")
  mass_error = abs(sum(transfer%soil_to_drain_rate) - q)
  call require(mass_error <= 64.0_real64 * epsilon(1.0_real64) * q, "accepted transfer mass closure")
  call require(d%scalar_transfer_is_authoritative .and. d%worker_scratch_only, "diagnostic contract")

  v%groundwater_level = -10.0_real64
  call distribute_single_level_positive_divdra(p, v, q, transfer, d)
  call require(d%status == DRAIN_DIST_OK .and. d%water_table_node == 1, "exact legacy seam stays shallow")

  v%groundwater_level = -(10.0_real64 + 2.0e-10_real64)
  call distribute_single_level_positive_divdra(p, v, q, transfer, d)
  call require(d%status == DRAIN_DIST_OK .and. d%water_table_node == 2, "beyond legacy seam advances compartment")

  v%groundwater_level = -30.0_real64
  call distribute_single_level_positive_divdra(p, v, q, transfer, d)
  call require(d%status == DRAIN_DIST_INVALID_HYDRAULIC_VIEW, "profile bottom fails closed")

  v%groundwater_level = -5.0_real64
  call distribute_single_level_positive_divdra(p, v, 1.0e-10_real64, transfer, d)
  call require(d%status == DRAIN_DIST_TRANSFER_BELOW_ADMITTED_MAGNITUDE, "restricted magnitude boundary")

  call distribute_single_level_positive_divdra(p, v, -1.0_real64, transfer, d)
  call require(d%status == DRAIN_DIST_INVALID_TRANSFER, "negative transfer fails closed")

  call distribute_single_level_positive_divdra(p, v, 0.0_real64, transfer, d)
  call require(d%status == DRAIN_DIST_OK .and. d%zero_transfer, "zero transfer accepted")

  write(*,'(A)') 'FCI32_DIVDRA_ADMISSION_SMOKE=PASS'

contains

  subroutine require(condition, label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if (.not. condition) then
      write(*,'(A,1X,A)') 'FCI32_SMOKE_FAIL', trim(label)
      error stop 1
    end if
  end subroutine require

end program fci32_divdra_admission_smoke
