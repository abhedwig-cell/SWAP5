program test_q4b_dynamic_top_direct
 use,intrinsic::iso_fortran_env,only:real64
 use MOD_grid,only:numnod,z,dz,disnod
 use mod_soil_water_solver_contract,only:soil_water_parameter_set_t,soil_water_boundary_conditions_t,soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE
 use mod_b110_default_mvg_provider,only:b110_default_mvg_parameters_t,initialize_b110_default_mvg_parameters
 use mod_b110_dynamic_top_boundary_solver_adapter,only:b110_dynamic_top_boundary_solver_provider_t,bind_b110_dynamic_top_boundary_solver_provider
 implicit none
 type(soil_water_parameter_set_t),target::g
 type(b110_default_mvg_parameters_t),target::hp
 type(b110_dynamic_top_boundary_solver_provider_t)::p
 type(soil_water_boundary_conditions_t)::bc
 type(soil_water_top_boundary_result_t)::r
 real(real64)::cof(24,numnod),hs(12),ths(12),h,theta,pond,dt
 integer::soil,i,j,k
 hs=real([-300,-100,-55,-30,-20,-10,-3,-1,0,1,5,20],real64)
 ths=real([.05,.1,.15,.2,.25,.3,.35,.4,.45,.5,.55,.6],real64)
 g%active_nodes=numnod;allocate(g%z(numnod),g%dz(numnod),g%node_distance(numnod))
 g%z=z;g%dz=dz;g%node_distance=disnod(1:numnod)
 do soil=1,2
  call init_cof(cof,soil);call initialize_b110_default_mvg_parameters(hp,cof)
  do i=1,size(hs)
   h=hs(i)
   do j=1,3
    select case(j);case(1);pond=0._real64;case(2);pond=1e-8_real64;case(3);pond=.1_real64;end select
    do k=1,3
     select case(k);case(1);dt=.01_real64;case(2);dt=.005_real64;case(3);dt=.000625_real64;end select
     theta=.3_real64
     call bind_b110_dynamic_top_boundary_solver_provider(p,g,hp,1,pond,dt,0._real64,0._real64,0._real64,0._real64,0._real64,0._real64,0._real64,0._real64,1._real64)
     call p%evaluate(h,theta,pond,bc,r)
     write(*,'(*(g0,:,","))')'DIRECT',soil,h,theta,pond,dt,r%status,trim(r%route),r%actual_top_flux,r%candidate_ponding_depth
     if(r%status/=SW_TOP_BOUNDARY_AVAILABLE)error stop 'direct provider unavailable'
    end do
   end do
  end do
 end do
 print '(a)','Q4B_DYNAMIC_TOP_DIRECT=PASS'
contains
 subroutine init_cof(c,s)
  real(real64),intent(out)::c(:,:);integer,intent(in)::s;real(real64)::tr,ts,a,n,l,ks;integer::q
  if(s==1)then;tr=.02;ts=.43;a=.0234;n=1.801;l=-1.061;ks=52.91
  else;tr=.01;ts=.59;a=.0195;n=1.109;l=-3.138;ks=5.52;end if
  c=0
  do q=1,size(c,2);c(1,q)=tr;c(2,q)=ts;c(3,q)=ks;c(4,q)=a;c(5,q)=l;c(6,q)=n;c(7,q)=1-1/n;c(8,q)=a;c(10,q)=ks;c(11,q)=.999;c(12,q)=.99*ks;c(22,q)=-1e6;c(23,q)=1e-12;end do
 end subroutine
end program
