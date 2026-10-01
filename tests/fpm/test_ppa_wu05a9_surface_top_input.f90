program test_ppa_wu05a9_surface_top_input
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_macropore_surface_top_input, only: macropore_surface_forcing_t, &
       macropore_surface_geometry_t, macropore_surface_partition_result_t, &
       evaluate_macropore_surface_partition
  implicit none

  type(macropore_surface_forcing_t) :: forcing
  type(macropore_surface_geometry_t) :: geometry
  type(macropore_surface_partition_result_t) :: result
  real(real64) :: capacity(2)

  forcing%precipitation_rate_cm_per_day = 1.0_real64
  forcing%irrigation_rate_cm_per_day = 0.2_real64
  forcing%snowmelt_rate_cm_per_day = 0.3_real64
  forcing%runon_rate_cm_per_day = 0.4_real64
  forcing%lateral_overland_to_macropores_cm = 0.06_real64

  geometry%num_domains = 2
  geometry%top_area_fraction = 0.20_real64
  allocate(geometry%domain_top_area_fraction(2))
  geometry%domain_top_area_fraction = [0.08_real64,0.12_real64]

  capacity = [0.04_real64,0.20_real64]
  call evaluate_macropore_surface_partition(forcing,geometry,0.5_real64,capacity,result)
  if (.not. result%valid) error stop 'A9 surface partition invalid'

  ! Direct supply = 0.75 cm, with 20% reserved for macropore top area.
  if (abs(result%direct_supply_total_cm-0.75_real64) > 1.0e-12_real64) &
       error stop 'A9 direct supply'
  if (abs(result%matrix_direct_supply_total_cm-0.60_real64) > 1.0e-12_real64) &
       error stop 'A9 matrix direct partition'

  ! Domain direct vertical: [0.06,0.09]; lateral: [0.024,0.036].
  if (abs(result%top%requested_vertical_cm(1)-0.06_real64) > 1.0e-12_real64 .or. &
      abs(result%top%requested_vertical_cm(2)-0.09_real64) > 1.0e-12_real64) &
       error stop 'A9 vertical domain request'
  if (abs(result%top%requested_lateral_cm(1)-0.024_real64) > 1.0e-12_real64 .or. &
      abs(result%top%requested_lateral_cm(2)-0.036_real64) > 1.0e-12_real64) &
       error stop 'A9 lateral domain request'

  if (abs(result%top%accepted_total_cm + result%returned_surface_cm - &
       result%top%requested_total_cm) > 1.0e-12_real64) &
       error stop 'A9 accepted returned receipt'
  if (abs(result%source_partition_residual_cm) > 1.0e-12_real64) &
       error stop 'A9 external source partition'

  ! Runon is deliberately not direct macropore area forcing.
  if (abs(result%runon_total_cm-0.20_real64) > 1.0e-12_real64) &
       error stop 'A9 runon ownership'

  print '(a)', 'PPA_WU05A9_SURFACE_TOP_INPUT=PASS'
end program test_ppa_wu05a9_surface_top_input
