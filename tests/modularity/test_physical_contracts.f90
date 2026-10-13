program test_physical_contracts
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
  use mod_b110_default_mvg_provider
  use mod_restricted_surface_evaporation
  use mod_drainage_hooghoudt_equivalent_depth
  implicit none
  type(b110_default_mvg_parameters_t) :: hydraulic
  type(boesten_evaporation_parameters_t) :: p
  type(boesten_evaporation_state_t) :: committed
  type(boesten_evaporation_forcing_t) :: forcing
  type(boesten_evaporation_result_t) :: result
  type(hooghoudt_equivalent_depth_geometry_t) :: geometry
  type(hooghoudt_equivalent_depth_prepared_t) :: prepared
  type(hooghoudt_equivalent_depth_diagnostics_t) :: diagnostics
  real(real64) :: conductivity,nan_value
  logical :: ok
  nan_value=ieee_value(0.0_real64,ieee_quiet_nan)
  call evaluate_b110_default_mvg_conductivity(hydraulic,1,-10.0_real64,conductivity,ok)
  if(ok .or. conductivity/=0.0_real64) error stop 'uninitialized hydraulic provider accepted'
  ! Parameter readiness and node-range checks are evaluated by production code.
  hydraulic%active_nodes=1
  allocate(hydraulic%cofgen(42,1));hydraulic%cofgen=0.0_real64
  call evaluate_b110_default_mvg_conductivity(hydraulic,0,-10.0_real64,conductivity,ok)
  if(ok) error stop 'invalid node accepted'
  call evaluate_b110_default_mvg_conductivity(hydraulic,1,nan_value,conductivity,ok)
  if(ok) error stop 'nonfinite pressure accepted'
  print '(a)', 'MODULAR_HYDRAULIC_INVALID_CONTRACT=PASS'
  p%cofred=0.35_real64
  committed%spev=0.04_real64;committed%saev=0.04_real64
  forcing%potential_bare_soil_evaporation=0.3_real64;forcing%wetting_rate=0.05_real64
  forcing%surface_is_ponded=.false.
  call evaluate_boesten_evaporation_reduction(p,committed,forcing,0.25_real64,result)
  if(result%status/=BOESTEN_EVAP_AVAILABLE) error stop 'valid production trial rejected'
  if(committed%spev/=0.04_real64.or.committed%saev/=0.04_real64) error stop 'trial mutated committed pair'
  call evaluate_boesten_evaporation_reduction(p,committed,forcing,0.0_real64,result)
  if(result%status/=BOESTEN_EVAP_INVALID_INPUT) error stop 'zero interval accepted'
  forcing%wetting_rate=nan_value
  call evaluate_boesten_evaporation_reduction(p,committed,forcing,0.25_real64,result)
  if(result%status/=BOESTEN_EVAP_INVALID_INPUT) error stop 'nonfinite forcing accepted'
  if(committed%spev/=0.04_real64.or.committed%saev/=0.04_real64) error stop 'invalid trial mutated committed pair'
  print '(a)', 'MODULAR_BOESTEN_NONMUTATION_INVALID_CONTRACT=PASS'
  call prepare_hooghoudt_equivalent_depth(geometry,prepared,diagnostics)
  if(diagnostics%status/=EQDEPTH_INVALID_PARAMETERS.or.prepared%is_valid) error stop 'invalid drainage geometry accepted'
  geometry%drain_spacing=100.0_real64;geometry%wetted_perimeter=1.0_real64
  geometry%drain_bottom_level=0.0_real64;geometry%impermeable_base_level=0.0_real64
  call prepare_hooghoudt_equivalent_depth(geometry,prepared,diagnostics)
  if(diagnostics%status/=EQDEPTH_OK.or..not.prepared%is_valid) error stop 'valid shallow geometry rejected'
  if(prepared%equivalent_depth/=0.0_real64.or.prepared%branch/=EQDEPTH_BRANCH_SHALLOW) error stop 'zero-depth limit violated'
  geometry%impermeable_base_level=-5.0_real64
  call prepare_hooghoudt_equivalent_depth(geometry,prepared,diagnostics)
  if(diagnostics%status/=EQDEPTH_OK.or.prepared%equivalent_depth<=0.0_real64) error stop 'positive depth rejected'
  if(prepared%equivalent_depth>prepared%depth_below_drain) error stop 'depth bound violated'
  geometry%drain_spacing=nan_value
  call prepare_hooghoudt_equivalent_depth(geometry,prepared,diagnostics)
  if(diagnostics%status/=EQDEPTH_INVALID_PARAMETERS.or.prepared%is_valid) error stop 'nonfinite geometry accepted'
  print '(a)', 'MODULAR_DRAINAGE_DOMAIN_LIMIT_CONTRACT=PASS'
end program
