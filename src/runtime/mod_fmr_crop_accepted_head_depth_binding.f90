module mod_fmr_crop_accepted_head_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_crop_accepted_hydraulic_provenance, only: &
       crop_accepted_hydraulic_provenance_t, bind_committed_crop_hydraulic_provenance, CROP_HYD_PROV_OK
  use mod_crop_b111_pressure_head_average, only: compute_b111_pressure_head_average, CROP_HAVG_OK
  implicit none
  private
  integer, parameter, public :: CROP_HEAD_DEPTH_OK=0, CROP_HEAD_DEPTH_INVALID=1, &
       CROP_HEAD_DEPTH_PROVENANCE=2, CROP_HEAD_DEPTH_GRID=3
  public :: propose_committed_crop_head_depth_average
contains
  ! Bounded read-only composition. Grid dz remains an external untrusted input:
  ! its identity must be independently bound to the accepted soil grid before
  ! this value can authorize a physical crop/lifecycle event.
  subroutine propose_committed_crop_head_depth_average(committed,lineage,revision,time,z,dz, &
       average,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time,z,dz(:)
    real(real64), intent(out) :: average
    integer, intent(out) :: status
    type(crop_accepted_hydraulic_provenance_t) :: snapshot
    integer :: provenance_status,average_status
    average=0.0_real64
    status=CROP_HEAD_DEPTH_INVALID
    if(.not.ieee_is_finite(z).or..not.ieee_is_finite(time)) return
    if(size(dz)<1.or..not.all(ieee_is_finite(dz))) return
    if(any(dz<=0.0_real64)) return
    call bind_committed_crop_hydraulic_provenance(committed,lineage,revision,time, &
         snapshot,provenance_status)
    status=CROP_HEAD_DEPTH_PROVENANCE
    if(provenance_status/=CROP_HYD_PROV_OK.or..not.snapshot%valid) return
    status=CROP_HEAD_DEPTH_GRID
    if(size(dz)/=snapshot%hydraulic%active_nodes) return
    if(z< -sum(dz).or.z>0.0_real64) return
    call compute_b111_pressure_head_average(z,dz,snapshot%hydraulic%pressure_head, &
         average,average_status)
    if(average_status/=CROP_HAVG_OK) then
      average=0.0_real64
      return
    end if
    status=CROP_HEAD_DEPTH_OK
  end subroutine
end module
