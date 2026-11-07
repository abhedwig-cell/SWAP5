program joint_saturation_contact_driver
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use mod_ppa_wu05a6_saturated_exchange_rate
 implicit none
 type(saturated_exchange_request_t)::r,bad
 type(saturated_exchange_result_t)::opened,closed,graph,ordinary
 real(real64)::fraction,expected
 integer::i,side
 r%num_domains=1;r%num_nodes=2;r%matrix_top_saturated_node=1;r%matrix_bottom_saturated_node=2
 r%step_duration=.001d0;r%matrix_level=-.5d0
 r%bottom_domain=[2];r%top_macro_saturated_node=[1]
 r%macro_saturated_fraction=[.5d0];r%macro_reference_level=[1d0]
 r%z=[-1d0,-2d0];r%dz=[1d0,1d0];r%matrix_head=[0d0,1d0]
 r%ksat_horizontal=[1d0,1d0];r%diameter=[.2d0,.2d0]
 r%domain_fraction=reshape([.01d0,.01d0],[1,2]);r%cdarcy=reshape([.4d0,.3d0],[1,2])
 call evaluate_saturated_exchange(r,opened)
 r%matrix_head(1)=-1d-12;call evaluate_saturated_exchange(r,closed)
 if(.not.opened%valid.or..not.closed%valid)error stop 'invalid endpoint'
 if(closed%qexc_to_matrix_rate_cm_per_day(1,1)/=0d0)error stop 'negative-head exclusion lost'
 if(opened%qexc_to_matrix_rate_cm_per_day(1,1)<=0d0)error stop 'missing zero-head jump'
 r%zero_head_fraction=[0d0,-1d0]
 do i=0,4
  fraction=real(i,real64)/4d0;r%zero_head_fraction(1)=fraction
  do side=1,2
   r%matrix_head(1)=-real(side-1,real64)*1d-12
   call evaluate_saturated_exchange(r,graph)
   if(.not.graph%valid)error stop 'graph invalid'
   expected=fraction*opened%qexc_to_matrix_rate_cm_per_day(1,1)
   if(abs(graph%qexc_to_matrix_rate_cm_per_day(1,1)-expected)>1d-15)error stop 'wrong graph action'
   if(graph%qexc_to_matrix_rate_cm_per_day(1,2)/=opened%qexc_to_matrix_rate_cm_per_day(1,2))error stop 'other cell changed'
   if(abs(graph%macro_to_matrix_amount_cm(1,1)-r%step_duration*expected)>1d-15)error stop 'amount rate mismatch'
   if(abs(graph%signed_matrix_to_macro_amount_cm(1,1)+graph%macro_to_matrix_amount_cm(1,1))>1d-15)error stop 'signed transfer mismatch'
  end do
 end do
 r%zero_head_fraction=-1d0;r%matrix_head(1)=0d0
 call evaluate_saturated_exchange(r,ordinary)
 if(any(ordinary%signed_matrix_to_macro_amount_cm/=opened%signed_matrix_to_macro_amount_cm))error stop 'unselected route changed'
 bad=r;bad%zero_head_fraction=[0d0];call evaluate_saturated_exchange(bad,graph)
 if(graph%valid)error stop 'wrong shape admitted'
 bad=r;bad%zero_head_fraction(1)=1.01d0;call evaluate_saturated_exchange(bad,graph)
 if(graph%valid)error stop 'out of range admitted'
 bad=r;bad%zero_head_fraction(1)=ieee_value(0d0,ieee_quiet_nan);call evaluate_saturated_exchange(bad,graph)
 if(graph%valid)error stop 'nonfinite admitted'
 print '(a)','ZERO_HEAD_SATURATED_TRANSFER_ENDPOINTS_ACTION_CONSERVATION_REFUSALS_PASS'
end program
