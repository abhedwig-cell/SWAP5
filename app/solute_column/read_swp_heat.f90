! Component input adapter. Other SWP switches are not activated by this reader.
module mod_column_swp_heat
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  use mod_soil_temperature_contract,only:soil_temperature_parameters_t,soil_temperature_state_t, &
    soil_temperature_forcing_t,SOIL_TEMP_OK,SOIL_TEMP_TOP_AIR_TEMPERATURE,SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX, &
    initialize_soil_temperature_state
  use mod_restricted_soil_temperature,only:initialize_soil_temperature_from_texture
  implicit none
  private
  public::import_column_swp_heat
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print '(A)','SWP_HEAT_REJECTED: '//message
      error stop 1
    end if
  end subroutine
  subroutine import_column_swp_heat(path,dz,z,distance,theta_sat,parameters,state,forcing)
    character(*),intent(in)::path
    real(real64),intent(in)::dz(:),z(:),distance(:),theta_sat(:)
    type(soil_temperature_parameters_t),intent(out)::parameters
    type(soil_temperature_state_t),intent(out)::state
    type(soil_temperature_forcing_t),intent(out)::forcing
    integer::n,nsub,nlay,mode,nheat,i,j,k,pos,code
    integer::ids(256),layers(256),counts(256),node_layer(size(dz))
    real(real64)::height(256),sand(256),silt(256),clay(256),organic(256),osat(256),depth,width
    real(real64),allocatable::table(:),initial_temperature(:)
    logical::rdinqr
    n=size(dz)
    call require(n>=2.and.n<=256,'node capacity')
    call require(size(z)==n.and.size(distance)==n.and.size(theta_sat)==n,'water owner shape')
    call require(all(ieee_is_finite(dz)).and.all(ieee_is_finite(z)).and. &
      all(ieee_is_finite(distance)).and.all(ieee_is_finite(theta_sat)),'nonfinite water owner')
    call rdinit(74,0,trim(path))
    call rdsinr('swhea',0,2,mode);call require(mode==1,'SWHEA1 required')
    call rdsinr('swcalt',1,2,mode);call require(mode==2,'numeric SWCALT2 required')
    call rdsinr('swinco',1,3,mode);call require(mode/=3,'loose historical restart excluded')
    call rdsinr('swtopbhea',1,4,mode);call require(mode==1,'only original air top boundary selected')
    call rdsinr('swbotbhea',1,2,mode);call require(mode==1,'only zero bottom heat flux selected')
    call require(.not.rdinqr('tsoil'),'deprecated ZH/TSOIL not selected')
    call rdinne('isublay',nsub);call require(nsub>=1.and.nsub<=256,'sublayer count')
    call rdfinr('isublay',1,256,ids,256,nsub)
    call rdfinr('isoillay',1,256,layers,256,nsub)
    call rdfinr('ncomp',1,256,counts,256,nsub)
    call rdfdor('hsublay',1d-4,1d4,height,256,nsub)
    call require(all(ids(:nsub)==[(i,i=1,nsub)]),'ordered sublayer identities')
    call require(sum(counts(:nsub))==n,'SWP and water grid size differ')
    nlay=maxval(layers(:nsub))
    do i=1,nlay
      call require(any(layers(:nsub)==i),'soil-layer identity gap')
    end do
    call rdfdor('psand',0d0,1d0,sand,256,nlay)
    call rdfdor('psilt',0d0,1d0,silt,256,nlay)
    call rdfdor('pclay',0d0,1d0,clay,256,nlay)
    call rdfdor('orgmat',0d0,1d0,organic,256,nlay)
    call rdfdor('osat',0d0,1d0,osat,256,nlay)
    call rdinne('tsoiltb',nheat)
    call require(nheat>=4.and.nheat<=512.and.mod(nheat,2)==0,'TSOILTB table size')
    allocate(table(nheat));table=0d0
    call rdadortb('tsoiltb',-1d5,0d0,-50d0,50d0,table,nheat,.true.)
    call require(all(ieee_is_finite(table)),'nonfinite initial thermal table')
    call require(all(table(3:nheat:2)>table(1:nheat-2:2)),'temperature depths must increase')
    close(74)
    k=0;depth=0d0
    do i=1,nsub
      width=height(i)/counts(i)
      do j=1,counts(i)
        k=k+1;node_layer(k)=layers(i)
        call require(abs(dz(k)-width)<=16d0*epsilon(1d0)*max(1d0,abs(width)), &
          'SWP and water cell thickness differ')
        call require(abs(z(k)+depth+.5d0*width)<=32d0*epsilon(1d0)*max(1d0,abs(z(k))), &
          'SWP and water cell center differ')
        depth=depth+width
      end do
    end do
    call require(all(abs(theta_sat-osat(node_layer))<=16d0*epsilon(1d0)), &
      'SWP and hydraulic porosity differ')
    call initialize_soil_temperature_from_texture(dz,distance,theta_sat,sand(node_layer),silt(node_layer), &
      clay(node_layer),organic(node_layer),parameters,code)
    call require(code==SOIL_TEMP_OK,'source texture initialization failed')
    allocate(initial_temperature(n));pos=0
    do i=1,n
      call afgen_2(table,nheat,abs(z(i)),initial_temperature(i),pos)
    end do
    call initialize_soil_temperature_state(initial_temperature,state,code)
    call require(code==SOIL_TEMP_OK,'source thermal state initialization failed')
    forcing%top_boundary_mode=SOIL_TEMP_TOP_AIR_TEMPERATURE
    forcing%bottom_boundary_mode=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX
    print '(A)','SWP_NATIVE_NUMERIC_HEAT_BOOTSTRAP_IMPORTED'
  end subroutine import_column_swp_heat
end module mod_column_swp_heat
