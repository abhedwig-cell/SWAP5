module mod_fmr_tillage_joint_restart
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_transaction_reference, only: transaction_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_state_t
  use mod_fmr_committed_restart, only: fmr_committed_restart_bundle_t, &
       fmr_export_committed_restart, fmr_restore_committed_restart, FMR_RESTART_OK
  use mod_fmr_tillage_profile_restart, only: tillage_profile_state_t, tillage_profile_restart_record_t, &
       export_tillage_profile, restore_tillage_profile, TILLAGE_PROFILE_RESTART_OK
  implicit none
  private
  integer, parameter, public :: TILLAGE_JOINT_RESTART_OK = 0
  integer, parameter, public :: TILLAGE_JOINT_RESTART_INVALID = 1
  type, public :: tillage_joint_restart_t
    integer :: schema = 0
    integer(int64) :: column_id = 0_int64
    integer(int64) :: material_id = 0_int64
    type(fmr_committed_restart_bundle_t) :: physical
    type(tillage_profile_restart_record_t) :: management
  end type
  public :: export_tillage_joint_restart, restore_tillage_joint_restart
contains
  subroutine export_tillage_joint_restart(column,template,parameters,physical,profile,event_count, &
       parameter_set_identity,bundle,status)
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(kernel_committed_state_t), intent(in) :: physical
    type(tillage_profile_state_t), intent(in) :: profile
    integer, intent(in) :: event_count
    integer(int64), intent(in) :: parameter_set_identity
    type(tillage_joint_restart_t), intent(out) :: bundle
    integer, intent(out) :: status
    type(tillage_joint_restart_t) :: candidate
    class(transaction_state_t), allocatable :: snapshot
    logical :: available, exported
    integer :: code
    bundle=tillage_joint_restart_t()
    status=TILLAGE_JOINT_RESTART_INVALID
    if (parameters%parameter_set_id <= 0_int64 .or. &
        column%parameter_ref /= parameters%parameter_set_id) return
    call physical%snapshot(snapshot,available)
    if (.not. available .or. .not. allocated(snapshot)) return
    select type (snapshot)
    type is (fmr_b110_physical_state_t)
      if (.not. matching_profile(parameters,snapshot,profile)) return
    class default
      return
    end select
    call export_tillage_profile(profile,event_count,candidate%management,code)
    if (code /= TILLAGE_PROFILE_RESTART_OK) return
    call fmr_export_committed_restart([column],[template],[physical],parameter_set_identity, &
         candidate%physical,exported,code)
    if (.not. exported .or. code /= FMR_RESTART_OK) return
    candidate%schema=1
    candidate%column_id=column%column_id
    candidate%material_id=parameters%parameter_set_id
    bundle=candidate
    status=TILLAGE_JOINT_RESTART_OK
  end subroutine

  subroutine restore_tillage_joint_restart(bundle,column,template,parameters,event_count, &
       parameter_set_identity,physical,profile,restored,status)
    type(tillage_joint_restart_t), intent(in) :: bundle
    type(fmr_logical_column_t), intent(in) :: column
    type(fmr_template_t), intent(in) :: template
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    integer, intent(in) :: event_count
    integer(int64), intent(in) :: parameter_set_identity
    type(kernel_committed_state_t), intent(inout) :: physical
    type(tillage_profile_state_t), intent(inout) :: profile
    logical, intent(out) :: restored
    integer, intent(out) :: status
    type(kernel_committed_state_t) :: candidate_physical(1)
    type(tillage_profile_state_t) :: candidate_profile
    class(transaction_state_t), allocatable :: snapshot
    logical :: valid, available
    integer :: code
    restored=.false.
    status=TILLAGE_JOINT_RESTART_INVALID
    if (bundle%schema /= 1 .or. bundle%column_id /= column%column_id .or. &
        bundle%material_id /= parameters%parameter_set_id .or. &
        column%parameter_ref /= bundle%material_id .or. physical%ready()) return
    call restore_tillage_profile(bundle%management,event_count,parameters%active_nodes,candidate_profile,code)
    if (code /= TILLAGE_PROFILE_RESTART_OK) return
    call fmr_restore_committed_restart(bundle%physical,parameter_set_identity,[column],[template], &
         candidate_physical,valid,code)
    if (.not. valid .or. code /= FMR_RESTART_OK) return
    call candidate_physical(1)%snapshot(snapshot,available)
    if (.not. available .or. .not. allocated(snapshot)) return
    select type (snapshot)
    type is (fmr_b110_physical_state_t)
      if (.not. matching_profile(parameters,snapshot,candidate_profile)) return
    class default
      return
    end select
    physical=candidate_physical(1)
    profile=candidate_profile
    restored=.true.
    status=TILLAGE_JOINT_RESTART_OK
  end subroutine

  logical function matching_profile(parameters,state,profile) result(ok)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters
    type(fmr_b110_physical_state_t), intent(in) :: state
    type(tillage_profile_state_t), intent(in) :: profile
    integer :: i,n
    ok=.false.
    n=parameters%active_nodes
    if (n < 1 .or. state%active_nodes /= n .or. .not. allocated(parameters%cofgen) .or. &
        .not. allocated(state%water_content) .or. .not. allocated(state%pressure_head) .or. &
        .not. allocated(profile%water_content) .or. .not. allocated(profile%pressure_head_cm) .or. &
        .not. allocated(profile%vg)) return
    if (size(parameters%cofgen,1) < 7 .or. size(parameters%cofgen,2) /= n .or. &
        size(state%water_content) /= n .or. size(state%pressure_head) /= n .or. &
        size(profile%water_content) /= n .or. size(profile%pressure_head_cm) /= n .or. &
        size(profile%vg) /= n) return
    if (.not. all(ieee_is_finite(parameters%cofgen(1:7,:))) .or. &
        .not. all(ieee_is_finite(state%water_content)) .or. &
        .not. all(ieee_is_finite(state%pressure_head)) .or. &
        .not. ieee_is_finite(state%ponding_depth)) return
    if (any(abs(state%water_content-profile%water_content) > 1.e-10_real64) .or. &
        any(abs(state%pressure_head-profile%pressure_head_cm) > 1.e-10_real64) .or. &
        abs(state%ponding_depth-profile%ponding_depth_cm) > 1.e-10_real64) return
    do i=1,n
      if (any(abs(parameters%cofgen(1:7,i)-[profile%vg(i)%theta_residual, &
          profile%vg(i)%theta_saturated,profile%vg(i)%saturated_conductivity, &
          profile%vg(i)%alpha,profile%vg(i)%lambda,profile%vg(i)%n,profile%vg(i)%m]) > 1.e-12_real64)) return
    end do
    ok=.true.
  end function
end module
