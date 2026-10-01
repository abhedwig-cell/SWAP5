program test_ppa_wu05_perch20_restart_lifecycle
  use, intrinsic :: iso_fortran_env, only: int64,real64
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t,fmr_template_t,FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_OPTIONAL_STATE_LAYOUT_MACROPORE,FMR_NUMERICAL_CONTINUATION_NONE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, &
       FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05_perch19_reduction_controller, only: macropore_reduction_continuation_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_macropore_reduction_state_t,fmr_new_b110_macropore_reduction_committed_state
  use mod_fmr_restart_state_contract, only: fmr_restart_state_matches_template
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t,fmr_export_committed_restart, &
       fmr_restore_committed_restart,FMR_RESTART_OK,FMR_RESTART_TEMPLATE_MISMATCH
  implicit none

  integer(int64),parameter::column_id=5202001_int64,parameter_set_identity=52029001_int64
  real(real64),parameter::committed_time=35797.504543715368_real64
  type(fmr_logical_column_t)::columns(1)
  type(fmr_template_t)::templates(1),plain_template,wrong_num_template
  type(kernel_committed_state_t)::source_states(1),restored_states(1),rejected_states(1)
  type(fmr_b110_physical_state_t)::physical
  type(macropore_reduction_continuation_t)::reduction
  type(fmr_committed_restart_bundle_t)::bundle,roundtrip
  class(transaction_state_t),allocatable::snapshot,clone
  logical::ok,exported,restored
  integer::status

  call configure_template(templates(1))
  call configure_column(columns(1),templates(1))
  call configure_physical(physical)
  reduction=macropore_reduction_continuation_t(level=2,stable_steps=7,previous_dt=2.0e-3_real64)

  call fmr_new_b110_macropore_reduction_committed_state(source_states(1),column_id,physical,reduction, &
       committed_time,ok)
  call require(ok .and. source_states(1)%ready(),'committed reduction state')

  call source_states(1)%snapshot(snapshot,ok)
  call require(ok .and. allocated(snapshot),'snapshot available')
  call verify_reduction_state(snapshot,reduction,'source snapshot')
  call snapshot%clone(clone)
  call require(allocated(clone),'clone allocated')
  call verify_reduction_state(clone,reduction,'clone exact')
  select type(c=>clone)
  type is(fmr_b110_macropore_reduction_state_t)
    c%reduction_continuation%level=3
    c%reduction_continuation%stable_steps=0
  class default
    error stop 'PERCH20 clone dynamic type'
  end select
  deallocate(snapshot)
  call source_states(1)%snapshot(snapshot,ok)
  call verify_reduction_state(snapshot,reduction,'clone mutation isolated')
  write(*,'(a)') 'PPA_WU05_PERCH20_CLONE_ISOLATION=PASS'

  call fmr_export_committed_restart(columns,templates,source_states,parameter_set_identity,bundle,exported,status)
  call require(exported .and. status==FMR_RESTART_OK,'restart export')
  call require(allocated(bundle%records) .and. size(bundle%records)==1,'restart record')
  call require(fmr_restart_state_matches_template(bundle%records(1)%physical_state,templates(1)), &
       'registered layout matches')
  call verify_reduction_state(bundle%records(1)%physical_state,reduction,'export payload')

  plain_template=templates(1)
  plain_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
  call require(.not.fmr_restart_state_matches_template(bundle%records(1)%physical_state,plain_template), &
       'reduction state rejected by NONE layout')
  wrong_num_template=templates(1)
  wrong_num_template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  call require(.not.fmr_restart_state_matches_template(bundle%records(1)%physical_state,wrong_num_template), &
       'reduction state rejected by temporal-history layout')

  call fmr_restore_committed_restart(bundle,parameter_set_identity,columns,[plain_template],rejected_states,restored,status)
  call require(.not.restored .and. status==FMR_RESTART_TEMPLATE_MISMATCH,'wrong numerical layout rejected')
  call require(.not.rejected_states(1)%ready(),'wrong-layout rejection atomic')
  write(*,'(a)') 'PPA_WU05_PERCH20_LAYOUT_FAIL_CLOSED=PASS'

  call fmr_restore_committed_restart(bundle,parameter_set_identity,columns,templates,restored_states,restored,status)
  call require(restored .and. status==FMR_RESTART_OK,'restart restore')
  call restored_states(1)%snapshot(snapshot,ok)
  call require(ok .and. allocated(snapshot),'restored snapshot')
  call verify_reduction_state(snapshot,reduction,'restored payload')

  call fmr_export_committed_restart(columns,templates,restored_states,parameter_set_identity,roundtrip,exported,status)
  call require(exported .and. status==FMR_RESTART_OK,'roundtrip export')
  call verify_reduction_state(roundtrip%records(1)%physical_state,reduction,'roundtrip payload')
  call require(roundtrip%records(1)%lineage_id==bundle%records(1)%lineage_id,'roundtrip lineage')
  call require(roundtrip%records(1)%revision==bundle%records(1)%revision,'roundtrip revision')
  call require(same_bits(roundtrip%records(1)%committed_time,bundle%records(1)%committed_time),'roundtrip time')
  write(*,'(a)') 'PPA_WU05_PERCH20_RESTART_EXACT=PASS'
  write(*,'(a)') 'PPA_WU05_PERCH20_RESTART_GATE=PASS'

contains

  subroutine configure_template(t)
    type(fmr_template_t),intent(out)::t
    t%template_id=52020_int64
    t%physics_topology_id=52021_int64
    t%vertical_layout_id=52022_int64
    t%state_layout_id=52023_int64
    t%solver_interface_id=52024_int64
    t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_MACROPORE
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_MACROPORE_REDUCTION
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine configure_column(c,t)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(in)::t
    c%column_id=column_id
    c%template_id=t%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine

  subroutine configure_physical(state)
    type(fmr_b110_physical_state_t),intent(out)::state
    logical::state_ok
    state%active_nodes=3
    allocate(state%pressure_head(3),state%water_content(3),state%macropore)
    state%pressure_head=[0.25_real64,-3.5_real64,1.0_real64]
    state%water_content=[0.42_real64,0.31_real64,0.44_real64]
    state%ponding_depth=0.0_real64
    state%groundwater_level=-2.0_real64
    call state%macropore%initialize(1,3,state_ok)
    call require(state_ok,'macropore initialize')
    state%macropore%icp_bottom_domain=[3]
    state%macropore%volume_domain_cp=0.20_real64
    state%macropore%water_domain_cp=0.0_real64
    state%macropore%water_domain_cp(1,3)=0.05_real64
  end subroutine

  subroutine verify_reduction_state(state,expected,label)
    class(transaction_state_t),intent(in)::state
    type(macropore_reduction_continuation_t),intent(in)::expected
    character(len=*),intent(in)::label
    select type(s=>state)
    type is(fmr_b110_macropore_reduction_state_t)
      call require(s%reduction_continuation%valid(),trim(label)//' valid')
      call require(s%reduction_continuation%level==expected%level,trim(label)//' level')
      call require(s%reduction_continuation%stable_steps==expected%stable_steps,trim(label)//' stable steps')
      call require(same_bits(s%reduction_continuation%previous_dt,expected%previous_dt),trim(label)//' previous dt')
      call require(allocated(s%macropore) .and. s%macropore%ready(),trim(label)//' physical macropore')
    class default
      call require(.false.,trim(label)//' dynamic type')
    end select
  end subroutine

  pure elemental logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    integer(int64)::ia,ib
    ia=transfer(a,ia); ib=transfer(b,ib); equal=ia==ib
  end function

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH20_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program test_ppa_wu05_perch20_restart_lifecycle
