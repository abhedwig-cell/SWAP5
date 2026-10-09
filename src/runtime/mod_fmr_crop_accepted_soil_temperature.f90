module mod_fmr_crop_accepted_soil_temperature
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: &
       fmr_b110_physical_state_t,fmr_b110_temporal_indicator_state_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t, &
       build_soil_temperature_field_view, SOIL_TEMP_OK
  implicit none
  private
  integer, parameter, public :: CROP_ACCEPTED_TEMP_OK=0, CROP_ACCEPTED_TEMP_INVALID=1, &
       CROP_ACCEPTED_TEMP_MISMATCH=2, CROP_ACCEPTED_TEMP_ABSENT=3, CROP_ACCEPTED_TEMP_NODE=4
  public :: sample_committed_crop_soil_temperature
contains
  ! Read-only F-KT heat-state owner access. No caller-supplied temperature can
  ! substitute for a missing SWHEA/physical heat continuation. The nodsow
  ! grid mapping and atmospheric forcing provenance remain separate.
  subroutine sample_committed_crop_soil_temperature(committed,lineage,revision,time,node,temperature,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time
    integer, intent(in) :: node
    real(real64), intent(out) :: temperature
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: physical
    type(soil_temperature_field_view_t) :: field
    real(real64) :: accepted_time
    integer :: temp_status
    logical :: available
    temperature=0.0_real64
    status=CROP_ACCEPTED_TEMP_INVALID
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(.not.ieee_is_finite(time).or.lineage<=0_int64.or.revision<0_int64) return
    status=CROP_ACCEPTED_TEMP_MISMATCH
    if(committed%current_lineage_id()/=lineage.or.committed%current_revision()/=revision) return
    call committed%current_time(accepted_time,available)
    if(.not.available.or..not.ieee_is_finite(accepted_time)) return
    if(transfer(time,0_int64)/=transfer(accepted_time,0_int64)) return
    call committed%snapshot(physical,available)
    status=CROP_ACCEPTED_TEMP_ABSENT
    if(.not.available) return
    select type (physical)
    type is (fmr_b110_physical_state_t)
      if(.not.allocated(physical%soil_temperature)) return
      call build_soil_temperature_field_view(physical%soil_temperature,field,temp_status)
      if(temp_status/=SOIL_TEMP_OK.or.field%active_nodes/=physical%active_nodes) return
    type is (fmr_b110_temporal_indicator_state_t)
      if(.not.allocated(physical%soil_temperature)) return
      call build_soil_temperature_field_view(physical%soil_temperature,field,temp_status)
      if(temp_status/=SOIL_TEMP_OK.or.field%active_nodes/=physical%active_nodes) return
    class default
      return
    end select
    status=CROP_ACCEPTED_TEMP_NODE
    if(node<1.or.node>field%active_nodes) return
    if(.not.all(ieee_is_finite(field%temperature_c))) return
    temperature=field%temperature_c(node)
    status=CROP_ACCEPTED_TEMP_OK
  end subroutine
end module
