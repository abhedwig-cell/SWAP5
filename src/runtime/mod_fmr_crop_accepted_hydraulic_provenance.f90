module mod_fmr_crop_accepted_hydraulic_provenance
  use, intrinsic :: iso_fortran_env, only: real64, int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_process_hydraulic_view, only: process_hydraulic_view_t, validate_process_hydraulic_view
  use mod_fmr_process_hydraulic_view_binding, only: fmr_build_committed_process_hydraulic_view
  implicit none
  private
  integer, parameter, public :: CROP_HYD_PROV_OK=0, CROP_HYD_PROV_INVALID=1, &
       CROP_HYD_PROV_MISMATCH=2, CROP_HYD_PROV_UNSUPPORTED=3
  type, public :: crop_accepted_hydraulic_provenance_t
    logical :: valid=.false.
    integer(int64) :: lineage_id=0_int64, revision=-1_int64
    real(real64) :: accepted_time=0.0_real64
    type(process_hydraulic_view_t) :: hydraulic
  end type
  public :: bind_committed_crop_hydraulic_provenance
contains
  ! Read-only accepted hydraulic snapshot, never a crop preparation forcing
  ! proposal. Depth/grid averaging requires separately verified B1.11 geometry.
  subroutine bind_committed_crop_hydraulic_provenance(committed,expected_lineage, &
       expected_revision,expected_time,binding,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: expected_lineage,expected_revision
    real(real64), intent(in) :: expected_time
    type(crop_accepted_hydraulic_provenance_t), intent(out) :: binding
    integer, intent(out) :: status
    type(process_hydraulic_view_t) :: view
    real(real64) :: accepted_time
    logical :: available,ok
    binding=crop_accepted_hydraulic_provenance_t()
    status=CROP_HYD_PROV_INVALID
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(expected_lineage<=0_int64.or.expected_revision<0_int64) return
    if(.not.ieee_is_finite(expected_time)) return
    status=CROP_HYD_PROV_MISMATCH
    if(committed%current_lineage_id()/=expected_lineage) return
    if(committed%current_revision()/=expected_revision) return
    call committed%current_time(accepted_time,available)
    if(.not.available.or..not.ieee_is_finite(accepted_time)) return
    if(transfer(expected_time,0_int64)/=transfer(accepted_time,0_int64)) return
    status=CROP_HYD_PROV_UNSUPPORTED
    call fmr_build_committed_process_hydraulic_view(committed,view,available)
    if(.not.available) return
    call validate_process_hydraulic_view(view,ok)
    if(.not.ok) return
    if(.not.all(ieee_is_finite(view%pressure_head))) return
    if(.not.all(ieee_is_finite(view%water_content))) return
    if(.not.ieee_is_finite(view%ponding_depth).or. &
         .not.ieee_is_finite(view%groundwater_level)) return
    binding%lineage_id=expected_lineage
    binding%revision=expected_revision
    binding%accepted_time=accepted_time
    binding%hydraulic=view
    binding%valid=.true.
    status=CROP_HYD_PROV_OK
  end subroutine
end module
