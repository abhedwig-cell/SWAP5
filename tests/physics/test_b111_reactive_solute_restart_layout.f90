program test_b111_reactive_solute_restart_layout
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_initialize_reactive_solute_profile, fmr_new_b110_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK
  implicit none

  type(fmr_b110_physical_state_t)::state
  type(fmr_template_t)::template,mobile_template
  type(fmr_logical_column_t)::columns(1)
  type(kernel_committed_state_t)::states(1),restored(1)
  type(fmr_committed_restart_bundle_t)::bundle
  class(transaction_state_t),allocatable::snapshot
  integer::status
  logical::ok

  state%active_nodes=2
  state%water_content=[0.2_real64,0.3_real64]
  call fmr_initialize_reactive_solute_profile(state,[10.0_real64,20.0_real64], &
       [1.0_real64,2.0_real64],[0.5_real64,0.75_real64],0.4_real64,0.25_real64, &
       [3.0_real64,4.0_real64],status,1.25_real64)
  call check(status==0,'reactive initializer')
  call check(state%salt%reactive_ready(2),'reactive ready')
  call check(.not.state%salt%ready(2),'mobile-only ready rejects reactive payload')

  template%template_id=9001_int64
  template%physics_topology_id=1_int64
  template%vertical_layout_id=1_int64
  template%state_layout_id=1_int64
  template%solver_interface_id=1_int64
  template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
  template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_REACTIVE_COMPARTMENTS
  template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  call check(fmr_restart_state_matches_template(state,template),'reactive restart layout accepts state')

  mobile_template=template
  mobile_template%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  call check(.not.fmr_restart_state_matches_template(state,mobile_template),'mobile restart layout rejects reactive state')

  columns(1)%column_id=1_int64
  columns(1)%template_id=template%template_id
  columns(1)%parameter_ref=1_int64
  columns(1)%state_handle=1_int64
  columns(1)%forcing_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  call fmr_new_b110_committed_state(states(1),77_int64,state,0.0_real64,ok)
  call check(ok,'committed state init')
  call fmr_export_committed_restart(columns,[template],states,123_int64,bundle,ok,status)
  call check(ok.and.status==FMR_RESTART_OK,'restart export')
  call fmr_restore_committed_restart(bundle,123_int64,columns,[template],restored,ok,status)
  call check(ok.and.status==FMR_RESTART_OK,'restart restore')
  call restored(1)%snapshot(snapshot,ok)
  call check(ok,'restart snapshot')
  select type(snapshot)
  type is(fmr_b110_physical_state_t)
    call check(allocated(snapshot%salt),'restored salt allocated')
    call check(snapshot%salt%reactive_ready(2),'restored reactive ready')
    call check(all(snapshot%salt%mass_mg_cm2==state%salt%mass_mg_cm2),'dissolved restart identity')
    call check(all(snapshot%salt%sorbed_mass_mg_cm2==state%salt%sorbed_mass_mg_cm2),'sorbed restart identity')
    call check(snapshot%salt%pond_mass_mg_cm2==state%salt%pond_mass_mg_cm2,'pond restart identity')
    call check(snapshot%salt%aquifer_mass_mg_cm2==state%salt%aquifer_mass_mg_cm2,'aquifer restart identity')
    call check(all(snapshot%salt%age_amount_cm_day==state%salt%age_amount_cm_day),'age restart identity')
    call check(snapshot%salt%pond_age_amount_cm2_day==state%salt%pond_age_amount_cm2_day,'pond age restart identity')
  class default
    call check(.false.,'wrong restored physical type')
  end select

  print '(A)','B111_REACTIVE_SOLUTE_RESTART_LAYOUT_PASS'
contains
  subroutine check(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
