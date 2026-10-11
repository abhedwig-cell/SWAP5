module mod_fmr_crop_certified_sowing_source
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_parameter_identity_t
  use mod_crop_b110_grid_sowing_preflight, only: preflight_b110_grid_sowing_node, CROP_GRID_SOW_OK
  use mod_fmr_crop_atomic_accepted_hydroheat, only: sample_committed_crop_hydroheat, CROP_HYDROHEAT_OK
  implicit none
  private
  integer, parameter, public :: CROP_CERT_SOW_OK=0, CROP_CERT_SOW_INVALID=1, &
       CROP_CERT_SOW_UNCERTIFIED=2, CROP_CERT_SOW_GRID=3, CROP_CERT_SOW_PHYSICAL=4
  public :: sample_certified_committed_sowing_source
contains
  ! This read-only route does not accept caller-provided z, dz, nodsow or SWHEA.
  ! F-KT must hold a certified B110 identity from its initialization/restart.
  subroutine sample_certified_committed_sowing_source(committed,lineage,revision,time,ztempsow, &
       node,pressure_head,soil_temperature,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time,ztempsow
    integer, intent(out) :: node,status
    real(real64), intent(out) :: pressure_head,soil_temperature
    type(kernel_parameter_identity_t) :: identity
    integer :: grid_status,hydro_status
    logical :: available
    node=0
    pressure_head=0.0_real64
    soil_temperature=0.0_real64
    status=CROP_CERT_SOW_INVALID
    if(.not.ieee_is_finite(time).or..not.ieee_is_finite(ztempsow)) return
    if(lineage<=0_int64.or.revision<0_int64) return
    status=CROP_CERT_SOW_UNCERTIFIED
    call committed%certified_parameter_identity(identity,available)
    if(.not.available.or..not.identity%valid) return
    if(.not.identity%heat_enabled) return
    status=CROP_CERT_SOW_GRID
    call preflight_b110_grid_sowing_node(ztempsow,identity%z,identity%dz,node,grid_status)
    if(grid_status/=CROP_GRID_SOW_OK) then
      node=0
      return
    end if
    call sample_committed_crop_hydroheat(committed,lineage,revision,time,node, &
         pressure_head,soil_temperature,hydro_status)
    if(hydro_status/=CROP_HYDROHEAT_OK) then
      status=CROP_CERT_SOW_PHYSICAL
      node=0
      pressure_head=0.0_real64
      soil_temperature=0.0_real64
      return
    end if
    status=CROP_CERT_SOW_OK
  end subroutine
end module
