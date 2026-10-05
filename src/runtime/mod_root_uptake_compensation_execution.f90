module mod_root_uptake_compensation_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t
  use mod_root_uptake_compensation, only: root_compensation_config_t, root_compensation_diagnostics_t, &
       compose_jarvis_root_uptake, ROOT_COMP_OK, ROOT_COMP_OFF, ROOT_COMP_JARVIS, ROOT_COMP_WALSUM, &
       root_walsum_geometry_t, evaluate_walsum_geometry
  implicit none
  private
  integer,parameter,public::ROOT_COMP_EXEC_OK=0,ROOT_COMP_EXEC_INPUT=1,ROOT_COMP_EXEC_PHYSICS=2
  public::apply_root_uptake_compensation
contains
  subroutine apply_root_uptake_compensation(config,ptra,base_fluxes,base_diagnostics,oxygen_reduction_total, &
       final_fluxes,compensation_diagnostics,status,geometry,node_thickness_cm,salinity_reduction_total)
    type(root_compensation_config_t),intent(in)::config
    real(real64),intent(in)::ptra,oxygen_reduction_total
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_diagnostics_t),intent(in)::base_diagnostics
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    type(root_compensation_diagnostics_t),intent(out)::compensation_diagnostics
    integer,intent(out)::status
    type(root_walsum_geometry_t),optional,intent(in)::geometry
    real(real64),optional,intent(in)::node_thickness_cm(:)
    real(real64),optional,intent(in)::salinity_reduction_total
    real(real64)::salt_reduction
    type(root_compensation_config_t)::effective_config
    integer::comp_status,deepest_node

    salt_reduction=0.0_real64
    if(present(salinity_reduction_total))salt_reduction=salinity_reduction_total
    if(.not.ieee_is_finite(salt_reduction).or.salt_reduction<0.0_real64)then
      final_fluxes=root_water_uptake_flux_result_t()
      compensation_diagnostics=root_compensation_diagnostics_t()
      status=ROOT_COMP_EXEC_INPUT
      return
    end if
    if(config%method==ROOT_COMP_OFF) then
      final_fluxes=base_fluxes
      compensation_diagnostics=root_compensation_diagnostics_t()
      if(allocated(base_fluxes%root_extraction_sink)) then
        compensation_diagnostics%uncompensated_uptake=sum(base_fluxes%root_extraction_sink)
        compensation_diagnostics%compensated_uptake=compensation_diagnostics%uncompensated_uptake
      end if
      compensation_diagnostics%drought_reduction_total=base_diagnostics%drought_reduction_total
      compensation_diagnostics%oxygen_reduction_total=oxygen_reduction_total
      compensation_diagnostics%salinity_reduction_total=salt_reduction
      status=ROOT_COMP_EXEC_OK
      return
    end if

    effective_config=config
    if(config%method==ROOT_COMP_WALSUM) then
      final_fluxes=root_water_uptake_flux_result_t()
      compensation_diagnostics=root_compensation_diagnostics_t()
      status=ROOT_COMP_EXEC_INPUT
      if(.not.present(geometry).or..not.present(node_thickness_cm)) return
      if(.not.allocated(base_fluxes%root_extraction_sink)) return
      if(size(base_fluxes%root_extraction_sink)/=size(node_thickness_cm)) return
      call evaluate_walsum_geometry(geometry,node_thickness_cm,effective_config%alpha_critical,deepest_node,comp_status)
      if(comp_status/=ROOT_COMP_OK) return
      if(any(base_fluxes%root_extraction_sink(deepest_node+1:)/=0.0_real64)) return
      effective_config%method=ROOT_COMP_JARVIS
    end if
    call compose_jarvis_root_uptake(effective_config,ptra,base_fluxes,base_diagnostics%drought_reduction_total, &
         oxygen_reduction_total,final_fluxes,compensation_diagnostics,comp_status,salt_reduction)
    if(comp_status/=ROOT_COMP_OK) then
      final_fluxes=root_water_uptake_flux_result_t()
      status=ROOT_COMP_EXEC_PHYSICS
      return
    end if
    status=ROOT_COMP_EXEC_OK
  end subroutine
end module
