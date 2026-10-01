program a27_reverse_exchange
 use iso_fortran_env, only: real64
 use mod_ppa_wu05a6_saturated_exchange_rate
 use mod_rfm_endpoint_release
 implicit none
 type(saturated_exchange_request_t)::s
 type(saturated_exchange_result_t)::sr
 type(rfm_endpoint_release_request_t)::r
 type(rfm_endpoint_release_result_t)::rr
 real(real64)::heads(3),steps(3),expected
 integer::i,j
 heads=[2._real64,5._real64,10._real64]
 steps=[.01_real64,.005_real64,.0025_real64]
 s%num_domains=1;s%num_nodes=1;s%matrix_top_saturated_node=1;s%matrix_bottom_saturated_node=1
 s%matrix_partial_top_active=.false.;s%flow_reduction=1.;s%shape_factor=1.
 s%bottom_domain=[1];s%top_macro_saturated_node=[1];s%macro_saturated_fraction=[1._real64]
 s%z=[-95._real64];s%dz=[10._real64];s%macro_reference_level=[-94._real64]
 s%ksat_horizontal=[1._real64];s%diameter=[20._real64]
 allocate(s%domain_fraction(1,1),s%cdarcy(1,1))
 s%domain_fraction=1.;s%cdarcy=.01_real64
 ! Shared local geometry: contact bottom 100 cm, area .05, W=.3 -> H=6, water level 94 cm, h_mp(95)=1.
 r%accepted_storage_cm=[.3_real64];r%contact_thickness_cm=[10._real64]
 r%exchange_length_cm=[20._real64];r%chi_wall=[1._real64]
 r%wall_sorptivity_cm_sqrt_day=[0._real64];r%matrix_conductivity_cm_per_day=[1._real64]
 r%accepted_wall_age_day=[0._real64]
 print '(a)','matrix_head_cm,macro_head_cm,dt_day,standard_matrix_to_macro_cm,rfm_matrix_to_macro_cm,rfm_macro_to_matrix_cm'
 do i=1,3
  do j=1,3
   s%matrix_head=[heads(i)];s%step_duration=steps(j)
   call evaluate_saturated_exchange(s,sr)
   if(.not.sr%valid)error stop 'standard invalid'
   expected=.01_real64*(heads(i)-1._real64)*steps(j)
   if(abs(sr%matrix_to_macro_amount_cm(1,1)-expected)>1e-14_real64)error stop 'Darcy oracle'
   r%step_duration_day=steps(j)
   r%macro_to_matrix_head_difference_cm=[max(0._real64,1._real64-heads(i))]
   call evaluate_rfm_endpoint_release(r,1e-12_real64,rr)
   if(.not.rr%valid)error stop 'RFM invalid'
   if(rr%release_total_cm/=0._real64.or.rr%storage_end_cm/=.3_real64)error stop 'RFM directional oracle'
   print '(6(es24.16,:,","))',heads(i),1._real64,steps(j),sr%matrix_to_macro_amount_cm(1,1),0._real64,rr%release_total_cm
  end do
 end do
end program
