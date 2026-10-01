module mod_fmr_bartholomeus_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t, build_bartholomeus_runtime_view, &
       BARTHOLOMEUS_INPUT_OK
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  use mod_fmr_bartholomeus_activation
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_uptake_oxygen_composition, only: compose_root_sink_with_oxygen_factor, ROOT_OXYGEN_COMPOSE_OK
  implicit none
  private

  integer,parameter,public::FMR_BARTHOLOMEUS_EXEC_OK=0
  integer,parameter,public::FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED=1
  integer,parameter,public::FMR_BARTHOLOMEUS_EXEC_INPUT=2
  integer,parameter,public::FMR_BARTHOLOMEUS_EXEC_PHYSICS=3
  public::fmr_apply_bartholomeus_to_root_sink

contains
  subroutine fmr_apply_bartholomeus_to_root_sink(config,hydraulic,thermal,data,crop,w_root,w_root_z0, &
       atmospheric_ctop,base_fluxes,final_fluxes,status)
    type(fmr_bartholomeus_selection_t),intent(in)::config
    type(process_hydraulic_view_t),intent(in)::hydraulic
    type(soil_temperature_field_view_t),intent(in)::thermal
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    real(real64),intent(in)::w_root(:),w_root_z0(:),atmospheric_ctop
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    integer,intent(out)::status
    type(bartholomeus_runtime_view_t)::view
    real(real64),allocatable::factors(:)
    integer::route,wmode,input_status,compose_status
    logical::ok

    final_fluxes=root_water_uptake_flux_result_t()
    call select_fmr_bartholomeus_route(config,route,wmode)
    if(route==FMR_BARTHOLOMEUS_DISABLED) then
      final_fluxes=base_fluxes
      status=FMR_BARTHOLOMEUS_EXEC_OK
      return
    end if
    if(route/=FMR_BARTHOLOMEUS_ACTIVE) then
      status=FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED;return
    end if

    call build_bartholomeus_runtime_view(hydraulic,thermal,size(w_root),view,input_status)
    if(input_status/=BARTHOLOMEUS_INPUT_OK .or. size(w_root_z0)/=view%rooted_nodes) then
      status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
    end if
    call evaluate_bartholomeus_factors_from_state(view,data,crop,w_root,w_root_z0,atmospheric_ctop,wmode,factors,ok)
    if(.not.ok) then
      status=FMR_BARTHOLOMEUS_EXEC_PHYSICS;return
    end if
    call compose_root_sink_with_oxygen_factor(base_fluxes,view%rooted_nodes,factors,final_fluxes,compose_status)
    if(compose_status/=ROOT_OXYGEN_COMPOSE_OK) then
      final_fluxes=root_water_uptake_flux_result_t()
      status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
    end if
    status=FMR_BARTHOLOMEUS_EXEC_OK
  end subroutine
end module
