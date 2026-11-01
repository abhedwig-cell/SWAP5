! Observational driver: unchanged public heat owner, explicit snapshot inputs.
program grass_energy_stock
 use iso_fortran_env,only:real64
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_restricted_soil_temperature,only:soil_temperature_parameters_t,soil_temperature_state_t, &
  soil_temperature_forcing_t,soil_temperature_numerical_config_t,soil_temperature_workspace_t, &
  soil_temperature_result_t,soil_temperature_diagnostics_t,initialize_soil_temperature_state, &
  trial_restricted_soil_temperature,copy_soil_temperature_profile,initialize_soil_temperature_from_texture
 implicit none
 type(soil_temperature_parameters_t)::p
 type(soil_temperature_state_t)::initial,trial
 type(soil_temperature_forcing_t)::forcing
 type(soil_temperature_numerical_config_t)::numerical
 type(soil_temperature_workspace_t)::workspace
 type(soil_temperature_result_t)::result
 type(soil_temperature_diagnostics_t)::diagnostics
 type(process_hydraulic_view_t)::left,right
 real(real64),allocatable::z(:),dz(:),distance(:),porosity(:),head(:),theta0(:),theta1(:),old(:),new(:)
 real(real64),allocatable::sand(:),silt(:),clay(:),organic(:)
 real(real64)::dt,air
 integer::n,cases,unit,id,day,kind,j,status
 character(2048)::path
 call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='old')
 read(unit,*)n,cases
 if(n/=113.or.cases<1)error stop 'energy probe geometry'
 allocate(z(n),dz(n),distance(n),porosity(n),head(n),theta0(n),theta1(n),old(n))
 allocate(sand(n),silt(n),clay(n),organic(n))
 read(unit,*)z;read(unit,*)dz;read(unit,*)distance;read(unit,*)porosity
 read(unit,*)sand;read(unit,*)silt;read(unit,*)clay;read(unit,*)organic
 call initialize_soil_temperature_from_texture(dz,distance,porosity,sand,silt,clay,organic,p,status)
 if(status/=0)error stop 'energy probe literal SWP texture initialization'
 forcing%top_boundary_mode=1;forcing%bottom_boundary_mode=1
 do j=1,n
  write(*,'(a,i0,6(a,es25.17e3))')'PARAM,',j,',',dz(j),',',porosity(j),',',p%f_quartz(j), &
   ',',p%f_clay(j),',',p%f_organic(j),',',distance(j)
 end do
 left%active_nodes=n;left%ponding_depth=0d0;left%groundwater_level=-100d0
 do id=1,cases
  read(unit,*)day,kind,dt,air
  read(unit,*)head;read(unit,*)theta0;read(unit,*)theta1;read(unit,*)old
  left%pressure_head=head;left%water_content=theta0;right=left;right%water_content=theta1
  call initialize_soil_temperature_state(old,initial,status)
  if(status/=0)error stop 'energy probe initial state'
  forcing%air_temperature_c=air
  call trial_restricted_soil_temperature(p,numerical,forcing,left,right,initial,0d0,dt, &
   workspace,trial,result,diagnostics)
  if(result%status/=0.or..not.result%produced.or..not.diagnostics%energy_accounting_complete) &
   error stop 'energy probe real heat trial'
  call copy_soil_temperature_profile(trial,new,status)
  if(status/=0)error stop 'energy probe output'
  write(*,'(a,i0,7(a,es25.17e3))')'ENERGY,',id,',',dt,',',air, &
   ',',result%sensible_storage_change_j_cm2,',',result%boundary_energy_into_soil_j_cm2, &
   ',',result%energy_residual_j_cm2,',',result%top_heat_flux_into_soil_j_cm2_day, &
   ',',result%bottom_heat_flux_into_soil_j_cm2_day
  do j=1,n
   write(*,'(a,i0,a,i0,3(a,es25.17e3))')'NODE,',id,',',j,',',new(j), &
    ',',workspace%heat_capacity_j_cm3_k(j),',',workspace%node_conductivity_j_cm_k_day(j)
  end do
 end do
 close(unit)
 print '(a)','REAL_HEAT_ENERGY_STOCK_OBSERVATIONS_COMPLETE'
end program grass_energy_stock
