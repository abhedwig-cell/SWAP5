program test_ppa_wu05a15_exchange_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: soil_water_physical_state_t
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t, evaluate_macropore_geometry
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, macropore_rate_bundle_result_t, &
       evaluate_macropore_rate_bundle
  use mod_macropore_standard_storage, only: macropore_standard_storage_view_t, canonicalize_macropore_standard_storage
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t, matrix_perched_zone_view_t, &
       derive_matrix_saturated_zone_view, derive_matrix_perched_zone_view, prepare_standard_macropore_rate_request
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t, initialize_fmr_macropore_standard_config
  use mod_ppa_wu05a15_exchange_derivative, only: macropore_exchange_derivative_result_t, &
       evaluate_macropore_exchange_derivative
  implicit none

  integer,parameter::n=6,nd=1
  type(soil_water_physical_state_t)::matrix
  type(macropore_continuation_state_t)::macro
  type(macropore_geometry_result_t)::geometry
  type(macropore_standard_storage_view_t)::macro_view
  type(matrix_saturated_zone_view_t)::matrix_view
  type(matrix_perched_zone_view_t)::perched_tight,perched_merge
  type(fmr_macropore_physical_config_t)::config
  type(macropore_rate_bundle_request_t)::request,base_request,work_request
  type(macropore_rate_bundle_result_t)::rates,work_rates
  type(macropore_exchange_derivative_result_t)::derivative
  real(real64)::z(n),dz(n),theta_s(n),theta_r(n),static_volume(n),domain_fraction(nd,n),diameter(n)
  real(real64)::wall_correction(n),sorp_max(n),sorp_alpha(n),conductivity(n),entry_head(n)
  real(real64)::sorp_fac_parallel(n),ksat_horizontal(n),cdarcy(nd,n),capacity(n),expected,delh
  integer::potential_bottom(nd)
  logical::ok

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

  call derive_matrix_saturated_zone_view(matrix,z,dz,matrix_view)
  call require(matrix_view%valid .and. matrix_view%active,'main saturated view active')
  call require(matrix_view%top_node==6 .and. matrix_view%bottom_node==6,'main saturated view bounds')

  ! Exact 4.3.1 CALCGWL oracle: the node-3 under-saturated volume is 0.01 cm.
  ! With a 0.005 cm threshold it splits the perched body; with 0.02 cm it is
  ! bridged and the upper saturated compartment belongs to the same perched zone.
  call derive_matrix_perched_zone_view(matrix,theta_s,z,dz,matrix_view,0.005_real64,perched_tight)
  call require(perched_tight%valid .and. perched_tight%active,'tight perched valid')
  call require(perched_tight%top_node==3 .and. perched_tight%bottom_node==4,'tight perched bounds')
  call require(abs(perched_tight%water_level_cm+25.32258064516129_real64)<1.0e-12_real64, &
       'tight perched water level')

  call derive_matrix_perched_zone_view(matrix,theta_s,z,dz,matrix_view,0.02_real64,perched_merge)
  call require(perched_merge%valid .and. perched_merge%active,'merged perched valid')
  call require(perched_merge%top_node==2 .and. perched_merge%bottom_node==4,'merged perched bounds')
  call require(perched_merge%partial_top_active,'merged perched top fraction active')
  call require(abs(perched_merge%water_level_cm+12.142857142857142_real64)<1.0e-12_real64, &
       'merged perched water level')
  call require(abs(perched_merge%bottom_level_cm+38.75_real64)<1.0e-12_real64,'merged perched bottom level')

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
  call require(ok .and. config%valid_for_nodes(n),'A11 config valid')
  call require(config%rate_template%perched_detection_enabled,'A11 perched config enabled')

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

  call prepare_standard_macropore_rate_request(config%rate_template,macro,geometry,macro_view,matrix,z,dz,0.1_real64, &
       request,matrix_view,ok)
  call require(ok,'A11 FMR rate request')
  call require(request%unsaturated%sorptivity%perched_active,'A11 request perched active')
  call require(request%unsaturated%sorptivity%perched_top_node==2 .and. &
       request%unsaturated%sorptivity%perched_bottom_node==4,'A11 unsaturated perched exclusion')
  call require(request%interflow_sat%matrix_top_saturated_node==2 .and. &
       request%interflow_sat%matrix_bottom_saturated_node==4,'A11 interflow bounds')
  call require(request%interflow_sat%matrix_partial_top_active,'A11 interflow top fraction')
  call require(abs(request%interflow_sat%matrix_level-perched_merge%water_level_cm)<1.0e-12_real64, &
       'A11 interflow reference level')

  call evaluate_macropore_rate_bundle(request,rates)
  call require(rates%valid,'A11 source bundle valid')
  call require(sum(rates%qin_interflow_rate)>0.0_real64,'A11 perched interflow positive')
  call require(rates%qexc_to_matrix_rate(1,4)<0.0_real64,'A11 perched exchange sign')
  call require(abs(rates%unsaturated%selected_rate_cm_per_day(1,3))<1.0e-15_real64 .and. &
       abs(rates%unsaturated%selected_rate_cm_per_day(1,4))<1.0e-15_real64 .and. &
       abs(rates%unsaturated%selected_rate_cm_per_day(1,2))<1.0e-15_real64,'A11 perched excludes absorption')

  base_request=request
  capacity=0.02_real64

  ! Exact negative evidence: perched QInIntSat is active but MACRORATE(2)
  ! contains no matching SATFLOW(4) derivative call.
  work_request=base_request
  work_request%unsaturated%sorptivity%sorptivity_max=0.0_real64
  work_request%unsaturated%conductivity=0.0_real64
  work_request%matrix_sat%cdarcy=0.0_real64
  work_request%matrix_sat%ksat_horizontal=0.0_real64
  work_request%matrix_sat%matrix_bottom_saturated_node=0
  call evaluate_macropore_rate_bundle(work_request,work_rates)
  call require(work_rates%valid .and. sum(work_rates%qin_interflow_rate)>0.0_real64,'A15 perched rate active')
  call evaluate_macropore_exchange_derivative(work_request,work_rates,capacity,derivative)
  call require(derivative%valid,'A15 perched derivative valid')
  call require(.not.derivative%perched_derivative_included,'A15 perched derivative excluded')
  call require(maxval(abs(derivative%total_dqdh_node))<1.0e-15_real64,'A15 perched derivative exact zero')

  ! Main saturated SATFLOW(4): dQ/dh = -Qexc/DelH.
  work_request=base_request
  work_request%unsaturated%sorptivity%sorptivity_max=0.0_real64
  work_request%unsaturated%conductivity=0.0_real64
  work_request%interflow_sat%cdarcy=0.0_real64
  work_request%matrix_sat%matrix_top_saturated_node=6
  work_request%matrix_sat%matrix_bottom_saturated_node=6
  work_request%matrix_sat%matrix_head=0.0_real64
  work_request%matrix_sat%matrix_head(6)=1.0_real64
  work_request%matrix_sat%macro_reference_level=-50.0_real64
  work_request%matrix_sat%top_macro_saturated_node=6
  work_request%matrix_sat%macro_saturated_fraction=1.0_real64
  work_request%matrix_sat%cdarcy=0.01_real64
  call evaluate_macropore_rate_bundle(work_request,work_rates)
  call require(work_rates%valid .and. work_rates%qout_sat_rate(1,6)>1.0e-7_real64,'A15 main saturated rate')
  call evaluate_macropore_exchange_derivative(work_request,work_rates,capacity,derivative)
  delh=4.0_real64
  expected=-work_rates%qout_sat_rate(1,6)/delh
  call require(abs(derivative%main_saturated_dqdh(1,6)-expected)<1.0e-12_real64,'A15 main saturated derivative')

  ! Sorptivity-selected ABSORPTION(2), standard swabs=1.
  work_request=base_request
  work_request%interflow_sat%cdarcy=0.0_real64
  work_request%matrix_sat%cdarcy=0.0_real64
  work_request%unsaturated%sorptivity%matrix_top_saturated_node=n+1
  work_request%unsaturated%sorptivity%perched_active=.false.
  work_request%unsaturated%sorptivity%top_water_node=1
  work_request%unsaturated%sorptivity%bottom_domain=n
  work_request%unsaturated%sorptivity%theta=0.25_real64
  work_request%unsaturated%sorptivity%history_absorption_time=0.0_real64
  work_request%unsaturated%sorptivity%sorptivity_max=0.001_real64
  work_request%unsaturated%sorptivity%sorptivity_alpha=0.5_real64
  work_request%unsaturated%conductivity=0.0_real64
  call evaluate_macropore_rate_bundle(work_request,work_rates)
  call require(work_rates%valid .and. work_rates%qout_unsat_rate(1,2)>1.0e-7_real64,'A15 sorptivity rate')
  call require(work_rates%unsaturated%selected_by_sorptivity(1,2),'A15 sorptivity branch')
  call evaluate_macropore_exchange_derivative(work_request,work_rates,capacity,derivative)
  expected=-work_rates%qout_unsat_rate(1,2)*0.5_real64/(0.45_real64-0.25_real64)*capacity(2)
  call require(abs(derivative%unsaturated_dqdh(1,2)-expected)<1.0e-12_real64,'A15 sorptivity derivative')

  ! Darcy-selected ABSORPTION(2): dQ/dh = -Qout/DelH.
  work_request=base_request
  work_request%interflow_sat%cdarcy=0.0_real64
  work_request%matrix_sat%cdarcy=0.0_real64
  work_request%unsaturated%sorptivity%matrix_top_saturated_node=n+1
  work_request%unsaturated%sorptivity%perched_active=.false.
  work_request%unsaturated%sorptivity%top_water_node=1
  work_request%unsaturated%sorptivity%bottom_domain=n
  work_request%unsaturated%sorptivity%sorptivity_max=0.0_real64
  work_request%unsaturated%conductivity=0.0_real64
  work_request%unsaturated%conductivity(2)=0.01_real64
  work_request%unsaturated%pressure_head=-20.0_real64
  work_request%unsaturated%groundwater_level_domain=-10.0_real64
  work_request%unsaturated%entry_head=-1.0_real64
  call evaluate_macropore_rate_bundle(work_request,work_rates)
  call require(work_rates%valid .and. work_rates%qout_unsat_rate(1,2)>1.0e-7_real64,'A15 Darcy rate')
  call require(.not.work_rates%unsaturated%selected_by_sorptivity(1,2),'A15 Darcy branch')
  call evaluate_macropore_exchange_derivative(work_request,work_rates,capacity,derivative)
  delh=25.0_real64
  expected=-work_rates%qout_unsat_rate(1,2)/delh
  call require(abs(derivative%unsaturated_dqdh(1,2)-expected)<1.0e-12_real64,'A15 Darcy derivative')

  print '(a)', 'PPA_WU05A15_PERCHED_NEGATIVE_DERIVATIVE=PASS'
  print '(a)', 'PPA_WU05A15_MAIN_SAT_DERIVATIVE=PASS'
  print '(a)', 'PPA_WU05A15_SORPTIVITY_DERIVATIVE=PASS'
  print '(a)', 'PPA_WU05A15_DARCY_DERIVATIVE=PASS'
  print '(a)', 'PPA_WU05A15_EXCHANGE_DERIVATIVE_GATE=PASS'

contains

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A11_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a15_exchange_derivative
