program test_ppa_wu05a18_andelst_perched_baseline
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_solve_request_t, &
       soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t,reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t,matrix_perched_zone_view_t, &
       derive_matrix_saturated_zone_view,derive_matrix_perched_zone_view
  implicit none

  real(real64),parameter::dt=1.41388e-3_real64
  real(real64),parameter::crit=0.1_real64
  type(soil_water_parameter_set_t),target::params
  type(b110_default_mvg_parameters_t),target::hp
  type(b110_default_mvg_provider_t),target::hyd
  type(b110_source_sink_provider_t),target::source
  type(fixed_flux_top_boundary_provider_t),target::top
  type(reference_richards_legacy_solver_t)::solver
  type(reference_richards_legacy_workspace_t)::workspace
  type(soil_water_solve_request_t)::request
  type(soil_water_solve_result_t)::result
  type(matrix_saturated_zone_view_t)::main0,main1
  type(matrix_perched_zone_view_t)::perched0,perched1
  real(real64),allocatable::cofgen(:,:),theta_s(:),water(:),cond(:),cap(:),dkdh(:)
  real(real64),allocatable,target::qdra(:,:),qssdi(:),qrot(:)
  real(real64)::h(numnod)
  integer::i,lay
  logical::ok

  allocate(params%z(numnod),params%dz(numnod),params%node_distance(numnod))
  allocate(cofgen(24,numnod),theta_s(numnod),water(numnod),cond(numnod),cap(numnod),dkdh(numnod))
  params%parameter_set_id=518001_int64
  params%active_nodes=numnod
  params%z=z; params%dz=dz; params%node_distance=disnod(1:numnod)

  h = [ &
    -1.6927648910083026e-01_real64, -5.3552933724089669e-01_real64, -9.0111932332061950e-01_real64, -1.2654373923239099e+00_real64, -1.6276757245582778e+00_real64, &
    -1.9867465759893652e+00_real64, -2.3411588380229582e+00_real64, -2.6888249822119872e+00_real64, -3.0267501974927682e+00_real64, -3.3505181458614497e+00_real64, &
    -3.6534286575813746e+00_real64, -3.9251130720967531e+00_real64, -3.5248184782630703e+00_real64, -2.9089148181587725e+00_real64, -2.2835160267079360e+00_real64, &
    -1.6510468561759648e+00_real64, -1.0131487137174204e+00_real64, -3.7097101170820146e-01_real64, 2.7465527084839048e-01_real64, 9.2311242991133513e-01_real64, &
    1.5739301457616506e+00_real64, 2.2267428254055721e+00_real64, 2.8812611368525434e+00_real64, 3.5372524881584182e+00_real64, 4.1945273127104805e+00_real64, &
    4.8813423539399308e+00_real64, 5.4116495081658931e+00_real64, 2.0159159813914860e+00_real64, -1.3728567166212584e+00_real64, -4.7512675921662222e+00_real64, &
    -8.1090173233675706e+00_real64, -1.1600190731671278e+01_real64, -1.4922261289164561e+01_real64, -1.8298759786507890e+01_real64, -1.8268731754713624e+01_real64, &
    -1.7295767836826439e+01_real64, -1.6256682016235928e+01_real64, -1.5141498014771276e+01_real64, -1.3924821856991775e+01_real64, -1.2585821482075977e+01_real64, &
    -1.1118396303407067e+01_real64, -9.5375286718146679e+00_real64, -7.8468545297741104e+00_real64, -6.1011665431231661e+00_real64, -4.3550814021492137e+00_real64, &
    -2.6087251926699069e+00_real64, -8.6215195750269724e-01_real64, 8.8461059429324174e-01_real64, 2.6531328673916552e+00_real64, 4.4894776396112999e+00_real64 ]

  cofgen=0.0_real64
  do i=1,numnod
    if(i<=12)then; lay=1
    else if(i<=26)then; lay=2
    else if(i<=34)then; lay=3
    else if(i<=42)then; lay=4
    else; lay=5
    end if
    select case(lay)
    case(1); call set_layer(i,0.055_real64,0.405_real64,0.0289_real64,1.0930_real64,-10.502_real64,1.00_real64)
    case(2); call set_layer(i,0.055_real64,0.405_real64,0.0289_real64,1.0930_real64,-10.502_real64,3.08_real64)
    case(3); call set_layer(i,0.100_real64,0.393_real64,0.0075_real64,1.1080_real64,-14.455_real64,0.17_real64)
    case(4); call set_layer(i,0.010_real64,0.395_real64,0.0172_real64,1.0925_real64,-5.819_real64,1.63_real64)
    case(5); call set_layer(i,0.000_real64,0.444_real64,0.0117_real64,1.0735_real64,-0.254_real64,2.51_real64)
    end select
  end do

  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hyd,hp,dt)
  call hyd%evaluate(h,water,cond,cap,dkdh)

  allocate(qdra(1,numnod),qssdi(numnod),qrot(numnod))
  qdra=0.0_real64; qssdi=0.0_real64; qrot=0.0_real64
  qrot(1:30)=[ &
    1.0251884974293897e-05_real64,1.0251884974293900e-05_real64,1.0251884974293898e-05_real64,1.0251884974293898e-05_real64,1.0251884974293895e-05_real64, &
    1.0251884974293903e-05_real64,1.0251884974293895e-05_real64,1.0251884974293887e-05_real64,1.0251884974293910e-05_real64,1.0240614423353784e-05_real64, &
    9.4148427378775613e-06_real64,7.7396072300553449e-06_real64,6.1509391454114038e-06_real64,4.5203062434372516e-06_real64,2.8896733414631151e-06_real64, &
    1.9802957499173295e-06_real64,1.8441379026024747e-06_real64,1.7079800552876363e-06_real64,1.5718222079727980e-06_real64,1.4356643606579430e-06_real64, &
    1.2995065133431047e-06_real64,1.1633486660282827e-06_real64,1.0251884974293977e-06_real64,8.8702832883049621e-07_real64,7.5087048151567434e-07_real64, &
    6.1471263420081944e-07_real64,4.7855478688598096e-07_real64,3.4239693957114263e-07_real64,2.0623909225630419e-07_real64,7.0081244941465794e-08_real64 ]
  qdra(1,48)=5.3697510972773295e-04_real64
  qdra(1,49:50)=5.4953333352821313e-04_real64
  call bind_b110_source_sink_provider(source,qdra,qssdi,qrot)

  request%parameters=>params
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=h
  request%base_state%water_content=water
  request%base_state%ponding_depth=0.0_real64
  request%base_state%groundwater_level=-59.98714271_real64
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%top_flux=-1.63447034_real64
  request%boundary%bottom_mode=2
  request%boundary%bottom_flux=-0.31232592_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=30
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-5_real64
  request%numerical%compartment_balance_tolerance=1.0e-8_real64
  request%numerical%total_balance_tolerance=1.0e-8_real64
  request%numerical%head_abs_tolerance=1.0e-3_real64
  request%numerical%head_rel_tolerance=1.0e-3_real64
  request%numerical%ponding_tolerance=1.0e-4_real64
  request%evaluation%constitutive=>hyd
  request%evaluation%source_sink=>source
  request%evaluation%top_boundary=>top
  request%step_duration=dt

  call derive_matrix_saturated_zone_view(request%base_state,z,dz,main0)
  call require(main0%valid .and. main0%active,'initial main saturated zone')
  call derive_matrix_perched_zone_view(request%base_state,theta_s,z,dz,main0,crit,perched0)
  call require(perched0%valid .and. perched0%active,'initial perched active')
  call require(perched0%top_node==19 .and. perched0%bottom_node==29,'initial source perched bounds')

  call solver%solve(request,workspace,result)
  call require(result%status==SW_SOLVE_CONVERGED,'Reference Richards converged')
  call require(result%integrated_mass_balance_residual_available,'mass residual available')
  call require(abs(result%integrated_mass_balance_residual_cm)<1.0e-8_real64,'hard mass gate')

  call derive_matrix_saturated_zone_view(result%candidate_state,z,dz,main1)
  call require(main1%valid .and. main1%active,'endpoint main saturated zone')
  call derive_matrix_perched_zone_view(result%candidate_state,theta_s,z,dz,main1,crit,perched1)
  call require(perched1%valid .and. perched1%active,'endpoint perched active')
  call require(perched1%bottom_node<main1%top_node-1,'endpoint perched distinct')

  write(*,'(*(g0))') 'PPA_WU05A18_BASELINE|MASS=',result%integrated_mass_balance_residual_cm, &
       '|IT=',result%diagnostics%nonlinear_iterations,'|P_TOP=',perched1%top_node, &
       '|P_BOTTOM=',perched1%bottom_node,'|MAIN_TOP=',main1%top_node
  print '(a)', 'PPA_WU05A18_ANDELST_SNAPSHOT_SOURCE=PASS'
  print '(a)', 'PPA_WU05A18_REFERENCE_RICHARDS_BASELINE=PASS'
  print '(a)', 'PPA_WU05A18_PERCHED_PERSISTENCE=PASS'
  print '(a)', 'PPA_WU05A18_BASELINE_GATE=PASS'

contains

  subroutine set_layer(node,tr,ts,alpha,npar,lexp,ksat)
    integer,intent(in)::node
    real(real64),intent(in)::tr,ts,alpha,npar,lexp,ksat
    cofgen(1,node)=tr
    cofgen(2,node)=ts
    cofgen(3,node)=ksat
    cofgen(4,node)=alpha
    cofgen(5,node)=lexp
    cofgen(6,node)=npar
    cofgen(7,node)=1.0_real64-1.0_real64/npar
    cofgen(8,node)=alpha
    cofgen(10,node)=ksat
    cofgen(11,node)=0.999_real64
    cofgen(12,node)=0.99_real64*ksat
    cofgen(22,node)=-1.0e6_real64
    cofgen(23,node)=1.0e-12_real64
    theta_s(node)=ts
  end subroutine set_layer

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05A18_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05a18_andelst_perched_baseline
