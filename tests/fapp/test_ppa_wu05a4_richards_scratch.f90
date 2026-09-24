program test_scratch_binding
  use, intrinsic::iso_fortran_env,only:real64,int64
  use, intrinsic::ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_reference_richards_workspace
  use mod_ppa_wu05a4_richards_scratch_binding
  use mod_ppa_wu05a4_saturated_trial
  use mod_ppa_wu05a4_trial_exchange
  use mod_ppa_wu05a4_matrix_fraction
  use mod_ppa_wu05a4_static_geometry
  use mod_ppa_wu05a4_checkpoint_input
  use mod_ppa_wu05a4_attempt
  use mod_ppa_wu05a4_reference_finish
  use mod_reference_richards_state_binding
  use mod_ppa_wu05a4_reduction_policy
  use mod_ppa_wu05a2_macropore_state
  use mod_ppa_wu05a3_interval_candidate
  use mod_ppa_wu05a3_candidate_mass
  implicit none
  type(reference_richards_workspace_t)::ws
  type(saturated_domain_inputs)::input
  type(reference_trial_transfer)::used
  type(macro_trial_key)::key
  real(real64)::storage,captured_begin,captured_end
  real(real64),allocatable::amount(:)
  integer(int64)::generation
  logical::ok
  input%z=[-0.5_real64,-1.5_real64]; input%dz=[1.0_real64,1.0_real64]
  input%volume=[0.25_real64,0.25_real64]; input%resistance_inverse=[0.25_real64,0.25_real64]
  input%matrix_top=2; input%pore_saturated_top=1; input%saturated_fraction=0.5_real64
  input%bottom=-2; input%matrix_level=-1; input%pore_level=-0.5_real64; input%storage=0.375_real64
  key=macro_trial_key(6_int64,0_int64,1_int64,1_int64)
  call initialize_reference_workspace(ws,2)
  generation=ws%generation
  ws%dfdh_main=1; ws%dfdh_lower=3; ws%dfdh_upper=4; ws%source=5; ws%sink=6
  call run(generation)
  call check(ok,1)
  call check(abs(ws%residual(2)+0.125_real64)+abs(ws%dfdh_main(2)-1.25_real64)<1.e-14_real64,2)
  call check(maxval(abs(ws%source-5))+maxval(abs(ws%sink-6))<1.e-14_real64,3)
  call check(maxval(abs(ws%dfdh_lower-3))+maxval(abs(ws%dfdh_upper-4))<1.e-14_real64,4)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,5)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,6)
  call copy_reference_budget(ws,used,key,[-0.5_real64,0.5_real64],1.0_real64, &
      amount,captured_begin,captured_end,ok)
  call check(ok,48)
  call check(abs(captured_begin-0.375_real64)+abs(captured_end-0.25_real64)<1.e-14_real64,49)
  call initialize_reference_workspace(ws,2)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),12)
  call run(generation)
  call check(.not.ok.and.maxval(abs(ws%residual))<1.e-14_real64,7)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),8)
  generation=ws%generation
  call poison_reference_workspace(ws)
  call run(generation)
  call check(.not.ok.and.ws%poisoned,9)
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,10)
  call poison_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),13)
  call reset_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,14)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,15)
  call discard_reference_transfer(used)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,16)
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  call run(generation)
  call check(ok,17)
  call reset_reference_workspace(ws)
  ws%dfdh_main=1
  input%matrix_top=-9; input%matrix_level=999
  key%evaluation=2
  call apply_saturated_reference_scratch(input,[-0.5_real64,0.25_real64],1.0_real64,key, &
      generation,.true.,ws,used,storage,ok,pond=0.0_real64)
  call check(ok,19)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,20)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,21)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,22)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,23)
  call check(input%matrix_top==-9.and.abs(input%matrix_level-999)<1.e-14_real64,24)
  key%evaluation=3
  call apply_saturated_reference_scratch(input,[-0.5_real64,-0.25_real64],1.0_real64,key, &
      generation,.true.,ws,used,storage,ok,pond=0.0_real64)
  call check(.not.ok,25)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,26)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,27)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),28)
  call reset_reference_workspace(ws)
  ws%dfdh_main=7
  key%evaluation=4
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,29)
  call check(maxval(abs(ws%dfdh_main-7))<1.e-14_real64,30)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,31)
  ! Rebuilding the ordinary Jacobian happens later. Altering physical input
  ! here must not affect the derivative already captured by the residual.
  input%resistance_inverse=99
  ws%dfdh_main=1
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(ok,32)
  call check(abs(ws%dfdh_main(2)-11.0_real64/9)<1.e-14_real64,33)
  call check(abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,34)
  ws%dfdh_main=2
  call apply_reference_trial_diagonal(ws,used,key,.false.,ok)
  call check(ok.and.maxval(abs(ws%dfdh_main-2))<1.e-14_real64,35)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(ok,36)
  call check(abs(storage-input%storage+sum(amount))<1.e-14_real64,37)
  key%evaluation=5
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.maxval(abs(ws%dfdh_main-2))<1.e-14_real64,38)
  key%evaluation=4
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),39)
  input%resistance_inverse=0.25_real64
  ws%residual=0
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,40)
  call initialize_reference_workspace(ws,2)
  ws%dfdh_main=3
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.maxval(abs(ws%dfdh_main-3))<1.e-14_real64,41)
  generation=ws%generation
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,42)
  ws%dfdh_main=[3.0_real64]
  call apply_reference_trial_diagonal(ws,used,key,.true.,ok)
  call check(.not.ok.and.abs(ws%dfdh_main(1)-3)<1.e-14_real64,43)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),44)
  ws%residual=0
  call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(ok,45)
  key%evaluation=5
  call apply_saturated_reference_residual(input,[-0.5_real64,-0.25_real64],0.0_real64,1.0_real64, &
      key,generation,ws,used,storage,ok)
  call check(.not.ok.and.abs(ws%residual(2)+1.0_real64/6)<1.e-14_real64,46)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok.and..not.allocated(amount),47)
  call release_reference_workspace(ws)
  call copy_reference_transfer(ws,used,key,amount,ok)
  call check(.not.ok,18)
  call run(generation)
  call check(.not.ok,11)
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_BINDING=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_SCRATCH_GENERATION_POISON=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_TRANSFER_LIFETIME=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_HEAD_DERIVED_ASSEMBLY=PASS'
  print '(a)','PPA_WU05A4_REFERENCE_SPLIT_CALLBACKS=PASS'
  call nonlinear_callback_sequence()
  call interval_handoff()
  call check_matrix_fraction()
  call check_static_geometry()
  call check_checkpoint_input()
  call check_attempt_lifecycle()
  print '(a)','PPA_WU05A4_STATIC_ATTEMPT_LIFECYCLE=PASS'
  print '(a)','PPA_WU05A4_CHECKPOINT_DERIVED_INPUT=PASS'
  print '(a)','PPA_WU05A4_STATIC_GEOMETRY_COMPOSITION=PASS'
  call check_reduction_policy()
  call check_reduction_composition()
  print '(a)','PPA_WU05A4_REDUCTION_BEFORE_STORAGE_LIMIT=PASS'
  print '(a)','PPA_WU05A4_REDUCTION_POLICY=PASS'
  call coupled_storage_check()
  call closed_attempt_check()
  print '(a)','PPA_WU05A4_CLOSED_ATTEMPT_STORAGE_GUARD=PASS'
  print '(a)','PPA_WU05A4_LINEAR_MATRIX_MACRO_STORAGE_BALANCE=PASS'
  print '(a)','PPA_WU05A4_STATIC_MATRIX_FRACTION=PASS'
  print '(a)','PPA_WU05A4_USED_TRANSFER_INTERVAL_HANDOFF=PASS'
  print '(a)','PPA_WU05A4_REDUCED_NONLINEAR_CALLBACK_RETRY=PASS'
contains
  subroutine closed_attempt_check()
    type(static_macro_attempt)::attempt
    type(static_macro_geometry)::geometry
    type(ppa_wu05a2_macropore_checkpoint_t)::cp
    type(ppa_wu05a2_macropore_candidate_t)::candidate
    type(candidate_mass_account)::account
    type(reference_richards_workspace_t),allocatable::scratch
    type(reference_richards_state_binding_t)::final_state
    real(real64)::h,dt,capacity,theta(2),bad_theta(2),faces(3),source(2),sink(2),root(2),external
    integer::j,k,mode
    logical::valid,converged
    call ppa_wu05a2_initialize_payload(1,2,cp%payload,valid)
    call check(valid,300)
    cp%lineage_id=96; cp%revision=0; cp%payload%bottom_domain=2
    cp%payload%pore_volume=0.25_real64; cp%payload%domain_water_storage=0.375_real64
    cp%payload%pore_water(1,:)=[0.125_real64,0.25_real64]
    allocate(scratch)
    call initialize_reference_workspace(scratch,2)
    final_state%active_nodes=2
    allocate(final_state%h(2),final_state%theta(2),final_state%hm1(2),final_state%thetm1(2), &
        final_state%k(2),final_state%kmean(3),final_state%dimoca(2),final_state%itnumb(100,2))
    final_state%hm1=0; final_state%k=1; final_state%dimoca=0; final_state%itnumb=0
    do j=1,3
      dt=0.5_real64*2.0_real64**(j-1)
      do mode=0,15
        scratch%unsaturated_flags=.false.
        call begin_static_attempt(cp,input%z,input%dz,input%volume,[1.0_real64,1.0_real64], &
            input%resistance_inverse,dt,int(10*j+mode,int64),0,scratch,attempt,geometry,valid)
        call check(valid,301)
        capacity=geometry%matrix_fraction(2)*input%dz(2)
        faces=[-0.1_real64,-0.06_real64,-0.02_real64]
        source=[0.03_real64,0.01_real64]; sink=[0.01_real64,0.02_real64]; root=0.005_real64
        external=0
        if(mode>=5)external=0.08_real64*dt
        h=0.25_real64; converged=.false.
        do k=1,100
          scratch%residual=[0.0_real64,capacity*(h-0.2_real64)/dt]
          if(mode>=5)scratch%residual(2)=scratch%residual(2)-0.025_real64
          call evaluate_static_attempt(attempt,scratch,[-0.5_real64,h],0.0_real64,valid)
          call check(valid,302)
          if(abs(scratch%residual(2))<1.e-13_real64)then
            converged=.true.; exit
          end if
          scratch%dfdh_main=capacity/dt
          call diagonal_static_attempt(attempt,scratch,[-0.5_real64,h],.true.,valid)
          call check(valid,303)
          h=h-scratch%residual(2)/scratch%dfdh_main(2)
        end do
        call check(converged,304)
        ! Independent manufactured constitutive law, theta(h)=h in cell 2.
        theta=[0.2_real64,h]
        if(mode>=5)theta(1)=0.2_real64+0.055_real64*dt/capacity
        bad_theta=theta
        select case(mode)
        case(1)
          bad_theta(2)=theta(2)+0.01_real64
        case(2)
          ! Total unchanged, but wrong per-cell allocation must still fail.
          bad_theta=theta+[0.01_real64,-0.01_real64]
        case(3)
          bad_theta(1)=ieee_value(0.0_real64,ieee_quiet_nan)
        case(4)
          bad_theta(1)=-0.1_real64
        end select
        if(mode==5.or.mode>=11)then
          final_state%h=[-0.5_real64,h]; final_state%thetm1=0.2_real64
          final_state%theta=theta; final_state%qtop=faces(1); final_state%qbot=faces(3)
          final_state%kmean=1; final_state%ftoph=.false.
          scratch%head_gradient=-faces
          scratch%source=source; scratch%sink=sink; scratch%provider_root_sink=root
          ! Poison unrelated scratch to prove it is not a face-flux authority.
          scratch%vertical_flux=ieee_value(0.0_real64,ieee_quiet_nan)
          if(mode==11)final_state%ftoph=.true.
          if(mode==12)scratch%head_gradient(2)=-scratch%head_gradient(2)
          if(mode==13)scratch%unsaturated_flags(3)=.true.
          if(mode==14)final_state%kmean(2)=-1
          if(mode==15)final_state%h(2)=h+0.01_real64
          call finish_reference_static_attempt(attempt,scratch,final_state,1.e-12_real64,candidate,account,valid)
        else if(mode>=5)then
          if(mode==6)faces=-faces
          if(mode==7)faces(2)=faces(2)+0.01_real64 ! unchanged external total
          if(mode==8)source(2)=source(2)+0.01_real64 ! duplicated input
          if(mode==9)sink(1)=-0.01_real64
          if(mode==10)faces(1)=ieee_value(0.0_real64,ieee_quiet_nan)
          call finish_matrix_static_attempt(attempt,scratch,[-0.5_real64,h],[0.2_real64,0.2_real64], &
              bad_theta,faces,source,sink,root,1.e-12_real64,candidate,account,valid)
        else
          call finish_closed_static_attempt(attempt,scratch,[-0.5_real64,h],[0.2_real64,0.2_real64], &
              bad_theta,1.e-12_real64,candidate,account,valid)
        end if
        if(mode==0.or.mode==5)then
          call check(valid.and.candidate%valid.and.account%valid,305)
          call check(abs(sum((theta-0.2_real64)*geometry%matrix_fraction*input%dz) &
              +candidate%payload%domain_water_storage(1)-0.375_real64-external)<1.e-12_real64,306)
        else
          call check(.not.valid.and..not.candidate%valid.and..not.account%valid,307)
        end if
        call finish_closed_static_attempt(attempt,scratch,[-0.5_real64,h],[0.2_real64,0.2_real64], &
            theta,1.e-12_real64,candidate,account,valid)
        call check(.not.valid,308)
      end do
    end do
    call check(abs(cp%payload%domain_water_storage(1)-0.375_real64)<tiny(1.0_real64),309)
    call release_reference_workspace(scratch)
  end subroutine

  subroutine check_attempt_lifecycle()
    type(static_macro_attempt)::attempt
    type(static_macro_geometry)::geometry
    type(ppa_wu05a2_macropore_checkpoint_t)::cp
    type(ppa_wu05a2_macropore_candidate_t)::candidate
    type(candidate_mass_account)::account
    type(reference_richards_workspace_t)::local_ws
    real(real64)::z(2),dz(2),volume(2),diameter(2),resistance(2),head(2),first_store
    logical::valid
    z=[-0.5_real64,-1.5_real64]; dz=1; volume=0.25_real64; diameter=1; resistance=0.25_real64
    head=[-0.5_real64,0.25_real64]
    call ppa_wu05a2_initialize_payload(1,2,cp%payload,valid)
    call check(valid,260)
    cp%lineage_id=91; cp%revision=0; cp%payload%bottom_domain=2
    cp%payload%pore_volume=0.25_real64; cp%payload%domain_water_storage=0.375_real64
    cp%payload%pore_water(1,:)=[0.125_real64,0.25_real64]
    call initialize_reference_workspace(local_ws,2)
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,1.0_real64,1_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid.and.geometry%valid,261)
    ! Caller-side mutations cannot change the captured beginning state.
    cp%payload%domain_water_storage=0.1_real64
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(valid,262)
    local_ws%dfdh_main=1
    call diagonal_static_attempt(attempt,local_ws,head,.true.,valid)
    call check(valid,263)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(valid.and.candidate%valid.and.account%valid,264)
    first_store=candidate%payload%domain_water_storage(1)
    call check(abs(first_store-5.0_real64/24)<1.e-14_real64,265)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid.and..not.account%valid,266)
    cp%payload%domain_water_storage=0.375_real64
    ! Discard and changed-dt retry always start from the same checkpoint.
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,1.0_real64,2_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,267)
    local_ws%residual=0
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(valid,268)
    call discard_static_attempt(attempt)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid,269)
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.1_real64,3_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,270)
    local_ws%residual=0
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(valid,271)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(valid,272)
    call check(abs(candidate%payload%domain_water_storage(1)-0.35625_real64)<1.e-14_real64,273)
    ! Changed heads replace the last capture; finishing with old heads rejects.
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.1_real64,4_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,274)
    local_ws%residual=0
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(valid,275)
    local_ws%residual=0
    call evaluate_static_attempt(attempt,local_ws,[-0.5_real64,0.1_real64],0.0_real64,valid)
    call check(valid,276)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid,277)
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(.not.valid,278)
    ! Invalid begin must clear previous state, and cannot publish geometry.
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.0_real64,5_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(.not.valid.and..not.geometry%valid,279)
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.1_real64,6_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,280)
    local_ws%dfdh_main=7
    call diagonal_static_attempt(attempt,local_ws,head,.true.,valid)
    call check(.not.valid.and.maxval(abs(local_ws%dfdh_main-7))<tiny(1.0_real64),281)
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(.not.valid,282)
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.1_real64,7_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,283)
    call initialize_reference_workspace(local_ws,2)
    local_ws%residual=8
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(.not.valid.and.maxval(abs(local_ws%residual-8))<tiny(1.0_real64),284)
    call begin_static_attempt(cp,z,dz,volume,diameter,resistance,0.1_real64,8_int64,0, &
        local_ws,attempt,geometry,valid)
    call check(valid,285)
    local_ws%residual=0
    call evaluate_static_attempt(attempt,local_ws,head,0.0_real64,valid)
    call check(valid,286)
    call diagonal_static_attempt(attempt,local_ws,[-0.5_real64,0.1_real64],.true.,valid)
    call check(.not.valid,287)
    call finish_static_attempt(attempt,local_ws,head,1.e-12_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid,288)
    call release_reference_workspace(local_ws)
  end subroutine

  subroutine check_checkpoint_input()
    type(ppa_wu05a2_macropore_checkpoint_t)::cp,bad_cp
    type(saturated_domain_inputs)::derived
    type(static_macro_geometry)::geometry
    type(reference_richards_workspace_t)::local_ws
    type(reference_trial_transfer)::transfer
    type(ppa_wu05a2_macropore_candidate_t)::candidate
    type(candidate_mass_account)::account
    real(real64)::candidate_storage
    real(real64)::centers(2),resistance(2),volume(2),diameter(2)
    integer::case_id
    logical::valid
    call ppa_wu05a2_initialize_payload(1,2,cp%payload,valid)
    call check(valid,230)
    cp%lineage_id=key%lineage; cp%revision=key%revision
    cp%payload%bottom_domain=2
    cp%payload%pore_volume=0.25_real64
    cp%payload%domain_water_storage=0.375_real64
    cp%payload%pore_water(1,:)=[0.125_real64,0.25_real64]
    call prepare_static_checkpoint_input(cp,[-0.5_real64,-1.5_real64],[1.0_real64,1.0_real64], &
        [0.25_real64,0.25_real64],[1.0_real64,1.0_real64],[0.25_real64,0.25_real64],derived,geometry,valid)
    call check(valid.and.geometry%valid,231)
    call check(derived%pore_saturated_top==1.and.derived%matrix_top==0,232)
    call check(abs(derived%pore_level+0.5_real64)+abs(derived%saturated_fraction-0.5_real64)<1.e-14_real64,233)
    call initialize_reference_workspace(local_ws,2)
    call apply_saturated_reference_residual(derived,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
        key,local_ws%generation,local_ws,transfer,candidate_storage,valid)
    call check(valid,234)
    call prepare_reference_interval(local_ws,transfer,key,[-0.5_real64,0.25_real64],1.0_real64, &
        cp,1.e-12_real64,candidate,account,valid)
    call check(valid.and.candidate%valid,235)
    call check(abs(candidate_storage-5.0_real64/24)<1.e-14_real64,236)
    call check(abs(cp%payload%domain_water_storage(1)-0.375_real64)<1.e-14_real64,237)
    ! Same total but incompatible vertical distribution is not silently rebuilt.
    cp%payload%pore_water(1,:)=[0.25_real64,0.125_real64]
    call prepare_static_checkpoint_input(cp,[-0.5_real64,-1.5_real64],[1.0_real64,1.0_real64], &
        [0.25_real64,0.25_real64],[1.0_real64,1.0_real64],[0.25_real64,0.25_real64],derived,geometry,valid)
    call check(.not.valid.and..not.geometry%valid.and..not.allocated(derived%volume),238)
    cp%payload%pore_water(1,:)=[0.0_real64,0.25_real64]
    cp%payload%domain_water_storage=0.25_real64
    call prepare_static_checkpoint_input(cp,[-0.5_real64,-1.5_real64],[1.0_real64,1.0_real64], &
        [0.25_real64,0.25_real64],[1.0_real64,1.0_real64],[0.25_real64,0.25_real64],derived,geometry,valid)
    call check(valid.and.derived%pore_saturated_top==2,239)
    call check(abs(derived%pore_level+1)+abs(derived%saturated_fraction-1)<1.e-14_real64,240)
    do case_id=1,8
      bad_cp=cp; centers=[-0.5_real64,-1.5_real64]
      resistance=0.25_real64; volume=0.25_real64; diameter=1
      select case(case_id)
      case(1)
        bad_cp%lineage_id=0
      case(2)
        bad_cp%payload%bottom_domain=1
      case(3)
        centers(2)=-2
      case(4)
        resistance(1)=ieee_value(0.0_real64,ieee_quiet_nan)
      case(5)
        volume(1)=0.3_real64
      case(6)
        diameter(1)=0
      case(7)
        bad_cp%payload%domain_water_storage=0.6_real64
      case(8)
        deallocate(bad_cp%payload%pore_water)
      end select
      call prepare_static_checkpoint_input(bad_cp,centers,[1.0_real64,1.0_real64],volume,diameter, &
          resistance,derived,geometry,valid)
      call check(.not.valid.and..not.geometry%valid.and..not.allocated(derived%volume),240+case_id)
    end do
    call release_reference_workspace(local_ws)
  end subroutine

  subroutine check_static_geometry()
    type(static_macro_geometry)::geometry
    logical::valid
    call prepare_static_macro_geometry([0.25_real64,0.5_real64],[1.0_real64,1.0_real64], &
        [1.0_real64,1.0_real64],geometry,valid)
    call check(valid.and.geometry%valid,220)
    call check(maxval(abs(geometry%matrix_fraction-[0.75_real64,0.5_real64]))<1.e-14_real64,221)
    call check(abs(geometry%surface_fraction-0.25_real64)+abs(geometry%capacity-1000)<1.e-14_real64,222)
    call prepare_static_macro_geometry([0.8_real64],[1.0_real64],[1.0_real64],geometry,valid)
    call check(valid,223)
    ! Surface cap must not be substituted for the matrix volume fraction.
    call check(abs(geometry%surface_fraction-0.6_real64)+abs(geometry%matrix_fraction(1)-0.2_real64) &
        <1.e-14_real64,224)
    call prepare_static_macro_geometry([1.e-5_real64],[1.0_real64],[1.0_real64],geometry,valid)
    call check(valid.and.abs(geometry%surface_fraction)<tiny(1.0_real64),225)
    call prepare_static_macro_geometry([0.25_real64],[1.0_real64],[0.0_real64],geometry,valid)
    call check(.not.valid.and..not.geometry%valid.and..not.allocated(geometry%matrix_fraction),226)
  end subroutine

  subroutine check_reduction_composition()
    type(exchange_reduction_history)::history,proposal
    type(saturated_domain_inputs)::trial_input
    type(macro_exchange_evaluation)::evaluation
    type(macro_trial_key)::identity
    real(real64)::rate,store
    logical::valid
    integer::j
    trial_input=input
    do j=0,3
      if(j>0)then
        call propose_exchange_retry(history,100.0_real64,proposal,valid)
        call check(valid,210)
        history=proposal
      end if
      trial_input%reduction_decades=history%decades
      identity=macro_trial_key(96_int64,0_int64,int(j+1,int64),1_int64)
      call prepare_saturated_from_heads(trial_input,[-0.5_real64,0.25_real64],0.0_real64, &
          100.0_real64,identity,evaluation,store,valid)
      call check(valid,211)
      ! Long dt: storage cap stays active at levels 0,1,2, then releases at 3.
      rate=min(0.1875_real64*0.1_real64**real(j,real64), &
          (0.375_real64-5.0_real64/24.0_real64)/100.0_real64)
      call check(abs(evaluation%rate(2)-rate)<1.e-14_real64,212)
      call check(abs(evaluation%derivative(2)+rate/0.75_real64)<1.e-14_real64,213)
      call check(abs(store-0.375_real64+rate*100.0_real64)<1.e-13_real64,214)
      call check(abs(input%storage-0.375_real64)<1.e-14_real64.and.input%reduction_decades==0,215)
    end do
    ! Recovery proposal changes future trials only, not the last captured rate.
    call propose_exchange_recovery(history,101.0_real64,proposal,valid)
    call check(valid.and.proposal%decades==2.and.history%decades==3,216)
    call check(abs(evaluation%rate(2)-rate)<1.e-14_real64,217)
  end subroutine

  subroutine check_reduction_policy()
    type(exchange_reduction_history)::history,proposal
    logical::valid
    integer::j
    do j=1,3
      call propose_exchange_retry(history,0.1_real64,proposal,valid)
      call check(valid.and.proposal%decades==j.and.proposal%reduced_retry,200)
      call check(history%decades==j-1,201)
      history=proposal
    end do
    call propose_exchange_retry(history,0.1_real64,proposal,valid)
    call check(.not.valid.and.history%decades==3,202)
    do j=1,9
      call propose_exchange_recovery(history,0.1_real64,proposal,valid)
      call check(valid.and.proposal%decades==3.and.proposal%steps==j,203)
      call check(.not.proposal%reduced_retry,204)
      history=proposal
    end do
    call propose_exchange_recovery(history,0.1_real64,proposal,valid)
    call check(valid.and.proposal%decades==2.and.proposal%steps==0,205)
    history=proposal
    call propose_exchange_recovery(history,0.2_real64,proposal,valid)
    call check(valid.and.proposal%decades==1.and.proposal%steps==0,206)
    call check(abs(proposal%previous_dt-0.2_real64)<tiny(1.0_real64),207)
    history%decades=-1
    call propose_exchange_retry(history,0.1_real64,proposal,valid)
    call check(.not.valid,208)
    history=exchange_reduction_history()
    call propose_exchange_recovery(history,ieee_value(0.0_real64,ieee_quiet_nan),proposal,valid)
    call check(.not.valid,209)
  end subroutine

  ! Closed exchange with a manufactured linear matrix storage law, no vertical
  ! flow. Exercises physical volume weighting but is NOT full Richards.
  subroutine coupled_storage_check()
    type(reference_richards_workspace_t),allocatable::scratch
    type(reference_trial_transfer)::capture
    type(macro_trial_key)::identity
    real(real64),allocatable::fraction(:),transfer(:)
    real(real64)::h,dt,capacity,store,initial_store,final_store,matrix_change
    logical::valid,converged
    integer::j,k
    allocate(scratch)
    call initialize_reference_workspace(scratch,2)
    call static_matrix_fraction([0.25_real64,0.25_real64],input%dz,fraction,valid)
    call check(valid,190)
    capacity=fraction(2)*input%dz(2) ! dtheta/dh = 1 for this test law
    do j=1,3
      dt=0.5_real64*2.0_real64**(j-1)
      h=0.25_real64; converged=.false.
      identity=macro_trial_key(95_int64,0_int64,int(j,int64),1_int64)
      do k=1,100
        identity%evaluation=int(k,int64)
        scratch%residual=[0.0_real64,capacity*(h-0.2_real64)/dt]
        call apply_saturated_reference_residual(input,[-0.5_real64,h],0.0_real64,dt, &
            identity,scratch%generation,scratch,capture,store,valid)
        call check(valid,191)
        if(abs(scratch%residual(2))<1.e-13_real64)then
          converged=.true.; exit
        end if
        scratch%dfdh_main=capacity/dt
        call apply_reference_trial_diagonal(scratch,capture,identity,.true.,valid,[-0.5_real64,h])
        call check(valid,192)
        h=h-scratch%residual(2)/scratch%dfdh_main(2)
      end do
      call check(converged,193)
      call copy_reference_budget(scratch,capture,identity,[-0.5_real64,h],dt, &
          transfer,initial_store,final_store,valid)
      call check(valid,194)
      matrix_change=capacity*(h-0.2_real64)
      call check(abs(matrix_change-sum(transfer))<3.e-13_real64,195)
      call check(abs(matrix_change+final_store-initial_store)<3.e-13_real64,196)
      ! Omitting the static-pore fraction would measurably violate this balance.
      call check(abs(input%dz(2)*(h-0.2_real64)+final_store-initial_store)>1.e-3_real64,197)
      call discard_reference_transfer(capture)
    end do
    call release_reference_workspace(scratch)
  end subroutine

  subroutine check_matrix_fraction()
    real(real64),allocatable::fraction(:)
    logical::valid
    call static_matrix_fraction([0.0_real64,0.5_real64,1.0_real64], &
        [1.0_real64,2.0_real64,1.0_real64],fraction,valid)
    call check(valid,180)
    call check(maxval(abs(fraction-[1.0_real64,0.75_real64,0.0_real64]))<tiny(1.0_real64),181)
    call static_matrix_fraction([1.1_real64],[1.0_real64],fraction,valid)
    call check(.not.valid.and..not.allocated(fraction),182)
    call static_matrix_fraction([0.0_real64],[0.0_real64],fraction,valid)
    call check(.not.valid.and..not.allocated(fraction),183)
    call static_matrix_fraction([-0.1_real64],[1.0_real64],fraction,valid)
    call check(.not.valid.and..not.allocated(fraction),184)
    call static_matrix_fraction([0.1_real64],[1.0_real64,1.0_real64],fraction,valid)
    call check(.not.valid.and..not.allocated(fraction),185)
    call static_matrix_fraction([ieee_value(0.0_real64,ieee_quiet_nan)],[1.0_real64],fraction,valid)
    call check(.not.valid.and..not.allocated(fraction),186)
  end subroutine

  subroutine interval_handoff()
    type(ppa_wu05a2_macropore_committed_t)::initial,continued,restored
    type(ppa_wu05a2_macropore_restart_t)::restart
    type(ppa_wu05a2_macropore_checkpoint_t)::restored_checkpoint
    type(ppa_wu05a2_macropore_candidate_t)::replayed
    type(saturated_domain_inputs)::next_input
    type(static_macro_geometry)::next_geometry
    type(ppa_wu05a2_macropore_checkpoint_t)::checkpoint
    type(ppa_wu05a2_macropore_candidate_t)::candidate
    type(candidate_mass_account)::account
    type(reference_richards_workspace_t),allocatable::scratch
    type(reference_trial_transfer)::capture
    type(macro_trial_key)::identity
    real(real64),allocatable::matrix(:),faces(:,:),balance(:)
    real(real64)::start_store,end_store,diagnostic,exchange(1,2),volume(1,2)
    logical::valid
    integer::status
    allocate(scratch)
    call initialize_reference_workspace(scratch,2)
    call ppa_wu05a2_initialize_payload(1,2,initial%payload,valid)
    call check(valid,130)
    initial%lineage_id=81; initial%revision=0
    initial%payload%bottom_domain=2
    initial%payload%pore_volume=0.25_real64
    initial%payload%pore_water(1,:)=[0.125_real64,0.25_real64]
    initial%payload%domain_water_storage=0.375_real64
    call ppa_wu05a2_capture_checkpoint(initial,checkpoint,valid)
    call check(valid,131)
    identity=macro_trial_key(81_int64,0_int64,1_int64,1_int64)
    call apply_saturated_reference_residual(input,[-0.5_real64,0.25_real64],0.0_real64,1.0_real64, &
        identity,scratch%generation,scratch,capture,diagnostic,valid)
    call check(valid,132)
    call copy_reference_budget(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
        matrix,start_store,end_store,valid)
    call check(valid,133)
    volume=0.25_real64; exchange(1,:)=matrix ! dt = 1 day
    call prepare_macropore_interval_candidate(checkpoint,1.0_real64,volume,[0.0_real64],[0.0_real64], &
        exchange,[0.0_real64,0.0_real64],input%dz,[-2.0_real64],1.e-13_real64, &
        candidate,faces,balance,status)
    call check(status==0.and.candidate%valid,134)
    call check(abs(candidate%payload%domain_water_storage(1)-end_store)<1.e-13_real64,135)
    call check(abs(sum(candidate%payload%pore_water)-end_store)<1.e-13_real64,136)
    call account_candidate_mass(checkpoint,candidate,1.0_real64,[0.0_real64],exchange, &
        [0.0_real64,0.0_real64],matrix,1.e-13_real64,account,status)
    call check(status==0.and.account%valid,137)
    ! A mismatched transfer must not pass the accounting seam.
    matrix(1)=matrix(1)+0.01_real64
    call account_candidate_mass(checkpoint,candidate,1.0_real64,[0.0_real64],exchange, &
        [0.0_real64,0.0_real64],matrix,1.e-13_real64,account,status)
    call check(status/=0.and..not.account%valid,138)
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
        checkpoint,1.e-13_real64,candidate,account,valid)
    call check(valid.and.candidate%valid.and.account%valid,140)
    call check(abs(candidate%payload%domain_water_storage(1)-end_store)<1.e-13_real64,141)
    checkpoint%revision=1
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
        checkpoint,1.e-13_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid.and..not.account%valid,142)
    checkpoint%revision=0
    checkpoint%payload%pore_water(1,:)=[0.25_real64,0.125_real64]
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
        checkpoint,1.e-13_real64,candidate,account,valid)
    call check(.not.valid.and..not.candidate%valid,143)
    checkpoint%payload%pore_water(1,:)=[0.125_real64,0.25_real64]
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
        checkpoint,1.e-13_real64,candidate,account,valid)
    call check(valid,144)
    call bridge_rejection_checks(scratch,capture,identity,checkpoint,candidate,account)
    ! Isolated DTO commit/restart only, not a joint Richards physical commit.
    continued=initial
    call ppa_wu05a2_commit_candidate(candidate,continued,valid)
    call check(valid,145)
    call ppa_wu05a2_export_restart(continued,restart,valid)
    call check(valid,146)
    call ppa_wu05a2_restore_restart(restart,restored,valid)
    call check(valid,147)
    call ppa_wu05a2_capture_checkpoint(continued,checkpoint,valid)
    call check(valid,148)
    call ppa_wu05a2_capture_checkpoint(restored,restored_checkpoint,valid)
    call check(valid,149)
    call prepare_static_checkpoint_input(checkpoint,input%z,input%dz,input%volume, &
        [1.0_real64,1.0_real64],input%resistance_inverse,next_input,next_geometry,valid)
    call check(valid.and.next_input%pore_saturated_top==2,249)
    identity%revision=continued%revision; identity%attempt=2; identity%evaluation=1
    scratch%residual=0
    call apply_saturated_reference_residual(next_input,[-0.5_real64,0.1_real64],0.0_real64,1.0_real64, &
        identity,scratch%generation,scratch,capture,diagnostic,valid)
    call check(valid,150)
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.1_real64],1.0_real64, &
        checkpoint,1.e-13_real64,candidate,account,valid)
    call check(valid,151)
    call discard_reference_transfer(capture)
    call reset_reference_workspace(scratch)
    call prepare_static_checkpoint_input(restored_checkpoint,input%z,input%dz,input%volume, &
        [1.0_real64,1.0_real64],input%resistance_inverse,next_input,next_geometry,valid)
    call check(valid,250)
    call apply_saturated_reference_residual(next_input,[-0.5_real64,0.1_real64],0.0_real64,1.0_real64, &
        identity,scratch%generation,scratch,capture,diagnostic,valid)
    call check(valid,152)
    call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.1_real64],1.0_real64, &
        restored_checkpoint,1.e-13_real64,replayed,account,valid)
    call check(valid,153)
    call check(maxval(abs(candidate%payload%pore_water-replayed%payload%pore_water))<tiny(1.0_real64),154)
    call check(maxval(abs(candidate%payload%domain_water_storage-replayed%payload%domain_water_storage)) &
        <tiny(1.0_real64),155)
    call ppa_wu05a2_discard_candidate(replayed)
    call ppa_wu05a2_discard_candidate(candidate)
    call check(initial%revision==0.and.abs(initial%payload%domain_water_storage(1)-start_store)<1.e-14_real64,139)
    call release_reference_workspace(scratch)
  end subroutine
    subroutine bridge_rejection_checks(scratch,capture,identity,checkpoint,candidate,account)
      type(reference_richards_workspace_t),intent(in)::scratch
      type(reference_trial_transfer),intent(inout)::capture
      type(macro_trial_key),intent(in)::identity
      type(ppa_wu05a2_macropore_checkpoint_t),intent(in)::checkpoint
      type(ppa_wu05a2_macropore_candidate_t),intent(in)::candidate
      type(candidate_mass_account),intent(in)::account
      type(ppa_wu05a2_macropore_checkpoint_t)::bad
      type(ppa_wu05a2_macropore_candidate_t)::rejected
      type(candidate_mass_account)::bad_account
      real(real64)::tol
      integer::case_id
      logical::valid
      do case_id=1,7
        bad=checkpoint; tol=1.e-13_real64
        select case(case_id)
        case(1)
          bad%lineage_id=checkpoint%lineage_id+1
        case(2)
          bad%payload%domain_water_storage=0.4_real64
        case(3)
          bad%payload%pore_volume(1,1)=0.3_real64
        case(4)
          bad%payload%bottom_domain=1
        case(5)
          deallocate(bad%payload%pore_water)
        case(6)
          tol=-1
        case(7)
          tol=ieee_value(0.0_real64,ieee_quiet_nan)
        end select
        rejected=candidate; bad_account=account
        call prepare_reference_interval(scratch,capture,identity,[-0.5_real64,0.25_real64],1.0_real64, &
            bad,tol,rejected,bad_account,valid)
        call check(.not.valid.and..not.rejected%valid.and..not.bad_account%valid,160+case_id)
      end do
    end subroutine

  ! Manufactured scalar matrix residual, NOT the full Richards equation.
  ! The macro part is the real bounded evaluator, including head-derived caps.
  subroutine nonlinear_callback_sequence()
    type(reference_richards_workspace_t),allocatable::trial_ws
    type(reference_trial_transfer)::capture
    type(macro_trial_key)::trial_key,old_key
    real(real64)::h,dt,q,expected,trial_store,step,trial_h,alpha,base_norm,begin_store,end_store
    real(real64),allocatable::transfer(:)
    logical::valid,converged,accepted
    integer::attempt,iteration,backtrack,rejections
    allocate(trial_ws)
    call initialize_reference_workspace(trial_ws,2)
    do attempt=1,3
      dt=0.5_real64*2.0_real64**(attempt-1)
      trial_key=macro_trial_key(7_int64,0_int64,int(attempt,int64),1_int64)
      call discard_reference_transfer(capture)
      ! A rejected head trial must not advance the immutable beginning store.
      trial_ws%residual=0
      call apply_saturated_reference_residual(input,[-0.5_real64,-0.25_real64],0.0_real64,dt, &
          trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
      call check(.not.valid,101)
      h=0.25_real64; converged=.false.; rejections=0
      do iteration=1,100
        trial_key%evaluation=trial_key%evaluation+1
        trial_ws%residual=[0.0_real64,h-0.2_real64]
        call apply_saturated_reference_residual(input,[-0.5_real64,h],0.0_real64,dt, &
            trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
        call check(valid,102)
        ! Independent analytic rate for this grid: Darcy outflow, limited by
        ! initial store minus the head-derived groundwater inventory.
        q=min(0.25_real64*(1-h),0.125_real64/((h+0.5_real64)*dt))
        call check(abs(trial_ws%residual(2)-(h-0.2_real64-q))<1.e-14_real64,103)
        if(abs(trial_ws%residual(2))<1.e-12_real64)then
          converged=.true.; exit
        end if
        trial_ws%dfdh_main=1
        call apply_reference_trial_diagonal(trial_ws,capture,trial_key,.true.,valid,[-0.5_real64,h])
        call check(valid,104)
        step=trial_ws%residual(2)/trial_ws%dfdh_main(2)
        base_norm=abs(trial_ws%residual(2))
        ! Deliberately overrelax to exercise rejection of valid evaluations,
        ! then damp. This is a test driver, not HeadCalc's line-search policy.
        alpha=8; accepted=.false.
        do backtrack=1,12
          trial_h=h-alpha*step
          trial_key%evaluation=trial_key%evaluation+1
          trial_ws%residual=[0.0_real64,trial_h-0.2_real64]
          call apply_saturated_reference_residual(input,[-0.5_real64,trial_h],0.0_real64,dt, &
              trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
          if(valid)then
            if(abs(trial_ws%residual(2))<0.5_real64*base_norm)then
              accepted=.true.; h=trial_h; exit
            end if
          end if
          rejections=rejections+1
          call discard_reference_transfer(capture)
          call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid)
          call check(.not.valid.and..not.allocated(transfer),117)
          call check(abs(input%storage-0.375_real64)<1.e-14_real64,118)
          alpha=alpha*0.5_real64
        end do
        call check(accepted,119)
      end do
      call check(converged,105)
      call check(rejections>0,120)
      if(attempt==1)then
        expected=0.36_real64
      else
        expected=(-0.3_real64+sqrt(0.49_real64+0.5_real64/dt))/2
      end if
      call check(abs(h-expected)<2.e-12_real64,106)
      ! Account the last residual's actual captured amount; no reevaluation.
      call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid,[-0.5_real64,h],dt)
      call check(valid,107)
      call check(abs(sum(transfer)-q*dt)<1.e-14_real64,108)
      call check(abs(trial_store-input%storage+sum(transfer))<1.e-14_real64,109)
      input%storage=999
      call copy_reference_budget(trial_ws,capture,trial_key,[-0.5_real64,h],dt, &
          transfer,begin_store,end_store,valid)
      input%storage=0.375_real64
      call check(valid,121)
      call check(abs(begin_store-input%storage)+abs(end_store-trial_store)<1.e-14_real64,122)
      call check(abs(end_store-begin_store+sum(transfer))<1.e-14_real64,123)
      call check(abs(input%storage-0.375_real64)<1.e-14_real64,110)
      old_key=trial_key
      old_key%attempt=old_key%attempt+1
      call copy_reference_transfer(trial_ws,capture,old_key,transfer,valid)
      call check(.not.valid.and..not.allocated(transfer),111)
      ! Reusing a key with changed heads must not consume a stale tangent.
      trial_ws%dfdh_main=1
      call apply_reference_trial_diagonal(trial_ws,capture,trial_key,.true.,valid,[-0.5_real64,h+0.01_real64])
      call check(.not.valid.and.maxval(abs(trial_ws%dfdh_main-1))<1.e-14_real64,112)
      call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid)
      call check(.not.valid.and..not.allocated(transfer),113)
      trial_ws%residual=[0.0_real64,h-0.2_real64]
      call apply_saturated_reference_residual(input,[-0.5_real64,h],0.0_real64,dt, &
          trial_key,trial_ws%generation,trial_ws,capture,trial_store,valid)
      call check(valid,114)
      call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid,[-0.5_real64,h],dt*2)
      call check(.not.valid.and..not.allocated(transfer),115)
      call copy_reference_transfer(trial_ws,capture,trial_key,transfer,valid)
      call check(.not.valid.and..not.allocated(transfer),116)
      begin_store=999; end_store=999
      call copy_reference_budget(trial_ws,capture,trial_key,[-0.5_real64,h],dt, &
          transfer,begin_store,end_store,valid)
      call check(.not.valid.and..not.allocated(transfer),124)
      call check(abs(begin_store)+abs(end_store)<1.e-14_real64,125)
    end do
    call discard_reference_transfer(capture)
    call release_reference_workspace(trial_ws)
  end subroutine

  subroutine run(expected)
    integer(int64),intent(in)::expected
    call apply_saturated_reference_scratch(input,[-0.5_real64,0.5_real64],1.0_real64,key, &
        expected,.true.,ws,used,storage,ok)
  end subroutine
  subroutine check(condition,code)
    logical,intent(in)::condition
    integer,intent(in)::code
    if(condition)return
    print *,code
    error stop 1
  end subroutine
end program
