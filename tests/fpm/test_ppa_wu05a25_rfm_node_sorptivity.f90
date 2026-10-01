module mod_a25_node_s_test
 use, intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:constitutive_hydraulics_provider_t
 implicit none
 type,extends(constitutive_hydraulics_provider_t)::linear_t
 contains
  procedure::evaluate=>ev
  procedure::evaluate_demand=>evd
  procedure::supports_point_conductivity=>sp
  procedure::evaluate_point_conductivity=>ep
 end type
contains
 subroutine ev(self,h,theta,k,c,dk)
  class(linear_t),intent(in)::self;real(real64),intent(in)::h(:)
  real(real64),intent(out)::theta(:),k(:),c(:),dk(:)
  theta=0.4_real64+0.002_real64*h;k=1.0_real64;c=.002_real64;dk=0.0_real64
 end subroutine
 subroutine evd(self,h,m,theta,k,c,dk)
  class(linear_t),intent(in)::self;real(real64),intent(in)::h(:);integer,intent(in)::m
  real(real64),intent(out)::theta(:),k(:),c(:),dk(:);call self%evaluate(h,theta,k,c,dk)
 end subroutine
 logical function sp(self) result(x);class(linear_t),intent(in)::self;x=.true.;end function
 subroutine ep(self,i,h,t,k,a);class(linear_t),intent(in)::self;integer,intent(in)::i
  real(real64),intent(in)::h,t;real(real64),intent(out)::k;logical,intent(out)::a;k=1.0_real64;a=i>0
 end subroutine
end module
program test_ppa_wu05a25_rfm_node_sorptivity
 use, intrinsic::iso_fortran_env,only:real64
 use mod_a25_node_s_test
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_surface_sorptivity,only:evaluate_rfm_node_sorptivity
 implicit none
 type(linear_t)::p;type(process_hydraulic_view_t)::v;real(real64)::s;logical::ok
 v%active_nodes=2;allocate(v%pressure_head(2),v%water_content(2))
 v%pressure_head=[-100.0_real64,-50.0_real64];v%water_content=[0.2_real64,0.3_real64]
 v%ponding_depth=0.0_real64;v%groundwater_level=-200.0_real64
 call evaluate_rfm_node_sorptivity(v,p,2,32,s,ok)
 if(.not.ok)error stop 'node S unavailable'
 if(abs(s-sqrt(7.5_real64))>1e-12_real64)error stop 'node S oracle'
 print '(a)','PPA_WU05A25_RFM_NODE_SORPTIVITY=PASS'
end program
