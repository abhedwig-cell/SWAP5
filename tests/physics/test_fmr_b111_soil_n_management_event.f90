program test_fmr_b111_soil_n_management_event
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, &
       initialize_soil_n_pool_state, SOIL_N_OK
  use mod_b111_soil_n_addition, only: b111_soil_n_material_t, b111_soil_n_split_parameters_t
  use mod_fmr_b111_soil_n_transaction, only: fmr_b111_soil_n_state_t, &
       initialize_fmr_b111_soil_n_state, FMR_SOIL_N_OK
  use mod_fmr_b111_soil_n_management_event, only: fmr_b111_soil_n_management_event_t, &
       fmr_b111_soil_n_management_event_receipt_t, apply_fmr_b111_soil_n_management_material_event, &
       FMR_B111_N_EVENT_OK, FMR_B111_N_EVENT_APPLY_FAILED, &
       FMR_B111_N_EVENT_AMENDMENT, FMR_B111_N_EVENT_RESIDUE
  implicit none

  type(soil_n_inventory_parameters_t)::p,ps
  type(soil_n_pool_state_t)::s,ss
  type(fmr_b111_soil_n_state_t)::state,restarted,candidate
  type(fmr_b111_soil_n_management_event_t)::event
  type(fmr_b111_soil_n_management_event_receipt_t)::receipt
  integer::status
  integer(int64)::event_id
  logical::available,consumed
  real(real64)::n_after_amend,n_after_residue

  p%depth_m=0.5_real64
  p%nfrac_fom=[0.03_real64,0.01_real64,0.03_real64,0.01_real64, &
               0.03_real64,0.01_real64,0.03_real64,0.01_real64]
  p%nfrac_biomass=0.04_real64
  p%nfrac_humus=0.05_real64
  call initialize_soil_n_pool_state(p,[0d0,0d0,0d0,0d0,0d0,0d0,0d0,0d0], &
       0d0,0d0,0d0,0d0,s,status)
  call check(status==SOIL_N_OK,'inventory init')
  call initialize_fmr_b111_soil_n_state(p,s,state,status)
  call check(status==FMR_SOIL_N_OK,'state init')

  event%event_id=1001_int64
  event%event_kind=FMR_B111_N_EVENT_AMENDMENT
  event%depth_m=0.5_real64
  event%split%nfrac_fom_min=0.01_real64
  event%split%nfrac_fom_max=0.03_real64
  event%split%nfrac_humus=0.05_real64
  event%split%asfa_min=0.03_real64
  event%split%asfa_max=0.28_real64
  event%material%application_kg_m2=1.0_real64
  event%material%application_age=1.0_real64
  event%material%organic_matter_fraction=0.5_real64
  event%material%organic_n_fraction=0.025_real64
  event%material%ammonium_n_fraction=0.02_real64
  event%material%nitrate_n_fraction=0.01_real64
  event%material%volatilization_fraction=0.25_real64

  call apply_fmr_b111_soil_n_management_material_event(state,event,candidate,receipt)
  call check(receipt%status==FMR_B111_N_EVENT_OK,'amendment candidate')
  call state%snapshot(ps,ss,available)
  call check(available,'committed snapshot before amendment commit')
  call near(ss%nitrogen_total(ps),0.0_real64,'candidate-only no committed mutation')
  state=candidate
  call state%snapshot(ps,ss,available)
  call check(available,'amendment committed snapshot')
  n_after_amend=ss%nitrogen_total(ps)

  call apply_fmr_b111_soil_n_management_material_event(state,event,candidate,receipt)
  call check(receipt%status==FMR_B111_N_EVENT_APPLY_FAILED,'duplicate amendment rejected')
  call state%snapshot(ps,ss,available)
  call near(ss%nitrogen_total(ps),n_after_amend,'duplicate no mutation')

  call state%snapshot_management_event(event_id,consumed,available)
  call check(available.and.consumed.and.event_id==1001_int64,'event lineage persisted')
  call initialize_fmr_b111_soil_n_state(ps,ss,restarted,status,event_id,consumed)
  call check(status==FMR_SOIL_N_OK,'restart init')
  call apply_fmr_b111_soil_n_management_material_event(restarted,event,candidate,receipt)
  call check(receipt%status==FMR_B111_N_EVENT_APPLY_FAILED,'restart duplicate rejected')

  event%event_id=1002_int64
  event%event_kind=FMR_B111_N_EVENT_RESIDUE
  event%material%volatilization_fraction=0.9_real64
  event%material%application_kg_m2=0.4_real64
  call apply_fmr_b111_soil_n_management_material_event(restarted,event,candidate,receipt)
  call check(receipt%status==FMR_B111_N_EVENT_OK,'residue candidate')
  call near(receipt%nitrogen%external_n_output_kg_m2,0.0_real64,'residue volatilization forced zero')
  restarted=candidate
  call restarted%snapshot(ps,ss,available)
  call check(available,'residue snapshot')
  n_after_residue=ss%nitrogen_total(ps)
  call check(n_after_residue>n_after_amend,'new residue event adds N')

  print '(A)','FMR_B111_SOIL_N_MANAGEMENT_EVENT_PASS'
contains
  subroutine near(x,y,label)
    real(real64),intent(in)::x,y
    character(len=*),intent(in)::label
    call check(abs(x-y)<=1e-12_real64*max(1.0_real64,abs(x),abs(y)),label)
  end subroutine
  subroutine check(ok,label)
    logical,intent(in)::ok
    character(len=*),intent(in)::label
    if(.not.ok)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
