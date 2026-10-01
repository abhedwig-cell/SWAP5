program test_fmr_root_uptake_oxygen_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_fmr_root_uptake_oxygen_binding
  implicit none
  type(root_water_uptake_flux_result_t) :: base, off, on
  type(fmr_root_oxygen_binding_diagnostics_t) :: d
  real(real64) :: f(2)

  allocate(base%root_extraction_sink(3))
  base%root_extraction_sink=[2.0_real64,4.0_real64,0.0_real64]
  base%actual_uptake_total=6.0_real64

  call fmr_apply_root_uptake_oxygen_selection(base,2,.false.,fluxes=off,diagnostics=d)
  if (d%status /= FMR_ROOT_OXYGEN_OK .or. .not.d%preservation_route) error stop 1
  if (any(off%root_extraction_sink /= base%root_extraction_sink)) error stop 2
  if (off%actual_uptake_total /= base%actual_uptake_total) error stop 3

  f=[0.5_real64,0.0_real64]
  call fmr_apply_root_uptake_oxygen_selection(base,2,.true.,f,on,d)
  if (d%status /= FMR_ROOT_OXYGEN_OK) error stop 4
  if (any(on%root_extraction_sink /= [1.0_real64,0.0_real64,0.0_real64])) error stop 5
  if (on%actual_uptake_total /= 1.0_real64) error stop 6

  print '(a)', 'PPA_WU05C3P_RUNTIME_SELECTION=PASS'
end program
