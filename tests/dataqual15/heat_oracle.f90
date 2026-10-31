! Identical snapshot inputs through the two real numeric heat owners.
program grass_heat_oracle
 use iso_fortran_env,only:real64
 use MOD_grid,only:numnod,numlay,layer,z,dz,disnod
 use MOD_swap_base,only:swcalt
 use variables,only:theta,thetm1,thetas,thetsl,dt
 use atmosphere_interface,only:tav
 use MOD_snow,only:ssnow
 use MOD_texture_orgmat,only:psand,psilt,pclay,orgmat
 use MOD_SoilTemperature,only:SoilTemperature,tsoil,heacap,heacon,swtopbhea,swbotbhea
 use mod_column_swp_heat,only:import_column_swp_heat
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_restricted_soil_temperature,only:soil_temperature_parameters_t,soil_temperature_state_t, &
  soil_temperature_forcing_t,soil_temperature_numerical_config_t,soil_temperature_workspace_t, &
  soil_temperature_result_t,soil_temperature_diagnostics_t,initialize_soil_temperature_state, &
  trial_restricted_soil_temperature,copy_soil_temperature_profile
 implicit none
 type(soil_temperature_parameters_t)::parameters
 type(soil_temperature_state_t)::initial,full,half,twice
 type(soil_temperature_forcing_t)::forcing
 type(soil_temperature_numerical_config_t)::numerical
 type(soil_temperature_workspace_t)::workspace
 type(soil_temperature_result_t)::result,half_result
 type(soil_temperature_diagnostics_t)::diagnostics
 type(process_hydraulic_view_t)::water
 real(real64)::porosity(256),sand(256),silt(256),clay(256),organic(256)
 real(real64)::old(113),head(113),moisture(113),full_old(113),half_old(113)
 real(real64),allocatable::current(:),refined(:)
 real(real64)::step,flux,stock,err_t,err_q,err_e,err_half
 integer::unit,io,status,day,nsub,i,k,j,ns,counts(256),layers(256)
 character(2048)::path
 call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='old')
 read(unit,*)numnod;if(numnod/=113)error stop 'source geometry'
 read(unit,*)z(:numnod);read(unit,*)dz(:numnod);read(unit,*)disnod(:numnod)
 call rdinit(74,0,'input.swp');call rdinne('isublay',nsub)
 call rdfinr('ncomp',1,256,counts,256,nsub);call rdfinr('isoillay',1,256,layers,256,nsub)
 numlay=maxval(layers(:nsub));k=0
 do i=1,nsub
  do j=1,counts(i)
   k=k+1;layer(k)=layers(i)
  end do
 end do
 if(k/=numnod)error stop 'source layer map'
 call rdfdor('psand',0d0,1d0,sand,256,numlay);call rdfdor('psilt',0d0,1d0,silt,256,numlay)
 call rdfdor('pclay',0d0,1d0,clay,256,numlay);call rdfdor('orgmat',0d0,1d0,organic,256,numlay)
 call rdfdor('osat',0d0,1d0,porosity,256,numlay);close(74)
 thetsl(:numlay)=porosity(:numlay);thetas(:numnod)=porosity(layer(:numnod))
 psand(:numlay)=sand(:numlay);psilt(:numlay)=silt(:numlay);pclay(:numlay)=clay(:numlay);orgmat(:numlay)=organic(:numlay)
 call import_column_swp_heat('input.swp',dz(:numnod),z(:numnod),disnod(:numnod),thetas(:numnod), &
  parameters,initial,forcing)
 swcalt=2;swtopbhea=1;swbotbhea=1;ssnow=0d0;call SoilTemperature(11)
 water%active_nodes=numnod;water%ponding_depth=0d0;water%groundwater_level=-100d0
 ns=0
 do
  read(unit,*,iostat=io)day,step,tav
  if(io<0)exit
  if(io/=0)error stop 'snapshot header'
  read(unit,*)head;read(unit,*)moisture;read(unit,*)old
  water%pressure_head=head;water%water_content=moisture
  theta(:numnod)=moisture;thetm1(:numnod)=moisture;tsoil(:numnod)=old;dt=step
  call SoilTemperature(2);full_old=tsoil(:numnod)
  flux=heacon(1)*(tav-full_old(1))/disnod(1);stock=sum(heacap(:numnod)*dz(:numnod)*(full_old-old))
  call initialize_soil_temperature_state(old,initial,status)
  if(status/=0)error stop 'native initial snapshot'
  forcing%air_temperature_c=tav
  call trial_restricted_soil_temperature(parameters,numerical,forcing,water,water,initial, &
   0d0,step,workspace,full,result,diagnostics)
  if(result%status/=0.or..not.result%produced)error stop 'native full heat rejected'
  call copy_soil_temperature_profile(full,current,status)
  err_t=maxval(abs(current-full_old));err_q=abs(result%top_heat_flux_into_soil_j_cm2_day-flux)
  err_e=max(abs(result%sensible_storage_change_j_cm2-stock),abs(stock-step*flux))
  tsoil(:numnod)=old;dt=.5d0*step;call SoilTemperature(2);call SoilTemperature(2);half_old=tsoil(:numnod)
  call trial_restricted_soil_temperature(parameters,numerical,forcing,water,water,initial, &
   0d0,.5d0*step,workspace,half,half_result,diagnostics)
  if(half_result%status/=0)error stop 'native half heat rejected'
  call trial_restricted_soil_temperature(parameters,numerical,forcing,water,water,half, &
   .5d0*step,step,workspace,twice,half_result,diagnostics)
  if(half_result%status/=0)error stop 'native second half heat rejected'
  call copy_soil_temperature_profile(twice,refined,status);err_half=maxval(abs(refined-half_old))
  ns=ns+1
  write(*,'(a,i0,7(a,es25.17e3))')'HEAT_PAIR,',day,',',step,',',err_t,',',err_q,',',err_e,',',err_half, &
   ',',maxval(abs(current-refined)),',',maxval(abs(full_old-half_old))
  ! Existing independent FVQ58 component limits, registered before execution.
  if(max(err_t,err_half)>5d-10.or.err_q>5d-10.or.err_e>5d-9)error stop 'source heat operator discrepancy'
 end do
 close(unit);if(ns/=72)error stop 'missing original snapshot/step cases'
 print '(a)','PAIRED_ORIGINAL_CURRENT_HEAT_SNAPSHOTS_PASS'
end program
