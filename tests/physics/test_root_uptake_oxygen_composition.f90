program test_root_uptake_oxygen_composition
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_uptake_oxygen_composition
  implicit none
  type(root_water_uptake_flux_result_t) :: base, out
  real(real64) :: f(3)
  integer :: status

  allocate(base%root_extraction_sink(4))
  base%root_extraction_sink = [1.0_real64,2.0_real64,3.0_real64,0.0_real64]
  base%actual_uptake_total = 6.0_real64
  f = [1.0_real64,0.5_real64,0.0_real64]

  call compose_root_sink_with_oxygen_factor(base,3,f,out,status)
  if (status /= ROOT_OXYGEN_COMPOSE_OK) error stop 1
  if (maxval(abs(out%root_extraction_sink-[1.0_real64,1.0_real64,0.0_real64,0.0_real64])) > 1e-15_real64) error stop 2
  if (abs(out%actual_uptake_total-2.0_real64) > 1e-15_real64) error stop 3

  f(2) = 1.1_real64
  call compose_root_sink_with_oxygen_factor(base,3,f,out,status)
  if (status /= ROOT_OXYGEN_COMPOSE_INVALID_FACTOR) error stop 4

  print '(a)', 'PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS'
end program
