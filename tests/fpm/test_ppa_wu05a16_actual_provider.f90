program test_ppa_wu05a16_actual_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t, copy_macropore_continuation_state
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, canonicalize_macropore_standard_storage
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t, initialize_fmr_macropore_standard_config
  use mod_ppa_wu05a16_inner_macropore_provider, only: ppa_wu05a16_inner_macropore_provider_t
  implicit none

  integer,parameter::n=6,nd=1
  type(soil_water_physical_state_t)::matrix
  type(macropore_continuation_state_t)::macro,before
  type(macropore_geometry_result_t)::geometry
  type(macropore_standard_storage_view_t)::macro_view
  type(fmr_macropore_physical_config_t)::config
  type(ppa_wu05a16_inner_macropore_provider_t)::provider
  real(real64)::z(n),dz(n),theta_s(n),theta_r(n),static_volume(n),domain_fraction(nd,n),diameter(n)
  real(real64)::wall_correction(n),sorp_max(n),sorp_alpha(n),conductivity(n),entry_head(n)
  real(real64)::sorp_fac_parallel(n),ksat_horizontal(n),cdarcy(nd,n),capacity(n)
  real(real64)::exchange1(n),exchange2(n),dqdh(n),heads2(n)
  integer::potential_bottom(nd)
  logical::ok,active,derivative_available

  z=[-5.0_real64,-15.0_real64,-25.0_real64,-35.0_real64,-45.0_real64,-55.0_real64]
  dz=10.0_real64
  theta_s=0.45_real64
  theta_r=0.05_real64

  matrix%active_nodes=n
  allocate(matrix%pressure_head(n),matrix%water_content(n))
  matrix%pressure_head=[-5.0_real64,2.0_real64,-0.1_real64,3.0_real64,-5.0_real64,1.0_real64]
  matrix%water_content=[0.25_real64,0.45_real64,0.449_real64,0.45_real64,0.44_real64,0.45_real64]
  matrix%ponding_depth=0.0_real64
  matrix%groundwater_level=-52.0_real64
  capacity=0.02_real64

  static_volume=0.5_real64
  domain_fraction=1.0_real64
  diameter=4.0_real64
  wall_correction=0.95_real64
  sorp_max=0.001_real64
  sorp_alpha=0.5_real64
  conductivity=0.01_real64
  entry_head=-1.0_real64
  sorp_fac_parallel=0.5_real64
  ksat_horizontal=0.1_real64
  cdarcy=0.01_real64
  potential_bottom=n

  call initialize_fmr_macropore_standard_config(config,1,static_volume,domain_fraction,potential_bottom, &
       z,dz,diameter,theta_s,theta_r,wall_correction,sorp_max,sorp_alpha,conductivity,entry_head, &
       sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.0_real64,0,ok, &
       perched_enabled=.true.,critical_under_saturated_volume_cm=0.02_real64)
  call require(ok .and. config%valid_for_nodes(n),'config valid')

  ! Isolate source-faithful perched QInIntSat from all other A6 transfer paths.
  config%rate_template%unsaturated%sorptivity%sorptivity_max=0.0_real64
  config%rate_template%unsaturated%conductivity=0.0_real64
  config%rate_template%matrix_sat%ksat_horizontal=0.0_real64
  config%rate_template%matrix_sat%cdarcy=0.0_real64
  config%rate_template%rapid%enabled=.false.

  call macro%initialize(nd,n,ok)
  call require(ok,'macro initialized')
  macro%dynamic_volume_cp=0.0_real64
  call evaluate_macropore_geometry(config%geometry,macro%dynamic_volume_cp,geometry)
  call require(geometry%valid,'geometry valid')
  macro%icp_bottom_domain=geometry%bottom_domain
  macro%volume_domain_cp=geometry%volume_domain_cp
  macro%water_domain_cp=0.0_real64
  macro%water_domain_cp(1,n)=0.25_real64
  call canonicalize_macropore_standard_storage(macro,1,z,dz,macro_view,ok)
  call require(ok,'macro storage canonical')
  call copy_macropore_continuation_state(macro,before,ok)
  call require(ok,'snapshot copied')

  call provider%configure(macro,geometry,config%rate_template,z,dz,0.1_real64, &
       matrix%ponding_depth,matrix%groundwater_level,ok)
  call require(ok,'provider configured')

  call provider%evaluate_rate(matrix%pressure_head,matrix%water_content,exchange1,active)
  call require(active,'perched provider active')
  call require(sum(exchange1)<-1.0e-12_real64,'perched exchange toward macropore')

  call provider%evaluate_derivative(matrix%pressure_head,matrix%water_content,capacity,dqdh, &
       derivative_available,active)
  call require(derivative_available .and. active,'provider derivative available')
  call require(maxval(abs(dqdh))<1.0e-15_real64,'exact perched derivative zero')

  heads2=matrix%pressure_head
  heads2(2)=4.0_real64
  call provider%evaluate_rate(heads2,matrix%water_content,exchange2,active)
  call require(active,'changed iterate provider active')
  call require(maxval(abs(exchange2-exchange1))>1.0e-12_real64,'provider responds to current iterate')

  call require(macro%same_values(before),'accepted seven-field state unchanged')

  write(*,'(*(g0))') 'PPA_WU05A16_ACTUAL_PROVIDER|Q1=',sum(exchange1),'|Q2=',sum(exchange2), &
       '|MAX_DQDH=',maxval(abs(dqdh))
  print '(a)', 'PPA_WU05A16_ACTUAL_PERCHED_RATE=PASS'
  print '(a)', 'PPA_WU05A16_ACTUAL_DERIVATIVE_SEMANTICS=PASS'
  print '(a)', 'PPA_WU05A16_ACCEPTED_STATE_ISOLATION=PASS'
  print '(a)', 'PPA_WU05A16_ACTUAL_PROVIDER_GATE=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A16_ACTUAL_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a16_actual_provider
