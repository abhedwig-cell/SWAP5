! Reevaluate an accepted original heat step with the unchanged SWAP5 heat owner.
program replay_grass_heat_leaf
 use iso_fortran_env, only: real64
 use mod_process_hydraulic_view, only: process_hydraulic_view_t
 use mod_restricted_soil_temperature
 implicit none
 type(soil_temperature_parameters_t) :: parameters
 type(soil_temperature_state_t) :: initial, candidate
 type(soil_temperature_forcing_t) :: forcing
 type(soil_temperature_numerical_config_t) :: numerical
 type(soil_temperature_workspace_t) :: workspace
 type(soil_temperature_result_t) :: result
 type(soil_temperature_diagnostics_t) :: diagnostics
 type(process_hydraulic_view_t) :: left, right
 real(real64), allocatable :: fields(:,:), temperature(:)
 real(real64) :: clock, dt, top
 integer :: n, status, i
 read(*,*) n, clock, dt, top
 allocate(fields(13,n))
 do i=1,n
  read(*,*) fields(:,i)
 end do
 call initialize_soil_temperature_from_texture(fields(1,:),fields(2,:),fields(3,:), &
  fields(4,:),fields(5,:),fields(6,:),fields(7,:),parameters,status)
 if(status/=SOIL_TEMP_OK) error stop 'legacy heat parameters refused'
 left%active_nodes=n
 left%pressure_head=spread(0d0,1,n)
 left%water_content=fields(8,:)
 right=left
 right%water_content=fields(9,:)
 call initialize_soil_temperature_state(fields(10,:),initial,status)
 if(status/=SOIL_TEMP_OK) error stop 'legacy heat state refused'
 forcing%air_temperature_c=top
 forcing%top_boundary_mode=SOIL_TEMP_TOP_AIR_TEMPERATURE
 forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
 call trial_restricted_soil_temperature(parameters,numerical,forcing,left,right,initial,0d0,dt, &
  workspace,candidate,result,diagnostics)
 if(result%status/=SOIL_TEMP_OK.or..not.result%produced) error stop 'legacy heat step refused'
 call copy_soil_temperature_profile(candidate,temperature,status)
 if(status/=SOIL_TEMP_OK) error stop 'heat output refused'
 write(*,'(a,1x,i0,*(1x,es25.17e3))') 'REPLAY_HEAT', maxloc(abs(temperature-fields(11,:)),dim=1), &
  clock,dt,top,maxval(abs(temperature-fields(11,:))), &
  maxval(abs(workspace%heat_capacity_j_cm3_k-fields(12,:))), &
  maxval(abs(workspace%node_conductivity_j_cm_k_day-fields(13,:))),result%energy_residual_j_cm2
end program
