program test_bartholomeus_b111_assembled
  use iso_fortran_env,only:real64
  use MOD_grid
  use MOD_MvG
  use variables
  use atmosphere_interface
  use plant_interface
  use MOD_cropdevelopment
  use MOD_texture_orgmat
  use MOD_SoilTemperature
  use O2_pars,only:c_top,legacy_wft=>waterfilm_thickness
  use mod_bartholomeus_runtime_input
  use mod_bartholomeus_parameter_contract
  use mod_bartholomeus_factor_provider
  use mod_bartholomeus_waterfilm_provider
  implicit none
  type(bartholomeus_runtime_view_t)::view
  type(BartholomeusImmutableDataset)::data
  type(BartholomeusCropParameters)::crop
  real(real64),allocatable::factors(:),film(:)
  real(real64)::w100(4),w500(4),oracle(4),wr(4),worst,film_difference,legacy_films(4)
  logical::ok
  integer::i,j,n,status,count,no_stress,stress
  do i=1,4
    cofgen(1,i)=.05d0;cofgen(2,i)=.45d0;cofgen(4,i)=.01d0
    cofgen(6,i)=1.5d0;cofgen(7,i)=1.d0-1.d0/cofgen(6,i)
    w100(i)=watcon(i,campbell_h100);w500(i)=watcon(i,campbell_h500)
  end do
  call construct_bartholomeus_dataset(cofgen,dz,spread(orgmat(1),1,4),spread(psand(1),1,4), &
       spread(bdens(1),1,4),w100,w500,w100,campbell_h100,campbell_h500,0,data,ok)
  if(.not.ok) error stop 'immutable construction'
  crop%c_mroot=c_mroot;crop%f_senes=f_senes;crop%q10_root=q10_root
  crop%specific_resp_humus=specific_resp_humus;crop%q10_microbial=q10_microbial
  crop%microbial_shape_m=.9d0;crop%root_shape_m=.9d0;crop%root_radius_m=rootradius_m
  crop%max_resp_factor=max_resp_factor
  worst=0;film_difference=0;count=0;no_stress=0;stress=0
  do j=1,18
    n=3
    if(mod(j,3)==0) n=1
    h=-10.d0**(real(mod(j,6),real64))
    if(j==1) h(1)=0.d0
    if(j==2) h(1)=1.d0
    if(j==7) h=-200000.d0
    srl=10.d0**(real(mod(j,4),real64))
    wroot_node_top=[1.d0,.8d0,.6d0,.4d0]*real(j,real64)
    do i=1,4
      theta(i)=watcon(i,h(i))
    end do
    view%rooted_nodes=n
    view%pressure_head_cm=h(1:n);view%water_content=theta(1:n);view%soil_temperature_k=tsoil(1:n)+273.d0
    c_top=0
    do i=1,n
      call OxygenStress(i,oracle(i))
      legacy_films(i)=legacy_wft
    end do
    wr=1.d0/srl
    call evaluate_bartholomeus_factors_from_state(view,data,crop,wr(1:n),wroot_node_top(1:n), &
         672.d0/(8.314472d0*(tav+273.d0)),BARTHOLOMEUS_WATERFILM_REFERENCE,factors,ok)
    if(.not.ok) error stop 'assembled candidate rejection'
    call evaluate_bartholomeus_waterfilm(view,data,BARTHOLOMEUS_WATERFILM_REFERENCE,film,status)
    if(status/=BARTHOLOMEUS_WATERFILM_OK) error stop 'film rejection'
    do i=1,n
      if(h(i)<0 .and. .45d0-theta(i)>=1.d-4) then
        film_difference=max(film_difference,abs(film(i)-legacy_films(i)))
      end if
      worst=max(worst,abs(factors(i)-oracle(i)))
      if(oracle(i)>.99999d0) no_stress=no_stress+1
      if(oracle(i)<.99999d0) stress=stress+1
      print '(a,i0,a,i0,3(a,es24.16))','C3A_ASSEMBLED case=',j,' node=',i, &
           ' legacy=',oracle(i),' current=',factors(i),' difference=',abs(factors(i)-oracle(i))
      count=count+1
    end do
  end do
  print '(a,i0,a,i0,a,i0)','C3A_ASSEMBLED_COUNT=',count,' NO_STRESS=',no_stress,' STRESS=',stress
  print '(a,es24.16)','C3A_ASSEMBLED_MAX_RWU_DIFFERENCE=',worst
  print '(a,es24.16)','C3A_ASSEMBLED_MAX_WFT_DIFFERENCE=',film_difference
  if(worst>1.d-4) error stop 'source SOLVE accuracy exceeded'
  if(no_stress==0 .or. stress==0) error stop 'missing response coverage'
  print '(a)','PPA_WU05C3A_B111_ASSEMBLED=PASS'
end program
