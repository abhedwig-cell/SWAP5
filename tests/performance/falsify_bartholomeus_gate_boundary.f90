program falsify_bartholomeus_gate_boundary
 ! PERF02 deterministic decision-boundary falsification.
 use iso_fortran_env,only:real64,int64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider,only:evaluate_bartholomeus_factors_from_state
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 use mod_bartholomeus_no_stress_gate,only:bartholomeus_macro_supply_bound_no_stress
 implicit none
 integer,parameter::NCASE=512,NNEAR=9
 real(real64),parameter::eps(NNEAR)=[-1e-4_real64,-1e-6_real64,-1e-8_real64,-1e-10_real64,0._real64,1e-10_real64,1e-8_real64,1e-6_real64,1e-4_real64]
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 real(real64)::wr(1),w0(1),facmin,ct,lo,hi,mid,gate_ct,ref_ct,theta_r,theta_s,alpha,npar,gfp,head,temp,depth
 real(real64),allocatable::fac(:)
 integer::k,j,it,total,skips,false_skips,n_gt2,n_gt2_skips,near_gate,near_ref
 logical::ok,sg,slo,shi,rlo,rhi
 total=0;skips=0;false_skips=0;n_gt2=0;n_gt2_skips=0;near_gate=0;near_ref=0
 allocate(v%pressure_head_cm(1),v%water_content(1),v%soil_temperature_k(1));v%rooted_nodes=1
 do k=1,NCASE
   theta_r=0.01_real64+0.09_real64*u(k,1); theta_s=max(theta_r+0.12_real64,0.32_real64+0.28_real64*u(k,2))
   alpha=0.002_real64+0.048_real64*u(k,3); npar=1.05_real64+1.75_real64*u(k,4)
   head=-(0.2_real64*10._real64**(4.2_real64*u(k,5))); temp=273.5_real64+35._real64*u(k,6)
   gfp=max(1.01e-4_real64,(theta_s-theta_r)*(0.002_real64+0.90_real64*u(k,7)))
   depth=0.005_real64+0.495_real64*u(k,8)
   call setup_case(theta_r,theta_s,alpha,npar,depth,u(k,9),u(k,10),u(k,11),d,c,ok)
   if(.not.ok)cycle
   v%pressure_head_cm=head;v%water_content=theta_s-gfp;v%soil_temperature_k=temp
   wr=0.002_real64+2._real64*u(k,12);w0=0.002_real64+2._real64*u(k,22)
   c%c_mroot=1e-7_real64*10._real64**(4._real64*u(k,13))
   c%f_senes=0.05_real64+0.95_real64*u(k,14)
   c%specific_resp_humus=1e-8_real64*10._real64**(4._real64*u(k,15))
   c%q10_root=1.1_real64+2.9_real64*u(k,16);c%q10_microbial=1.1_real64+2.9_real64*u(k,17)
   c%microbial_shape_m=0.03_real64+1.47_real64*u(k,18);c%root_shape_m=0.03_real64+1.47_real64*u(k,19)
   c%root_radius_m=2e-5_real64*10._real64**(2._real64*u(k,20));c%max_resp_factor=1._real64+3._real64*u(k,21)
   if(npar>2._real64)n_gt2=n_gt2+1
   ! Broad ctop probes plus direct false-skip check.
   do j=0,16
     ct=1e-3_real64*10._real64**(real(j,real64)*0.5_real64)
     call check_point(ct,npar>2._real64)
   enddo
   ! Locate gate decision boundary in ctop, if bracketed, then probe densely around it.
   lo=1e-4_real64;hi=1e6_real64;slo=bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,lo);shi=bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,hi)
   if((.not.slo).and.shi)then
     do it=1,70
       mid=sqrt(lo*hi)
       if(bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,mid))then;hi=mid;else;lo=mid;endif
     enddo
     gate_ct=hi
     do j=1,NNEAR;near_gate=near_gate+1;call check_point(gate_ct*(1._real64+eps(j)),npar>2._real64);enddo
   endif
   ! Independently locate the full Reference transition to factor 1 and probe it.
   lo=1e-4_real64;hi=1e6_real64;call ref_no_stress(lo,rlo);call ref_no_stress(hi,rhi)
   if((.not.rlo).and.rhi)then
     do it=1,70
       mid=sqrt(lo*hi);call ref_no_stress(mid,ok)
       if(ok)then;hi=mid;else;lo=mid;endif
     enddo
     ref_ct=hi
     do j=1,NNEAR;near_ref=near_ref+1;call check_point(ref_ct*(1._real64+eps(j)),npar>2._real64);enddo
   endif
 enddo
 print '(a,i0)','BOUNDARY_TOTAL=',total
 print '(a,i0)','BOUNDARY_SKIPS=',skips
 print '(a,i0)','BOUNDARY_FALSE_SKIPS=',false_skips
 print '(a,i0)','BOUNDARY_NEAR_GATE=',near_gate
 print '(a,i0)','BOUNDARY_NEAR_REFERENCE=',near_ref
 print '(a,i0)','BOUNDARY_N_GT_2_CASES=',n_gt2
 print '(a,i0)','BOUNDARY_N_GT_2_SKIPS=',n_gt2_skips
 if(false_skips/=0)error stop 'PERF02 boundary falsified'
 if(n_gt2_skips/=0)error stop 'n>2 must conservatively fall back'
contains
 subroutine check_point(ctop,is_gt2)
  real(real64),intent(in)::ctop;logical,intent(in)::is_gt2
  logical::g
  if(ctop<=0)return
  call evaluate_bartholomeus_factors_from_state(v,d,c,wr,w0,ctop,BARTHOLOMEUS_WATERFILM_REFERENCE,fac,ok)
  if(.not.ok)return
  facmin=minval(fac);g=bartholomeus_macro_supply_bound_no_stress(v,d,c,wr,w0,ctop)
  total=total+1
  if(g)then
    skips=skips+1
    if(is_gt2)n_gt2_skips=n_gt2_skips+1
    if(facmin<1._real64-1e-14_real64)then
      false_skips=false_skips+1
      write(*,'(a,i0,8(1x,es16.8))')'FALSE_SKIP',k,ctop,facmin,head,gfp,npar,alpha,temp,wr(1)
    endif
  endif
 end subroutine
 subroutine ref_no_stress(ctop,res)
  real(real64),intent(in)::ctop;logical,intent(out)::res
  call evaluate_bartholomeus_factors_from_state(v,d,c,wr,w0,ctop,BARTHOLOMEUS_WATERFILM_REFERENCE,fac,ok)
  res=ok.and.minval(fac)>=1._real64-1e-14_real64
 end subroutine
 subroutine setup_case(tr,ts,a,n,dz,uo,us,ub,data,crop,valid)
  real(real64),intent(in)::tr,ts,a,n,dz,uo,us,ub
  type(BartholomeusImmutableDataset),intent(out)::data;type(BartholomeusCropParameters),intent(out)::crop;logical,intent(out)::valid
  real(real64)::cg(7,1),z(1),org(1),sand(1),bd(1),w100(1),w500(1),tg(1),m
  cg=0._real64;m=1._real64-1._real64/n;cg(1,1)=tr;cg(2,1)=ts;cg(4,1)=a;cg(6,1)=n;cg(7,1)=m
  z=100._real64*dz;org=0.001_real64+0.119_real64*uo;sand=0.05_real64+0.90_real64*us;bd=800._real64+900._real64*ub
  w100=tr+0.72_real64*(ts-tr);w500=tr+0.35_real64*(ts-tr);tg=tr+0.65_real64*(ts-tr)
  call construct_bartholomeus_dataset(cg,z,org,sand,bd,w100,w500,tg,-100._real64,-500._real64,0,data,valid)
  crop%c_mroot=1e-5_real64;crop%f_senes=1;crop%q10_root=2;crop%specific_resp_humus=1e-6_real64;crop%q10_microbial=2
  crop%microbial_shape_m=.9_real64;crop%root_shape_m=.9_real64;crop%root_radius_m=2e-4_real64;crop%max_resp_factor=2
 end subroutine
 pure real(real64) function u(i,j)
  integer,intent(in)::i,j
  integer(int64)::x
  x=mod(104729_int64*int(i,int64)+13007_int64*int(j,int64)+7919_int64*int(i*j,int64),1000003_int64)
  u=(real(x,real64)+0.5_real64)/1000003.0_real64
 end function
end program
