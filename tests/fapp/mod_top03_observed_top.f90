! Research instrumentation: delegates every physical evaluation unchanged.
module mod_top03_observed_top
 use,intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:dynamic_top_boundary_provider_t,soil_water_boundary_conditions_t, &
 soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX,SW_TOP_BOUNDARY_REGIME_HEAD
 use mod_b110_dynamic_top_boundary_solver_adapter,only:b110_dynamic_top_boundary_solver_provider_t
 implicit none
 type::top03_top_trace_t
 integer::calls=0,external_calls=0,flux_calls=0,head_calls=0,switches=0,last_regime=0
 real(real64)::cv_external_flux=0.0_real64,cv_surface_residual=0.0_real64,cv_surface_storage=0.0_real64
 character(len=120)::label=''
 end type
 type,extends(dynamic_top_boundary_provider_t)::top03_observed_top_t
 type(b110_dynamic_top_boundary_solver_provider_t)::delegate
 type(top03_top_trace_t),pointer::trace=>null()
 logical::surface_cv_enabled=.false.
 real(real64)::surface_cv_external_head_cm=0.0_real64
 real(real64)::surface_cv_microrelief_cm=0.05_real64
 contains
 procedure::evaluate=>observed_evaluate
 end type
 contains
 subroutine observed_evaluate(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
 class(top03_observed_top_t),intent(in)::self
 real(real64),intent(in)::pressure_head_top,water_content_top,candidate_ponding_depth
 type(soil_water_boundary_conditions_t),intent(in)::requested
 type(soil_water_top_boundary_result_t),intent(out)::result
 real(real64)::d,kface,dt,g,g_surface,s0,hlo,hhi,hs,mid,flo,fhi,fmid,qext,qsoil,ds,sill,hr_excess,hs_excess
 integer::iteration
 if(self%surface_cv_enabled)then
  result=soil_water_top_boundary_result_t()
  if(.not.associated(self%delegate%geometry).or..not.associated(self%delegate%hydraulics))return
  d=self%delegate%geometry%node_distance(1);dt=self%delegate%step_duration
  kface=0.5_real64*(self%delegate%hydraulics%cofgen(3,1)+self%delegate%fixed_top_node_conductivity)
  if(d<=0.0_real64.or.dt<=0.0_real64.or.kface<=0.0_real64)return
  g=kface/d;s0=self%delegate%previous_ponding_depth
  sill=self%delegate%external_flooding_sill_head_cm
  hlo=min(-self%surface_cv_microrelief_cm,self%surface_cv_external_head_cm,pressure_head_top)-100.0_real64
  hhi=max(self%surface_cv_microrelief_cm,self%surface_cv_external_head_cm,pressure_head_top,s0)+100.0_real64
  flo=surface_residual(hlo);fhi=surface_residual(hhi)
  if(flo>0.0_real64.or.fhi<0.0_real64)return
  do iteration=1,100
   mid=0.5_real64*(hlo+hhi);fmid=surface_residual(mid)
   if(fmid>0.0_real64)then
    hhi=mid
   else
    hlo=mid
   end if
   if(abs(hhi-hlo)<=2.0e-14_real64*max(1.0_real64,abs(mid)))exit
  end do
  hs=0.5_real64*(hlo+hhi);ds=surface_storage_slope(hs)
  hr_excess=max(self%surface_cv_external_head_cm-sill,0.0_real64)
  hs_excess=max(hs-sill,0.0_real64)
  qext=g*(hr_excess-hs_excess)
  g_surface=g
  if(hs<=sill)g_surface=0.0_real64
  qsoil=kface*((hs-pressure_head_top)/d+1.0_real64)
  result%status=SW_TOP_BOUNDARY_AVAILABLE;result%regime=SW_TOP_BOUNDARY_REGIME_HEAD
  result%surface_head=hs;result%candidate_ponding_depth=surface_storage(hs)
  result%surface_face_conductivity=kface;result%actual_top_flux=-qsoil
  result%net_potential_surface_flux=qext;result%surface_head_derivative_available=.true.
  result%surface_head_dpressure_head_top=dt*kface/d/(ds+dt*g_surface+dt*kface/d)
  result%carries_surface_mass_terms=.true.;result%runoff_resolved=.true.
  result%route='top03-unified-surface-cv'
  if(associated(self%trace))then
   self%trace%cv_external_flux=qext
   self%trace%cv_surface_storage=result%candidate_ponding_depth
   self%trace%cv_surface_residual=result%candidate_ponding_depth-s0-dt*(qext-qsoil)
  end if
 else
 call self%delegate%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
 end if
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
 contains
  real(real64) function surface_storage(h)
   real(real64),intent(in)::h
   real(real64)::dd
   dd=self%surface_cv_microrelief_cm
   if(h<=-dd)then
    surface_storage=0.0_real64
   else if(h<dd)then
    surface_storage=(h+dd)**2/(4.0_real64*dd)
   else
    surface_storage=h
   end if
  end function
  real(real64) function surface_storage_slope(h)
   real(real64),intent(in)::h
   real(real64)::dd
   dd=self%surface_cv_microrelief_cm
   if(h<=-dd)then
    surface_storage_slope=0.0_real64
   else if(h<dd)then
    surface_storage_slope=(h+dd)/(2.0_real64*dd)
   else
    surface_storage_slope=1.0_real64
   end if
  end function
  real(real64) function surface_residual(h)
   real(real64),intent(in)::h
   hr_excess=max(self%surface_cv_external_head_cm-sill,0.0_real64)
   hs_excess=max(h-sill,0.0_real64)
   surface_residual=surface_storage(h)-s0-dt*(g*(hr_excess-hs_excess)- &
    kface*((h-pressure_head_top)/d+1.0_real64))
  end function
 end subroutine
end module
