module mod_fmr_bartholomeus_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_process_hydraulic_view, only: process_hydraulic_view_t
  use mod_soil_temperature_contract, only: soil_temperature_field_view_t
  use mod_bartholomeus_runtime_input, only: bartholomeus_runtime_view_t, build_bartholomeus_runtime_view, &
       BARTHOLOMEUS_INPUT_OK
  use mod_bartholomeus_parameter_contract, only: BartholomeusImmutableDataset, BartholomeusCropParameters
  use mod_bartholomeus_factor_provider, only: evaluate_bartholomeus_factors_from_state
  use mod_fmr_bartholomeus_activation
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t
  use mod_root_oxygen_reproduction_response, only: root_oxygen_reproduction_parameters_t, &
       evaluate_root_oxygen_reproduction_profile, ROOT_OXYGEN_REPRO_OK
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
       atmospheric_ctop,base_fluxes,final_fluxes,status,oxygen_factors,reproduction_parameters,reproduction_rooted_nodes)
    type(fmr_bartholomeus_selection_t),intent(in)::config
    type(process_hydraulic_view_t),intent(in)::hydraulic
    type(soil_temperature_field_view_t),intent(in)::thermal
    type(BartholomeusImmutableDataset),intent(in)::data
    type(BartholomeusCropParameters),intent(in)::crop
    ! Source inputs: w_root=1/SRL [kg/m]; w_root_z0=wroot_node_top [kg/m3].
    ! Neither array is a normalized uptake/root fraction. The crop owner must
    ! supply them; this routine does not evolve or reconstruct crop state.
    real(real64),intent(in)::w_root(:),w_root_z0(:),atmospheric_ctop
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    integer,intent(out)::status
    real(real64),allocatable,optional,intent(out)::oxygen_factors(:)
    type(root_oxygen_reproduction_parameters_t),optional,intent(in)::reproduction_parameters
    integer,optional,intent(in)::reproduction_rooted_nodes
    type(bartholomeus_runtime_view_t)::view
    real(real64),allocatable::factors(:)
    integer::route,wmode,input_status,compose_status
    logical::ok

    if(present(oxygen_factors)) then
      if(allocated(base_fluxes%root_extraction_sink)) then
        allocate(oxygen_factors(size(base_fluxes%root_extraction_sink)))
        oxygen_factors=1.0_real64
      end if
    end if
    final_fluxes=root_water_uptake_flux_result_t()
    call select_fmr_bartholomeus_route(config,route,wmode)
    if(route==FMR_BARTHOLOMEUS_DISABLED) then
      final_fluxes=base_fluxes
      status=FMR_BARTHOLOMEUS_EXEC_OK
      return
    end if
    if(route/=FMR_BARTHOLOMEUS_ACTIVE .and. route/=FMR_BARTHOLOMEUS_REPRODUCTION) then
      status=FMR_BARTHOLOMEUS_EXEC_UNSUPPORTED;return
    end if

    if(route==FMR_BARTHOLOMEUS_REPRODUCTION) then
      if(.not.present(reproduction_parameters).or..not.present(reproduction_rooted_nodes)) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(.not.allocated(base_fluxes%root_extraction_sink)) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(.not.reproduction_parameters%ready()) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(reproduction_parameters%active_nodes()>size(base_fluxes%root_extraction_sink)) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(reproduction_rooted_nodes<0.or.reproduction_rooted_nodes>reproduction_parameters%active_nodes()) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(reproduction_rooted_nodes<size(base_fluxes%root_extraction_sink)) then
        if(any(abs(base_fluxes%root_extraction_sink(reproduction_rooted_nodes+1:))>tiny(1.0_real64))) then
          status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
        end if
      end if
      if(reproduction_rooted_nodes==0) then
        final_fluxes=base_fluxes
        status=FMR_BARTHOLOMEUS_EXEC_OK
        return
      end if
      if(hydraulic%active_nodes<reproduction_parameters%active_nodes() .or. &
         thermal%active_nodes<reproduction_parameters%active_nodes()) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(.not.allocated(hydraulic%water_content) .or. .not.allocated(thermal%temperature_c)) then
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      call evaluate_root_oxygen_reproduction_profile(reproduction_parameters, &
           hydraulic%water_content(1:reproduction_parameters%active_nodes()), &
           thermal%temperature_c(1:reproduction_parameters%active_nodes()), &
           reproduction_rooted_nodes, factors, input_status)
      if(input_status/=ROOT_OXYGEN_REPRO_OK) then
        status=FMR_BARTHOLOMEUS_EXEC_PHYSICS;return
      end if
      call compose_root_sink_with_oxygen_factor(base_fluxes,reproduction_rooted_nodes,factors, &
           final_fluxes,compose_status)
      if(compose_status/=ROOT_OXYGEN_COMPOSE_OK) then
        final_fluxes=root_water_uptake_flux_result_t()
        status=FMR_BARTHOLOMEUS_EXEC_INPUT;return
      end if
      if(present(oxygen_factors)) then
        if(allocated(oxygen_factors)) deallocate(oxygen_factors)
        allocate(oxygen_factors(size(base_fluxes%root_extraction_sink)))
        oxygen_factors=1.0_real64
        if(reproduction_rooted_nodes>0) oxygen_factors(1:reproduction_rooted_nodes)=factors
      end if
      status=FMR_BARTHOLOMEUS_EXEC_OK
      return
    end if

    ! No extraction requires no oxygen physics or current owner views.
    ! Configuration remains fail-closed because route selection precedes this exit.
    if(size(w_root)==0 .and. size(w_root_z0)==0) then
      final_fluxes=base_fluxes
      status=FMR_BARTHOLOMEUS_EXEC_OK
      return
    end if
    if(allocated(base_fluxes%root_extraction_sink)) then
      if(size(w_root)==size(w_root_z0) .and. size(w_root)<=size(base_fluxes%root_extraction_sink)) then
        if(all(ieee_is_finite(base_fluxes%root_extraction_sink(1:size(w_root))))) then
          if(all(abs(base_fluxes%root_extraction_sink(1:size(w_root)))<=tiny(1.0_real64))) then
            final_fluxes=base_fluxes
            status=FMR_BARTHOLOMEUS_EXEC_OK
            return
          end if
        end if
      end if
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
    if(present(oxygen_factors)) oxygen_factors(1:view%rooted_nodes)=factors
    status=FMR_BARTHOLOMEUS_EXEC_OK
  end subroutine
end module
