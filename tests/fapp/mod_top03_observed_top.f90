! Research instrumentation: delegates every physical evaluation unchanged.
module mod_top03_observed_top
 use,intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:dynamic_top_boundary_provider_t,soil_water_boundary_conditions_t, &
 soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX,SW_TOP_BOUNDARY_REGIME_HEAD
 use mod_b110_dynamic_top_boundary_solver_adapter,only:b110_dynamic_top_boundary_solver_provider_t
 implicit none
 type::top03_top_trace_t
 integer::calls=0,external_calls=0,flux_calls=0,head_calls=0,switches=0,last_regime=0
 character(len=120)::label=''
 end type
 type,extends(dynamic_top_boundary_provider_t)::top03_observed_top_t
 type(b110_dynamic_top_boundary_solver_provider_t)::delegate
 type(top03_top_trace_t),pointer::trace=>null()
 contains
 procedure::evaluate=>observed_evaluate
 end type
 contains
 subroutine observed_evaluate(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
 class(top03_observed_top_t),intent(in)::self
 real(real64),intent(in)::pressure_head_top,water_content_top,candidate_ponding_depth
 type(soil_water_boundary_conditions_t),intent(in)::requested
 type(soil_water_top_boundary_result_t),intent(out)::result
 call self%delegate%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
 if(.not.associated(self%trace))return
 self%trace%calls=self%trace%calls+1
 if(result%status/=SW_TOP_BOUNDARY_AVAILABLE)return
 if(result%external_surface_head_imposed)self%trace%external_calls=self%trace%external_calls+1
 if(result%regime==SW_TOP_BOUNDARY_REGIME_FLUX)self%trace%flux_calls=self%trace%flux_calls+1
 if(result%regime==SW_TOP_BOUNDARY_REGIME_HEAD)self%trace%head_calls=self%trace%head_calls+1
 if(self%trace%last_regime/=0.and.self%trace%last_regime/=result%regime)then
 self%trace%switches=self%trace%switches+1
 write(*,'(a,a,3(a,i0),2(a,es24.16),a,a)')'REGIME_CHANGE,',trim(self%trace%label), &
 ',',self%trace%calls,',',self%trace%last_regime,',',result%regime,',',pressure_head_top, &
 ',',candidate_ponding_depth,',',trim(result%route)
 end if
 self%trace%last_regime=result%regime
 end subroutine
end module
