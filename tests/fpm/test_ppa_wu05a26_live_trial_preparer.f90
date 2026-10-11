module mod_a26_live_provider
 use,intrinsic::iso_fortran_env,only:real64
 use mod_soil_water_solver_contract,only:constitutive_hydraulics_provider_t
 implicit none
 type,extends(constitutive_hydraulics_provider_t)::p_t
 contains
  procedure::evaluate=>ev;procedure::evaluate_demand=>evd;procedure::supports_point_conductivity=>sp;procedure::evaluate_point_conductivity=>ep
 end type
contains
 subroutine ev(self,pressure_head,water_content,conductivity,capacity,dconductivity_dhead);class(p_t),intent(in)::self;real(real64),intent(in)::pressure_head(:);real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:)
 water_content=.3_real64;conductivity=1._real64;capacity=.002_real64;dconductivity_dhead=0._real64
 end subroutine
 subroutine evd(self,pressure_head,demand_mask,water_content,conductivity,capacity,dconductivity_dhead);class(p_t),intent(in)::self;real(real64),intent(in)::pressure_head(:);integer,intent(in)::demand_mask
 real(real64),intent(out)::water_content(:),conductivity(:),capacity(:),dconductivity_dhead(:);call self%evaluate(pressure_head,water_content,conductivity,capacity,dconductivity_dhead)
 end subroutine
 logical function sp(self);class(p_t),intent(in)::self;sp=.true.;end function
 subroutine ep(self,node_index,pressure_head,water_content,conductivity,available);class(p_t),intent(in)::self;integer,intent(in)::node_index;real(real64),intent(in)::pressure_head,water_content;real(real64),intent(out)::conductivity;logical,intent(out)::available
 conductivity=1._real64;available=node_index>0
 end subroutine
end module
program test_ppa_wu05a26_live_trial_preparer
 use,intrinsic::iso_fortran_env,only:real64
 use mod_a26_live_provider
 use mod_soil_water_solver_contract,only:soil_water_top_boundary_result_t,SW_TOP_BOUNDARY_AVAILABLE,SW_TOP_BOUNDARY_REGIME_FLUX,SW_TOP_BOUNDARY_REGIME_HEAD
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_rfm_runtime_configuration,only:rfm_runtime_configuration_t
 use mod_rfm_surface_forcing,only:rfm_surface_forcing_t
 use mod_rfm_physical_state,only:rfm_physical_state_t,copy_rfm_physical_state
 use mod_rfm_live_trial_preparer
 implicit none
 type(p_t)::p;type(process_hydraulic_view_t)::v;type(rfm_runtime_configuration_t)::c
 type(rfm_surface_forcing_t)::f;type(rfm_physical_state_t)::a,snap,h1,h2,h4
 type(soil_water_top_boundary_result_t)::top;type(rfm_live_trial_prepare_result_t)::r,r2,rr
 logical::ok;integer::i;real(real64)::depth(2),thick(2),d12,d24
 call a%initialize(1,ok);if(.not.ok)error stop 'init';call copy_rfm_physical_state(a,snap,ok)
 c%enabled=.true.;c%sigma_b=1._real64;c%f_mb=.2_real64;c%connectivity_p=1._real64;c%z_ah_cm=20._real64;c%z_ic_cm=100._real64
 c%chi_wall=1._real64;c%exchange_length_cm=20._real64;c%mb_contact_length_cm=80._real64;c%sorptivity_panels=16;c%mb_wall_node_index=2
 allocate(c%endpoint_depth_cm(1),c%endpoint_contact_thickness_cm(1),c%endpoint_area_fraction(1),c%endpoint_node_index(1))
 c%endpoint_depth_cm=100._real64;c%endpoint_contact_thickness_cm=20._real64;c%endpoint_area_fraction=.05_real64;c%endpoint_node_index=2
 f%supplied=.true.;f%event_active=.true.;f%precipitation_rate_cm_per_day=8._real64
 v%active_nodes=2;allocate(v%pressure_head(2),v%water_content(2));v%pressure_head=[-100._real64,-30._real64];v%water_content=.3_real64
 v%ponding_depth=0._real64;v%groundwater_level=-200._real64;depth=[10._real64,95._real64];thick=[10._real64,10._real64]
 top%status=SW_TOP_BOUNDARY_AVAILABLE;top%regime=SW_TOP_BOUNDARY_REGIME_FLUX;top%carries_surface_mass_terms=.true.;top%runoff_resolved=.true.
 top%candidate_ponding_depth=0._real64;top%runoff_depth=0._real64;top%net_potential_surface_flux=8._real64
 call prepare_rfm_live_trial(a,c,f,v,p,top,depth,thick,.01_real64,1e-10_real64,r)
 if(.not.r%valid)error stop 'live valid'
 if(.not.a%same_values(snap))error stop 'accepted mutation'
 call prepare_rfm_live_trial(a,c,f,v,p,top,depth,thick,.01_real64,1e-10_real64,r2)
 if(abs(r%candidate%deep_receipt_cm-r2%candidate%deep_receipt_cm)>0._real64)error stop 'replay'
 top%regime=SW_TOP_BOUNDARY_REGIME_HEAD
 call prepare_rfm_live_trial(a,c,f,v,p,top,depth,thick,.01_real64,1e-10_real64,r2)
 if(r2%valid)error stop 'head regime admitted'

 ! Zero-RFM numerical limit: matrix share equals effective supply and no fast-domain receipt/source remains.
 top%regime=SW_TOP_BOUNDARY_REGIME_FLUX
 top%net_potential_surface_flux=1e-8_real64
 call prepare_rfm_live_trial(a,c,f,v,p,top,depth,thick,.01_real64,1e-10_real64,r2)
 if(.not.r2%valid)error stop 'zero limit valid'
 if(abs(r2%surface%matrix_supply_cm_per_day-r2%surface%effective_supply_cm_per_day)>1e-10_real64)error stop 'zero matrix equivalence'
 if(r2%candidate%deep_receipt_cm>1e-10_real64.or.any(r2%candidate%matrix_source_rate_per_day>1e-10_real64))error stop 'zero fast receipt'

 ! Frozen-hydraulic timestep refinement: compare one full, two half and four quarter candidate integrations.
 top%net_potential_surface_flux=8._real64
 call prepare_rfm_live_trial(a,c,f,v,p,top,depth,thick,.04_real64,1e-10_real64,r);if(.not.r%valid)error stop 'ref full'
 call copy_rfm_physical_state(r%candidate%candidate_rfm,h1,ok);if(.not.ok)error stop 'ref full copy'
 call copy_rfm_physical_state(a,h2,ok);if(.not.ok)error stop 'ref half init'
 do i=1,2
   call prepare_rfm_live_trial(h2,c,f,v,p,top,depth,thick,.02_real64,1e-10_real64,rr);if(.not.rr%valid)error stop 'ref half'
   call copy_rfm_physical_state(rr%candidate%candidate_rfm,h2,ok);if(.not.ok)error stop 'ref half copy'
 end do
 call copy_rfm_physical_state(a,h4,ok);if(.not.ok)error stop 'ref quarter init'
 do i=1,4
   call prepare_rfm_live_trial(h4,c,f,v,p,top,depth,thick,.01_real64,1e-10_real64,rr);if(.not.rr%valid)error stop 'ref quarter'
   call copy_rfm_physical_state(rr%candidate%candidate_rfm,h4,ok);if(.not.ok)error stop 'ref quarter copy'
 end do
 d12=abs(sum(h1%endpoint_water_cm)-sum(h2%endpoint_water_cm))
 d24=abs(sum(h2%endpoint_water_cm)-sum(h4%endpoint_water_cm))
 if(d24>d12+1e-12_real64)error stop 'refinement not contracting'
 print '(a)','PPA_WU05A26_ZERO_RFM_LIMIT=PASS'
 print '(a)','PPA_WU05A26_TIMESTEP_REFINEMENT=PASS'
 print '(a)','PPA_WU05A26_LIVE_TRIAL_PREPARER=PASS'
end program
