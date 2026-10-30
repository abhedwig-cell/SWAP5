program test_ppa_micro02_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64
  use MOD_grid, only: dz
  use MOD_re_global, only: hroot, mroot, mflux
  use mod_RWU_micro, only: RWU_micro, UpwPot, swDoSatRel, swHydrLift, swO2ECT, swTypeTred, &
       RootRadius, Kroot, Lstem_A0, Lstem_A1, PLhalf, CampA, Tol_2, myTolX, TolConv, factor, Ntrial, PP, X, Q, S, delX, iMicro
  use mod_root_micro_matric_flux_table
  use mod_root_micro_de_willigen_process
  use original_micro_attribution,only:original_attribute
  implicit none
  type(micro_matric_flux_table_t) :: tables(2)
  type(micro_de_willigen_parameters_t) :: parameters
  type(micro_de_willigen_result_t) :: typed
  real(real64) :: samples(MICRO_TABLE_POINTS), head(2), density(2), stress(2)
  real(real64) :: source_flux(2), alpha, tact, tact1, tact2
  logical :: check(3)
  integer :: j, status, case_no,mode
  real(real64)::dry,oxy,salt,drought,rdry,roxy,rsalt,rdrought,actual,optimal,max_attribution_difference
  real(real64)::oxygen(2),salinity(2)

  samples=.01_real64
  do j=1,2
    call build_micro_matric_flux_table(samples,.01_real64,.01_real64,tables(j),status)
    if(status/=MICRO_TABLE_OK) error stop 1
  end do
  allocate(UpwPot(2))
  parameters%root_radius_cm=.01_real64
  parameters%root_conductance_cm_per_day=.001_real64
  parameters%stem_a0_per_day=.01_real64
  parameters%stem_a1_per_cm=.001_real64
  parameters%half_leaf_pressure_cm=10000.0_real64
  parameters%campbell_exponent=2.0_real64
  parameters%residual_tolerance_cm_per_day=1.0e-6_real64
  RootRadius=parameters%root_radius_cm
  Kroot=parameters%root_conductance_cm_per_day
  Lstem_A0=parameters%stem_a0_per_day
  Lstem_A1=parameters%stem_a1_per_cm
  PLhalf=1.0_real64/parameters%half_leaf_pressure_cm
  CampA=parameters%campbell_exponent
  Tol_2=1.0e-6_real64
  myTolX=1.0e-7_real64
  TolConv=1.0e-4_real64
  factor=1.25_real64
  Ntrial=500
  ! do_RWU_micro normally sets this module SAVE value before calling RWU_micro.
  ! The direct oracle entry point must make that hidden source dependency explicit.
  iMicro=1
  swDoSatRel=0
  swHydrLift=0
  head=[-100.0_real64,-100.0_real64]
  density=.5_real64

  do case_no=1,4
    swO2ECT=0
    swTypeTred=1
    stress=1.0_real64
    select case(case_no)
    case(2)
      swO2ECT=1
      stress=[.75_real64,.5_real64]
    case(3)
      swO2ECT=2
      stress=[.75_real64,.5_real64]
    case(4)
      swTypeTred=2
    end select
    parameters%oxygen_mode=swO2ECT
    parameters%reduction_mode=swTypeTred
    call RWU_micro(1,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
    call RWU_micro(2,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
    print '(A,I0,A,3L2,A,5ES17.8)', 'SOURCE_DIAGNOSTIC=',case_no,' CHECK=',check, &
         ' TACT/T1/T2/U1/U2=',tact,tact1,tact2,source_flux
    print '(A,ES17.8,A,2ES17.8,A,2ES17.8,A,2ES17.8)', &
         'SOURCE_ROOT_PP=',PP,' HROOT=',hroot,' MROOT=',mroot,' MFLUX=',mflux
    print '(A,3ES17.8,A,2ES17.8,A,2ES17.8,A,3ES17.8)', &
         'SOURCE_X=',X,' Q=',Q,' S=',S,' DELX=',delX
    if(.not.all(check)) error stop 2
    call evaluate_micro_de_willigen(parameters,head,dz,density,stress,2,.1_real64,tables,typed)
    if(typed%status/=MICRO_DW_OK) error stop 3
    if(any(abs(typed%root_extraction_sink-source_flux)>2.0e-5_real64)) then
      print *,case_no,source_flux,typed%root_extraction_sink
      error stop 4
    end if
    print '(A,I0,A,2F12.8)', 'SOURCE_CASE=',case_no,' UPTAKE=',source_flux
  end do
  ! Heterogeneous pressure heads with one source hydraulic horizon.
  head=[-100.0_real64,-200.0_real64]
  swO2ECT=0
  swTypeTred=1
  stress=1.0_real64
  call RWU_micro(1,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  call RWU_micro(2,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  if(.not.all(check).or.any(source_flux<0.0_real64)) error stop 5
  parameters%oxygen_mode=0
  parameters%reduction_mode=1
  call evaluate_micro_de_willigen(parameters,head,dz,density,stress,2,.1_real64,tables,typed)
  if(typed%status/=MICRO_DW_OK.or.any(typed%root_extraction_sink<0.0_real64)) error stop 6
  if(any(abs(typed%root_extraction_sink-source_flux)>2.0e-5_real64)) error stop 7
  print '(A,2F12.8,A,3L2)', 'SOURCE_SYNCED_NO_LIFT=',source_flux,' CHECK=',check
  ! Actual original potato scalar values on the incumbent oracle profile.
  ! This is component execution, not a historical-project migration claim.
  parameters%root_radius_cm=.013_real64;parameters%root_conductance_cm_per_day=.000035_real64
  parameters%stem_a0_per_day=.000031844_real64;parameters%stem_a1_per_cm=.00017768_real64
  parameters%half_leaf_pressure_cm=16000._real64;parameters%campbell_exponent=5._real64
  parameters%pressure_tolerance_cm=.000001_real64;parameters%newton_tolerance_cm=.00001_real64
  parameters%residual_tolerance_cm_per_day=.0001_real64;parameters%oxygen_mode=1
  RootRadius=parameters%root_radius_cm;Kroot=parameters%root_conductance_cm_per_day
  Lstem_A0=parameters%stem_a0_per_day;Lstem_A1=parameters%stem_a1_per_cm
  PLhalf=1._real64/parameters%half_leaf_pressure_cm;CampA=parameters%campbell_exponent
  Tol_2=parameters%pressure_tolerance_cm;myTolX=parameters%newton_tolerance_cm
  TolConv=parameters%residual_tolerance_cm_per_day;swO2ECT=1
  stress=[.75_real64,.5_real64]
  call RWU_micro(1,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  call RWU_micro(2,1,2,dz,head,density,stress,.false.,.1_real64,tact,source_flux,alpha,tact1,tact2,check)
  if(.not.all(check))error stop 8
  call evaluate_micro_de_willigen(parameters,head,dz,density,stress,2,.1_real64,tables,typed)
  if(typed%status/=MICRO_DW_OK.or.any(abs(typed%root_extraction_sink-source_flux)>2.e-5_real64))error stop 9
  print '(A,2ES17.8)', 'DATAQUAL15_ORIGINAL_POTATO_MICRO_SCALARS=',source_flux
  ! Reuse this original microscopic uptake observation with the literal source
  ! root-stress partition. P_func uses LRV*DZ, not the already reduced sink.
  max_attribution_difference=0._real64
  do case_no=1,6
    oxygen=1._real64;salinity=1._real64;mode=0;actual=sum(source_flux);optimal=actual
    select case(case_no)
    case(2)
      oxygen=[.75_real64,.5_real64]
    case(3)
      salinity=[.9_real64,.8_real64]
    case(4)
      oxygen=[.75_real64,.5_real64];salinity=[.9_real64,.8_real64]
    case(5)
      oxygen=[.75_real64,.5_real64];salinity=[.9_real64,.8_real64]
      mode=1;optimal=.1_real64-.5_real64*(.1_real64-actual)
    case(6)
      actual=0._real64;optimal=0._real64
    end select
    call original_attribute(2,dz,density,oxygen,salinity,.1_real64,actual,mode,optimal,rdry,roxy,rsalt,rdrought)
    call attribute_micro_root_stress_losses(dz,density,oxygen,salinity,2,.1_real64,actual,mode,optimal, &
         dry,oxy,salt,drought,status)
    if(status/=MICRO_DW_OK)error stop 10
    max_attribution_difference=max(max_attribution_difference,maxval(abs([dry-rdry,oxy-roxy,salt-rsalt,drought-rdrought])))
    if(max_attribution_difference>1.e-14_real64)error stop 11
    if(abs(dry+oxy+salt-(.1_real64-actual))>1.e-14_real64)error stop 12
    print '(A,I0,A,4ES17.8)', 'DATAQUAL15_LITERAL_MICRO_PARTITION=',case_no,' LOSSES/ROOT_FACTOR=',dry,oxy,salt,drought
  end do
  call attribute_micro_root_stress_losses(dz,density,oxygen,salinity,2,0._real64,0._real64,0,0._real64, &
       dry,oxy,salt,drought,status)
  if(status/=MICRO_DW_OK.or.drought/=0._real64)error stop 13
  call original_attribute(2,dz,density,oxygen,salinity,0._real64,0._real64,0,0._real64, &
       rdry,roxy,rsalt,rdrought,previous=.37_real64)
  call attribute_micro_root_stress_losses(dz,density,oxygen,salinity,2,0._real64,0._real64,0,0._real64, &
       dry,oxy,salt,drought,status,previous_drought_factor=.37_real64)
  if(status/=MICRO_DW_OK.or.drought/=rdrought.or.drought/=.37_real64)error stop 15
  print '(A,ES25.17E3)', 'DATAQUAL15_SOURCE_ZERO_DEMAND_SAVED_FACTOR=',drought
  call attribute_micro_root_stress_losses(dz,density,oxygen,salinity,2,.1_real64,.08_real64,1,.05_real64, &
       dry,oxy,salt,drought,status)
  if(status/=MICRO_DW_INVALID)error stop 14
  print '(A,ES25.17E3)', 'DATAQUAL15_MAX_ATTRIBUTION_DIFFERENCE=',max_attribution_difference
  print '(A)', 'DATAQUAL15_MICRO_PARTITION_SOURCE_ZERO_DEMAND_AND_INVALID_OPTIMUM=PASS'
  print '(A)', 'MICRO02_CORRECTED_LITERAL_COMPARISON_PASS'
end program
