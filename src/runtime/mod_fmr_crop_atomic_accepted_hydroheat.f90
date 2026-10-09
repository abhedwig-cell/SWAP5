module mod_fmr_crop_atomic_accepted_hydroheat
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_serialized_reference_backend, only: &
       fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t, &
       build_soil_temperature_field_view, SOIL_TEMP_OK
  implicit none
  private
  integer, parameter, public :: CROP_HYDROHEAT_OK=0, CROP_HYDROHEAT_INVALID=1, &
       CROP_HYDROHEAT_STALE=2, CROP_HYDROHEAT_ABSENT=3, CROP_HYDROHEAT_NODE=4
  public :: sample_committed_crop_hydroheat
contains
  ! Both fields are sampled from ONE detached F-KT committed snapshot.
  ! A node supplied by the caller is NOT yet authenticated to B110 z/dz.
  subroutine sample_committed_crop_hydroheat(committed,lineage,revision,time,node,head,temperature,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time
    integer, intent(in) :: node
    real(real64), intent(out) :: head,temperature
    integer, intent(out) :: status
    class(transaction_state_t), allocatable :: physical
    type(soil_temperature_field_view_t) :: heat
    real(real64) :: accepted_time
    integer :: st
    logical :: available
    head=0.0_real64
    temperature=0.0_real64
    status=CROP_HYDROHEAT_INVALID
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(lineage<=0_int64.or.revision<0_int64.or..not.ieee_is_finite(time)) return
    status=CROP_HYDROHEAT_STALE
    if(committed%current_lineage_id()/=lineage.or.committed%current_revision()/=revision) return
    call committed%current_time(accepted_time,available)
    if(.not.available.or..not.ieee_is_finite(accepted_time)) return
    if(transfer(accepted_time,0_int64)/=transfer(time,0_int64)) return
    call committed%snapshot(physical,available)
    status=CROP_HYDROHEAT_ABSENT
    if(.not.available) return
    select type(physical)
    type is(fmr_b110_physical_state_t)
      call inspect(physical,head,temperature,st)
    type is(fmr_b110_temporal_indicator_state_t)
      call inspect(physical,head,temperature,st)
    class default
      return
    end select
    status=st
  contains
    subroutine inspect(state,h,t,s)
      class(fmr_b110_physical_state_t), intent(in) :: state
      real(real64), intent(out) :: h,t
      integer, intent(out) :: s
      integer :: hstatus
      h=0.0_real64
      t=0.0_real64
      s=CROP_HYDROHEAT_ABSENT
      if(state%active_nodes<=0) return
      if(.not.allocated(state%pressure_head).or..not.allocated(state%water_content)) return
      if(size(state%pressure_head)/=state%active_nodes.or. &
           size(state%water_content)/=state%active_nodes) return
      if(.not.allocated(state%soil_temperature)) return
      call build_soil_temperature_field_view(state%soil_temperature,heat,hstatus)
      if(hstatus/=SOIL_TEMP_OK.or.heat%active_nodes/=state%active_nodes) return
      s=CROP_HYDROHEAT_NODE
      if(node<1.or.node>state%active_nodes) return
      if(.not.all(ieee_is_finite(state%pressure_head))) return
      if(.not.all(ieee_is_finite(state%water_content))) return
      if(.not.all(ieee_is_finite(heat%temperature_c))) return
      h=state%pressure_head(node)
      t=heat%temperature_c(node)
      s=CROP_HYDROHEAT_OK
    end subroutine
  end subroutine
end module
