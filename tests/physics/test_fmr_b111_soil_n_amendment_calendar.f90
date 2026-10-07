program test_fmr_b111_soil_n_amendment_calendar
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use mod_soil_n_pool_state
  use mod_b111_soil_n_addition
  use mod_fmr_b111_soil_n_transaction
  use mod_fmr_b111_soil_n_amendment_calendar
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::s,ss
  type(fmr_b111_soil_n_state_t)::state,candidate,restarted
  type(b111_soil_n_split_parameters_t)::split
  type(b111_amendment_calendar_group_t)::g1,g2
  type(b111_amendment_calendar_item_t)::items(3)
  type(b111_amendment_calendar_group_t),allocatable::groups(:)
  type(b111_amendment_calendar_receipt_t)::r
  integer::status
  integer(int64)::event_id
  logical::consumed,available
  real(real64)::n0,n1

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.03_real64,0.01_real64,0.03_real64,0.01_real64,0.03_real64,0.01_real64,0.03_real64,0.01_real64]
  p%nfrac_biomass=0.04_real64;p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,spread(0.0_real64,1,8),0.0_real64,0.0_real64,0.1_real64,0.1_real64,s,status)
  call check(status==SOIL_N_OK,'pool init')
  call initialize_fmr_b111_soil_n_state(p,s,state,status)
  call check(status==FMR_SOIL_N_OK,'state init')
  n0=s%nitrogen_total(p)

  split%nfrac_fom_min=0.01_real64;split%nfrac_fom_max=0.03_real64
  split%nfrac_humus=0.05_real64;split%asfa_min=0.03_real64;split%asfa_max=0.28_real64

  ! Unsorted raw records: complete material records must remain intact while
  ! sorting and adjacent dates within 1e-3 are grouped.
  items(1)%source_time=12.0_real64
  items(1)%material%application_kg_m2=0.30_real64
  items(1)%material%volatilization_fraction=0.30_real64
  items(2)%source_time=10.0005_real64
  items(2)%material%application_kg_m2=0.20_real64
  items(2)%material%volatilization_fraction=0.20_real64
  items(3)%source_time=10.0_real64
  items(3)%material%application_kg_m2=0.10_real64
  items(3)%material%volatilization_fraction=0.10_real64
  call build_b111_amendment_calendar(items,groups,status)
  call check(status==FMR_B111_AMCAL_OK.and.size(groups)==2,'calendar build')
  call check(groups(1)%event_id==1_int64.and.groups(2)%event_id==2_int64,'monotone group ids')
  call check(size(groups(1)%materials)==2.and.size(groups(2)%materials)==1,'same-date grouping')
  call near(groups(1)%materials(1)%application_kg_m2,0.10_real64,'sorted first dosage identity')
  call near(groups(1)%materials(1)%volatilization_fraction,0.10_real64,'sorted first material identity')
  call near(groups(1)%materials(2)%application_kg_m2,0.20_real64,'grouped second dosage identity')
  call near(groups(2)%materials(1)%application_kg_m2,0.30_real64,'later dosage identity')

  g1%event_id=1_int64;g1%source_time=10.0_real64
  allocate(g1%materials(2))
  g1%materials(1)%application_kg_m2=0.5_real64
  g1%materials(1)%application_age=1.0_real64
  g1%materials(1)%organic_matter_fraction=0.4_real64
  g1%materials(1)%organic_n_fraction=0.02_real64
  g1%materials(1)%ammonium_n_fraction=0.01_real64
  g1%materials(1)%nitrate_n_fraction=0.005_real64
  g1%materials(1)%volatilization_fraction=0.2_real64
  g1%materials(2)=g1%materials(1)
  g1%materials(2)%application_kg_m2=0.25_real64
  g1%materials(2)%volatilization_fraction=0.0_real64

  call apply_b111_amendment_calendar_group(state,10.5_real64,p%depth_m,split,g1,candidate,r)
  call check(r%status==FMR_B111_AMCAL_NOT_DUE,'early event not due')
  call candidate%snapshot(ps,ss,available)
  call near(ss%nitrogen_total(ps),n0,'early event no mutation')

  call apply_b111_amendment_calendar_group(state,11.0_real64,p%depth_m,split,g1,candidate,r)
  call check(r%status==FMR_B111_AMCAL_OK.and.r%material_count==2,'grouped event due')
  call check(r%nitrogen%external_n_input_kg_m2>r%nitrogen%external_n_output_kg_m2,'group adds net N')
  call state%snapshot(ps,ss,available)
  call near(ss%nitrogen_total(ps),n0,'committed remains untouched before accept')
  call candidate%snapshot(ps,ss,available)
  n1=ss%nitrogen_total(ps)
  call near(n1,n0+r%nitrogen%external_n_input_kg_m2-r%nitrogen%external_n_output_kg_m2,'group owner mass closure')
  call candidate%snapshot_management_event(event_id,consumed,available)
  call check(available.and.consumed.and.event_id==1_int64,'event cursor advanced')

  call initialize_fmr_b111_soil_n_state(ps,ss,restarted,status,event_id,consumed)
  call check(status==FMR_SOIL_N_OK,'restart event state')
  call apply_b111_amendment_calendar_group(restarted,11.0_real64,p%depth_m,split,g1,candidate,r)
  call check(r%status==FMR_B111_AMCAL_DUPLICATE,'restart duplicate rejected')

  g2%event_id=2_int64;g2%source_time=12.0_real64
  allocate(g2%materials(1));g2%materials(1)=g1%materials(1)
  call apply_b111_amendment_calendar_group(restarted,13.0_real64,p%depth_m,split,g2,candidate,r)
  call check(r%status==FMR_B111_AMCAL_OK,'next calendar group accepted')
  call candidate%snapshot_management_event(event_id,consumed,available)
  call check(available.and.event_id==2_int64,'calendar cursor two')

  print '(A)','FMR_B111_SOIL_N_AMENDMENT_CALENDAR_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1.0e-11_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed';error stop 1
    end if
  end subroutine
end program
