module mod_root_uptake_compensation_execution
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_root_water_uptake_process, only: root_water_uptake_flux_result_t, root_water_uptake_diagnostics_t
  use mod_root_uptake_compensation, only: root_compensation_config_t, root_compensation_diagnostics_t, &
       compose_jarvis_root_uptake, ROOT_COMP_OK, ROOT_COMP_OFF
  implicit none
  private
  integer,parameter,public::ROOT_COMP_EXEC_OK=0,ROOT_COMP_EXEC_INPUT=1,ROOT_COMP_EXEC_PHYSICS=2
  public::apply_root_uptake_compensation
contains
  subroutine apply_root_uptake_compensation(config,ptra,base_fluxes,base_diagnostics,oxygen_reduction_total, &
       final_fluxes,compensation_diagnostics,status)
    type(root_compensation_config_t),intent(in)::config
    real(real64),intent(in)::ptra,oxygen_reduction_total
    type(root_water_uptake_flux_result_t),intent(in)::base_fluxes
    type(root_water_uptake_diagnostics_t),intent(in)::base_diagnostics
    type(root_water_uptake_flux_result_t),intent(out)::final_fluxes
    type(root_compensation_diagnostics_t),intent(out)::compensation_diagnostics
    integer,intent(out)::status
    integer::comp_status

    if(config%method==ROOT_COMP_OFF) then
      final_fluxes=base_fluxes
      compensation_diagnostics=root_compensation_diagnostics_t()
      if(allocated(base_fluxes%root_extraction_sink)) then
        compensation_diagnostics%uncompensated_uptake=sum(base_fluxes%root_extraction_sink)
        compensation_diagnostics%compensated_uptake=compensation_diagnostics%uncompensated_uptake
      end if
      compensation_diagnostics%drought_reduction_total=base_diagnostics%drought_reduction_total
      compensation_diagnostics%oxygen_reduction_total=oxygen_reduction_total
      status=ROOT_COMP_EXEC_OK
      return
    end if

    call compose_jarvis_root_uptake(config,ptra,base_fluxes,base_diagnostics%drought_reduction_total, &
         oxygen_reduction_total,final_fluxes,compensation_diagnostics,comp_status)
    if(comp_status/=ROOT_COMP_OK) then
      final_fluxes=root_water_uptake_flux_result_t()
      status=ROOT_COMP_EXEC_PHYSICS
      return
    end if
    status=ROOT_COMP_EXEC_OK
  end subroutine
end module
