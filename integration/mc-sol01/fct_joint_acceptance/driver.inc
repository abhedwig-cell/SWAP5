 ! Declarations injected into the unchanged accepted-water fixture.
 type(research_chemical_t)::chem,initial_chem,saved_chem,reference_chem,restored_chem
 type(kernel_committed_state_t)::initial_water,saved_water,reference_water,restored_water
 type(kernel_persistence_snapshot_t)::persisted
 type(research_joint_result_t)::jr,ref_result
 type(b111_reactive_solute_substep_forcing_t)::model
 type(b111_reactive_solute_substep_forcing_t),allocatable::models(:)
 type(canonical_numerical_config_t)::bad_config
 real(real64),allocatable::concentration(:)
 real(real64)::exponent,h,initial_mass,total_in,total_out,worst
 integer::nt,k,accepted,rejected
 ! BEGIN TEST BODY
 read(path,*)exponent
 h=40d0/nodes
 allocate(concentration(nodes))
 do k=1,nodes
  concentration(k)=.05d0+exp(-.5d0*((k-.5d0)*h-15d0)**2)
 end do
 call initialize_mobile_salt_state(dz,theta,concentration,chem%mobile,code)
 if(code/=SOLUTE_OK)error stop 'mobile init'
 call initialize_solute_compartment_state(.26d0*concentration**exponent*dz,0d0,0d0,0d0*theta,chem%companion,code)
 if(code/=SOLCOMP_OK)error stop 'companion init'
 chem%water=theta;chem%clock=0d0;initial_water=water;initial_chem=chem
 model%transport_scheme=B111_TRANSPORT_IMPLICIT_UPWIND
 model%temperature_active=.true.;model%temperature_c=20d0+0d0*theta;model%gampar=0d0*theta
 model%rtheta=.3d0+0d0*theta;model%bexp=1d0+0d0*theta;model%decpot=0d0*theta;model%fdepth=1d0+0d0*theta
 model%bulk_density=1.3d0+0d0*theta;model%kf=.2d0+0d0*theta;model%frexp=exponent
 model%face_distance_cm=[(h,k=1,nodes-1)];model%face_left_weight=[(.5d0,k=1,nodes-1)]
 model%face_right_weight=model%face_left_weight;model%theta_sat_left=[(.423d0,k=1,nodes-1)]
 model%dispersivity_cm=0d0*model%face_distance_cm;model%rain_c_mg_cm3=.05d0
 initial_mass=sum(chem%mobile%mass_mg_cm2)+chem%companion%solute_total()
 total_in=0d0;total_out=0d0;worst=0d0;accepted=0;rejected=0
 do i=1,4
  saved_water=water;saved_chem=chem
  ! Reference candidate establishes the actual substep count, never a mock.
  reference_water=water;reference_chem=chem
  call joint(reference_water,reference_chem,i*.1d0,ref_result)
  if(ref_result%status/=RESEARCH_JOINT_OK)then
   print *,'REFERENCE_FAILED',ref_result%status,ref_result%chemical_status,ref_result%completed,ref_result%substeps
   error stop 'reference joint'
  end if
  nt=ref_result%substeps
  if(nt<2)error stop 'no late prefix'
  if(allocated(models))deallocate(models)
  allocate(models(nt));models=model;models(nt)%decpot(1)=.01d0
  call joint(water,chem,i*.1d0,jr,models)
  if(jr%status/=RESEARCH_JOINT_CHEMICAL.or.jr%completed/=nt-1.or.any(jr%ledger/=0d0))error stop 'late rejection'
  call same_water(water,saved_water);call same_chemical(chem,saved_chem);rejected=rejected+1
  ! Wrong schedule length rejects after the real water trial, before chemistry.
  call joint(water,chem,i*.1d0,jr,models(:nt-1))
  if(jr%status/=RESEARCH_JOINT_CHEMICAL.or.jr%completed/=0)error stop 'model count rejection'
  call same_water(water,saved_water);call same_chemical(chem,saved_chem);rejected=rejected+1
  ! Actual incomplete water trial must not publish either state.
  bad_config=cfg%numerical;bad_config%max_committed_substeps=1
  call run_research_joint_fct(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water, &
   cfg%tiles(1)%base_forcing,bad_config,chem,model,i*.1d0,jr)
  if(jr%status/=RESEARCH_JOINT_WATER.or.jr%completed/=0)error stop 'water rejection'
  call same_water(water,saved_water);call same_chemical(chem,saved_chem);rejected=rejected+1
  ! Fail-closed entry mismatches do not start chemical execution.
  chem%clock=chem%clock+.01d0
  call joint(water,chem,i*.1d0,jr)
  if(jr%status/=RESEARCH_JOINT_INVALID)error stop 'clock mismatch'
  chem%clock=saved_chem%clock
  call same_water(water,saved_water);call same_chemical(chem,saved_chem);rejected=rejected+1
  chem%water(1)=chem%water(1)+.01d0
  call joint(water,chem,i*.1d0,jr)
  if(jr%status/=RESEARCH_JOINT_INVALID)error stop 'carrier mismatch'
  chem%water=saved_chem%water
  call same_water(water,saved_water);call same_chemical(chem,saved_chem);rejected=rejected+1
  call joint(water,chem,i*.1d0,jr)
  if(jr%status/=RESEARCH_JOINT_OK.or.jr%completed/=nt)error stop 'retry commit'
  call same_water(water,reference_water);call same_chemical(chem,reference_chem)
  if(any(jr%ledger/=ref_result%ledger))error stop 'retry ledger'
  print '(A,1X,3(I0,1X),4(ES25.16E3,1X))','WINDOW',i,nt,nt-1,jr%ledger
  accepted=accepted+nt;total_in=total_in+jr%ledger(1);total_out=total_out+jr%ledger(2)
  worst=max(worst,maxval(abs(jr%ledger(3:))))
  if(i==2)then
   call export_kernel_committed_state(water,cfg%tiles(1)%template%state_layout_id,persisted,ok,code)
   if(.not.ok.or.code/=KERNEL_PERSISTENCE_OK)error stop 'export checkpoint'
   restored_chem=chem
   call restore_kernel_committed_state(persisted,cfg%tiles(1)%template%state_layout_id,restored_water,ok,code)
   if(.not.ok.or.code/=KERNEL_PERSISTENCE_OK)error stop 'restore checkpoint'
   call same_water(water,restored_water);call same_chemical(chem,restored_chem)
  else if(i>2)then
   ! Fresh backend scratch cannot be necessary accepted continuation authority.
   call backend%initialize(top)
   call joint(restored_water,restored_chem,i*.1d0,ref_result)
   if(ref_result%status/=RESEARCH_JOINT_OK.or.ref_result%substeps/=nt)error stop 'checkpoint continuation'
   call same_water(water,restored_water);call same_chemical(chem,restored_chem)
   if(any(jr%ledger/=ref_result%ledger))error stop 'checkpoint ledger'
  end if
 end do
 worst=max(worst,abs(sum(chem%mobile%mass_mg_cm2)+chem%companion%solute_total()-initial_mass-total_in+total_out))
 if(worst>1d-10)error stop 'joint conservation'
 if(any(chem%mobile%mass_mg_cm2<0d0).or.any(chem%companion%sorbed_matrix_mass<0d0))error stop 'negative joint'
 print '(A,1X,3(ES25.16E3,1X))','BUDGET',initial_mass,total_in,total_out
 print '(A,1X,3(I0,1X),4(ES25.16E3,1X))','JOINT_PASS',nodes,accepted,rejected,factor,exponent,worst,chem%clock
 do k=1,nodes
  print '(A,1X,I0,1X,4(ES25.16E3,1X))','CELL',k,chem%water(k),chem%mobile%concentration_mg_cm3(k), &
   chem%mobile%mass_mg_cm2(k),chem%companion%sorbed_matrix_mass(k)
 end do
 print '(A)','LATE_CHEMICAL_WATER_REJECTION_EXACT_RETRY_AND_OPAQUE_CHECKPOINT_PASS'
contains
 subroutine joint(w,c,t,r,ms)
  type(kernel_committed_state_t),intent(inout)::w
  type(research_chemical_t),intent(inout)::c
  real(real64),intent(in)::t
  type(research_joint_result_t),intent(out)::r
  type(b111_reactive_solute_substep_forcing_t),optional,intent(in)::ms(:)
  call run_research_joint_fct(backend,column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,w, &
   cfg%tiles(1)%base_forcing,cfg%numerical,c,model,t,r,ms)
 end subroutine
 subroutine same_chemical(a,b)
  type(research_chemical_t),intent(in)::a,b
  if(a%clock/=b%clock.or.any(a%water/=b%water))error stop 'chemical clock water drift'
  if(any(a%mobile%mass_mg_cm2/=b%mobile%mass_mg_cm2).or. &
   any(a%mobile%concentration_mg_cm3/=b%mobile%concentration_mg_cm3))error stop 'mobile drift'
  if(any(a%companion%sorbed_matrix_mass/=b%companion%sorbed_matrix_mass).or. &
   any(a%companion%age_amount/=b%companion%age_amount).or. &
   a%companion%pond_mass/=b%companion%pond_mass.or.a%companion%aquifer_mass/=b%companion%aquifer_mass.or. &
   a%companion%age_pond_previous_concentration/=b%companion%age_pond_previous_concentration)error stop 'companion drift'
 end subroutine
 subroutine same_water(a,b)
  type(kernel_committed_state_t),intent(in)::a,b
  class(transaction_state_t),allocatable::p,q
  real(real64),allocatable::ha(:),hb(:)
  real(real64)::ta,tb
  logical::oa,ob
  if(a%current_revision()/=b%current_revision().or.a%current_lineage_id()/=b%current_lineage_id())error stop 'provenance drift'
  call a%current_time(ta,oa);call b%current_time(tb,ob)
  if(.not.oa.or..not.ob.or.ta/=tb)error stop 'water clock drift'
  call a%snapshot(p,oa);call b%snapshot(q,ob)
  if(.not.oa.or..not.ob)error stop 'physical snapshot'
  select type(p)
  type is(fmr_b110_temporal_indicator_state_t)
   select type(q)
   type is(fmr_b110_temporal_indicator_state_t)
    if(p%active_nodes/=q%active_nodes.or.any(p%pressure_head/=q%pressure_head).or. &
     any(p%water_content/=q%water_content).or.p%ponding_depth/=q%ponding_depth.or. &
     p%groundwater_level/=q%groundwater_level)error stop 'physical water drift'
    call p%temporal_history_snapshot(ha,oa);call q%temporal_history_snapshot(hb,ob)
    if(.not.oa.or..not.ob)error stop 'history unavailable'
    if(any(ha/=hb))error stop 'temporal history drift'
   class default
    error stop 'water type q'
   end select
  class default
   error stop 'water type p'
  end select
 end subroutine
end program
