module mod_fmr_crop_preemergence_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_crop_preemergence_owner, only: crop_preemergence_parameters_t, crop_preemergence_daily_forcing_t, &
       GERMINATION_TEMPERATURE_WATER
  implicit none
  private

  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_OK=0
  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_INVALID_PARAMETERS=1
  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_INVALID_HYDRAULIC=2
  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_INVALID_THERMAL=3
  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_INVALID_GEOMETRY=4
  integer, parameter, public :: FMR_PREEMERGENCE_BINDING_DEPTH_OUTSIDE_PROFILE=5

  real(real64), parameter :: B111_SMALL=1.0e-6_real64
  real(real64), parameter :: B111_NODE_EPS=1.0e-8_real64

  public :: fmr_bind_crop_preemergence_forcing
  public :: b111_average_pressure_head_to_depth

contains

  subroutine fmr_bind_crop_preemergence_forcing(parameters,hydraulic,thermal,zbotcp_cm,dz_cm, &
       average_air_temperature_c,forcing,status)
    type(crop_preemergence_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic
    type(soil_temperature_field_view_t), intent(in) :: thermal
    real(real64), intent(in) :: zbotcp_cm(:),dz_cm(:)
    real(real64), intent(in) :: average_air_temperature_c
    type(crop_preemergence_daily_forcing_t), intent(out) :: forcing
    integer, intent(out) :: status

    integer :: node,local_status,n
    logical :: need_hydraulic,need_geometry

    forcing=crop_preemergence_daily_forcing_t()
    status=FMR_PREEMERGENCE_BINDING_INVALID_PARAMETERS
    if(.not.parameters%ready())return
    if(.not.ieee_is_finite(average_air_temperature_c))return

    forcing%average_air_temperature_c=average_air_temperature_c

    need_hydraulic=parameters%preparation_enabled.or.parameters%sowing_enabled.or. &
         parameters%germination_mode==GERMINATION_TEMPERATURE_WATER
    need_geometry=need_hydraulic.or.parameters%sowing_enabled
    if(.not.need_hydraulic.and..not.parameters%sowing_enabled)then
      status=FMR_PREEMERGENCE_BINDING_OK
      return
    end if

    n=hydraulic%active_nodes
    if(need_hydraulic)then
      status=FMR_PREEMERGENCE_BINDING_INVALID_HYDRAULIC
      if(n<=0.or..not.allocated(hydraulic%pressure_head))return
      if(size(hydraulic%pressure_head)/=n.or.any(.not.ieee_is_finite(hydraulic%pressure_head)))return
    else
      n=thermal%active_nodes
    end if

    if(need_geometry)then
      status=FMR_PREEMERGENCE_BINDING_INVALID_GEOMETRY
      if(size(zbotcp_cm)/=n.or.size(dz_cm)/=n)return
      if(any(.not.ieee_is_finite(zbotcp_cm)).or.any(.not.ieee_is_finite(dz_cm)).or.any(dz_cm<=0.0_real64))return
    end if

    if(parameters%preparation_enabled)then
      call b111_average_pressure_head_to_depth(hydraulic%pressure_head,dz_cm, &
           parameters%preparation_monitor_depth_cm,forcing%preparation_average_head_cm,local_status)
      if(local_status/=FMR_PREEMERGENCE_BINDING_OK)then;status=local_status;return;end if
    end if

    if(parameters%sowing_enabled)then
      call b111_average_pressure_head_to_depth(hydraulic%pressure_head,dz_cm, &
           parameters%sowing_head_monitor_depth_cm,forcing%sowing_average_head_cm,local_status)
      if(local_status/=FMR_PREEMERGENCE_BINDING_OK)then;status=local_status;return;end if

      status=FMR_PREEMERGENCE_BINDING_INVALID_THERMAL
      if(thermal%active_nodes/=n.or..not.allocated(thermal%temperature_c))return
      if(size(thermal%temperature_c)/=n.or.any(.not.ieee_is_finite(thermal%temperature_c)))return

      node=1
      do
        if(node>n)then
          status=FMR_PREEMERGENCE_BINDING_DEPTH_OUTSIDE_PROFILE
          return
        end if
        if(zbotcp_cm(node)<parameters%sowing_temperature_monitor_depth_cm+B111_NODE_EPS)exit
        node=node+1
      end do
      forcing%sowing_soil_temperature_c=thermal%temperature_c(node)
    end if

    if(parameters%germination_mode==GERMINATION_TEMPERATURE_WATER)then
      call b111_average_pressure_head_to_depth(hydraulic%pressure_head,dz_cm, &
           parameters%germination_head_monitor_depth_cm,forcing%germination_average_head_cm,local_status)
      if(local_status/=FMR_PREEMERGENCE_BINDING_OK)then;status=local_status;return;end if
    end if

    status=FMR_PREEMERGENCE_BINDING_OK
  end subroutine

  subroutine b111_average_pressure_head_to_depth(pressure_head_cm,dz_cm,z_monitor_cm,value,status)
    real(real64), intent(in) :: pressure_head_cm(:),dz_cm(:),z_monitor_cm
    real(real64), intent(out) :: value
    integer, intent(out) :: status

    integer :: node,n
    real(real64) :: remaining,pf_average,weight

    value=0.0_real64
    status=FMR_PREEMERGENCE_BINDING_INVALID_GEOMETRY
    n=size(pressure_head_cm)
    if(n<=0.or.size(dz_cm)/=n)return
    if(any(.not.ieee_is_finite(pressure_head_cm)).or.any(.not.ieee_is_finite(dz_cm)).or. &
       any(dz_cm<=0.0_real64).or..not.ieee_is_finite(z_monitor_cm).or.z_monitor_cm>0.0_real64)return

    ! Literal B1.11 SWAP/functions.f90 H_AVERAGE.
    if(abs(z_monitor_cm)<B111_SMALL)then
      pf_average=log10(max(1.0_real64,-pressure_head_cm(1)))
      value=-10.0_real64**pf_average
      status=FMR_PREEMERGENCE_BINDING_OK
      return
    end if

    remaining=-z_monitor_cm
    if(remaining>sum(dz_cm)+B111_SMALL)then
      status=FMR_PREEMERGENCE_BINDING_DEPTH_OUTSIDE_PROFILE
      return
    end if

    node=0
    pf_average=0.0_real64
    do while(remaining>0.0_real64)
      node=node+1
      if(node>n)then
        status=FMR_PREEMERGENCE_BINDING_DEPTH_OUTSIDE_PROFILE
        return
      end if
      weight=min(remaining,dz_cm(node))/(-z_monitor_cm)
      pf_average=pf_average+log10(max(1.0_real64,-pressure_head_cm(node)))*weight
      remaining=remaining-dz_cm(node)
    end do
    value=-10.0_real64**pf_average
    if(.not.ieee_is_finite(value))then
      value=0.0_real64
      status=FMR_PREEMERGENCE_BINDING_INVALID_HYDRAULIC
      return
    end if
    status=FMR_PREEMERGENCE_BINDING_OK
  end subroutine

end module mod_fmr_crop_preemergence_binding
