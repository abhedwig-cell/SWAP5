module mod_fmr_crop_certified_hydrothermal_forcing
  use, intrinsic :: iso_fortran_env, only: real64,int64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_transaction_reference, only: transaction_state_t
  use mod_kernel_transactions, only: kernel_committed_state_t,kernel_parameter_identity_t
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
       fmr_b110_temporal_indicator_state_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t, &
       build_soil_temperature_field_view, SOIL_TEMP_OK
  use mod_crop_b110_grid_sowing_preflight, only: preflight_b110_grid_sowing_node,CROP_GRID_SOW_OK
  use mod_crop_b111_pressure_head_average, only: compute_b111_pressure_head_average,CROP_HAVG_OK
  implicit none
  private
  integer, parameter, public :: CROP_CERT_FORCE_OK=0, CROP_CERT_FORCE_INVALID=1, &
       CROP_CERT_FORCE_UNCERTIFIED=2,CROP_CERT_FORCE_STALE=3, &
       CROP_CERT_FORCE_GRID=4,CROP_CERT_FORCE_HEAT=5
  public :: sample_certified_committed_crop_hydrothermal_forcing
contains
  ! One read-only accepted F-KT clone, one owner-certified B110 z/dz and
  ! source-faithful B1.11 zprep/zsow pF averages and ztempsow/soil heat.
  ! Does not authorize or publish crop events or accepted atmospheric tav.
  subroutine sample_certified_committed_crop_hydrothermal_forcing(committed,lineage,revision,time, &
       zprep,zsow,ztempsow,hprep_avg,hsow_avg,sow_soil_temperature,nodsow,status)
    type(kernel_committed_state_t), intent(in) :: committed
    integer(int64), intent(in) :: lineage,revision
    real(real64), intent(in) :: time,zprep,zsow,ztempsow
    real(real64), intent(out) :: hprep_avg,hsow_avg,sow_soil_temperature
    integer, intent(out) :: nodsow,status
    type(kernel_parameter_identity_t) :: identity
    class(transaction_state_t), allocatable :: physical
    type(soil_temperature_field_view_t) :: heat
    real(real64) :: accepted_time,prep,sow
    integer :: node_status,heat_status,avg_status
    logical :: available
    nodsow=0
    hprep_avg=0.0_real64
    hsow_avg=0.0_real64
    sow_soil_temperature=0.0_real64
    status=CROP_CERT_FORCE_INVALID
    if(lineage<=0_int64.or.revision<0_int64) return
    if(.not.ieee_is_finite(time).or..not.ieee_is_finite(zprep).or. &
         .not.ieee_is_finite(zsow).or..not.ieee_is_finite(ztempsow)) return
    status=CROP_CERT_FORCE_STALE
    if(.not.committed%ready().or..not.committed%time_is_bound()) return
    if(committed%current_lineage_id()/=lineage.or.committed%current_revision()/=revision) return
    call committed%current_time(accepted_time,available)
    if(.not.available.or..not.ieee_is_finite(accepted_time)) return
    if(transfer(time,0_int64)/=transfer(accepted_time,0_int64)) return
    status=CROP_CERT_FORCE_UNCERTIFIED
    call committed%certified_parameter_identity(identity,available)
    if(.not.available.or..not.identity%heat_enabled) return
    status=CROP_CERT_FORCE_GRID
    call preflight_b110_grid_sowing_node(ztempsow,identity%z,identity%dz,nodsow,node_status)
    if(node_status/=CROP_GRID_SOW_OK) then
      nodsow=0
      return
    end if
    call committed%snapshot(physical,available)
    status=CROP_CERT_FORCE_HEAT
    if(.not.available) return
    select type(physical)
    type is(fmr_b110_physical_state_t)
      call extract(physical)
    type is(fmr_b110_temporal_indicator_state_t)
      call extract(physical)
    class default
      nodsow=0
    end select
    if(status/=CROP_CERT_FORCE_OK) then
      nodsow=0
      hprep_avg=0.0_real64
      hsow_avg=0.0_real64
      sow_soil_temperature=0.0_real64
    end if
  contains
    subroutine extract(state)
      class(fmr_b110_physical_state_t), intent(in) :: state
      if(state%active_nodes/=identity%active_nodes) return
      if(.not.allocated(state%pressure_head).or..not.allocated(state%water_content)) return
      if(size(state%pressure_head)/=state%active_nodes.or. &
           size(state%water_content)/=state%active_nodes) return
      if(.not.all(ieee_is_finite(state%pressure_head)).or. &
           .not.all(ieee_is_finite(state%water_content))) return
      if(.not.allocated(state%soil_temperature)) return
      call build_soil_temperature_field_view(state%soil_temperature,heat,heat_status)
      if(heat_status/=SOIL_TEMP_OK.or.heat%active_nodes/=state%active_nodes) return
      if(.not.all(ieee_is_finite(heat%temperature_c))) return
      call compute_b111_pressure_head_average(zprep,identity%dz,state%pressure_head,prep,avg_status)
      if(avg_status/=CROP_HAVG_OK) then
        status=CROP_CERT_FORCE_GRID
        nodsow=0
        return
      end if
      call compute_b111_pressure_head_average(zsow,identity%dz,state%pressure_head,sow,avg_status)
      if(avg_status/=CROP_HAVG_OK) then
        status=CROP_CERT_FORCE_GRID
        nodsow=0
        return
      end if
      hprep_avg=prep
      hsow_avg=sow
      sow_soil_temperature=heat%temperature_c(nodsow)
      status=CROP_CERT_FORCE_OK
    end subroutine
  end subroutine
end module
