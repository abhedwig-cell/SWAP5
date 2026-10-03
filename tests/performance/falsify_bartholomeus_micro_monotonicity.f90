program falsify_micro_monotonicity
 use iso_fortran_env,only:real64
 use mod_bartholomeus_micro
 implicit none
 type(BartholomeusMicroInput)::p
 real(real64)::prev,cur,w,rf
 integer::it,ig,ir,iw,viol,total
 real(real64),parameter::temps(5)=real([278,283,288,293,303],real64)
 real(real64),parameter::gfps(6)=[.005_real64,.02_real64,.05_real64,.10_real64,.20_real64,.35_real64]
 real(real64),parameter::roots(5)=[0._real64,.1_real64,.3_real64,.6_real64,1._real64]
 viol=0;total=0
 do it=1,size(temps);do ig=1,size(gfps);do ir=1,size(roots)
  p%c_mroot=1e-5;p%w_root=roots(ir);p%f_senes=1;p%q10_root=2;p%soil_temp_k=temps(it)
  p%sat_water_content=.45;p%gas_filled_porosity=gfps(ig);p%d_o2_in_water=1e-4;p%d_root=.4e-4
  p%percent_org_mat=2;p%soil_density=1300;p%specific_resp_humus=1e-6;p%q10_microbial=2
  p%depth_m=.1;p%microbial_shape_m=.9;p%root_radius_m=.0002;p%bunsen_coeff=.03
  rf=2;prev=-huge(1._real64)
  do iw=0,240
   w=10._real64**(-8._real64+real(iw,real64)*(5._real64/240._real64))
   p%waterfilm_thickness_m=w;cur=bartholomeus_micro_concentration(p,rf)
   total=total+1
   if(iw>0 .and. cur<prev-1e-12_real64*max(1._real64,abs(prev)))viol=viol+1
   prev=cur
  enddo
 enddo;enddo;enddo
 print '(a,i0)','MICRO_MONO_TOTAL=',total
 print '(a,i0)','MICRO_MONO_DECREASE_VIOLATIONS=',viol
end program
