module mod_fmr_crop_certified_germination_moisture
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t,kernel_parameter_identity_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t
  use mod_crop_b111_pressure_head_average, only: compute_b111_pressure_head_average,CROP_HAVG_OK
  implicit none
  private
  integer, parameter, public :: CROP_CERT_GERM_OK=0,CROP_CERT_GERM_INVALID=1, &
       CROP_CERT_GERM_STALE=2,CROP_CERT_GERM_UNCERTIFIED=3, &
       CROP_CERT_GERM_PHYSICAL=4,CROP_CERT_GERM_DEPTH=5
  public :: sample_certified_committed_germination_head
contains
  ! SWGERM=2 moisture sampling only. No caller dz/head; no heat dependency.
  ! The accepted daily atmospheric TAV must be separately authenticated
  ! before a full crop germination transition may be published.
  subroutine sample_certified_committed_germination_head(committed,lineage,revision, &
       time,zgerm,average_head,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time,zgerm
    real(real64), intent(out) :: average_head
    integer, intent(out) :: status
    type(kernel_parameter_identity_t) :: identity
    class(transaction_state_t), allocatable :: physical
    logical :: available
    integer :: hstatus
    real(real64) :: accepted_time
    average_head=0.0_real64
    status=CROP_CERT_GERM_INVALID
    if(lineage<=0_int64.or.revision<0_int64) return
    if(.not.ieee_is_finite(time).or..not.ieee_is_finite(zgerm)) return
    status=CROP_CERT_GERM_STALE
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(committed%current_lineage_id()/=lineage.or.committed%current_revision()/=revision) return
    call committed%current_time(accepted_time,available)
    if(.not.available.or..not.ieee_is_finite(accepted_time)) return
    if(transfer(time,0_int64)/=transfer(accepted_time,0_int64)) return
    status=CROP_CERT_GERM_UNCERTIFIED
    call committed%certified_parameter_identity(identity,available)
    if(.not.available.or..not.identity%valid) return
    if(.not.allocated(identity%dz)) return
    status=CROP_CERT_GERM_PHYSICAL
    call committed%snapshot(physical,available)
    if(.not.available) return
    select type(physical)
    type is(fmr_b110_physical_state_t)
      call sample(physical)
    type is(fmr_b110_temporal_indicator_state_t)
      call sample(physical)
    class default
      return
    end select
  contains
    subroutine sample(state)
      class(fmr_b110_physical_state_t), intent(in) :: state
      if(state%active_nodes/=identity%active_nodes) return
      if(.not.allocated(state%pressure_head).or..not.allocated(state%water_content)) return
      if(size(state%pressure_head)/=identity%active_nodes.or. &
           size(state%water_content)/=identity%active_nodes) return
      if(.not.all(ieee_is_finite(state%pressure_head)).or. &
           .not.all(ieee_is_finite(state%water_content))) return
      call compute_b111_pressure_head_average(zgerm,identity%dz, &
           state%pressure_head,average_head,hstatus)
      if(hstatus/=CROP_HAVG_OK) then
        average_head=0.0_real64
        status=CROP_CERT_GERM_DEPTH
        return
      end if
      status=CROP_CERT_GERM_OK
    end subroutine
  end subroutine
end module
