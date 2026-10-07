module mod_fmr_oxygen_reproduction_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_root_oxygen_reproduction_response, only: root_oxygen_reproduction_parameters_t, &
       evaluate_root_oxygen_reproduction_profile, ROOT_OXYGEN_REPRO_OK
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_uptake_oxygen_composition, only: compose_root_sink_with_oxygen_factor, ROOT_OXYGEN_COMPOSE_OK
  implicit none
  private

  integer, parameter, public :: FMR_OXYGEN_REPRO_EXEC_OK=0
  integer, parameter, public :: FMR_OXYGEN_REPRO_EXEC_INPUT=1
  integer, parameter, public :: FMR_OXYGEN_REPRO_EXEC_PHYSICS=2

  public :: fmr_apply_oxygen_reproduction_to_root_sink

contains

  subroutine fmr_apply_oxygen_reproduction_to_root_sink(parameters,hydraulic,thermal,rooted_nodes, &
       base_fluxes,final_fluxes,status,oxygen_factors)
    type(root_oxygen_reproduction_parameters_t), intent(in) :: parameters
    type(process_hydraulic_view_t), intent(in) :: hydraulic
    type(soil_temperature_field_view_t), intent(in) :: thermal
    integer, intent(in) :: rooted_nodes
    type(root_water_uptake_flux_result_t), intent(in) :: base_fluxes
    type(root_water_uptake_flux_result_t), intent(out) :: final_fluxes
    integer, intent(out) :: status
    real(real64), allocatable, optional, intent(out) :: oxygen_factors(:)

    real(real64), allocatable :: factors(:), temp_c(:)
    integer :: n, component_status, compose_status

    final_fluxes=root_water_uptake_flux_result_t()
    status=FMR_OXYGEN_REPRO_EXEC_INPUT
    if(.not.parameters%ready())return
    n=parameters%active_nodes()
    if(hydraulic%active_nodes/=n.or.thermal%active_nodes/=n)return
    if(rooted_nodes<0.or.rooted_nodes>n)return
    if(.not.allocated(hydraulic%water_content).or..not.allocated(thermal%temperature_c))return
    if(size(hydraulic%water_content)/=n.or.size(thermal%temperature_c)/=n)return

    if(rooted_nodes==0)then
      final_fluxes=base_fluxes
      if(present(oxygen_factors))allocate(oxygen_factors(0))
      status=FMR_OXYGEN_REPRO_EXEC_OK
      return
    end if

    if(.not.allocated(base_fluxes%root_extraction_sink))return
    if(size(base_fluxes%root_extraction_sink)<rooted_nodes)return

    allocate(temp_c(n))
    temp_c=thermal%temperature_c
    call evaluate_root_oxygen_reproduction_profile(parameters,hydraulic%water_content,temp_c, &
         rooted_nodes,factors,component_status)
    if(component_status/=ROOT_OXYGEN_REPRO_OK)then
      status=FMR_OXYGEN_REPRO_EXEC_PHYSICS
      return
    end if

    call compose_root_sink_with_oxygen_factor(base_fluxes,rooted_nodes,factors,final_fluxes,compose_status)
    if(compose_status/=ROOT_OXYGEN_COMPOSE_OK)then
      final_fluxes=root_water_uptake_flux_result_t()
      status=FMR_OXYGEN_REPRO_EXEC_INPUT
      return
    end if
    if(present(oxygen_factors))oxygen_factors=factors
    status=FMR_OXYGEN_REPRO_EXEC_OK
  end subroutine

end module mod_fmr_oxygen_reproduction_execution
