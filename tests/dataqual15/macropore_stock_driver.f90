program macropore_stock_driver
 use iso_fortran_env,only:real64
 use mod_macropore_continuation_state,only:macropore_continuation_state_t
 use mod_macropore_standard_storage,only:macropore_standard_storage_view_t, &
   derive_macropore_standard_storage_view,canonicalize_macropore_standard_storage
 use mod_ppa_wu05a6_vertical_flux_reconstruction,only:vertical_flux_reconstruction_request_t, &
   vertical_flux_reconstruction_result_t,reconstruct_vertical_flux
 implicit none
 type(macropore_continuation_state_t)::s,old,normalized
 type(macropore_standard_storage_view_t)::v,again
 type(vertical_flux_reconstruction_request_t)::request
 type(vertical_flux_reconstruction_result_t)::flux
 real(real64)::z(4)=[-.5d0,-1.5d0,-2.5d0,-3.5d0],dz(4)=1d0,total,err,scale
 integer::geometry,k,cases
 logical::ok
 cases=0
 do geometry=1,3
  do k=1,10
   call s%initialize(1,4,ok)
   if(.not.ok)error stop 'initialize'
   s%icp_bottom_domain=4;s%volume_domain_cp=0.1d0
   if(geometry==2)s%volume_domain_cp(1,4)=0d0
   if(geometry==3)s%volume_domain_cp(1,4)=1d-15
   total=10d0**(-18+k)
   s%water_domain_cp(1,1)=total
   old=s
   call derive_macropore_standard_storage_view(s,1,z,dz,v)
   if(.not.v%valid.or..not.s%same_values(old))error stop 'pure view'
   scale=max(total,tiny(1d0));err=abs(sum(v%normalized_water_cm)-total)/scale
   if(err>8d0*epsilon(1d0))error stop 'stock erased or invented'
   normalized=s
   call canonicalize_macropore_standard_storage(normalized,1,z,dz,again,ok)
   if(.not.ok)error stop 'canonicalize'
   call derive_macropore_standard_storage_view(normalized,1,z,dz,again)
   if(.not.again%valid)error stop 'second view'
   if(any(again%normalized_water_cm/=v%normalized_water_cm))error stop 'idempotence'
   request%num_domains=1;request%num_nodes=4;request%top_node=1;request%step_duration=.002d0
   request%bottom_domain=[4];request%top_inflow_rate=[total/.002d0]
   request%previous_water_cm=reshape([0d0,0d0,0d0,0d0],[1,4])
   request%current_water_cm=v%normalized_water_cm
   request%exchange_to_matrix_rate=reshape([0d0,0d0,0d0,0d0],[1,4])
   request%external_outflow_rate=reshape([0d0,0d0,0d0,0d0],[1,4])
   call reconstruct_vertical_flux(request,flux)
   if(.not.flux%valid)error stop 'reconstruction'
   if(abs(flux%vertical_face_rate(1,5))>16d0*epsilon(1d0)*total/.002d0)error stop 'fictitious closed-bottom flux'
   cases=cases+1
   write(*,'(a,i0,a,i0,2(a,es25.17e3))')'STOCK,',geometry,',',k,',',total,',',flux%vertical_face_rate(1,5)
  end do
 end do
 ! A nearly filled ordinary cell must not create water by rounding upwards.
 call s%initialize(1,4,ok);s%icp_bottom_domain=4;s%volume_domain_cp=.1d0
 total=.1d0-5d-13;s%water_domain_cp(1,4)=total
 call derive_macropore_standard_storage_view(s,1,z,dz,v)
 if(.not.v%valid.or.sum(v%normalized_water_cm)/=total)error stop 'near-full mass creation'
 print '(a,i0)','MACRO_STOCK_MASS_AND_CLOSED_BOTTOM_PASS ',cases+1
end program
