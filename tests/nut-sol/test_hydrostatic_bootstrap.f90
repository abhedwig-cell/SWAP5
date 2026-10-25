program test_hydrostatic_bootstrap
 use iso_fortran_env,only:real64
 use mod_column_swp_water,only:import_column_swp_water,initialize_column_hydrostatic_water
 use mod_column_swp_heat,only:import_column_swp_heat
 use mod_soil_temperature_contract,only:soil_temperature_parameters_t,soil_temperature_state_t, &
   soil_temperature_forcing_t,soil_temperature_field_view_t,build_soil_temperature_field_view
 use hydrostatic_literal,only:original_initialize
 implicit none
 real(real64)::width(256),pond,gwl,depth
 real(real64),allocatable::h(:),cof(:,:),z(:),distance(:),expected(:)
 type(soil_temperature_parameters_t)::p
 type(soil_temperature_state_t)::state
 type(soil_temperature_forcing_t)::forcing
 type(soil_temperature_field_view_t)::view
 integer::n,i,j,k,code,bottom,nsub,nlay,counts(256),layers(256)
 real(real64)::height(256),osat(256)
 character(1024)::path,mode,bbc
 call get_command_argument(1,path);call get_command_argument(2,mode)
 if(trim(mode)=='external-bbc')then
   call get_command_argument(3,bbc)
   call rdinit(75,0,trim(bbc));call rdsinr('swbotb',1,8,bottom);close(75)
   ! Original hydraulic extensions remain excluded. Qualify only the unchanged
   ! original grid/GWLI component using the same real initializer as the adapter.
   call rdinit(75,0,trim(path))
   call rdinne('isoillay',nsub);call rdfinr('isoillay',1,256,layers,256,nsub)
   call rdfinr('ncomp',1,256,counts,256,nsub);nlay=maxval(layers(:nsub));n=sum(counts(:nsub))
   call rdfdor('hsublay',1d-4,1d4,height,256,nsub);call rdfdor('osat',0d0,1d0,osat,256,nlay)
   call rdsdor('gwli',-10000d0,1000d0,gwl);close(75)
   allocate(cof(24,n));cof=0d0;k=0
   do i=1,nsub
     do j=1,counts(i)
       k=k+1;width(k)=height(i)/counts(i);cof(2,k)=osat(layers(i))
     end do
   end do
   call initialize_column_hydrostatic_water(width(:n),gwl,bottom,h,pond)
 else if(trim(mode)=='omit-pond')then
   call import_column_swp_water(trim(path),n,width,h,cof)
 else
   call import_column_swp_water(trim(path),n,width,h,cof,pond)
 end if
 call rdinit(75,0,trim(path));call rdsdor('gwli',-10000d0,1000d0,gwl);close(75)
 allocate(z(n),distance(n),expected(n));depth=0d0
 do i=1,n
   z(i)=-(depth+.5d0*width(i));depth=depth+width(i)
 end do
 distance(1)=.5d0*width(1);distance(2:n)=.5d0*(width(1:n-1)+width(2:n))
 call original_initialize(n,gwl,z,expected,depth)
 if(any(h/=expected).or.pond/=depth)error stop 'original hydrostatic construction differs'
 call import_column_swp_heat(trim(path),width(:n),z,distance,cof(2,:),p,state,forcing)
 call build_soil_temperature_field_view(state,view,code)
 if(code/=0.or..not.p%ready())error stop 'real thermal owner not initialized'
 do i=1,n
   write(*,'(A,I0,5(1x,ES25.17E3))')'NODE ',i,width(i),z(i),h(i),view%temperature_c(i),cof(2,i)
 end do
 write(*,'(A,ES25.17E3)')'POND ',pond
 print '(A)','SOURCE_HYDROSTATIC_AND_HEAT_INITIALIZATION_PASS'
end program
