module mod_column_swp_macro_configuration
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite,ieee_value,ieee_quiet_nan
 use mod_column_swp_macro_initial
 use mod_fmr_macropore_configuration
 implicit none
 private
 public::import_column_macro_configuration
contains
 subroutine import_column_macro_configuration(path,initial,config)
 character(*),intent(in)::path
 type(native_macro_initial_t),intent(out)::initial
 type(fmr_macropore_physical_config_t),intent(out)::config
 integer::n,u,code,seepage_option
 real(real64)::conductivity(256),entry_head(256),sorption_factor(256),horizontal_ksat(256)
 real(real64)::shape_factor,rapid_resistance,critical_undersaturation,pond_threshold,source_surface_conductivity,minimum_surface_conductivity,nan
 logical::ok
 namelist /macro_configuration/seepage_option,shape_factor,rapid_resistance,critical_undersaturation,pond_threshold, &
   source_surface_conductivity,minimum_surface_conductivity,conductivity,entry_head,sorption_factor,horizontal_ksat
 call import_column_macro_initial(path,initial);n=initial%geometry%num_nodes
 nan=ieee_value(0d0,ieee_quiet_nan);conductivity=nan;entry_head=nan;sorption_factor=nan;horizontal_ksat=nan
 seepage_option=0;shape_factor=nan;rapid_resistance=nan;critical_undersaturation=nan;pond_threshold=nan;source_surface_conductivity=nan;minimum_surface_conductivity=nan
 open(newunit=u,file=trim(path),status='old',action='read',iostat=code);call require(code==0,'configuration open')
 read(u,nml=macro_configuration,iostat=code);close(u);call require(code==0,'configuration grammar')
 call require(all(ieee_is_finite(conductivity(:n))).and.all(ieee_is_finite(entry_head(:n))).and. &
  all(ieee_is_finite(sorption_factor(:n))).and.all(ieee_is_finite(horizontal_ksat(:n))),'configuration arrays')
 call require(all(ieee_is_finite([shape_factor,rapid_resistance,critical_undersaturation,pond_threshold,source_surface_conductivity,minimum_surface_conductivity])), &
  'configuration scalars')
 call require(seepage_option==1,'original seepage option1')
 call require(source_surface_conductivity==1000d0.and.minimum_surface_conductivity==1000d0, &
  'source surface conductivity must be capped even without dynamic cracks')
 call initialize_fmr_macropore_standard_config(config,initial%geometry%top_node,initial%geometry%static_volume_cp, &
  initial%geometry%domain_fraction,initial%geometry%potential_bottom_domain,initial%z,initial%geometry%dz, &
  initial%geometry%characteristic_diameter,initial%theta_s,initial%theta_r,1d0+0d0*initial%theta_s, &
  initial%sorptivity_max,initial%sorptivity_alpha,conductivity(:n),entry_head(:n),sorption_factor(:n), &
  horizontal_ksat(:n),initial%darcy,1d0,shape_factor,seepage_option,ok, &
  rapid_enabled=.true.,rapid_drain_type=1,rapid_drain_level_cm=initial%drain_level, &
  rapid_area_exponent=initial%rapid_exponent,rapid_kd_reference=initial%rapid_kd, &
  rapid_resistance_reference_day=rapid_resistance,perched_enabled=critical_undersaturation>0d0, &
  critical_under_saturated_volume_cm=critical_undersaturation,matrix_area_fraction=initial%matrix_fraction, &
  shrinkage=initial%shrinkage)
 call require(ok,'production standard macro configuration')
 ! Current geometry preparation replaces the seed wall correction at every
 ! actual rate evaluation. No new wall formula is introduced by this adapter.
 config%surface_pond_inflow_enabled=.true.;config%surface_pond_threshold_cm=pond_threshold
 config%surface_macropore_conductivity_cm_per_day=source_surface_conductivity
 call require(config%valid_for_nodes(n),'production macro configuration')
 end subroutine
 subroutine require(ok,label)
 logical,intent(in)::ok
 character(*),intent(in)::label
 if(.not.ok)then;print '(a)','SWP_MACRO_CONFIG_REJECTED: '//label;error stop 1;end if
 end subroutine
end module
