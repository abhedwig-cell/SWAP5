program test_swap431_sol01_restart_contract
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED, FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND
  use mod_fmr_serialized_reference_backend, only: fmr_b110_sol01_state_t, &
       fmr_new_b110_sol01_committed_state, fmr_initialize_sol01_companion
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, fmr_export_committed_restart, &
       fmr_restore_committed_restart, FMR_RESTART_OK, FMR_RESTART_KERNEL_PERSISTENCE_REJECTED
  implicit none

  type(fmr_b110_sol01_state_t) :: initial
  type(kernel_committed_state_t) :: state_registry(1), restored_registry(1)
  type(fmr_logical_column_t) :: columns(1)
  type(fmr_template_t) :: templates(1), wrong_templates(1)
  type(fmr_committed_restart_bundle_t) :: bundle
  class(transaction_state_t), allocatable :: snapshot
  logical :: ok,exported,restored,got
  integer :: status

  initial%active_nodes=2
  allocate(initial%pressure_head(2),initial%water_content(2),initial%salt)
  initial%pressure_head=[-10d0,-20d0]
  initial%water_content=[.25d0,.30d0]
  initial%ponding_depth=.4d0
  initial%groundwater_level=-75d0
  allocate(initial%salt%mass_mg_cm2(2))
  initial%salt%mass_mg_cm2=[2d0,3d0]
  call fmr_initialize_sol01_companion(initial,[1d0,1.5d0],.75d0,status)
  call require(status==0,'companion init')

  call fmr_new_b110_sol01_committed_state(state_registry(1),99101_int64,initial,12.5d0,ok)
  call require(ok,'committed init')

  columns(1)%column_id=99101_int64
  columns(1)%template_id=99102_int64
  columns(1)%parameter_ref=1_int64
  columns(1)%forcing_handle=1_int64
  columns(1)%state_handle=1_int64
  columns(1)%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE

  templates(1)%template_id=99102_int64
  templates(1)%physics_topology_id=99103_int64
  templates(1)%vertical_layout_id=99104_int64
  templates(1)%state_layout_id=99105_int64
  templates(1)%solver_interface_id=99106_int64
  templates(1)%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  templates(1)%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED_SORBED_POND

  call fmr_export_committed_restart(columns,templates,state_registry,99107_int64,bundle,exported,status)
  call require(exported.and.status==FMR_RESTART_OK,'export')

  call fmr_restore_committed_restart(bundle,99107_int64,columns,templates,restored_registry,restored,status)
  call require(restored.and.status==FMR_RESTART_OK,'restore')
  call restored_registry(1)%snapshot(snapshot,got)
  call require(got,'snapshot')
  select type(s=>snapshot)
  type is(fmr_b110_sol01_state_t)
    call require(all(s%salt%mass_mg_cm2==[2d0,3d0]),'dissolved roundtrip')
    call require(all(s%solute_companion%sorbed_matrix_mass==[1d0,1.5d0]),'sorbed roundtrip')
    call require(s%solute_companion%pond_mass==.75d0,'pond roundtrip')
  class default
    error stop 'SOL01_RESTART dynamic type lost'
  end select

  wrong_templates=templates
  wrong_templates(1)%solute_state_layout_id=FMR_SOLUTE_STATE_LAYOUT_MOBILE_DISSOLVED
  call fmr_export_committed_restart(columns,wrong_templates,state_registry,99107_int64,bundle,exported,status)
  call require(.not.exported.and.status==FMR_RESTART_KERNEL_PERSISTENCE_REJECTED,'legacy layout rejects SOL01 state')

  print '(A)','SOL01_RESTART_CONTRACT_PASS'
contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      print '(A)',trim(label)//' failed'
      error stop 1
    end if
  end subroutine
end program
