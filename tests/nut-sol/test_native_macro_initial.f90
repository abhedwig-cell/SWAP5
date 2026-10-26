program test_native_macro_initial
 use iso_fortran_env,only:real64
 use mod_column_swp_macro_initial
 use mod_macropore_standard_storage
 use mod_macropore_continuation_state
 use mod_macropore_dynamic_shrinkage
 use mod_ppa_wu05a6_sorptivity_rate
 implicit none
 type(native_macro_initial_t)::p
 type(macropore_continuation_state_t)::before
 type(macropore_standard_storage_view_t)::v
 type(sorptivity_rate_request_t)::q
 type(sorptivity_rate_result_t)::r
 character(1024)::path
 real(real64),allocatable::old_dynamic(:),old_subsidence(:)
 real(real64)::budget
 integer::n,nd
 logical::ok
 call get_command_argument(1,path);call import_column_macro_initial(trim(path),p)
 n=p%geometry%num_nodes;nd=p%geometry%num_domains
 if(n/=112.or.nd/=5)error stop 'original dimensions'
 if(p%cutoff/=57.or.abs(p%groundwater+80.9d0)>1d-12)error stop 'original full capillary zone'
 budget=sum(p%state%water_domain_cp)
 if(budget<=1d0)error stop 'missing physical initial stocks'
 call copy_macropore_continuation_state(p%state,before,ok)
 if(.not.ok)error stop 'initial state copy'
 call canonicalize_macropore_standard_storage(p%state,1,p%z,p%geometry%dz,v,ok)
 if(.not.ok.or..not.p%state%same_values(before))error stop 'non-idempotent initialization'
 ! Independent predecessor path distinguishes the required downward initialization.
 call evaluate_dynamic_crack_profile(p%shrinkage,p%theta,p%theta,p%geometry%dz,p%matrix_fraction, &
  0d0*p%theta,old_dynamic,ok,old_subsidence,active_node=p%cutoff,top_node=1)
 if(.not.ok)error stop 'previous simultaneous profile'
 budget=maxval(abs(old_subsidence))
 block
 real(real64),allocatable::new_dynamic(:),new_subsidence(:)
 call prepare_initial_dynamic_crack_profile(p%shrinkage,p%theta,p%geometry%dz,p%matrix_fraction, &
  1,p%cutoff,new_dynamic,new_subsidence,ok)
 if(.not.ok.or.maxval(abs(old_subsidence-new_subsidence))<9d-5)error stop 'missing predecessor distinction'
 end block
 budget=sum(p%state%water_domain_cp)
 call prepare_initial_dynamic_crack_profile(p%shrinkage,p%theta,p%geometry%dz,p%matrix_fraction, &
  1,p%cutoff,old_dynamic,old_subsidence,ok)
 if(.not.ok)error stop 'initial profile'
 call prepare_initial_dynamic_crack_profile(p%shrinkage,p%theta,p%geometry%dz,p%matrix_fraction, &
  1,n+1,old_dynamic,old_subsidence,ok)
 if(ok)error stop 'invalid initial cutoff accepted'
 ! A positive amount must pass through the original zero-volume tapered tip
 ! without being lost or divided by zero. Negative capacity remains invalid.
 before%water_domain_cp(4,before%icp_bottom_domain(4))=1d-13
 call canonicalize_macropore_standard_storage(before,1,p%z,p%geometry%dz,v,ok)
 if(.not.ok.or.abs(sum(before%water_domain_cp(4,:))-1d-13)>1d-25)error stop 'wet tapered tip lost water'
 before%volume_domain_cp(4,before%icp_bottom_domain(4))=-1d-13
 call canonicalize_macropore_standard_storage(before,1,p%z,p%geometry%dz,v,ok)
 if(ok.or.before%volume_domain_cp(4,before%icp_bottom_domain(4))/=-1d-13)error stop 'negative tapered volume changed'
 call copy_macropore_continuation_state(p%state,before,ok)
 if(.not.ok)error stop 'restore initial witness'
 ! Real sorptivity owner consumes all source coefficients. Probe partial wet walls
 ! in every original layer, preserving the actual initial state separately.
 q%num_nodes=n;q%num_domains=nd;q%top_node=1;q%swmbf=1;q%matrix_top_saturated_node=n+1
 q%step_duration=1d-3;q%bottom_domain=p%geometry%potential_bottom_domain;q%top_water_node=[1,1,1,1,1]
 q%theta=.8d0*p%theta_s;q%theta_s=p%theta_s;q%theta_r=p%theta_r;q%dz=p%geometry%dz
 q%diameter=p%geometry%characteristic_diameter;q%wall_correction=1d0+0d0*p%theta
 q%sorptivity_max=p%sorptivity_max;q%sorptivity_alpha=p%sorptivity_alpha
 q%domain_fraction=p%geometry%domain_fraction
 allocate(q%wet_fraction(nd,n),q%history_sorptivity(nd,n),q%history_theta_ref(nd,n),q%history_absorption_time(nd,n))
 q%wet_fraction=.5d0;q%history_sorptivity=0d0;q%history_theta_ref=0d0;q%history_absorption_time=0d0
 call evaluate_sorptivity_rate(q,r)
 if(.not.r%valid.or.sum(r%amount_cm)<=0d0.or.any(r%amount_cm<0d0))error stop 'source sorptivity not consumed'
 if(.not.p%state%same_values(before))error stop 'preparation/consumer mutated initial state'
 if(abs(sum(p%storage%total_water_cm)-budget)>1d-12)error stop 'initial mass'
 print '(a,i0,a,i0)','ORIGINAL_MACRO_INITIAL_PRODUCTION_PASS nodes=',n,' domains=',nd
 print '(a,*(es25.17e3,1x))','ORIGINAL_MACRO_INITIAL_VALUES=',budget,sum(p%state%dynamic_volume_cp),p%rapid_kd, &
  minval(p%sorptivity_max),maxval(p%sorptivity_max),sum(r%amount_cm),sum(p%storage%total_water_cm)-budget
end program
