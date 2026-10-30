program test_matrix_route
  use iso_fortran_env,only:real64,int64
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend
  use mod_fmr_production_application_bootstrap
  use mod_kernel_transactions
  use mod_fixed_flux_top_boundary_provider
  use mod_b110_default_mvg_provider
  use MOD_grid,only:numnod,z,dz,disnod
  use mod_transaction_reference,only:transaction_state_t,TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_solute_mobile_salt_state,only:mobile_salt_state_t
  use mod_solute_compartment_state,only:solute_compartment_state_t
  use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
  use mod_fmr_b111_matrix_solute_route
  use mod_root_salinity_response,only:SALINITY_OK,SALINITY_INVALID
  use b111_literal_oracle,only:literal_step
  implicit none
  real(real64),parameter::T0=0.0_real64,T1=1.0e-3_real64,HARD_MASS_GATE=1.0e-10_real64
  type(fmr_production_application_config_t)::cfg
  type(fmr_serialized_reference_backend_t)::backend
  type(fixed_flux_top_boundary_provider_t),target::top
  type(fmr_logical_column_t)::column
  type(kernel_committed_state_t)::water_state
  type(kernel_checkpoint_t)::cp
  type(kernel_candidate_state_t)::candidate
  type(kernel_result_t)::result
  type(kernel_diagnostics_t)::diag
  type(fmr_serialized_physical_observation_t)::obs
  type(fmr_water_flux_substep_trace_t),allocatable::bad(:),allsteps(:)
  type(b111_reactive_solute_substep_forcing_t)::p,f
  type(matrix_solute_state_t)::solute,resumed,initial,retry
  type(matrix_solute_restart_t)::restart
  type(matrix_solute_receipt_t)::r,r2
  type(mobile_salt_state_t)::mobile,reference_mobile
  type(solute_compartment_state_t)::companion
  real(real64),allocatable::water(:),expected_c(:),expected_mass(:),faces(:)
  real(real64),allocatable::salinity_c(:),salinity_alpha(:),salinity_sink(:),salinity_loss(:),salinity_water(:)
  real(real64)::salinity_total
  real(real64)::k,t,mass0,oracle_decay,oracle_in,oracle_out,closure,total_in,total_out,begin_time
  integer(int64)::revision
  integer::status,i,j,face_status
  logical::ok,did_commit
  character(64)::exponent_argument

  call initialize_application_config(cfg,-75.0_real64,k)
  cfg%tiles(1)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  cfg%tiles(1)%base_forcing%top_flux=0.0_real64
  cfg%tiles(1)%base_forcing%bottom_flux=-0.1_real64
  cfg%tiles(1)%base_forcing%drainage_flux_by_level=1.0e-4_real64
  cfg%tiles(1)%base_forcing%subsurface_irrigation_source=0.0_real64
  cfg%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
  cfg%numerical%model_temporal_indicator_budget_available=.true.
  cfg%numerical%model_temporal_indicator_budget=1.0e-6_real64
  cfg%numerical%transaction%temporal_tolerance=0.0_real64
  cfg%numerical%transaction%max_retries=30
  cfg%numerical%max_committed_substeps=10000
  column%column_id=cfg%tiles(1)%tile_id;column%template_id=cfg%tiles(1)%template%template_id
  column%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call backend%initialize(top)
  call fmr_new_b110_temporal_indicator_committed_state(water_state,column%column_id,cfg%tiles(1)%initial_state,T0,ok, &
       spread(0.0_real64,1,numnod))
  call require(ok,'water state')
  call parameters(p)
  call get_command_argument(1,exponent_argument)
  if(len_trim(exponent_argument)>0)read(exponent_argument,*)p%frexp
  if(abs(p%frexp-1.0_real64)>epsilon(1.0_real64))p%cref_mg_cm3=0.37_real64
  call signed_contracts(p)
  allocate(expected_c(numnod),expected_mass(numnod))
  expected_c=[(0.1_real64+0.1_real64*i,i=1,numnod)]
  water=cfg%tiles(1)%initial_state%water_content
  expected_mass=(water*expected_c+p%bulk_density*p%kf*p%cref_mg_cm3* &
       (expected_c/p%cref_mg_cm3)**p%frexp)*dz
  call initialize_matrix_solute(p,9001_int64,T0,water,expected_c,solute,status)
  call require(status==MATRIX_OK,'initialize actual chemical state')
  call solute%root_salinity_view(T0,water,dz,spread(.1d0,1,numnod),.25d0,.5d0, &
       salinity_c,salinity_alpha,salinity_sink,salinity_loss,salinity_total,status)
  call require(status==SALINITY_OK,'reactive chemical owner salinity view')
  call require(maxval(abs(salinity_c-expected_c))<1d-14,'same reactive dissolved concentration')
  call require(maxval(abs(salinity_alpha-max(0d0,1d0-max(0d0,expected_c-.25d0)*.5d0)))<1d-14, &
       'incumbent Maas-Hoffman salinity response')
  call require(abs(sum(salinity_sink)+salinity_total-.1d0*numnod)<1d-14,'salinity uptake attribution')
  call solute%root_salinity_view(T1,water,dz,spread(.1d0,1,numnod),.25d0,.5d0, &
       salinity_c,salinity_alpha,salinity_sink,salinity_loss,salinity_total,status)
  call require(status==SALINITY_INVALID.and..not.allocated(salinity_c),'reject other sibling clock')
  salinity_water=water;salinity_water(1)=salinity_water(1)+1d-6
  call solute%root_salinity_view(T0,salinity_water,dz,spread(.1d0,1,numnod),.25d0,.5d0, &
       salinity_c,salinity_alpha,salinity_sink,salinity_loss,salinity_total,status)
  call require(status==SALINITY_INVALID.and..not.allocated(salinity_c),'reject other sibling water')
  call solute%root_salinity_view(T0,water,2d0*dz,spread(.1d0,1,numnod),.25d0,.5d0, &
       salinity_c,salinity_alpha,salinity_sink,salinity_loss,salinity_total,status)
  call require(status==SALINITY_INVALID.and..not.allocated(salinity_c),'reject chemical geometry change')
  initial=solute;mass0=sum(expected_mass);total_in=0.0_real64;total_out=0.0_real64
  do i=1,3
    begin_time=(i-1)*T1
    call water_state%capture_checkpoint(cp,ok)
    call backend%run_trial(column,cfg%tiles(1)%template,cfg%tiles(1)%parameters,water_state, &
         cfg%tiles(1)%base_forcing,cfg%numerical,begin_time,i*T1,cp,result,candidate,diag, &
         trace_accepted_water_flux_substeps=.true.)
    if(.not.result%completed)print *,'water diagnostics',result%status,diag%solver_rejections,diag%mass_rejections,diag%temporal_rejections
    call require(result%completed.and.candidate%ready(),'actual Full Richards accepted trajectory')
    obs=backend%observation()
    call require(obs%accepted_water_flux_trace_available,'accepted flux trace available')
    call backend%commit_trial_candidate(water_state,candidate,diag,did_commit,status)
    call require(did_commit,'hydraulic owner commits accepted water')
    call require(any(abs(obs%accepted_water_flux_substeps(1)%water_start- &
         obs%accepted_water_flux_substeps(size(obs%accepted_water_flux_substeps))%water_end)>1.0e-12_real64),'water storage changes')
    ! The oracle has independently extracted literal B1.11 expressions.
    do j=1,size(obs%accepted_water_flux_substeps)
      associate(s=>obs%accepted_water_flux_substeps(j))
        call mod_reconstruct(s,faces,closure,face_status)
        if(face_status/=0)print *,'face diagnostics',face_status,closure,s%t1-s%t0
        call require(face_status==0,'actual carrier water balance')
        f=p;f%dt_day=s%t1-s%t0;f%theta=s%water_end;f%theta_previous=s%water_start
        f%q_face_up_cm_day=-faces;f%root_sink_cm_day=s%root_sink;f%qdra_cm_day=s%drainage_sink_by_level
        call literal_step(f,expected_c,expected_mass,oracle_decay,oracle_in,oracle_out)
      end associate
    end do
    call consume_accepted_matrix_trace(solute,obs%accepted_water_flux_substeps,r)
    if(r%status/=0)print *,'chemical diagnostics',r%status,r%process_status,r%completed_substeps
    call require(r%status==MATRIX_OK,'actual chemical route accepted')
    call require(r%decay_out>0.0_real64,'actual temperature active decay')
    total_in=total_in+r%external_in;total_out=total_out+r%external_out
    call solute%snapshot(t,water,mobile,companion,revision)
    call require(maxval(abs(mobile%concentration_mg_cm3-expected_c))<1.0e-11_real64,'literal concentration oracle')
    call require(maxval(abs(mobile%mass_mg_cm2+companion%sorbed_matrix_mass-expected_mass))<1.0e-11_real64,'literal mass oracle')
    call require(abs(sum(expected_mass)-mass0-total_in+total_out)<1.0e-11_real64,'multi-window chemical balance')
    call require(all(mobile%mass_mg_cm2>=0.0_real64).and.all(companion%sorbed_matrix_mass>=0.0_real64),'nonnegative physical stores')
    if(i==1)then
      allsteps=obs%accepted_water_flux_substeps
      call export_matrix_solute_restart(solute,restart,status)
      call require(status==0,'export continuation')
      call restore_matrix_solute_restart(restart,9002_int64,resumed,status)
      call require(status/=0,'wrong parameter identity fails closed')
      call restore_matrix_solute_restart(restart,9001_int64,resumed,status)
      call require(status==0,'restore chemical companion')
    else
      call consume_accepted_matrix_trace(resumed,obs%accepted_water_flux_substeps,r2)
      call require(r2%status==0,'restart continuation')
      call compare_states(solute,resumed)
    end if
    ! An already consumed carrier must never update either mass or clock again.
    retry=solute
    call consume_accepted_matrix_trace(solute,obs%accepted_water_flux_substeps,r2)
    call require(r2%status==MATRIX_CARRIER,'duplicate consumption rejected')
    call compare_states(solute,retry)
    print '(A,I0,3ES24.16)','MATRIX_WINDOW ',i,r%mass_after,r%external_out,r%decay_out
  end do
  ! A valid first carrier followed by invalid second carrier rolls back the
  ! whole prefix. Repeat with the valid trace: exact same committed postimage.
  bad=[allsteps,allsteps]
  call consume_accepted_matrix_trace(initial,bad,r)
  call require(r%status==MATRIX_CARRIER.and.r%completed_substeps==size(allsteps),'failed prefix not published')
  call initialize_matrix_solute(p,9001_int64,T0,cfg%tiles(1)%initial_state%water_content, &
       [(0.1_real64+0.1_real64*j,j=1,numnod)],retry,status)
  call compare_states(initial,retry)
  call consume_accepted_matrix_trace(initial,allsteps,r)
  call consume_accepted_matrix_trace(retry,allsteps,r2)
  call require(r%status==0.and.r2%status==0,'retry original accepted carrier')
  call compare_states(initial,retry)
  print '(A)','MATRIX_ACTUAL_RICHARDS_ORACLE_ROLLBACK_RESTART=PASS'
contains
  subroutine signed_contracts(base)
    use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
    type(b111_reactive_solute_substep_forcing_t),intent(in)::base
    type(b111_reactive_solute_substep_forcing_t)::f,pbad
    type(fmr_water_flux_substep_trace_t)::trace(1),broken(1)
    type(matrix_solute_state_t)::a,saved,failed
    type(matrix_solute_receipt_t)::r
    type(mobile_salt_state_t)::m
    type(solute_compartment_state_t)::s
    real(real64)::w(numnod),c(numnod),mass(numnod),u(numnod+1),dec,ein,eout,t
    real(real64),allocatable::afterwater(:)
    integer(int64)::rev
    integer::variant,j,status
    w=0.3_real64;c=[(0.2_real64+0.1_real64*j,j=1,numnod)]
    pbad=base;pbad%frexp=2.00001_real64
    call initialize_matrix_solute(pbad,9001_int64,0.0_real64,w,c,failed,status)
    call require(status/=0,'exponent above qualified application domain rejected')
    pbad=base;pbad%frexp=0.49999_real64
    call initialize_matrix_solute(pbad,9001_int64,0.0_real64,w,c,failed,status)
    call require(status/=0,'exponent below qualified application domain rejected')
    do j=1,5
      pbad=base
      select case(j)
      case(1)
        pbad%frexp=ieee_value(0.0_real64,ieee_quiet_nan)
      case(2)
        pbad%rain_rate_cm_day=ieee_value(0.0_real64,ieee_quiet_nan)
      case(3)
        pbad%irrigation_rate_cm_day=ieee_value(0.0_real64,ieee_quiet_nan)
      case(4)
        pbad%macropore_area_fraction=ieee_value(0.0_real64,ieee_quiet_nan)
      case(5)
        pbad%rain_rate_cm_day=huge(0.0_real64)
        pbad%irrigation_rate_cm_day=huge(0.0_real64)
      end select
      call initialize_matrix_solute(pbad,9001_int64,0.0_real64,w,c,failed,status)
      call require(status==MATRIX_INVALID,'invalid scalar initialization returns status under FPE traps')
      call require(.not.failed%ready(),'invalid scalar initialization publishes no state')
    end do
    print '(A)','MATRIX_INITIALIZATION_NONFINITE_OVERFLOW_O0_O2=PASS'
    pbad=base;pbad%gampar(1)=ieee_value(0.0_real64,ieee_quiet_nan)
    call initialize_matrix_solute(pbad,9001_int64,0.0_real64,w,c,failed,status)
    call require(status/=0,'invalid immutable reaction parameter rejected')
    call initialize_matrix_solute(base,9001_int64,0.0_real64,-w,c,failed,status)
    call require(status/=0,'negative carrier storage rejected')
    do variant=1,4
      f=base;f%temperature_active=variant/=4
      f%temperature_c=spread(20.0_real64+10.0_real64*variant,1,numnod)
      trace(1)=fmr_water_flux_substep_trace_t()
      trace(1)%t0=0.0_real64;trace(1)%t1=0.1_real64
      trace(1)%water_start=w
      trace(1)%root_sink=spread(0.001_real64,1,numnod)
      allocate(trace(1)%drainage_sink_by_level(2,numnod))
      trace(1)%drainage_sink_by_level(1,:)=0.003_real64
      trace(1)%drainage_sink_by_level(2,:)=-0.001_real64
      trace(1)%net_node_source=-sum(trace(1)%drainage_sink_by_level,dim=1)-trace(1)%root_sink
      trace(1)%subsurface_source=spread(0.0_real64,1,numnod)
      u=0.01_real64;u(1)=0.0_real64
      if(mod(variant,2)==0)u(numnod+1)=-0.01_real64
      trace(1)%top_flux=u(1);trace(1)%bottom_flux=u(numnod+1)
      trace(1)%water_end=w
      do j=1,numnod
        trace(1)%water_end(j)=w(j)+0.1_real64*(u(j+1)-u(j)+trace(1)%net_node_source(j))/dz(j)
      end do
      call initialize_matrix_solute(f,9001_int64,0.0_real64,w,c,a,status)
      call require(status==0,'signed fixture initialized')
      saved=a
      mass=(w*c+f%bulk_density*f%kf*f%cref_mg_cm3*(c/f%cref_mg_cm3)**f%frexp)*dz
      f%dt_day=0.1_real64;f%theta=trace(1)%water_end;f%theta_previous=w
      f%q_face_up_cm_day=u;f%root_sink_cm_day=trace(1)%root_sink;f%qdra_cm_day=trace(1)%drainage_sink_by_level
      call literal_step(f,c,mass,dec,ein,eout)
      call consume_accepted_matrix_trace(a,trace,r)
      call require(r%status==0,'signed root drainage bottom route')
      call a%snapshot(t,afterwater,m,s,rev)
      call require(maxval(abs(m%concentration_mg_cm3-c))<1.0e-12_real64,'signed literal oracle')
      call require(maxval(abs(m%mass_mg_cm2+s%sorbed_matrix_mass-mass))<1.0e-12_real64,'signed compartment mass oracle')
      call require(abs(r%decay_out-dec)<1.0e-12_real64,'literal decay receipt')
      call require(abs(r%external_out-r%external_in-eout)<1.0e-12_real64,'signed external receipt')
      if(variant==4)call require(abs(r%decay_out)<=0.0_real64,'heat off disables source decay')
      broken=trace;broken(1)%net_node_source=0.0_real64
      failed=saved
      call consume_accepted_matrix_trace(failed,broken,r)
      call require(r%status==MATRIX_CARRIER,'inconsistent root drainage source rejected')
      call compare_states(saved,failed)
      broken=trace;broken(1)%root_sink(1)=ieee_value(0.0_real64,ieee_quiet_nan)
      call consume_accepted_matrix_trace(failed,broken,r)
      call require(r%status==MATRIX_CARRIER,'nonfinite root input rejected')
      call compare_states(saved,failed)
      pbad=base;pbad%decpot=100.0_real64
      call initialize_matrix_solute(pbad,9001_int64,0.0_real64,w, &
           [(0.2_real64+0.1_real64*j,j=1,numnod)],failed,status)
      saved=failed
      call consume_accepted_matrix_trace(failed,trace,r)
      call require(r%status==MATRIX_PROCESS,'reaction overdraw rejected')
      call compare_states(saved,failed)
      ! Repeat from identical committed authority with a shorter valid carrier.
      trace(1)%t1=0.001_real64
      trace(1)%water_end=w+(trace(1)%water_end-w)*0.01_real64
      call consume_accepted_matrix_trace(failed,trace,r)
      call require(r%status==0,'overdraw retry shorter carrier succeeds')
      c=[(0.2_real64+0.1_real64*j,j=1,numnod)]
    end do
    print '(A)','MATRIX_SIGNED_ROOT_DRAIN_BOTTOM_REACTION_RETRY=PASS'
  end subroutine
  subroutine parameters(f)
    type(b111_reactive_solute_substep_forcing_t),intent(out)::f
    f%dz_cm=dz;f%theta=cfg%tiles(1)%initial_state%water_content
    f%bulk_density=spread(1.3_real64,1,numnod);f%kf=spread(0.2_real64,1,numnod)
    f%temperature_active=.true.;f%temperature_c=spread(20.0_real64,1,numnod)
    f%gampar=spread(0.05_real64,1,numnod);f%rtheta=spread(0.3_real64,1,numnod)
    f%bexp=spread(1.0_real64,1,numnod);f%decpot=spread(0.02_real64,1,numnod)
    f%fdepth=spread(1.0_real64,1,numnod)
    f%face_distance_cm=disnod(2:numnod)
    f%face_left_weight=0.5_real64*dz(2:numnod)/f%face_distance_cm
    f%face_right_weight=0.5_real64*dz(1:numnod-1)/f%face_distance_cm
    f%theta_sat_left=cfg%tiles(1)%parameters%cofgen(2,1:numnod-1)
    f%dispersivity_cm=spread(0.2_real64,1,numnod-1)
    f%molecular_diffusion_cm2_day=0.05_real64;f%tscf=0.5_real64
    f%cdrain_mg_cm3=0.4_real64;f%cseep_mg_cm3=0.3_real64
  end subroutine
  subroutine compare_states(a,b)
    type(matrix_solute_state_t),intent(in)::a,b
    type(mobile_salt_state_t)::m1,m2
    type(solute_compartment_state_t)::s1,s2
    real(real64)::t1,t2
    real(real64),allocatable::w1(:),w2(:)
    integer(int64)::v1,v2
    call a%snapshot(t1,w1,m1,s1,v1);call b%snapshot(t2,w2,m2,s2,v2)
    call require(abs(t1-t2)<=0.0_real64.and.v1==v2,'continuation lineage identity')
    call require(all(abs(w1-w2)<=0.0_real64),'restart carrier identity')
    call require(all(abs(m1%mass_mg_cm2-m2%mass_mg_cm2)<=0.0_real64),'restart dissolved identity')
    call require(all(abs(m1%concentration_mg_cm3-m2%concentration_mg_cm3)<=0.0_real64),'restart concentration identity')
    call require(all(abs(s1%sorbed_matrix_mass-s2%sorbed_matrix_mass)<=0.0_real64),'restart sorbed identity')
  end subroutine
  subroutine mod_reconstruct(s,q,cl,code)
    use mod_solute_water_face_flux_reconstruction,only:reconstruct_interval_water_face_flux
    type(fmr_water_flux_substep_trace_t),intent(in)::s
    real(real64),allocatable,intent(out)::q(:)
    real(real64),intent(out)::cl
    integer,intent(out)::code
    call reconstruct_interval_water_face_flux(dz,s%water_start,s%water_end,s%net_node_source, &
         -s%top_flux,-s%bottom_flux,s%t1-s%t0,1.0e-10_real64/(s%t1-s%t0),q,cl,code)
  end subroutine
  subroutine require(ok,label)
    logical,intent(in)::ok
    character(*),intent(in)::label
    if(.not.ok)then
      print '(A)','FAIL '//label;error stop 1
    end if
  end subroutine
  include 'matrix_fixture.inc'
end program
