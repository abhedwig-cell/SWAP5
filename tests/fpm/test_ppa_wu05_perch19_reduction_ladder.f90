program test_ppa_wu05_perch19_reduction_ladder
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_soil_water_solver_contract, only: soil_water_parameter_set_t,soil_water_solve_request_t, &
       soil_water_solve_result_t,SW_SOLVE_CONVERGED
  use mod_reference_richards_legacy_binding, only: reference_richards_legacy_solver_t, &
       reference_richards_legacy_workspace_t
  use mod_reference_richards_state_binding, only: FSI_TOP_MODE_EXPLICIT_FLUX
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t,b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters,bind_b110_default_mvg_provider
  use mod_b110_source_sink_provider, only: b110_source_sink_provider_t,bind_b110_source_sink_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_macropore_standard_rate_adapter, only: matrix_saturated_zone_view_t,matrix_perched_zone_view_t, &
       derive_matrix_saturated_zone_view,derive_matrix_perched_zone_view
  use mod_macropore_continuation_state, only: macropore_continuation_state_t
  use mod_ppa_wu05a5_multi_domain_process, only: macropore_geometry_result_t,evaluate_macropore_geometry
  use mod_fmr_macropore_configuration, only: fmr_macropore_physical_config_t,initialize_fmr_macropore_standard_config
  use mod_macropore_single_column_runtime, only: macropore_single_column_runtime_t,macropore_runtime_policy_t, &
       macropore_runtime_result_t,MACRO_RUNTIME_CONVERGED
  implicit none

  real(real64),parameter :: dt=2.0e-3_real64
  real(real64),parameter :: source_gwl=-7.9567111140905610e1_real64
  real(real64),parameter :: source_pegwl=6.3031614696426097e-1_real64
  real(real64),parameter :: source_pebottom=-2.8777845917377004e1_real64
  real(real64),parameter :: source_qtop=-9.7461172849236255e-1_real64
  real(real64),parameter :: source_qbot=-9.9302686238463434e-3_real64
  real(real64),parameter :: source_h(numnod) = [ &
       6.43010282718079695e-1_real64, 6.68549162830310739e-1_real64, 6.94238653987799159e-1_real64, 7.20078756190832947e-1_real64, &
       7.46069469439699984e-1_real64, 7.72210793734687928e-1_real64, 7.98502729076084661e-1_real64, 8.24945275464177508e-1_real64, &
       8.51538432899253905e-1_real64, 8.78282201381600958e-1_real64, 9.05176415335178786e-1_real64, 9.32208943299884796e-1_real64, &
       1.45531984084535848e+0_real64, 2.13948756643130533e+0_real64, 2.82367685308484706e+0_real64, 3.50787992297359619e+0_real64, &
       4.19209243852626035e+0_real64, 4.87631375029386138e+0_real64, 5.56054320882742381e+0_real64, 6.24478016467797037e+0_real64, &
       6.92902396839652379e+0_real64, 7.61327397053410682e+0_real64, 8.29752952164174218e+0_real64, 8.98178996271973062e+0_real64, &
       9.66605463476837734e+0_real64, 1.03503228883387024e+1_real64, 1.07518953509728696e+1_real64, 6.03167348192390129e+0_real64, &
       1.31148120216819231e+0_real64, -3.40869325477250351e+0_real64, -8.12860132752549802e+0_real64, -1.33207844186458519e+1_real64, &
       -1.97558922612244814e+1_real64, -2.79223906069283991e+1_real64, -3.05459229114626076e+1_real64, -3.13316550820706929e+1_real64, &
       -3.17320586627391670e+1_real64, -3.17411629110699387e+1_real64, -3.13862237327239235e+1_real64, -3.07122187485403089e+1_real64, &
       -2.97691985684998670e+1_real64, -2.86045996348141678e+1_real64, -2.71105315330298957e+1_real64, -2.54519171058429841e+1_real64, &
       -2.37280042866150218e+1_real64, -2.19483109754172467e+1_real64, -2.01209829508919285e+1_real64, -1.82530341114032950e+1_real64, &
       -1.63505613769070095e+1_real64, -1.44189329451117487e+1_real64, -1.24629519185108215e+1_real64, -1.04869993937742461e+1_real64, &
       -8.25021811936266936e+0_real64, -5.77060305050075684e+0_real64, -3.29068095924812010e+0_real64, -8.10619833461699968e-1_real64, &
       1.66951962640198404e+0_real64, 4.14965908633825098e+0_real64, 6.62979854634619681e+0_real64, 9.10993800642490648e+0_real64, &
       1.15900774665734492e+1_real64, 1.40702169267908843e+1_real64, 1.65503563870762598e+1_real64, 1.90304958474286110e+1_real64, &
       2.15106353078469610e+1_real64, 2.39907747683303185e+1_real64, 2.64709142288776853e+1_real64, 2.89510536894880524e+1_real64, &
       3.14311931501604001e+1_real64, 3.39113326108936946e+1_real64, 3.63914720716868914e+1_real64, 3.88716115325389353e+1_real64, &
       4.25931851884213373e+1_real64, 4.75569433289730625e+1_real64, 5.25207014697228232e+1_real64, 5.74844596106632224e+1_real64, &
       6.24482177517867640e+1_real64, 6.74119758930858239e+1_real64, 7.23757340345526785e+1_real64, 7.73394921761795047e+1_real64, &
       8.23032503179583728e+1_real64, 8.72670084598812679e+1_real64, 9.22307666019400756e+1_real64, 9.71945247441266389e+1_real64, &
       1.02158282886432701e+2_real64, 1.07122041028849893e+2_real64, 1.12085799171369857e+2_real64, 1.17049557313984124e+2_real64, &
       1.22013315456684168e+2_real64, 1.26977073599461448e+2_real64, 1.31940831742307324e+2_real64, 1.36904589885213170e+2_real64, &
       1.41895856139540570e+2_real64, 1.46890891005132431e+2_real64, 1.51885925870730858e+2_real64, 1.56880960736335680e+2_real64, &
       1.61875995601946755e+2_real64, 1.66871030467563912e+2_real64, 1.71866065333186981e+2_real64, 1.76861100198815791e+2_real64, &
       1.81856135064450172e+2_real64, 1.86851169930089981e+2_real64, 1.91846204795734991e+2_real64, 1.96841239661385089e+2_real64, &
       2.01836274527040104e+2_real64, 2.06831309392699836e+2_real64, 2.11826344258364117e+2_real64, 2.16821379124032802e+2_real64, &
       2.21816413989705723e+2_real64, 2.26811448855382679e+2_real64, 2.31806483721063529e+2_real64, 2.36801518586748074e+2_real64 ]

  type(soil_water_parameter_set_t),target :: parameters
  type(b110_default_mvg_parameters_t),target :: hp
  type(b110_default_mvg_provider_t),target :: hydraulics
  type(b110_source_sink_provider_t),target :: source_sink
  type(fixed_flux_top_boundary_provider_t),target :: top_provider
  type(reference_richards_legacy_solver_t) :: solver
  type(reference_richards_legacy_workspace_t) :: workspace
  type(soil_water_solve_request_t) :: request
  type(soil_water_solve_result_t) :: result
  type(matrix_saturated_zone_view_t) :: main_view
  type(matrix_perched_zone_view_t) :: perched_view
  type(macropore_continuation_state_t) :: macro
  type(macropore_geometry_result_t) :: geometry
  type(fmr_macropore_physical_config_t) :: macro_config
  type(macropore_single_column_runtime_t) :: macro_runtime
  type(macropore_runtime_policy_t) :: macro_policy
  type(macropore_runtime_result_t) :: macro_result
  real(real64),target :: qdra(1,numnod),qssdi(numnod),qrot(numnod)
  real(real64) :: cofgen(24,numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
  real(real64) :: theta_s(numnod),theta_r(numnod),static_volume(numnod),domain_fraction(1,numnod), &
       diameter(numnod),wall_correction(numnod),sorp_max(numnod),sorp_alpha(numnod), &
       unsat_conductivity(numnod),entry_head(numnod),sorp_fac_parallel(numnod), &
       ksat_horizontal(numnod),cdarcy(1,numnod)
  integer :: potential_bottom(1)
  integer :: i
  logical :: ok

  parameters%parameter_set_id=1801_int64
  parameters%active_nodes=numnod
  allocate(parameters%z(numnod),parameters%dz(numnod),parameters%node_distance(numnod))
  parameters%z=z
  parameters%dz=dz
  parameters%node_distance=disnod(1:numnod)

  cofgen=0.0_real64
  call assign_layer(1,12,  0.055_real64,0.405_real64,0.0289_real64,1.0930_real64,-10.502_real64,1.00_real64)
  call assign_layer(13,26, 0.055_real64,0.405_real64,0.0289_real64,1.0930_real64,-10.502_real64,3.08_real64)
  call assign_layer(27,34, 0.100_real64,0.393_real64,0.0075_real64,1.1080_real64,-14.455_real64,0.17_real64)
  call assign_layer(35,42, 0.010_real64,0.395_real64,0.0172_real64,1.0925_real64,-5.819_real64,1.63_real64)
  call assign_layer(43,52, 0.000_real64,0.444_real64,0.0117_real64,1.0735_real64,-0.254_real64,2.51_real64)
  call assign_layer(53,72, 0.005_real64,0.442_real64,0.0078_real64,1.0870_real64,-7.713_real64,1.25_real64)
  call assign_layer(73,92, 0.010_real64,0.525_real64,0.0050_real64,1.0800_real64,-7.465_real64,1.37_real64)
  call assign_layer(93,112,0.010_real64,0.525_real64,0.0050_real64,1.0800_real64,-7.465_real64,10.00_real64)

  theta_s=cofgen(2,:)
  call initialize_b110_default_mvg_parameters(hp,cofgen)
  call bind_b110_default_mvg_provider(hydraulics,hp,dt)
  call hydraulics%evaluate(source_h,water,conductivity,capacity,dkdh)
  call require(all(water>=cofgen(1,:)-1.0e-12_real64 .and. water<=theta_s+1.0e-12_real64), &
       'source snapshot constitutive bounds')

  qdra=0.0_real64
  qssdi=0.0_real64
  qrot=0.0_real64
  call bind_b110_source_sink_provider(source_sink,qdra,qssdi,qrot)

  request=soil_water_solve_request_t()
  request%parameters=>parameters
  request%base_state%active_nodes=numnod
  allocate(request%base_state%pressure_head(numnod),request%base_state%water_content(numnod))
  request%base_state%pressure_head=source_h
  request%base_state%water_content=water
  request%base_state%ponding_depth=source_pegwl
  request%base_state%groundwater_level=source_gwl
  request%step_duration=dt
  request%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX
  request%boundary%bottom_mode=2
  request%boundary%top_flux=source_qtop
  request%boundary%top_head=source_pegwl
  request%boundary%bottom_flux=source_qbot
  request%boundary%bottom_head=0.0_real64
  request%physical%macropore_active=.false.
  request%numerical%max_iterations=30
  request%numerical%max_backtracking=4
  request%numerical%conductivity_implicit_mode=0
  request%numerical%conductivity_mean_method=1
  request%numerical%min_step_duration=1.0e-5_real64
  request%numerical%compartment_balance_tolerance=1.0e-6_real64
  request%numerical%total_balance_tolerance=1.0e-5_real64
  request%numerical%head_abs_tolerance=1.0e-2_real64
  request%numerical%head_rel_tolerance=1.0e-3_real64
  request%numerical%ponding_tolerance=1.0e-4_real64
  request%evaluation%constitutive=>hydraulics
  request%evaluation%source_sink=>source_sink
  request%evaluation%top_boundary=>top_provider

  call solver%solve(request,workspace,result)
  write(*,'(*(g0))') 'PPA_WU05_PERCH19_BASELINE|STATUS=',result%status, &
       '|RETRY=',result%retry_advised,'|NONLINEAR_IT=',result%diagnostics%nonlinear_iterations, &
       '|INTERNAL_RETRIES=',result%diagnostics%internal_retries, &
       '|MASS=',result%unrounded_mass_balance_residual
  call require(result%status==SW_SOLVE_CONVERGED,'Reference Richards converged')
  call require(abs(result%unrounded_mass_balance_residual)<=1.0e-8_real64,'hard mass gate')

  call derive_matrix_saturated_zone_view(result%candidate_state,z,dz,main_view)
  call require(main_view%valid .and. main_view%active,'main groundwater view')
  call derive_matrix_perched_zone_view(result%candidate_state,theta_s,z,dz,main_view,0.1_real64,perched_view)
  write(*,'(*(g0))') 'PPA_WU05_PERCH19_PERCHED|ACTIVE=',perched_view%active, &
       '|TOP=',perched_view%top_node,'|BOTTOM=',perched_view%bottom_node, &
       '|LEVEL=',perched_view%water_level_cm,'|BOTTOM_LEVEL=',perched_view%bottom_level_cm, &
       '|MAIN_TOP=',main_view%top_node
  call require(perched_view%valid .and. perched_view%active,'distinct perched topology retained')
  call require(perched_view%top_node==1,'source-consistent perched top')
  call require(perched_view%bottom_node>=28 .and. perched_view%bottom_node<=30,'source-consistent perched bottom')
  call require(main_view%top_node>=54 .and. main_view%top_node<=57,'source-consistent main groundwater top')
  call require(perched_view%bottom_node<main_view%top_node,'perched separated from main groundwater')

  ! A18 G5: enable the already-qualified A17 inner callback on exactly the
  ! same source-backed matrix state. Competing macropore transfers are
  ! suppressed so any storage gain is attributable to perched QInIntSat.
  theta_r=cofgen(1,:)
  static_volume=0.04_real64*dz
  domain_fraction=1.0_real64
  potential_bottom(1)=numnod
  diameter=10.0_real64
  wall_correction=1.0_real64
  sorp_max=0.0_real64
  sorp_alpha=0.5_real64
  unsat_conductivity=0.0_real64
  entry_head=-10.0_real64
  sorp_fac_parallel=0.33_real64
  ksat_horizontal=cofgen(3,:)
  cdarcy=0.0_real64

  print '(a)', 'PPA_WU05_PERCH19_STAGE=BEFORE_CONFIG'
  call initialize_fmr_macropore_standard_config(macro_config,1,static_volume,domain_fraction,potential_bottom, &
       z,dz,diameter,theta_s,theta_r,wall_correction,sorp_max,sorp_alpha,unsat_conductivity,entry_head, &
       sorp_fac_parallel,ksat_horizontal,cdarcy,1.0_real64,1.5_real64,1,ok, &
       rapid_enabled=.false.,perched_enabled=.true.,critical_under_saturated_volume_cm=0.1_real64)
  print '(a,l1)', 'PPA_WU05_PERCH19_STAGE=AFTER_CONFIG OK=',ok
  call require(ok .and. macro_config%valid_for_nodes(numnod),'A18 macropore config')
  macro_config%rate_template%matrix_sat%ksat_horizontal=1.0e-30_real64
  macro_config%rate_template%matrix_sat%cdarcy=0.0_real64

  print '(a)', 'PPA_WU05_PERCH19_STAGE=BEFORE_MACRO_INIT'
  call macro%initialize(1,numnod,ok)
  call require(ok,'A18 macropore state initialize')
  macro%dynamic_volume_cp=0.0_real64
  print '(a)', 'PPA_WU05_PERCH19_STAGE=BEFORE_GEOMETRY'
  call evaluate_macropore_geometry(macro_config%geometry,macro%dynamic_volume_cp,geometry)
  call require(geometry%valid,'A18 macropore geometry')
  macro%icp_bottom_domain=geometry%bottom_domain
  macro%volume_domain_cp=geometry%volume_domain_cp
  macro%water_domain_cp=0.0_real64

  macro_policy%enabled=.true.
  macro_policy%inner_richards_exchange_enabled=.true.
  macro_policy%source_reduction_ladder_enabled=.true.
  macro_policy%max_correctors=80
  macro_policy%exchange_relative_tolerance=1.0e-10_real64
  macro_policy%exchange_floor=1.0e-12_real64
  macro_policy%damping_previous_weight=0.5_real64
  macro_policy%solver_mass_tolerance_cm=1.0e-8_real64
  macro_policy%internal_exchange_tolerance_cm=1.0e-9_real64

  call macro_runtime%execute(solver,workspace,request,macro,macro_config%geometry,macro_config%rate_template, &
       macro_config%history_template,macro_policy,macro_result)
  write(*,'(*(g0))') 'PPA_WU05_PERCH19_REDUCTION|STATUS=',macro_result%status, &
       '|ATTEMPTS=',macro_result%source_reduction_attempts, &
       '|INDEX=',macro_result%source_reduction_index, &
       '|FACTOR=',macro_result%source_reduction_factor, &
       '|USED=',macro_result%inner_richards_exchange_used, &
       '|INITIAL_RATE=',macro_result%inner_initial_exchange_rate_cm_per_day, &
       '|FINAL_RATE=',macro_result%inner_final_exchange_rate_cm_per_day
  call require(macro_result%status==MACRO_RUNTIME_CONVERGED,'PERCH19 ladder converged')
  call require(macro_result%source_reduction_attempts==2,'PERCH19 exact retry count')
  call require(macro_result%source_reduction_index==1,'PERCH19 exact accepted index')
  call require(abs(macro_result%source_reduction_factor-0.1_real64)<1.0e-15_real64,'PERCH19 exact accepted factor')
  call require(macro_result%inner_richards_exchange_used,'A18 inner route used')
  call require(allocated(macro_result%exchange_rate_node),'A18 final exchange receipt allocated')
  call require(allocated(macro_result%macropore_candidate%water_domain_cp),'A18 macropore candidate allocated')
  write(*,'(*(g0))') 'PPA_WU05_PERCH19_INNER|Q=',sum(macro_result%exchange_rate_node), &
       '|MACRO_DELTA=',sum(macro_result%macropore_candidate%water_domain_cp)-sum(macro%water_domain_cp), &
       '|INTERNAL_RES=',macro_result%internal_exchange_residual_cm, &
       '|MACRO_RES=',macro_result%macro_balance_residual_cm
  call require(sum(macro_result%exchange_rate_node)<-1.0e-10_real64,'A18 perched matrix-to-macro exchange')
  call require(sum(macro_result%macropore_candidate%water_domain_cp)>sum(macro%water_domain_cp)+1.0e-12_real64, &
       'A18 perched macro storage gain')
  call require(abs(macro_result%internal_exchange_residual_cm)<=1.0e-9_real64,'A18 internal mass cancellation')
  call require(abs(macro_result%macro_balance_residual_cm)<=1.0e-9_real64,'A18 macro mass closure')
  call require(maxval(abs(macro%water_domain_cp))==0.0_real64,'A18 accepted macro state unchanged')

  print '(a)', 'PPA_WU05_PERCH19_SOURCE_ACCEPTED_SNAPSHOT=PASS'
  print '(a)', 'PPA_WU05_PERCH19_REFERENCE_RICHARDS_BASELINE=PASS'
  print '(a)', 'PPA_WU05_PERCH19_PERCHED_TOPOLOGY_RETAINED=PASS'
  print '(a)', 'PPA_WU05_PERCH19_BASELINE_GATE=PASS'
  write(*,'(*(g0))') 'PPA_WU05_PERCH19_SOURCE_REDUCTION_ACCEPTED|FACTOR=',macro_result%source_reduction_factor
  print '(a)', 'PPA_WU05_PERCH19_EXACT_LADDER=PASS'
  print '(a)', 'PPA_WU05_PERCH19_ACTIVE_PERCHED_INNER=PASS'
  print '(a)', 'PPA_WU05_PERCH19_INNER_MASS_CLOSURE=PASS'
  print '(a)', 'PPA_WU05_PERCH19_GATE=PASS'

contains

  subroutine assign_layer(first,last,theta_r,theta_sat,alpha,npar,lexp,ksat)
    integer,intent(in)::first,last
    real(real64),intent(in)::theta_r,theta_sat,alpha,npar,lexp,ksat
    do i=first,last
      cofgen(1,i)=theta_r
      cofgen(2,i)=theta_sat
      cofgen(3,i)=ksat
      cofgen(4,i)=alpha
      cofgen(5,i)=lexp
      cofgen(6,i)=npar
      cofgen(7,i)=1.0_real64-1.0_real64/npar
      cofgen(8,i)=alpha
      cofgen(9,i)=-10.0_real64
      cofgen(10,i)=-999.0_real64
      cofgen(11,i)=0.0_real64
      cofgen(12,i)=0.0_real64
      cofgen(22,i)=0.0_real64
      cofgen(23,i)=0.0_real64
      cofgen(24,i)=1.0e-8_real64
    end do
  end subroutine assign_layer

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(a,1x,a)') 'PPA_WU05_PERCH19_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_ppa_wu05_perch19_reduction_ladder
