program test_fmr_b111_soil_n_amendment_group
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_soil_n_pool_state
  use mod_b111_soil_n_addition
  use mod_b111_soil_n_amendment_group
  use mod_fmr_b111_soil_n_transaction
  use mod_fmr_b111_soil_n_amendment_group
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::s,ss
  type(fmr_b111_soil_n_state_t)::state,candidate,restarted
  type(b111_amendment_group_t)::group
  type(b111_soil_n_split_parameters_t)::split
  type(fmr_b111_amendment_receipt_t)::receipt
  integer::status
  integer(int64)::event_id
  logical::available,consumed
  real(real64)::n0,n1

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.005_real64,0.03_real64,0.005_real64,0.03_real64, &
               0.005_real64,0.03_real64,0.005_real64,0.03_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,spread(0.0_real64,1,8),0.0_real64,0.0_real64,0.0_real64,0.0_real64,s,status)
  call check(status==SOIL_N_OK,'pool init')
  call initialize_fmr_b111_soil_n_state(p,s,state,status)
  call check(status==FMR_SOIL_N_OK,'state init')

  split%nfrac_fom_min=0.005_real64
  split%nfrac_fom_max=0.03_real64
  split%nfrac_humus=0.05_real64
  split%asfa_min=0.03_real64
  split%asfa_max=0.28_real64

  group%event_id=7001_int64
  group%legacy_event_time=99.0_real64
  allocate(group%materials(2))
  group%materials(1)%application_kg_m2=0.02_real64
  group%materials(1)%application_age=1.0_real64
  group%materials(1)%organic_matter_fraction=0.5_real64
  group%materials(1)%organic_n_fraction=0.015_real64
  group%materials(1)%ammonium_n_fraction=0.01_real64
  group%materials(1)%nitrate_n_fraction=0.005_real64
  group%materials(1)%volatilization_fraction=0.25_real64
  group%materials(2)=group%materials(1)
  group%materials(2)%application_kg_m2=0.01_real64
  group%materials(2)%application_age=2.0_real64
  group%materials(2)%volatilization_fraction=0.0_real64

  call prepare_fmr_b111_amendment_candidate(state,group,99.0_real64,p%depth_m,split,candidate,receipt)
  call check(receipt%status==FMR_B111_AMEND_BUILD_FAILED,'not due rejected')
  call state%snapshot(ps,ss,available)
  call check(available,'pre snapshot')
  n0=ss%nitrogen_total(ps)

  call prepare_fmr_b111_amendment_candidate(state,group,100.0_real64,p%depth_m,split,candidate,receipt)
  call check(receipt%status==FMR_B111_AMEND_OK,'due amendment candidate')
  call check(receipt%group%material_count==2,'group material count')
  call check(receipt%group%gross_n_input_kg_m2>receipt%group%volatilized_n_output_kg_m2,'positive retained N')
  call state%snapshot(ps,ss,available)
  call near(ss%nitrogen_total(ps),n0,'candidate-only committed unchanged')
  state=candidate
  call state%snapshot(ps,ss,available)
  n1=ss%nitrogen_total(ps)
  call near(n1,n0+receipt%owner%external_n_input_kg_m2-receipt%owner%external_n_output_kg_m2,'amendment owner closure')

  call prepare_fmr_b111_amendment_candidate(state,group,100.0_real64,p%depth_m,split,candidate,receipt)
  call check(receipt%status==FMR_B111_AMEND_APPLY_FAILED,'duplicate group rejected')
  call state%snapshot(ps,ss,available)
  call near(ss%nitrogen_total(ps),n1,'duplicate no mutation')

  call state%snapshot_management_event(event_id,consumed,available)
  call check(available.and.consumed.and.event_id==7001_int64,'event lineage')
  call initialize_fmr_b111_soil_n_state(ps,ss,restarted,status,event_id,consumed)
  call check(status==FMR_SOIL_N_OK,'restart reconstruction')
  call prepare_fmr_b111_amendment_candidate(restarted,group,100.0_real64,p%depth_m,split,candidate,receipt)
  call check(receipt%status==FMR_B111_AMEND_APPLY_FAILED,'restart duplicate rejected')

  print '(A)','FMR_B111_SOIL_N_AMENDMENT_GROUP_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=2.0e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
