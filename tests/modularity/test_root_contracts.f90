program test_root_contracts
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_water_uptake_process
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  implicit none
  type(root_water_uptake_parameters_t) :: p
  type(root_water_uptake_request_t) :: q, saved_q
  type(process_hydraulic_view_t) :: h, saved_h
  type(root_water_uptake_flux_result_t) :: f, first
  type(root_water_uptake_diagnostics_t) :: d
  p%active_nodes=2
  p%hlim3l=-500._real64;p%hlim3h=-800._real64;p%hlim4=-16000._real64
  p%adcrl=0.1_real64;p%adcrh=0.5_real64
  q%potential_transpiration=1._real64;q%rooted_nodes=2
  q%cumulative_root_fraction=[0._real64,0.25_real64,1._real64]
  h%active_nodes=2;h%pressure_head=[-100._real64,-100._real64];h%water_content=[0.3_real64,0.3_real64]
  saved_q=q;saved_h=h
  call evaluate_macro_feddes_drought_uptake(p,h,q,first,d)
  if(d%status/=ROOT_UPTAKE_OK) error stop 'valid uptake rejected'
  if(maxval(abs(first%root_extraction_sink-[0.25_real64,0.75_real64]))>1e-12_real64) error stop 'unstressed partition'
  if(abs(first%actual_uptake_total-sum(first%root_extraction_sink))>1e-12_real64) error stop 'single sink ownership'
  q%cumulative_root_fraction=[0._real64,0.8_real64,0.7_real64]
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_INVALID_REQUEST) error stop 'invalid distribution accepted'
  q=saved_q
  h%active_nodes=1
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_INVALID_HYDRAULIC_VIEW) error stop 'foreign view accepted'
  h=saved_h
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK.or.any(f%root_extraction_sink/=first%root_extraction_sink)) error stop 'A/B/A drift'
  if(any(h%pressure_head/=saved_h%pressure_head).or.any(h%water_content/=saved_h%water_content).or. &
     any(q%cumulative_root_fraction/=saved_q%cumulative_root_fraction)) error stop 'input mutation'
  q%rooted_nodes=0
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK.or..not.d%no_roots.or.any(f%root_extraction_sink/=0._real64)) error stop 'no roots'
  q=saved_q;q%potential_transpiration=0._real64
  call evaluate_macro_feddes_drought_uptake(p,h,q,f,d)
  if(d%status/=ROOT_UPTAKE_OK.or..not.d%negligible_transpiration) error stop 'zero transpiration'
  print '(a)','MODULAR_ROOT_NONMUTATION_INVALID_ABA=PASS'
end program
