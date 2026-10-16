module mod_a26h_provider
 use,intrinsic::iso_fortran_env,only:real64
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
 subroutine ev(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
  class(linear_t),intent(in)::self;real(real64),intent(in)::pressure_head(:)
  real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
  water_content=0.4_real64+0.002_real64*pressure_head;conductivity=1.0_real64
  capacity=.002_real64;dconductivity_dhead=0.0_real64
  if(.not.same_type_as(self,self))error stop 'provider'
 end subroutine
 subroutine evd(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead)
  class(linear_t),intent(in)::self;real(real64),intent(in)::pressure_head(:);integer,intent(in)::demand_mask
  real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
  call self%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
  if(demand_mask<0)error stop 'demand'
 end subroutine
 logical function sp(self) result(supported)
  class(linear_t),intent(in)::self;supported=.true.;if(.not.same_type_as(self,self))supported=.false.
 end function
 subroutine ep(self,node_index,pressure_head,water_content,conductivity,available)
  class(linear_t),intent(in)::self;integer,intent(in)::node_index
  real(real64),intent(in)::pressure_head,water_content;real(real64),intent(out)::conductivity;logical,intent(out)::available
  conductivity=1.0_real64;available=node_index>0.and.pressure_head==pressure_head.and.water_content==water_content
  if(.not.same_type_as(self,self))available=.false.
 end subroutine
end module
program test_ppa_wu05a26h_wall_history
 use,intrinsic::iso_fortran_env,only:int64,real64
 use mod_a26h_provider
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_physical_state,only:rfm_physical_state_t,copy_rfm_physical_state
 use mod_rfm_wall_hydraulic_history_binding
 implicit none
 type(linear_t)::p;type(process_hydraulic_view_t)::v
 type(rfm_physical_state_t)::a,snap
 type(rfm_wall_hydraulic_binding_result_t)::r,r2
 logical::ok
 call a%initialize(2,ok);if(.not.ok)error stop 'init'
 a%endpoint_water_cm=[0.2_real64,0.0_real64]
 a%wall_age_day=[0.4_real64,0.0_real64]
 a%wall_sorptivity_cm_sqrt_day=[9.0_real64,0.0_real64]
 call copy_rfm_physical_state(a,snap,ok)
 v%active_nodes=3;allocate(v%pressure_head(3),v%water_content(3))
 v%pressure_head=[-100.0_real64,-50.0_real64,-25.0_real64]
 v%water_content=0.4_real64+0.002_real64*v%pressure_head
 v%ponding_depth=0.0_real64;v%groundwater_level=-200.0_real64
 call bind_rfm_wall_hydraulics_from_accepted(a,[0.1_real64,0.1_real64],[1,2],3,v,p,32,r)
 if(.not.r%valid)error stop 'bind'
 if(transfer(r%endpoint_sorptivity_cm_sqrt_day(1),0_int64)/=transfer(9.0_real64,0_int64))error stop 'wet overwritten'
 if(abs(r%endpoint_sorptivity_cm_sqrt_day(2)-sqrt(7.5_real64))>1e-12_real64)error stop 'dry seed'
 if(abs(r%mb_sorptivity_cm_sqrt_day-sqrt(1.875_real64))>1e-12_real64)error stop 'mb derive'
 if(.not.a%same_values(snap))error stop 'accepted mutated'
 call bind_rfm_wall_hydraulics_from_accepted(a,[0.1_real64,0.1_real64],[1,2],3,v,p,32,r2)
 if(any(transfer(r%endpoint_sorptivity_cm_sqrt_day,[0_int64],2)/= &
        transfer(r2%endpoint_sorptivity_cm_sqrt_day,[0_int64],2)))error stop 'retry endpoint'
 if(transfer(r%mb_sorptivity_cm_sqrt_day,0_int64)/=transfer(r2%mb_sorptivity_cm_sqrt_day,0_int64))error stop 'retry mb'
 print '(a)','PPA_WU05A26H_WALL_HISTORY=PASS'
end program
