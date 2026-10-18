module mod_fmr_b111_mineral_route
 use iso_fortran_env,only:real64,int64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_soil_n_mineral_owner
 use mod_soil_n_pool_state,only:soil_n_pool_state_t
 use mod_fmr_serialized_reference_backend,only:fmr_water_flux_substep_trace_t
 use mod_solute_water_face_flux_reconstruction,only:reconstruct_interval_water_face_flux,WATER_FACE_FLUX_OK
 implicit none
 private
 type,public::mineral_daily_carrier_t
   real(real64)::t0=0d0,t1=0d0,water_start=0d0,water_end=0d0
   real(real64)::outflow=0d0,in_bottom=0d0,in_lateral=0d0,root_water=0d0,surface_water=0d0
 end type
 public::consume_mineral_trace,aggregate_mineral_trace
contains
 subroutine consume_mineral_trace(state,steps,receipt)
   type(mineral_state_t),intent(inout)::state
   type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
   type(mineral_receipt_t),intent(out)::receipt
   type(mineral_daily_carrier_t)::c
   integer::status
   receipt=mineral_receipt_t()
   call aggregate_mineral_trace(state,steps,c,status)
   if(status/=MINERAL_OK)return
   call advance_mineral_day(state,c%t0,c%t1,c%water_end,c%outflow,c%in_bottom,c%in_lateral,c%root_water,receipt)
 end subroutine
 subroutine aggregate_mineral_trace(state,steps,carrier,status,clean_surface_water)
   type(mineral_state_t),intent(in)::state
   type(fmr_water_flux_substep_trace_t),intent(in)::steps(:)
   type(mineral_daily_carrier_t),intent(out)::carrier
   integer,intent(out)::status
   logical,intent(in),optional::clean_surface_water
   logical::allow_surface
   real(real64)::surface
   type(mineral_parameters_t)::p
   type(soil_n_pool_state_t)::s
   real(real64),allocatable::water(:),faces(:)
   real(real64)::time,theta,dt,clock,closure,outflow,inbot,inlat,root,scale,water_end
   integer(int64)::id,revision
   integer::k,n,code
   carrier=mineral_daily_carrier_t();status=MINERAL_INVALID
   allow_surface=.false.;if(present(clean_surface_water))allow_surface=clean_surface_water
   surface=0d0
   if(.not.state%ready().or.size(steps)<1)return
   call state%configuration(p,id);call state%snapshot(time,theta,s,revision)
   n=size(p%dz_cm);clock=time;outflow=0d0;inbot=0d0;inlat=0d0;root=0d0
   if(.not.ieee_is_finite(steps(size(steps))%t1))return
   if(abs(steps(size(steps))%t1-time-1d0)>0d0)return
   do k=1,size(steps)
     associate(t=>steps(k))
       if(.not.all(ieee_is_finite([t%t0,t%t1,t%top_flux,t%bottom_flux])))return
       if(abs(t%t0-clock)>0d0.or.t%t1<=t%t0.or.t%t1>time+1d0)return
       if(max(abs(t%top_flux),abs(t%bottom_flux))>1d4)return
       if(.not.allocated(t%water_start).or..not.allocated(t%water_end).or..not.allocated(t%root_sink).or. &
          .not.allocated(t%net_node_source).or..not.allocated(t%drainage_sink_by_level))return
       if(size(t%water_start)/=n.or.size(t%water_end)/=n.or.size(t%root_sink)/=n.or. &
          size(t%net_node_source)/=n.or.size(t%drainage_sink_by_level,2)/=n)return
       if(size(t%drainage_sink_by_level,1)>64)return
       if(.not.all(ieee_is_finite(t%water_start)).or..not.all(ieee_is_finite(t%water_end)).or. &
          .not.all(ieee_is_finite(t%root_sink)).or..not.all(ieee_is_finite(t%net_node_source)).or. &
          .not.all(ieee_is_finite(t%drainage_sink_by_level)))return
       if(any(t%water_start<1d-4).or.any(t%water_end<1d-4).or.any(t%water_start>1d0).or.any(t%water_end>1d0))return
       if(any(t%root_sink<0d0).or.any(t%root_sink>1d4).or.any(abs(t%net_node_source)>1d4))return
       if(any(abs(t%drainage_sink_by_level)>1d4))return
       scale=max(1d0,maxval(abs(t%net_node_source)))
       if(any(abs(t%net_node_source+sum(t%drainage_sink_by_level,dim=1)+t%root_sink)> &
          1024d0*epsilon(1d0)*scale))return
       if(k==1)then
         if(abs(sum(p%dz_cm*t%water_start)/sum(p%dz_cm)-theta)>1024d0*epsilon(1d0))return
       else
         if(any(abs(t%water_start-water)>1024d0*epsilon(1d0)))return
       end if
       if(allocated(t%macropore_matrix_exchange))then
         if(.not.all(ieee_is_finite(t%macropore_matrix_exchange)))return
         if(any(abs(t%macropore_matrix_exchange)>0d0))return
       end if
       if(allocated(t%macropore_matrix_exchange_domain))then
         if(size(t%macropore_matrix_exchange_domain,1)>0)return
       end if
       if(allocated(t%subsurface_source))then
         if(.not.all(ieee_is_finite(t%subsurface_source)))return
         if(any(abs(t%subsurface_source)>0d0))return
       end if
       if(.not.allow_surface.and.abs(t%top_flux)>0d0)return
       dt=t%t1-t%t0
       surface=surface-dt*t%top_flux*.01d0
       call reconstruct_interval_water_face_flux(p%dz_cm,t%water_start,t%water_end,t%net_node_source, &
          -t%top_flux,-t%bottom_flux,dt,1d-10/dt,faces,closure,code)
       if(code/=WATER_FACE_FLUX_OK)return
       outflow=outflow+dt*(max(0d0,-t%bottom_flux)+sum(max(0d0,t%drainage_sink_by_level)))*.01d0
       inbot=inbot+dt*max(0d0,t%bottom_flux)*.01d0
       inlat=inlat+dt*sum(max(0d0,-t%drainage_sink_by_level))*.01d0
       root=root+dt*sum(t%root_sink)*.01d0
       water=t%water_end;clock=t%t1
     end associate
   end do
   water_end=sum(p%dz_cm*water)/sum(p%dz_cm)
   ! Whole route requires exactly a day; daily integrals become rates numerically.
   carrier=mineral_daily_carrier_t(time,clock,theta,water_end,outflow,inbot,inlat,root,surface)
   status=MINERAL_OK
 end subroutine
end module
