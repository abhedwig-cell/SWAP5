program test_fmr_root_uptake_oxygen_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_root_water_uptake_process, only: root_water_uptake_parameters_t, root_water_uptake_flux_result_t, &
       root_water_uptake_diagnostics_t
  use mod_fmr_root_uptake_process_binding, only: fmr_root_uptake_crop_input_t, fmr_root_uptake_binding_diagnostics_t
  use mod_fmr_root_uptake_oxygen_binding
  implicit none
  type(kernel_committed_state_t) :: committed
  type(root_water_uptake_parameters_t) :: p
  type(fmr_root_uptake_crop_input_t) :: crop
  type(root_water_uptake_flux_result_t) :: off, on
  type(root_water_uptake_diagnostics_t) :: pd
  type(fmr_root_uptake_binding_diagnostics_t) :: rd
  type(fmr_root_oxygen_binding_diagnostics_t) :: od
  real(real64) :: f(2)

  ! Use the existing no-crop route: it deliberately requires no hydraulic view and is ideal
  ! for proving that oxygen-disabled selection is byte/semantic preservation at the binding seam.
  p%active_nodes=2
  crop%crop_emerged=.false.
  call fmr_evaluate_committed_root_uptake_with_oxygen(committed,p,crop,.false.,fluxes=off, &
       process_diagnostics=pd,root_diagnostics=rd,oxygen_diagnostics=od)
  if (od%status /= FMR_ROOT_OXYGEN_OK .or. .not.od%preservation_route) error stop 1
  if (.not.allocated(off%root_extraction_sink)) error stop 2
  if (any(off%root_extraction_sink /= 0.0_real64) .or. off%actual_uptake_total /= 0.0_real64) error stop 3

  ! Oxygen enabled on the same inactive route remains zero and validates factor shape semantics.
  f=[0.5_real64,0.0_real64]
  call fmr_evaluate_committed_root_uptake_with_oxygen(committed,p,crop,.true.,f,on,pd,rd,od)
  if (od%status /= FMR_ROOT_OXYGEN_FACTOR_REJECTED) error stop 4

  print '(a)', 'PPA_WU05C3P_RUNTIME_SELECTION=PASS'
end program
