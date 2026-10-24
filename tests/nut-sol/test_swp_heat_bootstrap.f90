program test_swp_heat_bootstrap
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
  use mod_column_swp_heat,only:import_column_swp_heat
  use mod_restricted_soil_temperature,only:initialize_soil_temperature_from_texture
  use mod_soil_temperature_contract,only:soil_temperature_parameters_t,soil_temperature_state_t, &
    soil_temperature_forcing_t,soil_temperature_field_view_t,build_soil_temperature_field_view,SOIL_TEMP_OK
  use literal_texture_oracle,only:literal_texture
  implicit none
  type(soil_temperature_parameters_t)::parameters,invalid
  type(soil_temperature_state_t)::state
  type(soil_temperature_forcing_t)::forcing
  type(soil_temperature_field_view_t)::view
  integer::n,i,j,k,nsub,nlay,nheat,pos,code,counts(256),layers(256)
  real(real64)::width(256),height(256),depth,sand(256),silt(256),clay(256),organic(256),osat(256)
  real(real64),allocatable::heads(:),cofgen(:,:),z(:),distance(:),fq(:),fc(:),fo(:),temp(:),table(:),bad(:)
  integer,allocatable::node_layer(:)
  character(1024)::path,mode
  call get_command_argument(1,path)
  call get_command_argument(2,mode)
  ! The thermal component consumes the original grid, not the separate
  ! unsaturated-only water-initialization adapter (Andelst has SWINCO2).
  call rdinit(75,0,trim(path))
  call rdinne('isoillay',nsub);call rdfinr('isoillay',1,256,layers,256,nsub)
  call rdfinr('ncomp',1,256,counts,256,nsub);nlay=maxval(layers(:nsub));n=sum(counts(:nsub))
  if(n<2.or.n>256)error stop 'oracle grid capacity'
  call rdfdor('hsublay',1d-4,1d4,height,256,nsub)
  call rdfdor('osat',0d0,1d0,osat,256,nlay);close(75)
  allocate(cofgen(24,n));cofgen=0d0;k=0
  do i=1,nsub
    do j=1,counts(i)
      k=k+1;width(k)=height(i)/counts(i);cofgen(2,k)=osat(layers(i))
    end do
  end do
  allocate(z(n),distance(n),node_layer(n),fq(n),fc(n),fo(n),temp(n),bad(n))
  depth=0d0
  do i=1,n
    z(i)=-depth-.5d0*width(i);depth=depth+width(i)
  end do
  distance(1)=.5d0*width(1);distance(2:n)=.5d0*(width(1:n-1)+width(2:n))
  if(trim(mode)=='bad-center')z(1)=z(1)-.01d0
  if(trim(mode)=='bad-porosity')cofgen(2,1)=cofgen(2,1)-.01d0
  if(trim(mode)=='bad-width')width(1)=width(1)+.01d0
  call import_column_swp_heat(trim(path),width(:n),z,distance,cofgen(2,:),parameters,state,forcing)
  call build_soil_temperature_field_view(state,view,code)
  if(code/=SOIL_TEMP_OK.or..not.parameters%ready())error stop 'native heat owner unavailable'
  ! Original TTUTIL and original temperature task1 source arithmetic form the oracle.
  call rdinit(75,0,trim(path))
  call rdinne('isoillay',nsub);call rdfinr('isoillay',1,256,layers,256,nsub)
  call rdfinr('ncomp',1,256,counts,256,nsub);nlay=maxval(layers(:nsub))
  call rdfdor('psand',0d0,1d0,sand,256,nlay);call rdfdor('psilt',0d0,1d0,silt,256,nlay)
  call rdfdor('pclay',0d0,1d0,clay,256,nlay);call rdfdor('orgmat',0d0,1d0,organic,256,nlay)
  call rdfdor('osat',0d0,1d0,osat,256,nlay)
  call rdinne('tsoiltb',nheat);allocate(table(nheat));table=0d0
  call rdadortb('tsoiltb',-1d5,0d0,-50d0,50d0,table,nheat,.true.);close(75)
  k=0
  do i=1,nsub
    do j=1,counts(i)
      k=k+1;node_layer(k)=layers(i)
    end do
  end do
  call literal_texture(n,cofgen(2,:),sand(node_layer),silt(node_layer),clay(node_layer),organic(node_layer),fq,fc,fo)
  if(any(parameters%f_quartz/=fq).or.any(parameters%f_clay/=fc).or.any(parameters%f_organic/=fo)) &
    error stop 'source texture volume fractions differ'
  pos=0
  do i=1,n
    call afgen_2(table,nheat,abs(z(i)),temp(i),pos)
  end do
  if(any(view%temperature_c/=temp))error stop 'source initial temperature differs'
  if(forcing%top_boundary_mode/=1.or.forcing%bottom_boundary_mode/=1)error stop 'source boundary modes differ'
  do i=1,n
    write(*,'(A,I0,6(1x,ES25.17E3))')'NODE ',i,z(i),fq(i),fc(i),fo(i),temp(i),parameters%theta_sat(i)
  end do
  ! Invalid constructor inputs cannot create an initialized parameter owner.
  do i=1,7
    bad=organic(node_layer)
    select case(i)
    case(1)
      bad(1)=-.01d0
    case(2)
      bad(1)=1d0
    case(3)
      bad(1)=ieee_value(0d0,ieee_quiet_nan)
    case(4)
      call initialize_soil_temperature_from_texture(width(:n),distance,cofgen(2,:), &
        spread(1d0,1,n),spread(1d0,1,n),spread(1d0,1,n),bad,invalid,code)
    case(5)
      call initialize_soil_temperature_from_texture(width(:n),distance,cofgen(2,:), &
        sand(node_layer),silt(node_layer),clay(node_layer),bad(:n-1),invalid,code)
    case(6)
      bad(1)=2d0
      call initialize_soil_temperature_from_texture(width(:n),distance,bad,sand(node_layer), &
        silt(node_layer),clay(node_layer),organic(node_layer),invalid,code)
    case(7)
      bad(1)=0d0
      call initialize_soil_temperature_from_texture(bad,distance,cofgen(2,:),sand(node_layer), &
        silt(node_layer),clay(node_layer),organic(node_layer),invalid,code)
    end select
    if(i<=3)call initialize_soil_temperature_from_texture(width(:n),distance,cofgen(2,:), &
      sand(node_layer),silt(node_layer),clay(node_layer),bad,invalid,code)
    if(code==SOIL_TEMP_OK.or.invalid%ready())error stop 'invalid texture initialization accepted'
  end do
  print '(A,I0)','NATIVE_HEAT_SOURCE_AND_NEGATIVE_CONTROLS_PASS ',n
end program
