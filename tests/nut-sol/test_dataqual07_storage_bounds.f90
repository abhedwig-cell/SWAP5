program test_storage_bounds
 use iso_fortran_env,only:real64
 use mod_ppa_wu05a6_top_inflow_limiter
 implicit none
 type(standard_inflow_limit_request_t)::q
 type(standard_inflow_limit_result_t)::r
 real(real64)::scale,stock,change,maximum_error,budget
 integer::i,j,cases
 q%num_domains=1
 q%accepted_storage_cm=[0d0];q%maximum_storage_cm=[1d0];q%minimum_storage_cm=[0d0]
 q%potential_top_vertical_cm=[0d0];q%potential_top_lateral_cm=[0d0]
 q%potential_interflow_sat_cm=[0d0];q%potential_matrix_sat_cm=[0d0]
 q%potential_outflow_cm=[7.67100964216345d-11];q%redistribution_capacity_cm=[0d0];q%top_domain_fraction=[1d0]
 call evaluate_standard_inflow_limit(q,r)
 if(.not.r%valid.or.r%outflow_fraction(1)/=1d0)error stop 'legacy deadband changed'
 q%conservative_storage_bounds=.true.
 call evaluate_standard_inflow_limit(q,r)
 if(.not.r%valid.or.r%outflow_fraction(1)/=0d0)error stop 'dry domain exported water'
 maximum_error=0d0;cases=0
 do i=-16,2
  scale=10d0**i
  do j=0,100
   q%maximum_storage_cm=[scale]
   q%accepted_storage_cm=[scale*j/100d0]
   q%potential_outflow_cm=[scale*(101-j)/70d0]
   q%potential_top_vertical_cm=[scale*j/90d0]
   q%potential_top_lateral_cm=[scale*j/130d0]
   q%potential_interflow_sat_cm=[scale*j/270d0]
   q%potential_matrix_sat_cm=[scale*j/110d0]
   call evaluate_standard_inflow_limit(q,r)
   if(.not.r%valid)error stop 'valid receipt rejected'
   budget=q%accepted_storage_cm(1)+r%accepted_top_vertical_cm(1)+r%accepted_top_lateral_cm(1) + &
     r%accepted_interflow_sat_cm(1)+r%accepted_matrix_sat_cm(1)
   stock=budget-r%outflow_fraction(1)*q%potential_outflow_cm(1)
   if(stock < -8d0*epsilon(1d0)*scale.or.stock>scale*(1d0+8d0*epsilon(1d0)))error stop 'storage bound'
   if(r%outflow_fraction(1)<0d0.or.r%outflow_fraction(1)>1d0)error stop 'invalid fraction'
   change=stock-q%accepted_storage_cm(1)
   maximum_error=max(maximum_error,abs(change-(budget-q%accepted_storage_cm(1) - &
     r%outflow_fraction(1)*q%potential_outflow_cm(1))))
   cases=cases+1
  enddo
 enddo
 ! A receiver with pre-existing top input has less redistribution room.
 q%num_domains=2
 q%accepted_storage_cm=[1d0,.8d0];q%maximum_storage_cm=[1d0,1d0];q%minimum_storage_cm=[0d0,0d0]
 q%potential_top_vertical_cm=[1d0,.1d0];q%potential_top_lateral_cm=[0d0,0d0]
 q%potential_interflow_sat_cm=[0d0,0d0];q%potential_matrix_sat_cm=[0d0,0d0]
 q%potential_outflow_cm=[0d0,0d0];q%redistribution_capacity_cm=[0d0,.2d0];q%top_domain_fraction=[.5d0,.5d0]
 call evaluate_standard_inflow_limit(q,r)
 if(.not.r%valid)error stop 'redistribution receipt'
 if(abs(r%redistributed_top_cm(2)-.1d0)>1d-15)error stop 'receiver room'
 if(abs(q%accepted_storage_cm(2)+r%accepted_top_vertical_cm(2)-1d0)>1d-15)error stop 'receiver overfill'
 if(abs(r%returned_surface_cm-.9d0)>1d-15)error stop 'return to surface'
 q%accepted_storage_cm=[-1d0,-1d0]
 call evaluate_standard_inflow_limit(q,r)
 if(r%valid)error stop 'invalid stock admitted'
 print *, 'DATAQUAL07_STORAGE_BOUNDS_PASS',cases,maximum_error
end program
