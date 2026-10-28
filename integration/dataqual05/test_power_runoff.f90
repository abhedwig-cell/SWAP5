program test_power_runoff
 use iso_fortran_env,only:real64,real128
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
 use mod_b110_dynamic_top_boundary_provider
 implicit none
 type(soil_water_parameter_set_t)::g
 type(b110_default_mvg_parameters_t)::hp
 type(b110_dynamic_top_boundary_request_t)::q,qp,qm
 type(b110_dynamic_top_boundary_result_t)::r,rp,rm
 real(real64)::c(24,1),e,delta,fd,err,maxbalance,maxderivative,maxoracle
 real(real128)::lo,hi,mid,f,source,coef,scale,oracle
 real(real64),parameter::exponents(5)=[.5d0,.75d0,1d0,1.5d0,2d0],steps(3)=[1d-5,.01d0,.2d0]
 integer::ie,it,ik,ip,im,ih,iteration,n
 character(16)::mode
 call get_command_argument(1,mode)
 g%active_nodes=1;g%dz=[1d0];g%node_distance=[.5d0]
 c=0d0;c(1,1)=.05d0;c(2,1)=.45d0;c(3,1)=1d0;c(4,1)=.02d0;c(5,1)=.5d0;c(6,1)=1.6d0;c(7,1)=1d0-1d0/1.6d0
 c(8,1)=.02d0;c(9,1)=0d0;c(10,1)=1d0;c(11,1)=.999d0;c(12,1)=.99d0;c(22,1)=-1d6;c(23,1)=1d-12
 call initialize_b110_default_mvg_parameters(hp,c)
 maxbalance=0d0;maxderivative=0d0;maxoracle=0d0;n=0
 do ie=1,5
  e=exponents(ie)
  if(trim(mode)=='linear'.and.e/=1d0)cycle
  do it=1,3
   do ik=1,2
    do ip=1,2
     do im=0,1
      do ih=1,3
       q=b110_dynamic_top_boundary_request_t()
       q%conductivity_mean_method=1;q%pressure_head_top_cm=-.1d0*ih;q%water_content_top=.4d0
       q%previous_ponding_depth_cm=1d0;q%step_duration_day=steps(it);q%precipitation_rate_cm_per_day=2d0
       q%ponding_max_cm=.05d0*(ip-1);q%runoff_resistance_day=.01d0;q%runoff_exponent=e
       q%fixed_top_node_conductivity_cm_per_day=.1d0*ik
       if(im==1)q%macropore_surface_area_fraction=.1d0
       q%matrix_source_area_partition=im==1
       q%macropore_pond_donor_active=im==1;q%macropore_pond_threshold_cm=.01d0;q%macropore_surface_conductivity_cm_per_day=.1d0
       call evaluate_b110_dynamic_top_boundary(g,hp,q,r)
       if(r%status/=B110_DYN_TOP_AVAILABLE.or.r%runoff_depth_cm<=0d0)then
        print *,ie,it,ik,ip,im,ih,r%status,r%route,r%runoff_depth_cm
        error stop 'no active runoff'
       end if
       err=abs(r%candidate_ponding_depth_cm-q%previous_ponding_depth_cm-q%step_duration_day* &
         (r%net_potential_surface_flux_cm_per_day+r%actual_top_flux_cm_per_day)+r%runoff_depth_cm)
       maxbalance=max(maxbalance,err)
       if(err>2d-13)error stop 'independent surface balance'
       ! real128 oracle in pond coordinates, independent of provider root algorithm.
       source=real(q%previous_ponding_depth_cm,real128)+real(q%step_duration_day,real128)* &
        (real(r%net_potential_surface_flux_cm_per_day,real128)-real(r%surface_face_conductivity_cm_per_day,real128)* &
        (1-real(q%pressure_head_top_cm,real128)/.5_real128))
       coef=1+real(q%step_duration_day,real128)*real(r%surface_face_conductivity_cm_per_day,real128)/.5_real128
       scale=real(q%step_duration_day,real128)/real(q%runoff_resistance_day,real128)
       lo=real(q%ponding_max_cm,real128);hi=source/coef
       do iteration=1,180
        mid=(lo+hi)/2
        f=coef*mid+scale*(mid-real(q%ponding_max_cm,real128))**real(e,real128)-source
        if(f>0)then;hi=mid;else;lo=mid;end if
       end do
       oracle=(hi+lo)/2;maxoracle=max(maxoracle,abs(r%surface_head_cm-real(oracle,real64)))
       if(abs(r%surface_head_cm-real(oracle,real64))>2d-14)error stop 'real128 oracle'
       delta=1d-5;qp=q;qm=q;qp%pressure_head_top_cm=q%pressure_head_top_cm+delta;qm%pressure_head_top_cm=q%pressure_head_top_cm-delta
       call evaluate_b110_dynamic_top_boundary(g,hp,qp,rp);call evaluate_b110_dynamic_top_boundary(g,hp,qm,rm)
       fd=(rp%surface_head_cm-rm%surface_head_cm)/(2*delta)
       maxderivative=max(maxderivative,abs(fd-r%surface_head_dpressure_head_top))
       if(abs(fd-r%surface_head_dpressure_head_top)>5d-10)error stop 'surface Jacobian finite difference'
       n=n+1
       if(trim(mode)=='linear')write(*,'(4es26.17)')r%surface_head_cm,r%runoff_depth_cm,r%actual_top_flux_cm_per_day,r%surface_head_dpressure_head_top
      end do
     end do
    end do
   end do
  end do
 end do
 write(*,'(a,i0,3es25.16)')'POWER_RUNOFF_PASS ',n,maxbalance,maxderivative,maxoracle
end program
