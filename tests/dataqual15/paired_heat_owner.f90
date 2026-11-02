! Matched explicit component inputs, not accepted application intervals.
program paired_heat_owner
 use iso_fortran_env, only: real64
 use MOD_SoilTemperature, only: temperature_numeric,tsoil,heacap,heacon,tetop,swtopbhea,swbotbhea
 use MOD_grid, only: numnod,numlay,layer,z,dz,disnod
 use MOD_texture_orgmat, only: orgmat,pclay,psand,psilt
 use variables, only: theta,thetm1,thetas,thetsl,dt
 use atmosphere_interface, only: tav
 use MOD_snow, only: ssnow
 use mod_process_hydraulic_view, only: process_hydraulic_view_t
 use mod_restricted_soil_temperature
 implicit none
 type(soil_temperature_parameters_t)::p
 type(soil_temperature_state_t)::initial,trial
 type(soil_temperature_forcing_t)::forcing
 type(soil_temperature_numerical_config_t)::numerical
 type(soil_temperature_workspace_t)::workspace
 type(soil_temperature_result_t)::result
 type(soil_temperature_diagnostics_t)::diagnostics
 type(process_hydraulic_view_t)::left,right
 real(real64),allocatable::porosity(:),head(:),theta0(:),theta1(:),old(:),new(:)
 real(real64),allocatable::sand(:),silt(:),clay(:),organic(:),zz(:),ddz(:),distance(:)
 real(real64)::step,air,temp_error,capacity_error,stock,solid,c0,c1,physical_gap,original_boundary,boundary_error
 integer::n,cases,unit,id,day,kind,j,k,status
 character(2048)::path
 call get_command_argument(1,path);open(newunit=unit,file=trim(path),status='old')
 read(unit,*)n,cases
 if(n/=113.or.cases/=432)error stop 'explicit input scope'
 allocate(zz(n),ddz(n),distance(n),porosity(n),head(n),theta0(n),theta1(n),old(n))
 allocate(sand(n),silt(n),clay(n),organic(n))
 read(unit,*)zz;read(unit,*)ddz;read(unit,*)distance;read(unit,*)porosity
 read(unit,*)sand;read(unit,*)silt;read(unit,*)clay;read(unit,*)organic
 call initialize_soil_temperature_from_texture(ddz,distance,porosity,sand,silt,clay,organic,p,status)
 if(status/=0)error stop 'current texture initialization'
 numnod=n;numlay=0;z(1:n)=zz;dz(1:n)=ddz;disnod(1:n)=distance;thetas(1:n)=porosity
 ! Preserve every node texture; compress identical layers only for B1 arrays.
 do j=1,n
  k=1
  do while(k<=numlay)
   if(psand(k)==sand(j).and.psilt(k)==silt(j).and.pclay(k)==clay(j).and. &
      orgmat(k)==organic(j).and.thetsl(k)==porosity(j))exit
   k=k+1
  end do
  if(k>numlay)then
   numlay=k
   if(numlay>size(thetsl))error stop 'original layer capacity'
   psand(k)=sand(j);psilt(k)=silt(j);pclay(k)=clay(j);orgmat(k)=organic(j);thetsl(k)=porosity(j)
  end if
  layer(j)=k
 end do
 ssnow=0d0;swtopbhea=1;swbotbhea=1
 call temperature_numeric(11)
 forcing%top_boundary_mode=1;forcing%bottom_boundary_mode=1
 left%active_nodes=n;left%ponding_depth=0d0;left%groundwater_level=-100d0
 do id=1,cases
  read(unit,*)day,kind,step,air
  read(unit,*)head;read(unit,*)theta0;read(unit,*)theta1;read(unit,*)old
  left%pressure_head=head;left%water_content=theta0;right=left;right%water_content=theta1
  call initialize_soil_temperature_state(old,initial,status)
  if(status/=0)error stop 'current initial state'
  forcing%air_temperature_c=air
  call trial_restricted_soil_temperature(p,numerical,forcing,left,right,initial,0d0,step, &
   workspace,trial,result,diagnostics)
  if(result%status/=0.or..not.result%produced)error stop 'current heat solve'
  call copy_soil_temperature_profile(trial,new,status)
  if(status/=0)error stop 'current output'
  theta(1:n)=theta1;thetm1(1:n)=theta0;tsoil(1:n)=old;dt=step;tav=air
  call temperature_numeric(2)
  temp_error=maxval(abs(new-tsoil(1:n)))
  capacity_error=maxval(abs(workspace%heat_capacity_j_cm3_k-heacap(1:n)))
  if(temp_error>1d-11.or.capacity_error>1d-13)error stop 'matched owner mismatch'
  stock=0d0
  do j=1,n
   solid=p%f_quartz(j)*2.128d0+p%f_clay(j)*2.385d0+p%f_organic(j)*2.496d0
   c0=solid+theta0(j)*4.18d0+max(0d0,porosity(j)-theta0(j))*.001212d0
   c1=solid+theta1(j)*4.18d0+max(0d0,porosity(j)-theta1(j))*.001212d0
   stock=stock+ddz(j)*(c1*tsoil(j)-c0*old(j))
  end do
  original_boundary=step*heacon(1)*(tetop-tsoil(1))/distance(1)
  physical_gap=stock-original_boundary
  boundary_error=abs(original_boundary-result%boundary_energy_into_soil_j_cm2)
  if(boundary_error>1d-10)error stop 'matched conduction boundary mismatch'
  write(*,'(a,i0,a,i0,6(a,es25.17e3))')'PAIR,',id,',',kind,',',temp_error,',',capacity_error, &
   ',',physical_gap,',',result%energy_residual_j_cm2,',',result%sensible_storage_change_j_cm2,',',boundary_error
 end do
 print '(a)','MATCHED_CURRENT_AND_UNMODIFIED_B111_HEAT_OWNERS_COMPLETE'
end program
