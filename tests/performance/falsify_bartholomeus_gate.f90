program falsify_bartholomeus_gate
 use iso_fortran_env,only:real64
 use mod_bartholomeus_runtime_input,only:bartholomeus_runtime_view_t
 use mod_bartholomeus_parameter_contract
 use mod_bartholomeus_factor_provider,only:evaluate_bartholomeus_factors_from_state
 use mod_bartholomeus_waterfilm_provider,only:BARTHOLOMEUS_WATERFILM_REFERENCE
 use mod_bartholomeus_no_stress_gate,only:bartholomeus_macro_supply_bound_no_stress
 implicit none
 integer,parameter::N=3
 real(real64),parameter::heads(11)=real([-1,-3,-5,-10,-20,-40,-75,-100,-200,-500,-1000],real64)
 real(real64),parameter::temps(5)=real([278,283,288,293,303],real64)
 real(real64),parameter::roots(5)=[0._real64,.1_real64,.3_real64,.6_real64,1._real64]
 real(real64),parameter::ctops(4)=[.27_real64,2.7_real64,27._real64,270._real64]
 type(bartholomeus_runtime_view_t)::v
 type(BartholomeusImmutableDataset)::d
 type(BartholomeusCropParameters)::c
 real(real64)::wr(N),w0(N),top,gfpmin,minfac
 real(real64),allocatable::fac(:)
 integer::ih,it,ir,ic,total,nostress,skips,false_skips
 logical::ok
 call setup(v,d,c)
 total=0;nostress=0;skips=0;false_skips=0
 do ih=1,size(heads);do it=1,size(temps);do ir=1,size(roots);do ic=1,size(ctops)
  v%pressure_head_cm=heads(ih);v%soil_temperature_k=temps(it)
  call theta_from_head(heads(ih),v%water_content)
  wr=roots(ir);w0=roots(ir);top=ctops(ic)
  call evaluate_bartholomeus_factors_from_state(v,d,c,wr,w0,top,BARTHOLOMEUS_WATERFILM_REFERENCE,fac,ok)
  if(.not.ok)error stop 'reference'
  total=total+1;minfac=minval(fac)
  if(minfac>=1._real64-1.e-14_real64)nostress=nostress+1
  if(bartholomeus_macro_supply_bound_no_stress(v,d,c,w0,top))then
   skips=skips+1;if(minfac<1._real64-1.e-14_real64)false_skips=false_skips+1
  endif
  gfpmin=minval(d%soil(:)%saturated_water_content-v%water_content)
  write(*,'(a,4(es14.6,1x),a,es14.6,1x,a,es14.6)')'GATE_ROW ',heads(ih),temps(it),roots(ir),gfpmin,' CTOP ',top,' MINFAC ',minfac
 enddo;enddo;enddo;enddo
 print '(a,i0)','GATE_TOTAL=',total
 print '(a,i0)','GATE_NOSTRESS=',nostress
 print '(a,i0)','GATE_BOUND_SKIPS=',skips
 print '(a,i0)','GATE_BOUND_FALSE_SKIPS=',false_skips
contains
 subroutine setup(v,d,c)
  type(bartholomeus_runtime_view_t),intent(out)::v;type(BartholomeusImmutableDataset),intent(out)::d
  type(BartholomeusCropParameters),intent(out)::c
  real(real64)::cg(7,N),dz(N),org(N),sand(N),bd(N),w100(N),w500(N);logical::valid
  cg=0;cg(1,:)=.05;cg(2,:)=.45;cg(4,:)=.01;cg(6,:)=1.5;cg(7,:)=1._real64-1._real64/cg(6,:)
  dz=10;org=.02;sand=.6;bd=1300;w100=.30;w500=.20
  call construct_bartholomeus_dataset(cg,dz,org,sand,bd,w100,w500,w100,-100._real64,-500._real64,0,d,valid)
  if(.not.valid)error stop 'dataset';v%rooted_nodes=N
  allocate(v%pressure_head_cm(N),v%water_content(N),v%soil_temperature_k(N))
  c%c_mroot=1e-5;c%f_senes=1;c%q10_root=2;c%specific_resp_humus=1e-6;c%q10_microbial=2
  c%microbial_shape_m=.9;c%root_shape_m=.9;c%root_radius_m=.0002;c%max_resp_factor=2
 end subroutine
 subroutine theta_from_head(h,theta)
  real(real64),intent(in)::h;real(real64),intent(out)::theta(N)
  real(real64)::se
  se=(1._real64+(.01_real64*abs(h))**1.5_real64)**(-(1._real64-1._real64/1.5_real64))
  theta=.05_real64+(.45_real64-.05_real64)*se
 end subroutine
end program
