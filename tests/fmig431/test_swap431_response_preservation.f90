program response_preservation
 use iso_fortran_env,only:real64,int64
 use mod_fmr_drainage_response_binding
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_ppa_wu05b12_analytic_fixture,only:setup_b12_analytic_level
 use mod_ppa_wu05b14_extended_fixture,only:setup_b14_levels
 implicit none
 type(fmr_drainage_response_level_parameters_t)::p(1)
 type(fmr_drainage_response_level_parameters_t),allocatable::e(:)
 type(fmr_drainage_response_level_control_t)::c(1)
 type(fmr_drainage_response_level_control_t),allocatable::ec(:)
 type(fmr_drainage_response_diagnostics_t)::d
 type(process_hydraulic_view_t)::v
 real(real64)::q(1,4),g(11),pond(3)
 integer::i,j,k,st,count
 g=[-200d0,-5d0,-3.001d0,-3d0,-2.99999999995d0,-2.5d0,-1d0,-.1d0,0d0,10d0,1001d0]
 pond=[0d0,.25d0,1d0];count=0;v%active_nodes=4
 allocate(v%pressure_head(4),v%water_content(4));v%pressure_head=-75d0;v%water_content=.3d0
 do k=1,9
  p=fmr_drainage_response_level_parameters_t();c=fmr_drainage_response_level_control_t();p(1)%variant=k
  select case(k)
  case(1)
   p(1)%linear%drainage_resistance=200d0;c(1)%drain_head_supplied=.true.;c(1)%drain_head=-3d0
  case(2)
   p(1)%tabulated%groundwater_depth=[0d0,2d0,100d0];p(1)%tabulated%signed_exchange_rate=[.1d0,0d0,-.01d0]
  case(3:7)
   call setup_b12_analytic_level(p(1),k-2,-3d0,st)
   if(st/=0)error stop 'preparation'
  case(8)
   p(1)%empirical%coefficient=.1d0;p(1)%empirical%exponent=.5d0;c(1)%drain_head_supplied=.true.;c(1)%drain_head=-3d0
  case(9)
   call setup_b14_levels(3,[-3d0,-2d0],-4d0,e,ec);p=e;c=ec
  end select
  do i=1,size(g)
  do j=1,size(pond)
   v%groundwater_level=g(i);v%ponding_depth=pond(j)
   call evaluate_fmr_drainage_response_bottom_lumped(p,c,v,q,d)
   if(d%status/=0)error stop 'baseline response rejected'
   write(*,'(4I4,4Z18.16)') k,i,j,d%status,transfer(q,[0_int64],4)
   write(*,'(4Z18.16,3L2)')transfer(d%aggregate%signed_soil_to_drain_rate,0_int64), &
        transfer(d%level(1)%dq_dgroundwater_level,0_int64),transfer(d%aggregate%dq_dgroundwater_level,0_int64), &
        transfer(d%level(1)%signed_soil_to_drain_rate,0_int64),d%level(1)%flux_defined,d%level(1)%derivative_defined,d%level(1)%branch_or_nonsmooth_point
   count=count+1
  end do
  end do
 end do
 print '(A,I0)','RESPONSE_DEFAULT_PRESERVATION_CASES=',count
 print '(A)','RESPONSE_DEFAULT_REAL_BINDER=PASS'
end program
